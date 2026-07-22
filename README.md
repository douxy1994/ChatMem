# ChatMem

## v1.3.5 Release Status

- The shared `v1.3.5` GitHub Release provides matching macOS and Windows packages with in-app update support.
- Native Kimi Code support includes MCP, skill, global guidance, and local-history reading on both platforms.
- Windows search covers native Agent history, synced snapshots, and the ChatMem memory store. Only the newest in-flight query may update the result list.
- Full release notes: [`docs/releases/v1.3.5.md`](./docs/releases/v1.3.5.md).

ChatMem 是一个本地优先的 AI 编程记忆与迁移层。它把 Claude、Codex、Gemini、OpenCode、ZCode、Hermes、Kimi Code 等本地对话历史整理成可搜索、可恢复、可迁移、可继续使用的项目上下文。

它不是另一个聊天客户端。ChatMem 解决的是 AI 编程里最容易断线的部分：换 agent、换窗口、换机器、隔几天回来，模型不知道之前发生过什么。ChatMem 会把本地对话作为证据层索引，再把稳定知识沉淀为启动规则、Wiki、checkpoint 和 handoff，并通过桌面端与 MCP 把这些上下文带回新的 agent 会话。

## 当前版本

最新版本：`v1.3.5`

### v1.3.5 重点更新

**双端更新与 Windows 对齐**
- macOS 与 Windows 安装包合并到同一个 Release；Windows 可直接下载并静默安装更高版本。
- Windows 端完整支持 Kimi Code MCP、skill、全局规则和本地会话读取；只有包含真实用户消息的会话才会显示为可用来源。
- Windows 搜索统一覆盖 Agent 原生会话、同步目录和 ChatMem 本地内存库，并避免快速输入时旧请求覆盖新结果。
- Windows 侧栏底部固定显示收藏夹、垃圾箱和设置三个入口，版本号独立放在右下角。

### v1.3.3 重点更新

**Kimi Code 原生集成**
- 设置 -> Agent 集成新增 `Kimi Code`，`一键安装到全部` 包含 Kimi Code。
- MCP 写入 `~/.kimi-code/mcp.json` 的 `mcpServers.chatmem`（stdio：`ChatMem --mcp`，`startupTimeoutMs: 30000`）。
- ChatMem skill 写入 `~/.kimi-code/skills/chatmem/SKILL.md`。
- 全局引导规则写入 `~/.kimi-code/AGENTS.md`（托管块，幂等覆盖）。
- 设置 `KIMI_CODE_HOME` 时所有路径跟随该变量；卸载只移除 ChatMem 写入的配置，不影响其他 MCP server、skill 和规则。

**Kimi Code 本地历史读取**
- 新增 `agentswap-kimi` adapter，读取 `~/.kimi-code/sessions/<workDirKey>/<sessionId>/` 下的 `state.json` 和 `agents/**/wire.jsonl`。
- 从 `turn.prompt` 提取真实用户输入，从 `content.part` 提取 assistant 正文和 thinking，tool result 按 `toolCallId` 精确回填。
- 主 agent 与子代理 wire 按时间戳合并为同一时间线；项目根目录取自 `state.json` 的 `workDir`。
- 首页来源、WebDAV 同步、本地文件夹同步和 `import_all_local_history` 全部包含 Kimi Code；adapter 只读，恢复命令为 `kimi --session <sessionId>`。

**开发文档**
- Release 说明见 `docs/releases/v1.3.3.md`。
- Windows 端同功能实现指南见 `docs/windows-v1.3.3-kimi-implementation.md`。

### v1.3.2 重点更新

