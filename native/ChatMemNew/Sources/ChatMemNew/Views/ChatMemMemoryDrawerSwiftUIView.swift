import SwiftUI

struct ChatMemMemoryDrawerSwiftUIView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("启动规则管理")
                        .font(.system(size: 22, weight: .bold))
                    Text("候选规则、已批准规则、Wiki 和继续工作状态。")
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
                    Text(tabLabel(tab)).tag(tab)
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
                drawerCard(candidate.title, "\(candidate.reason)\n\(candidate.value)", action: "审批待桥接")
            }
        case .rules:
            ForEach(store.snapshot.approvedMemories) { memory in
                drawerCard(memory.title, "\(memory.freshness): \(memory.usageHint)", action: "重新核验待桥接")
            }
        case .wiki:
            ForEach(store.snapshot.wikiPages) { page in
                drawerCard(page.title, page.preview, action: "重建待桥接")
            }
        case .continuation:
            ForEach(store.snapshot.checkpoints) { checkpoint in
                drawerCard(checkpoint.summary, checkpoint.resumeCommand, action: "转交待桥接")
            }
            ForEach(store.snapshot.handoffs) { handoff in
                drawerCard(handoff.goal, "\(handoff.fromAgent.label) → \(handoff.toAgent.label)\n\(handoff.nextItem)", action: "标记接收待桥接")
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

    private func tabLabel(_ tab: MemoryDrawerTab) -> String {
        switch tab {
        case .review: "候选"
        case .rules: "规则"
        case .wiki: "Wiki"
        case .continuation: "继续"
        }
    }
}
