import AppKit
import Foundation
import Network

final class RelayController: @unchecked Sendable {
    struct Paths {
        let stateRoot: URL

        var statusFile: URL { stateRoot.appending(path: "status.json") }
        var tokenFile: URL { stateRoot.appending(path: "capability.token") }
        var pairingFile: URL { stateRoot.appending(path: "pairing.json") }
        var logFile: URL { stateRoot.appending(path: "app-server.log") }
        var pidFile: URL { stateRoot.appending(path: "app-server.pid") }
        var configFile: URL { stateRoot.appending(path: "config.json") }
    }

    private let fileManager: FileManager
    private let environment: [String: String]
    private let stateRoot: URL
    private let executableOverride: URL?

    init(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        stateRoot: URL? = nil,
        executableOverride: URL? = nil
    ) {
        self.fileManager = fileManager
        self.environment = environment
        self.stateRoot = stateRoot ?? Self.defaultStateRoot(fileManager: fileManager)
        self.executableOverride = executableOverride
    }

    func loadConfiguration() -> RelayConfiguration {
        let paths = Paths(stateRoot: stateRoot)
        let fallback = RelayConfiguration.defaults(stateRoot: paths.stateRoot)
        guard let data = try? Data(contentsOf: paths.configFile) else {
            return fallback
        }
        guard let decoded = try? JSONDecoder().decode(RelayConfiguration.self, from: data) else {
            return fallback
        }
        return decoded.normalized(stateRoot: paths.stateRoot)
    }

    func saveConfiguration(_ configuration: RelayConfiguration) throws {
        let paths = Paths(stateRoot: stateRoot)
        try ensureStateDirectory(paths: paths)
        let normalized = configuration.normalized(stateRoot: paths.stateRoot)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(normalized)
        try data.write(to: paths.configFile, options: .atomic)
    }

    func loadSnapshot(
        transientHealth: RelayHealth? = nil,
        errorSummary: String? = nil
    ) -> RelaySnapshot {
        let paths = Paths(stateRoot: stateRoot)
        let configuration = loadConfiguration()
        let runtime = locateCodexExecutable()
        let status = readStatus(paths: paths)
        let pid = readPID(paths: paths)
        let processIsRunning = pid.map(processRunning(pid:)) ?? false
        let reachable = processIsRunning && probeRelay(host: configuration.listenHost, port: configuration.listenPort)
        let health = transientHealth ?? resolveHealth(
            runtime: runtime,
            processIsRunning: processIsRunning,
            reachable: reachable,
            errorSummary: errorSummary
        )

        let websocketURL = status?.websocketURL ?? buildWebsocketURL(
            host: configuration.listenHost,
            port: configuration.listenPort,
            publicWSURL: configuration.publicWSURL
        )

        let pairingURL: String?
        if let stored = status?.pairingURL {
            pairingURL = stored
        } else if let token = readToken(paths: paths) {
            pairingURL = buildPairingURL(websocketURL: websocketURL, token: token)
        } else {
            pairingURL = nil
        }

        let lastStartedAt = status?.startedAt.flatMap {
            Date(timeIntervalSince1970: TimeInterval($0))
        }

        return RelaySnapshot(
            hostName: Host.current().localizedName ?? "This Mac",
            health: health,
            configuration: configuration,
            websocketURL: websocketURL,
            pairingURL: pairingURL,
            runtimeExecutable: runtime?.path(percentEncoded: false),
            logFile: paths.logFile,
            stateRoot: paths.stateRoot,
            lastStartedAt: lastStartedAt,
            processID: pid.map(Int.init),
            tokenExists: fileManager.fileExists(atPath: paths.tokenFile.path(percentEncoded: false)),
            processRunning: processIsRunning,
            reachable: reachable,
            errorSummary: errorSummary
        )
    }

