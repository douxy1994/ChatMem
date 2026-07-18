use std::collections::HashMap;
use std::path::{Path, PathBuf};

use anyhow::Result;
use chrono::{DateTime, Utc};
use serde_json::{json, Value};
use uuid::Uuid;

use agentswap_core::adapter::AgentAdapter;
use agentswap_core::files::move_path_to_trash;
use agentswap_core::titles::{choose_title, title_candidate};
use agentswap_core::types::*;

/// Returns the Kimi Code data root: `$KIMI_CODE_HOME` when set, otherwise `~/.kimi-code`.
pub fn kimi_code_home() -> Option<PathBuf> {
    if let Some(custom) = std::env::var_os("KIMI_CODE_HOME") {
        let custom = PathBuf::from(custom);
        if !custom.as_os_str().is_empty() {
            return Some(custom);
        }
    }
    dirs::home_dir().map(|home| home.join(".kimi-code"))
}

/// Adapter for reading Kimi Code CLI sessions.
///
/// Layout (see Kimi Code docs "Data locations"):
/// `<home>/sessions/<workDirKey>/<sessionId>/state.json` for metadata and
/// `<home>/sessions/<workDirKey>/<sessionId>/agents/<agent>/wire.jsonl` for the
/// main agent and sub-agent transcripts.
pub struct KimiCodeAdapter {
    home_dir: PathBuf,
}

impl Default for KimiCodeAdapter {
    fn default() -> Self {
        Self::new()
    }
}

struct SessionState {
    title: Option<String>,
    work_dir: Option<String>,
    created_at: Option<DateTime<Utc>>,
    updated_at: Option<DateTime<Utc>>,
}

struct PendingToolResult {
    output: String,
    is_error: bool,
}

impl KimiCodeAdapter {
    pub fn new() -> Self {
        Self {
            home_dir: kimi_code_home().unwrap_or_else(|| PathBuf::from("/")),
        }
    }

    #[allow(dead_code)]
    pub fn with_home_dir(home_dir: PathBuf) -> Self {
        Self { home_dir }
    }

    fn sessions_dir(&self) -> PathBuf {
        self.home_dir.join("sessions")
    }

    fn find_session_dir(&self, id: &str) -> Option<PathBuf> {
        let sessions_dir = self.sessions_dir();
        let workspaces = std::fs::read_dir(&sessions_dir).ok()?;
        for workspace in workspaces.flatten() {
            let candidate = workspace.path().join(id);
            if candidate.is_dir() {
                return Some(candidate);
            }
        }
        None
    }

    fn parse_state(session_dir: &Path) -> SessionState {
        let raw = std::fs::read_to_string(session_dir.join("state.json")).unwrap_or_default();
        let value: Value = serde_json::from_str(&raw).unwrap_or_else(|_| json!({}));
        let parse_ts = |key: &str| {
            value
                .get(key)
                .and_then(|item| item.as_str())
                .and_then(|item| item.parse::<DateTime<Utc>>().ok())
        };
        SessionState {
            title: value
                .get("title")
                .and_then(|item| item.as_str())
                .map(|item| item.trim().to_string())
                .filter(|item| !item.is_empty()),
            work_dir: value
                .get("workDir")
                .and_then(|item| item.as_str())
                .map(|item| item.trim().to_string())
                .filter(|item| !item.is_empty()),
            created_at: parse_ts("createdAt"),
            updated_at: parse_ts("updatedAt"),
        }
    }

    fn event_time(value: &Value, fallback: DateTime<Utc>) -> DateTime<Utc> {
        value
            .get("time")
            .and_then(|item| item.as_i64())
            .and_then(DateTime::from_timestamp_millis)
            .unwrap_or(fallback)
    }

    fn looks_like_absolute_path(value: &str) -> bool {
        let value = value.strip_prefix("file://").unwrap_or(value);
        value.starts_with('/')
            || value.starts_with("~/")
            || (value.len() > 2
                && value.as_bytes()[1] == b':'
                && (value.as_bytes()[2] == b'\\' || value.as_bytes()[2] == b'/'))
    }

