import AppKit

@MainActor
final class SettingsView: NSView {
    private let store: AppStore

    init(store: AppStore) {
        self.store = store
        super.init(frame: .zero)
        build()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func build() {
        let stack = ViewFactory.verticalStack(spacing: 14)
        stack.addArrangedSubviews([
            ViewFactory.label("Settings", font: DesignSystem.titleFont(24)),
            section("General", rows: ["Language: English / 中文", "Typeface: System, PingFang SC, SF Mono", "Auto-save recovery checkpoints: enabled"]),
            section("Updates and diagnostics", rows: ["Check updates", "Run upgrade self-check", "Telemetry: com.chatmem.native"]),
            section("Agent integration", rows: ["Install all", "Repair individual agent guidance", "MCP setup status"]),
            section("Sync", rows: ["WebDAV verification", "OneDrive/local folder sync", "Auto backup interval"]),
        ])
        let actions = ViewFactory.horizontalStack()
        actions.addArrangedSubviews([
            ViewFactory.button("Check Updates", target: self, action: #selector(queueUpdate), style: .primary),
            ViewFactory.button("Install Integrations", target: self, action: #selector(queueIntegration)),
            ViewFactory.button("Verify Sync", target: self, action: #selector(queueSync))
        ])
        stack.addArrangedSubview(actions)
        addSubview(stack)
        stack.pinToSuperview()
    }

    private func section(_ title: String, rows: [String]) -> NSView {
        let card = ViewFactory.card()
        let inner = ViewFactory.verticalStack(spacing: 7)
        inner.addArrangedSubview(ViewFactory.label(title, font: DesignSystem.titleFont(15)))
        rows.forEach { inner.addArrangedSubview(ViewFactory.label($0, color: .secondaryLabelColor, lines: 1)) }
        card.addSubview(inner)
        inner.pinToSuperview(insets: NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        return card
    }

    @objc private func queueUpdate() { store.showQueuedAction("Update check") }
    @objc private func queueIntegration() { store.showQueuedAction("Agent integration install") }
    @objc private func queueSync() { store.showQueuedAction("Sync verification") }
}
