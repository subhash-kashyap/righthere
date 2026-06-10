import SwiftUI

/// One question-answer exchange in the ask box. `answer` grows while the
/// reply streams in.
struct ChatTurn: Identifiable, Equatable {
    let id = UUID()
    let question: String
    var answer: String = ""
}

struct AskView: View {
    @ObservedObject var appState: AppState
    @State private var prompt: String = ""
    @State private var turns: [ChatTurn] = []
    @State private var conversation: Conversation?
    @State private var streamTask: Task<Void, Never>?
    @State private var isLoading: Bool = false
    @State private var isContextVisible: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Text("ask right here")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)

                // Toggle Button +/- c
                Text(isContextVisible || !appState.selectedText.isEmpty ? "- c" : "+ c")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.7))
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            if isContextVisible || !appState.selectedText.isEmpty {
                                isContextVisible = false
                                appState.selectedText = ""
                            } else {
                                isContextVisible = true
                            }
                        }
                    }

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.8)
                }

                Spacer()

                if appState.resolvedEngine == .onDevice {
                    Text("local")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .help("answers come from the on-device model — nothing leaves this Mac")
                }

                Button(action: {
                    appState.showSettings()
                }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("settings")

                Button(action: {
                    appState.closeAskDialog()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .help("close")
            }
            .padding(.horizontal, 16)
            .padding(.top, 24) // Increased top padding to avoid cutoff
            .padding(.bottom, 12)

            // Context (if any)
            if isContextVisible || !appState.selectedText.isEmpty {
                VStack(alignment: .trailing, spacing: 6) {
                    ZStack(alignment: .topLeading) {
                        if appState.selectedText.isEmpty {
                            Text("put context here...")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary.opacity(0.4))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 14)
                        }

                        TextEditor(text: $appState.selectedText)
                            .font(.system(size: 12))
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 80)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(8)

                    HStack(spacing: 8) {
                        QuickActionButton(title: "eli5") {
                            prompt = "Explain this like I'm 5: "
                            isFocused = true
                        }
                        QuickActionButton(title: "rewrite") {
                            prompt = "Rewrite this to be more professional: "
                            isFocused = true
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }

            // Input
            TextField(turns.isEmpty ? "Ask anything..." : "follow up...", text: $prompt)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.primary.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .focused($isFocused)
                .accentColor(.primary)
                .onSubmit {
                    sendToAI()
                }

            // Transcript
            if !turns.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(turns) { turn in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(turn.question)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundColor(.secondary)
                                    Text(turn.answer.isEmpty ? "…" : turn.answer)
                                        .font(.system(size: 13, design: .serif))
                                        .lineSpacing(4)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                }
                                .id(turn.id)
                            }
                        }
                        .padding(16)
                    }
                    .frame(minHeight: 160, maxHeight: 400)
                    .background(Color.primary.opacity(0.03))
                    .cornerRadius(12)
                    .padding(16)
                    // Scroll once when a turn is added so its question is in
                    // view, then stay put — following the stream down would
                    // yank the text away while the user reads.
                    .onChange(of: turns.count) { _, _ in
                        if let last = turns.last {
                            proxy.scrollTo(last.id, anchor: .top)
                        }
                    }
                }
                .transition(.opacity)
            }

            Spacer(minLength: 16)
        }
        .frame(width: 400)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
        .onAppear {
            isFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResetAskView"))) { _ in
            // Each summon starts a fresh conversation.
            streamTask?.cancel()
            streamTask = nil
            conversation = nil
            turns = []
            prompt = ""
            isLoading = false
            isContextVisible = !appState.selectedText.isEmpty
            isFocused = true
        }
    }

    func sendToAI() {
        guard !prompt.isEmpty, !isLoading else { return }
        let currentPrompt = prompt
        // The engine's transcript carries earlier turns, so pasted context
        // only needs to ride along on the first question.
        let currentContext = turns.isEmpty ? appState.selectedText : ""
        // The question stays in the input on purpose — the user clears or
        // edits it themselves when they want a follow-up.
        isLoading = true

        // First question pins the conversation to whichever engine is
        // ready right now; follow-ups stay on it.
        let convo = conversation ?? Conversation(engine: appState.resolvedEngine, api: appState.apiService)
        conversation = convo

        let turn = ChatTurn(question: currentPrompt)
        withAnimation { turns.append(turn) }

        streamTask = Task {
            do {
                var fullReply = ""
                for try await snapshot in convo.streamAnswer(to: currentPrompt, context: currentContext) {
                    fullReply = snapshot
                    if let index = turns.firstIndex(where: { $0.id == turn.id }) {
                        turns[index].answer = snapshot
                    }
                }
                appState.addToHistory(question: currentPrompt, answer: fullReply, context: currentContext)
            } catch {
                if !Task.isCancelled,
                   let index = turns.firstIndex(where: { $0.id == turn.id }) {
                    let message = "Error: \(error.localizedDescription)"
                    turns[index].answer = turns[index].answer.isEmpty
                        ? message
                        : turns[index].answer + "\n\n" + message
                }
            }
            isLoading = false
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct QuickActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.1))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}
