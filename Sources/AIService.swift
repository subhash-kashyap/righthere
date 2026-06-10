import Foundation

/// Which hosted API answers when the on-device model doesn't.
/// OpenAI and OpenRouter share the chat-completions wire format;
/// Anthropic has its own messages API and SSE shape.
enum APIProvider: String, CaseIterable {
    case openai
    case anthropic
    case openrouter

    var label: String { rawValue }

    var defaultModel: String {
        switch self {
        case .openai: return "gpt-4o-mini"
        case .anthropic: return "claude-haiku-4-5"
        case .openrouter: return "openai/gpt-4o-mini"
        }
    }

    var endpoint: URL? {
        switch self {
        case .openai: return URL(string: "https://api.openai.com/v1/chat/completions")
        case .openrouter: return URL(string: "https://openrouter.ai/api/v1/chat/completions")
        case .anthropic: return URL(string: "https://api.anthropic.com/v1/messages")
        }
    }
}

/// Streaming client for the user's own API key. Used when the on-device
/// model isn't available (older macOS, ineligible hardware) or when the
/// user picks the own-API engine explicitly.
struct AIService {
    let provider: APIProvider
    let apiKey: String
    let model: String

    init(provider: APIProvider, apiKey: String, model: String = "") {
        self.provider = provider
        self.apiKey = apiKey
        self.model = model.isEmpty ? provider.defaultModel : model
    }

    enum AIError: Error, LocalizedError {
        case missingAPIKey
        case invalidURL
        case noResponse
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "Add your API key in Settings, or switch to the on-device model."
            case .invalidURL: return "Invalid API URL."
            case .noResponse: return "The API returned an unexpected response."
            case .requestFailed(let reason): return reason
            }
        }
    }

    /// Streams the assistant reply as cumulative snapshots of the full
    /// text (each yielded value replaces the previous one).
    func stream(messages: [[String: String]]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await streamInto(continuation, messages: messages)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func streamInto(
        _ continuation: AsyncThrowingStream<String, Error>.Continuation,
        messages: [[String: String]]
    ) async throws {
        guard !apiKey.isEmpty else { throw AIError.missingAPIKey }
        guard let url = provider.endpoint else { throw AIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any]
        switch provider {
        case .openai, .openrouter:
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            body = [
                "model": model,
                "messages": messages,
                "temperature": 0.7,
                "stream": true
            ]
        case .anthropic:
            request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            // Anthropic takes the system prompt top-level, not as a message.
            let system = messages.first { $0["role"] == "system" }?["content"] ?? ""
            let turns = messages.filter { $0["role"] != "system" }
            body = [
                "model": model,
                "max_tokens": 1024,
                "system": system,
                "messages": turns,
                "stream": true
            ]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.noResponse
        }
        guard httpResponse.statusCode == 200 else {
            var errorData = Data()
            for try await byte in bytes { errorData.append(byte) }
            let errorBody = String(data: errorData, encoding: .utf8) ?? "unknown error"
            throw AIError.requestFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        // Server-sent events: "data: {json}" lines. OpenAI-style streams
        // close with "data: [DONE]"; Anthropic's just ends.
        var fullReply = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            if payload == "[DONE]" { break }
            if let delta = Self.deltaContent(in: payload, provider: provider) {
                fullReply += delta
                continuation.yield(fullReply)
            }
        }
    }

    /// Pulls the text delta out of one SSE chunk, per provider format.
    private static func deltaContent(in payload: String, provider: APIProvider) -> String? {
        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        switch provider {
        case .openai, .openrouter:
            guard let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any] else { return nil }
            return delta["content"] as? String
        case .anthropic:
            guard json["type"] as? String == "content_block_delta",
                  let delta = json["delta"] as? [String: Any] else { return nil }
            return delta["text"] as? String
        }
    }
}
