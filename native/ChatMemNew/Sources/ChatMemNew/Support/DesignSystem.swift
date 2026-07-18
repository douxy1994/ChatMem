import AppKit

@MainActor
enum DesignSystem {
    static let sidebarWidth: CGFloat = 330
    static let drawerWidth: CGFloat = 380
    static let topBarHeight: CGFloat = 56
    static let cornerRadius: CGFloat = 8
    static let compactSpacing: CGFloat = 8
    static let sectionSpacing: CGFloat = 14
    static let controlHeight: CGFloat = 30

    static var appBackground: NSColor {
        isDarkMode ? NSColor(calibratedWhite: 0.10, alpha: 1) : NSColor(calibratedRed: 0.95, green: 0.97, blue: 0.93, alpha: 1)
    }

    static var surfaceBackground: NSColor {
        isDarkMode ? NSColor(calibratedWhite: 0.16, alpha: 1) : NSColor(calibratedWhite: 1, alpha: 0.94)
    }

    static var softBackground: NSColor {
        isDarkMode ? NSColor(calibratedWhite: 0.20, alpha: 1) : NSColor(calibratedRed: 0.94, green: 0.96, blue: 0.92, alpha: 1)
    }

    static let accent = NSColor(calibratedRed: 0.23, green: 0.56, blue: 0.39, alpha: 1)

    static func titleFont(_ size: CGFloat = 20) -> NSFont {
        NSFont.systemFont(ofSize: size, weight: .semibold)
    }

    static func bodyFont(_ size: CGFloat = 13) -> NSFont {
        NSFont.systemFont(ofSize: size, weight: .regular)
    }

    static func captionFont(_ size: CGFloat = 11) -> NSFont {
        NSFont.systemFont(ofSize: size, weight: .medium)
    }

    private static var isDarkMode: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}
