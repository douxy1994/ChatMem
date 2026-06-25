# ChatMem Native AppKit Parallel Target Design

## Summary

Create a new parallel native macOS application target for ChatMem under `native/ChatMemNew/`.
The new target uses Swift and AppKit for the UI and leaves the existing Tauri, React, Rust,
and installed `/Applications/ChatMem.app` baseline untouched.

The goal is not a visual prototype. The native target must preserve the current ChatMem
information architecture and eventually reach full feature parity before it can be considered
as a replacement candidate. Replacement of the installed app remains a separate user-approved
release decision.

## Goals

- Add a separate Swift/AppKit macOS app target in the repository.
- Keep existing `src/`, `src-tauri/`, `crates/`, package files, and release assets unchanged
  during the native target bootstrap.
- Implement the full native UI structure first, matching the current ChatMem product flow:
  sidebar library, conversation workspace, local history, memory drawer, settings, favorites,
  trash, migration, checkpoints, handoffs, and help/about surfaces.
- Use native macOS controls and behaviors where they fit: windows, split views, outline/list
  views, toolbar/menu commands, sheets, pasteboard actions, and standard settings panels.
- Add lightweight telemetry through `OSLog.Logger` for high-value runtime events.
- Provide a stable native build/run entrypoint that does not interfere with the existing app.

## Non-Goals

- Do not rewrite, delete, or restructure the existing Tauri/React app in this phase.
- Do not replace `/Applications/ChatMem.app`.
- Do not ship a partial native build as the default ChatMem app.
- Do not implement a webview wrapper around the old UI and call it native.
- Do not use blank pages, dead buttons, or unmarked stubs as placeholders.

## Project Layout

The native app lives in a new isolated directory:

```text
native/ChatMemNew/
  Package.swift
  Sources/ChatMemNew/
    App/
    Controllers/
    Models/
    Stores/
    Services/
    Views/
    Support/
  Tests/ChatMemNewTests/
```

Supporting automation lives outside source:

```text
script/build_and_run_native.sh
.codex/environments/environment.toml
```

If `.codex/environments/environment.toml` already contains unrelated local actions, the native
action is added without removing those entries.

## Architecture

The first implementation layer is an AppKit application with explicit controller boundaries:

- `ChatMemNewApp`: `NSApplicationDelegate`, lifecycle setup, activation policy, menus.
- `MainWindowController`: owns the main window, toolbar, split layout, and top-level navigation.
- `LibrarySidebarController`: source selector, search, project groups, machine groups,
  conversation rows, favorites, trash, and sidebar collapse state.
- `WorkspaceController`: switches between workbench, selected conversation, settings, favorites,
  trash, about, and help surfaces.
- `MemoryDrawerController`: candidate rules, approved rules, wiki, continuation state.
- `SettingsWindowController` or settings workspace controller: language, font, updates,
  diagnostics, integrations, and sync settings.
- `ModalCoordinator`: migration, handoff composer, delete, trash, empty-trash confirmations.
- `Telemetry`: small typed wrapper around `OSLog.Logger`.

State is held in native stores rather than inside view controllers:

- `ConversationStore`: selected agent, conversation list, selected conversation, search,
  project grouping, trash and favorites.
- `MemoryStoreClient`: repo memories, candidates, wiki pages, health, checkpoints, handoffs,
  runs, artifacts, episodes.
- `SettingsStore`: locale, font, update preferences, sync settings, auto backup, integration state.
- `NativeBridge`: abstraction boundary for backend calls. It starts with deterministic sample
  data and local no-op responses only where functionality is not yet connected, then evolves
  toward real backend integration.

The bridge boundary is important: native UI code should not directly know whether a feature is
served by a future Rust bridge, a helper executable, JSON fixtures, or a local Swift service.

## UI Parity Surface

The native app must expose the same major surfaces as the current UI:

- Top bar with ChatMem identity, version, settings/about access, and native window behavior.
- Sidebar source selector for supported agents: Claude, Codex, Gemini/Antigravity where retained,
  OpenCode, ZCode, Hermes.
- Sidebar search and organization controls: arrangement, sort, filters, bulk selection,
  collapse/restore groups, machine group management, and project/chat grouping.
- Conversation list rows with title, project path, timestamps, message/file counts, source agent,
  and selection state.
- Workbench empty state when no conversation is selected.
- Conversation workspace with title, project path, storage path, resume command, continuation
  prompt, migration action, and local history tab.
- Conversation transcript detail with messages, tool calls, metadata, and file changes.
- Local history panel with scan, import, alias merge, recall, index health, and bootstrap status.
- Memory drawer with review inbox, approved startup rules, wiki projection, checkpoints,
  and handoff packets.
