# ChatMem v1.1.3 macOS 端同步适配指南

## 背景

Windows 端已完成以下修改，使 macOS 端的对话能通过 OneDrive 同步到 Windows 并在 ChatMem 中显示。macOS 端需要做对等修改，才能读取到 Windows 端的对话。

## 需要修改的 4 个部分

### 1. 文件名编码（`src-tauri/src/local_sync.rs`）

**问题**：ZCode 的 `encode_zcode_cli_id()` 生成含冒号的 ID（如 `claude:task:xxx:yyy`）。macOS 允许冒号作为文件名，但 Windows 不允许。

**方案**：读写同步文件夹时，统一使用 HTML 实体编码。

添加两个函数（已有函数的地方直接替换）：

```rust
/// 将对话 ID 编码为安全文件名
pub fn id_to_filename(id: &str) -> String {
    let mut out = String::with_capacity(id.len());
    for ch in id.chars() {
        match ch {
            ':' => out.push_str("&#x3a;"),
            '<' => out.push_str("&#x3c;"),
            '>' => out.push_str("&#x3e;"),
            '"' => out.push_str("&#x22;"),
            '|' => out.push_str("&#x7c;"),
            '?' => out.push_str("&#x3f;"),
            '*' => out.push_str("&#x2a;"),
            '/' => out.push_str("&#x2f;"),
            '\\' => out.push_str("&#x5c;"),
            _ => out.push(ch),
        }
    }
    out
}

/// 将安全文件名解码为原始对话 ID
pub fn filename_to_id(name: &str) -> String {
    name.replace("&#x3a;", ":")
        .replace("&#x3c;", "<")
        .replace("&#x3e;", ">")
        .replace("&#x22;", "\"")
        .replace("&#x7c;", "|")
        .replace("&#x3f;", "?")
        .replace("&#x2a;", "*")
        .replace("&#x2f;", "/")
        .replace("&#x5c;", "\\")
}
```

**调用位置**（共 3 处）：

#### 写入时（`bidirectional_sync` 函数，2 处 `fs::write`）

原来的：
```rust
let file_path = conversations_dir.join(agent).join(format!("{id}.json"));
fs::write(&file_path, local_body)?;
```

改为：
```rust
let safe_name = id_to_filename(id);
let file_path = conversations_dir.join(agent).join(format!("{safe_name}.json"));
fs::write(&file_path, local_body)?;
```

#### 读取时（`read_remote_conversations` 函数）

原来的：
```rust
let file_name = path.file_stem().map(|n| n.to_string_lossy().to_string()).unwrap_or_default();
if file_name.is_empty() { continue; }
// ... 使用 file_name 作为 key
remote.insert((agent.to_string(), file_name), (updated_at, body));
```

改为：
```rust
let file_name = path.file_stem().map(|n| n.to_string_lossy().to_string()).unwrap_or_default();
if file_name.is_empty() { continue; }
let id = filename_to_id(&file_name);  // 解码回原始 ID
// ... 使用 id 作为 key
remote.insert((agent.to_string(), id), (updated_at, body));
```

同时把 `read_remote_conversations` 的可见性改为 `pub`。

---

### 2. 同步时导入远程对话到记忆库（`src-tauri/src/main.rs`）

**问题**：`sync_local_now` 只上传本地对话到同步文件夹，但不把远程对话导入到 ChatMem 记忆库。

**方案**：同步完成后，读取远程对话并写入记忆库。

在 `sync_local_now` 函数末尾，`bidirectional_sync` 返回后添加：

```rust
let result = local_sync::bidirectional_sync(&items, &path).map_err(|e| e.to_string())?;

// 导入远程对话到记忆库
if result.downloaded > 0 {
    if let Ok(store) = open_memory_store() {
        let remote = local_sync::read_remote_conversations(&path);
        let mut local_ids: std::collections::HashSet<(String, String)> = std::collections::HashSet::new();
        for item in &items {
            local_ids.insert((item.agent.clone(), item.id.clone()));
        }
        for ((agent, id), (_updated_at, body)) in &remote {
            if local_ids.contains(&(agent.clone(), id.clone())) {
                continue;  // 跳过本地已有的
            }
            match serde_json::from_slice::<Conversation>(body) {
                Ok(conversation) => {
                    if let Err(e) = sync_conversation_into_store(&store, agent, &conversation) {
                        eprintln!("Warning: failed to import synced {agent}/{id}: {e}");
                    }
                }
                Err(e) => {
                    eprintln!("Warning: failed to deserialize synced {agent}/{id}: {e}");
                }
            }
        }
    }
}

Ok(result)
```

---

### 3. 来源视图显示同步的对话（`src-tauri/src/main.rs`）

**问题**：`list_conversations` 只从适配器读取，同步过来的对话（在记忆库中）不在来源视图中显示。

**方案**：合并适配器结果 + 记忆库结果。

#### 3a. 在 MemoryStore 中添加查询方法（`src-tauri/src/chatmem_memory/store.rs`）

