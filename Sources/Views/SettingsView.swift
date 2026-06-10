import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Engine")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)

                Picker("", selection: $appState.aiEngineRaw) {
                    ForEach(AIEngine.allCases, id: \.rawValue) { engine in
                        Text(engine.label).tag(engine.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)

                // on-device availability status
                Text(LocalAIService.status.isReady
                     ? "✓ \(LocalAIService.status.message)"
                     : "on-device: \(LocalAIService.status.message)")
                    .font(.system(size: 10))
                    .foregroundColor(LocalAIService.status.isReady ? .green : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("OpenAI API Key")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)

                SecureField("sk-...", text: $appState.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
            }

            Divider()
            
            HStack {
                Text("Shortcut:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("⌃ ⌥ A")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Spacer()
        }
        .padding(16)
        .frame(width: 280, height: 230)
    }
}
