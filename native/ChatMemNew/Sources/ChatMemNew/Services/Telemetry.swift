import Foundation
import OSLog

final class Telemetry {
    private let lifecycleLogger = Logger(subsystem: "com.chatmem.native", category: "Lifecycle")
    private let sidebarLogger = Logger(subsystem: "com.chatmem.native", category: "Sidebar")
    private let workspaceLogger = Logger(subsystem: "com.chatmem.native", category: "Workspace")
    private let memoryLogger = Logger(subsystem: "com.chatmem.native", category: "Memory")
    private let bridgeLogger = Logger(subsystem: "com.chatmem.native", category: "Bridge")
    private let syncLogger = Logger(subsystem: "com.chatmem.native", category: "Sync")

    func lifecycle(_ message: String) {
        lifecycleLogger.notice("\(message, privacy: .public)")
    }

    func sidebar(_ message: String) {
        sidebarLogger.notice("\(message, privacy: .public)")
    }

    func workspace(_ message: String) {
        workspaceLogger.notice("\(message, privacy: .public)")
    }

    func memory(_ message: String) {
        memoryLogger.notice("\(message, privacy: .public)")
    }

    func bridge(_ message: String) {
        bridgeLogger.notice("\(message, privacy: .public)")
    }

    func sync(_ message: String) {
        syncLogger.notice("\(message, privacy: .public)")
    }
}
