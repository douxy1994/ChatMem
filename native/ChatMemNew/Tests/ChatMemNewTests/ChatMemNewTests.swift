import Testing
@testable import ChatMemNew

@MainActor
@Test func designSystemHasStableDimensions() async throws {
    #expect(DesignSystem.sidebarWidth >= 300)
    #expect(DesignSystem.drawerWidth >= 320)
}

@MainActor
@Test func sampleSnapshotCoversPrimarySurfaces() async throws {
    let snapshot = SampleNativeBridge().loadSnapshot()
    #expect(snapshot.conversations.isEmpty == false)
    #expect(snapshot.memoryCandidates.isEmpty == false)
    #expect(snapshot.approvedMemories.isEmpty == false)
    #expect(snapshot.wikiPages.isEmpty == false)
    #expect(snapshot.checkpoints.isEmpty == false)
    #expect(snapshot.handoffs.isEmpty == false)
    #expect(snapshot.runs.isEmpty == false)
    #expect(snapshot.artifacts.isEmpty == false)
    #expect(snapshot.episodes.isEmpty == false)
}

@MainActor
@Test func storeFiltersConversationsByAgentAndSearch() async throws {
    let store = AppStore(bridge: SampleNativeBridge())
    store.setAgent(.claude)
    #expect(store.filteredConversations.count == 1)
    store.setSearch("bootstrap")
    #expect(store.filteredConversations.map(\.id) == ["claude-memory-bootstrap"])
}