**Google Antigravity CLI 集成**
- 设置 -> Agent 集成新增 `Google Antigravity`，与原 `Gemini` 保持并存。
- Antigravity CLI 使用独立配置：`~/.gemini/antigravity-cli/mcp_config.json`。
- ChatMem skill 写入：`~/.gemini/antigravity-cli/skills/chatmem/SKILL.md`。
- 全局引导规则写入：`~/.gemini/antigravity-cli/AGENTS.md`。
- 原 Gemini CLI 配置仍保留在 `~/.gemini/settings.json` 和 `~/.gemini/GEMINI.md`，用于企业授权或 API Key 仍需 Gemini CLI 的场景。

**Antigravity 本地历史读取**
- 新增 Antigravity 本地历史 adapter，读取真实 transcript：`~/.gemini/antigravity/brain/<session>/.system_generated/logs/transcript.jsonl`。
- 解析 `USER_REQUEST`、`Cwd`、`AbsolutePath`、tool calls、thinking metadata 和文件变化，项目根目录不再误显示为 Antigravity brain 目录。
- 主界面“来源”下拉改为运行时检测，只显示本机已安装且有可读数据目录的 agent。Gemini 和 Antigravity 可以并存；如果本机未安装 Gemini CLI，Gemini 不会出现在首页来源中。

**工作台同步入口**
- 工作台右上角“立即同步”按钮恢复 v1.3.0/v1.3.1 早期的循环箭头 icon 和禁用态旋转动画，不再使用云朵流光样式。

**开发文档**
- Release 说明见 `docs/releases/v1.3.2.md`。
- Windows 端同功能实现指南见 `docs/windows-v1.3.2-antigravity-implementation.md`。

### v1.3.1 重点更新

**WebDAV 同步修复**
- 修复 WebDAV 同步被本地历史中的陈旧 rollout 路径中断的问题：如果某条本地索引指向的源 transcript 已经不存在，同步会跳过该陈旧条目并继续上传其他可用对话。
- 修复工作台“立即同步”无法复用刚在设置页保存过的 WebDAV 密码的问题：设置页验证或同步后，当前应用会话会缓存该密码，工作台快捷同步可直接继续使用。
- 解析错误、损坏数据等非“文件缺失”问题仍会失败并提示，不会被静默吞掉。

**Windows 工作台体验**
- 工作台右上角同步按钮改为云同步图标，同步中会显示旋转和流动高光状态。
- Windows 顶部菜单栏移除 `View` 菜单，保留更精简的 ChatMem / File / Edit 菜单结构。

**发布**
- Windows x64 安装包已合并到 `v1.3.1` GitHub Release：推荐下载 `ChatMem_1.3.1_x64-setup.exe`，批量部署可使用 `ChatMem_1.3.1_x64_en-US.msi`。
- Release 说明见 `docs/releases/v1.3.1.md`。

### v1.3.0 重点更新

**工作台**
- 首页升级为“工作台”，把继续工作、项目时间线、收藏夹增强、智能搜索、项目记忆、发布检查、对话质量、隐私清理和跨平台状态集中到一页。
- 未选择对话时不再只显示空状态，而是直接给出最近任务、项目活动、推荐接续 agent、发布检查和清理候选。
- 工作台右上角新增“立即同步”入口，可直接执行当前已配置的 WebDAV 或 OneDrive/本地文件夹同步，不需要再进入设置页。

**收藏夹增强**
- 收藏项支持备注、标签和置顶。
- 收藏夹可复制“收藏继续卡片”，用于从重要对话快速接续。
- 收藏夹仍保存轻量快照，不复制完整对话内容。

**开发状态**
- 这一版先提供本地可用的功能骨架：所有卡片都由现有本地对话、收藏、记忆、handoff、Wiki 和 release 信息派生。
- 深度语义检索、自动记忆写入和清理执行仍保持审慎：先展示候选，不自动删除或自动写入长期规则。
- 当前发布继续使用稳定的 Tauri + Rust + React 主线，未发布的原生重写实验内容已移除。
- Release 说明见 `docs/releases/v1.3.0.md`。
- Windows 端同功能实现指南见 `docs/windows-v1.3.0-workbench-implementation.md`。

### v1.2.2 重点更新

