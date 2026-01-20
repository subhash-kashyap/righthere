import Foundation

struct AIService {
    let apiKey: String
    
    enum AIError: Error {
        case invalidURL
        case noResponse
        case requestFailed(String)
    }
    
    func ask(prompt: String, context: String = "") async throws -> String {
        print("[DEBUG] AIService.ask called (OpenAI)")
        guard !apiKey.isEmpty else {
            print("[DEBUG] API Key is empty")
            return "Please set your OpenAI API key in the menu bar settings."
        }
        
        let urlString = "https://api.openai.com/v1/chat/completions"
        guard let url = URL(string: urlString) else {
            print("[DEBUG] Invalid URL: \(urlString)")
            throw AIError.invalidURL
        }
        
        let systemPrompt = "You are a helpful assistant. Provide concise answers."
        let userMessage = context.isEmpty ? prompt : "Context: \(context)\n\nQuestion: \(prompt)"
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage]
            ],
            "temperature": 0.7
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("[DEBUG] Fetching AI response from OpenAI...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.noResponse
        }
        
        if httpResponse.statusCode != 200 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[DEBUG] AI Request failed with status: \(httpResponse.statusCode), body: \(errorMsg)")
            throw AIError.requestFailed("HTTP \(httpResponse.statusCode): \(errorMsg)")
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            print("[DEBUG] Successfully parsed OpenAI response")
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        print("[DEBUG] AI response had no expected content")
        throw AIError.noResponse
    }
}
