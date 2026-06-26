import SwiftUI
import AppKit

struct ChatMemWorkspaceSwiftUIView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        ZStack {
            SwiftUITheme.appBackground
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch store.workspace {
                    case .workbench:
                        workbench
                    case .conversation:
                        conversationWorkspace
                    case .localHistory:
                        localHistory
                    case .settings:
                        settings
                    case .favorites:
                        listWorkspace("Favorites", "Pinned conversations for fast recovery.", store.favorites)
                    case .trash:
                        listWorkspace("Trash", "Review low-signal or deleted conversations before permanent removal.", store.trashed)
                    case .help:
                        help
                    case .about:
                        about
                    }
                }
                .padding(22)
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(SwiftUITheme.surface)
                    .shadow(color: .black.opacity(0.06), radius: 24, x: 0, y: 12)
                    .padding(16)
            )
        }
    }

    private var conversationWorkspace: some View {
        guard let detail = store.selectedConversation else { return AnyView(workbench) }
        return AnyView(
            VStack(alignment: .leading, spacing: 16) {
                conversationHeader(detail)
                metaStrip(detail)
                memorySummary
                HStack(alignment: .top, spacing: 14) {
                    transcript(detail)
                        .frame(maxWidth: .infinity)
                    recoveryRail(detail)
                        .frame(width: 280)
                }
            }
        )
    }

    private var workbench: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Continue Work")
                        .font(.system(size: 28, weight: .bold))
                    Text("Pick up the latest progress, commands, and next steps.")
                        .foregroundStyle(SwiftUITheme.secondaryText)
                }
                Spacer()
                Button("Open Memory") { store.toggleMemoryDrawer(tab: .review) }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                metricCard("Indexed history", "\(store.snapshot.repoHealth.indexedConversations)", "local conversations")
                metricCard("Pending review", "\(store.snapshot.memoryCandidates.count)", "candidate rules")
                metricCard("Project rules", "\(store.snapshot.approvedMemories.count)", "approved memories")
                metricCard("Wiki pages", "\(store.snapshot.wikiPages.count)", "readable projections")
            }
            panel("Recent Tasks") {
                ForEach(store.filteredConversations.prefix(5)) { conversation in
                    Button { store.selectConversation(conversation.id) } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(conversation.title).font(.system(size: 13, weight: .semibold))
                                Text(conversation.projectDirectory).font(.system(size: 11)).foregroundStyle(SwiftUITheme.secondaryText)
                            }
                            Spacer()
                            Text(conversation.updatedAt).font(.system(size: 11)).foregroundStyle(SwiftUITheme.mutedText)
                        }
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
    }

    private func conversationHeader(_ detail: ConversationDetail) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(detail.summary.sourceAgent.label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(SwiftUITheme.secondaryText)
                Text(detail.summary.title)
                    .font(.system(size: 25, weight: .bold))
                    .lineLimit(2)
                Text(detail.summary.projectDirectory)
                    .font(.system(size: 12))
                    .foregroundStyle(SwiftUITheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 8) {
                primaryButton("Migrate", "arrow.left.arrow.right") { store.showQueuedAction("Migration") }
                secondaryButton("Path", "doc.on.doc") { copy(detail.summary.storagePath) }
                secondaryButton("Resume", "terminal") { copy(detail.summary.resumeCommand) }
                secondaryButton("Prompt", "sparkles") { copy(detail.continuationPrompt) }
                secondaryButton("History", "clock.arrow.circlepath") { store.openWorkspace(.localHistory) }
                secondaryButton("Memory", "tray.full") { store.toggleMemoryDrawer(tab: .review) }
            }
        }
    }

    private func metaStrip(_ detail: ConversationDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            metaRow("File Location", detail.summary.storagePath)
            metaRow("Resume Command", detail.summary.resumeCommand)
            metaRow("Continuation Prompt", detail.continuationPrompt)
        }
        .chatMemCard(padding: 12)
    }

    private var memorySummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("05", "Project Memory Drafts", store.selectedConversation?.summary.projectDirectory ?? "No project path detected.")
            HStack(spacing: 10) {
                miniStat("\(store.snapshot.approvedMemories.count)", "rules")
                miniStat("\(store.snapshot.memoryCandidates.count)", "pending")
                miniStat("\(store.snapshot.wikiPages.count)", "Wiki")
            }
            Button("Open Memory View") { store.toggleMemoryDrawer(tab: store.snapshot.memoryCandidates.isEmpty ? .rules : .review) }
                .buttonStyle(.bordered)
        }
        .chatMemCard()
    }

    private func transcript(_ detail: ConversationDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Conversation")
                .font(.system(size: 17, weight: .bold))
            ForEach(detail.messages) { message in
                VStack(alignment: .leading, spacing: 8) {
                    Text(message.role.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(SwiftUITheme.secondaryText)
                    Text(message.content)
                        .font(.system(size: 13))
                    ForEach(message.toolCalls) { tool in
                        Text("Tool: \(tool.name) · \(tool.status) · \(tool.output)")
                            .font(.system(size: 11))
                            .foregroundStyle(SwiftUITheme.secondaryText)
                    }
                }
                .chatMemCard(padding: 12)
            }
        }
    }

    private func recoveryRail(_ detail: ConversationDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            panel("Recoverable Progress") {
                Text(detail.summary.title).font(.system(size: 13, weight: .semibold))
                Text(detail.summary.resumeCommand).font(.system(size: 11, design: .monospaced)).foregroundStyle(SwiftUITheme.secondaryText)
                Button("Create Checkpoint") { store.showQueuedAction("Create checkpoint") }
            }
            panel("File Changes") {
                ForEach(detail.fileChanges) { change in
                    Text("\(change.changeType): \(change.path)")
                        .font(.system(size: 11))
                        .foregroundStyle(SwiftUITheme.secondaryText)
                        .lineLimit(2)
                }
            }
        }
    }

    private var localHistory: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Local History").font(.system(size: 26, weight: .bold))
            Text("Open deeper records only when source-backed context is needed.")
                .foregroundStyle(SwiftUITheme.secondaryText)
            panel("Project Index Status") {
                Text("Indexed conversations: \(store.snapshot.repoHealth.indexedConversations)")
                Text("Pending candidates: \(store.snapshot.repoHealth.pendingCandidates)")
                Text("Bootstrap ready: \(store.snapshot.repoHealth.bootstrapReady ? "yes" : "no")")
                ForEach(store.snapshot.repoHealth.aliasWarnings, id: \.self) { warning in
                    Text(warning).foregroundStyle(SwiftUITheme.secondaryText)
                }
                HStack {
                    primaryButton("Scan", "arrow.clockwise") { store.showQueuedAction("Repo scan") }
                    secondaryButton("Import", "tray.and.arrow.down") { store.showQueuedAction("Import all local history") }
                    secondaryButton("Merge Alias", "link") { store.showQueuedAction("Alias merge") }
                    secondaryButton("Recall", "magnifyingglass") { store.showQueuedAction("History recall") }
                }
            }
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Settings").font(.system(size: 26, weight: .bold))
            settingsSection("General", ["Language: English / 中文", "Typeface: System, PingFang SC, SF Mono", "Auto-save recovery checkpoints: enabled"])
            settingsSection("Updates and diagnostics", ["Check updates", "Run upgrade self-check", "Telemetry: com.chatmem.native"])
            settingsSection("Agent integration", ["Install all", "Repair per-agent guidance", "MCP status"])
            settingsSection("Sync", ["WebDAV verification", "OneDrive/local folder sync", "Auto backup interval"])
        }
    }

    private var help: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Help").font(.system(size: 26, weight: .bold))
            settingsSection("Continue Work", ["Restore the resume command, inspect conversation evidence, or open local history."])
            settingsSection("Review Memory", ["Approve only durable startup rules. Local history remains searchable without approval."])
            settingsSection("Agent Integrations", ["Install MCP and per-agent guidance so recall questions route to ChatMem."])
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ChatMemNew").font(.system(size: 30, weight: .bold))
            Text("Native SwiftUI/AppKit parallel build. It does not replace /Applications/ChatMem.app.")
                .foregroundStyle(SwiftUITheme.secondaryText)
            settingsSection("Build Status", ["UI parity pass using SwiftUI, sample data, and queued backend bridge states."])
        }
    }

    private func listWorkspace(_ title: String, _ subtitle: String, _ conversations: [ConversationSummary]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.system(size: 26, weight: .bold))
            Text(subtitle).foregroundStyle(SwiftUITheme.secondaryText)
            ForEach(conversations) { conversation in
                HStack {
                    VStack(alignment: .leading) {
                        Text(conversation.title).font(.system(size: 14, weight: .semibold))
                        Text("\(conversation.sourceAgent.label) · \(conversation.projectDirectory)")
                            .font(.system(size: 12))
                            .foregroundStyle(SwiftUITheme.secondaryText)
                    }
                    Spacer()
                    Button("Open") { store.selectConversation(conversation.id) }
                }
                .chatMemCard()
            }
        }
    }

    private func panel<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 16, weight: .bold))
            content()
        }
        .chatMemCard()
    }

    private func metricCard(_ value: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value).font(.system(size: 24, weight: .bold))
            Text(title).font(.system(size: 13, weight: .semibold))
            Text(detail).font(.system(size: 11)).foregroundStyle(SwiftUITheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .chatMemCard()
    }

    private func settingsSection(_ title: String, _ rows: [String]) -> some View {
        panel(title) {
            ForEach(rows, id: \.self) { row in
                Text(row).foregroundStyle(SwiftUITheme.secondaryText)
            }
        }
    }

    private func sectionHeader(_ number: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(SwiftUITheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16, weight: .bold))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(SwiftUITheme.secondaryText).lineLimit(1)
            }
        }
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10, weight: .bold)).foregroundStyle(SwiftUITheme.mutedText)
            Text(value).font(.system(size: 11)).foregroundStyle(SwiftUITheme.secondaryText).lineLimit(2)
        }
    }

    private func miniStat(_ value: String, _ label: String) -> some View {
        VStack {
            Text(value).font(.system(size: 20, weight: .bold))
            Text(label).font(.system(size: 11)).foregroundStyle(SwiftUITheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(SwiftUITheme.soft)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func primaryButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
        }
        .buttonStyle(.borderedProminent)
        .tint(SwiftUITheme.accent)
    }

    private func secondaryButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
        }
        .buttonStyle(.bordered)
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        store.telemetry.workspace("Copied value to pasteboard")
    }
}
