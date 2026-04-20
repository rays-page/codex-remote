import Foundation
import SwiftUI

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case failed(String)

    var label: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .failed:
            return "Connection Error"
        }
    }

    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
}

struct CodexModelOption: Identifiable, Equatable {
    let id: String
    let displayName: String
    let description: String
    let isDefault: Bool
}

struct RemoteThread: Identifiable, Equatable {
    let id: String
    var name: String
    var preview: String
    var cwd: String
    var updatedAt: Date
    var statusLabel: String
    var waitingOnApproval: Bool
}

enum TimelineKind {
    case user
    case agent
    case plan
    case reasoning
    case command
    case diff
    case system
}

struct RemoteTimelineItem: Identifiable, Equatable {
    let id: String
    var kind: TimelineKind
    var title: String
    var body: String
    var caption: String?

    var tint: Color {
        switch kind {
        case .user:
            return AppTheme.accent
        case .agent:
            return AppTheme.podGlow
        case .plan:
            return AppTheme.warning
        case .reasoning:
            return AppTheme.secondaryText
        case .command:
            return AppTheme.command
        case .diff:
            return AppTheme.success
        case .system:
            return AppTheme.secondaryText
        }
    }
}

enum ApprovalKind {
    case command
    case fileChange
    case permissions
}

struct PendingApproval: Identifiable {
    let id: String
    let requestID: AnyHashable
    let method: String
    let kind: ApprovalKind
    let title: String
    let body: String
    let params: [String: Any]
    let decisions: [String]
}

struct PromptQuestion: Identifiable, Hashable {
    let id: String
    let header: String
    let prompt: String
    let options: [String]
    let allowsFreeform: Bool
    var answer: String
}

struct PendingPrompt: Identifiable {
    let id: String
    let requestID: AnyHashable
    let method: String
    var questions: [PromptQuestion]
}

enum CourierPodState: String {
    case disconnected
    case boot
    case idle
    case working
    case ping
    case waiting
    case error

    var artColor: Color {
        switch self {
        case .disconnected:
            return Color(hex: 0x7C8A84)
        case .boot:
            return Color(hex: 0xC8E6FF)
        case .idle:
            return Color(hex: 0xC8FFAB)
        case .working:
            return Color(hex: 0xFFF0A8)
        case .ping:
            return Color(hex: 0xFFDCA1)
        case .waiting:
            return Color(hex: 0xD5D9FF)
        case .error:
            return Color(hex: 0xFFB0A8)
        }
    }

    var quoteColor: Color {
        switch self {
        case .disconnected:
            return Color(hex: 0x7A867D)
        case .boot:
            return Color(hex: 0x88A9C4)
        case .idle:
            return Color(hex: 0x8BA774)
        case .working:
            return Color(hex: 0xC3B66B)
        case .ping:
            return Color(hex: 0xC49A6E)
        case .waiting:
            return Color(hex: 0x99A2D7)
        case .error:
            return Color(hex: 0xD18A81)
        }
    }

    var fallbackQuote: String {
        switch self {
        case .disconnected:
            return "off watch"
        case .boot:
            return "waking up"
        case .idle:
            return "on watch"
        case .working:
            return "at work"
        case .ping:
            return "with you"
        case .waiting:
            return "hold please"
        case .error:
            return "hit a snag"
        }
    }

    var frames: [String] {
        switch self {
        case .disconnected:
            return [
                """
                 .__.
                 |--|
                 |_ |
                 '=='
                """
            ]
        case .boot:
            return [
                """
                 .__.
                 |..|
                 |_ |
                 '=='
                """,
                """
                 .__.
                 |.:|
                 |_ |
                 '=='
                """,
                """
                 .__.
                 |..|
                 |_.|
                 '=='
                """
            ]
        case .idle:
            return [
                """
                 .__.
                 |oo|
                 |_>|
                 '=='
                """,
                """
                 .__.
                 |-o|
                 |_>|
                 '=='
                """
            ]
        case .working:
            return [
                """
                 .__.
                 |><|
                 |#>|
                 '=#'
                """,
                """
                 .__.
                 |<>|
                 |=.|
                 '#='
                """,
                """
                 .__.
                 |><|
                 |=>|
                 '=#'
                """,
                """
                 .__.
                 |<>|
                 |#>|
                 '#='
                """
            ]
        case .ping:
            return [
                """
                 .__.
                 |^^|
                 |_>|
                 '=='
                """,
                """
                 .__.
                 |^o|
                 |_>|
                 '=='
                """
            ]
        case .waiting:
            return [
                """
                 .__.
                 |??|
                 |!>|
                 '=='
                """,
                """
                 .__.
                 |?o|
                 |!>|
                 '=='
                """
            ]
        case .error:
            return [
                """
                 .__.
                 |xx|
                 |!>|
                 '=='
                """
            ]
        }
    }
}

enum AppTheme {
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
}

extension Color {
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}
