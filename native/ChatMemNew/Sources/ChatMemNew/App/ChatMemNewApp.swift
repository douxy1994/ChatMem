import AppKit
import OSLog

@main
@MainActor
final class ChatMemNewApp: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?
    private var store: AppStore?
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
        self.store = store
        mainWindowController = controller
        installMenus()
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    private func installMenus() {
        let menuBar = NSMenu()
        NSApp.mainMenu = menuBar

        let appMenuItem = NSMenuItem()
        menuBar.addItem(appMenuItem)
        let appMenu = NSMenu(title: "ChatMemNew")
        appMenuItem.submenu = appMenu
        addItem("关于 ChatMemNew", to: appMenu, action: #selector(openAbout), key: "")
        appMenu.addItem(.separator())
        addItem("设置...", to: appMenu, action: #selector(openSettings), key: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "隐藏 ChatMemNew", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        appMenu.addItem(NSMenuItem(title: "隐藏其他", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h"))
        appMenu.addItem(NSMenuItem(title: "显示全部", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "退出 ChatMemNew", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        let workspaceMenuItem = NSMenuItem()
        menuBar.addItem(workspaceMenuItem)
        let workspaceMenu = NSMenu(title: "工作台")
        workspaceMenuItem.submenu = workspaceMenu
        addItem("继续工作", to: workspaceMenu, action: #selector(openWorkbench), key: "1")
        addItem("待确认", to: workspaceMenu, action: #selector(openReview), key: "2")
        addItem("历史", to: workspaceMenu, action: #selector(openHistory), key: "3")
        addItem("本地历史", to: workspaceMenu, action: #selector(openLocalHistory), key: "4")
        workspaceMenu.addItem(.separator())
        addItem("打开记忆视图", to: workspaceMenu, action: #selector(openMemory), key: "m")

        let helpMenuItem = NSMenuItem()
        menuBar.addItem(helpMenuItem)
        let helpMenu = NSMenu(title: "帮助")
        helpMenuItem.submenu = helpMenu
        addItem("ChatMemNew 帮助", to: helpMenu, action: #selector(openHelp), key: "?")
    }

    private func addItem(_ title: String, to menu: NSMenu, action: Selector, key: String) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    private func focusMainWindow() {
        mainWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openWorkbench() {
        store?.openWorkspace(.workbench)
        focusMainWindow()
    }

    @objc private func openReview() {
        store?.openWorkspace(.review)
        focusMainWindow()
    }

    @objc private func openHistory() {
        store?.openWorkspace(.history)
        focusMainWindow()
    }

    @objc private func openLocalHistory() {
        store?.openWorkspace(.localHistory)
        focusMainWindow()
    }

    @objc private func openMemory() {
        store?.toggleMemoryDrawer(tab: .review)
        focusMainWindow()
    }

    @objc private func openSettings() {
        store?.openWorkspace(.settings)
        focusMainWindow()
    }

    @objc private func openHelp() {
        store?.openWorkspace(.help)
        focusMainWindow()
    }

    @objc private func openAbout() {
        store?.openWorkspace(.about)
        focusMainWindow()
    }
}
