import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// State for one ask-box conversation: created on the first question, kept
/// alive for follow-ups, discarded when the box is summoned fresh.
///
/// The engine is resolved once at creation and pinned — each engine keeps
/// its own transcript (a LanguageModelSession on-device, a messages array
/// for OpenAI), so hopping between them mid-thread would lose context.
@MainActor
final class Conversation {

    static let systemPrompt = "You are a helpful assistant. Provide concise answers."

    let engine: AIEngine
    private let api: AIService

    /// Own-API transcript; grows by one user + one assistant entry per turn.
    private var messages: [[String: String]] = [
        ["role": "system", "content": Conversation.systemPrompt]
    ]

    /// The on-device session, which holds the transcript internally.
    /// Stored untyped so the property compiles on macOS < 26; only
    /// touched inside #available blocks.
    private var localSession: Any?

    init(engine: AIEngine, api: AIService) {
        self.engine = engine
        self.api = api
    }

    /// Streams the answer as cumulative snapshots of the full reply text
    /// (each yielded value replaces the previous one).
    func streamAnswer(to prompt: String, context: String) -> AsyncThrowingStream<String, Error> {
        // The on-device model has a ~4096 token context window — keep
        // pasted context from blowing past it.
        let message = context.isEmpty
            ? prompt
            : "Context: \(String(context.prefix(8_000)))\n\nQuestion: \(prompt)"

        switch engine {
        case .onDevice:
            return streamLocal(message)
        case .openAI, .auto:
            return streamRemote(message)
        }
    }

    // MARK: - Apple Foundation Models

    private func streamLocal(_ message: String) -> AsyncThrowingStream<String, Error> {
        #if canImport(FoundationModels)
        guard #available(macOS 26.0, *), LocalAIService.status.isReady else {
            return Self.failing(AIService.AIError.requestFailed(LocalAIService.status.message))
        }

        let session = (localSession as? LanguageModelSession)
            ?? LanguageModelSession(instructions: Self.systemPrompt)
        localSession = session

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await partial in session.streamResponse(to: message) {
                        continuation.yield(partial.content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        #else
        return Self.failing(AIService.AIError.requestFailed("app was built without the FoundationModels SDK"))
        #endif
    }

    // MARK: - Own API (OpenAI / Anthropic / OpenRouter)

    private func streamRemote(_ message: String) -> AsyncThrowingStream<String, Error> {
        messages.append(["role": "user", "content": message])
        let service = api
        let transcript = messages

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var fullReply = ""
                    for try await snapshot in service.stream(messages: transcript) {
                        fullReply = snapshot
                        continuation.yield(snapshot)
                    }
                    self.messages.append(["role": "assistant", "content": fullReply])
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func failing(_ error: Error) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish(throwing: error) }
    }
}
