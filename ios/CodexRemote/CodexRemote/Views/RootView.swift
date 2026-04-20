import SwiftUI

struct RootView: View {
    @ObservedObject var store: CodexRemoteStore
    @State private var showingConnectionSheet = false
    @State private var showingFallbackControls = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    heroCard
                    setupSummaryCard
                    messagesGuideCard
                    diagnosticsCard
                    fallbackCard
                }
                .padding(16)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Codex Remote")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await store.onAppear()
        }
        .onChange(of: store.needsAttention) { _, needsAttention in
            if needsAttention {
                showingFallbackControls = true
            }
        }
        .sheet(isPresented: $showingConnectionSheet) {
            ConnectionSheetView(
                models: store.models,
                initialProfile: store.profile,
                connectionState: store.connectionState,
                onSave: { profile in
                    store.updateProfile(profile)
                },
                onConnect: {
                    Task { await store.connect() }
                },
                onDisconnect: {
                    store.disconnect()
                }
            )
            .presentationDetents([.large])
        }
        .alert(
            "Codex Remote",
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
        .preferredColorScheme(.dark)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            CourierPodView(
                state: store.courierState,
                quote: store.courierQuote
            )

            HStack(spacing: 10) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)

                Text(store.connectionState.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.text)

                Spacer()

                Button("Edit Setup") {
                    showingConnectionSheet = true
                }
                .buttonStyle(.bordered)

                Button(store.connectionState.isConnected ? "Disconnect" : "Connect") {
                    if store.connectionState.isConnected {
                        store.disconnect()
                    } else {
                        Task { await store.connect() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(store.connectionState.isConnected ? AppTheme.warning : AppTheme.accent)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var setupSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Setup")
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            SummaryRow(label: "Relay", value: store.profile.websocketURL.isEmpty ? "Not set" : store.profile.websocketURL)
            SummaryRow(label: "Token", value: store.profile.token.isEmpty ? "Missing" : "Stored in shared keychain")
            SummaryRow(label: "Workspace", value: store.profile.defaultWorkspace.isEmpty ? "Thread decides" : store.profile.defaultWorkspace)
            SummaryRow(label: "Model", value: store.profile.defaultModel.isEmpty ? "Thread default" : store.profile.defaultModel)
            SummaryRow(label: "Reasoning", value: store.profile.reasoningEffort.title)
            SummaryRow(label: "Approval", value: store.profile.approvalPolicy.title)

            Text("These defaults are shared with the Messages extension through an App Group. The capability token stays out of UserDefaults.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(16)
        .background(cardBackground)
    }

    private var messagesGuideCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Use In Messages")
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            Text("Open any conversation in Messages, tap the app drawer, and choose Codex Remote.")
                .foregroundStyle(AppTheme.text)

            Text("Compact mode is for orientation and shortcuts. Expanded mode is where prompt entry, approvals, and request-for-input flows happen.")
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(16)
        .background(cardBackground)
    }

    private var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fallback Diagnostics")
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            SummaryRow(label: "Recent threads", value: "\(store.threads.count)")
            SummaryRow(label: "Loaded models", value: "\(store.models.count)")
            SummaryRow(label: "Active thread", value: store.selectedThread?.name ?? "None")

            HStack {
                Button("Refresh Relay State") {
                    Task { await store.refreshAll() }
                }
                .buttonStyle(.bordered)
                .disabled(!store.connectionState.isConnected)

                if store.needsAttention {
                    Text("Attention needed in the control surface below.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.warning)
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var fallbackCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup("Fallback Control Surface", isExpanded: $showingFallbackControls) {
                RemoteControlSurface(
                    store: store,
                    onShowSettings: {
                        showingConnectionSheet = true
                    },
                    showsSettingsButton: false
                )
                .padding(.top, 12)
            }
            .tint(AppTheme.accent)

            Text("The iPhone app now stays focused on setup and rescue access. Messages is the primary day-to-day control surface.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(16)
        .background(cardBackground)
    }

    private var statusColor: Color {
        switch store.connectionState {
        case .connected:
            return AppTheme.success
        case .connecting:
            return AppTheme.warning
        case .failed:
            return .red
        case .disconnected:
            return AppTheme.secondaryText
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(AppTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }
}

private struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)

            Text(value)
                .foregroundStyle(AppTheme.text)
                .font(label == "Workspace"
                    ? .system(size: 13, weight: .medium, design: .monospaced)
                    : .body
                )
        }
    }
}