    fn is_project_dir_key(key: &str) -> bool {
        matches!(
            key.to_ascii_lowercase().as_str(),
            "cwd" | "currentworkingdirectory" | "workingdirectory" | "workdir" | "projectpath"
                | "projectdir"
        )
    }

    fn is_file_path_key(key: &str) -> bool {
        matches!(
            key.to_ascii_lowercase().as_str(),
            "absolutepath" | "absolute_path" | "filepath" | "file_path" | "path"
        )
    }

    fn collect_named_strings(value: &Value, output: &mut Vec<(String, String)>) {
        match value {
            Value::Object(map) => {
                for (key, nested) in map {
                    if let Some(text) = nested.as_str() {
                        output.push((key.clone(), text.to_string()));
                    }
                    Self::collect_named_strings(nested, output);
                }
            }
            Value::Array(items) => {
                for item in items {
                    Self::collect_named_strings(item, output);
                }
            }
            _ => {}
        }
    }

    /// Lists agent transcript files inside a session dir, main agent first,
    /// then sub-agents in directory-name order.
    fn agent_wire_files(session_dir: &Path) -> Vec<(String, PathBuf)> {
        let agents_dir = session_dir.join("agents");
        let mut files = Vec::new();
        let entries = match std::fs::read_dir(&agents_dir) {
            Ok(entries) => entries,
            Err(_) => return files,
        };
        let mut sub_agents = Vec::new();
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().to_string();
            let wire = entry.path().join("wire.jsonl");
            if !wire.exists() {
                continue;
            }
            if name == "main" {
                files.push((name, wire));
            } else {
                sub_agents.push((name, wire));
            }
        }
        sub_agents.sort_by(|a, b| a.0.cmp(&b.0));
        files.extend(sub_agents);
        files
    }

    /// Parses one agent wire.jsonl into messages, file changes and the first
    /// user prompt seen. Kimi Code emits the real user input as `turn.prompt`;
    /// assistant output arrives as loop events (`content.part`, `tool.call`,
    /// `tool.result`) grouped by `(turnId, step)`.
    fn parse_wire(
        wire_path: &Path,
        agent_name: &str,
    ) -> (Vec<Message>, Vec<FileChange>, Option<String>, Option<String>) {
        let file = match std::fs::File::open(wire_path) {
            Ok(file) => file,
            Err(_) => return (Vec::new(), Vec::new(), None, None),
        };
        let reader = std::io::BufReader::new(file);
        use std::io::BufRead;

        let mut messages: Vec<Message> = Vec::new();
        let mut file_changes = Vec::new();
        let mut tool_results: HashMap<String, PendingToolResult> = HashMap::new();
        // toolCallId -> (message index, tool call index) so late tool.result
        // events land on the exact call they belong to.
        let mut pending_calls: HashMap<String, (usize, usize)> = HashMap::new();
        let mut first_user_msg: Option<String> = None;
        let mut project_dir: Option<String> = None;
        let mut last_ts = Utc::now();
        // Index of the assistant message currently collecting loop events,
        // keyed by (turnId, step) so a new step starts a fresh message.
        let mut current_step: Option<(String, i64)> = None;

        for line in reader.lines() {
            let line = match line {
                Ok(line) => line,
                Err(_) => continue,
            };
            if line.trim().is_empty() {
                continue;
            }
            let value: Value = match serde_json::from_str(&line) {
                Ok(value) => value,
                Err(_) => continue,
            };
            let ts = Self::event_time(&value, last_ts);
            last_ts = ts;

            match value.get("type").and_then(|item| item.as_str()) {
                Some("turn.prompt") => {
                    let text = value
                        .get("input")
                        .and_then(|item| item.as_array())
                        .map(|parts| {
                            parts
                                .iter()
                                .filter(|part| part.get("type").and_then(|t| t.as_str()) == Some("text"))
                                .filter_map(|part| part.get("text").and_then(|t| t.as_str()))
                                .collect::<Vec<_>>()
                                .join("\n")
                        })
                        .unwrap_or_default();
                    let text = text.trim().to_string();
                    if text.is_empty() {
                        continue;
                    }
                    if first_user_msg.is_none() {
                        first_user_msg = title_candidate(&text, 100);
                    }
                    current_step = None;
                    messages.push(Message {
                        id: Uuid::new_v4(),
                        timestamp: ts,
                        role: Role::User,
                        content: text,
                        tool_calls: Vec::new(),
                        metadata: HashMap::from([(
                            "kimi_agent".to_string(),
                            json!(agent_name),
                        )]),
                    });
                }
                Some("context.append_loop_event") => {
                    let event = match value.get("event") {
                        Some(event) => event,
                        None => continue,
                    };
                    let turn_id = event
                        .get("turnId")
                        .and_then(|item| item.as_str())
                        .unwrap_or("")
                        .to_string();
                    let step = event.get("step").and_then(|item| item.as_i64()).unwrap_or(0);
                    let step_key = (turn_id, step);

                    match event.get("type").and_then(|item| item.as_str()) {
                        Some("content.part") => {
                            let part = match event.get("part") {
                                Some(part) => part,
                                None => continue,
                            };
                            let part_type = part.get("type").and_then(|item| item.as_str()).unwrap_or("");
                            let text = match part_type {
                                "text" => part.get("text").and_then(|item| item.as_str()),
                                "think" => part.get("think").and_then(|item| item.as_str()),
                                _ => None,
                            };
                            let text = text.unwrap_or("").trim().to_string();
                            if text.is_empty() {
                                continue;
                            }
                            if current_step.as_ref() != Some(&step_key) {
                                current_step = Some(step_key);
                                messages.push(Message {
                                    id: Uuid::new_v4(),
                                    timestamp: ts,
                                    role: Role::Assistant,
                                    content: String::new(),
                                    tool_calls: Vec::new(),
                                    metadata: HashMap::from([(
                                        "kimi_agent".to_string(),
                                        json!(agent_name),
                                    )]),
                                });
                            }
                            let message = match messages.last_mut() {
                                Some(message) => message,
                                None => continue,
                            };
                            if part_type == "text" {
                                if !message.content.is_empty() {
                                    message.content.push_str("\n\n");
                                }
                                message.content.push_str(&text);
                            } else {
                                let thinking = message
                                    .metadata
                                    .entry("thinking".to_string())
                                    .or_insert_with(|| json!(""));
                                let merged = format!(
                                    "{}\n\n{}",
                                    thinking.as_str().unwrap_or(""),
                                    text
                                );
                                *thinking = json!(merged.trim());
                            }
                        }
                        Some("tool.call") => {
                            let name = event
                                .get("name")
                                .and_then(|item| item.as_str())
                                .unwrap_or("")
                                .to_string();
                            let args = event.get("args").cloned().unwrap_or_else(|| json!({}));
                            let call_id = event
                                .get("toolCallId")
                                .and_then(|item| item.as_str())
                                .map(|item| item.to_string());

                            if current_step.as_ref() != Some(&step_key) {
                                current_step = Some(step_key);
                                messages.push(Message {
                                    id: Uuid::new_v4(),
                                    timestamp: ts,
                                    role: Role::Assistant,
                                    content: String::new(),
                                    tool_calls: Vec::new(),
                                    metadata: HashMap::from([(
                                        "kimi_agent".to_string(),
                                        json!(agent_name),
                                    )]),
                                });
                            }
                            let message_index = messages.len() - 1;
                            let message_id = messages[message_index].id;

                            let mut named_strings = Vec::new();
                            Self::collect_named_strings(&args, &mut named_strings);
                            for (key, raw_value) in &named_strings {
                                let normalized = raw_value
                                    .strip_prefix("file://")
                                    .unwrap_or(raw_value)
                                    .to_string();
                                if project_dir.is_none()
                                    && Self::is_project_dir_key(key)
                                    && Self::looks_like_absolute_path(&normalized)
                                {
                                    project_dir = Some(normalized.clone());
                                }
                                if Self::is_file_path_key(key)
                                    && Self::looks_like_absolute_path(&normalized)
                                {
                                    file_changes.push(FileChange {
                                        path: normalized,
                                        change_type: ChangeType::Modified,
                                        timestamp: ts,
                                        message_id,
                                    });
                                }
                            }

                            let mut tool_call = ToolCall {
                                name,
                                input: args,
                                output: None,
                                status: ToolStatus::Success,
                            };
                            if let Some(call_id) = call_id.as_ref() {
                                if let Some(result) = tool_results.get(call_id) {
                                    tool_call.output = Some(result.output.clone());
                                    if result.is_error {
                                        tool_call.status = ToolStatus::Error;
                                    }
                                }
                            }
                            let message = &mut messages[message_index];
                            message.tool_calls.push(tool_call);
                            if let Some(call_id) = call_id {
                                pending_calls
                                    .insert(call_id, (message_index, message.tool_calls.len() - 1));
                            }
                        }
                        Some("tool.result") => {
                            let call_id = event
                                .get("toolCallId")
                                .and_then(|item| item.as_str())
                                .unwrap_or("")
                                .to_string();
                            if call_id.is_empty() {
                                continue;
                            }
                            let raw_output = event
                                .get("result")
                                .and_then(|result| result.get("output"))
                                .cloned()
                                .unwrap_or_else(|| json!(""));
                            let output = match raw_output.as_str() {
                                Some(text) => text.to_string(),
                                None => raw_output.to_string(),
                            };
                            let is_error = event
                                .get("result")
                                .and_then(|result| result.get("is_error"))
                                .and_then(|item| item.as_bool())
                                .unwrap_or(false);
                            tool_results.insert(call_id.clone(), PendingToolResult { output, is_error });
                            // Fill the matching tool call when it was already recorded.
                            if let Some((message_index, call_index)) = pending_calls.get(&call_id) {
                                if let Some(result) = tool_results.get(&call_id) {
                                    if let Some(tool_call) = messages
                                        .get_mut(*message_index)
                                        .and_then(|message| message.tool_calls.get_mut(*call_index))
                                    {
                                        tool_call.output = Some(result.output.clone());
                                        if result.is_error {
                                            tool_call.status = ToolStatus::Error;
                                        }
                                    }
                                }
                            }
                        }
                        _ => {}
                    }
                }
                _ => {}
            }
        }

        (messages, file_changes, first_user_msg, project_dir)
    }
}

