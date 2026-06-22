import { relaunch } from "@tauri-apps/api/process";
import { invoke } from "@tauri-apps/api/tauri";
import { checkUpdate, installUpdate } from "@tauri-apps/api/updater";

export type UpdateState =
  | { kind: "idle" }
  | { kind: "checking" }
  | { kind: "up-to-date" }
  | { kind: "available"; version: string; notes: string | null; publishedAt: string | null }
  | { kind: "installing"; version: string }
  | { kind: "error"; message: string };

type GithubUpdateCheck = {
  shouldUpdate: boolean;
  version: string;
  notes: string | null;
  publishedAt: string | null;
  assetName: string | null;
};

function isMissingNativeUpdateCommand(error: unknown) {
  const message = String(error).toLowerCase();
  return (
    message.includes("unknown command") ||
    message.includes("command not found") ||
    message.includes("not found: check_github_release_update") ||
    message.includes("not found: install_github_release_update")
  );
}

export async function runUpdateCheck(): Promise<UpdateState> {
  try {
    const result = await invoke<GithubUpdateCheck>("check_github_release_update");

    if (!result.shouldUpdate) {
      return { kind: "up-to-date" };
    }

    return {
      kind: "available",
      version: result.version,
      notes: result.notes,
      publishedAt: result.publishedAt,
    };
  } catch (error) {
    // Older installs may not have the native GitHub release command yet.
    if (!isMissingNativeUpdateCommand(error)) {
      throw error;
    }
  }

  const result = await checkUpdate();

  if (!result.shouldUpdate) {
    return { kind: "up-to-date" };
  }

  return {
    kind: "available",
    version: result.manifest?.version ?? "",
    notes: result.manifest?.body ?? null,
    publishedAt: result.manifest?.date ?? null,
  };
}

export async function installAvailableUpdate(version: string) {
  try {
    await invoke<GithubUpdateCheck>("install_github_release_update");
    return { kind: "installing", version } as const;
  } catch (error) {
    // Fall back to Tauri's signed updater when a latest.json manifest is available.
    if (!isMissingNativeUpdateCommand(error)) {
      throw error;
    }
  }

  await installUpdate();
  await relaunch();

  return { kind: "installing", version } as const;
}