**收藏夹**
- 对话列表新增星标按钮，可将重要对话加入收藏夹。
- 左侧底部新增“收藏夹”入口，收藏夹内容在右侧工作区显示，行为和垃圾箱一致，不替换左侧对话列表。
- 收藏夹保存轻量对话快照，不复制完整对话内容，也不改变原对话存储位置。
- 收藏夹保留原有项目路径、来源、更新时间和标题信息，方便后续快速接续。

**界面调整**
- 左侧底部移除“关于我们”入口，底部只保留“收藏夹 / 垃圾箱 / 设置”和版本号。
- 底部三个入口按钮恢复为和版本号同一行对齐，保持 v1.2.1 的底部高度。
- 底部入口按内容宽度分配，收藏数量不再挤压“收藏夹”文字。
- 设置页返回按钮移到左下角浮窗，复用首页收起边栏按钮的视觉样式。

**开发文档**
- Release 说明见 `docs/releases/v1.2.2.md`。
- Windows 端同功能实现指南见 `docs/windows-v1.2.2-favorites-implementation.md`。

### v1.2.1 重点更新

**继续卡片**
- `Migrate` 弹窗新增“总结式迁移”选项，用于复制 source-backed continuation brief；原完整对话迁移仍作为默认选项保留。
- 对话工具栏的继续按钮继续复制原有低 token 续接提示，不替代原功能。
- brief 会提取当前工作线、最新完成动作、权威文件、过期背景、证据来源和续接协议。
- 新增 continuation brief 回归评测：`npm run eval:continuation-brief`。
- 完整对话迁移继续用于归档、审计和兼容旧流程；总结式迁移用于跨 agent 快速接续。
- Release 说明见 `docs/releases/v1.2.1.md`。
- Windows 端同功能实现指南见 `docs/windows-summary-migration-implementation.md`。

---

### v1.2.0 重点更新

**删除对话功能增强**
- 新增确认对话框：删除前二次确认，提示"此操作将删除本机记录和 OneDrive 同步记录，删除后无法找回"
- 新增 `delete_memory_conversation` 命令：直接从记忆库 + 同步文件夹删除对话
- 前端 fallback：`trash_conversation` 失败时自动尝试 `delete_memory_conversation`
- `trash_conversation` 回退：适配器找不到对话时，从同步文件夹或记忆库读取

**列表显示修复**
- `list_conversations` 直接读取同步文件夹：在适配器 + 记忆库之后，额外从 OneDrive 同步文件夹读取对话列表
- 修复同步对话在来源视图中不可见的问题

**UI 改进**
- 标题栏居中：Logo + "ChatMem" 居中显示
- 版本号移到底部栏右下角
- 收起按钮浮动：从侧边栏内部移到外部，绝对定位在左下角
- 新图标：sidebar 收起图标（面板+箭头）、manage groups 图标（重叠矩形）

**ZCode 原生集成**
- Agent 集成中新增 ZCode 选项
- MCP 自动安装到 `~/.zcode/v2/config.json`
- Skill 通过 skills-manager 中央仓库软链接

---

### v1.1.3 重点更新

**macOS 26 (Tahoe) 兼容修复**
- 修复在 macOS 26 上窗口完全卡死无法操作的问题
- 改用原生窗口装饰（`decorations: true`），移除自定义透明窗口和拖拽区域
- 关闭按钮改为隐藏窗口（标准 macOS 行为），dock 栏右键退出才真正退出

**OneDrive 双向同步**
- 新增本地文件夹同步功能，支持 OneDrive、Google Drive、Dropbox 等任意同步目录
- 双向合并算法：按 `updated_at` 时间戳自动判断上传/下载/跳过
- 云端同步状态检测：自动识别 `.tmp`、`.partial`、`~$` 锁文件，避免与云盘客户端冲突
- 定时自动备份：可配置间隔（5/15/30/60/120 分钟），云盘忙碌时自动跳过
- 用户自选文件夹路径，通过系统原生文件夹选择器设置
- **修复 Windows error 123**：ZCode 对话 ID 含冒号，Windows 不允许冒号作文件名。写入时编码为 `&#x3a;`，读取时解码还原
- **同步自动导入**：远程对话同步后自动写入 ChatMem 记忆库，切换来源即可查看跨机器对话
- 跨平台文件名编码规范见 `docs/cross-platform-filename-encoding.md`