impl AgentAdapter for KimiCodeAdapter {
    fn is_available(&self) -> bool {
        self.sessions_dir().exists()
    }

    fn list_conversations(&self) -> Result<Vec<ConversationSummary>> {
        let mut summaries = Vec::new();
        let sessions_dir = self.sessions_dir();
        if !sessions_dir.exists() {
            return Ok(summaries);
        }

        for workspace in std::fs::read_dir(&sessions_dir)?.flatten() {
            let workspace_path = workspace.path();
            if !workspace_path.is_dir() {
                continue;
            }
            let sessions = match std::fs::read_dir(&workspace_path) {
                Ok(sessions) => sessions,
                Err(_) => continue,
            };
            for session in sessions.flatten() {
                let session_path = session.path();
                if !session_path.is_dir() {
                    continue;
                }
                if Self::agent_wire_files(&session_path).is_empty() {
                    continue;
                }
                let id = session.file_name().to_string_lossy().to_string();
                if let Ok(conv) = self.read_conversation(&id) {
                    summaries.push(ConversationSummary {
                        id: conv.id,
                        source_agent: conv.source_agent,
                        project_dir: conv.project_dir,
                        created_at: conv.created_at,
                        updated_at: conv.updated_at,
                        summary: conv.summary,
                        message_count: conv.messages.len(),
                        file_count: conv.file_changes.len(),
                    });
                }
            }
        }
        summaries.sort_by(|a, b| b.updated_at.cmp(&a.updated_at));
        Ok(summaries)
    }

