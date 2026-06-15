# ChatMem v1.1.3 macOS 端同步适配指南

## 背景

Windows 端已完成以下修改，使 macOS 端的对话能通过 OneDrive 同步到 Windows 并在 ChatMem 中显示。macOS 端需要做对等修改，才能读取到 Windows 端的对话。

## 需要修改的 4 个部分

### 1. 文件名编码（`src-tauri/src/local_sync.rs`）

**问题**：ZCode 的 `encode_zcode_cli_id()` 生成含冒号的 ID（如 `claude:task:xxx:yyy`）。macOS 允许冒号作为文件名，但 Windows 不允许。

**方案**：读写同步文件夹时，统一使用 HTML 实体编码。

添加两个函数（已有函数的地方直接替换）：

```rust
/// 将对话 ID 编码为安全文件名
pub fn id_to_filename(id: &str) -> String {
    let mut out = String::with_capacity(id.len());
    for ch in id.chars() {
        match ch {
            ':' => out.push_str("&#x3a;"),
            '<' => out.push_str("&#x3c;"),
            '>' => out.push_str("&#x3e;"),
            '"' => out.push_str("&#x22;"),
            '|' => out.push_str("&#x7c;"),
            '?' => out.push_str("&#x3f;"),
            '*' => out.push_str("&#x2a;"),
            '/' => out.push_str("&#x2f;"),
            '\\' => out.push_str("&#x5c;"),
            _ => out.push(ch),
        }
    }
    out
}

/// 将安全文件名解码为原始对话 ID
pub fn filename_to_id(name: &str) -> String {
    name.replace("&#x3a;", ":")
        .replace("&#x3c;", "<")
        .replace("&#x3e;", ">")
        .replace("&#x22;", "\"")
        .replace("&#x7c;", "|")
        .replace("&#x3f;", "?")
        .replace("&#x2a;", "*")
        .replace("&#x2f;", "/")
        .replace("&#x5c;", "\\")
}
```

**调用位置**（共 3 处）：

#### 写入时（`bidirectional_sync` 函数，2 处 `fs::write`）

原来的：
```rust
let file_path = conversations_dir.join(agent).join(format!("{id}.json"));
fs::write(&file_path, local_body)?;
```

改为：
```rust
let safe_name = id_to_filename(id);
let file_path = conversations_dir.join(agent).join(format!("{safe_name}.json"));
fs::write(&file_path, local_body)?;
```

#### 读取时（`read_remote_conversations` 函数）

原来的：
```rust
let file_name = path.file_stem().map(|n| n.to_string_lossy().to_string()).unwrap_or_default();
if file_name.is_empty() { continue; }
// ... 使用 file_name 作为 key
remote.insert((agent.to_string(), file_name), (updated_at, body));
```

改为：
```rust
let file_name = path.file_stem().map(|n| n.to_string_lossy().to_string()).unwrap_or_default();
if file_name.is_empty() { continue; }
let id = filename_to_id(&file_name);  // 解码回原始 ID
// ... 使用 id 作为 key
remote.insert((agent.to_string(), id), (updated_at, body));
```

同时把 `read_remote_conversations` 的可见性改为 `pub`。

---

### 2. 同步时导入远程对话到记忆库（`src-tauri/src/main.rs`）

**问题**：`sync_local_now` 只上传本地对话到同步文件夹，但不把远程对话导入到 ChatMem 记忆库。

**方案**：同步完成后，读取远程对话并写入记忆库。

在 `sync_local_now` 函数末尾，`bidirectional_sync` 返回后添加：

```rust
let result = local_sync::bidirectional_sync(&items, &path).map_err(|e| e.to_string())?;

// 导入远程对话到记忆库
if result.downloaded > 0 {
    if let Ok(store) = open_memory_store() {
        let remote = local_sync::read_remote_conversations(&path);
        let mut local_ids: std::collections::HashSet<(String, String)> = std::collections::HashSet::new();
        for item in &items {
            local_ids.insert((item.agent.clone(), item.id.clone()));
        }
        for ((agent, id), (_updated_at, body)) in &remote {
            if local_ids.contains(&(agent.clone(), id.clone())) {
                continue;  // 跳过本地已有的
            }
            match serde_json::from_slice::<Conversation>(body) {
                Ok(conversation) => {
                    if let Err(e) = sync_conversation_into_store(&store, agent, &conversation) {
                        eprintln!("Warning: failed to import synced {agent}/{id}: {e}");
                    }
                }
                Err(e) => {
                    eprintln!("Warning: failed to deserialize synced {agent}/{id}: {e}");
                }
            }
        }
    }
}

Ok(result)
```

