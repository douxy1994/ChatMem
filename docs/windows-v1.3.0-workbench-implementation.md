# Windows Development Guide: ChatMem v1.3.0

This document is the Windows parity guide for ChatMem v1.3.0. Implement the same product behavior as the macOS/Tauri build while keeping Windows-native interaction conventions where appropriate.

## Release Scope

v1.3.0 remains on the Tauri + Rust + React code path. Do not port or depend on the removed unpublished native rewrite experiment.

Required feature areas:

1. Workbench home
2. Favorites+
3. Project timeline
4. Agent recommendation
5. Smart search
6. Project memory
7. Release/build assistant
8. Conversation quality
9. Local privacy cleanup
10. Windows/macOS parity status
11. Trash and sync deletion semantics
12. Summary migration option

The implementation must be local-first and non-destructive by default.

## Data Sources

Use data already loaded by the app:

- `sortedConversations`
- `filteredConversations`
- `favoriteConversations`
- `repoMemories`
- `memoryCandidates`
- `wikiPages`
- `checkpoints`
- `handoffs`
- `runs`
- `artifacts`
- `packageInfo.version`
- local sync settings

Do not require network access to render the Workbench.

## Workbench Entry

When no conversation is selected and no secondary panel is open, render the Workbench instead of an empty state.

Expected behavior:

- The Workbench title is the primary title.
- The line below it is the subtitle.
- Primary actions include “Resume Latest” and “Open Favorites”.
- Cards must reflow in narrow windows instead of pushing the Workbench below the sidebar.
- Avoid blank card slots. If a section has no data, show a compact empty state inside that section or rebalance the grid.

Return behavior:

- Conversation detail and local history detail should expose a floating bottom-right “Back to Workbench” button.
- The button should not require scrolling to the top of a long conversation.

## Favorites+

Extend `FavoriteConversationSnapshot` with:

```ts
note?: string;
tags?: string[];
pinned?: boolean;
```

Normalize missing values as:

```ts
note: "";
tags: [];
pinned: false;
```

Rust settings payload should include:

```rust
#[serde(default)]
note: String,
#[serde(default)]
tags: Vec<String>,
#[serde(default)]
pinned: bool,
```

Behavior:

- Sort pinned favorites before normal favorites.
- Preserve the selected user sort inside each pinned/unpinned group.
- Support note editing.
- Support comma-separated tags.
- Support pin/unpin.
- Support remove from favorites.
- Support “Copy Favorite Continuation Card”.

Continuation card fields:

- title
- source agent
- conversation id
- project path
- updated time
- pinned priority, if set
- tags, if present
- note, if present
- instruction to load source-backed ChatMem history before continuing

## Sidebar Bottom Entries

The bottom entries should show:

- Favorites
- Trash
- version label

Do not show Settings in the bottom bar on macOS. On Windows, Settings may stay in the app UI if that matches the Windows shell design.

Count badges:

- Use a small rounded badge.
- Do not let badges truncate the text label.
- Keep label and badge visible at minimum supported width.

## Menu and Settings

macOS uses `ChatMem -> 设置...` and emits `open-settings` to the frontend.

Windows can expose Settings through:

- in-app Settings entry, or
- application menu, if a Windows menu is enabled.

Both platforms should reuse the same SettingsPanel and persisted settings model.

## Trash Semantics

This is a required behavior change.

Moving to Trash:

- Creates a local recovery snapshot.
- Removes the active local memory/store record.
- Does not delete OneDrive/local sync backup.
- Does not delete WebDAV backup.
- Shows copy explaining that sync copies are preserved while recoverable.

Emptying Trash or expiry cleanup:

- Permanently removes the Trash recovery snapshot.
- Deletes configured OneDrive/local sync backup.
- Deletes configured remote backup only on final destructive cleanup paths where credentials and settings are available.

Reason:

- A trashed conversation must remain recoverable during the retention period.
- Deleting sync copies at move-to-trash time makes recovery incomplete across machines.

## Summary Migration

The Migrate dialog must include both options:

- Full conversation migration
- Summary migration

Full conversation migration:

- Keeps the existing behavior.
- Writes/imports the complete conversation where supported.

Summary migration:

- Copies a compact source-backed continuation brief.
- Does not write to the target platform.
- Does not delete the original conversation.
- Shows a success notice and closes the dialog after copying.

## Project Memory

The Project Memory card should load project-scoped local data for the currently selected or latest project:

- approved startup rules
- pending memory candidates
- wiki pages
- checkpoints
- handoffs
- runs
- artifacts

Opening “Project Memory View” from a conversation must stay in the Workbench/project-memory context. It must not navigate to an empty local-history page.

If no local history matches the repo root, show a diagnostic warning:

```text
ChatMem scanned local conversations but none matched this repo root; verify project paths or aliases.
```

This warning should not hide the rest of the Workbench.

## Workbench Card Logic

### Continue Work Home

Show the latest visible conversation and a Resume Latest action.

### Favorites+

Show favorite count, pinned count, top tags, and recent favorites.

### Project Timeline

Group conversations by normalized project path.

For each group show:

- project label
- conversation count
- aggregate message count
- aggregate file count
- latest updated time
- action to open the latest conversation

### Agent Recommendation

Local heuristic:

- file changes or implementation keywords -> Codex
- long context, writing, release, docs -> Claude
- search or research terms -> Gemini
- otherwise continue with the source agent

### Smart Search

If the sidebar search query is not empty, show filtered matches. Otherwise show recent conversations with project and recency cues.

### Release/Build Assistant

Show:

- current version: `v1.3.0`
- release notes: `docs/releases/v1.3.0.md`
- Windows guide: `docs/windows-v1.3.0-workbench-implementation.md`
- update channel: `douxy1994/ChatMem`

Rows must be clickable or expose details; long paths must wrap or ellipsize inside their own row, not overflow into neighboring cards.

### Conversation Quality

Rank useful conversations by:

- message count
- file count
- favorite bonus

### Privacy Cleanup

Only list candidates:

- not favorited
- older than 30 days
- low message count
- no file changes

Do not delete automatically. The user must explicitly move items to Trash.

## Styling Parity

Minimum requirements:

- No card content may overlap neighboring cards.
- Buttons and labels must remain readable at minimum supported window width.
- Green user-message bubbles must render links as white underlined text.
- Tool-call detail panels should use stable max width and not resize between compact and expanded states.
- The organize-session icon must be visually distinct from the manage-groups icon.

## Suggested Tests

Run:

```powershell
npm run test:run
npm run build
cargo check --manifest-path .\src-tauri\Cargo.toml
```

Add or keep tests for:

- Workbench heading appears when no conversation is selected.
- Settings Back returns to Workbench.
- Version label shows `v1.3.0`.
- Favorites metadata normalizes and persists.
- Favorite continuation card can be copied.
- Trash move does not delete sync backup.
- Empty Trash deletes sync backup when configured.
- Summary migration copy shows success and closes the dialog.
- Project Memory View does not navigate to an empty local-history panel.

## Acceptance Criteria

Windows parity is complete when:

- all Workbench cards render from local data without placeholders
- Favorites metadata survives app restart
- Trash recovery and final deletion semantics match this document
- summary migration is an additional option, not a replacement for full migration
- UI stays readable at the minimum supported window size
- release docs and updater channel point to `v1.3.0`
