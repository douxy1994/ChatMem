import AppKit
import OSLog

@main
final class ChatMemNewApp: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?
    private let logger = Logger(subsystem: "com.chatmem.native", category: "Lifecycle")

    static func main() {
        let app = NSApplication.shared
        let delegate = ChatMemNewApp()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.notice("ChatMemNew launched")
        let store = AppStore(bridge: SampleNativeBridge())
        let controller = MainWindowController(store: store)
        mainWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
