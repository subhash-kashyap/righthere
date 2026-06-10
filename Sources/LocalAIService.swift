import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device answers via Apple Foundation Models (Apple Intelligence).
/// No API key, no network. Requires macOS 26+, Apple Silicon, and
/// Apple Intelligence enabled in System Settings.
///
/// Built with `canImport` + `#available` guards so the app still compiles
/// and runs on older macOS (falls back to OpenAI there).
struct LocalAIService {

    enum Status {
        case ready
        case unavailable(String)

        var message: String {
            switch self {
            case .ready: return "on-device model ready"
            case .unavailable(let reason): return reason
            }
        }

        var isReady: Bool {
            if case .ready = self { return true }
            return false
        }
    }

    /// Safe to call on any macOS version.
    static var status: Status {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .ready
            case .unavailable(.deviceNotEligible):
                return .unavailable("this Mac isn't eligible for Apple Intelligence")
            case .unavailable(.appleIntelligenceNotEnabled):
                return .unavailable("turn on Apple Intelligence in System Settings")
            case .unavailable(.modelNotReady):
                return .unavailable("model is downloading — try again in a bit")
            case .unavailable(_):
                return .unavailable("on-device model unavailable")
            }
        } else {
            return .unavailable("needs macOS 26+ (you're on \(ProcessInfo.processInfo.operatingSystemVersionString))")
        }
        #else
        return .unavailable("app was built without the FoundationModels SDK")
        #endif
    }

    func ask(prompt: String, context: String = "") async throws -> String {
        #if canImport(FoundationModels)
        guard #available(macOS 26.0, *), Self.status.isReady else {
            throw AIService.AIError.requestFailed(Self.status.message)
        }

        // The on-device model has a ~4096 token context window — keep the
        // pasted context from blowing past it.
        let trimmedContext = String(context.prefix(8_000))
        let userMessage = trimmedContext.isEmpty
            ? prompt
            : "Context: \(trimmedContext)\n\nQuestion: \(prompt)"

        let session = LanguageModelSession(
            instructions: "You are a helpful assistant. Provide concise answers."
        )
        let response = try await session.respond(to: userMessage)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        #else
        throw AIService.AIError.requestFailed("app was built without the FoundationModels SDK")
        #endif
    }
}
