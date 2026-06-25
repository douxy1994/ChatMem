# Windows Development Guide: ChatMem v1.3.2 Google Antigravity Integration

This guide describes the Windows parity work for ChatMem v1.3.2. The goal is to add Google Antigravity CLI as a new Agent integration target while keeping Gemini CLI available.

## Product Rule

Do not rename or remove Gemini CLI in ChatMem. Google Antigravity CLI is a successor path for consumer Gemini CLI users, but Gemini CLI can still coexist for enterprise and API Key setups. The UI must therefore show both:

- `Gemini`
- `Google Antigravity`

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

## Tests

Add a Windows-equivalent backend test that covers:

1. `selected_agents("antigravity")` succeeds.
2. Installing creates `mcp_config.json`, `skills\chatmem\SKILL.md`, and `AGENTS.md`.
3. The JSON contains `mcpServers.chatmem.command`, `args`, `timeout`, and `trust`.
4. `instructions_installed` and `mcp_installed` return true.
5. Uninstall removes only ChatMem entries and leaves unrelated config intact.

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
6. Start `agy` and ask a recall-style question for a repository.
7. Confirm the agent can discover ChatMem guidance and can call the ChatMem MCP server after restart.

Windows parity is complete when Antigravity can be installed, repaired, uninstalled, and reinstalled without changing Gemini CLI files.
