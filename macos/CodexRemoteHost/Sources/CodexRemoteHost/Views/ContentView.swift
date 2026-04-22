import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: RelayStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                heroCard
                walkAwayCard
                pairingCard
                advancedCard
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(background)
        .preferredColorScheme(.dark)
        .navigationTitle("Codex Remote Host")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isPerformingAction)
            }
        }
        .alert(
            "Codex Remote Host",
            isPresented: Binding(
                get: { store.transientError != nil },
                set: { newValue in
                    if !newValue {
                        store.transientError = nil
                    }
                }
            ),
            actions: {
                Button("OK", role: .cancel) { }
            },
            message: {
                Text(store.transientError ?? "")
            }
        )
        .task {
            store.handleInitialPresentation()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Courier Pod Beacon")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(HostTheme.accent)

            Text("Start it once. Know you can walk away. Pick Codex back up from your phone.")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(HostTheme.text)

            Text("This Mac is the dock your phone depends on. The host companion is here to answer one question fast: are you safe to step away and keep driving Codex from your phone?")
                .font(.body)
                .foregroundStyle(HostTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                CourierPodView(
                    mood: store.snapshot.podMood,
                    quote: store.snapshot.podQuote
                )
                .frame(width: 260)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        statusLamp
                        Text(store.snapshot.statusLabel.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(statusColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(statusColor.opacity(0.14), in: Capsule())

                        if store.snapshot.safeToStepAway {
                            Text("Safe to step away")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(HostTheme.podGlow)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(HostTheme.podGlow.opacity(0.12), in: Capsule())
                        }
                    }

                    Text(store.snapshot.headline)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(HostTheme.text)

                    Text(store.snapshot.detail)
                        .font(.body)
                        .foregroundStyle(HostTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Button(store.snapshot.primaryActionTitle) {
                            if store.snapshot.health == .running {
                                store.restartRelay()
                            } else {
                                store.startRelay()
                            }
                        }
                        .buttonStyle(PrimaryActionButtonStyle(tint: primaryTint))
                        .disabled(store.isPerformingAction || (!store.snapshot.canStart && store.snapshot.health != .running))

                        Button(store.snapshot.canStop ? "Stop Relay" : "Reveal Logs") {
                            if store.snapshot.canStop {
                                store.stopRelay()
                            } else {
                                store.openLogs()
                            }
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                        .disabled(store.isPerformingAction)

                        Button("Open Logs") {
                            store.openLogs()
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }

                    Divider()
                        .overlay(HostTheme.border)

                    LazyVGrid(columns: [
                        GridItem(.flexible(minimum: 160)),
                        GridItem(.flexible(minimum: 160)),
                        GridItem(.flexible(minimum: 160)),
                    ], alignment: .leading, spacing: 12) {
                        MetricView(label: "Host", value: store.snapshot.hostPlatformLabel)
                        MetricView(label: "Relay", value: store.snapshot.displayWebsocketURL)
                        MetricView(label: "Last Start", value: HostFormatting.relativeStartText(for: store.snapshot.lastStartedAt))
                        MetricView(label: "State Folder", value: store.snapshot.stateRoot.path(percentEncoded: false))
                        MetricView(label: "Runtime", value: store.snapshot.runtimeLabel)
                        MetricView(label: "Pairing", value: store.snapshot.pairingURL ?? "Start the relay to generate a pair link")
                    }
                }
            }

            HStack(spacing: 10) {
                Button("Copy Pair Link") {
                    store.copyPairingLink()
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(store.snapshot.pairingURL == nil)

                Button("Copy Websocket URL") {
                    store.copyWebsocketURL()
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Button("Reveal State Folder") {
                    store.openStateFolder()
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        }
        .padding(22)
        .background(cardBackground)
    }

    private var pairingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pick Up On Phone")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(HostTheme.text)

            Text("Once the relay is up, the iPhone app can grab this host through the same `codexremote://pair` link the Windows launcher already writes. Copy it, scan it, and continue from the phone.")
                .foregroundStyle(HostTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 18) {
                QRCodeCardView(payload: store.snapshot.pairingURL)
                    .frame(width: 210)

                VStack(alignment: .leading, spacing: 10) {
                    DetailRow(label: "Pair link", value: store.snapshot.pairingURL ?? "Relay not running yet")
                    DetailRow(label: "Websocket", value: store.snapshot.displayWebsocketURL)
                    DetailRow(label: "Token", value: store.snapshot.tokenExists ? "Stored in Application Support" : "Not generated yet")
                    DetailRow(label: "When to use", value: "Tap this when you want to walk away and keep driving Codex from your phone.")
                }
            }
        }
        .padding(22)
        .background(cardBackground)
    }

    private var advancedCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            DisclosureGroup("Advanced Relay Settings", isExpanded: $store.showsAdvancedDetails) {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isOn: Binding(
                        get: { store.startRelayOnLaunch },
                        set: { store.setStartRelayOnLaunch($0) }
                    )) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Start relay when this app opens")
                                .foregroundStyle(HostTheme.text)
                            Text("Keeps the flow close to open app, glance, walk away.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(HostTheme.secondaryText)
                        }
                    }
                    .toggleStyle(.switch)

                    Text("Keep the defaults unless you need a public tunnel URL or a different port. The phone app only cares that the websocket and pairing outputs stay stable.")
                        .foregroundStyle(HostTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(alignment: .top, spacing: 14) {
                        LabeledField(title: "Listen Host", text: $store.configuration.listenHost)
                        LabeledField(
                            title: "Listen Port",
                            text: Binding(
                                get: { String(store.configuration.listenPort) },
                                set: { store.configuration.listenPort = Int($0) ?? RelayConfiguration.defaultPort }
                            )
                        )
                    }

                    LabeledField(title: "Public Websocket URL", text: $store.configuration.publicWSURL)

                    Button("Save Settings") {
                        store.saveConfiguration()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
                .padding(.top, 14)
            }
            .tint(HostTheme.accent)
            .font(.system(size: 15, weight: .semibold, design: .rounded))
        }
        .padding(22)
        .background(cardBackground)
    }

    private var background: some View {
        LinearGradient(
            colors: [
                HostTheme.background,
                HostTheme.surface,
                Color(hex: 0x0A1112),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            RadialGradient(
                colors: [
                    HostTheme.accent.opacity(0.12),
                    .clear,
                ],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 420
            )
        )
        .ignoresSafeArea()
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(HostTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(HostTheme.border, lineWidth: 1)
            )
    }

    private var statusLamp: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 12, height: 12)
            .shadow(color: statusColor.opacity(0.55), radius: 10, x: 0, y: 0)
    }

    private var statusColor: Color {
        switch store.snapshot.health {
        case .running:
            return HostTheme.podGlow
        case .starting:
            return HostTheme.command
        case .stalled:
            return HostTheme.warning
        case .notInstalled, .error:
            return HostTheme.error
        case .stopped:
            return HostTheme.secondaryText
        }
    }

    private var primaryTint: Color {
        store.snapshot.health == .running ? HostTheme.warning : HostTheme.accent
    }

    private var walkAwayCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(store.snapshot.pickupStatusTitle)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(HostTheme.text)

            Text("This is the last glance before you leave the desktop. If these checks look good, the phone handoff is in good shape.")
                .foregroundStyle(HostTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(store.snapshot.pickupChecklist) { item in
                    WalkAwayChecklistRow(item: item)
                }
            }
        }
        .padding(22)
        .background(cardBackground)
    }
}

