import Messages
import SwiftUI

@MainActor
final class MessagesViewBridge: ObservableObject {
    @Published var presentationStyle: MSMessagesAppPresentationStyle = .compact
    @Published var showingSettings = false
}

@MainActor
final class MessagesViewController: MSMessagesAppViewController {
    private let store = CodexRemoteStore(profileStore: .shared())
    private let bridge = MessagesViewBridge()
    private var hostingController: UIHostingController<MessagesExtensionRootView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        configureHostingController()
        syncPresentationStyle()
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        syncPresentationStyle()
        Task {
            await store.onAppear(prefersImmediateConnect: true)
            if store.connectionState.isConnected {
                await store.refreshAll()
            }
        }
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        syncPresentationStyle()
    }

    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        super.didReceive(message, conversation: conversation)
        syncPresentationStyle()
    }

    private func configureHostingController() {
        let controller = UIHostingController(rootView: makeRootView())
        addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        controller.didMove(toParent: self)
        hostingController = controller
    }

    private func makeRootView() -> MessagesExtensionRootView {
        MessagesExtensionRootView(
            store: store,
            bridge: bridge,
            requestExpanded: { [weak self] in
                guard let self, self.presentationStyle != .expanded else { return }
                self.requestPresentationStyle(.expanded)
            },
            requestCompact: { [weak self] in
                guard let self, self.presentationStyle != .compact else { return }
                self.requestPresentationStyle(.compact)
            }
        )
    }

    private func syncPresentationStyle() {
        bridge.presentationStyle = presentationStyle
        hostingController?.rootView = makeRootView()
    }
}

struct MessagesExtensionRootView: View {
    @ObservedObject var store: CodexRemoteStore
    @ObservedObject var bridge: MessagesViewBridge
    let requestExpanded: () -> Void
    let requestCompact: () -> Void

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if bridge.presentationStyle == .compact {
                compactView
            } else {
                expandedView
            }
        }
        .sheet(isPresented: $bridge.showingSettings) {
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

    private var compactView: some View {
        VStack(alignment: .leading, spacing: 10) {
            CourierPodView(
                state: store.courierState,
                quote: store.courierQuote,
                style: .compact
            )

            VStack(alignment: .leading, spacing: 4) {
                Label(store.connectionState.label, systemImage: store.connectionState.isConnected ? "bolt.horizontal.fill" : "bolt.slash.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.text)

                Text(threadSummary)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)

                if !store.profile.defaultWorkspace.isEmpty {
                    Text(store.profile.defaultWorkspace)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 8) {
                Button(store.connectionState.isConnected ? "Disconnect" : "Connect") {
                    if store.connectionState.isConnected {
                        store.disconnect()
                    } else {
                        Task { await store.connect() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(store.connectionState.isConnected ? AppTheme.warning : AppTheme.accent)

                Button("Resume") {
                    Task {
                        if !store.connectionState.isConnected {
                            await store.connect()
                        }
                        await store.refreshThreads()
                        if let thread = store.threads.first {
                            await store.selectThread(thread)
                        }
                        requestExpanded()
                    }
                }
                .buttonStyle(.bordered)

                Button("New Thread") {
                    store.prepareForNewThread()
                    requestExpanded()
                }
                .buttonStyle(.bordered)

                Button("Settings") {
                    requestExpanded()
                    DispatchQueue.main.async {
                        bridge.showingSettings = true
                    }
                }
                .buttonStyle(.bordered)
            }

            if store.needsAttention {
                Button("Handle Approval Or Input") {
                    requestExpanded()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.warning)
            }
        }
        .padding(12)
    }

    private var expandedView: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Messages Control")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        Spacer()

                        Button("Setup") {
                            bridge.showingSettings = true
                        }
                        .buttonStyle(.bordered)

                        Button("Compact") {
                            requestCompact()
                        }
                        .buttonStyle(.bordered)
                    }

                    CourierPodView(
                        state: store.courierState,
                        quote: store.courierQuote
                    )
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                )

                RemoteControlSurface(
                    store: store,
                    onShowSettings: {
                        bridge.showingSettings = true
                    }
                )
            }
            .padding(16)
        }
    }

    private var threadSummary: String {
        if let selectedThread = store.selectedThread {
            return selectedThread.name
        }
        if let latest = store.threads.first {
            return "Latest: \(latest.name)"
        }
        return "No active thread"
    }
}
