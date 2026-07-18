#!/usr/bin/env node
// Cross-platform launcher for the chatmem-mcp stdio server.
// Mirrors mcp/run-chatmem-mcp.ps1 so the repo-level .mcp.json works on
// macOS, Linux, and Windows.

import { spawn } from "node:child_process";
import { existsSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = process.env.CHATMEM_REPO_ROOT
  ? resolve(process.env.CHATMEM_REPO_ROOT)
  : resolve(scriptDir, "..");

const binaryName = process.platform === "win32" ? "chatmem-mcp.exe" : "chatmem-mcp";

function resolveBinary() {
  if (process.env.CHATMEM_MCP_BIN && existsSync(process.env.CHATMEM_MCP_BIN)) {
    return resolve(process.env.CHATMEM_MCP_BIN);
  }

  const candidates = [
    join(repoRoot, "src-tauri", "target", "release", binaryName),
    join(repoRoot, ".tauri-target-build", "release", binaryName),
    join(repoRoot, "src-tauri", "target", "debug", binaryName),
  ]
    .filter((p) => existsSync(p))
    .sort((a, b) => statSync(b).mtimeMs - statSync(a).mtimeMs);

  return candidates[0] ?? null;
}

const binary = resolveBinary();
if (!binary) {
  console.error(
    "chatmem-mcp binary not found. Build the MCP server with `cargo build --release --bin chatmem-mcp` in src-tauri, or set CHATMEM_MCP_BIN."
  );
  process.exit(1);
}

const child = spawn(binary, process.argv.slice(2), { stdio: "inherit" });
child.on("error", (err) => {
  console.error(`failed to launch chatmem-mcp: ${err.message}`);
  process.exit(1);
});
child.on("exit", (code, signal) => {
  if (signal) {
    process.kill(process.pid, signal);
    return;
  }
  process.exit(code ?? 0);
});