    fn read_conversation(&self, id: &str) -> Result<Conversation> {
        let session_dir = self
            .find_session_dir(id)
            .ok_or_else(|| anyhow::anyhow!("Kimi Code session not found for id: {}", id))?;

        let state = Self::parse_state(&session_dir);
        let wire_files = Self::agent_wire_files(&session_dir);
        if wire_files.is_empty() {
            anyhow::bail!("Kimi Code session has no wire transcript for id: {}", id);
        }

        let mut messages = Vec::new();
        let mut file_changes = Vec::new();
        let mut first_user_msg: Option<String> = None;
        let mut project_dir = state.work_dir.clone();

        for (agent_name, wire_path) in &wire_files {
            let (mut agent_messages, mut agent_changes, agent_first_user, agent_project) =
                Self::parse_wire(wire_path, agent_name);
            if first_user_msg.is_none() {
                first_user_msg = agent_first_user;
            }
            if project_dir.is_none() {
                project_dir = agent_project;
            }
            messages.append(&mut agent_messages);
            file_changes.append(&mut agent_changes);
        }

        // Merge main and sub-agent events into a single timeline.
        messages.sort_by_key(|message| message.timestamp);

        let created_at = state
            .created_at
            .or_else(|| messages.first().map(|message| message.timestamp))
            .unwrap_or_else(Utc::now);
        let updated_at = state
            .updated_at
            .or_else(|| messages.last().map(|message| message.timestamp))
            .unwrap_or(created_at);

        Ok(Conversation {
            id: id.to_string(),
            source_agent: AgentKind::KimiCode,
            project_dir: project_dir.unwrap_or_else(|| session_dir.display().to_string()),
            created_at,
            updated_at,
            summary: choose_title(state.title.as_deref(), first_user_msg.as_deref(), 100),
            messages,
            file_changes,
        })
    }

