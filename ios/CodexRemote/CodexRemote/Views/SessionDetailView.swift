import SwiftUI

struct SessionDetailView: View {
    let thread: RemoteThread?
    let timeline: [RemoteTimelineItem]
    let activeDiff: String
    let canInterrupt: Bool
    let onInterrupt: () -> Void
    @Binding var draftMessage: String
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            if let thread {
                VStack(alignment: .leading, spacing: 6) {
                    Text(thread.name)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.text)

                    Text(thread.cwd.isEmpty ? thread.preview : thread.cwd)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.secondaryText)

                    HStack(spacing: 10) {
                        Label(thread.statusLabel, systemImage: thread.waitingOnApproval ? "hand.raised.fill" : "bolt.fill")
                        Text(thread.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppTheme.elevatedSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                )
            }

            if !activeDiff.isEmpty {
                DisclosureGroup("Latest Diff") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(activeDiff)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(AppTheme.success)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, 8)
                }
                .tint(AppTheme.accent)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(AppTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                )
            }

            ScrollView {
                LazyVStack(spacing: 12) {
                    if timeline.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("No thread activity yet.")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Text("Start a turn from your phone and the live Codex output will stream here.")
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(AppTheme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(AppTheme.border, lineWidth: 1)
                                )
                        )
                    }

                    ForEach(timeline) { item in
                        TimelineCard(item: item)
                    }
                }
                .padding(.vertical, 4)
            }

            VStack(spacing: 10) {
                TextEditor(text: $draftMessage)
                    .frame(minHeight: 86, maxHeight: 120)
                    .padding(12)
                    .scrollContentBackground(.hidden)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(AppTheme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(AppTheme.border, lineWidth: 1)
                            )
                    )
                    .foregroundStyle(AppTheme.text)

                HStack(spacing: 12) {
                    Button("Interrupt") {
                        onInterrupt()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canInterrupt)

                    Spacer()

                    Button("Send") {
                        onSend()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                }
            }
        }
    }
}

private struct TimelineCard: View {
    let item: RemoteTimelineItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.text)

                Spacer()

                if let caption = item.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            Text(item.body.isEmpty ? " " : item.body)
                .font(item.kind == .command || item.kind == .diff
                    ? .system(size: 12, weight: .regular, design: .monospaced)
                    : .system(size: 15, weight: .regular, design: .default)
                )
                .foregroundStyle(item.kind == .command || item.kind == .diff ? item.tint : AppTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(item.tint.opacity(0.16))
                        .frame(width: 4)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
    }
}
