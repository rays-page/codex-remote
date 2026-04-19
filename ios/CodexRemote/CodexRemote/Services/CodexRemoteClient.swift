import Foundation

@MainActor
final class CodexRemoteClient {
    typealias JSONObject = [String: Any]
    typealias ServerRequestHandler = (AnyHashable, String, JSONObject) async -> Any
    typealias NotificationHandler = (String, JSONObject) -> Void
    typealias DisconnectHandler = (String) -> Void

    enum ClientError: LocalizedError {
        case invalidURL
        case notConnected
        case serverError(String)
        case badResponse

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "The websocket URL is invalid."
            case .notConnected:
                return "No Codex websocket is connected."
            case .serverError(let message):
                return message
            case .badResponse:
                return "The Codex server returned an unreadable response."
            }
        }
    }

    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var nextRequestID = 1
    private var pendingContinuations: [String: CheckedContinuation<Any, Error>] = [:]

    var onNotification: NotificationHandler?
    var onServerRequest: ServerRequestHandler?
    var onDisconnect: DisconnectHandler?

    func connect(profile: ConnectionProfile) async throws {
        disconnect()

        guard let url = URL(string: profile.websocketURL) else {
            throw ClientError.invalidURL
        }

        var request = URLRequest(url: url)
        if !profile.token.isEmpty {
            request.setValue("Bearer \(profile.token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 30

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: request)
        self.session = session
        self.task = task
        task.resume()
        receiveLoop()

        _ = try await sendRequest(
            method: "initialize",
            params: [
                "clientInfo": [
                    "name": "codex-remote-ios",
                    "title": "Codex Remote",
                    "version": "1.0.0"
                ],
                "capabilities": [
                    "experimentalApi": true,
                    "optOutNotificationMethods": []
                ]
            ]
        )
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        session?.invalidateAndCancel()
        task = nil
        session = nil

        for continuation in pendingContinuations.values {
            continuation.resume(throwing: ClientError.notConnected)
        }
        pendingContinuations.removeAll()
    }

    func sendRequest(method: String, params: Any) async throws -> Any {
        guard task != nil else {
            throw ClientError.notConnected
        }

        let requestID = nextRequestID
        nextRequestID += 1

        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": requestID,
            "method": method,
            "params": params
        ]

        try await sendJSON(payload)

        return try await withCheckedThrowingContinuation { continuation in
            pendingContinuations[String(requestID)] = continuation
        }
    }

    func sendResponse(id: AnyHashable, result: Any) async {
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": rawID(from: id),
            "result": result
        ]

        try? await sendJSON(payload)
    }

    private func receiveLoop() {
        guard let task else { return }

        task.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let message):
                    await self.handle(message)
                    self.receiveLoop()
                case .failure(let error):
                    self.onDisconnect?(error.localizedDescription)
                    self.disconnect()
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) async {
        let data: Data
        switch message {
        case .data(let binary):
            data = binary
        case .string(let string):
            data = Data(string.utf8)
        @unknown default:
            return
        }

        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? JSONObject
        else {
            onDisconnect?("Received an invalid JSON packet from Codex.")
            return
        }

        if let id = object["id"] {
            if let method = object["method"] as? String {
                let params = object["params"] as? JSONObject ?? [:]
                if let handler = onServerRequest {
                    let result = await handler(anyHashableID(from: id), method, params)
                    await sendResponse(id: anyHashableID(from: id), result: result)
                } else {
                    await sendResponse(id: anyHashableID(from: id), result: [:])
                }
                return
            }

            let key = requestKey(from: id)
            guard let continuation = pendingContinuations.removeValue(forKey: key) else {
                return
            }

            if let error = object["error"] as? JSONObject {
                let message = (error["message"] as? String) ?? "The Codex server returned an error."
                continuation.resume(throwing: ClientError.serverError(message))
            } else if let result = object["result"] {
                continuation.resume(returning: result)
            } else {
                continuation.resume(throwing: ClientError.badResponse)
            }
            return
        }

        if let method = object["method"] as? String {
            let params = object["params"] as? JSONObject ?? [:]
            onNotification?(method, params)
        }
    }

    private func sendJSON(_ payload: [String: Any]) async throws {
        guard let task else {
            throw ClientError.notConnected
        }

        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        let string = String(decoding: data, as: UTF8.self)
        try await task.send(.string(string))
    }

    private func requestKey(from rawID: Any) -> String {
        if let string = rawID as? String {
            return string
        }
        if let number = rawID as? NSNumber {
            return number.stringValue
        }
        return String(describing: rawID)
    }

    private func anyHashableID(from rawID: Any) -> AnyHashable {
        if let string = rawID as? String {
            return AnyHashable(string)
        }
        if let number = rawID as? NSNumber {
            return AnyHashable(number.intValue)
        }
        return AnyHashable(String(describing: rawID))
    }

    private func rawID(from id: AnyHashable) -> Any {
        if let intValue = id.base as? Int {
            return intValue
        }
        if let stringValue = id.base as? String {
            return stringValue
        }
        return String(describing: id)
    }
}
