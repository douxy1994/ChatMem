# Windows Implementation Guide: v1.2.2 Favorites And Layout Parity

This guide describes the v1.2.2 Favorites feature and related UI layout updates so the Windows build can implement the same behavior.

The intended outcome is UI and data compatibility with the macOS/local v1.2.2 build in this repository.

## Scope

Implement these v1.2.2 changes:

- Favorites storage and normalization
- star/unstar actions in conversation rows
- right-side Favorites workspace
- bottom utility navigation with Favorites, Trash, Settings, and version
- removal of visible About utility entry
- Settings page floating back button
- updater/release channel pointing to `douxy1994/ChatMem`

Do not remove or replace the v1.2.1 migration features:

- full conversation migration remains available
- summary-style migration remains available inside the `Migrate` modal
- low-token continuation copy remains available from the conversation toolbar

## Data Model

Add this frontend type in `src/settings/storage.ts`:

```ts
export type FavoriteConversationSnapshot = {
  id: string;
  sourceAgent: string;
  projectDir: string;
  createdAt: string;
  updatedAt: string;
  summary: string | null;
};
```

Extend `AppSettings`:

```ts
favoriteConversations: Record<string, FavoriteConversationSnapshot>;
```

Extend `DEFAULT_SETTINGS`:

```ts
favoriteConversations: {},
```

Add tolerant normalization:

- if `favoriteConversations` is missing, use `{}`
- ignore entries that are not records
- ignore entries without string `id` or string `sourceAgent`
- default missing `projectDir`, `createdAt`, and `updatedAt` to `""`
- default non-string `summary` to `null`

Use conversation keys in the same format already used by list selection:

```ts
`${source_agent}:${id}`
```

This avoids collisions when different agents reuse the same conversation id.

## Native Settings Payload

Windows must keep the Rust/native settings payload in sync with frontend settings. In `src-tauri/src/main.rs`, add:

```rust
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
struct FavoriteConversationPayload {
    id: String,
    source_agent: String,
    project_dir: String,
    created_at: String,
    updated_at: String,
    summary: Option<String>,
}
```

Then extend `AppSettingsPayload` with:

```rust
#[serde(default)]
favorite_conversations: std::collections::HashMap<String, FavoriteConversationPayload>,
```

Important compatibility note:

- The frontend settings object uses camelCase: `favoriteConversations`.
- The native JSON payload uses serde conversion so persisted settings remain compatible.
- Do not drop unknown/new fields when native settings are loaded and saved. v1.2.2 also keeps `machine_group_names` and `machine_group_overrides` in the native payload so native settings round trips do not erase machine grouping state.

## Frontend Mapping

Add two helpers in `src/App.tsx`.

Snapshot from conversation:

```ts
function conversationToFavoriteSnapshot(conversation): FavoriteConversationSnapshot {
  return {
    id: conversation.id,
    sourceAgent: conversation.source_agent,
    projectDir: getConversationProjectDir(conversation),
    createdAt: conversation.created_at,
    updatedAt: conversation.updated_at,
    summary: conversation.summary ?? null,
  };
}
```

Conversation summary from snapshot:

```ts
function favoriteSnapshotToConversationSummary(snapshot): ConversationSummary {
  return {
    id: snapshot.id,
    source_agent: snapshot.sourceAgent,
    project_dir: snapshot.projectDir,
    created_at: snapshot.createdAt,
    updated_at: snapshot.updatedAt,
    summary: snapshot.summary,
    message_count: 0,
    file_count: 0,
  };
}
```

The zero counts are acceptable because Favorites is a navigation surface, not a full list source.

## Favorite Toggle Behavior

Implement a handler equivalent to:

```ts
const handleToggleFavoriteConversation = (conversation) => {
  const conversationKey = getConversationKey(conversation);
  const nextFavorites = { ...appSettings.favoriteConversations };

  if (nextFavorites[conversationKey]) {
    delete nextFavorites[conversationKey];
  } else {
    nextFavorites[conversationKey] = conversationToFavoriteSnapshot(conversation);
  }

  const nextSettings = updateSettings({ favoriteConversations: nextFavorites });
  setAppSettings(nextSettings);
};
```

Expected UX:

- every normal conversation row shows a star button
- clicking the star must not open the conversation row
- selected/favorited rows keep the star visible
- bulk selection and machine-group move modes hide star buttons
- unstar removes the item from the Favorites page immediately

## Opening Favorite Conversations

Favorites may point to conversations from another top-level agent. Add a helper that switches source before opening:

```ts
const handleOpenConversation = async (conversation: ConversationSummary) => {
  const agent = getTopLevelAgent(conversation.source_agent);
  if (agent !== selectedAgent) {
    setSelectedAgent(agent);
    await loadConversations("", agent);
  }
  await loadConversationDetail(conversation.id, agent);
};
```

`getTopLevelAgent()` should map:

- `zcode*` -> `zcode`
- `claude`, `codex`, `gemini`, `opencode`, `hermes` -> themselves
- unknown values -> a conservative default, currently `claude`