---

### 3. 来源视图显示同步的对话（`src-tauri/src/main.rs`）

**问题**：`list_conversations` 只从适配器读取，同步过来的对话（在记忆库中）不在来源视图中显示。

**方案**：合并适配器结果 + 记忆库结果。

#### 3a. 在 MemoryStore 中添加查询方法（`src-tauri/src/chatmem_memory/store.rs`）

```rust
pub fn list_store_conversations(
    &self,
    source_agent: &str,
) -> Result<Vec<(String, String, Option<String>, String, String, usize)>> {
    let conn = self.conn()?;
    let mut stmt = conn.prepare(
        "SELECT c.source_conversation_id, r.repo_root, c.summary, c.started_at, c.updated_at,
                (SELECT COUNT(*) FROM messages m WHERE m.conversation_id = c.conversation_id) as msg_count
         FROM conversations c
         JOIN repos r ON c.repo_id = r.repo_id
         WHERE c.source_agent = ?1
         ORDER BY c.updated_at DESC",
    )?;
    let rows = stmt
        .query_map([source_agent], |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, Option<String>>(2)?,
                row.get::<_, String>(3)?,
                row.get::<_, String>(4)?,
                row.get::<_, usize>(5)?,
            ))
        })?
        .filter_map(|r| r.ok())
        .collect();
    Ok(rows)
}
```

#### 3b. 修改 `list_conversations`（`src-tauri/src/main.rs`）

```rust
async fn list_conversations(agent: String) -> Result<Vec<ConversationSummaryResponse>, String> {
    let adapter = get_adapter(&agent)?;

    let mut seen_ids: std::collections::HashSet<String> = std::collections::HashSet::new();
    let mut results: Vec<ConversationSummaryResponse> = Vec::new();

    // 适配器（本地原生存储）
    if adapter.is_available() {
        if let Ok(conversations) = adapter.list_conversations() {
            for summary in conversations {
                seen_ids.insert(summary.id.clone());
                results.push(convert_summary(summary));
            }
        }
    }

    // 记忆库（从其他机器同步过来的）
    if let Ok(store) = open_memory_store() {
        if let Ok(store_convs) = store.list_store_conversations(&agent) {
            for (source_id, repo_root, summary, started_at, updated_at, msg_count) in store_convs {
                if seen_ids.contains(&source_id) {
                    continue;
                }
                seen_ids.insert(source_id.clone());
                results.push(ConversationSummaryResponse {
                    id: source_id,
                    source_agent: agent.clone(),
                    project_dir: repo_root,
                    created_at: started_at,
                    updated_at,
                    summary,
                    message_count: msg_count,
                    file_count: 0,
                });
            }
        }
    }

    Ok(results)
}
```

---

### 4. 读取同步的对话详情（`src-tauri/src/main.rs`）

**问题**：`read_conversation` 只从适配器读取，点击同步的对话会报错。

**方案**：适配器失败时，从同步文件夹读取原始 JSON。

```rust
async fn read_conversation(agent: String, id: String) -> Result<ConversationResponse, String> {
    let adapter = get_adapter(&agent)?;

    // 先试适配器
    let conversation = match adapter.read_conversation(&id) {
        Ok(mut conv) => {
            conv.project_dir = normalize_project_dir(&conv.project_dir);
            conv
        }
        Err(_) => {
            // 适配器没有 → 从同步文件夹读取
            let settings = read_app_settings_from_disk()?;
            let sync_folder = settings
                .as_ref()
                .map(|s| s.sync.sync_folder.clone())
                .unwrap_or_default();
            if sync_folder.is_empty() {
                return Err(format!("Conversation {id} not found"));
            }
            let safe_name = local_sync::id_to_filename(&id);
            let file_path = std::path::PathBuf::from(&sync_folder)
                .join("conversations")
                .join(&agent)
                .join(format!("{safe_name}.json"));
            if !file_path.exists() {
                return Err(format!("Conversation {id} not found"));
            }
            let body = std::fs::read(&file_path)
                .map_err(|e| format!("Failed to read synced conversation: {e}"))?;
            serde_json::from_slice::<Conversation>(&body)
                .map_err(|e| format!("Failed to parse synced conversation: {e}"))?
        }
    };

    let storage_path = resolve_storage_path(&agent, &id);
    let resume_command = build_resume_command(&agent, &id);
    if let Ok(store) = MemoryStore::open_app() {
        let _ = sync_conversation_into_store(&store, &agent, &conversation);
    }
    Ok(convert_conversation(conversation, storage_path, resume_command))
}
```