    func start(with configuration: RelayConfiguration) async throws -> RelaySnapshot {
        let paths = Paths(stateRoot: stateRoot)
        try ensureStateDirectory(paths: paths)

        let normalized = configuration.normalized(stateRoot: paths.stateRoot)
        try saveConfiguration(normalized)

        if let existingPID = readPID(paths: paths), processRunning(pid: existingPID) {
            return loadSnapshot()
        }

        guard let executable = locateCodexExecutable() else {
            throw RelayActionError.missingCodex
        }

        let token = try ensureToken(paths: paths)
        let websocketURL = buildWebsocketURL(
            host: normalized.listenHost,
            port: normalized.listenPort,
            publicWSURL: normalized.publicWSURL
        )
        let pairingURL = buildPairingURL(websocketURL: websocketURL, token: token)

        if !fileManager.fileExists(atPath: paths.logFile.path(percentEncoded: false)) {
            fileManager.createFile(atPath: paths.logFile.path(percentEncoded: false), contents: nil)
        }

        let logHandle = try FileHandle(forWritingTo: paths.logFile)
        try logHandle.seekToEnd()

        let process = Process()
        process.executableURL = executable
        process.arguments = [
            "app-server",
            "--listen", "ws://\(normalized.listenHost):\(normalized.listenPort)",
            "--ws-auth", "capability-token",
            "--ws-token-file", paths.tokenFile.path(percentEncoded: false),
        ]
        process.currentDirectoryURL = paths.stateRoot
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = logHandle
        process.standardError = logHandle
        try process.run()

        writePID(process.processIdentifier, paths: paths)
        let status = RelayStatusPayload(
            pid: Int(process.processIdentifier),
            startedAt: Int(Date().timeIntervalSince1970),
            listenHost: normalized.listenHost,
            listenPort: normalized.listenPort,
            websocketURL: websocketURL,
            pairingURL: pairingURL,
            token: token,
            runtimeExecutable: executable.path(percentEncoded: false),
            logFile: paths.logFile.path(percentEncoded: false),
            tokenFile: paths.tokenFile.path(percentEncoded: false),
            statusFile: paths.statusFile.path(percentEncoded: false),
            foreground: false,
            running: true
        )
        try writeStatus(status, paths: paths)

        try await Task.sleep(nanoseconds: 900_000_000)
        if !processRunning(pid: process.processIdentifier) {
            let detail = logTail(paths: paths).isEmpty
                ? "Codex Remote Host could not keep the relay alive."
                : "Codex Remote Host could not keep the relay alive.\n\n\(logTail(paths: paths))"
            throw RelayActionError.couldNotLaunch(detail)
        }

        return loadSnapshot()
    }

