import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import App from "../App";
import { I18nProvider } from "../i18n/I18nProvider";
import { SETTINGS_STORAGE_KEY } from "../settings/storage";

const mockInvoke = vi.fn();
const mockEventListeners = new Map<string, (event: unknown) => void>();

vi.mock("@tauri-apps/api/tauri", () => ({
  invoke: (...args: unknown[]) => mockInvoke(...args),
}));

vi.mock("@tauri-apps/api/event", () => ({
  listen: vi.fn(async (eventName: string, handler: (event: unknown) => void) => {
    mockEventListeners.set(eventName, handler);
    return () => mockEventListeners.delete(eventName);
  }),
}));

vi.mock("@tauri-apps/api/updater", () => ({
  checkUpdate: vi.fn().mockResolvedValue({ shouldUpdate: false }),
  installUpdate: vi.fn().mockResolvedValue(undefined),
}));

vi.mock("@tauri-apps/api/process", () => ({
  relaunch: vi.fn().mockResolvedValue(undefined),
}));

vi.mock("@tauri-apps/api/window", () => ({
  appWindow: {
    minimize: vi.fn(),
    toggleMaximize: vi.fn(),
    close: vi.fn(),
  },
}));

function renderApp() {
  return render(
    <I18nProvider>
      <App />
    </I18nProvider>,
  );
}

async function openSettingsFromMenu() {
  await waitFor(() => {
    expect(mockEventListeners.has("open-settings")).toBe(true);
  });
  await act(async () => {
    mockEventListeners.get("open-settings")?.({});
  });
}

function selectWebDavSync() {
  fireEvent.change(screen.getByLabelText("Conversation data sync method:"), {
    target: { value: "webdav" },
  });
}

