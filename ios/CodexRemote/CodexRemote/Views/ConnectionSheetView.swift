import SwiftUI

struct ConnectionSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let models: [CodexModelOption]
    let initialProfile: ConnectionProfile
    let connectionState: ConnectionState
    let onSave: (ConnectionProfile) -> Void
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    @State private var draft: ConnectionProfile

    init(
        models: [CodexModelOption],
        initialProfile: ConnectionProfile,
        connectionState: ConnectionState,
        onSave: @escaping (ConnectionProfile) -> Void,
        onConnect: @escaping () -> Void,
        onDisconnect: @escaping () -> Void
    ) {
        self.models = models
        self.initialProfile = initialProfile
        self.connectionState = connectionState
        self.onSave = onSave
        self.onConnect = onConnect
        self.onDisconnect = onDisconnect
        _draft = State(initialValue: initialProfile)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("ws://192.168.1.50:8765", text: $draft.websocketURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    SecureField("Capability token", text: $draft.token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Relay")
                } footer: {
                    Text("The URL syncs through the app group. The capability token is stored through shared keychain access.")
                }

                Section("Defaults") {
                    TextField("Workspace path on the desktop", text: $draft.defaultWorkspace)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if !models.isEmpty {
                        Picker("Known model", selection: $draft.defaultModel) {
                            Text("Use thread default").tag("")
                            ForEach(models) { model in
                                Text(model.displayName).tag(model.id)
                            }
                            if !draft.defaultModel.isEmpty, !models.contains(where: { $0.id == draft.defaultModel }) {
                                Text("Custom: \(draft.defaultModel)").tag(draft.defaultModel)
                            }
                        }
                    }

                    TextField("Custom model id (optional)", text: $draft.defaultModel)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Picker("Sandbox", selection: $draft.defaultSandbox) {
                        ForEach(SandboxPreference.allCases) { sandbox in
                            Text(sandbox.title).tag(sandbox)
                        }
                    }

                    Picker("Approval policy", selection: $draft.approvalPolicy) {
                        ForEach(ApprovalPreference.allCases) { approval in
                            Text(approval.title).tag(approval)
                        }
                    }

                    Picker("Reasoning", selection: $draft.reasoningEffort) {
                        ForEach(ReasoningPreference.allCases) { effort in
                            Text(effort.title).tag(effort)
                        }
                    }

                    Picker("Personality", selection: $draft.personality) {
                        ForEach(PersonalityPreference.allCases) { personality in
                            Text(personality.title).tag(personality)
                        }
                    }

                    Toggle("Auto-connect on launch", isOn: $draft.autoConnectOnLaunch)
                }

                Section("Status") {
                    LabeledContent("Relay") {
                        Text(connectionState.label)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    LabeledContent("Token") {
                        Text(draft.token.isEmpty ? "Not configured" : "Ready")
                            .foregroundStyle(draft.token.isEmpty ? AppTheme.secondaryText : AppTheme.success)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Remote Setup")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                }

                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button("Disconnect") {
                            onDisconnect()
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button("Save + Connect") {
                            onSave(draft)
                            onConnect()
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
