# Windows Development Guide: ChatMem v1.3.2 Google Antigravity Integration

This guide describes the Windows parity work for ChatMem v1.3.2. The goal is to add Google Antigravity CLI as a new Agent integration target while keeping Gemini CLI available.

## Product Rule

Do not rename or remove Gemini CLI in ChatMem. Google Antigravity CLI is a successor path for consumer Gemini CLI users, but Gemini CLI can still coexist for enterprise and API Key setups. The UI must therefore show both:

- `Gemini`
- `Google Antigravity`

This rule applies to Settings -> Agent integration. The main conversation source selector is different: it must show only agents that are actually installed or have readable local history on the current machine.

## Required Backend Changes

Update the Agent integration model in `src-tauri/src/agent_integration.rs`.

Add enum variant:

```rust
Antigravity
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
```

Use these key and label values:

```text
key: antigravity
label: Google Antigravity
```

## Windows Paths

Use `%USERPROFILE%` as the home directory base.

Gemini CLI remains:

```text
%USERPROFILE%\.gemini\settings.json
%USERPROFILE%\.gemini\GEMINI.md
```

Google Antigravity CLI uses:

```text
%USERPROFILE%\.gemini\antigravity-cli\mcp_config.json
%USERPROFILE%\.gemini\antigravity-cli\skills\chatmem\SKILL.md
%USERPROFILE%\.gemini\antigravity-cli\AGENTS.md
```

Do not write Antigravity MCP settings into `%USERPROFILE%\.gemini\settings.json`.

Google Antigravity local history uses a different directory:

```text
%USERPROFILE%\.gemini\antigravity\brain\<session-id>\.system_generated\logs\transcript.jsonl
```

