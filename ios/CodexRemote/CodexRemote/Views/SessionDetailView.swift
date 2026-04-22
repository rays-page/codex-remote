import SwiftUI

struct RemoteControlSurface: View {
    @ObservedObject var store: CodexRemoteStore
    let onShowSettings: () -> Void
    var showsSettingsButton = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            controlHeader

            if let pendingApproval = store.pendingApproval {
                ApprovalCardView(prompt: pendingApproval) { decision in
                    store.submitApproval(decision: decision)
                }
            }

            if let pendingPrompt = store.pendingPrompt {
                PromptCardView(prompt: pendingPrompt, store: store)
            }

            if let selectedThread = store.selectedThread {
                SelectedThreadCard(thread: selectedThread)
            } else {
                EmptyThreadCard()
            }

            defaultsCard
            recentThreadsCard

            if !store.activeDiff.isEmpty {
                diffCard
            }

            activityCard
            composerCard
        }
    }

    private var controlHeader: some View {
        HStack(spacing: 10) {
            Label(store.connectionState.label, systemImage: store.connectionState.isConnected ? "bolt.horizontal.fill" : "bolt.slash.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.text)

            if store.needsAttention {
                Text("Needs input")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.warning)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(AppTheme.warning.opacity(0.12))
                    )
            }

            Spacer()

            if showsSettingsButton {
                Button("Settings") {
                    onShowSettings()
                }
                .buttonStyle(.bordered)
            }

            Button(store.connectionState.isConnected ? "Disconnect" : "Connect") {
                if store.connectionState.isConnected {
                    store.disconnect()
                } else {
                    Task { await store.connect() }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(store.connectionState.isConnected ? AppTheme.warning : AppTheme.accent)
        }
        .padding(14)
        .background(cardBackground)
    }

    private var defaultsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Turn Defaults")
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            VStack(alignment: .leading, spacing: 10) {
                Text("Model")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)

                if store.models.isEmpty {
                    TextField(
                        "Thread default or model id",
                        text: Binding(
                            get: { store.profile.defaultModel },
                            set: { store.updateDefaultModel($0) }
                        )
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.elevatedSurface)
                    )
                    .foregroundStyle(AppTheme.text)
                } else {
                    Picker(
                        "Model",
                        selection: Binding(
                            get: { store.profile.defaultModel },
                            set: { store.updateDefaultModel($0) }
                        )
                    ) {
                        Text("Thread default").tag("")
                        ForEach(store.models) { model in
                            Text(model.displayName).tag(model.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppTheme.text)
                }
            }

            HStack(spacing: 10) {
                Picker(
                    "Reasoning",
                    selection: Binding(
                        get: { store.profile.reasoningEffort },
                        set: { store.updateReasoningEffort($0) }
                    )
                ) {
                    ForEach(ReasoningPreference.allCases) { effort in
                        Text(effort.title).tag(effort)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.text)

                Picker(
                    "Approval",
                    selection: Binding(
                        get: { store.profile.approvalPolicy },
                        set: { store.updateApprovalPolicy($0) }
                    )
                ) {
                    ForEach(ApprovalPreference.allCases) { approval in
                        Text(approval.title).tag(approval)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.text)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var recentThreadsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Threads")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                Spacer()

                Button("Refresh") {
                    Task { await store.refreshAll() }
                }
                .buttonStyle(.bordered)

                Button("New Thread") {
                    store.prepareForNewThread()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }

            if store.threads.isEmpty {
                Text("Connect to the relay to load threads, then pick one to resume or start fresh.")
                    .foregroundStyle(AppTheme.secondaryText)
                    .font(.subheadline)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(store.threads.prefix(5))) { thread in
                        Button {
                            Task { await store.selectThread(thread) }
                        } label: {
                            RemoteThreadCard(thread: thread, isSelected: store.selectedThreadID == thread.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var diffCard: some View {
        DisclosureGroup("Latest Diff") {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(store.activeDiff)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(AppTheme.success)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 8)
        }
        .tint(AppTheme.accent)
        .padding(16)
        .background(cardBackground)
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity")
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            if store.timeline.isEmpty {
                Text("No thread activity yet. Use the composer below to start or continue a turn.")
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                VStack(spacing: 10) {
                    ForEach(store.timeline) { item in
                        TimelineCard(item: item)
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var composerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(store.selectedThreadID == nil ? "New Thread Draft" : "Reply in Thread")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                Spacer()

                Button("Interrupt") {
                    Task { await store.interruptActiveTurn() }
                }
                .buttonStyle(.bordered)
                .disabled(store.selectedThreadID == nil || store.pendingApproval != nil || store.pendingPrompt != nil)
            }

            TextEditor(text: $store.draftMessage)
                .frame(minHeight: 92, maxHeight: 136)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(AppTheme.elevatedSurface)
                )
                .foregroundStyle(AppTheme.text)

            HStack {
                if let selectedThread = store.selectedThread {
                    Text("Sending to \(selectedThread.name)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                } else {
                    Text("The next send will start a fresh thread.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                Button(store.selectedThreadID == nil ? "Start Thread" : "Send Turn") {
                    let startsNewThread = store.selectedThreadID == nil
                    Task { await store.sendCurrentDraft(startNewThread: startsNewThread) }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .disabled(!store.connectionState.isConnected || store.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(AppTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }
}

private struct SelectedThreadCard: View {
    let thread: RemoteThread

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(thread.name)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.text)

            Text(thread.cwd.isEmpty ? thread.preview : thread.cwd)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.secondaryText)

            HStack(spacing: 10) {
                Label(thread.statusLabel, systemImage: thread.waitingOnApproval ? "hand.raised.fill" : "bolt.fill")
                Text(thread.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.caption)
            .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.elevatedSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
    }
}

private struct EmptyThreadCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No active thread")
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            Text("Pick a recent conversation to resume or leave it empty and the next send will start a new thread.")
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.elevatedSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
    }
}

private struct RemoteThreadCard: View {
    let thread: RemoteThread
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(thread.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
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
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? AppTheme.elevatedSurface : AppTheme.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isSelected ? AppTheme.accent.opacity(0.45) : AppTheme.border, lineWidth: 1)
                )
        )
    }
}

private struct ApprovalCardView: View {
    let prompt: PendingApproval
    let onDecision: (String) -> Void

    var body: some View {
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
                    decisionButton(for: decision)
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

    @ViewBuilder
    private func decisionButton(for decision: String) -> some View {
        if decision == "decline" || decision == "cancel" {
            Button(decisionLabel(decision)) {
                onDecision(decision)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        } else {
            Button(decisionLabel(decision)) {
                onDecision(decision)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
        }
    }
}

private struct PromptCardView: View {
    let prompt: PendingPrompt
    @ObservedObject var store: CodexRemoteStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Need Your Input")
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            ForEach(prompt.questions) { question in
                VStack(alignment: .leading, spacing: 8) {
                    Text(question.header)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.text)

                    if !question.prompt.isEmpty {
                        Text(question.prompt)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    if !question.options.isEmpty {
                        Picker(
                            "Choice",
                            selection: Binding(
                                get: { question.answer },
                                set: { store.updatePromptAnswer(questionID: question.id, answer: $0) }
                            )
                        ) {
                            Text("Select").tag("")
                            ForEach(question.options, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppTheme.text)
                    }

                    if question.allowsFreeform || question.options.isEmpty {
                        TextField(
                            question.options.isEmpty ? "Answer" : "Other",
                            text: Binding(
                                get: { question.answer },
                                set: { store.updatePromptAnswer(questionID: question.id, answer: $0) }
                            )
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppTheme.background)
                        )
                        .foregroundStyle(AppTheme.text)
                    }
                }
            }

            HStack {
                Spacer()

                Button("Submit Answers") {
                    store.submitPromptAnswers()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.elevatedSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AppTheme.accent.opacity(0.32), lineWidth: 1)
                )
        )
    }
}

private struct TimelineCard: View {
    let item: RemoteTimelineItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.text)

                Spacer()

                if let caption = item.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            Text(item.body.isEmpty ? " " : item.body)
                .font(item.kind == .command || item.kind == .diff
                    ? .system(size: 12, weight: .regular, design: .monospaced)
                    : .system(size: 15, weight: .regular, design: .default)
                )
                .foregroundStyle(item.kind == .command || item.kind == .diff ? item.tint : AppTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.background)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(item.tint.opacity(0.16))
                        .frame(width: 4)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
    }
}
