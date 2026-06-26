import AppKit

@MainActor
enum ViewFactory {
    static func label(_ text: String, font: NSFont = DesignSystem.bodyFont(), color: NSColor = .labelColor, lines: Int = 0) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.maximumNumberOfLines = lines
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    static func button(_ title: String, target: AnyObject?, action: Selector?, style: ButtonStyle = .secondary) -> NSButton {
        let button = NSButton(title: title, target: target, action: action)
        button.bezelStyle = style == .primary ? .rounded : .recessed
        button.controlSize = .regular
        button.font = DesignSystem.bodyFont(12)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    static func iconButton(_ title: String, target: AnyObject?, action: Selector?) -> NSButton {
        let button = NSButton(title: title, target: target, action: action)
        button.bezelStyle = .texturedRounded
        button.controlSize = .small
        button.font = DesignSystem.bodyFont(12)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    static func verticalStack(spacing: CGFloat = DesignSystem.compactSpacing) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.distribution = .gravityAreas
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    static func horizontalStack(spacing: CGFloat = DesignSystem.compactSpacing) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.distribution = .gravityAreas
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    static func scrollView(documentView: NSView) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.documentView = documentView
        scroll.translatesAutoresizingMaskIntoConstraints = false
        return scroll
    }

    static func card() -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = DesignSystem.surfaceBackground.cgColor
        view.layer?.cornerRadius = DesignSystem.cornerRadius
        view.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.45).cgColor
        view.layer?.borderWidth = 1
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    static func clear(_ view: NSView) {
        view.subviews.forEach { $0.removeFromSuperview() }
    }

    static func clearStack(_ stack: NSStackView) {
        stack.arrangedSubviews.forEach { view in
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }
}

enum ButtonStyle {
    case primary
    case secondary
}

@MainActor
extension NSStackView {
    func addArrangedSubviews(_ views: [NSView]) {
        views.forEach(addArrangedSubview)
    }
}

@MainActor
extension NSView {
    func pinToSuperview(insets: NSEdgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)) {
        guard let superview else { return }
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: superview.topAnchor, constant: insets.top),
            leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: superview.trailingAnchor, constant: -insets.right),
            bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: -insets.bottom)
        ])
    }
}