```rust
pub fn list_store_conversations(
    &self,
    source_agent: &str,
) -> Result<Vec<(String, String, Option<String>, String, String, usize)>> {
    let conn = self.conn()?;
    let mut stmt = conn.prepare(
        "SELECT c.source_conversation_id, r.repo_root, c.summary, c.started_at, c.updated_at,
                (SELECT COUNT(*) FROM messages m WHERE m.conversation_id = c.conversation_id) as msg_count
         FROM conversations c
         JOIN repos r ON c.repo_id = r.repo_id
         WHERE c.source_agent = ?1
         ORDER BY c.updated_at DESC",
    )?;
    let rows = stmt
        .query_map([source_agent], |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, Option<String>>(2)?,
                row.get::<_, String>(3)?,
                row.get::<_, String>(4)?,
                row.get::<_, usize>(5)?,
            ))
        })?
        .filter_map(|r| r.ok())
        .collect();
    Ok(rows)
}
```

#### 3b. 修改 `list_conversations`（`src-tauri/src/main.rs`）

```rust
async fn list_conversations(agent: String) -> Result<Vec<ConversationSummaryResponse>, String> {
    let adapter = get_adapter(&agent)?;

    let mut seen_ids: std::collections::HashSet<String> = std::collections::HashSet::new();
    let mut results: Vec<ConversationSummaryResponse> = Vec::new();

    // 适配器（本地原生存储）
    if adapter.is_available() {
        if let Ok(conversations) = adapter.list_conversations() {
            for summary in conversations {
                seen_ids.insert(summary.id.clone());
                results.push(convert_summary(summary));
            }
        }
    }

    // 记忆库（从其他机器同步过来的）
    if let Ok(store) = open_memory_store() {
        if let Ok(store_convs) = store.list_store_conversations(&agent) {
            for (source_id, repo_root, summary, started_at, updated_at, msg_count) in store_convs {
                if seen_ids.contains(&source_id) {
                    continue;
                }
                seen_ids.insert(source_id.clone());
                results.push(ConversationSummaryResponse {
                    id: source_id,
                    source_agent: agent.clone(),
                    project_dir: repo_root,
                    created_at: started_at,
                    updated_at,
                    summary,
                    message_count: msg_count,
                    file_count: 0,
                });
            }
        }
    }

    Ok(results)
}
```

---

### 4. 读取同步的对话详情（`src-tauri/src/main.rs`）

**问题**：`read_conversation` 只从适配器读取，点击同步的对话会报错。

**方案**：适配器失败时，从同步文件夹读取原始 JSON。

```rust
async fn read_conversation(agent: String, id: String) -> Result<ConversationResponse, String> {
    let adapter = get_adapter(&agent)?;

    // 先试适配器
    let conversation = match adapter.read_conversation(&id) {
        Ok(mut conv) => {
            conv.project_dir = normalize_project_dir(&conv.project_dir);
            conv
        }
        Err(_) => {
            // 适配器没有 → 从同步文件夹读取
            let settings = read_app_settings_from_disk()?;
            let sync_folder = settings
                .as_ref()
                .map(|s| s.sync.sync_folder.clone())
                .unwrap_or_default();
            if sync_folder.is_empty() {
                return Err(format!("Conversation {id} not found"));
            }
            let safe_name = local_sync::id_to_filename(&id);
            let file_path = std::path::PathBuf::from(&sync_folder)
                .join("conversations")
                .join(&agent)
                .join(format!("{safe_name}.json"));
            if !file_path.exists() {
                return Err(format!("Conversation {id} not found"));
            }
            let body = std::fs::read(&file_path)
                .map_err(|e| format!("Failed to read synced conversation: {e}"))?;
            serde_json::from_slice::<Conversation>(&body)
                .map_err(|e| format!("Failed to parse synced conversation: {e}"))?
        }
    };

    let storage_path = resolve_storage_path(&agent, &id);
    let resume_command = build_resume_command(&agent, &id);
    if let Ok(store) = MemoryStore::open_app() {
        let _ = sync_conversation_into_store(&store, &agent, &conversation);
    }
    Ok(convert_conversation(conversation, storage_path, resume_command))
}
```

---

## 验证步骤

1. 安装修改后的 macOS 版本
2. 打开 ChatMem，确保 OneDrive 同步文件夹已配置
3. 点击「同步」
4. 切换到任意来源（Claude / Codex / Hermes / ZCode）
5. 检查是否出现 Windows 路径（如 `C:/Users/xxx`）的项目
6. 点击进入项目，确认能正常查看对话内容

## 注意事项

- 两个平台必须使用**完全相同**的 `id_to_filename` / `filename_to_id` 实现
- 已有的原始冒号文件名（macOS 之前写入的）仍可正常读取，`filename_to_id` 不会改变不含编码的字符串
- 首次同步后，macOS 端的旧冒号文件名会被新的 `&#x3a;` 编码文件名覆盖（时间戳更新的一方胜出）
