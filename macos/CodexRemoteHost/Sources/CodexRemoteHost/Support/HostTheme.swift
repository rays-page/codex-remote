import SwiftUI

enum HostTheme {
    static let background = Color(hex: 0x060707)
    static let surface = Color(hex: 0x121516)
    static let elevatedSurface = Color(hex: 0x1B1F20)
    static let border = Color.white.opacity(0.08)
    static let text = Color(hex: 0xF5F7F7)
    static let secondaryText = Color(hex: 0x9AA4A3)
    static let accent = Color(hex: 0x2AD9C9)
    static let podGlow = Color(hex: 0xC8FFAB)
    static let warning = Color(hex: 0xFFDCA1)
    static let success = Color(hex: 0x85E6A6)
    static let command = Color(hex: 0x9FD3FF)
    static let error = Color(hex: 0xFFB0A8)
}

extension Color {
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}