**系统托盘（Windows）/ Dock 行为优化（macOS）**
- 关闭按钮最小化到系统托盘（不退出应用）
- 托盘右键菜单：打开主界面 / 同步 / 退出
- 单击托盘图标恢复窗口

**Hermes Agent 支持**
- 新增 Hermes Agent 适配器，从 `~/.hermes/state.db` SQLite 数据库读取对话
- Windows 端使用 `AppData/Local/hermes/state.db`
- 设置 → Agent 集成中支持一键安装/卸载 Hermes MCP 配置和 Skill
- 修复工具调用显示 unknown：正确解析 OpenAI 格式（function.name/arguments）

**ZCode 原生集成**
- 新增 ZCode 集成支持，设置 → Agent 集成可管理
- MCP 自动安装到 `~/.zcode/v2/config.json`
- Skill 通过 skills-manager 中央仓库软链接到 `~/.zcode/skills/chatmem/`

**机器分组**
- 自动检测对话来源机器（Windows / Mac / Linux）
- 多台电脑时显示机器分组层，单台时不显示
- 双击分组名称可自定义重命名，保存到设置
- 支持合并电脑分组、移动对话到其他分组

**对话来源视图增强**
- 来源视图合并本地适配器 + 记忆库数据，同步的对话在来源视图中可见
- 点击同步的对话可正常查看详情，适配器失败时自动从同步文件夹读取

**统一 Skill 管理**
- ChatMem skill 统一存放在 `~/.skills-manager/skills/chatmem/`
- Claude、Codex、Hermes、ZCode 通过软链接/Junction 共享同一份 SKILL.md
- 从 Agent 列表中移除 Gemini CLI 和 OpenCode（不再需要）

**设置持久化**
- 同步文件夹路径、自动备份开关、备份间隔等设置保存到 settings.json
- Windows：`AppData/Roaming/ChatMem/settings.json`；macOS：`~/Library/Application Support/ChatMem/settings.json`
- 重新安装后无需重新配置，设置自动恢复

**跨平台构建修复**
- macOS 专用依赖（cocoa/objc）改为平台条件依赖，Windows 编译不再报错
- Windows x64 构建通过 `npx tauri build --target x86_64-pc-windows-msvc`

### v1.1.2 重点更新

- 新增 ZCode 顶层来源：ZCode 下按 CLI 分组，CLI 下再按项目分组，支持 ZCode 内的 Claude、Codex、Gemini、OpenCode 等会话结构。
- 对话标题更贴近任务内容：优先使用用户真实输入的任务文字，而不是原始 UUID、命令提示或工具调用字符串。
- 完整对话支持 Markdown 渲染：长回答、列表、代码块、链接会以更可读的方式显示。
- 工具调用历史更安静：多个工具调用默认折叠为小字号灰色信息层，让"用户说了什么、agent 回答了什么"成为阅读重点。
- 更适合长会话延续：继续卡片会提取当前工作线、最新完成动作、权威文件和过期背景，配合低 token 历史检索、对话证据窗口、checkpoint、handoff 和 Wiki 接续，而不是重新读取整段超长对话。
- UI 层级优化：来源选择、搜索、项目/对话列表、对话操作、关于页都按 Codex 桌面端方向重新梳理，并修复右侧对话区横向溢出。

## 下载

正式下载入口：

