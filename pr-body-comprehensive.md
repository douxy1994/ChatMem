## Windows x64 端完整升级 — ChatMem v1.1.3

本 PR 包含 Windows 端的所有修改，对应 macOS 端 v1.1.3 的功能对等实现。

### 修改概览

| 类别 | 修改 | 文件 |
|------|------|------|
| 构建修复 | macOS 专用依赖改为平台条件依赖 | `src-tauri/Cargo.toml` |
| 同步修复 | 文件名编码（冒号→`&#x3a;`） | `src-tauri/src/local_sync.rs` |
| 同步增强 | 远程对话自动导入记忆库 | `src-tauri/src/main.rs` |
| 来源视图 | 合并适配器+记忆库数据 | `src-tauri/src/main.rs`, `store.rs` |
| 对话读取 | 适配器失败时从同步文件夹读取 | `src-tauri/src/main.rs` |
| Hermes 路径 | Windows 使用 AppData/Local/hermes/ | `agent_integration.rs`, `adapter.rs` |
| 系统托盘 | 关闭→最小化到托盘，右键菜单 | `src-tauri/src/main.rs`, `tauri.conf.json` |
| 机器分组 | 自动检测平台、合并/移动/重命名 | `src/App.tsx`, `styles.css`, `storage.ts` |
| UI 修复 | action bar 浅色主题样式 | `src/styles.css`, `src/App.tsx` |

### 详细说明

#### 1. 构建修复（`src-tauri/Cargo.toml`）
```toml
# 原来：cocoa/objc 是无条件依赖，Windows 编译失败
# 修复：
[target.'cfg(target_os = "macos")'.dependencies]
cocoa = "0.24"
objc = "0.2"
```

#### 2. 同步 error 123 修复（`src-tauri/src/local_sync.rs`）
ZCode 的 `encode_zcode_cli_id()` 生成含冒号的 ID，Windows 禁止冒号作文件名。添加 `id_to_filename()` / `filename_to_id()` 编码/解码函数。

#### 3. 同步自动导入（`src-tauri/src/main.rs` — `sync_local_now`）
同步完成后，读取远程对话并写入 ChatMem 记忆库。

#### 4. 来源视图增强（`src-tauri/src/main.rs` — `list_conversations`）
合并本地适配器结果 + 记忆库结果，去重后返回。

#### 5. 对话读取回退（`src-tauri/src/main.rs` — `read_conversation`）
适配器读不到时，从 OneDrive 同步文件夹读取原始 JSON。

#### 6. Hermes Windows 路径（`agent_integration.rs`, `adapter.rs`）
config.yaml / state.db / SKILL.md 优先使用 `dirs::data_local_dir()/hermes/`，回退 `~/.hermes/`。

#### 7. 系统托盘（`src-tauri/src/main.rs`, `tauri.conf.json`）
- 添加 `system-tray` feature
- 关闭按钮→隐藏窗口（所有平台）
- 托盘菜单：打开主界面 / 同步 / 退出

#### 8. 机器分组（`src/App.tsx`）
- `detectMachineId()`：按平台检测（不按用户名拆分）
- 多台电脑时显示分组层，单台不显示
- 双击重命名，支持合并/移动对话

#### 9. 跨平台文件名编码规范
见 `docs/cross-platform-filename-encoding.md` — macOS 端需做对等修改。

#### 10. macOS 适配指南
见 `docs/macos-sync-adaptation-guide.md` — 包含所有需要 macOS 端对等修改的代码。
