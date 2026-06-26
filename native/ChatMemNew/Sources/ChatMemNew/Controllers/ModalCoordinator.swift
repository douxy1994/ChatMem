import AppKit

@MainActor
final class ModalCoordinator {
    func showInfo(message: String, in window: NSWindow?) {
        let alert = NSAlert()
        alert.messageText = "ChatMemNew"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}
