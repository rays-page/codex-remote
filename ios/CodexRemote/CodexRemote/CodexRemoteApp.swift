import SwiftUI

@main
struct CodexRemoteApp: App {
    @StateObject private var store = CodexRemoteStore()

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .onOpenURL { url in
                    store.handleDeepLink(url)
                }
        }
    }
}
