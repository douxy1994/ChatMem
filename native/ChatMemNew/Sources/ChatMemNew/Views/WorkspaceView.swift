import AppKit

@MainActor
final class WorkspaceView: NSView {
    private let store: AppStore
    private let content = NSView()

    init(store: AppStore) {
        self.store = store
        super.init(frame: .zero)
        build()
        reload()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func reload() {
        ViewFactory.clear(content)
        let next: NSView
        switch store.workspace {
        case .workbench:
            next = emptyWorkbench()
        case .conversation:
            next = conversationWorkspace()
        case .localHistory:
            next = localHistoryWorkspace()
        case .settings:
            next = SettingsView(store: store)
        case .favorites:
            next = UtilityWorkspaces.list(title: "Favorites", subtitle: "Pinned conversations for fast recovery.", conversations: store.favorites)
        case .trash:
            next = UtilityWorkspaces.list(title: "Trash", subtitle: "Review conversations before permanent deletion.", conversations: store.trashed)
        case .help:
            next = UtilityWorkspaces.help()
        case .about:
            next = UtilityWorkspaces.about()
        }
        content.addSubview(next)
        next.pinToSuperview(insets: NSEdgeInsets(top: 18, left: 22, bottom: 18, right: 22))
    }

    private func build() {
        wantsLayer = true
        layer?.backgroundColor = DesignSystem.appBackground.cgColor
        translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        content.pinToSuperview()
    }

    private func emptyWorkbench() -> NSView {
        let stack = ViewFactory.verticalStack(spacing: 12)
        stack.alignment = .centerX
        stack.addArrangedSubviews([
            ViewFactory.label("ChatMem", font: DesignSystem.titleFont(28)),
            ViewFactory.label("Select a conversation from the sidebar to continue.", color: .secondaryLabelColor)
        ])
        return centered(stack)
    }

    private func conversationWorkspace() -> NSView {
        guard let detail = store.selectedConversation else {
            return emptyWorkbench()
        }
        let stack = ViewFactory.verticalStack(spacing: 14)
        let titleRow = ViewFactory.horizontalStack(spacing: 10)
        let titleBlock = ViewFactory.verticalStack(spacing: 3)
        titleBlock.addArrangedSubviews([
            ViewFactory.label(detail.summary.sourceAgent.label, font: DesignSystem.captionFont(), color: .secondaryLabelColor),
            ViewFactory.label(detail.summary.title, font: DesignSystem.titleFont(24), color: .labelColor, lines: 2),
            ViewFactory.label(detail.summary.projectDirectory, font: DesignSystem.captionFont(), color: .secondaryLabelColor, lines: 1)
        ])
        let actions = ViewFactory.horizontalStack(spacing: 8)
        actions.addArrangedSubviews([
            ViewFactory.button("Migrate", target: self, action: #selector(queueMigrate), style: .primary),
            ViewFactory.button("Copy Path", target: self, action: #selector(copyPath)),
            ViewFactory.button("Copy Resume", target: self, action: #selector(copyResume)),
            ViewFactory.button("Copy Continuation", target: self, action: #selector(copyContinuation)),
            ViewFactory.button("Local History", target: self, action: #selector(openLocalHistory)),
            ViewFactory.button("Memory", target: self, action: #selector(openMemory))
        ])
        titleRow.addArrangedSubviews([titleBlock, actions])
        titleBlock.setContentHuggingPriority(.defaultLow, for: .horizontal)
        actions.setContentHuggingPriority(.required, for: .horizontal)
        stack.addArrangedSubview(titleRow)
        titleRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let meta = ViewFactory.card()
        let metaStack = ViewFactory.verticalStack(spacing: 5)
        metaStack.addArrangedSubviews([
            ViewFactory.label("Storage: \(detail.summary.storagePath)", font: DesignSystem.captionFont(), color: .secondaryLabelColor, lines: 1),
            ViewFactory.label("Resume: \(detail.summary.resumeCommand)", font: DesignSystem.captionFont(), color: .secondaryLabelColor, lines: 1),
            ViewFactory.label("Continuation: \(detail.continuationPrompt)", font: DesignSystem.captionFont(), color: .tertiaryLabelColor, lines: 2)
        ])
        meta.addSubview(metaStack)
        metaStack.pinToSuperview(insets: NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
        stack.addArrangedSubview(meta)
        meta.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let scrollContent = ViewFactory.verticalStack(spacing: 12)
        scrollContent.addArrangedSubview(ConversationDetailView(detail: detail))
        let scroll = ViewFactory.scrollView(documentView: scrollContent)
        stack.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 420).isActive = true
        scrollContent.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -18).isActive = true
        return stack
    }

    private func localHistoryWorkspace() -> NSView {
        let health = store.snapshot.repoHealth
        let stack = ViewFactory.verticalStack(spacing: 14)
        stack.addArrangedSubviews([
            ViewFactory.label("Local History", font: DesignSystem.titleFont(24)),
            ViewFactory.label("Index health, scan, alias merge, and recall controls are represented here for parity.", color: .secondaryLabelColor, lines: 0)
        ])
        let card = ViewFactory.card()
        let inner = ViewFactory.verticalStack(spacing: 8)
        inner.addArrangedSubviews([
            ViewFactory.label("Indexed conversations: \(health.indexedConversations)", font: DesignSystem.bodyFont()),
            ViewFactory.label("Pending candidates: \(health.pendingCandidates)", font: DesignSystem.bodyFont()),
            ViewFactory.label("Bootstrap ready: \(health.bootstrapReady ? "yes" : "no")", font: DesignSystem.bodyFont())
        ])
        health.aliasWarnings.forEach { inner.addArrangedSubview(ViewFactory.label("Alias warning: \($0)", color: .secondaryLabelColor, lines: 0)) }
        let actions = ViewFactory.horizontalStack()
        actions.addArrangedSubviews([
            ViewFactory.button("Scan Repo", target: self, action: #selector(queueScan), style: .primary),
            ViewFactory.button("Import All", target: self, action: #selector(queueImport)),
            ViewFactory.button("Merge Alias", target: self, action: #selector(queueAlias)),
            ViewFactory.button("Recall History", target: self, action: #selector(queueRecall))
        ])
        inner.addArrangedSubview(actions)
        card.addSubview(inner)
        inner.pinToSuperview(insets: NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        stack.addArrangedSubview(card)
        card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }

    private func centered(_ view: NSView) -> NSView {
        let container = NSView()
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            view.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        store.telemetry.workspace("Copied value to pasteboard")
    }

    @objc private func queueMigrate() { store.showQueuedAction("Migration") }
    @objc private func queueScan() { store.showQueuedAction("Repo scan") }
    @objc private func queueImport() { store.showQueuedAction("Import all local history") }
    @objc private func queueAlias() { store.showQueuedAction("Alias merge") }
    @objc private func queueRecall() { store.showQueuedAction("History recall") }
    @objc private func openLocalHistory() { store.openWorkspace(.localHistory) }
    @objc private func openMemory() { store.toggleMemoryDrawer(tab: .review) }
    @objc private func copyPath() { if let detail = store.selectedConversation { copyToPasteboard(detail.summary.storagePath) } }
    @objc private func copyResume() { if let detail = store.selectedConversation { copyToPasteboard(detail.summary.resumeCommand) } }
    @objc private func copyContinuation() { if let detail = store.selectedConversation { copyToPasteboard(detail.continuationPrompt) } }
}