describe("Sync settings", () => {
  beforeEach(() => {
    localStorage.clear();
    localStorage.setItem(
      SETTINGS_STORAGE_KEY,
      JSON.stringify({ locale: "en", autoCheckUpdates: false, autoCaptureMemory: false }),
    );

    mockInvoke.mockReset();
    mockInvoke.mockResolvedValue([]);
    mockEventListeners.clear();
  });

  it("persists a Zotero-style WebDAV conversation-data profile without a fake provider dropdown", async () => {
    renderApp();

    await openSettingsFromMenu();
    expect(screen.queryByRole("heading", { name: "About ChatMem" })).toBeNull();
    expect(await screen.findByRole("heading", { name: "Conversation Data Sync" })).toBeTruthy();
    expect(screen.queryByText(/Use a generic WebDAV server/)).toBeNull();
    expect(screen.queryByText(/Account details/)).toBeNull();

    selectWebDavSync();
    expect((screen.getByLabelText("Conversation data sync method:") as HTMLSelectElement).value).toBe("webdav");
    expect(screen.queryByText(/Passwords are kept/)).toBeNull();
    fireEvent.change(screen.getByLabelText("Protocol"), {
      target: { value: "https" },
    });
    fireEvent.change(screen.getByLabelText("Server and path"), {
      target: { value: "example.com/webdav" },
    });
    fireEvent.change(screen.getByLabelText("Username"), {
      target: { value: "liang@example.com" },
    });
    fireEvent.change(screen.getByLabelText("Password"), {
      target: { value: "local-secret" },
    });
    fireEvent.change(screen.getByLabelText("Download files"), {
      target: { value: "as-needed" },
    });

    await waitFor(() => {
      const saved = JSON.parse(localStorage.getItem(SETTINGS_STORAGE_KEY) ?? "{}");
      expect(saved.sync).toEqual({
        provider: "webdav",
        webdavScheme: "https",
        webdavHost: "example.com",
        webdavPath: "webdav",
        username: "liang@example.com",
        remotePath: "chatmem",
        downloadMode: "as-needed",
        syncFolder: "",
      });
      expect(saved.sync.password).toBeUndefined();
      expect(JSON.stringify(saved.sync)).not.toContain("local-secret");
    });
  });

  it("restores WebDAV sync settings from the native settings file when browser storage was reset", async () => {
    localStorage.clear();
    mockInvoke.mockImplementation((command: string) => {
      if (command === "load_app_settings") {
        return Promise.resolve({
          locale: "en",
          autoCheckUpdates: false,
          sync: {
            provider: "webdav",
            webdavScheme: "https",
            webdavHost: "dav.example.com",
            webdavPath: "remote.php/dav/files/liang",
            username: "liang@example.com",
            remotePath: "chatmem",
            downloadMode: "as-needed",
          },
        });
      }
      if (command === "load_webdav_password") {
        return Promise.resolve("saved-secret");
      }
      return Promise.resolve([]);
    });

    renderApp();

    await openSettingsFromMenu();

    await waitFor(() => {
      expect(
        (screen.getByLabelText("Conversation data sync method:") as HTMLSelectElement).value,
      ).toBe("webdav");
      expect((screen.getByLabelText("Server and path") as HTMLInputElement).value).toBe(
        "dav.example.com/remote.php/dav/files/liang",
      );
      expect((screen.getByLabelText("Username") as HTMLInputElement).value).toBe(
        "liang@example.com",
      );
      expect((screen.getByLabelText("Password") as HTMLInputElement).value).toBe("saved-secret");
      expect((screen.getByLabelText("Download files") as HTMLSelectElement).value).toBe(
        "as-needed",
      );
    });

    expect(mockInvoke).toHaveBeenCalledWith("load_app_settings");
    expect(mockInvoke).toHaveBeenCalledWith("load_webdav_password", {
      username: "liang@example.com",
    });
    expect(JSON.parse(localStorage.getItem(SETTINGS_STORAGE_KEY) ?? "{}").sync).toEqual({
      provider: "webdav",
      webdavScheme: "https",
      webdavHost: "dav.example.com",
      webdavPath: "remote.php/dav/files/liang",
      username: "liang@example.com",
      remotePath: "chatmem",
      downloadMode: "as-needed",
      syncFolder: "",
    });
  });

  it("verifies the WebDAV server with the entered password and shows success", async () => {
    renderApp();

    await openSettingsFromMenu();
    selectWebDavSync();
    fireEvent.change(screen.getByLabelText("Protocol"), {
      target: { value: "https" },
    });
    fireEvent.change(screen.getByLabelText("Server and path"), {
      target: { value: "example.com/webdav" },
    });
    fireEvent.change(screen.getByLabelText("Username"), {
      target: { value: "liang@example.com" },
    });
    fireEvent.change(screen.getByLabelText("Password"), {
      target: { value: "local-secret" },
    });

    mockInvoke.mockResolvedValueOnce(undefined);
    fireEvent.click(screen.getByRole("button", { name: "Verify server" }));

    await waitFor(() => {
      expect(mockInvoke).toHaveBeenCalledWith("verify_webdav_server", {
        webdavScheme: "https",
        webdavHost: "example.com",
        webdavPath: "webdav",
        remotePath: "chatmem",
        username: "liang@example.com",
        password: "local-secret",
      });
      expect(mockInvoke).toHaveBeenCalledWith("save_webdav_password", {
        username: "liang@example.com",
        password: "local-secret",
      });
      expect(screen.getByText("Verification successful")).toBeTruthy();
    });
  });

  it("runs a real WebDAV sync after credentials are entered", async () => {
    renderApp();

    await openSettingsFromMenu();
    selectWebDavSync();
    fireEvent.change(screen.getByLabelText("Protocol"), {
      target: { value: "https" },
    });
    fireEvent.change(screen.getByLabelText("Server and path"), {
      target: { value: "example.com/webdav" },
    });
    fireEvent.change(screen.getByLabelText("Username"), {
      target: { value: "liang@example.com" },
    });
    fireEvent.change(screen.getByLabelText("Password"), {
      target: { value: "local-secret" },
    });

    mockInvoke.mockResolvedValueOnce({
      uploadedCount: 2,
      remoteUrl: "https://example.com/webdav/chatmem/",
    });
    fireEvent.click(screen.getByRole("button", { name: "Sync now" }));

    await waitFor(() => {
      expect(mockInvoke).toHaveBeenCalledWith("sync_webdav_now", {
        webdavScheme: "https",
        webdavHost: "example.com",
        webdavPath: "webdav",
        remotePath: "chatmem",
        username: "liang@example.com",
        password: "local-secret",
      });
      expect(screen.getByText("Synced 2 files to WebDAV")).toBeTruthy();
      expect(screen.getByText("Remote folder: https://example.com/webdav/chatmem/")).toBeTruthy();
    });
  });

  it("runs an upgrade readiness check from settings", async () => {
    mockInvoke.mockImplementation((command: string) => {
      if (command === "run_upgrade_readiness_check") {
        return Promise.resolve({
          status: "warning",
          summary: "Upgrade check found 1 item that needs attention.",
          checks: [
            {
              key: "settings",
              label: "Native settings file",
              status: "ok",
              detail: "Settings file is available.",
            },
            {
              key: "webdav_password",
              label: "WebDAV password",
              status: "warning",
              detail: "Password is not in the OS credential store.",
            },
            {
              key: "memory_store",
              label: "Memory database",
              status: "ok",
              detail: "Memory database can be opened.",
            },
          ],
          warnings: ["Password is not in the OS credential store."],
        });
      }
      return Promise.resolve([]);
    });

    renderApp();

    await openSettingsFromMenu();
    fireEvent.click(await screen.findByRole("button", { name: "Run upgrade check" }));

    await waitFor(() => {
      expect(mockInvoke).toHaveBeenCalledWith("run_upgrade_readiness_check");
      expect(screen.getByText("Upgrade check found 1 item that needs attention.")).toBeTruthy();
      expect(screen.getByText("Native settings file")).toBeTruthy();
      expect(screen.getByText("WebDAV password")).toBeTruthy();
      expect(screen.getByText("Memory database")).toBeTruthy();
    });
  });

  it("installs ChatMem MCP and Skill into local agents from settings", async () => {
    mockInvoke.mockImplementation((command: string, payload?: Record<string, unknown>) => {
      if (command === "detect_agent_integrations") {
        return Promise.resolve([
          {
            agent: "codex",
            label: "Codex",
            configPath: "C:/Users/demo/.codex/config.toml",
            instructionsPath: "C:/Users/demo/.codex/skills/chatmem/SKILL.md",
            mcpInstalled: false,
            instructionsInstalled: false,
            configExists: true,
            status: "not_installed",
            statusLabel: "Not installed",
            commandPreview: '"C:/Program Files/ChatMem/ChatMem.exe" --mcp',
            details: [],
          },
        ]);
      }

      if (command === "install_agent_integration") {
        expect(payload).toEqual({ agent: "all" });
        return Promise.resolve([
          {
            agent: "codex",
            label: "Codex",
            changed: true,
            message: "Codex integration installed.",
            backupPaths: [],
            status: {
              agent: "codex",
              label: "Codex",
              configPath: "C:/Users/demo/.codex/config.toml",
              instructionsPath: "C:/Users/demo/.agents/skills/chatmem/SKILL.md",
              mcpInstalled: true,
              instructionsInstalled: true,
              configExists: true,
              status: "ready",
              statusLabel: "Ready",
              commandPreview: '"C:/Program Files/ChatMem/ChatMem.exe" --mcp',
              details: [],
            },
          },
        ]);
      }

      return Promise.resolve([]);
    });

    renderApp();

    await openSettingsFromMenu();
    expect(await screen.findByRole("heading", { name: "Agent integration" })).toBeTruthy();
    expect((await screen.findAllByText("Codex")).length).toBeGreaterThan(0);
    expect(screen.getByText(/MCP plus each agent's native guidance entry/)).toBeTruthy();
    expect(screen.getAllByText("Guidance").length).toBeGreaterThan(0);

    fireEvent.click(screen.getByRole("button", { name: "Install all" }));

    await waitFor(() => {
      expect(mockInvoke).toHaveBeenCalledWith("install_agent_integration", { agent: "all" });
      expect(screen.getByText("Installed or repaired all detected integrations.")).toBeTruthy();
      expect(screen.getByText("Ready")).toBeTruthy();
    });
  });

  it("shows installed agent integrations before undeployed ones", async () => {
    mockInvoke.mockImplementation((command: string) => {
      if (command === "detect_agent_integrations") {
        return Promise.resolve([
          {
            agent: "codex",
            label: "Codex",
            configPath: "C:/Users/demo/.codex/config.toml",
            instructionsPath: "C:/Users/demo/.codex/skills/chatmem/SKILL.md",
            mcpInstalled: false,
            instructionsInstalled: false,
            configExists: true,
            status: "not_installed",
            statusLabel: "Not installed",
            commandPreview: '"C:/Program Files/ChatMem/ChatMem.exe" --mcp',
            details: [],
          },
          {
            agent: "claude",
            label: "Claude",
            configPath: "C:/Users/demo/.claude.json",
            instructionsPath: "C:/Users/demo/.claude/CLAUDE.md",
            mcpInstalled: true,
            instructionsInstalled: true,
            configExists: true,
            status: "ready",
            statusLabel: "Ready",
            commandPreview: '"C:/Program Files/ChatMem/ChatMem.exe" --mcp',
            details: [],
          },
        ]);
      }
      return Promise.resolve([]);
    });

    renderApp();

    await openSettingsFromMenu();
    const cards = await screen.findAllByRole("article");
    const integrationCards = cards.filter((card) =>
      card.classList.contains("agent-integration-card"),
    );

    expect(integrationCards).toHaveLength(2);
    expect(integrationCards[0].textContent).toContain("Claude");
    expect(integrationCards[1].textContent).toContain("Codex");
  });
});
