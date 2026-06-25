import { invoke } from "@tauri-apps/api/tauri";
import type { Locale } from "../i18n/types";

export type SyncProvider = "off" | "webdav" | "onedrive";
export type WebDavScheme = "https" | "http";
export type DownloadMode = "on-sync" | "as-needed";
export type AppFontFamily = "system" | "source-sans" | "source-serif" | "wenkai";

export type FavoriteConversationSnapshot = {
  id: string;
  sourceAgent: string;
  projectDir: string;
  title: string;
  createdAt: string;
  updatedAt: string;
  note: string;
  tags: string[];
  pinned: boolean;
};

export const APP_FONT_OPTIONS: Array<{
  id: AppFontFamily;
  label: Record<Locale, string>;
  cssFamily: string;
}> = [
  {
    id: "system",
    label: {
      "zh-CN": "系统默认",
      en: "System",
    },
    cssFamily:
      '"Segoe UI Variable Text", "Segoe UI", "PingFang SC", "Microsoft YaHei UI", system-ui, sans-serif',
  },
  {
    id: "source-sans",
    label: {
      "zh-CN": "思源黑体 / Noto Sans",
      en: "Source Han Sans / Noto Sans",
    },
    cssFamily:
      '"Noto Sans CJK SC", "Source Han Sans SC", "思源黑体", "Microsoft YaHei UI", "PingFang SC", sans-serif',
  },
  {
    id: "source-serif",
    label: {
      "zh-CN": "思源宋体 / Noto Serif",
      en: "Source Han Serif / Noto Serif",
    },
    cssFamily:
      '"Noto Serif CJK SC", "Source Han Serif SC", "思源宋体", "Songti SC", "SimSun", serif',
  },
  {
    id: "wenkai",
    label: {
      "zh-CN": "霞鹜文楷 / 楷体",
      en: "LXGW WenKai / Kaiti",
    },
    cssFamily: '"LXGW WenKai", "霞鹜文楷", "Kaiti SC", "STKaiti", "KaiTi", cursive',
  },
];

export type SyncSettings = {
  provider: SyncProvider;
  webdavScheme: WebDavScheme;
  webdavHost: string;
  webdavPath: string;
  username: string;
  password?: string;
  remotePath: string;
  downloadMode: DownloadMode;
  syncFolder: string;
};

export type AppSettings = {
  locale: Locale;
  fontFamily: AppFontFamily;
  autoCheckUpdates: boolean;
  autoCaptureMemory: boolean;
  trashRetentionDays: number;
  sync: SyncSettings;
  autoBackupEnabled: boolean;
  autoBackupIntervalMinutes: number;
  favorites: FavoriteConversationSnapshot[];
  machineGroupNames: Record<string, string>;
  machineGroupOverrides: Record<string, string>;
  favoriteConversations: Record<string, FavoriteConversationSnapshot>;
};

export const SETTINGS_STORAGE_KEY = "chatmem.settings";

export const DEFAULT_SYNC_SETTINGS: SyncSettings = {
  provider: "off",
  webdavScheme: "https",
  webdavHost: "",
  webdavPath: "",
  username: "",
  remotePath: "chatmem",
  downloadMode: "on-sync",
  syncFolder: "",
};

export const DEFAULT_SETTINGS: AppSettings = {
  locale: "zh-CN",
  fontFamily: "system",
  autoCheckUpdates: true,
  autoCaptureMemory: true,
  trashRetentionDays: 14,
  sync: DEFAULT_SYNC_SETTINGS,
  autoBackupEnabled: false,
  autoBackupIntervalMinutes: 30,
  favorites: [],
  machineGroupNames: {},
  machineGroupOverrides: {},
  favoriteConversations: {},
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value && typeof value === "object" && !Array.isArray(value));
}

function isAppFontFamily(value: unknown): value is AppFontFamily {
  return typeof value === "string" && APP_FONT_OPTIONS.some((option) => option.id === value);
}

export function normalizeSyncSettings(value: unknown): SyncSettings {
  if (!isRecord(value)) {
    return DEFAULT_SYNC_SETTINGS;
  }

  const parsed = value as Partial<SyncSettings> & { webdavUrl?: string; syncMode?: string };
  const parsedUrl = splitWebDavUrl(parsed.webdavUrl);

  return {
    provider: parsed.provider === "webdav" || parsed.provider === "onedrive" ? parsed.provider : "off",
    webdavScheme:
      parsed.webdavScheme === "http" || parsed.webdavScheme === "https"
        ? parsed.webdavScheme
        : parsedUrl.webdavScheme,
    webdavHost:
      typeof parsed.webdavHost === "string" ? parsed.webdavHost : parsedUrl.webdavHost,
    webdavPath:
      typeof parsed.webdavPath === "string" ? parsed.webdavPath : parsedUrl.webdavPath,
    username: typeof parsed.username === "string" ? parsed.username : "",
    password: typeof parsed.password === "string" ? parsed.password : undefined,
    remotePath: typeof parsed.remotePath === "string" && parsed.remotePath.trim() ? parsed.remotePath : "chatmem",
    downloadMode: parsed.downloadMode === "as-needed" ? "as-needed" : "on-sync",
    syncFolder: typeof parsed.syncFolder === "string" ? parsed.syncFolder : "",
  };
}

function normalizeStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .filter((item): item is string => typeof item === "string")
    .map((item) => item.trim())
    .filter(Boolean);
}

export function normalizeFavoriteSnapshot(value: unknown): FavoriteConversationSnapshot | null {
  if (!isRecord(value)) {
    return null;
  }

  const raw = value as Partial<FavoriteConversationSnapshot> & {
    summary?: unknown;
    source_agent?: unknown;
    project_dir?: unknown;
    created_at?: unknown;
    updated_at?: unknown;
  };
  const id = typeof raw.id === "string" ? raw.id.trim() : "";
  const sourceAgent =
    typeof raw.sourceAgent === "string"
      ? raw.sourceAgent.trim()
      : typeof raw.source_agent === "string"
        ? raw.source_agent.trim()
        : "";

  if (!id || !sourceAgent) {
    return null;
  }

  return {
    id,
    sourceAgent,
    projectDir:
      typeof raw.projectDir === "string"
        ? raw.projectDir
        : typeof raw.project_dir === "string"
          ? raw.project_dir
          : "",
    title:
      typeof raw.title === "string" && raw.title.trim()
        ? raw.title.trim()
        : typeof raw.summary === "string" && raw.summary.trim()
          ? raw.summary.trim()
          : id,
    createdAt:
      typeof raw.createdAt === "string"
        ? raw.createdAt
        : typeof raw.created_at === "string"
          ? raw.created_at
          : "",
    updatedAt:
      typeof raw.updatedAt === "string"
        ? raw.updatedAt
        : typeof raw.updated_at === "string"
          ? raw.updated_at
          : "",
    note: typeof raw.note === "string" ? raw.note : "",
    tags: normalizeStringArray(raw.tags),
    pinned: raw.pinned === true,
  };
}

function normalizeFavorites(value: unknown): FavoriteConversationSnapshot[] {
  if (!Array.isArray(value)) {
    return [];
  }

  const seen = new Set<string>();
  const favorites: FavoriteConversationSnapshot[] = [];

  value.forEach((item) => {
    const favorite = normalizeFavoriteSnapshot(item);
    if (!favorite) {
      return;
    }
    const key = `${favorite.sourceAgent}:${favorite.id}`;
    if (seen.has(key)) {
      return;
    }
    seen.add(key);
    favorites.push(favorite);
  });

  return favorites;
}