    func stop() async -> RelaySnapshot {
        let paths = Paths(stateRoot: stateRoot)
        guard let pid = readPID(paths: paths) else {
            return loadSnapshot()
        }

        if processRunning(pid: pid) {
            kill(pid, SIGTERM)
            for _ in 0..<8 {
                if !processRunning(pid: pid) {
                    break
                }
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
            if processRunning(pid: pid) {
                kill(pid, SIGKILL)
            }
        }

        try? fileManager.removeItem(at: paths.pidFile)
        return loadSnapshot()
    }

    func restart(with configuration: RelayConfiguration) async throws -> RelaySnapshot {
        _ = await stop()
        return try await start(with: configuration)
    }

    func revealLogs() {
        let paths = Paths(stateRoot: stateRoot)
        guard fileManager.fileExists(atPath: paths.logFile.path(percentEncoded: false)) else { return }
        NSWorkspace.shared.open(paths.logFile)
    }

    func revealStateFolder() {
        NSWorkspace.shared.open(stateRoot)
    }

    func copyString(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func ensureStateDirectory(paths: Paths) throws {
        try fileManager.createDirectory(at: paths.stateRoot, withIntermediateDirectories: true)
    }

    private func readStatus(paths: Paths) -> RelayStatusPayload? {
        guard let data = try? Data(contentsOf: paths.statusFile) else {
            return nil
        }
        return try? JSONDecoder().decode(RelayStatusPayload.self, from: data)
    }

    private func writeStatus(_ payload: RelayStatusPayload, paths: Paths) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let statusData = try encoder.encode(payload)
        try statusData.write(to: paths.statusFile, options: .atomic)

        let pairing = PairingPayload(
            websocketURL: payload.websocketURL,
            token: payload.token,
            pairingURL: payload.pairingURL
        )
        let pairingData = try encoder.encode(pairing)
        try pairingData.write(to: paths.pairingFile, options: .atomic)
    }

    private func readPID(paths: Paths) -> Int32? {
        guard let value = try? String(contentsOf: paths.pidFile, encoding: .utf8) else {
            return nil
        }
        return Int32(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func writePID(_ pid: Int32, paths: Paths) {
        try? String(pid).write(to: paths.pidFile, atomically: true, encoding: .utf8)
    }

    private func ensureToken(paths: Paths) throws -> String {
        if let existing = readToken(paths: paths) {
            return existing
        }
        let token = makeCapabilityToken()
        try token.write(to: paths.tokenFile, atomically: true, encoding: .utf8)
        return token
    }

    private func readToken(paths: Paths) -> String? {
        guard let raw = try? String(contentsOf: paths.tokenFile, encoding: .utf8) else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func makeCapabilityToken() -> String {
        let bytes = (0..<36).map { _ in UInt8.random(in: 0...255) }
        let encoded = Data(bytes).base64EncodedString()
        return encoded
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func resolveHealth(
        runtime: URL?,
        processIsRunning: Bool,
        reachable: Bool,
        errorSummary: String?
    ) -> RelayHealth {
        if errorSummary != nil {
            return .error
        }
        if runtime == nil {
            return .notInstalled
        }
        if processIsRunning && reachable {
            return .running
        }
        if processIsRunning {
            return .stalled
        }
        return .stopped
    }

    private func locateCodexExecutable() -> URL? {
        if let executableOverride, fileManager.isExecutableFile(atPath: executableOverride.path(percentEncoded: false)) {
            return executableOverride
        }

        let absoluteCandidates = [
            "/Applications/Codex.app/Contents/Resources/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex",
        ]

        for path in absoluteCandidates where fileManager.isExecutableFile(atPath: path) {
            return URL(filePath: path)
        }

        if let path = environment["PATH"] {
            for directory in path.split(separator: ":") {
                let candidate = URL(filePath: String(directory)).appending(path: "codex")
                if fileManager.isExecutableFile(atPath: candidate.path(percentEncoded: false)) {
                    return candidate
                }
            }
        }

        return nil
    }

    private func processRunning(pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        return kill(pid, 0) == 0 || errno == EPERM
    }

    private func probeRelay(host: String, port: Int) -> Bool {
        final class ProbeResult: @unchecked Sendable {
            var didConnect = false
        }

        guard let port = NWEndpoint.Port(rawValue: UInt16(port)) else {
            return false
        }
        let probeHost = probeHostForListenAddress(host)
        let connection = NWConnection(host: NWEndpoint.Host(probeHost), port: port, using: .tcp)
        let semaphore = DispatchSemaphore(value: 0)
        let queue = DispatchQueue(label: "CodexRemoteHost.Probe")
        let resultBox = ProbeResult()

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                resultBox.didConnect = true
                connection.cancel()
                semaphore.signal()
            case .failed, .cancelled:
                semaphore.signal()
            default:
                break
            }
        }

        connection.start(queue: queue)
        let result = semaphore.wait(timeout: .now() + 0.35)
        connection.cancel()
        return result == .success && resultBox.didConnect
    }

    private func probeHostForListenAddress(_ host: String) -> String {
        switch host {
        case "0.0.0.0", "::":
            return "127.0.0.1"
        default:
            return host
        }
    }

    private func logTail(paths: Paths, limit: Int = 600) -> String {
        guard let raw = try? String(contentsOf: paths.logFile, encoding: .utf8) else {
            return ""
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= limit {
            return trimmed
        }
        return String(trimmed.suffix(limit))
    }

    private func buildWebsocketURL(host: String, port: Int, publicWSURL: String) -> String {
        let trimmed = publicWSURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        let actualHost: String
        switch host {
        case "0.0.0.0", "::":
            actualHost = detectLANIPAddress()
        default:
            actualHost = host
        }
        return "ws://\(actualHost):\(port)"
    }

    private func buildPairingURL(websocketURL: String, token: String) -> String {
        var components = URLComponents()
        components.scheme = "codexremote"
        components.host = "pair"
        components.queryItems = [
            URLQueryItem(name: "url", value: websocketURL),
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "name", value: "Codex Remote"),
        ]
        return components.url?.absoluteString ?? "codexremote://pair"
    }

    private func detectLANIPAddress() -> String {
        let address = "127.0.0.1"
        var interfaceAddress: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&interfaceAddress) == 0, let firstAddress = interfaceAddress else {
            return address
        }
        defer { freeifaddrs(interfaceAddress) }

        var fallback: String?

        for pointer in sequence(first: firstAddress, next: { $0.pointee.ifa_next }) {
            let flags = Int32(pointer.pointee.ifa_flags)
            let interface = String(cString: pointer.pointee.ifa_name)
            let family = pointer.pointee.ifa_addr.pointee.sa_family
            guard family == UInt8(AF_INET) else { continue }
            guard (flags & IFF_UP) != 0, (flags & IFF_RUNNING) != 0 else { continue }
            guard (flags & IFF_LOOPBACK) == 0 else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                pointer.pointee.ifa_addr,
                socklen_t(pointer.pointee.ifa_addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )

            guard result == 0 else { continue }
            let candidate = String(decoding: hostname.prefix { $0 != 0 }.map(UInt8.init), as: UTF8.self)
            if interface.hasPrefix("en") || interface.hasPrefix("bridge") || interface.hasPrefix("utun") {
                return candidate
            }
            fallback = fallback ?? candidate
        }

        return fallback ?? address
    }

    private static func defaultStateRoot(fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(filePath: NSHomeDirectory()).appending(path: "Library/Application Support")
        return base.appending(path: "CodexRemote", directoryHint: .isDirectory)
    }
}
