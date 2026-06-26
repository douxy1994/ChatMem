import Foundation

enum AgentKind: String, CaseIterable, Identifiable {
    case claude
    case codex
    case gemini
    case antigravity
    case opencode
    case zcode
    case hermes

    var id: String { rawValue }

    var label: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        case .gemini: "Gemini"
        case .antigravity: "Antigravity"
        case .opencode: "OpenCode"
        case .zcode: "ZCode"
        case .hermes: "Hermes"
        }
    }
}

enum WorkspaceDestination: Equatable {
    case workbench
    case conversation
    case localHistory
    case settings
    case favorites
    case trash
    case help
    case about
}

enum MemoryDrawerTab: String, CaseIterable {
    case review = "Review"
    case rules = "Rules"
    case wiki = "Wiki"
    case continuation = "Continue"
}

struct ConversationSummary: Identifiable, Equatable {
    let id: String
    let sourceAgent: AgentKind
    let projectDirectory: String
    let title: String
    let updatedAt: String
    let messageCount: Int
    let fileCount: Int
    let storagePath: String
    let resumeCommand: String
    let isFavorite: Bool
    let isTrashed: Bool
}

struct ConversationDetail: Equatable {
    let summary: ConversationSummary
    let messages: [ConversationMessage]
    let fileChanges: [FileChange]
    let continuationPrompt: String
}

struct ConversationMessage: Identifiable, Equatable {
    let id: String
    let role: String
    let timestamp: String
    let content: String
    let toolCalls: [ToolCall]
}

struct ToolCall: Identifiable, Equatable {
    let id: String
    let name: String
    let status: String
    let output: String
}

struct FileChange: Identifiable, Equatable {
    let id: String
    let path: String
    let changeType: String
}

struct MemoryCandidate: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let reason: String
}

struct ApprovedMemory: Identifiable, Equatable {
    let id: String
    let title: String
    let usageHint: String
    let freshness: String
}

struct WikiPage: Identifiable, Equatable {
    let id: String
    let title: String
    let preview: String
}

struct Checkpoint: Identifiable, Equatable {
    let id: String
    let summary: String
    let resumeCommand: String
}

struct HandoffPacket: Identifiable, Equatable {
    let id: String
    let fromAgent: AgentKind
    let toAgent: AgentKind
    let goal: String
    let nextItem: String
}

struct RunRecord: Identifiable, Equatable {
    let id: String
    let title: String
    let status: String
    let artifactCount: Int
}

struct ArtifactRecord: Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String
}

struct EpisodeRecord: Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String
}

struct RepoHealth: Equatable {
    let indexedConversations: Int
    let pendingCandidates: Int
    let aliasWarnings: [String]
    let bootstrapReady: Bool
}

struct AppSnapshot: Equatable {
    let conversations: [ConversationSummary]
    let details: [String: ConversationDetail]
    let memoryCandidates: [MemoryCandidate]
    let approvedMemories: [ApprovedMemory]
    let wikiPages: [WikiPage]
    let checkpoints: [Checkpoint]
    let handoffs: [HandoffPacket]
    let runs: [RunRecord]
    let artifacts: [ArtifactRecord]
    let episodes: [EpisodeRecord]
    let repoHealth: RepoHealth
}