    fn render_prompt(&self, conversation: &Conversation) -> Result<String> {
        let mut text = String::new();
        text.push_str(&format!(
            "# Conversation: {}\n\n",
            conversation.summary.as_deref().unwrap_or(conversation.id.as_str())
        ));
        text.push_str("**Source:** Kimi Code\n");
        text.push_str(&format!(
            "**Started:** {}\n",
            conversation.created_at.to_rfc3339()
        ));
        text.push_str(&format!(
            "**Last Updated:** {}\n\n",
            conversation.updated_at.to_rfc3339()
        ));

        for msg in &conversation.messages {
            text.push_str(&format!("## {:?}\n", msg.role));
            text.push_str(&format!("**Time:** {}\n\n", msg.timestamp.to_rfc3339()));
            if !msg.content.trim().is_empty() {
                text.push_str(&msg.content);
                text.push_str("\n\n");
            }
        }

        Ok(text)
    }

    fn agent_kind(&self) -> AgentKind {
        AgentKind::KimiCode
    }

    fn display_name(&self) -> &str {
        "Kimi Code"
    }

    fn data_dir(&self) -> PathBuf {
        self.sessions_dir()
    }

    fn delete_conversation(&self, id: &str) -> Result<()> {
        if let Some(session_dir) = self.find_session_dir(id) {
            move_path_to_trash(&session_dir)?;
        }
        Ok(())
    }