- Review surfaces for pending candidates, stale rules, and pending transfers.
- History surfaces for conversations, recovery, transfers, runs, artifacts, and episodes.
- Settings surfaces for language, font, updates, upgrade self-check, agent integration,
  WebDAV, OneDrive/local sync, auto capture, and auto backup.
- Favorites and trash workspaces, including restore/delete/empty confirmation flows.
- Help/about surfaces with searchable guidance and diagnostics.

During the UI-first phase, any backend-incomplete action must render as a working native control
with one of these states:

- connected and functional,
- disabled with a visible reason,
- queued in the implementation backlog with telemetry and a clear user-facing status.

No surface may be blank or silently nonfunctional.

## AppKit Interop Decisions

This target is native AppKit-first:

- Use `NSWindowController` for the main window and auxiliary windows.
- Use `NSSplitViewController` or a constrained split layout for sidebar and workspace.
- Use `NSOutlineView` or collection/list views for project and machine group navigation.
- Use `NSTableView` or list-backed custom rows for dense conversation lists where needed.
- Use `NSToolbar` and menu commands for primary desktop actions.
- Use modal sheets for migration, handoff composition, and destructive confirmations.
- Use `NSPasteboard` for copy path, resume command, and continuation prompt actions.
- Use system colors, semantic materials, and native selection/focus behavior.

The current React CSS remains a visual reference only. Native controls should match the product
structure and density, while accepting small platform-appropriate differences.

## Telemetry

Use `OSLog.Logger` with subsystem `com.chatmem.native` and feature categories:

- `Lifecycle`: app launch, main window created, foreground activation.
- `Sidebar`: source changes, search changes, grouping changes, conversation selection.
- `Workspace`: workspace switches, conversation opened, settings/favorites/trash/about opened.
- `Memory`: drawer opened, tab changes, candidate actions, wiki rebuild request.
- `Bridge`: backend call start/success/failure and fallback paths.
- `Sync`: sync settings verification and sync actions.

Telemetry must not log secrets, raw transcript contents, WebDAV passwords, API keys, or full
private message text.

## Build And Run

Add `script/build_and_run_native.sh` as the native build/run entrypoint. It should:

1. Stop a running `ChatMemNew` process if present.
2. Build the SwiftPM app.
3. Stage `dist/ChatMemNew.app`.
4. Launch the app bundle with `/usr/bin/open -n`.
5. Support `--verify` to confirm the process exists.
6. Support `--telemetry` to stream filtered unified logs.

The Codex Run action should point to this native script without removing existing local actions.

## Backend Integration Plan

Backend completion should be incremental and bridge-driven:

1. UI parity shell with sample data and explicit disabled states.
2. Read-only conversation listing and detail loading.
3. Native copy, favorites, trash, and settings persistence.
4. Memory health, scan/import, alias merge, recall, candidates, approved rules, wiki.
5. Checkpoints, handoffs, runs, artifacts, episodes.
6. Agent integration install/repair/uninstall.
7. WebDAV/OneDrive/local sync and upgrade self-check.
8. Update flow.

The implementation plan can decide whether real backend calls are best served by:

- linking or wrapping the existing Rust core,
- introducing a small local helper executable,
- exposing a local command bridge,
- or porting selected platform functions to Swift.

The UI must not depend on that final transport choice.

## Testing And Verification

Minimum verification for the first implementation phase:

- `swift build` succeeds for the native package.
- `script/build_and_run_native.sh --verify` launches `ChatMemNew`.
- Telemetry emits lifecycle and at least one sidebar/workspace event.
- Native UI opens with no blank primary surface.
- Sidebar selection changes update the workspace.
- Settings, memory drawer, favorites, trash, and modals can be opened and closed.
- Clipboard actions use `NSPasteboard`.
- Existing Tauri/React files remain unchanged except for intentional docs or run configuration.

Future backend phases add tests around bridge responses, error states, and parity workflows.

## Risks

- The old React `App.tsx` contains a large amount of intertwined UI and state logic. Native parity
  will be easier if the first pass preserves information architecture but does not copy internal
  implementation shape.
- A visually complete UI can still be functionally incomplete. The backlog must track every
  disabled or queued action until parity is reached.
- Rust backend reuse may require build-system work. Keep the bridge abstract until the smallest
  reliable integration path is proven.
- The native app must remain clearly separate from the installed baseline to avoid accidental
  replacement before user-approved parity.

## Acceptance Criteria

- A new native target exists under `native/ChatMemNew/`.
- Old app source and installed app are not modified or replaced.
- The native app builds and launches independently.
- The first native UI pass contains all major current ChatMem surfaces with native macOS behavior.
- Telemetry is present and verifiable.
- The implementation backlog clearly identifies every feature not yet connected to real backend
  behavior.
