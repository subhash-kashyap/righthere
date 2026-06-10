import SwiftUI

struct SettingsView: View {
    // Reads the same defaults keys as AppState. Declared here as @AppStorage
    // so changing the picker re-renders this view immediately (an @AppStorage
    // inside an ObservableObject doesn't publish changes).
    @AppStorage("aiEngine") private var aiEngineRaw = AIEngine.auto.rawValue
    @AppStorage("apiKey") private var apiKey = ""

    private var engine: AIEngine {
        AIEngine(rawValue: aiEngineRaw) ?? .auto
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                sectionLabel("Engine")

                Picker("", selection: $aiEngineRaw) {
                    ForEach(AIEngine.allCases, id: \.rawValue) { engine in
                        Text(engine.label).tag(engine.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)

                statusLine
            }

            // Only show the API key where it can actually be used:
            // never in on-device mode, as a labeled fallback in auto.
            if engine != .onDevice {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("OpenAI API Key")

                    SecureField("sk-...", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)

                    if engine == .auto {
                        caption("Only used when the on-device model isn't available.")
                    } else if apiKey.isEmpty {
                        caption("Required — answers go through the OpenAI API.")
                    }
                }
            }

            Divider()

            HStack(spacing: 6) {
                sectionLabel("Shortcut")
                Spacer()
                keycap("⌥") ; keycap("⌥") ; keycap("R")
            }
            caption("Hold both Option keys and press R. Needs Accessibility access (macOS asks on first launch).")
        }
        .padding(16)
        .frame(width: 320)
    }

    /// One line that answers "what will handle my next question, and why".
    @ViewBuilder
    private var statusLine: some View {
        let status = LocalAIService.status
        switch engine {
        case .auto:
            if status.isReady {
                statusText("✓ using the on-device model — no API key needed", color: .green)
            } else {
                statusText("using OpenAI (\(status.message))", color: .secondary)
            }
        case .onDevice:
            if status.isReady {
                statusText("✓ \(status.message) — nothing leaves this Mac", color: .green)
            } else {
                statusText("⚠ \(status.message)", color: .orange)
            }
        case .openAI:
            statusText("answers go through the OpenAI API", color: .secondary)
        }
    }

    private func statusText(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundColor(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.secondary)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func keycap(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.1))
            .cornerRadius(4)
    }
}
