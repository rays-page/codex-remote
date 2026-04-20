import Foundation

enum AppSettings {
    static let appGroupIdentifier = "group.com.rayspage.codexremote"
    static let keychainAccessGroup = appGroupIdentifier
    static let keychainService = "CodexRemote.CapabilityToken"
    static let keychainAccount = "desktop-relay"
}

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

    init(
        websocketURL: String,
        token: String,
        defaultWorkspace: String,
        defaultModel: String,
        defaultSandbox: SandboxPreference,
        approvalPolicy: ApprovalPreference,
        reasoningEffort: ReasoningPreference,
        personality: PersonalityPreference,
        autoConnectOnLaunch: Bool
    ) {
        self.websocketURL = websocketURL
        self.token = token
        self.defaultWorkspace = defaultWorkspace
        self.defaultModel = defaultModel
        self.defaultSandbox = defaultSandbox
        self.approvalPolicy = approvalPolicy
        self.reasoningEffort = reasoningEffort
        self.personality = personality
        self.autoConnectOnLaunch = autoConnectOnLaunch
    }

    enum CodingKeys: String, CodingKey {
        case websocketURL
        case token
        case defaultWorkspace
        case defaultModel
        case defaultSandbox
        case approvalPolicy
        case reasoningEffort
        case personality
        case autoConnectOnLaunch
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        websocketURL = try container.decodeIfPresent(String.self, forKey: .websocketURL) ?? ConnectionProfile.default.websocketURL
        token = try container.decodeIfPresent(String.self, forKey: .token) ?? ""
        defaultWorkspace = try container.decodeIfPresent(String.self, forKey: .defaultWorkspace) ?? ""
        defaultModel = try container.decodeIfPresent(String.self, forKey: .defaultModel) ?? ""
        defaultSandbox = try container.decodeIfPresent(SandboxPreference.self, forKey: .defaultSandbox) ?? .workspaceWrite
        approvalPolicy = try container.decodeIfPresent(ApprovalPreference.self, forKey: .approvalPolicy) ?? .never
        reasoningEffort = try container.decodeIfPresent(ReasoningPreference.self, forKey: .reasoningEffort) ?? .high
        personality = try container.decodeIfPresent(PersonalityPreference.self, forKey: .personality) ?? .friendly
        autoConnectOnLaunch = try container.decodeIfPresent(Bool.self, forKey: .autoConnectOnLaunch) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(websocketURL, forKey: .websocketURL)
        try container.encode(token, forKey: .token)
        try container.encode(defaultWorkspace, forKey: .defaultWorkspace)
        try container.encode(defaultModel, forKey: .defaultModel)
        try container.encode(defaultSandbox, forKey: .defaultSandbox)
        try container.encode(approvalPolicy, forKey: .approvalPolicy)
        try container.encode(reasoningEffort, forKey: .reasoningEffort)
        try container.encode(personality, forKey: .personality)
        try container.encode(autoConnectOnLaunch, forKey: .autoConnectOnLaunch)
    }

    var nonSecretCopy: ConnectionProfile {
        var copy = self
        copy.token = ""
        return copy
    }

    var hasRelayConfiguration: Bool {
        !websocketURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
