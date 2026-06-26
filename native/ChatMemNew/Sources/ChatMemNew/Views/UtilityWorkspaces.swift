import AppKit

@MainActor
enum UtilityWorkspaces {
    static func list(title: String, subtitle: String, conversations: [ConversationSummary]) -> NSView {
        let stack = ViewFactory.verticalStack(spacing: 14)
        stack.addArrangedSubviews([
            ViewFactory.label(title, font: DesignSystem.titleFont(24)),
            ViewFactory.label(subtitle, color: .secondaryLabelColor)
        ])
        if conversations.isEmpty {
            stack.addArrangedSubview(ViewFactory.label("Nothing to show yet.", color: .secondaryLabelColor))
        } else {
            conversations.forEach { conversation in
                let card = ViewFactory.card()
                let inner = ViewFactory.verticalStack(spacing: 5)
                inner.addArrangedSubviews([
                    ViewFactory.label(conversation.title, font: DesignSystem.bodyFont(14)),
                    ViewFactory.label("\(conversation.sourceAgent.label) · \(conversation.projectDirectory)", color: .secondaryLabelColor, lines: 1),
                    ViewFactory.label("\(conversation.messageCount) messages · \(conversation.fileCount) files", font: DesignSystem.captionFont(), color: .tertiaryLabelColor)
                ])
                card.addSubview(inner)
                inner.pinToSuperview(insets: NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
                stack.addArrangedSubview(card)
                card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            }
        }
        return stack
    }

    static func help() -> NSView {
        let stack = ViewFactory.verticalStack(spacing: 14)
        stack.addArrangedSubviews([
            ViewFactory.label("Help", font: DesignSystem.titleFont(24)),
            helpCard("Continue work", "Start from the selected conversation, copy the resume command, or open local history for source-backed context."),
            helpCard("Review memory", "Use the memory drawer to separate durable startup rules from searchable local history."),
            helpCard("Agent integrations", "Install MCP and per-agent guidance so recall questions route through ChatMem.")
        ])
        return stack
    }

    static func about() -> NSView {
        let stack = ViewFactory.verticalStack(spacing: 14)
        stack.addArrangedSubviews([
            ViewFactory.label("ChatMemNew", font: DesignSystem.titleFont(28)),
            ViewFactory.label("Native Swift and AppKit parallel build for local-first coding-agent memory.", color: .secondaryLabelColor, lines: 0),
            helpCard("Build status", "UI parity shell with deterministic sample data. Backend bridge integration is queued by surface."),
            helpCard("Safety", "This app is installed separately as ChatMemNew.app and does not replace /Applications/ChatMem.app.")
        ])
        return stack
    }

    private static func helpCard(_ title: String, _ body: String) -> NSView {
        let card = ViewFactory.card()
        let inner = ViewFactory.verticalStack(spacing: 7)
        inner.addArrangedSubviews([
            ViewFactory.label(title, font: DesignSystem.titleFont(15)),
            ViewFactory.label(body, color: .secondaryLabelColor, lines: 0)
        ])
        card.addSubview(inner)
        inner.pinToSuperview(insets: NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        return card
    }
}
