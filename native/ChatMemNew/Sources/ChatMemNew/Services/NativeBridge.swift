import Foundation

protocol NativeBridge: AnyObject {
    func loadSnapshot() -> AppSnapshot
}

final class SampleNativeBridge: NativeBridge {
    func loadSnapshot() -> AppSnapshot {
        let conversations = [
            ConversationSummary(
                id: "codex-chatmem-native",
                sourceAgent: .codex,
                projectDirectory: "/Volumes/DouXY/download/ChatMem",
                title: "Native AppKit rewrite guardrails",
                updatedAt: "Today 07:42",
                messageCount: 34,
                fileCount: 9,
                storagePath: "~/.codex/history/chatmem-native.jsonl",
                resumeCommand: "codex resume chatmem-native",
                isFavorite: true,
                isTrashed: false
            ),
            ConversationSummary(
                id: "claude-memory-bootstrap",
                sourceAgent: .claude,
                projectDirectory: "/Volumes/DouXY/download/ChatMem",
                title: "Approved memory bootstrap scan",
                updatedAt: "Yesterday 22:10",
                messageCount: 118,
                fileCount: 22,
                storagePath: "~/.claude/projects/chatmem/transcript.jsonl",
                resumeCommand: "claude --continue",
                isFavorite: false,
                isTrashed: false
            ),
            ConversationSummary(
                id: "zcode-sync-debug",
                sourceAgent: .zcode,
                projectDirectory: "/Volumes/DouXY/download/ChatMem",
                title: "ZCode sync diagnostics and fallback",
                updatedAt: "Jun 24 18:06",
                messageCount: 67,
                fileCount: 14,
                storagePath: "~/.zcode/history/sync-debug.jsonl",
                resumeCommand: "zcode resume sync-debug",
                isFavorite: false,
                isTrashed: true
            )
        ]

        let details = Dictionary(uniqueKeysWithValues: conversations.map { summary in
            (
                summary.id,
                ConversationDetail(
                    summary: summary,
                    messages: [
                        ConversationMessage(
                            id: "\(summary.id)-1",
                            role: "user",
                            timestamp: summary.updatedAt,
                            content: "Continue the ChatMem work without breaking the installed baseline.",
                            toolCalls: []
                        ),
                        ConversationMessage(
                            id: "\(summary.id)-2",
                            role: "assistant",
                            timestamp: summary.updatedAt,
                            content: "Loaded project memory, preserved the Tauri baseline, and scoped the native AppKit target as a parallel app.",
                            toolCalls: [
                                ToolCall(id: "\(summary.id)-tool", name: "scan_repo_conversations", status: "completed", output: "3 relevant history records")
                            ]
                        )
                    ],
                    fileChanges: [
                        FileChange(id: "\(summary.id)-file-1", path: "docs/superpowers/specs/2026-06-26-chatmem-native-appkit-parallel-design.md", changeType: "created"),
                        FileChange(id: "\(summary.id)-file-2", path: "native/ChatMemNew", changeType: "planned")
                    ],
                    continuationPrompt: "Use ChatMem to continue this project with low-token context. Preserve old UI information architecture and do not replace /Applications/ChatMem.app."
                )
            )
        })

        return AppSnapshot(
            conversations: conversations,
            details: details,
            memoryCandidates: [
                MemoryCandidate(id: "cand-1", title: "Keep replacement confirmation-gated", value: "Do not replace /Applications/ChatMem.app until native parity is confirmed.", reason: "Prevents losing the working baseline."),
                MemoryCandidate(id: "cand-2", title: "Prefer bridge boundary", value: "Native UI should depend on NativeBridge instead of direct backend transport.", reason: "Keeps Rust/helper/Swift choices interchangeable.")
            ],
            approvedMemories: [
                ApprovedMemory(id: "mem-1", title: "Native rewrite parity bar", usageHint: "Preserve old information architecture and full feature behavior.", freshness: "fresh"),
                ApprovedMemory(id: "mem-2", title: "OneDrive machine path", usageHint: "Use /Volumes/DouXY/.CloudStorage/Data/OneDrive-个人/ for OneDrive tasks.", freshness: "fresh")
            ],
            wikiPages: [
                WikiPage(id: "wiki-1", title: "Project Overview", preview: "ChatMem is a local-first memory and migration control plane for coding agents."),
                WikiPage(id: "wiki-2", title: "Risk Ledger", preview: "Native UI must not become a polished but nonfunctional shell.")
            ],
            checkpoints: [
                Checkpoint(id: "cp-1", summary: "Native AppKit plan approved", resumeCommand: "codex resume native-chatmem")
            ],
            handoffs: [
                HandoffPacket(id: "handoff-1", fromAgent: .codex, toAgent: .claude, goal: "Review AppKit parity surfaces", nextItem: "Compare sidebar grouping and memory drawer behavior.")
            ],
            runs: [
                RunRecord(id: "run-1", title: "Native target bootstrap", status: "active", artifactCount: 1)
            ],
            artifacts: [
                ArtifactRecord(id: "artifact-1", title: "Design spec", summary: "Parallel AppKit target scope and acceptance criteria.")
            ],
            episodes: [
                EpisodeRecord(id: "episode-1", title: "Decision", summary: "Create native app in parallel directory and keep old Tauri app untouched.")
            ],
            repoHealth: RepoHealth(indexedConversations: 219, pendingCandidates: 2, aliasWarnings: ["One old cwd can be merged into the current repo alias."], bootstrapReady: true)
        )
    }
}
