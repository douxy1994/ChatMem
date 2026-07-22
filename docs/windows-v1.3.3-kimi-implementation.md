# Windows Development Guide: ChatMem v1.3.3 Kimi Code Integration

This guide describes the Windows parity work for ChatMem v1.3.3. The goal is to add Kimi Code CLI as a new Agent integration target and as a new local-history source, matching the macOS v1.3.3 behavior.

## Product Rule

Kimi Code is an additional target. Do not rename, remove, or merge any existing agent (Claude, Codex, Gemini, Google Antigravity, OpenCode, Hermes, ZCode).

The Settings -> Agent integration list shows all installable targets. The main conversation source selector is different: it must show Kimi Code only when readable Kimi Code session data exists on the current machine.

## Required Backend Changes

Update the Agent integration model in `src-tauri/src/agent_integration.rs`.

Add enum variant:

```rust
KimiCode
```

The final `IntegrationAgent::all()` order should be:

```rust
Claude
Codex
Gemini
Antigravity
OpenCode
Hermes
ZCode
KimiCode
```

Use these key and label values:

```text
key: kimi
label: Kimi Code
```

## Windows Paths

Use `%USERPROFILE%` as the home directory base. When the `KIMI_CODE_HOME` environment variable is set, all Kimi Code data moves to that directory instead.

Kimi Code integration paths:

```text
%USERPROFILE%\.kimi-code\mcp.json
%USERPROFILE%\.kimi-code\skills\chatmem\SKILL.md
%USERPROFILE%\.kimi-code\AGENTS.md
```

Kimi Code local history lives under:

```text
%USERPROFILE%\.kimi-code\sessions\<workDirKey>\<sessionId>\state.json
%USERPROFILE%\.kimi-code\sessions\<workDirKey>\<sessionId>\agents\main\wire.jsonl
%USERPROFILE%\.kimi-code\sessions\<workDirKey>\<sessionId>\agents\agent-N\wire.jsonl
```

`workDirKey` is a bucket name derived from the working directory (`wd_<slug>_<first-12-chars-of-sha256>`), so resolving a session by id requires scanning the workspace buckets. `%USERPROFILE%\.kimi-code\session_index.jsonl` (one record per line with `sessionId`, `sessionDir`, `workDir`) can be used as a supplementary index but must not be the only lookup path.

## MCP Config Shape

Write ChatMem under `mcpServers.chatmem` in `mcp.json`, matching the stdio JSON shape documented by Kimi Code:

```json
{
  "mcpServers": {
    "chatmem": {
      "command": "C:\\Program Files\\ChatMem\\ChatMem.exe",
      "args": ["--mcp"],
      "startupTimeoutMs": 30000
    }
  }
}
```

The command path must point to the installed ChatMem executable, not a developer checkout. Preserve every unrelated key in `mcp.json`, including other entries under `mcpServers`.

## Skill And Rules

Write the full ChatMem skill to:

```text
%USERPROFILE%\.kimi-code\skills\chatmem\SKILL.md
```

Write the managed ChatMem startup block to:

```text
%USERPROFILE%\.kimi-code\AGENTS.md
```

Use the same managed block markers as other integrations:

```text
<!-- CHATMEM-INTEGRATION:START -->
...
<!-- CHATMEM-INTEGRATION:END -->
```

The operation must be idempotent. Reinstalling should replace only the managed block and should not duplicate rules.

## Install Behavior

`install_agent_integration("kimi")` must:

1. Create parent directories when missing.
2. Preserve existing JSON keys in `mcp.json`.
3. Insert or replace only `mcpServers.chatmem`.
4. Install `skills/chatmem/SKILL.md`.
5. Upsert the managed block in `AGENTS.md`.
6. Return status `ready` when both MCP and guidance are installed.

`install_agent_integration("all")` must include Kimi Code.

## Uninstall Behavior

`uninstall_agent_integration("kimi")` must:

1. Remove only `mcpServers.chatmem` from `mcp.json`.
2. Delete only the `skills/chatmem` directory.
3. Remove only the managed block from `AGENTS.md`.
4. Preserve unrelated Kimi Code MCP servers, skills, settings, and rules.
5. Leave local ChatMem memory/history databases untouched.

## UI Requirements

The Settings -> Agent integration list is driven by native status results. Once the Rust/native layer returns the new status, the frontend shows a new card automatically.

Expected card text:

```text
Kimi Code
Config: %USERPROFILE%\.kimi-code\mcp.json
Guidance entry: %USERPROFILE%\.kimi-code\skills\chatmem\SKILL.md
```

Suggested details:

```text
Kimi Code 需要同时安装 ChatMem skill 和全局 AGENTS.md 规则；缺任一项都可能不会自动触发。
Install or repair, then restart the target agent.
```

The main source selector must be driven by runtime availability:

