import Foundation

/// OpenAI chat-completions client. Used when the on-device model isn't
/// available (older macOS, ineligible hardware) or when the user picks
/// the openai engine explicitly.
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

    func ask(prompt: String, context: String = "") async throws -> String {
        guard !apiKey.isEmpty else {
            throw AIError.missingAPIKey
        }

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw AIError.invalidURL
        }

        let userMessage = context.isEmpty ? prompt : "Context: \(context)\n\nQuestion: \(prompt)"
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "You are a helpful assistant. Provide concise answers."],
                ["role": "user", "content": userMessage]
            ],
            "temperature": 0.7
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.noResponse
        }
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "unknown error"
            throw AIError.requestFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.noResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