Do not read local history from `%USERPROFILE%\.gemini\antigravity-cli\`.

## MCP Config Shape

Write ChatMem under `mcpServers.chatmem`, matching the Gemini-compatible JSON payload already used by ChatMem:

```json
{
  "mcpServers": {
    "chatmem": {
      "command": "C:\\Program Files\\ChatMem\\ChatMem.exe",
      "args": ["--mcp"],
      "timeout": 30000,
      "trust": true
    }
  }
}
```

The command path must point to the installed ChatMem executable, not a developer checkout.

## Skill And Rules

Write the full ChatMem skill to:

```text
%USERPROFILE%\.gemini\antigravity-cli\skills\chatmem\SKILL.md
```

Write the managed ChatMem startup block to:

```text
%USERPROFILE%\.gemini\antigravity-cli\AGENTS.md
```

Use the same managed block markers as other integrations:

```text
<!-- CHATMEM-INTEGRATION:START -->
...
<!-- CHATMEM-INTEGRATION:END -->
```

The operation must be idempotent. Reinstalling should replace only the managed block and should not duplicate rules.

## Install Behavior

`install_agent_integration("antigravity")` must:

1. Create parent directories when missing.
2. Preserve existing JSON keys in `mcp_config.json`.
3. Insert or replace only `mcpServers.chatmem`.
4. Install `skills/chatmem/SKILL.md`.
5. Upsert the managed block in `AGENTS.md`.
6. Return status `ready` when both MCP and guidance are installed.

`install_agent_integration("all")` must include Antigravity in addition to Gemini.

## Uninstall Behavior

`uninstall_agent_integration("antigravity")` must:

1. Remove only `mcpServers.chatmem` from `mcp_config.json`.
2. Delete only the `skills/chatmem` directory.
3. Remove only the managed block from `AGENTS.md`.
4. Preserve unrelated Antigravity MCP servers, skills, settings, and rules.
5. Leave local ChatMem memory/history databases untouched.

## UI Requirements

The Settings -> Agent integration list is driven by native status results. Once the Rust/native layer returns the new status, the frontend should show a new card automatically.

Expected card text:

```text
Google Antigravity
Config: %USERPROFILE%\.gemini\antigravity-cli\mcp_config.json
Guidance entry: %USERPROFILE%\.gemini\antigravity-cli\skills\chatmem\SKILL.md
```

Suggested details:

```text
Antigravity CLI uses a separate mcp_config.json and global skills directory; Gemini CLI remains available separately.
Install or repair, then restart the target agent.
```

The main source selector must be driven by runtime availability:

1. Native layer returns status for supported sources: Claude, Codex, Gemini, Antigravity, OpenCode, ZCode, Hermes.
2. Frontend filters to `available == true`.
3. If Gemini CLI is not installed, do not show `Gemini` in the main source selector.
4. If `%USERPROFILE%\.gemini\antigravity\brain` exists and contains readable transcript data, show `Antigravity`.
5. Settings -> Agent integration can still show installable integrations even when the main source selector hides them.

Suggested native command:

```rust
#[tauri::command]
async fn detect_conversation_sources() -> Result<Vec<ConversationSourceStatus>, String>
```

Each source should call the matching adapter's `is_available()`.

## Antigravity Local History Adapter

Add or update the Antigravity adapter so it reads JSONL transcripts from:

```text
%USERPROFILE%\.gemini\antigravity\brain\<session-id>\.system_generated\logs\transcript.jsonl
```

Parsing requirements:

1. Each line is a JSON event.
2. Map `source` values:
   - `USER_EXPLICIT` / `USER` -> user message
   - `MODEL` -> assistant message
   - `SYSTEM` -> system message
3. For user content, extract only the text inside `<USER_REQUEST>...</USER_REQUEST>` when present.
4. Preserve `tool_calls` with their `name` and `args`.
5. Preserve `thinking`, event `type`, and `status` in message metadata.
6. Recover project root from tool call args such as `Cwd`, `WorkingDirectory`, `CurrentWorkingDirectory`, `ProjectPath`, or `ProjectDir`.
7. Recover file changes from args such as `AbsolutePath`, `FilePath`, `file_path`, or `Path`.
8. Do not use the brain session directory as `project_dir` unless no better project path exists.

## Tests

Add a Windows-equivalent backend test that covers:

1. `selected_agents("antigravity")` succeeds.
2. Installing creates `mcp_config.json`, `skills\chatmem\SKILL.md`, and `AGENTS.md`.
3. The JSON contains `mcpServers.chatmem.command`, `args`, `timeout`, and `trust`.
4. `instructions_installed` and `mcp_installed` return true.
5. Uninstall removes only ChatMem entries and leaves unrelated config intact.

Add an Antigravity local-history parser test that creates:

```text
<temp>\brain\session-001\.system_generated\logs\transcript.jsonl
```

The fixture should include:

- one `USER_EXPLICIT` event with `<USER_REQUEST>`
- one `MODEL` event with `tool_calls[0].args.Cwd`
- one file path in `tool_calls[0].args.AbsolutePath`

Expected result:

- source agent is Antigravity
- first user message is the clean request text
- `project_dir` equals the `Cwd` value
- `file_changes[0].path` equals the absolute file path

Run at minimum:

```powershell
cargo test --manifest-path .\src-tauri\Cargo.toml --bin chatmem installs_antigravity_cli_as_distinct_gemini_successor
cargo test --manifest-path .\src-tauri\Cargo.toml --bin chatmem
npm run test:run -- src/__tests__/App.test.tsx src/__tests__/SyncSettings.test.tsx
npm run build
```

## Manual Smoke Test

1. Install the Windows build.
2. Open Settings -> Agent integration.
3. Confirm both `Gemini` and `Google Antigravity` are visible.
4. Click install/repair on `Google Antigravity`.
5. Confirm files exist under `%USERPROFILE%\.gemini\antigravity-cli\`.
6. Confirm an Antigravity transcript exists under `%USERPROFILE%\.gemini\antigravity\brain\...\transcript.jsonl`.
7. Open the main source selector.
8. Confirm unavailable agents are hidden. For example, if Gemini CLI is not installed, `Gemini` should not appear.
9. Confirm `Antigravity` appears when Antigravity history exists.
10. Start `agy` and ask a recall-style question for a repository.
11. Confirm the agent can discover ChatMem guidance and can call the ChatMem MCP server after restart.

Windows parity is complete when Antigravity can be installed, repaired, uninstalled, reinstalled, and read from local history without changing Gemini CLI files.