---

## 验证步骤

1. 安装修改后的 macOS 版本
2. 打开 ChatMem，确保 OneDrive 同步文件夹已配置
3. 点击「同步」
4. 切换到任意来源（Claude / Codex / Hermes / ZCode）
5. 检查是否出现 Windows 路径（如 `C:/Users/xxx`）的项目
6. 点击进入项目，确认能正常查看对话内容

## 注意事项

- 两个平台必须使用**完全相同**的 `id_to_filename` / `filename_to_id` 实现
- 已有的原始冒号文件名（macOS 之前写入的）仍可正常读取，`filename_to_id` 不会改变不含编码的字符串
- 首次同步后，macOS 端的旧冒号文件名会被新的 `&#x3a;` 编码文件名覆盖（时间戳更新的一方胜出）

---

## 5. 机器分组功能（`src/App.tsx` + `src/settings/storage.ts` + `src/styles.css`）

**功能说明**：当用户有来自多台电脑的对话时（如一台 Windows + 一台 Mac），在项目列表上方自动显示机器分组层。单台电脑时不显示此层，不影响现有 UI。

### 5a. 添加 `detectMachineId` 工具函数（`src/App.tsx`）

在 `getProjectLabel` 函数附近添加：

```typescript
function detectMachineId(projectDir: string): string {
  const normalized = projectDir.replace(/\\/g, "/");
  // Windows: C:/Users/xxx or D:/xxx
  const windowsMatch = normalized.match(/^([a-zA-Z]):\/(?:Users\/([^/]+))?/);
  if (windowsMatch) {
    const user = windowsMatch[2] || "default";
    return `windows:${user.toLowerCase()}`;
  }
  // macOS: /Users/xxx or /Volumes/xxx
  const macUsersMatch = normalized.match(/^\/Users\/([^/]+)/);
  if (macUsersMatch) {
    return `macos:${macUsersMatch[1].toLowerCase()}`;
  }
  const macVolumesMatch = normalized.match(/^\/Volumes\/([^/]+)/);
  if (macVolumesMatch) {
    return `macos:${macVolumesMatch[1].toLowerCase()}`;
  }
  // Other
  const segments = normalized.split("/").filter(Boolean);
  return `other:${(segments[0] || "unknown").toLowerCase()}`;
}
```

### 5b. 设置中添加 `machineGroupNames`（`src/settings/storage.ts`）

在 `AppSettings` 类型中添加：

```typescript
machineGroupNames: Record<string, string>;
```

默认值：`machineGroupNames: {}`

在 `normalizeAppSettings` 中添加：

```typescript
machineGroupNames:
  typeof parsed.machineGroupNames === "object" && parsed.machineGroupNames !== null
    ? (parsed.machineGroupNames as Record<string, string>)
    : {},
```

### 5c. 添加 `machineGroups` memo 和渲染逻辑（`src/App.tsx`）

在 `zcodeProjectCliGroups` 之后添加：

```typescript
const [expandedMachineGroups, setExpandedMachineGroups] = useState<Record<string, boolean>>({});
const [renamingMachineGroup, setRenamingMachineGroup] = useState<string | null>(null);
const [machineGroupRenameValue, setMachineGroupRenameValue] = useState("");

const machineGroups = useMemo(() => {
  const groups = new Map<string, {
    id: string;
    autoLabel: string;
    projects: ProjectGroup[];
    conversationCount: number;
    latestAt: string;
  }>();

  projectGroups.forEach((pg) => {
    const machineId = detectMachineId(pg.fullPath);
    const existing = groups.get(machineId);
    if (existing) {
      existing.projects.push(pg);
      existing.conversationCount += pg.conversations.length;
      if (pg.latestAt > existing.latestAt) existing.latestAt = pg.latestAt;
    } else {
      groups.set(machineId, {
        id: machineId,
        autoLabel: machineId, // Will be refined below
        projects: [pg],
        conversationCount: pg.conversations.length,
        latestAt: pg.latestAt,
      });
    }
  });

  // Refine auto-labels
  const platformCounts = new Map<string, number>();
  groups.forEach((g) => {
    const platform = g.id.split(":")[0];
    platformCounts.set(platform, (platformCounts.get(platform) || 0) + 1);
  });

  const platformIndices = new Map<string, number>();
  groups.forEach((g) => {
    const [platform, user] = g.id.split(":");
    const count = platformCounts.get(platform) || 1;
    if (count === 1) {
      g.autoLabel = platform === "windows" ? "Windows" : platform === "macos" ? "Mac" : platform;
    } else {
      const idx = (platformIndices.get(platform) || 0) + 1;
      platformIndices.set(platform, idx);
      g.autoLabel = `${platform === "windows" ? "Windows" : platform === "macos" ? "Mac" : platform}-${idx}`;
    }
  });

  return Array.from(groups.values()).sort((a, b) => b.latestAt.localeCompare(a.latestAt));
}, [projectGroups]);

const getMachineGroupLabel = (groupId: string) => {
  return appSettings.machineGroupNames[groupId] ||
    machineGroups.find((g) => g.id === groupId)?.autoLabel ||
    groupId;
};
```