    fn write_conversation(&self, _conversation: &Conversation) -> Result<String> {
        anyhow::bail!("Kimi Code write is not implemented")
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write as IoWrite;
    use tempfile::TempDir;

    /// Helper: create a Kimi Code session layout under `<tmp>/sessions/<wd>/<id>/`.
    fn create_test_session(home: &Path, workspace: &str, id: &str) -> PathBuf {
        let session_dir = home.join("sessions").join(workspace).join(id);
        let main_dir = session_dir.join("agents").join("main");
        std::fs::create_dir_all(&main_dir).expect("create session dirs");
        session_dir
    }

    fn write_file(path: &Path, content: &str) {
        let mut file = std::fs::File::create(path).expect("create fixture file");
        file.write_all(content.as_bytes()).expect("write fixture");
    }

    #[test]
    fn test_kimi_reads_session_wire_and_state() {
        let tmp = TempDir::new().expect("temp dir");
        let home = tmp.path().join("kimi-home");
        let session_dir = create_test_session(&home, "wd_proj_0123456789ab", "session_test-001");

        write_file(
            &session_dir.join("state.json"),
            r#"{
  "createdAt": "2026-07-18T07:23:56.160Z",
  "updatedAt": "2026-07-18T08:19:45.363Z",
  "title": "修复登录 bug",
  "isCustomTitle": false,
  "custom": {},
  "workDir": "/tmp/proj",
  "lastPrompt": "再跑一下测试"
}"#,
        );

        write_file(
            &session_dir.join("agents").join("main").join("wire.jsonl"),
            r#"{"type":"metadata","protocol_version":"1.4","created_at":1784359436181}
{"type":"config.update","profileName":"agent","systemPrompt":"You are Kimi Code CLI."}
{"type":"turn.prompt","input":[{"type":"text","text":"修复登录 bug"}],"origin":{"kind":"user"},"time":1784359474365}
{"type":"context.append_loop_event","event":{"type":"content.part","uuid":"p1","turnId":"0","step":1,"part":{"type":"think","think":"先看一下代码"}},"time":1784359475000}
{"type":"context.append_loop_event","event":{"type":"tool.call","uuid":"tool_1","turnId":"0","step":1,"toolCallId":"tool_1","name":"Edit","args":{"path":"/tmp/proj/src/login.rs","old_string":"a","new_string":"b"}},"time":1784359476000}
{"type":"context.append_loop_event","event":{"type":"tool.result","toolCallId":"tool_1","result":{"output":"The edit was applied successfully."}},"time":1784359477000}
{"type":"context.append_loop_event","event":{"type":"content.part","uuid":"p2","turnId":"0","step":2,"part":{"type":"text","text":"已修复登录逻辑。"}},"time":1784359480000}
{"type":"turn.prompt","input":[{"type":"text","text":"再跑一下测试"}],"origin":{"kind":"user"},"time":1784359490000}
{"type":"context.append_loop_event","event":{"type":"content.part","uuid":"p3","turnId":"1","step":1,"part":{"type":"text","text":"测试全部通过。"}},"time":1784359500000}
"#,
        );

        let adapter = KimiCodeAdapter::with_home_dir(home.clone());
        assert!(adapter.is_available());

        let summaries = adapter.list_conversations().expect("list conversations");
        assert_eq!(summaries.len(), 1);
        assert_eq!(summaries[0].id, "session_test-001");
        assert_eq!(summaries[0].project_dir, "/tmp/proj");
        assert_eq!(summaries[0].summary.as_deref(), Some("修复登录 bug"));

        let conv = adapter
            .read_conversation("session_test-001")
            .expect("read conversation");
        assert_eq!(conv.source_agent, AgentKind::KimiCode);
        assert_eq!(conv.source_agent_name(), "Kimi Code");
        assert_eq!(conv.project_dir, "/tmp/proj");
        assert_eq!(conv.summary.as_deref(), Some("修复登录 bug"));
        assert_eq!(conv.created_at.to_rfc3339(), "2026-07-18T07:23:56.160+00:00");
        assert_eq!(conv.updated_at.to_rfc3339(), "2026-07-18T08:19:45.363+00:00");

        assert_eq!(conv.messages.len(), 5);
        assert_eq!(conv.messages[0].role, Role::User);
        assert_eq!(conv.messages[0].content, "修复登录 bug");

        // Step 1: thinking + tool call land on one assistant message.
        assert_eq!(conv.messages[1].role, Role::Assistant);
        assert_eq!(conv.messages[1].tool_calls.len(), 1);
        assert_eq!(conv.messages[1].tool_calls[0].name, "Edit");
        assert_eq!(
            conv.messages[1].tool_calls[0].output.as_deref(),
            Some("The edit was applied successfully.")
        );
        assert_eq!(
            conv.messages[1].metadata.get("thinking").and_then(|v| v.as_str()),
            Some("先看一下代码")
        );

        // Step 2: separate assistant message for the visible reply.
        assert_eq!(conv.messages[2].role, Role::Assistant);
        assert_eq!(conv.messages[2].content, "已修复登录逻辑。");

        assert_eq!(conv.messages[3].role, Role::User);
        assert_eq!(conv.messages[3].content, "再跑一下测试");

        assert_eq!(conv.messages[4].role, Role::Assistant);
        assert_eq!(conv.messages[4].content, "测试全部通过。");

        assert_eq!(conv.file_changes.len(), 1);
        assert_eq!(conv.file_changes[0].path, "/tmp/proj/src/login.rs");
        assert_eq!(conv.file_changes[0].change_type, ChangeType::Modified);
    }

