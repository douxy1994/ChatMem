import SwiftUI

struct ChatMemMemoryDrawerSwiftUIView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Startup Rules")
                        .font(.system(size: 22, weight: .bold))
                    Text("Stable rules, wiki, and continuation state.")
                        .font(.system(size: 12))
                        .foregroundStyle(SwiftUITheme.secondaryText)
                }
                Spacer()
                Button { store.toggleMemoryDrawer() } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
            }

            Picker("", selection: Binding(
                get: { store.memoryDrawerTab },
                set: { store.setMemoryDrawerTab($0) }
            )) {
                ForEach(MemoryDrawerTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    drawerContent
                }
                .padding(.bottom, 12)
            }
        }
        .padding(18)
        .frame(maxHeight: .infinity)
        .background(SwiftUITheme.sidebarBackground)
        .overlay(Rectangle().fill(SwiftUITheme.border).frame(width: 1), alignment: .leading)
        .shadow(color: .black.opacity(0.18), radius: 30, x: -10, y: 0)
    }

    @ViewBuilder
    private var drawerContent: some View {
        switch store.memoryDrawerTab {
        case .review:
            ForEach(store.snapshot.memoryCandidates) { candidate in
                drawerCard(candidate.title, "\(candidate.reason)\n\(candidate.value)", action: "Approve queued")
            }
        case .rules:
            ForEach(store.snapshot.approvedMemories) { memory in
                drawerCard(memory.title, "\(memory.freshness): \(memory.usageHint)", action: "Reverify queued")
            }
        case .wiki:
            ForEach(store.snapshot.wikiPages) { page in
                drawerCard(page.title, page.preview, action: "Rebuild queued")
            }
        case .continuation:
            ForEach(store.snapshot.checkpoints) { checkpoint in
                drawerCard(checkpoint.summary, checkpoint.resumeCommand, action: "Promote queued")
            }
            ForEach(store.snapshot.handoffs) { handoff in
                drawerCard(handoff.goal, "\(handoff.fromAgent.label) → \(handoff.toAgent.label)\n\(handoff.nextItem)", action: "Mark consumed queued")
            }
        }
    }

    private func drawerCard(_ title: String, _ body: String, action: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 14, weight: .semibold))
            Text(body).font(.system(size: 12)).foregroundStyle(SwiftUITheme.secondaryText)
            Button(action) { store.showQueuedAction(action) }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .chatMemCard(padding: 12)
    }
}
