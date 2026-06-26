import AppKit

@MainActor
final class MemoryDrawerView: NSView {
    private let store: AppStore
    private let tabs = NSSegmentedControl(labels: MemoryDrawerTab.allCases.map(\.rawValue), trackingMode: .selectOne, target: nil, action: nil)
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
        isHidden = !store.memoryDrawerOpen
        tabs.selectedSegment = MemoryDrawerTab.allCases.firstIndex(of: store.memoryDrawerTab) ?? 0
        ViewFactory.clear(content)

        let stack = ViewFactory.verticalStack(spacing: 10)
        stack.addArrangedSubview(ViewFactory.label(store.memoryDrawerTab.rawValue, font: DesignSystem.titleFont(18)))

        switch store.memoryDrawerTab {
        case .review:
            store.snapshot.memoryCandidates.forEach { candidate in
                stack.addArrangedSubview(card(title: candidate.title, body: "\(candidate.reason)\n\(candidate.value)", action: "Approve queued"))
            }
        case .rules:
            store.snapshot.approvedMemories.forEach { memory in
                stack.addArrangedSubview(card(title: memory.title, body: "\(memory.freshness): \(memory.usageHint)", action: "Reverify queued"))
            }
        case .wiki:
            store.snapshot.wikiPages.forEach { page in
                stack.addArrangedSubview(card(title: page.title, body: page.preview, action: "Rebuild queued"))
            }
        case .continuation:
            store.snapshot.checkpoints.forEach { checkpoint in
                stack.addArrangedSubview(card(title: checkpoint.summary, body: checkpoint.resumeCommand, action: "Promote queued"))
            }
            store.snapshot.handoffs.forEach { handoff in
                stack.addArrangedSubview(card(title: handoff.goal, body: "\(handoff.fromAgent.label) → \(handoff.toAgent.label)\n\(handoff.nextItem)", action: "Mark consumed queued"))
            }
        }

        let scroll = ViewFactory.scrollView(documentView: stack)
        content.addSubview(scroll)
        scroll.pinToSuperview()
        stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -18).isActive = true
    }

    private func build() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.borderWidth = 1
        translatesAutoresizingMaskIntoConstraints = false

        tabs.target = self
        tabs.action = #selector(tabChanged)
        tabs.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false

        let header = ViewFactory.horizontalStack()
        header.addArrangedSubviews([
            ViewFactory.label("Startup Rules", font: DesignSystem.titleFont(17)),
            ViewFactory.iconButton("Close", target: self, action: #selector(close))
        ])

        addSubview(header)
        addSubview(tabs)
        addSubview(content)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            header.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            tabs.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 12),
            tabs.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            tabs.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            content.topAnchor.constraint(equalTo: tabs.bottomAnchor, constant: 12),
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])
    }

    private func card(title: String, body: String, action: String) -> NSView {
        let card = ViewFactory.card()
        let inner = ViewFactory.verticalStack(spacing: 8)
        inner.addArrangedSubviews([
            ViewFactory.label(title, font: DesignSystem.bodyFont(13), lines: 2),
            ViewFactory.label(body, font: DesignSystem.captionFont(), color: .secondaryLabelColor, lines: 0),
            ViewFactory.button(action, target: self, action: #selector(queueAction))
        ])
        card.addSubview(inner)
        inner.pinToSuperview(insets: NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10))
        card.widthAnchor.constraint(equalToConstant: DesignSystem.drawerWidth - 32).isActive = true
        return card
    }

    @objc private func tabChanged() {
        let index = tabs.selectedSegment
        guard index >= 0, index < MemoryDrawerTab.allCases.count else { return }
        store.setMemoryDrawerTab(MemoryDrawerTab.allCases[index])
    }

    @objc private func close() {
        store.toggleMemoryDrawer()
    }

    @objc private func queueAction() {
        store.showQueuedAction("Memory drawer action")
    }
}
