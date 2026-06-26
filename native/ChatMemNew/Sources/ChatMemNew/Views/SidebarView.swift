import AppKit

@MainActor
final class SidebarView: NSView {
    private let store: AppStore
    private let sourcePopup = NSPopUpButton()
    private let searchField = NSSearchField()
    private let listStack = ViewFactory.verticalStack(spacing: 6)

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
        sourcePopup.selectItem(withTitle: store.selectedAgent.label)
        searchField.stringValue = store.searchQuery
        ViewFactory.clearStack(listStack)

        addSection(title: "Projects", count: store.filteredConversations.count)
        for conversation in store.filteredConversations {
            listStack.addArrangedSubview(conversationRow(conversation))
        }

        addSection(title: "Chats", count: store.snapshot.conversations.filter { $0.sourceAgent == store.selectedAgent }.count)
        for conversation in store.snapshot.conversations.filter({ $0.sourceAgent == store.selectedAgent && !$0.isTrashed }).prefix(3) {
            listStack.addArrangedSubview(compactRow(conversation))
        }
    }

    private func build() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        translatesAutoresizingMaskIntoConstraints = false

        sourcePopup.addItems(withTitles: AgentKind.allCases.map(\.label))
        sourcePopup.target = self
        sourcePopup.action = #selector(sourceChanged)
        sourcePopup.translatesAutoresizingMaskIntoConstraints = false

        searchField.placeholderString = "Search local history"
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.translatesAutoresizingMaskIntoConstraints = false

        let controls = ViewFactory.verticalStack(spacing: 10)
        controls.addArrangedSubviews([
            ViewFactory.label("Source", font: DesignSystem.captionFont(), color: .secondaryLabelColor),
            sourcePopup,
            searchField
        ])

        let scroll = ViewFactory.scrollView(documentView: listStack)
        let utility = ViewFactory.horizontalStack(spacing: 8)
        utility.addArrangedSubviews([
            ViewFactory.iconButton("Favorites", target: self, action: #selector(openFavorites)),
            ViewFactory.iconButton("Trash", target: self, action: #selector(openTrash)),
            ViewFactory.iconButton("Settings", target: self, action: #selector(openSettings))
        ])

        addSubview(controls)
        addSubview(scroll)
        addSubview(utility)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: DesignSystem.sidebarWidth),
            controls.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            controls.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            controls.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            sourcePopup.widthAnchor.constraint(equalTo: controls.widthAnchor),
            searchField.widthAnchor.constraint(equalTo: controls.widthAnchor),

            scroll.topAnchor.constraint(equalTo: controls.bottomAnchor, constant: 16),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            scroll.bottomAnchor.constraint(equalTo: utility.topAnchor, constant: -12),
            listStack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -16),

            utility.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            utility.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            utility.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])
    }

    private func addSection(title: String, count: Int) {
        let row = ViewFactory.horizontalStack()
        row.addArrangedSubviews([
            ViewFactory.label(title, font: DesignSystem.captionFont(12), color: .secondaryLabelColor),
            ViewFactory.label("\(count)", font: DesignSystem.captionFont(11), color: .tertiaryLabelColor)
        ])
        listStack.addArrangedSubview(row)
    }

    private func conversationRow(_ conversation: ConversationSummary) -> NSView {
        let button = NSButton()
        button.title = ""
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.target = self
        button.action = #selector(conversationClicked(_:))
        button.identifier = NSUserInterfaceItemIdentifier(conversation.id)
        button.translatesAutoresizingMaskIntoConstraints = false

        let stack = ViewFactory.verticalStack(spacing: 3)
        stack.addArrangedSubviews([
            ViewFactory.label(conversation.title, font: DesignSystem.bodyFont(13), color: .labelColor, lines: 1),
            ViewFactory.label(projectLabel(conversation.projectDirectory), font: DesignSystem.captionFont(), color: .secondaryLabelColor, lines: 1),
            ViewFactory.label("\(conversation.messageCount) messages · \(conversation.fileCount) files · \(conversation.updatedAt)", font: DesignSystem.captionFont(10), color: .tertiaryLabelColor, lines: 1)
        ])
        button.addSubview(stack)
        stack.pinToSuperview(insets: NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10))
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 72).isActive = true
        if conversation.id == store.selectedConversationID {
            button.contentTintColor = DesignSystem.accent
        }
        return button
    }

    private func compactRow(_ conversation: ConversationSummary) -> NSView {
        let row = ViewFactory.label("• \(conversation.title)", font: DesignSystem.captionFont(), color: .secondaryLabelColor, lines: 1)
        return row
    }

    private func projectLabel(_ path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent.isEmpty ? path : URL(fileURLWithPath: path).lastPathComponent
    }

    @objc private func sourceChanged() {
        guard let item = sourcePopup.selectedItem,
              let agent = AgentKind.allCases.first(where: { $0.label == item.title }) else { return }
        store.setAgent(agent)
    }

    @objc private func searchChanged() {
        store.setSearch(searchField.stringValue)
    }

    @objc private func conversationClicked(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }
        store.selectConversation(id)
    }

    @objc private func openFavorites() {
        store.openWorkspace(.favorites)
    }

    @objc private func openTrash() {
        store.openWorkspace(.trash)
    }

    @objc private func openSettings() {
        store.openWorkspace(.settings)
    }
}
