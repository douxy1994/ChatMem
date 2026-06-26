import Foundation

@MainActor
final class AppStore {
    let bridge: NativeBridge
    let telemetry = Telemetry()
    private(set) var snapshot: AppSnapshot
    var selectedAgent: AgentKind = .codex
    var selectedConversationID: String?
    var searchQuery = ""
    var workspace: WorkspaceDestination = .workbench
    var memoryDrawerOpen = false
    var memoryDrawerTab: MemoryDrawerTab = .review
    var modalMessage: String?
    var onChange: (() -> Void)?

    init(bridge: NativeBridge) {
        self.bridge = bridge
        telemetry.bridge("Loading sample snapshot")
        self.snapshot = bridge.loadSnapshot()
        selectedConversationID = snapshot.conversations.first?.id
        workspace = .conversation
    }

    var filteredConversations: [ConversationSummary] {
        snapshot.conversations.filter { conversation in
            conversation.sourceAgent == selectedAgent &&
                !conversation.isTrashed &&
                (searchQuery.isEmpty ||
                    conversation.title.localizedCaseInsensitiveContains(searchQuery) ||
                    conversation.projectDirectory.localizedCaseInsensitiveContains(searchQuery))
        }
    }

    var selectedConversation: ConversationDetail? {
        guard let selectedConversationID else { return nil }
        return snapshot.details[selectedConversationID]
    }

    var favorites: [ConversationSummary] {
        snapshot.conversations.filter(\.isFavorite)
    }

    var trashed: [ConversationSummary] {
        snapshot.conversations.filter(\.isTrashed)
    }

    func setAgent(_ agent: AgentKind) {
        selectedAgent = agent
        selectedConversationID = filteredConversations.first?.id
        workspace = selectedConversationID == nil ? .workbench : .conversation
        telemetry.sidebar("Selected source \(agent.rawValue)")
        notify()
    }

    func setSearch(_ query: String) {
        searchQuery = query
        telemetry.sidebar("Updated search query")
        notify()
    }

    func selectConversation(_ id: String) {
        selectedConversationID = id
        workspace = .conversation
        telemetry.sidebar("Selected conversation \(id)")
        notify()
    }

    func openWorkspace(_ destination: WorkspaceDestination) {
        workspace = destination
        telemetry.workspace("Opened workspace \(String(describing: destination))")
        notify()
    }

    func toggleMemoryDrawer(tab: MemoryDrawerTab? = nil) {
        if let tab {
            memoryDrawerTab = tab
        }
        memoryDrawerOpen.toggle()
        telemetry.memory(memoryDrawerOpen ? "Opened memory drawer" : "Closed memory drawer")
        notify()
    }

    func setMemoryDrawerTab(_ tab: MemoryDrawerTab) {
        memoryDrawerTab = tab
        telemetry.memory("Selected memory tab \(tab.rawValue)")
        notify()
    }

    func showQueuedAction(_ title: String) {
        modalMessage = "\(title) is queued for backend bridge integration. The native UI surface is present and intentionally not wired to destructive behavior yet."
        telemetry.bridge("Queued action \(title)")
        notify()
    }

    func clearModal() {
        modalMessage = nil
        notify()
    }

    private func notify() {
        onChange?()
    }
}
