import SwiftUI

struct RootView: View {
    @ObservedObject var store: CodexRemoteStore

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 16) {
                    header

                    if let pendingApproval = store.pendingApproval {
                        approvalBanner(pendingApproval)
                    }

                    if let selected = selectedThread {
                        SessionDetailView(
                            thread: selected,
                            timeline: store.timeline,
                            activeDiff: store.activeDiff,
                            canInterrupt: store.pendingApproval == nil && store.pendingPrompt == nil && selected.id == store.selectedThreadID,
                            onInterrupt: {
                                Task { await store.interruptActiveTurn() }
                            },
                            draftMessage: $store.draftMessage,
                            onSend: {
                                Task { await store.sendCurrentDraft() }
                            }
                        )
                    } else {
                        threadList
                    }
                }
                .padding(16)
            }
            .navigationTitle("Codex Remote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        store.showingConnectionSheet = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                    .tint(AppTheme.text)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        Button {
                            Task { await store.refreshThreads() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .tint(AppTheme.text)

                        Button {
                            store.selectedThreadID = nil
                            store.timeline = []
                            store.activeDiff = ""
                        } label: {
                            Image(systemName: "plus")
                        }
                        .tint(AppTheme.accent)
                    }
                }
            }
        }
        .task {
            await store.onAppear()
        }
        .sheet(isPresented: $store.showingConnectionSheet) {
            ConnectionSheetView(
                models: store.models,
                initialProfile: store.profile,
                connectionState: store.connectionState,
                onSave: { profile in
                    store.updateProfile(profile)
                },
                onConnect: {
                    Task { await store.connect() }
                },
                onDisconnect: {
                    store.disconnect()
                }
            )
            .presentationDetents([.large])
        }
        .sheet(item: $store.pendingPrompt) { prompt in
            PromptSheet(prompt: prompt, store: store)
        }
        .alert(
            "Codex Remote",
            isPresented: Binding(
                get: { store.transientError != nil },
                set: { newValue in
                    if !newValue {
                        store.transientError = nil
                    }
                }
            ),
            actions: {
                Button("OK", role: .cancel) { }
            },
            message: {
                Text(store.transientError ?? "")
            }
        )
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            CourierPodView(
                state: store.courierState,
                quote: store.courierQuote
            )

            HStack(spacing: 10) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 9, height: 9)

                Text(store.connectionState.label)
                    .foregroundStyle(AppTheme.text)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                if case .connected = store.connectionState {
                    Button("Disconnect") {
                        store.disconnect()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Connect") {
                        Task { await store.connect() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private var threadList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Threads")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.text)

            if store.threads.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("No remote threads yet.")
                        .foregroundStyle(AppTheme.text)
                        .font(.headline)
                    Text("Connect to the desktop relay, then start a new turn from the compose box or open an existing Codex thread.")
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(store.threads) { thread in
                            Button {
                                Task { await store.selectThread(thread) }
                            } label: {
                                ThreadCard(thread: thread, isSelected: store.selectedThreadID == thread.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                VStack(spacing: 10) {
                    TextEditor(text: $store.draftMessage)
                        .frame(minHeight: 86, maxHeight: 120)
                        .padding(12)
                        .scrollContentBackground(.hidden)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(AppTheme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(AppTheme.border, lineWidth: 1)
                                )
                        )
                        .foregroundStyle(AppTheme.text)

                    HStack {
                        Spacer()

                        Button("Start New Thread") {
                            Task { await store.sendCurrentDraft() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func approvalBanner(_ prompt: PendingApproval) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(prompt.title)
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            Text(prompt.body)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundStyle(AppTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                ForEach(prompt.decisions, id: \.self) { decision in
                    Button(decisionLabel(decision)) {
                        store.submitApproval(decision: decision)
                    }
                    .buttonStyle(decision == "decline" || decision == "cancel" ? .bordered : .borderedProminent)
                    .tint(decision == "decline" || decision == "cancel" ? .red : AppTheme.accent)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.elevatedSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AppTheme.warning.opacity(0.5), lineWidth: 1)
                )
        )
    }

    private func decisionLabel(_ raw: String) -> String {
        switch raw {
        case "acceptForSession":
            return "Accept For Session"
        case "decline":
            return "Decline"
        case "cancel":
            return "Cancel"
        default:
            return "Accept"
        }
    }

    private var selectedThread: RemoteThread? {
        guard let selectedThreadID = store.selectedThreadID else { return nil }
        return store.threads.first(where: { $0.id == selectedThreadID })
    }

    private var statusColor: Color {
        switch store.connectionState {
        case .connected:
            return AppTheme.success
        case .connecting:
            return AppTheme.warning
        case .failed:
            return .red
        case .disconnected:
            return AppTheme.secondaryText
        }
    }
}

private struct ThreadCard: View {
    let thread: RemoteThread
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(thread.name)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)

                Spacer()

                if thread.waitingOnApproval {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(AppTheme.warning)
                }
            }

            Text(thread.preview)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(2)

            HStack {
                Text(thread.statusLabel)
                Spacer()
                Text(thread.updatedAt.formatted(date: .omitted, time: .shortened))
            }
            .font(.caption)
            .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isSelected ? AppTheme.elevatedSurface : AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(isSelected ? AppTheme.accent.opacity(0.45) : AppTheme.border, lineWidth: 1)
                )
        )
    }
}

private struct PromptSheet: View {
    @Environment(\.dismiss) private var dismiss

    let prompt: PendingPrompt
    @ObservedObject var store: CodexRemoteStore

    var body: some View {
        NavigationStack {
            Form {
                ForEach(prompt.questions) { question in
                    Section(question.header) {
                        Text(question.prompt)
                            .foregroundStyle(AppTheme.secondaryText)

                        if !question.options.isEmpty {
                            Picker("Choice", selection: Binding(
                                get: { question.answer },
                                set: { store.updatePromptAnswer(questionID: question.id, answer: $0) }
                            )) {
                                Text("Select").tag("")
                                ForEach(question.options, id: \.self) { option in
                                    Text(option).tag(option)
                                }
                            }
                        }

                        if question.allowsFreeform || question.options.isEmpty {
                            TextField(
                                question.options.isEmpty ? "Answer" : "Other",
                                text: Binding(
                                    get: { question.answer },
                                    set: { store.updatePromptAnswer(questionID: question.id, answer: $0) }
                                )
                            )
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Need Your Input")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit") {
                        store.submitPromptAnswers()
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
