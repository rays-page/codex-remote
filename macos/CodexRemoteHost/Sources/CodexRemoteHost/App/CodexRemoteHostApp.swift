import SwiftUI

@main
struct CodexRemoteHostApp: App {
    @StateObject private var store = RelayStore()

    var body: some Scene {
        WindowGroup("Codex Remote Host", id: "main") {
            NavigationStack {
                ContentView(store: store)
            }
            .frame(minWidth: 920, minHeight: 720)
        }

        MenuBarExtra {
            MenuBarStatusView(store: store)
        } label: {
            Image(systemName: store.snapshot.menuSymbolName)
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuBarStatusView: View {
    @Environment(\.openWindow) private var openWindow

    @ObservedObject var store: RelayStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.snapshot.headline)
                .font(.system(size: 14, weight: .bold, design: .rounded))

            Text(store.snapshot.detail)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Button("Open Host Console") {
                openWindow(id: "main")
            }

            Button(store.snapshot.health == .running ? "Restart Relay" : "Start Relay") {
                if store.snapshot.health == .running {
                    store.restartRelay()
                } else {
                    store.startRelay()
                }
            }

            Button("Copy Pair Link") {
                store.copyPairingLink()
            }
            .disabled(store.snapshot.pairingURL == nil)

            Button("Open Logs") {
                store.openLogs()
            }

            Button("Reveal State Folder") {
                store.openStateFolder()
            }
        }
        .frame(width: 300)
        .padding(6)
    }
}