- [GitHub Releases](https://github.com/douxy1994/ChatMem/releases)

Windows 推荐下载：

- `ChatMem_<version>_x64-setup.exe`：普通用户推荐安装包。
- `ChatMem_<version>_x64_en-US.msi`：适合企业化或脚本化安装环境。
- `ChatMem-v<version>-portable.zip`：免安装便携版，如果发布页提供该文件。

macOS 推荐下载：

- `ChatMem-v<version>-macOS-Apple-Silicon.dmg`：M1 / M2 / M3 / M4 等 Apple Silicon Mac。
- `ChatMem-v<version>-macOS-Intel.dmg`：Intel Mac。

不知道自己的 Mac 属于哪一种时，点屏幕左上角苹果菜单，选择“关于本机”。如果显示“芯片 Apple M1/M2/M3/M4”，下载 Apple Silicon 版；如果显示“处理器 Intel”，下载 Intel 版。

当前 macOS 包暂未做 Apple Developer ID 签名和 notarization。首次打开时，系统可能需要你在“系统设置”中允许打开，或者通过右键菜单打开。

## 支持的本地历史来源

| 来源 | ChatMem 中的层级 | 说明 |
| --- | --- | --- |
| Claude | 来源 -> 项目 -> 对话 | 解析本机 Claude Code 项目对话和子代理任务。 |
| Codex | 来源 -> 项目/本地历史 -> 对话 | 解析 Codex CLI / Codex 桌面端 rollout 与会话历史。 |
| Gemini | 来源 -> 项目 -> 对话 | 解析 Gemini CLI 历史；仅在本机存在可读 Gemini 数据目录时显示。 |
| Google Antigravity | 来源 -> 项目 -> 对话 | 解析 `~/.gemini/antigravity/brain` 下的 Antigravity transcript；与 Gemini 并存。 |
| OpenCode | 来源 -> 项目 -> 对话 | 解析 OpenCode 本地会话；仅在本机存在可读数据目录时显示。 |
| Hermes | 来源 -> 项目 -> 对话 | 解析 Hermes Agent SQLite 数据库（`~/.hermes/state.db`）。 |
| ZCode | 来源 -> CLI -> 项目 -> 对话 | 解析 `~/.zcode/v2/acp-config`，把 ZCode 作为顶层来源，再按内部 CLI 分组。 |
| Kimi Code | 来源 -> 项目 -> 对话 | 解析 `~/.kimi-code/sessions` 下的 `state.json` 与 `wire.jsonl`（含子代理）；支持 `KIMI_CODE_HOME`；仅在本机存在可读会话时显示。 |

主界面的来源下拉只展示当前电脑已安装且可读取的来源；设置页的 Agent 集成仍会展示可安装/可修复的目标。

ZCode Windows 默认位置示例：

```text
C:\Users\<you>\.zcode\v2\acp-config\
```

## 核心能力

- 本地对话浏览、归类、全文搜索和标题清洗
- 对话详情、Markdown 正文、工具调用折叠、文件变更查看
- 一键复制会话文件位置与恢复命令
- Claude / Codex / Gemini / OpenCode / ZCode 之间的对话迁移
- 删除前确认、批量选择、垃圾箱保留与恢复
- 全量本地历史导入、当前项目扫描、路径别名修复
- 低 token 历史检索、对话证据读取、Wiki 投影、启动规则
- checkpoint、handoff、run、artifact 等继续工作记录
- 设置页一键安装 ChatMem MCP 与各平台原生引导入口
- WebDAV 可选备份与同步
- 简体中文 / English 切换
- 应用内检查更新

## 推荐工作流

1. 打开 ChatMem，选择左侧来源。
2. 对 ZCode，先选 CLI 分组，再进入项目和对话；其他来源直接按项目或本地历史浏览。
3. 在对话详情里重点阅读用户消息和 agent 回复，需要时再展开工具调用。
4. 对很长的旧会话，优先用本地历史检索、checkpoint 或 handoff 接续，不要让新窗口整段读取超长 transcript。
5. 在“设置 -> Agent 集成”里安装 ChatMem MCP，让 Claude Code、Codex、Gemini CLI、OpenCode 等 agent 能主动读取项目记忆。

可以在新线程里这样提示 agent：

```text
Use ChatMem to load repo memory for D:\your\repo, then continue from the latest checkpoint or handoff if one exists.
```

中文场景也可以直接说：

```text
请用 ChatMem 读取这个仓库的项目记忆，并从最近的检查点或交接包继续。
```

## ChatMem MCP

ChatMem 可以作为本地 MCP 记忆服务使用。桌面应用负责查看、搜索、迁移、审批和安装；MCP 负责让 agent 读取项目记忆、搜索历史、生成交接包。

MCP 能力包括：

- `get_project_context`：读取紧凑项目上下文、启动规则和相关历史。
- `search_repo_history`：低 token 搜索本地历史。
- `read_history_conversation`：按需读取对话证据窗口，而不是整段 transcript。
- `import_all_local_history`：导入 Claude、Codex、Gemini、OpenCode、ZCode 等本地历史。
- 记忆候选、冲突检查、规则合并、Wiki 重建、checkpoint、handoff 等工具。

推荐查看完整说明：

- [ChatMem MCP Setup](./docs/CHATMEM_MCP_SETUP.md)
- [ChatMem Architecture and Features](./docs/CHATMEM_ARCHITECTURE_AND_FEATURES.md)
- [ChatMem Product Strategy](./docs/CHATMEM_PRODUCT_STRATEGY.md)

## Agent 接入

推荐方式是在 ChatMem 桌面应用中打开“设置 -> Agent 集成”，点击“一键安装到全部”。ChatMem 会自动：

- 检测各类 agent 的用户级配置位置
- 写入 `chatmem` MCP server
- 安装 ChatMem skill 或平台等价的原生引导入口
- 在覆盖配置前生成 `.bak-YYYYMMDD-HHMMSS` 备份

安装后完全退出并重新打开对应 agent。ChatMem 通常不会出现在 `@chatmem` 这种对话提及列表里，它是 agent 后台可调用的 MCP 工具。

安装版优先使用 `ChatMem.exe --mcp` 启动 MCP，这样升级后不会依赖旧仓库路径。开发模式仍保留 `mcp/run-chatmem-mcp.ps1` 作为手动排障入口。

## 数据与隐私

ChatMem 默认本地优先：

- 本地历史和记忆索引存放在用户机器上的 SQLite 数据库中。
- 对话原文仍以本地 agent 的原始历史文件作为证据来源。
- WebDAV 是可选备份，不是日常检索和记忆能力的前提。
- MCP 工具会尽量返回紧凑上下文，避免把超长历史一次性塞进新窗口。

## 本地开发

环境要求：

- Node.js 20+
- Rust stable
- 对应平台可用的 Tauri 构建环境

常用命令：

```powershell
npm ci
npm run test:run
cargo test --manifest-path .\src-tauri\Cargo.toml
npm run tauri build
```

## 发布

发布由 GitHub Actions 处理。推送形如 `v1.1.0` 的 tag 后，工作流会自动构建并上传：

- Windows NSIS 安装包
- Windows MSI 安装包
- Windows 便携版 zip
- updater 所需的 `latest.json` 和签名文件
- macOS Apple Silicon / Intel dmg
- macOS app updater 包

应用内“检查更新”优先调用 GitHub Release API：

```text
https://api.github.com/repos/douxy1994/ChatMem/releases/latest
```

Windows 端会比较最新 Release tag 与当前版本；如果发现更高版本并且 Release 内包含 Windows `.exe` 安装器，会下载并运行安装器。如果版本一致，会提示当前为最新版本。

发布前需要在 GitHub 仓库里配置：

- `TAURI_PRIVATE_KEY`
- `TAURI_KEY_PASSWORD`

细节见 [DEVELOPMENT.md](./DEVELOPMENT.md)。