function splitWebDavUrl(value: unknown): Pick<SyncSettings, "webdavScheme" | "webdavHost" | "webdavPath"> {
  if (typeof value !== "string" || !value.trim()) {
    return {
      webdavScheme: "https",
      webdavHost: "",
      webdavPath: "",
    };
  }

  try {
    const url = new URL(value);
    return {
      webdavScheme: url.protocol === "http:" ? "http" : "https",
      webdavHost: url.host,
      webdavPath: url.pathname.replace(/^\/+|\/+$/g, ""),
    };
  } catch {
    return {
      webdavScheme: "https",
      webdavHost: value.replace(/^https?:\/\//, "").replace(/^\/+|\/+$/g, ""),
      webdavPath: "",
    };
  }
}

function normalizeFavoriteConversations(value: unknown): Record<string, FavoriteConversationSnapshot> {
  if (!isRecord(value)) {
    return {};
  }

  return Object.fromEntries(
    Object.entries(value).flatMap(([key, rawSnapshot]) => {
      if (!isRecord(rawSnapshot)) {
        return [];
      }

      const snapshot = rawSnapshot as Partial<FavoriteConversationSnapshot> & {
        summary?: unknown;
      };
      if (
        typeof key !== "string" ||
        typeof snapshot.id !== "string" ||
        typeof snapshot.sourceAgent !== "string"
      ) {
        return [];
      }

      return [
        [
          key,
          {
            id: snapshot.id,
            sourceAgent: snapshot.sourceAgent,
            projectDir: typeof snapshot.projectDir === "string" ? snapshot.projectDir : "",
            createdAt: typeof snapshot.createdAt === "string" ? snapshot.createdAt : "",
            updatedAt: typeof snapshot.updatedAt === "string" ? snapshot.updatedAt : "",
            title:
              typeof snapshot.title === "string" && snapshot.title.trim()
                ? snapshot.title.trim()
                : typeof snapshot.summary === "string" && snapshot.summary.trim()
                  ? snapshot.summary.trim()
                  : snapshot.id,
            note: typeof snapshot.note === "string" ? snapshot.note : "",
            tags: Array.isArray(snapshot.tags)
              ? snapshot.tags.filter((tag): tag is string => typeof tag === "string")
              : [],
            pinned: snapshot.pinned === true,
          },
        ],
      ];
    }),
  );
}

export function normalizeAppSettings(value: unknown): AppSettings {
  if (!isRecord(value)) {
    return DEFAULT_SETTINGS;
  }

  const parsed = value as Partial<AppSettings>;
  const fontFamily = isAppFontFamily(parsed.fontFamily)
    ? parsed.fontFamily
    : DEFAULT_SETTINGS.fontFamily;
  const parsedRetention =
    typeof parsed.trashRetentionDays === "number" && Number.isFinite(parsed.trashRetentionDays)
      ? Math.round(parsed.trashRetentionDays)
      : DEFAULT_SETTINGS.trashRetentionDays;

  return {
    locale: parsed.locale === "en" ? "en" : "zh-CN",
    fontFamily,
    autoCheckUpdates: parsed.autoCheckUpdates !== false,
    autoCaptureMemory: parsed.autoCaptureMemory !== false,
    trashRetentionDays: Math.min(365, Math.max(1, parsedRetention)),
    sync: normalizeSyncSettings(parsed.sync),
    autoBackupEnabled: parsed.autoBackupEnabled === true,
    autoBackupIntervalMinutes:
      typeof parsed.autoBackupIntervalMinutes === "number" && parsed.autoBackupIntervalMinutes >= 5
        ? parsed.autoBackupIntervalMinutes
        : 30,
    favorites: normalizeFavorites(parsed.favorites),
    machineGroupNames: isRecord(parsed.machineGroupNames)
      ? Object.fromEntries(
          Object.entries(parsed.machineGroupNames).filter(
            ([key, value]) => typeof key === "string" && typeof value === "string",
          ),
        )
      : {},
    machineGroupOverrides: isRecord(parsed.machineGroupOverrides)
      ? Object.fromEntries(
          Object.entries(parsed.machineGroupOverrides).filter(
            ([key, value]) => typeof key === "string" && typeof value === "string",
          ),
        )
      : {},
    favoriteConversations: normalizeFavoriteConversations(parsed.favoriteConversations),
  };
}

export function loadSettings(): AppSettings {
  try {
    const raw = localStorage.getItem(SETTINGS_STORAGE_KEY);
    if (!raw) {
      return DEFAULT_SETTINGS;
    }

    const parsed = JSON.parse(raw) as Partial<AppSettings>;
    return normalizeAppSettings(parsed);
  } catch {
    return DEFAULT_SETTINGS;
  }
}

export function saveSettings(settings: AppSettings) {
  localStorage.setItem(SETTINGS_STORAGE_KEY, JSON.stringify(settings));
  void saveNativeSettings(settings);
}

export function updateSettings(patch: Partial<AppSettings>) {
  const nextSettings = { ...loadSettings(), ...patch };
  saveSettings(nextSettings);
  return nextSettings;
}

export async function loadNativeSettings(): Promise<AppSettings | null> {
  try {
    const settings = await invoke<unknown>("load_app_settings");
    if (!isRecord(settings)) {
      return null;
    }
    return normalizeAppSettings(settings);
  } catch {
    return null;
  }
}

export async function saveNativeSettings(settings: AppSettings): Promise<void> {
  try {
    await invoke("save_app_settings", { settings: normalizeAppSettings(settings) });
  } catch {
    // localStorage remains the compatibility fallback when the native app bridge is unavailable.
  }
}

export async function loadWebDavPassword(username: string): Promise<string | null> {
  const trimmedUsername = username.trim();
  if (!trimmedUsername) {
    return null;
  }

  try {
    const password = await invoke<unknown>("load_webdav_password", { username: trimmedUsername });
    return typeof password === "string" ? password : null;
  } catch {
    return null;
  }
}

export async function saveWebDavPassword(username: string, password: string): Promise<void> {
  const trimmedUsername = username.trim();
  if (!trimmedUsername || !password) {
    return;
  }

  try {
    await invoke("save_webdav_password", { username: trimmedUsername, password });
  } catch {
    // Keep sync usable even if the OS credential store is unavailable.
  }
}