    #[test]
    fn test_kimi_reads_sub_agent_wire() {
        let tmp = TempDir::new().expect("temp dir");
        let home = tmp.path().join("kimi-home");
        let session_dir = create_test_session(&home, "wd_proj_0123456789ab", "session_test-002");
        let sub_dir = session_dir.join("agents").join("agent-0");
        std::fs::create_dir_all(&sub_dir).expect("create sub agent dir");

        write_file(
            &session_dir.join("state.json"),
            r#"{"createdAt":"2026-07-18T07:23:56.160Z","updatedAt":"2026-07-18T08:19:45.363Z","title":"探索代码库","workDir":"/tmp/proj"}"#,
        );
        write_file(
            &session_dir.join("agents").join("main").join("wire.jsonl"),
            r#"{"type":"turn.prompt","input":[{"type":"text","text":"探索代码库"}],"origin":{"kind":"user"},"time":1784359474365}
{"type":"context.append_loop_event","event":{"type":"content.part","uuid":"p1","turnId":"0","step":1,"part":{"type":"text","text":"已派出子代理。"}},"time":1784359600000}
"#,
        );
        write_file(
            &sub_dir.join("wire.jsonl"),
            r#"{"type":"context.append_loop_event","event":{"type":"content.part","uuid":"s1","turnId":"0","step":1,"part":{"type":"text","text":"子代理结论。"}},"time":1784359500000}
"#,
        );

        let adapter = KimiCodeAdapter::with_home_dir(home);
        let conv = adapter
            .read_conversation("session_test-002")
            .expect("read conversation");
        assert_eq!(conv.messages.len(), 3);
        // Sub-agent output is merged into the timeline by timestamp.
        assert_eq!(conv.messages[1].content, "子代理结论。");
        assert_eq!(
            conv.messages[1].metadata.get("kimi_agent").and_then(|v| v.as_str()),
            Some("agent-0")
        );
        assert_eq!(conv.messages[2].content, "已派出子代理。");
    }

    #[test]
    fn test_kimi_unavailable_without_sessions_dir() {
        let tmp = TempDir::new().expect("temp dir");
        let adapter = KimiCodeAdapter::with_home_dir(tmp.path().join("missing"));
        assert!(!adapter.is_available());
        assert!(adapter.list_conversations().expect("list").is_empty());
        assert!(adapter.read_conversation("session_none").is_err());
    }

    #[test]
    fn test_real_kimi_sessions_if_available() {
        let adapter = KimiCodeAdapter::new();
        if !adapter.is_available() {
            return;
        }

        let summaries = adapter.list_conversations().expect("list real conversations");
        if summaries.is_empty() {
            return;
        }

        assert!(
            summaries
                .iter()
                .all(|summary| summary.source_agent == AgentKind::KimiCode)
        );
        let conv = adapter
            .read_conversation(&summaries[0].id)
            .expect("read newest real conversation");
        assert_eq!(conv.source_agent, AgentKind::KimiCode);
        assert!(!conv.project_dir.is_empty());
        assert!(
            !conv.messages.is_empty(),
            "real Kimi Code sessions should contain at least one message"
        );
        assert!(
            conv.messages.iter().any(|message| message.role == Role::User),
            "real Kimi Code sessions should contain a user prompt"
        );
    }

    #[test]
    fn test_kimi_title_falls_back_to_first_prompt() {
        let tmp = TempDir::new().expect("temp dir");
        let home = tmp.path().join("kimi-home");
        let session_dir = create_test_session(&home, "wd_proj_0123456789ab", "session_test-003");
        write_file(
            &session_dir.join("state.json"),
            r#"{"createdAt":"2026-07-18T07:23:56.160Z","updatedAt":"2026-07-18T08:19:45.363Z","title":"","workDir":"/tmp/proj"}"#,
        );
        write_file(
            &session_dir.join("agents").join("main").join("wire.jsonl"),
            r#"{"type":"turn.prompt","input":[{"type":"text","text":"把构建脚本迁移到 pnpm"}],"origin":{"kind":"user"},"time":1784359474365}
"#,
        );

        let adapter = KimiCodeAdapter::with_home_dir(home);
        let conv = adapter
            .read_conversation("session_test-003")
            .expect("read conversation");
        assert_eq!(conv.summary.as_deref(), Some("把构建脚本迁移到 pnpm"));
    }
}
