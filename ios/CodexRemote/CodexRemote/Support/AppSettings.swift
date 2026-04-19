import Foundation

enum SandboxPreference: String, CaseIterable, Identifiable, Codable {
    case readOnly = "read-only"
    case workspaceWrite = "workspace-write"
    case dangerFullAccess = "danger-full-access"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .readOnly:
            return "Read Only"
        case .workspaceWrite:
            return "Workspace Write"
        case .dangerFullAccess:
            return "Danger Full Access"
        }
    }
}

enum ApprovalPreference: String, CaseIterable, Identifiable, Codable {
    case never
    case onRequest = "on-request"
    case untrusted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .never:
            return "Never Ask"
        case .onRequest:
            return "Ask When Needed"
        case .untrusted:
            return "Only Untrusted"
        }
    }
}

enum ReasoningPreference: String, CaseIterable, Identifiable, Codable {
    case minimal
    case low
    case medium
    case high
    case xhigh

    var id: String { rawValue }

    var title: String {
        rawValue.uppercased()
    }
}

enum PersonalityPreference: String, CaseIterable, Identifiable, Codable {
    case friendly
    case pragmatic
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .friendly:
            return "Friendly"
        case .pragmatic:
            return "Pragmatic"
        case .none:
            return "None"
        }
    }
}

struct ConnectionProfile: Codable, Equatable {
    var websocketURL: String
    var token: String
    var defaultWorkspace: String
    var defaultModel: String
    var defaultSandbox: SandboxPreference
    var approvalPolicy: ApprovalPreference
    var reasoningEffort: ReasoningPreference
    var personality: PersonalityPreference
    var autoConnectOnLaunch: Bool

    static let storageKey = "CodexRemote.connectionProfile"

    static let `default` = ConnectionProfile(
        websocketURL: "ws://127.0.0.1:8765",
        token: "",
        defaultWorkspace: "",
        defaultModel: "",
        defaultSandbox: .workspaceWrite,
        approvalPolicy: .never,
        reasoningEffort: .high,
        personality: .friendly,
        autoConnectOnLaunch: false
    )
}
