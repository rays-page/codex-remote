import Foundation

struct RelayConfiguration: Codable, Equatable {
    var listenHost: String
    var listenPort: Int
    var publicWSURL: String
    var tokenFile: String

    enum CodingKeys: String, CodingKey {
        case listenHost = "listen_host"
        case listenPort = "listen_port"
        case publicWSURL = "public_ws_url"
        case tokenFile = "token_file"
    }

    static let defaultHost = "0.0.0.0"
    static let defaultPort = 8765

    static func defaults(stateRoot: URL) -> RelayConfiguration {
        RelayConfiguration(
            listenHost: defaultHost,
            listenPort: defaultPort,
            publicWSURL: "",
            tokenFile: stateRoot.appending(path: "capability.token").path(percentEncoded: false)
        )
    }

    func normalized(stateRoot: URL) -> RelayConfiguration {
        var copy = self
        copy.listenHost = copy.listenHost.trimmingCharacters(in: .whitespacesAndNewlines)
        if copy.listenHost.isEmpty {
            copy.listenHost = Self.defaultHost
        }
        if copy.listenPort <= 0 {
            copy.listenPort = Self.defaultPort
        }
        copy.publicWSURL = copy.publicWSURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if copy.tokenFile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            copy.tokenFile = stateRoot.appending(path: "capability.token").path(percentEncoded: false)
        }
        return copy
    }
}

struct RelayStatusPayload: Codable, Equatable {
    var pid: Int?
    var startedAt: Int?
    var listenHost: String
    var listenPort: Int
    var websocketURL: String
    var pairingURL: String
    var token: String
    var runtimeExecutable: String?
    var logFile: String?
    var tokenFile: String?
    var statusFile: String?
    var foreground: Bool?
    var running: Bool?

    enum CodingKeys: String, CodingKey {
        case pid
        case startedAt = "started_at"
        case listenHost = "listen_host"
        case listenPort = "listen_port"
        case websocketURL = "websocket_url"
        case pairingURL = "pairing_url"
        case token
        case runtimeExecutable = "runtime_executable"
        case logFile = "log_file"
        case tokenFile = "token_file"
        case statusFile = "status_file"
        case foreground
        case running
    }
}

struct PairingPayload: Codable, Equatable {
    var websocketURL: String
    var token: String
    var pairingURL: String

    enum CodingKeys: String, CodingKey {
        case websocketURL = "websocket_url"
        case token
        case pairingURL = "pairing_url"
    }
}

enum RelayHealth: String, Equatable {
    case notInstalled
    case stopped
    case starting
    case running
    case stalled
    case error
}

enum CourierPodMood: Equatable {
    case disconnected
    case boot
    case idle
    case waiting
    case error
}

struct RelaySnapshot: Equatable {
    let hostName: String
    let health: RelayHealth
    let configuration: RelayConfiguration
    let websocketURL: String
    let pairingURL: String?
    let runtimeExecutable: String?
    let logFile: URL
    let stateRoot: URL
    let lastStartedAt: Date?
    let processID: Int?
    let tokenExists: Bool
    let processRunning: Bool
    let reachable: Bool
    let errorSummary: String?

    var headline: String {
        switch health {
        case .notInstalled:
            return "Codex not found"
        case .stopped:
            return "Relay asleep"
        case .starting:
            return "Starting relay"
        case .running:
            return "Relay live"
        case .stalled:
            return "Relay stalled"
        case .error:
            return "Relay needs attention"
        }
    }

    var detail: String {
        switch health {
        case .notInstalled:
            return "Install the Codex Mac app or expose `codex` in PATH, then this host can publish the same websocket pairing flow your phone already understands."
        case .stopped:
            return "The server is down right now. Start it here before you step away and keep steering threads from your phone."
        case .starting:
            return "The local relay is waking up and writing its pairing details."
        case .running:
            return "Safe to step away. The websocket relay is healthy, the pairing link is ready, and this Mac is acting as the dock for your phone."
        case .stalled:
            return "The process is up, but the local websocket is not answering yet. A restart usually clears it."
        case .error:
            return errorSummary ?? "The relay hit a snag. Open the log and restart it from this console."
        }
    }

    var statusLabel: String {
        switch health {
        case .notInstalled:
            return "Missing"
        case .stopped:
            return "Offline"
        case .starting:
            return "Starting"
        case .running:
            return "Ready"
        case .stalled:
            return "Stalled"
        case .error:
            return "Error"
        }
    }

    var primaryActionTitle: String {
        switch health {
        case .running:
            return "Restart Relay"
        case .notInstalled, .stopped, .starting, .stalled, .error:
            return "Start Relay"
        }
    }

    var canStart: Bool {
        health != .running && health != .starting && runtimeExecutable != nil
    }

    var canStop: Bool {
        processRunning
    }

    var safeToStepAway: Bool {
        health == .running
    }

    var displayWebsocketURL: String {
        websocketURL.isEmpty ? "Not ready" : websocketURL
    }

    var runtimeLabel: String {
        runtimeExecutable ?? "Unavailable"
    }

    var hostPlatformLabel: String {
        "\(hostName) · macOS"
    }

    var podMood: CourierPodMood {
        switch health {
        case .notInstalled, .error:
            return .error
        case .stopped:
            return .disconnected
        case .starting:
            return .boot
        case .running:
            return .idle
        case .stalled:
            return .waiting
        }
    }

    var podQuote: String {
        switch health {
        case .notInstalled:
            return "need codex"
        case .stopped:
            return "off watch"
        case .starting:
            return "waking up"
        case .running:
            return "on watch"
        case .stalled:
            return "hold please"
        case .error:
            return "hit a snag"
        }
    }

    var menuSymbolName: String {
        switch health {
        case .running:
            return "dot.radiowaves.left.and.right"
        case .starting:
            return "bolt.horizontal.circle"
        case .stalled, .error:
            return "exclamationmark.triangle.fill"
        case .notInstalled, .stopped:
            return "moon.zzz.fill"
        }
    }

    var pickupStatusTitle: String {
        switch health {
        case .running:
            return "Phone pickup is ready"
        case .starting:
            return "Getting your phone handoff ready"
        case .stopped:
            return "Start the relay before you walk away"
        case .stalled:
            return "Restart the relay before you walk away"
        case .notInstalled:
            return "Install Codex on this Mac first"
        case .error:
            return "Fix the relay before you walk away"
        }
    }

    var pickupChecklist: [RelayChecklistItem] {
        [
            RelayChecklistItem(
                id: "relay",
                title: "Relay",
                detail: safeToStepAway ? "The websocket relay is up." : "Bring the relay up before leaving the desktop.",
                isSatisfied: safeToStepAway
            ),
            RelayChecklistItem(
                id: "pairing",
                title: "Phone handoff",
                detail: pairingURL == nil ? "A pair link appears as soon as the relay starts." : "Your pair link is ready to scan or copy into the phone app.",
                isSatisfied: pairingURL != nil
            ),
            RelayChecklistItem(
                id: "awake",
                title: "Host stays reachable",
                detail: "Keep this Mac awake and on-network while you’re away. If it sleeps, the phone loses the host.",
                isSatisfied: safeToStepAway
            ),
        ]
    }
}

struct RelayChecklistItem: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let isSatisfied: Bool
}

enum RelayActionError: LocalizedError {
    case missingCodex
    case couldNotLaunch(String)

    var errorDescription: String? {
        switch self {
        case .missingCodex:
            return "Could not find the local Codex runtime. Install the Codex Mac app or expose `codex` in PATH."
        case .couldNotLaunch(let detail):
            return detail
        }
    }
}
