import { beforeEach, describe, expect, it, vi } from "vitest";

const mockInvoke = vi.fn();
const mockCheckUpdate = vi.fn();
const mockInstallUpdate = vi.fn();
const mockRelaunch = vi.fn();

vi.mock("@tauri-apps/api/tauri", () => ({
  invoke: (...args: unknown[]) => mockInvoke(...args),
}));

vi.mock("@tauri-apps/api/updater", () => ({
  checkUpdate: () => mockCheckUpdate(),
  installUpdate: () => mockInstallUpdate(),
}));

vi.mock("@tauri-apps/api/process", () => ({
  relaunch: () => mockRelaunch(),
}));

import { installAvailableUpdate, runUpdateCheck } from "../updater/updater";

const WINDOWS_ONLY_ERROR = "github release installer is only available on windows";

beforeEach(() => {
  mockInvoke.mockReset();
  mockCheckUpdate.mockReset();
  mockInstallUpdate.mockReset();
  mockRelaunch.mockReset();
});

describe("runUpdateCheck", () => {
  it("reports an available update from the GitHub release command", async () => {
    mockInvoke.mockResolvedValue({
      shouldUpdate: true,
      version: "1.3.6",
      notes: "notes",
      publishedAt: "2026-07-22T00:00:00Z",
      assetName: null,
    });

    const state = await runUpdateCheck();

    expect(state).toEqual({
      kind: "available",
      version: "1.3.6",
      notes: "notes",
      publishedAt: "2026-07-22T00:00:00Z",
    });
    expect(mockCheckUpdate).not.toHaveBeenCalled();
  });
});

describe("installAvailableUpdate", () => {
  it("uses the direct installer when the native command succeeds (Windows)", async () => {
    mockInvoke.mockResolvedValue({ shouldUpdate: true, version: "1.3.6" });

    const state = await installAvailableUpdate("1.3.6");

    expect(state).toEqual({ kind: "installing", version: "1.3.6" });
    expect(mockCheckUpdate).not.toHaveBeenCalled();
    expect(mockInstallUpdate).not.toHaveBeenCalled();
    expect(mockRelaunch).not.toHaveBeenCalled();
  });

  it("runs checkUpdate before installUpdate on the signed-updater fallback", async () => {
    mockInvoke.mockRejectedValue(new Error(WINDOWS_ONLY_ERROR));
    mockCheckUpdate.mockResolvedValue({ shouldUpdate: true, manifest: { version: "1.3.6" } });
    mockInstallUpdate.mockResolvedValue(undefined);
    mockRelaunch.mockResolvedValue(undefined);
    const callOrder: string[] = [];
    mockCheckUpdate.mockImplementation(async () => {
      callOrder.push("checkUpdate");
      return { shouldUpdate: true, manifest: { version: "1.3.6" } };
    });
    mockInstallUpdate.mockImplementation(async () => {
      callOrder.push("installUpdate");
    });

    const state = await installAvailableUpdate("1.3.6");

    expect(state).toEqual({ kind: "installing", version: "1.3.6" });
    expect(callOrder).toEqual(["checkUpdate", "installUpdate"]);
    expect(mockRelaunch).toHaveBeenCalledTimes(1);
  });

  it("does not install when the signed updater reports no update", async () => {
    mockInvoke.mockRejectedValue(new Error(WINDOWS_ONLY_ERROR));
    mockCheckUpdate.mockResolvedValue({ shouldUpdate: false });

    const state = await installAvailableUpdate("1.3.6");

    expect(state).toEqual({ kind: "up-to-date" });
    expect(mockInstallUpdate).not.toHaveBeenCalled();
    expect(mockRelaunch).not.toHaveBeenCalled();
  });

  it("propagates unexpected errors from the native command", async () => {
    mockInvoke.mockRejectedValue(new Error("network unreachable"));

    await expect(installAvailableUpdate("1.3.6")).rejects.toThrow("network unreachable");
    expect(mockCheckUpdate).not.toHaveBeenCalled();
  });
});
