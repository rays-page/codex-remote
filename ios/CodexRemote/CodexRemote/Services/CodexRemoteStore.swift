import Foundation
import SwiftUI

@MainActor
final class CodexRemoteStore: ObservableObject {
    typealias JSONObject = [String: Any]

    @Published var profile: ConnectionProfile
    @Published var connectionState: ConnectionState = .disconnected
    @Published var threads: [RemoteThread] = []
    @Published var selectedThreadID: String?
    @Published var timeline: [RemoteTimelineItem] = []
    @Published var draftMessage = ""
    @Published var models: [CodexModelOption] = []
    @Published var courierState: CourierPodState = .disconnected
    @Published var courierQuote = CourierPodState.disconnected.fallbackQuote
    @Published var activeDiff = ""
    @Published var pendingApproval: PendingApproval?
    @Published var pendingPrompt: PendingPrompt?
    @Published var transientError: String?

    private let client = CodexRemoteClient()
    private let profileStore: ConnectionProfileStore
    private var approvalContinuation: CheckedContinuation<Any, Never>?
    private var promptContinuation: CheckedContinuation<Any, Never>?
    private var streamedEntryIDs: [String: Int] = [:]
    private var activeTurnIDs: [String: String] = [:]
    private var hasAttemptedAutoConnect = false

    init(profileStore: ConnectionProfileStore = .shared()) {
        self.profileStore = profileStore
        self.profile = profileStore.load()

        client.onNotification = { [weak self] method, params in
            self?.handleNotification(method: method, params: params)
        }
        client.onServerRequest = { [weak self] requestID, method, params in
            await self?.handleServerRequest(id: requestID, method: method, params: params) ?? [:]
        }
        client.onDisconnect = { [weak self] reason in
            self?.connectionState = .failed(reason)
            self?.courierState = .error
            self?.courierQuote = "lost link"
        }
    }

    var selectedThread: RemoteThread? {
        guard let selectedThreadID else { return nil }
        return threads.first(where: { $0.id == selectedThreadID })
    }

    var needsAttention: Bool {
        pendingApproval != nil || pendingPrompt != nil
    }

    func onAppear(prefersImmediateConnect: Bool = false) async {
        guard !hasAttemptedAutoConnect else { return }
        hasAttemptedAutoConnect = true

        if (prefersImmediateConnect || profile.autoConnectOnLaunch), profile.hasRelayConfiguration {
            await connect()
        }
    }

    func connect() async {
        if case .connecting = connectionState {
            return
        }

        if case .connected = connectionState {
            await refreshAll()
            return
        }

        guard !profile.websocketURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            transientError = "Add a websocket URL first."
            return
        }

        connectionState = .connecting
        courierState = .boot
        courierQuote = "waking up"

