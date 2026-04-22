import SwiftUI

struct CourierPodView: View {
    let mood: CourierPodMood
    let quote: String

    @State private var frameIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(currentFrame)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(mood.artColor)
                .shadow(color: .black.opacity(0.45), radius: 0, x: 2, y: 2)
                .shadow(color: mood.artColor.opacity(0.22), radius: 14, x: 0, y: 0)

            Text(quote)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(mood.quoteColor)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(HostTheme.elevatedSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(HostTheme.border, lineWidth: 1)
                )
        )
        .onAppear {
            frameIndex = 0
        }
        .onReceive(Timer.publish(every: 0.28, on: .main, in: .common).autoconnect()) { _ in
            frameIndex = (frameIndex + 1) % max(mood.frames.count, 1)
        }
    }

    private var currentFrame: String {
        let frames = mood.frames
        guard !frames.isEmpty else { return "" }
        return frames[frameIndex % frames.count]
    }
}

private extension CourierPodMood {
    var artColor: Color {
        switch self {
        case .disconnected:
            return Color(hex: 0x7C8A84)
        case .boot:
            return Color(hex: 0xC8E6FF)
        case .idle:
            return Color(hex: 0xC8FFAB)
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
        case .waiting:
            return Color(hex: 0x99A2D7)
        case .error:
            return Color(hex: 0xD18A81)
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
