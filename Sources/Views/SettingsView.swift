import SwiftUI

struct SettingsView: View {
    // Reads the same defaults keys as AppState. Declared here as @AppStorage
    // so changing the picker re-renders this view immediately (an @AppStorage
    // inside an ObservableObject doesn't publish changes).
    @AppStorage("aiEngine") private var aiEngineRaw = AIEngine.auto.rawValue
    @AppStorage("apiProvider") private var apiProviderRaw = APIProvider.openai.rawValue
    @AppStorage("apiModel") private var apiModel = ""
    @AppStorage("apiKey") private var apiKey = ""

    @StateObject private var updateChecker = UpdateChecker()

    private var engine: AIEngine {
        AIEngine(rawValue: aiEngineRaw) ?? .auto
    }

    private var provider: APIProvider {
        APIProvider(rawValue: apiProviderRaw) ?? .openai
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                sectionLabel("AI Model")

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

            // Only show API configuration where it can actually be used:
            // never in on-device mode, as a labeled fallback in auto.
            if engine != .onDevice {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("Own AI API")

                    Picker("", selection: $apiProviderRaw) {
                        ForEach(APIProvider.allCases, id: \.rawValue) { provider in
                            Text(provider.label).tag(provider.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.small)

                    SecureField("api key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)

                    TextField("model (default: \(provider.defaultModel))", text: $apiModel)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)

                    if engine == .auto {
                        caption("Only used when the on-device model isn't available.")
                    } else if apiKey.isEmpty {
                        caption("Required — answers go through \(provider.label).")
                    }
                }
            }

            Divider()

            HStack(spacing: 6) {
                sectionLabel("Shortcut")
                Spacer()
                keycap("⌥ left") ; keycap("⌥ right") ; keycap("R")
            }
            caption("Hold Option (left) and Option (right) together, then press R.")

            Divider()

            updatesSection
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
                statusText("using \(provider.label) (\(status.message))", color: .secondary)
            }
        case .onDevice:
            if status.isReady {
                statusText("✓ \(status.message) — nothing leaves this Mac", color: .green)
            } else {
                statusText("⚠ \(status.message)", color: .orange)
            }
        case .openAI:
            statusText("answers go through \(provider.label) with your key", color: .secondary)
        }
    }

    @ViewBuilder
    private var updatesSection: some View {
        HStack(spacing: 8) {
            sectionLabel("Updates")
            caption("v\(UpdateChecker.currentVersion)")
            Spacer()
            switch updateChecker.state {
            case .idle:
                Button("check for updates") { updateChecker.check() }
                    .controlSize(.small)
            case .checking:
                ProgressView()
                    .controlSize(.small)
            case .upToDate:
                caption("✓ up to date")
            case .updateAvailable(let version, _):
                Button("get v\(version)") { updateChecker.openRelease() }
                    .controlSize(.small)
            case .failed:
                caption("couldn't check")
                Button("retry") { updateChecker.check() }
                    .controlSize(.small)
            }
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