        do {
            try await client.connect(profile: profile)
            connectionState = .connected
            courierState = .idle
            courierQuote = "on watch"
            saveProfile()
            await refreshAll()
        } catch {
            connectionState = .failed(error.localizedDescription)
            courierState = .error
            courierQuote = "hit a snag"
            transientError = error.localizedDescription
        }
    }

    func disconnect() {
        client.disconnect()
        connectionState = .disconnected
        courierState = .disconnected
        courierQuote = "off watch"
        activeTurnIDs.removeAll()
    }

    func refreshAll() async {
        await refreshModels()
        await refreshThreads()
    }

    func saveProfile() {
        profileStore.save(profile)
    }

    func updateProfile(_ newProfile: ConnectionProfile) {
        profile = newProfile
        saveProfile()
    }

    func updateDefaultModel(_ modelID: String) {
        profile.defaultModel = modelID
        saveProfile()
    }

    func updateReasoningEffort(_ effort: ReasoningPreference) {
        profile.reasoningEffort = effort
        saveProfile()
    }

    func updateApprovalPolicy(_ policy: ApprovalPreference) {
        profile.approvalPolicy = policy
        saveProfile()
    }

    func handleDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "codexremote" else { return }
        guard url.host?.lowercased() == "pair" else { return }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let queryItems = Dictionary(uniqueKeysWithValues: components.queryItems?.map { ($0.name, $0.value ?? "") } ?? [])
        if let pairedURL = queryItems["url"], !pairedURL.isEmpty {
            profile.websocketURL = pairedURL
        }
        if let token = queryItems["token"], !token.isEmpty {
            profile.token = token
        }
        saveProfile()
    }

    func prepareForNewThread() {
        selectedThreadID = nil
        timeline = []
        activeDiff = ""
        courierState = .ping
        courierQuote = "fresh page"
    }

    func refreshThreads() async {
        guard case .connected = connectionState else { return }

        do {
            let result = try await client.sendRequest(
                method: "thread/list",
                params: [
                    "archived": false,
                    "limit": 50
                ]
            )
            guard
                let payload = result as? JSONObject,
                let data = payload["data"] as? [JSONObject]
            else { return }

            let parsed = data.map(parseThread).sorted { $0.updatedAt > $1.updatedAt }
            threads = parsed

            if let selectedThreadID, !parsed.contains(where: { $0.id == selectedThreadID }) {
                self.selectedThreadID = nil
                timeline = []
                activeDiff = ""
            }

            if self.selectedThreadID == nil {
                self.selectedThreadID = parsed.first?.id
            }

            if let selectedThreadID = self.selectedThreadID {
                await loadThread(id: selectedThreadID)
            }
        } catch {
            transientError = error.localizedDescription
            courierState = .error
            courierQuote = "thread list failed"
        }
    }

    func refreshModels() async {
        guard case .connected = connectionState else { return }

        do {
            let result = try await client.sendRequest(
                method: "model/list",
                params: [
                    "limit": 50,
                    "includeHidden": false
                ]
            )
            guard
                let payload = result as? JSONObject,
                let data = payload["data"] as? [JSONObject]
            else { return }

            models = data.compactMap { modelJSON in
                guard
                    let id = string(modelJSON["model"]) ?? string(modelJSON["id"]),
                    let displayName = string(modelJSON["displayName"])
                else {
                    return nil
                }
                return CodexModelOption(
                    id: id,
                    displayName: displayName,
                    description: string(modelJSON["description"]) ?? "",
                    isDefault: bool(modelJSON["isDefault"])
                )
            }
        } catch {
            transientError = error.localizedDescription
        }
    }

    func selectThread(_ thread: RemoteThread) async {
        selectedThreadID = thread.id
        await loadThread(id: thread.id)
        courierState = .ping
        courierQuote = "with you"
    }

    func loadThread(id: String) async {
        guard case .connected = connectionState else { return }
        do {
            let result = try await client.sendRequest(
                method: "thread/read",
                params: [
                    "threadId": id,
                    "includeTurns": true
                ]
            )
            guard
                let payload = result as? JSONObject,
                let threadJSON = payload["thread"] as? JSONObject
            else { return }

            activeDiff = ""
            rebuildTimeline(from: threadJSON)
        } catch {
            transientError = error.localizedDescription
        }
    }

    func sendCurrentDraft(startNewThread: Bool = false) async {
        let trimmed = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard case .connected = connectionState else {
            transientError = "Connect to the desktop relay first."
            return
        }

        courierState = .working
        courierQuote = "at work"

        do {
            let threadID: String
            if !startNewThread, let selectedThreadID {
                threadID = selectedThreadID
            } else {
                let threadResult = try await client.sendRequest(
                    method: "thread/start",
                    params: [
                        "model": profile.defaultModel.isEmpty ? NSNull() : profile.defaultModel,
                        "cwd": profile.defaultWorkspace.isEmpty ? NSNull() : profile.defaultWorkspace,
                        "approvalPolicy": profile.approvalPolicy.rawValue,
                        "sandbox": profile.defaultSandbox.rawValue,
                        "serviceName": "Codex Remote iOS",
                        "personality": profile.personality.rawValue,
                        "experimentalRawEvents": false,
                        "persistExtendedHistory": true
                    ]
                )

                guard
                    let payload = threadResult as? JSONObject,
                    let threadJSON = payload["thread"] as? JSONObject,
                    let startedThreadID = string(threadJSON["id"])
                else {
                    throw CodexRemoteClient.ClientError.badResponse
                }

                let thread = parseThread(threadJSON)
                threads.removeAll { $0.id == thread.id }
                threads.insert(thread, at: 0)
                selectedThreadID = thread.id
                threadID = startedThreadID
            }

            timeline.append(
                RemoteTimelineItem(
                    id: "local-user-\(UUID().uuidString)",
                    kind: .user,
                    title: "You",
                    body: trimmed,
                    caption: nil
                )
            )

            let requestBody: JSONObject = [
                "threadId": threadID,
                "input": [
                    [
                        "type": "text",
                        "text": trimmed,
                        "text_elements": []
                    ]
                ],
                "cwd": profile.defaultWorkspace.isEmpty ? NSNull() : profile.defaultWorkspace,
                "approvalPolicy": profile.approvalPolicy.rawValue,
                "model": profile.defaultModel.isEmpty ? NSNull() : profile.defaultModel,
                "effort": profile.reasoningEffort.rawValue,
                "personality": profile.personality.rawValue
            ]

            let result = try await client.sendRequest(method: "turn/start", params: requestBody)
            if
                let payload = result as? JSONObject,
                let turnJSON = payload["turn"] as? JSONObject,
                let turnID = string(turnJSON["id"])
            {
                activeTurnIDs[threadID] = turnID
            }

            draftMessage = ""
            await refreshThreads()
        } catch {
            transientError = error.localizedDescription
            courierState = .error
            courierQuote = "send failed"
        }
    }

    func interruptActiveTurn() async {
        guard
            let selectedThreadID,
            let turnID = activeTurnIDs[selectedThreadID]
        else { return }

        do {
            _ = try await client.sendRequest(
                method: "turn/interrupt",
                params: [
                    "threadId": selectedThreadID,
                    "turnId": turnID
                ]
            )
            courierState = .ping
            courierQuote = "interrupted"
        } catch {
            transientError = error.localizedDescription
        }
    }

    func submitApproval(decision: String) {
        guard let pendingApproval else { return }

        let result: Any
        switch pendingApproval.kind {
        case .command:
            result = [
                "decision": decision
            ]
        case .fileChange:
            result = [
                "decision": decision
            ]
        case .permissions:
            let permissions = pendingApproval.params["permissions"] as? JSONObject ?? [:]
            let scope = decision == "acceptForSession" ? "session" : "turn"
            result = [
                "permissions": permissions,
                "scope": scope
            ]
        }

        approvalContinuation?.resume(returning: result)
        approvalContinuation = nil
        self.pendingApproval = nil
        courierState = .working
        courierQuote = "at work"
    }

    func submitPromptAnswers() {
        guard let pendingPrompt else { return }
        let answers = Dictionary(uniqueKeysWithValues: pendingPrompt.questions.map { question in
            (question.id, ["answers": [question.answer]])
        })
        promptContinuation?.resume(returning: ["answers": answers])
        promptContinuation = nil
        self.pendingPrompt = nil
        courierState = .working
        courierQuote = "back on it"
    }

    func updatePromptAnswer(questionID: String, answer: String) {
        guard var prompt = pendingPrompt else { return }
        guard let index = prompt.questions.firstIndex(where: { $0.id == questionID }) else { return }
        prompt.questions[index].answer = answer
        pendingPrompt = prompt
    }

    private func handleServerRequest(id: AnyHashable, method: String, params: JSONObject) async -> Any {
        switch method {
        case "item/commandExecution/requestApproval":
            let body = string(params["command"]) ?? string(params["reason"]) ?? "Codex wants to run a command."
            let available = (params["availableDecisions"] as? [String]) ?? ["accept", "decline"]
            pendingApproval = PendingApproval(
                id: UUID().uuidString,
                requestID: id,
                method: method,
                kind: .command,
                title: "Command Approval",
                body: body,
                params: params,
                decisions: available
            )
            courierState = .waiting
            courierQuote = "need your call"
            return await withCheckedContinuation { continuation in
                approvalContinuation = continuation
            }

        case "item/fileChange/requestApproval":
            let body = string(params["reason"]) ?? "Codex wants to apply a file change."
            pendingApproval = PendingApproval(
                id: UUID().uuidString,
                requestID: id,
                method: method,
                kind: .fileChange,
                title: "File Change Approval",
                body: body,
                params: params,
                decisions: ["accept", "acceptForSession", "decline"]
            )
            courierState = .waiting
            courierQuote = "need your call"
            return await withCheckedContinuation { continuation in
                approvalContinuation = continuation
            }

        case "item/permissions/requestApproval":
            let permissions = params["permissions"] as? JSONObject ?? [:]
            let body = string(params["reason"]) ?? Self.permissionsSummary(permissions)
            pendingApproval = PendingApproval(
                id: UUID().uuidString,
                requestID: id,
                method: method,
                kind: .permissions,
                title: "Permission Request",
                body: body,
                params: params,
                decisions: ["accept", "acceptForSession", "decline"]
            )
            courierState = .waiting
            courierQuote = "need your call"
            return await withCheckedContinuation { continuation in
                approvalContinuation = continuation
            }

        case "item/tool/requestUserInput":
            let rawQuestions = (params["questions"] as? [JSONObject]) ?? []
            let questions = rawQuestions.map { questionJSON in
                PromptQuestion(
                    id: string(questionJSON["id"]) ?? UUID().uuidString,
                    header: string(questionJSON["header"]) ?? "Question",
                    prompt: string(questionJSON["question"]) ?? "",
                    options: ((questionJSON["options"] as? [JSONObject]) ?? []).compactMap { string($0["label"]) },
                    allowsFreeform: bool(questionJSON["isOther"]),
                    answer: ""
                )
            }
            pendingPrompt = PendingPrompt(
                id: UUID().uuidString,
                requestID: id,
                method: method,
                questions: questions
            )
            courierState = .waiting
            courierQuote = "need your input"
            return await withCheckedContinuation { continuation in
                promptContinuation = continuation
            }

        default:
            return [:]
        }
    }

    private func handleNotification(method: String, params: JSONObject) {
        switch method {
        case "thread/started":
            if let threadJSON = params["thread"] as? JSONObject {
                let thread = parseThread(threadJSON)
                threads.removeAll { $0.id == thread.id }
                threads.insert(thread, at: 0)
                selectedThreadID = thread.id
            }

        case "thread/status/changed":
            guard let threadID = string(params["threadId"]) else { break }
            updateThreadStatus(threadID: threadID, status: params["status"] as? JSONObject)

        case "thread/name/updated":
            guard let threadID = string(params["threadId"]) else { break }
            let threadName = string(params["threadName"]) ?? "Untitled Thread"
            if let index = threads.firstIndex(where: { $0.id == threadID }) {
                threads[index].name = threadName
            }

        case "turn/started":
            if
                let threadID = string(params["threadId"]),
                let turnJSON = params["turn"] as? JSONObject,
                let turnID = string(turnJSON["id"])
            {
                activeTurnIDs[threadID] = turnID
            }
            courierState = .working
            courierQuote = "at work"

        case "turn/completed":
            if let threadID = string(params["threadId"]) {
                activeTurnIDs.removeValue(forKey: threadID)
                Task {
                    await refreshThreads()
                    if selectedThreadID == threadID {
                        await loadThread(id: threadID)
                    }
                }
            }
            courierState = .idle
            courierQuote = "on watch"

        case "turn/diff/updated":
            activeDiff = string(params["diff"]) ?? ""
            if !activeDiff.isEmpty {
                upsertTimelineItem(
                    id: "active-diff",
                    kind: .diff,
                    title: "Latest Diff",
                    body: activeDiff,
                    caption: "Turn patch preview"
                )
            }

        case "item/agentMessage/delta":
            guard let itemID = string(params["itemId"]), let delta = string(params["delta"]) else { break }
            appendDelta(id: itemID, kind: .agent, title: "Codex", delta: delta)
            courierState = .working
            courierQuote = "talking"

        case "item/commandExecution/outputDelta":
            guard let itemID = string(params["itemId"]), let delta = string(params["delta"]) else { break }
            appendDelta(id: itemID, kind: .command, title: "Shell Output", delta: delta)
            courierState = .working
            courierQuote = "in shell"

        case "error":
            let message = string(params["message"]) ?? "The Codex server emitted an error."
            transientError = message
            courierState = .error
            courierQuote = "hit a snag"

        default:
            break
        }
    }

    private func rebuildTimeline(from threadJSON: JSONObject) {
        streamedEntryIDs.removeAll()
        let turns = (threadJSON["turns"] as? [JSONObject]) ?? []
        var rebuilt: [RemoteTimelineItem] = []

        for turn in turns {
            let items = (turn["items"] as? [JSONObject]) ?? []
            for item in items {
                rebuilt.append(contentsOf: timelineItems(from: item))
            }
        }

        if !activeDiff.isEmpty {
            rebuilt.append(
                RemoteTimelineItem(
                    id: "active-diff",
                    kind: .diff,
                    title: "Latest Diff",
                    body: activeDiff,
                    caption: "Turn patch preview"
                )
            )
        }

        timeline = rebuilt
        for (index, item) in timeline.enumerated() {
            streamedEntryIDs[item.id] = index
        }
    }

    private func timelineItems(from itemJSON: JSONObject) -> [RemoteTimelineItem] {
        let itemType = string(itemJSON["type"]) ?? "system"
        let itemID = string(itemJSON["id"]) ?? UUID().uuidString

        switch itemType {
        case "userMessage":
            let content = ((itemJSON["content"] as? [JSONObject]) ?? [])
                .compactMap { string($0["text"]) }
                .joined(separator: "\n\n")
            return [
                RemoteTimelineItem(id: itemID, kind: .user, title: "You", body: content, caption: nil)
            ]

        case "agentMessage":
            return [
                RemoteTimelineItem(
                    id: itemID,
                    kind: .agent,
                    title: "Codex",
                    body: string(itemJSON["text"]) ?? "",
                    caption: string(itemJSON["phase"])
                )
            ]

        case "plan":
            return [
                RemoteTimelineItem(
                    id: itemID,
                    kind: .plan,
                    title: "Plan",
                    body: string(itemJSON["text"]) ?? "",
                    caption: nil
                )
            ]

        case "reasoning":
            let summary = ((itemJSON["summary"] as? [String]) ?? []).joined(separator: "\n")
            let content = ((itemJSON["content"] as? [String]) ?? []).joined(separator: "\n")
            let body = [summary, content].filter { !$0.isEmpty }.joined(separator: "\n\n")
            return [
                RemoteTimelineItem(
                    id: itemID,
                    kind: .reasoning,
                    title: "Reasoning",
                    body: body,
                    caption: nil
                )
            ]

        case "commandExecution":
            let command = string(itemJSON["command"]) ?? ""
            let output = string(itemJSON["aggregatedOutput"]) ?? ""
            let body = [command, output].filter { !$0.isEmpty }.joined(separator: "\n\n")
            return [
                RemoteTimelineItem(
                    id: itemID,
                    kind: .command,
                    title: "Command Execution",
                    body: body,
                    caption: string(itemJSON["status"])
                )
            ]

        case "fileChange":
            let changes = ((itemJSON["changes"] as? [JSONObject]) ?? []).compactMap { string($0["path"]) }
            let body = changes.isEmpty ? "File change recorded." : changes.joined(separator: "\n")
            return [
                RemoteTimelineItem(
                    id: itemID,
                    kind: .diff,
                    title: "File Changes",
                    body: body,
                    caption: string(itemJSON["status"])
                )
            ]

        case "mcpToolCall":
            return [
                RemoteTimelineItem(
                    id: itemID,
                    kind: .system,
                    title: "Tool Call",
                    body: "\(string(itemJSON["server"]) ?? "MCP") / \(string(itemJSON["tool"]) ?? "tool")",
                    caption: string(itemJSON["status"])
                )
            ]

        default:
            return []
        }
    }

    private func appendDelta(id: String, kind: TimelineKind, title: String, delta: String) {
        if let index = streamedEntryIDs[id], timeline.indices.contains(index) {
            timeline[index].body += delta
            return
        }

        let entry = RemoteTimelineItem(id: id, kind: kind, title: title, body: delta, caption: "streaming")
        streamedEntryIDs[id] = timeline.count
        timeline.append(entry)
    }

    private func upsertTimelineItem(id: String, kind: TimelineKind, title: String, body: String, caption: String?) {
        if let index = streamedEntryIDs[id], timeline.indices.contains(index) {
            timeline[index].body = body
            timeline[index].caption = caption
            return
        }

        let entry = RemoteTimelineItem(id: id, kind: kind, title: title, body: body, caption: caption)
        streamedEntryIDs[id] = timeline.count
        timeline.append(entry)
    }

    private func updateThreadStatus(threadID: String, status: JSONObject?) {
        guard let index = threads.firstIndex(where: { $0.id == threadID }) else { return }
        let type = string(status?["type"]) ?? "idle"
        let flags = (status?["activeFlags"] as? [String]) ?? []
        threads[index].waitingOnApproval = flags.contains("waitingOnApproval")
        threads[index].statusLabel = Self.statusLabel(for: type, waitingOnApproval: threads[index].waitingOnApproval)
        threads[index].updatedAt = Date()
    }

    private func parseThread(_ json: JSONObject) -> RemoteThread {
        let id = string(json["id"]) ?? UUID().uuidString
        let name = string(json["name"]) ?? string(json["preview"]) ?? "Untitled Thread"
        let preview = string(json["preview"]) ?? "No preview yet"
        let cwd = string(json["cwd"]) ?? ""
        let updatedSeconds = double(json["updatedAt"])
        let statusJSON = json["status"] as? JSONObject
        let statusType = string(statusJSON?["type"]) ?? "idle"
        let activeFlags = (statusJSON?["activeFlags"] as? [String]) ?? []
        let waiting = activeFlags.contains("waitingOnApproval")
        return RemoteThread(
            id: id,
            name: name,
            preview: preview,
            cwd: cwd,
            updatedAt: Date(timeIntervalSince1970: updatedSeconds),
            statusLabel: Self.statusLabel(for: statusType, waitingOnApproval: waiting),
            waitingOnApproval: waiting
        )
    }

    private static func statusLabel(for type: String, waitingOnApproval: Bool) -> String {
        if waitingOnApproval {
            return "Waiting on approval"
        }
        switch type {
        case "active":
            return "Active"
        case "systemError":
            return "System Error"
        case "notLoaded":
            return "Not Loaded"
        default:
            return "Idle"
        }
    }

    private static func permissionsSummary(_ permissions: JSONObject) -> String {
        var lines: [String] = ["Codex requested extra permissions."]
        if let network = permissions["network"] as? JSONObject, let enabled = network["enabled"] as? Bool, enabled {
            lines.append("Network access requested")
        }
        if let fileSystem = permissions["fileSystem"] as? JSONObject {
            let writePaths = (fileSystem["write"] as? [String]) ?? []
            let readPaths = (fileSystem["read"] as? [String]) ?? []
            if !readPaths.isEmpty {
                lines.append("Read: \(readPaths.joined(separator: ", "))")
            }
            if !writePaths.isEmpty {
                lines.append("Write: \(writePaths.joined(separator: ", "))")
            }
        }
        return lines.joined(separator: "\n")
    }

    private func string(_ value: Any?) -> String? {
        if let string = value as? String {
            return string
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    private func bool(_ value: Any?) -> Bool {
        if let bool = value as? Bool {
            return bool
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        return false
    }

    private func double(_ value: Any?) -> Double {
        if let double = value as? Double {
            return double
        }
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let string = value as? String {
            return Double(string) ?? 0
        }
        return 0
    }
}
