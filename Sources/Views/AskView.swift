import SwiftUI

struct AskView: View {
    @ObservedObject var appState: AppState
    @State private var prompt: String = ""
    @State private var response: String = ""
    @State private var isLoading: Bool = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Text("ask right here")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                
                // Settings Button
                Button(action: {
                    appState.showSettings()
                }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("Settings")
                
                // Close Button
                Button(action: {
                    appState.closeAskDialog()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Context (if any)
            if !appState.selectedText.isEmpty {
                Text(appState.selectedText)
                    .font(.system(size: 12))
                    .lineLimit(3)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .foregroundColor(.secondary)
            }
            
            // Input
            TextField("Ask anything...", text: $prompt)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.primary.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .focused($isFocused)
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
                }
                .frame(minHeight: 120, maxHeight: 400) // Ensure at least ~5-6 lines height
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
            self.prompt = ""
            self.isFocused = true
        }
    }
    
    func sendToAI() {
        guard !prompt.isEmpty else { return }
        let currentPrompt = prompt
        let currentContext = appState.selectedText
        isLoading = true
        response = "" // Clear previous response when sending new one
        
        Task {
            let aiService = AIService(apiKey: appState.apiKey)
            do {
                let result = try await aiService.ask(prompt: currentPrompt, context: currentContext)
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
