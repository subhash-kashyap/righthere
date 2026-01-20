import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 12) {
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
        .frame(width: 250, height: 120)
    }
}
