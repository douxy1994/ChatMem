import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const styles = readFileSync(resolve(process.cwd(), "src/styles.css"), "utf8");

function ruleFor(selector: string) {
  const escaped = selector.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const match = styles.match(new RegExp(`${escaped}\\s*\\{(?<body>[^}]+)\\}`, "u"));
  return match?.groups?.body ?? "";
}

function mediaRuleFor(query: string, selector: string) {
  const mediaStart = styles.indexOf(`@media ${query}`);
  if (mediaStart === -1) {
    return "";
  }

  const selectorStart = styles.indexOf(selector, mediaStart);
  if (selectorStart === -1) {
    return "";
  }

  const bodyStart = styles.indexOf("{", selectorStart);
  const bodyEnd = styles.indexOf("}", bodyStart);
  return bodyStart === -1 || bodyEnd === -1 ? "" : styles.slice(bodyStart + 1, bodyEnd);
}

describe("conversation layout CSS", () => {
  it("lets the right conversation workspace shrink inside the app frame", () => {
    [
      ".conversation-workspace",
      ".workspace-view-panel",
      ".workspace-view-panel-conversation",
      ".conversation-content-grid",
      ".conversation-content-grid > .conversation-detail",
      ".conversation-detail",
      ".stats",
      ".stat-item",
      ".message-list",
      ".message",
      ".message-shell",
    ].forEach((selector) => {
      expect(ruleFor(selector), selector).toContain("min-width: 0");
    });
  });

  it("prevents long conversation paths from defining the workspace min-content width", () => {
    expect(ruleFor(".conversation-meta-strip.compact")).toContain("min-width: 0");
    expect(ruleFor(".conversation-meta-strip.compact .meta-block")).toContain("min-width: 0");
    expect(ruleFor(".conversation-meta-strip.compact .meta-value")).toContain("overflow-wrap: anywhere");
  });

  it("lets conversation toolbar actions wrap instead of widening the workspace", () => {
    expect(ruleFor(".conversation-toolbar-actions")).toContain("flex-wrap: wrap");
    expect(ruleFor(".conversation-toolbar-actions")).toContain("max-width: min(");
  });

  it("keeps Trash header actions reachable in narrow workspaces", () => {
    expect(ruleFor(".trash-workspace-page")).toContain("width: min(");
    expect(ruleFor(".trash-workspace-page")).toContain("margin: 0 auto");
    expect(ruleFor(".trash-page-header")).toContain("flex-wrap: wrap");
    expect(ruleFor(".trash-page-header > div:first-child")).toContain("min-width: 0");
    expect(ruleFor(".trash-page-actions")).toContain("flex: 1 1");
    expect(ruleFor(".trash-page-actions")).toContain("min-width: 0");
    expect(ruleFor(".trash-page-actions")).toContain("justify-content: flex-start");
    expect(ruleFor(".trash-page-actions")).toContain("flex-wrap: wrap");
  });

  it("keeps the sidebar and workspace as adjacent panes at narrow widths", () => {
    expect(mediaRuleFor("(max-width: 960px)", ".app-body")).toContain(
      "grid-template-columns: minmax(236px, 32vw) minmax(0, 1fr)",
    );
    expect(mediaRuleFor("(max-width: 760px)", ".app-body")).toContain(
      "grid-template-columns: minmax(216px, 38vw) minmax(0, 1fr)",
    );
  });
});
