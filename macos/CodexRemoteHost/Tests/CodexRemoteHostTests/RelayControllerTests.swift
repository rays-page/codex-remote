import Foundation
import Testing
@testable import CodexRemoteHost

struct RelayControllerTests {
    @Test
    func writesWindowsCompatibleStatusAndPairingFiles() async throws {
        let workspace = URL(filePath: NSTemporaryDirectory())
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)

        let fakeCodex = workspace.appending(path: "codex")
        let fakeScript = """
        #!/bin/sh
        trap 'exit 0' TERM INT
        while true; do
          sleep 1
        done
        """
        try fakeScript.write(to: fakeCodex, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o755))],
            ofItemAtPath: fakeCodex.path(percentEncoded: false)
        )

        let stateRoot = workspace.appending(path: "state", directoryHint: .isDirectory)
        let controller = RelayController(stateRoot: stateRoot, executableOverride: fakeCodex)
        let configuration = RelayConfiguration.defaults(stateRoot: stateRoot).normalized(stateRoot: stateRoot)

        _ = try await controller.start(with: configuration)

        let statusFile = stateRoot.appending(path: "status.json")
        let pairingFile = stateRoot.appending(path: "pairing.json")
        #expect(FileManager.default.fileExists(atPath: statusFile.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: pairingFile.path(percentEncoded: false)))

        let statusData = try Data(contentsOf: statusFile)
        let pairingData = try Data(contentsOf: pairingFile)
        let status = try JSONDecoder().decode(RelayStatusPayload.self, from: statusData)
        let pairing = try JSONDecoder().decode(PairingPayload.self, from: pairingData)

        #expect(status.listenHost == configuration.listenHost)
        #expect(status.listenPort == configuration.listenPort)
        #expect(status.websocketURL == pairing.websocketURL)
        #expect(status.pairingURL == pairing.pairingURL)
        #expect(status.token == pairing.token)
        #expect(status.pid != nil)

        _ = await controller.stop()
    }
}