private struct MetricView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(HostTheme.secondaryText)

            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(HostTheme.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(HostTheme.elevatedSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(HostTheme.border, lineWidth: 1)
                )
        )
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(HostTheme.secondaryText)

            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(HostTheme.text)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(HostTheme.elevatedSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(HostTheme.border, lineWidth: 1)
                )
        }
    }
}

private struct WalkAwayChecklistRow: View {
    let item: RelayChecklistItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.isSatisfied ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(item.isSatisfied ? HostTheme.podGlow : HostTheme.warning)
                .font(.system(size: 18))
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(HostTheme.text)

                Text(item.detail)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(HostTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(HostTheme.elevatedSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(HostTheme.border, lineWidth: 1)
                )
        )
    }
}

private struct LabeledField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(HostTheme.secondaryText)

            TextField(title, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(HostTheme.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(HostTheme.elevatedSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(HostTheme.border, lineWidth: 1)
                        )
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct QRCodeCardView: View {
    let payload: String?

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        VStack(spacing: 10) {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .padding(16)
                    .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(HostTheme.elevatedSurface)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 34))
                                .foregroundStyle(HostTheme.secondaryText)
                            Text("Start the relay to generate the pairing code.")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(HostTheme.secondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 14)
                        }
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var image: NSImage? {
        guard let payload, !payload.isEmpty else { return nil }
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)) else {
            return nil
        }
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(Color.black.opacity(0.88))
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.72 : 1))
            )
    }
}

private struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(HostTheme.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(HostTheme.elevatedSurface.opacity(configuration.isPressed ? 0.78 : 1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(HostTheme.border, lineWidth: 1)
                    )
            )
    }
}
