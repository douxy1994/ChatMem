import SwiftUI

enum SwiftUITheme {
    static let appBackground = Color(red: 0.953, green: 0.969, blue: 0.933)
    static let sidebarBackground = Color(red: 0.965, green: 0.973, blue: 0.949)
    static let surface = Color.white.opacity(0.94)
    static let soft = Color(red: 0.957, green: 0.969, blue: 0.941)
    static let softStrong = Color(red: 0.933, green: 0.949, blue: 0.918)
    static let selected = Color(red: 0.227, green: 0.561, blue: 0.392).opacity(0.12)
    static let accent = Color(red: 0.227, green: 0.561, blue: 0.392)
    static let border = Color.black.opacity(0.08)
    static let secondaryText = Color(red: 0.42, green: 0.47, blue: 0.43)
    static let mutedText = Color(red: 0.56, green: 0.60, blue: 0.57)
}

extension View {
    func chatMemCard(padding: CGFloat = 14) -> some View {
        self
            .padding(padding)
            .background(SwiftUITheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(SwiftUITheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: Color.black.opacity(0.035), radius: 12, x: 0, y: 5)
    }
}
