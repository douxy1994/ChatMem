import AppKit

@MainActor
final class ConversationDetailView: NSView {
    private let detail: ConversationDetail

    init(detail: ConversationDetail) {
        self.detail = detail
        super.init(frame: .zero)
        build()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func build() {
        let stack = ViewFactory.verticalStack(spacing: 10)
        addSubview(stack)
        stack.pinToSuperview()

        for message in detail.messages {
            let card = ViewFactory.card()
            let inner = ViewFactory.verticalStack(spacing: 6)
            inner.addArrangedSubviews([
                ViewFactory.label(message.role.uppercased(), font: DesignSystem.captionFont(), color: .secondaryLabelColor),
                ViewFactory.label(message.content, font: DesignSystem.bodyFont(), color: .labelColor, lines: 0)
            ])
            for tool in message.toolCalls {
                inner.addArrangedSubview(ViewFactory.label("Tool: \(tool.name) · \(tool.status) · \(tool.output)", font: DesignSystem.captionFont(), color: .secondaryLabelColor, lines: 0))
            }
            card.addSubview(inner)
            inner.pinToSuperview(insets: NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
            stack.addArrangedSubview(card)
            card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        if !detail.fileChanges.isEmpty {
            let files = ViewFactory.card()
            let inner = ViewFactory.verticalStack(spacing: 5)
            inner.addArrangedSubview(ViewFactory.label("File Changes", font: DesignSystem.titleFont(14)))
            detail.fileChanges.forEach { change in
                inner.addArrangedSubview(ViewFactory.label("\(change.changeType): \(change.path)", font: DesignSystem.captionFont(), color: .secondaryLabelColor, lines: 1))
            }
            files.addSubview(inner)
            inner.pinToSuperview(insets: NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
            stack.addArrangedSubview(files)
            files.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
    }
}
