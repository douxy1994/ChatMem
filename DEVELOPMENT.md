# ChatMem Development Notes

## 环境准备

**macOS**
- Node.js 20+、Rust stable（rustup）、Xcode Command Line Tools

**Windows**
- Node.js 20+、Rust stable（rustup，msvc 工具链）
- Microsoft C++ 生成工具（Visual Studio Build Tools）
- WebView2 Runtime（Windows 10 1803+ / 11 一般已内置）

两端通用依赖安装：

```bash
npm ci
```

## Local Commands（双端通用）

```bash
npm run test:run                              # 前端测试
cargo test --manifest-path src-tauri/Cargo.toml   # Rust 测试（Windows PowerShell 用 .\src-tauri\Cargo.toml）
npm run tauri dev                             # 开发模式（热更新）
npm run tauri build                           # 生产构建
```

## Updater Key（v1.3.5 起更换为新密钥对）

应用内更新使用 minisign 签名。**v1.3.5 起使用新密钥对**，旧 Windows 机器上的
`C:\Users\93219\.tauri\chatmem.key` 已作废，不要再使用。

密钥存放位置（私钥和密码绝不进仓库）：

- macOS：`~/.tauri/chatmem.key`，密码文件 `~/.tauri/chatmem-updater-password.txt`
- Windows：需要在本地做签名构建时，把**同一份**私钥和密码文件拷到
  `%USERPROFILE%\.tauri\chatmem.key` 和 `%USERPROFILE%\.tauri\chatmem-updater-password.txt`
  （从 macOS 的 `~/.tauri/` 复制，或向维护者索取）

GitHub Secrets（`douxy1994/ChatMem`，已配置）：

- `TAURI_PRIVATE_KEY`：`chatmem.key` 文件全文
- `TAURI_KEY_PASSWORD`：密码文件内容

公钥写在 `src-tauri/tauri.conf.json` 的 `tauri.updater.pubkey`。
**更换密钥时必须同步修改该公钥并发新版本**——旧公钥的安装包无法验证新密钥签名的更新包，需要用户手动重装一次。

## Local Signed Build

macOS（zsh）：

```bash
export TAURI_PRIVATE_KEY="$(cat ~/.tauri/chatmem.key)"
export TAURI_KEY_PASSWORD="$(cat ~/.tauri/chatmem-updater-password.txt)"
npm run tauri build
```

Windows（PowerShell）：

```powershell
$env:TAURI_PRIVATE_KEY = Get-Content -Raw "$env:USERPROFILE\.tauri\chatmem.key"
$env:TAURI_KEY_PASSWORD = Get-Content -Raw "$env:USERPROFILE\.tauri\chatmem-updater-password.txt"
npm run tauri build
```

不带这两个变量也能构建出 `.app` / `.dmg` / `.exe`，但打包末尾会因无法签名
updater 包而报错（"A public key has been found, but no private key"），产物本身可用。

## Release Workflow（douxy1994/ChatMem）

发布流程定义在 `.github/workflows/release.yml`，触发条件：

- **Release 发布时**（`release: published`，主流程）
- 推送 `v*` tag（保留的备用触发）

标准发版步骤：

1. 同步三处版本号：`package.json`、`src-tauri/tauri.conf.json`、`src-tauri/Cargo.toml`
   （`src-tauri/Cargo.lock` 由构建自动更新，一并提交）
2. commit 并 push 到 `main`
3. 发布 Release：`gh release create vX.Y.Z --title "ChatMem vX.Y.Z" --notes-file <说明.md>`
   - 只写说明即可，**不要手动上传资产**，资产全部由 CI 追加
   - Release 说明如需修改，等 CI 跑完后再编辑定稿
4. CI 自动向该 Release 追加：
   - Windows NSIS 安装包（`*_x64-setup.exe`）+ 签名更新包 + `.sig`
   - Windows 便携版 `ChatMem-vX.Y.Z-portable.zip`
   - macOS dmg（Apple Silicon / Intel 各一）+ 签名更新包（`.app.tar.gz`）+ `.sig`
   - 双平台合并的 `latest.json`（应用内更新清单）
5. CI 全部变绿后，双端 app 的「检查更新」即可发现并完成应用内更新

## 应用内更新的双端机制

- **检查更新**：两端共用，前端 `src/updater/updater.ts` 先调
  `check_github_release_update`（`src-tauri/src/github_update.rs`，读最新 Release 元数据比较版本）
- **Windows 安装**：`install_github_release_update` 直接下载最新 Release 中的
  `*setup.exe` 并以 `/S` 静默安装——此路径**仅限 Windows**，不依赖签名密钥，
  但要求 Release 里有 CI 产出的 `.exe`
- **macOS 安装**：自动回退到 Tauri 签名更新器（`@tauri-apps/api/updater` 的
  `installUpdate`），下载 `latest.json` 中对应平台的 `.app.tar.gz`，用内置公钥验签后替换自身并重启
- Windows 安装模式：`tauri.conf.json` 的 `tauri.updater.windows.installMode = "passive"`

## Windows 端开发要点

- 安装包格式：NSIS（Tauri 默认），产物在 `src-tauri\target\release\bundle\nsis\`
- 便携版打包：

  ```powershell
  powershell -ExecutionPolicy Bypass -File .\scripts\build-portable.ps1 -Version X.Y.Z
  ```

  读取 `src-tauri\target\release\ChatMem.exe` 和 `README.md`，输出到 `dist-portable\`
- **功能同步约定**：Windows 端开发一律基于 `douxy1994/ChatMem` 的 `main` 分支，
  不要在 Windows 侧单独分叉版本号或功能；提交前跑 `npm run test:run` 和 `cargo test`
- 涉及平台差异的代码要显式标注（参考 `github_update.rs` 中 Windows-only 的
  installer 路径与 `updater.ts` 的平台回退逻辑），避免一端改动悄悄破坏另一端
- CI 的 Windows 构建在 `windows-latest`  runner 上跑，本地不构建 Windows 包也能发版

### Windows 搜索验收

- 侧栏搜索必须覆盖 Agent 原生会话、同步目录快照和 ChatMem 本地内存库中的会话。
- 单个会话文件无法读取时应跳过该条记录，不能让整次搜索失败。
- 连续快速输入时只允许最新请求更新列表；旧请求后返回时不得覆盖新结果。
- 搜索失败时清空旧结果并显示错误提示，避免把未过滤列表误认为搜索结果。
- 回归测试至少覆盖正文命中、中文关键词、同步摘要字段和异步请求乱序。

## macOS 注意

当前 macOS 发布包未做 Apple Developer ID 签名和 notarization，首次打开可能需要在
「系统设置 → 隐私与安全性」里允许。正式分发前如需减少 Gatekeeper 提示，在仓库
Secrets 中补充 Apple Developer 证书和 notarization 凭据，并扩展
`.github/workflows/release.yml`。