### 5d. 渲染机器分组（`src/App.tsx`）

在渲染项目列表的地方，用机器分组包裹（仅当 `machineGroups.length > 1` 时）：

```tsx
{machineGroups.length > 1 ? (
  <div className="machine-group-list">
    {machineGroups.map((mg) => {
      const isExpanded = expandedMachineGroups[mg.id] !== false;
      const label = getMachineGroupLabel(mg.id);
      return (
        <div key={mg.id} className="machine-group">
          <div
            className="machine-group-header"
            onClick={() =>
              setExpandedMachineGroups((prev) => ({ ...prev, [mg.id]: !isExpanded }))
            }
          >
            <button className="machine-group-chevron-btn">
              <span className={`machine-group-chevron ${isExpanded ? "expanded" : ""}`}>▶</span>
            </button>
            {renamingMachineGroup === mg.id ? (
              <input
                className="machine-group-rename-input"
                value={machineGroupRenameValue}
                onChange={(e) => setMachineGroupRenameValue(e.target.value)}
                onBlur={() => {
                  const trimmed = machineGroupRenameValue.trim();
                  if (trimmed) {
                    saveSettings({
                      ...appSettings,
                      machineGroupNames: { ...appSettings.machineGroupNames, [mg.id]: trimmed },
                    });
                  }
                  setRenamingMachineGroup(null);
                }}
                onKeyDown={(e) => {
                  if (e.key === "Enter") e.currentTarget.blur();
                  if (e.key === "Escape") setRenamingMachineGroup(null);
                }}
                autoFocus
                onClick={(e) => e.stopPropagation()}
              />
            ) : (
              <span
                className="machine-group-label"
                onDoubleClick={(e) => {
                  e.stopPropagation();
                  setRenamingMachineGroup(mg.id);
                  setMachineGroupRenameValue(label);
                }}
              >
                {label}
              </span>
            )}
            <span className="machine-group-count-pill">{mg.conversationCount}</span>
          </div>
          {isExpanded && (
            <div className="machine-project-group-list">
              {mg.projects.map((group) => renderProjectGroup(group))}
            </div>
          )}
        </div>
      );
    })}
  </div>
) : (
  <div className="project-group-list">
    {projectGroups.map((group) => renderProjectGroup(group))}
  </div>
)}
```

### 5e. CSS 样式（`src/styles.css`）

```css
.machine-group-list {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.machine-group { }
.machine-group-header {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 6px 10px;
  border-radius: 8px;
  cursor: pointer;
  user-select: none;
  font-weight: 600;
  font-size: 13px;
  color: var(--text-primary, #1a1a1a);
  background: var(--bg-secondary, #f5f5f5);
}
.machine-group-header:hover {
  background: var(--bg-hover, #eaeaea);
}
.machine-group-chevron-btn {
  background: none; border: none; padding: 0; cursor: pointer;
  display: flex; align-items: center;
}
.machine-group-chevron {
  font-size: 10px; transition: transform 0.15s;
  color: var(--text-secondary, #888);
}
.machine-group-chevron.expanded { transform: rotate(90deg); }
.machine-group-label { flex: 1; }
.machine-group-rename-input {
  flex: 1; font-size: 13px; font-weight: 600;
  border: 1px solid var(--accent, #4caf50); border-radius: 4px;
  padding: 2px 6px; outline: none;
}
.machine-group-count-pill {
  font-size: 11px; font-weight: 500; padding: 1px 7px;
  border-radius: 10px; background: var(--bg-tertiary, #e0e0e0);
  color: var(--text-secondary, #666);
}
.machine-project-group-list {
  display: flex; flex-direction: column; gap: 2px;
  padding-left: 16px;
}
```

### 验证

1. 安装修改后的 macOS 版本
2. 确保有来自 Windows 和 Mac 的对话（通过 OneDrive 同步）
3. 切换到任意来源，检查是否出现机器分组
4. 双击分组名称可以重命名
5. 单台电脑时不应出现分组层