When a normal conversation opens, close Favorites:

```ts
setShowFavorites(false);
```

## Favorites Workspace

Add `showFavorites` state in `src/App.tsx`.

Render Favorites in the main workspace, parallel to Trash:

```tsx
{showSettings
  ? renderSettingsPanel()
  : showAbout
    ? renderAboutWorkspace()
    : showFavorites
      ? renderFavoritesWorkspace()
      : showTrash
        ? renderTrashWorkspace()
        : renderWorkspace()}
```

Do not render Favorites as a replacement for the left sidebar list. The left sidebar should remain the normal source/project/conversation navigation.

Favorites workspace card actions:

- `Open`
- `Remove / 取消收藏`

Empty state:

- English: `Star important conversations to keep them available here.`
- Chinese: `收藏重要对话后，它们会集中显示在这里。`

## Bottom Utility Navigation

The bottom nav should contain exactly these visible entries:

- Favorites
- Trash
- Settings
- version label

Remove the visible About button from this nav. The existing About code can remain if another entry point needs it later, but it must not appear in the bottom utility row.

Click behavior:

- Favorites: closes Trash, Settings, About; toggles Favorites on/off
- Trash: closes Favorites, Settings, About; opens Trash
- Settings: closes Favorites, Trash, About; opens Settings
- Changing the source dropdown closes Favorites

CSS requirements:

- `.sidebar-utility-nav` is a single horizontal row
- `.utility-nav-actions` holds the three buttons
- `.utility-nav-version` stays on the same line as buttons
- `.utility-nav-button` uses content-based width, currently `flex: 0 1 auto`, `min-height: 34px`, and compact horizontal padding
- `.utility-nav-count` uses `flex: 0 0 auto` and must not use negative margins, otherwise the count can truncate `收藏夹 / Favorites`
- `.utility-nav-label` can still ellipsize as a fallback on very narrow windows, but normal sidebar width must show both the label and the count

## Settings Floating Back Button

`SettingsPanel` should support hiding the header close button:

```ts
showHeaderCloseButton?: boolean;
```

When App renders Settings, pass:

```tsx
showHeaderCloseButton={false}
```

Then render the close action outside the SettingsPanel:

```tsx
{showSettings ? (
  <button
    type="button"
    className="sidebar-collapse-float settings-return-float"
    aria-label={locale === "en" ? "Back" : "返回"}
    title={locale === "en" ? "Back" : "返回"}
    onClick={() => setShowSettings(false)}
  >
    <WindowButtonIcon type="back" />
  </button>
) : null}
```

The floating back button should reuse the same base style as `.sidebar-collapse-float`.

Add `.sidebar-collapse-float svg` to the shared icon-size selector so the icon renders consistently.

## Updater Endpoint

The fork release channel is:

```text
https://github.com/douxy1994/ChatMem/releases/latest/download/latest.json
```

Update:

- `src-tauri/tauri.conf.json`
- README release instructions
- release checklist docs

Do not point this fork build at `Rimagination/ChatMem` unless explicitly shipping an upstream release.

## Tests To Port

Add or update tests for:

```bash
npm run test:run -- src/__tests__/settingsStorage.test.ts src/__tests__/App.test.tsx -t "favorite|1.2.2 version|settings storage"
npm run test:run -- src/__tests__/App.test.tsx -t "opens settings as a full workspace page"
npm run build
```

Expected assertions:

- default settings include `favoriteConversations: {}`
- malformed favorite entries are dropped during normalization
- valid favorite entries survive normalization
- clicking a row star writes a favorite snapshot to local settings
- Favorites opens as a workspace page
- Favorites button can toggle the page off
- utility nav no longer has `About us`
- version label renders `v1.2.2`
- settings header has no `.toolbar-button`
- `.settings-return-float` exists and closes settings

## Windows Manual Smoke Test

1. Install the Windows build.
2. Open ChatMem and select a source with at least one conversation.
3. Click a conversation star.
4. Confirm the bottom Favorites count appears.
5. Click Favorites.
6. Confirm the right workspace shows the favorited card.
7. Click Open and confirm the original conversation opens.
8. Open Settings and confirm the return action is a left-bottom floating button.
9. Click Back and confirm the normal workspace returns.
10. Restart ChatMem and confirm the favorite remains.

## Acceptance Criteria

The Windows implementation is equivalent when:

- Favorites are persisted in settings and survive restart.
- Favorites do not copy full conversation content.
- Favorites can reopen conversations across supported top-level sources.
- Favorites display on the right, not as a left-sidebar replacement.
- Favorites toggle off when the bottom Favorites button is clicked again.
- Opening any normal conversation exits Favorites.
- About is not visible in the bottom utility nav.
- Bottom utility buttons and version label align in one row.
- Favorites count does not truncate the Favorites label at the normal sidebar width.
- Settings uses the floating left-bottom return button.
- v1.2.1 summary-style migration remains unchanged.
