import AppKit

@MainActor
final class MainWindowController: NSWindowController {
    private let store: AppStore

    init(store: AppStore) {
        self.store = store
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1240, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "ChatMemNew"
        window.minSize = NSSize(width: 1040, height: 680)
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unifiedCompact
        super.init(window: window)
        window.contentViewController = RootViewController(store: store)
        store.telemetry.lifecycle("Main window created")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}
