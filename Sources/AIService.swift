import Foundation

/// OpenAI chat-completions client (streaming). Used when the on-device
/// model isn't available (older macOS, ineligible hardware) or when the
/// user picks the openai engine explicitly.
struct AIService {
    let apiKey: String

    enum AIError: Error, LocalizedError {
        case missingAPIKey
        case invalidURL
        case noResponse
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "Add your OpenAI API key in Settings, or switch to the on-device engine."
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
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw AIError.invalidURL
        }

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messages,
            "temperature": 0.7,
            "stream": true
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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

        // Server-sent events: "data: {json}" lines, closed by "data: [DONE]".
        var fullReply = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            if payload == "[DONE]" { break }
            if let delta = Self.deltaContent(in: payload) {
                fullReply += delta
                continuation.yield(fullReply)
            }
        }
    }

    /// Pulls `choices[0].delta.content` out of one SSE chunk.
    private static func deltaContent(in payload: String) -> String? {
        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any] else {
            return nil
        }
        return delta["content"] as? String
    }
}
