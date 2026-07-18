# ChatMem Native AppKit Parallel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a parallel local `ChatMemNew.app` native macOS application that can be launched and tested without modifying or replacing the existing ChatMem Tauri app.

**Architecture:** Add a SwiftPM AppKit app under `native/ChatMemNew/` with focused models, stores, services, controllers, and views. The first version is UI-complete with deterministic sample data, explicit disabled/in-progress states for backend-incomplete actions, AppKit-native windowing, clipboard actions, sheets, and unified logging telemetry.

**Tech Stack:** Swift 5.9+, SwiftPM, AppKit, Foundation, OSLog, XCTest, shell build script.

## Global Constraints

- Existing `src/`, `src-tauri/`, `crates/`, package files, and release assets stay unchanged.
- Do not replace `/Applications/ChatMem.app`.
- Do not implement a webview wrapper around the old UI.
- No primary surface may be blank or silently nonfunctional.
- Backend-incomplete actions must be connected, disabled with a visible reason, or queued with clear status.
- Use `OSLog.Logger` with subsystem `com.chatmem.native` and do not log secrets or raw transcript contents.
- Stage and launch the native app as `dist/ChatMemNew.app`.

---

### Task 1: SwiftPM Native App Scaffold

**Files:**
- Create: `native/ChatMemNew/Package.swift`
- Create: `native/ChatMemNew/Sources/ChatMemNew/App/ChatMemNewApp.swift`
- Create: `native/ChatMemNew/Sources/ChatMemNew/Support/DesignSystem.swift`
- Create: `native/ChatMemNew/Tests/ChatMemNewTests/ChatMemNewTests.swift`

**Interfaces:**
- Produces: `ChatMemNewApp.main()`, `DesignSystem`, and an importable `ChatMemNew` module.

- [x] Create the SwiftPM executable package with macOS 13+ platform support.
- [x] Create the AppKit entrypoint that activates as a regular foreground macOS app.
- [x] Add a minimal XCTest target proving sample module code is importable.
- [x] Run `swift test` from `native/ChatMemNew` and expect tests to pass.

### Task 2: Models, Sample Data, Stores, and Telemetry

**Files:**
- Create: `native/ChatMemNew/Sources/ChatMemNew/Models/ChatMemModels.swift`
- Create: `native/ChatMemNew/Sources/ChatMemNew/Stores/AppStore.swift`
- Create: `native/ChatMemNew/Sources/ChatMemNew/Services/NativeBridge.swift`
- Create: `native/ChatMemNew/Sources/ChatMemNew/Services/Telemetry.swift`
- Modify: `native/ChatMemNew/Tests/ChatMemNewTests/ChatMemNewTests.swift`

**Interfaces:**
- Produces: `AgentKind`, `ConversationSummary`, `ConversationDetail`, `MemoryCandidate`, `ApprovedMemory`, `WikiPage`, `Checkpoint`, `HandoffPacket`, `RunRecord`, `ArtifactRecord`, `EpisodeRecord`, `AppStore`, `NativeBridge`, and `Telemetry`.
- Consumes: `DesignSystem`.

- [x] Define value models matching the current ChatMem UI surfaces.
- [x] Add deterministic sample data covering conversations, memory, wiki, checkpoints, handoffs, runs, artifacts, episodes, favorites, and trash.
- [x] Implement `AppStore` with selected agent, selected conversation, search, workspace, drawer, and settings state.
- [x] Add `Telemetry` categories for lifecycle, sidebar, workspace, memory, bridge, and sync.
- [x] Add tests for sample data completeness and search filtering.
- [x] Run `swift test` from `native/ChatMemNew` and expect tests to pass.

### Task 3: Main Window, Sidebar, and Conversation Workspace

**Files:**
- Create: `native/ChatMemNew/Sources/ChatMemNew/Controllers/MainWindowController.swift`
- Create: `native/ChatMemNew/Sources/ChatMemNew/Views/RootView.swift`
- Create: `native/ChatMemNew/Sources/ChatMemNew/Views/SidebarView.swift`
- Create: `native/ChatMemNew/Sources/ChatMemNew/Views/WorkspaceView.swift`
- Create: `native/ChatMemNew/Sources/ChatMemNew/Views/ConversationDetailView.swift`
- Modify: `native/ChatMemNew/Sources/ChatMemNew/App/ChatMemNewApp.swift`

**Interfaces:**
- Consumes: `AppStore`, `Telemetry`, `DesignSystem`.
- Produces: a foreground main window with source selection, search, grouped conversation list, and selected conversation detail.

- [x] Implement `MainWindowController` using `NSWindowController`.
- [x] Implement root split layout with a dense native sidebar and workspace.
- [x] Implement agent source selector, search, project/chat group sections, favorites/trash counters, and selection behavior.
- [x] Implement conversation workspace with title, path, resume command, continuation prompt, transcript, tool calls, and file changes.
- [x] Wire sidebar selection telemetry and workspace state updates.
- [x] Run `swift test` and `swift build` from `native/ChatMemNew`.

### Task 4: Memory Drawer, Settings, Favorites, Trash, and Sheets

**Files:**
- Create: `native/ChatMemNew/Sources/ChatMemNew/Views/MemoryDrawerView.swift`
- Create: `native/ChatMemNew/Sources/ChatMemNew/Views/SettingsView.swift`
- Create: `native/ChatMemNew/Sources/ChatMemNew/Views/UtilityWorkspaces.swift`
- Create: `native/ChatMemNew/Sources/ChatMemNew/Controllers/ModalCoordinator.swift`
- Modify: `native/ChatMemNew/Sources/ChatMemNew/Views/RootView.swift`
- Modify: `native/ChatMemNew/Sources/ChatMemNew/Views/WorkspaceView.swift`

**Interfaces:**
- Consumes: `AppStore`, `NativeBridge`, `Telemetry`.
- Produces: openable/closable memory drawer, settings, favorites, trash, help/about surfaces, and native sheets for queued actions.

- [x] Implement memory drawer tabs for review, rules, wiki, and continuation state.
- [x] Implement settings workspace with language/font/update/integration/sync sections.
- [x] Implement favorites, trash, help, and about workspaces.
- [x] Implement modal sheets for migration, handoff, delete, empty trash, and backend-incomplete action status.
- [x] Ensure backend-incomplete actions show a visible queued/disabled state.
- [x] Run `swift test` and `swift build` from `native/ChatMemNew`.

### Task 5: Build Script, Codex Run Action, Verification, and Local App Install

**Files:**
- Create: `script/build_and_run_native.sh`
- Modify: `.codex/environments/environment.toml`
- Modify: `docs/superpowers/plans/2026-06-26-chatmem-native-appkit-parallel.md`

**Interfaces:**
- Consumes: `native/ChatMemNew` executable target.
- Produces: `dist/ChatMemNew.app`, Codex action `Run Native ChatMemNew`, and verification evidence.

- [x] Add `script/build_and_run_native.sh` with `run`, `--verify`, `--logs`, and `--telemetry` modes.
- [x] Add or update `.codex/environments/environment.toml` with a separate native run action.
- [x] Run `./script/build_and_run_native.sh --verify` from repository root and expect `ChatMemNew` to launch.
- [x] Copy `dist/ChatMemNew.app` to `/Applications/ChatMemNew.app` without touching `/Applications/ChatMem.app`.
- [x] Run `/Applications/ChatMemNew.app` once through `open -n` and verify the process exists.
- [x] Update this plan checklist to mark completed tasks.
