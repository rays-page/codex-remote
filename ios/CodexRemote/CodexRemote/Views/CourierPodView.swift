import SwiftUI

struct CourierPodView: View {
    let state: CourierPodState
    let quote: String

    @State private var frameIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(currentFrame)
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .foregroundStyle(state.artColor)
                .shadow(color: .black.opacity(0.45), radius: 0, x: 2, y: 2)
                .shadow(color: state.artColor.opacity(0.18), radius: 14, x: 0, y: 0)

            Text(quote.isEmpty ? state.fallbackQuote : quote)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(state.quoteColor)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.elevatedSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
        .onAppear {
            frameIndex = 0
        }
        .onReceive(Timer.publish(every: 0.28, on: .main, in: .common).autoconnect()) { _ in
            frameIndex = (frameIndex + 1) % max(state.frames.count, 1)
        }
    }

    private var currentFrame: String {
        let frames = state.frames
        guard !frames.isEmpty else { return "" }
        return frames[frameIndex % frames.count]
    }
}
