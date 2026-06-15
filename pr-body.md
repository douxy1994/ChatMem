## Problem

1. **OneDrive sync error 123**: ZCode adapter generates conversation IDs with colons (e.g. `claude:task:xxx:yyy`). Windows forbids colons in filenames, causing `ERROR_INVALID_NAME (os error 123)` during bidirectional sync.

2. **No system tray**: Closing the window quits the app entirely. No way to keep it running in background.

## Fix

### Sync error 123

Added `id_to_filename()` / `filename_to_id()` in `local_sync.rs`:
- Encodes Windows-forbidden characters as HTML entities when writing to sync folder (`:` → `&#x3a;`, etc.)
- Decodes back when reading, maintaining cross-platform compatibility
- Already existing files with `&#x3a;` encoding are correctly decoded

### System tray

- Close button now **minimizes to system tray** instead of quitting (all platforms)
- Tray right-click menu: **打开主界面** (Ctrl+Shift+M), **同步**, **退出**
- Single click on tray icon restores the window
- Added `system-tray` feature to tauri dependency
- Added `systemTray` config in `tauri.conf.json`

### Hermes Windows paths (included from prior PR #12)

- `adapter.rs`: prefer `AppData/Local/hermes/state.db` over `~/.hermes/state.db`
- `agent_integration.rs`: same for `config.yaml` and `SKILL.md` paths

## Testing

- `cargo check` passes on Windows x86_64-pc-windows-msvc
- `npx tauri build --target x86_64-pc-windows-msvc` produces all bundles
- Sync folder with ZCode conversations (containing colons in IDs) no longer errors
- System tray appears in Windows notification area with correct menu
