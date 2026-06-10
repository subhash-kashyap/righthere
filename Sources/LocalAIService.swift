import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Availability of Apple's on-device model (Apple Intelligence).
/// Requires macOS 26+, Apple Silicon, and Apple Intelligence enabled in
/// System Settings. Conversation state lives in `Conversation`; this only
/// answers "can the on-device engine take a question right now, and if
/// not, why not" — safe to call on any macOS version.
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
}
