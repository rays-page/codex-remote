import AppKit
import Foundation

@MainActor
final class RelayStore: ObservableObject {
    private static let startRelayOnLaunchKey = "CodexRemoteHost.startRelayOnLaunch"

    @Published var configuration: RelayConfiguration
    @Published var snapshot: RelaySnapshot
    @Published var isPerformingAction = false
    @Published var transientError: String?
    @Published var showsAdvancedDetails = false
    @Published var startRelayOnLaunch: Bool {
        didSet {
            defaults.set(startRelayOnLaunch, forKey: Self.startRelayOnLaunchKey)
        }
    }

    private let controller: RelayController
    private let defaults: UserDefaults
    private var refreshTask: Task<Void, Never>?
    private var hasHandledInitialPresentation = false

    init(
        controller: RelayController = RelayController(),
        defaults: UserDefaults = .standard
    ) {
        self.controller = controller
        self.defaults = defaults
        let configuration = controller.loadConfiguration()
        self.configuration = configuration
        self.snapshot = controller.loadSnapshot()
        self.startRelayOnLaunch = defaults.object(forKey: Self.startRelayOnLaunchKey) as? Bool ?? true
        startPolling()
    }

    deinit {
        refreshTask?.cancel()
    }

    func refresh() {
        configuration = controller.loadConfiguration()
        snapshot = controller.loadSnapshot()
    }

    func handleInitialPresentation() {
        guard !hasHandledInitialPresentation else { return }
        hasHandledInitialPresentation = true
        refresh()

        guard startRelayOnLaunch else { return }

        switch snapshot.health {
        case .stopped where snapshot.canStart:
            startRelay()
        case .stalled:
            restartRelay()
        default:
            break
        }
    }

    func saveConfiguration() {
        do {
            try controller.saveConfiguration(configuration)
            snapshot = controller.loadSnapshot()
        } catch {
            transientError = error.localizedDescription
        }
    }

    func startRelay() {
        runAction { [self] in
            self.snapshot = self.controller.loadSnapshot(transientHealth: .starting)
            self.snapshot = try await self.controller.start(with: self.configuration)
        }
    }

    func stopRelay() {
        runAction { [self] in
            self.snapshot = await self.controller.stop()
        }
    }

    func restartRelay() {
        runAction { [self] in
            self.snapshot = self.controller.loadSnapshot(transientHealth: .starting)
            self.snapshot = try await self.controller.restart(with: self.configuration)
        }
    }

    func copyPairingLink() {
        guard let pairingURL = snapshot.pairingURL else { return }
        controller.copyString(pairingURL)
    }

    func copyWebsocketURL() {
        controller.copyString(snapshot.displayWebsocketURL)
    }

    func openLogs() {
        controller.revealLogs()
    }

    func openStateFolder() {
        controller.revealStateFolder()
    }

    func setStartRelayOnLaunch(_ enabled: Bool) {
        startRelayOnLaunch = enabled
    }

    private func startPolling() {
        refreshTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { return }
                self.refresh()
            }
        }
    }

    private func runAction(_ work: @escaping @MainActor () async throws -> Void) {
        guard !isPerformingAction else { return }
        isPerformingAction = true
        transientError = nil

        Task { @MainActor in
            defer { isPerformingAction = false }
            do {
                try await work()
            } catch {
                snapshot = controller.loadSnapshot(errorSummary: error.localizedDescription)
                transientError = error.localizedDescription
            }
        }
    }
}
