import SwiftUI

struct AskView: View {
    @ObservedObject var appState: AppState
    @State private var prompt: String = ""
    @State private var response: String = ""
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
                                // If context is visible (manual or data), hide it and clear data
                                isContextVisible = false
                                appState.selectedText = ""
                            } else {
                                // If hidden, show manual context
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
                
                // Settings Button
                Button(action: {
                    appState.showSettings()
                }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("settings")
                
                // Close Button
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
            TextField("Ask anything...", text: $prompt)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.primary.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .focused($isFocused)
                .accentColor(.primary) // Black/Primary cursor
                .onSubmit {
                    sendToAI()
                }
            
            if !response.isEmpty {
                ScrollView {
                    Text(response)
                        .font(.system(size: 13, design: .serif))
                        .lineSpacing(4)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled) // Enable copy/selection
                }
                .frame(minHeight: 160, maxHeight: 400) // Ensure at least ~7-8 lines height
                .background(Color.primary.opacity(0.03))
                .cornerRadius(12)
                .padding(16)
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
            self.response = ""
            self.isLoading = false
            self.isContextVisible = !appState.selectedText.isEmpty
            self.prompt = ""
            self.isFocused = true
        }
    }
    
    func sendToAI() {
        guard !prompt.isEmpty else { return }
        let currentPrompt = prompt
        let currentContext = appState.selectedText
        
        // Reset state for new question
        isLoading = true
        response = ""
        
        // Cycle focus to prevent automatic text highlighting
        isFocused = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isFocused = true
        }
        
        // resolvedEngine never returns .auto — it's already settled to a concrete engine.
        let engine = appState.resolvedEngine
        let apiKey = appState.apiKey
        Task {
            do {
                let result: String
                switch engine {
                case .onDevice:
                    result = try await LocalAIService().ask(prompt: currentPrompt, context: currentContext)
                case .openAI, .auto:
                    result = try await AIService(apiKey: apiKey).ask(prompt: currentPrompt, context: currentContext)
                }
                await MainActor.run {
                    withAnimation {
                        self.response = result
                        self.isLoading = false
                        // Save to history
                        appState.addToHistory(question: currentPrompt, answer: result, context: currentContext)
                    }
                }
            } catch {
                await MainActor.run {
                    self.response = "Error: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
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