1. Native layer returns status for supported sources: Claude, Codex, Gemini, Antigravity, OpenCode, ZCode, Hermes, Kimi Code.
2. Frontend filters to `available == true`.
3. Show `Kimi Code` only when `%USERPROFILE%\.kimi-code\sessions` (or `%KIMI_CODE_HOME%\sessions`) contains a parsed conversation with at least one real user message. Ignore bootstrap sessions that contain only `metadata`, `config.update`, or `tools.set_active_tools` events.
4. Settings -> Agent integration can still show Kimi Code as installable even when the main source selector hides it.

## Kimi Code Local History Adapter

Add the Kimi Code adapter (crate `agentswap-kimi`, type `KimiCodeAdapter`, `AgentKind::KimiCode`) so it reads sessions from:

```text
%USERPROFILE%\.kimi-code\sessions\<workDirKey>\<sessionId>\
```

Parsing requirements:

1. Read `state.json` for `title`, `workDir` (project root), `createdAt`, and `updatedAt`.
2. Read `agents/main/wire.jsonl` and every `agents/agent-N/wire.jsonl`; each line is a JSON event.
3. Map events:
   - `turn.prompt` -> user message; join `input[]` text parts. This is the canonical user input; do not duplicate `context.append_message` user-role events.
   - `context.append_loop_event` with `event.type == "content.part"` and `part.type == "text"` -> assistant text.
   - `content.part` with `part.type == "think"` -> thinking; keep it in message metadata, not visible content.
   - `tool.call` -> tool call with `name` and `args`; group into the assistant message for its `(turnId, step)`.
   - `tool.result` -> fill `output` and error status onto the tool call with the matching `toolCallId`.
4. Merge main and sub-agent messages into one timeline ordered by event time; tag sub-agent messages with `kimi_agent` metadata.
5. Recover `project_dir` from `state.json`'s `workDir` first; fall back to tool-call args such as `cwd`, `workdir`, or `projectpath`; never use the session storage directory as `project_dir` unless nothing better exists.
6. Recover file changes from absolute paths in tool-call args such as `path`, `file_path`, or `absolutepath`.
7. Title: prefer the non-empty `state.json` `title`, otherwise the first real user prompt.
8. The adapter is read-only: `write_conversation` must bail with a clear error, matching the Antigravity precedent.
9. Resume command: `kimi --session <sessionId>`.

## Tests

Add a Windows-equivalent backend test that covers:

1. `selected_agents("kimi")` succeeds.
2. Installing creates `mcp.json`, `skills\chatmem\SKILL.md`, and `AGENTS.md`.
3. The JSON contains `mcpServers.chatmem.command`, `args`, and `startupTimeoutMs`.
4. `instructions_installed` and `mcp_installed` return true.
5. Uninstall removes only ChatMem entries and leaves unrelated config intact.

Add a Kimi Code local-history parser test that creates:

```text
<temp>\sessions\wd_proj_0123456789ab\session_test-001\state.json
<temp>\sessions\wd_proj_0123456789ab\session_test-001\agents\main\wire.jsonl
```

The fixture should include:

- one `turn.prompt` event with the user request text
- one `content.part` `think` event and one `content.part` `text` event
- one `tool.call` with `args.path` pointing at an absolute file path
- one `tool.result` with the matching `toolCallId`

Expected result:

- source agent is Kimi Code
- first user message is the clean request text
- `project_dir` equals the `state.json` `workDir` value
- the tool call output is backfilled from `tool.result`
- `file_changes[0].path` equals the absolute file path

Also cover a bootstrap-only session with no `turn.prompt` event. It must not make the Kimi Code source available and must not appear in `list_conversations()`.

Run at minimum:

```powershell
cargo test --manifest-path .\crates\agentswap-kimi\Cargo.toml
cargo test --manifest-path .\src-tauri\Cargo.toml --bin chatmem installs_kimi_code_with_mcp_skill_and_agents_md
cargo test --manifest-path .\src-tauri\Cargo.toml --bin chatmem
npm run test:run -- src/__tests__/App.test.tsx src/__tests__/SyncSettings.test.tsx
npm run build
```

## Manual Smoke Test

1. Install the Windows build.
2. Open Settings -> Agent integration.
3. Confirm `Kimi Code` is visible alongside the existing agents.
4. Click install/repair on `Kimi Code`.
5. Confirm files exist under `%USERPROFILE%\.kimi-code\` (`mcp.json`, `skills\chatmem\SKILL.md`, `AGENTS.md`).
6. Confirm Kimi Code sessions exist under `%USERPROFILE%\.kimi-code\sessions\<wd>\<session>\`.
7. Open the main source selector.
8. Confirm unavailable agents are hidden and `Kimi Code` appears when Kimi Code history exists.
9. Start `kimi` and ask a recall-style question for a repository.
10. Confirm the agent can discover ChatMem guidance and can call the ChatMem MCP server after restart.

Windows parity is complete when Kimi Code can be installed, repaired, uninstalled, reinstalled, and read from local history without changing any other agent's files.
