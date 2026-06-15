## ChatMem v1.1.3

### macOS 26 (Tahoe) 兼容修复
- 修复窗口完全卡死，改用原生窗口装饰
- 关闭按钮隐藏窗口，dock 右键退出
- dock 点击重新显示窗口（class_addMethod，不覆盖 Tauri delegate）

### OneDrive 双向同步
- 支持任意同步目录（OneDrive / Google Drive / Dropbox）
- 双向合并：按 updated_at 时间戳自动判断上传/下载
- 云端同步状态检测，定时自动备份（5/15/30/60/120 分钟可选）
- **修复 Windows error 123**：ZCode 对话 ID 含冒号，Windows 不允许冒号作文件名。写入时编码为 `&#x3a;`，读取时解码还原
- **同步自动导入**：远程对话同步后自动写入 ChatMem 记忆库，切换来源即可查看
- **跨平台文件名编码规范**：见 `docs/cross-platform-filename-encoding.md`

### 系统托盘（Windows）
- 关闭按钮最小化到系统托盘，不退出
- 托盘右键菜单：打开主界面 / 同步 / 退出
- 单击托盘图标恢复窗口

### Hermes Agent 支持
- 新增适配器，读取 `~/.hermes/state.db`（Windows: `AppData/Local/hermes/state.db`）
- 设置 → Agent 集成一键安装/卸载 MCP
- **修复 Windows 路径**：config.yaml / state.db / SKILL.md 优先使用 `AppData/Local/hermes/`
- **修复工具调用显示 unknown**：正确解析 OpenAI 格式（function.name/arguments）

### 设置持久化
- syncFolder、autoBackupEnabled 等保存到 settings.json
- 重新安装后自动恢复

### 机器分组
- 自动检测对话来源机器（Windows / Mac / Linux）
- 多台电脑时显示机器分组层，单台时不显示
- 双击分组名称可自定义重命名
- 支持合并电脑分组、移动对话到其他分组
- 管理分组模式：勾选分组 → 合并到 / 勾选对话 → 移动到

### 对话来源视图增强
- `list_conversations` 合并本地适配器 + 记忆库数据，同步的对话在来源视图中可见
- `read_conversation` 适配器失败时自动从同步文件夹读取

### UI 改进
- 侧边栏滚动条始终可见，展开/折叠不影响宽度
- 项目文件夹箭头对齐，名称深绿色
- 机器分组 action bar 使用浅色主题样式

### 统一 Skill 管理
- Skill 统一存放，Claude/Codex/Hermes 软链接共享
- 移除 Gemini CLI 和 OpenCode

### 跨平台构建修复
- macOS 专用依赖（cocoa/objc）改为 `[target.'cfg(target_os = "macos")'.dependencies]`
- Windows x64 构建通过 CI 或本地 `npx tauri build --target x86_64-pc-windows-msvc`

---

**Windows 推荐下载**：`ChatMem_1.1.3_x64-setup.exe`
**macOS Apple Silicon**：`ChatMem-v1.1.3-macOS-Apple-Silicon.dmg`
