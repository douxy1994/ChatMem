import SwiftUI

struct ChatMemSidebarSwiftUIView: View {
    @ObservedObject var store: AppStore
    @State private var projectsExpanded = true
    @State private var chatsExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    controls
                    librarySection(
                        title: "项目",
                        systemImage: "folder",
                        count: store.filteredConversations.count,
                        expanded: $projectsExpanded
                    ) {
                        ForEach(store.filteredConversations) { conversation in
                            conversationRow(conversation, projectStyle: true)
                        }
                    }
                    librarySection(
                        title: "对话",
                        systemImage: "bubble.left.and.bubble.right",
                        count: store.snapshot.conversations.filter { $0.sourceAgent == store.selectedAgent && !$0.isTrashed }.count,
                        expanded: $chatsExpanded
                    ) {
                        ForEach(store.snapshot.conversations.filter { $0.sourceAgent == store.selectedAgent && !$0.isTrashed }) { conversation in
                            conversationRow(conversation, projectStyle: false)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 18)
                .padding(.bottom, 12)
            }

            utilityNav
        }
        .background(SwiftUITheme.sidebarBackground)
        .overlay(Rectangle().fill(SwiftUITheme.border).frame(width: 1), alignment: .trailing)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("来源", systemImage: "externaldrive")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SwiftUITheme.secondaryText)
                Spacer()
            }
            Picker("", selection: Binding(
                get: { store.selectedAgent },
                set: { store.setAgent($0) }
            )) {
                ForEach(AgentKind.allCases) { agent in
                    Text(agent.label).tag(agent)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(SwiftUITheme.mutedText)
                TextField("搜索本地历史", text: Binding(
                    get: { store.searchQuery },
                    set: { store.setSearch($0) }
                ))
                .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Color.white.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(SwiftUITheme.border))

            HStack(spacing: 6) {
                sidebarTool("square.grid.2x2", "整理")
                sidebarTool("checklist", "批量")
                sidebarTool("arrow.down.right.and.arrow.up.left", "折叠")
            }
        }
    }

    private func sidebarTool(_ icon: String, _ title: String) -> some View {
        Button { store.showQueuedAction(title) } label: {
            Image(systemName: icon)
                .frame(width: 28, height: 26)
        }
        .buttonStyle(.borderless)
        .help(title)
        .background(Color.white.opacity(0.48))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func librarySection<Content: View>(
        title: String,
        systemImage: String,
        count: Int,
        expanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                expanded.wrappedValue.toggle()
            } label: {
                HStack {
                    Image(systemName: expanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(SwiftUITheme.mutedText)
                    Label(title, systemImage: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SwiftUITheme.secondaryText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(SwiftUITheme.softStrong)
                        .clipShape(Capsule())
                }
            }
            .buttonStyle(.plain)

            if expanded.wrappedValue {
                VStack(spacing: 5) {
                    content()
                }
            }
        }
    }

    private func conversationRow(_ conversation: ConversationSummary, projectStyle: Bool) -> some View {
        Button {
            store.selectConversation(conversation.id)
        } label: {
            HStack(alignment: .top, spacing: 9) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(conversation.sourceAgent == .codex ? SwiftUITheme.accent : SwiftUITheme.mutedText)
                    .frame(width: 7, height: 32)
                    .padding(.top, 3)

                VStack(alignment: .leading, spacing: 3) {
                    Text(conversation.title)
                        .font(.system(size: projectStyle ? 12.5 : 12, weight: .semibold))
                        .lineLimit(2)
                    Text(projectName(conversation.projectDirectory))
                        .font(.system(size: 11))
                        .foregroundStyle(SwiftUITheme.secondaryText)
                        .lineLimit(1)
                    Text("\(conversation.messageCount) 条消息 · \(conversation.fileCount) 个文件 · \(conversation.updatedAt)")
                        .font(.system(size: 10))
                        .foregroundStyle(SwiftUITheme.mutedText)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(conversation.id == store.selectedConversationID ? SwiftUITheme.selected : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }

    private var utilityNav: some View {
        HStack(spacing: 6) {
            utilityButton("收藏", "star", store.favorites.count) { store.openWorkspace(.favorites) }
            utilityButton("回收站", "trash", store.trashed.count) { store.openWorkspace(.trash) }
            Spacer()
            Text("v1.3.2")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SwiftUITheme.mutedText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().fill(SwiftUITheme.border).frame(height: 1), alignment: .top)
    }

    private func utilityButton(_ title: String, _ icon: String, _ count: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                Text(title)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5)
                        .background(SwiftUITheme.softStrong)
                        .clipShape(Capsule())
                }
            }
            .font(.system(size: 11, weight: .medium))
        }
        .buttonStyle(.borderless)
    }

    private func projectName(_ path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent.isEmpty ? path : URL(fileURLWithPath: path).lastPathComponent
    }
}
