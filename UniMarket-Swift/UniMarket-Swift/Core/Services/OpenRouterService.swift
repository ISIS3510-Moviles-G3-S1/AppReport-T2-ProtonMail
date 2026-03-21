import Foundation

final class OpenRouterService {
    static let shared = OpenRouterService()

    private init() {}

    func generateEcoRecommendation(prompt: String) async throws -> String {
        print("DEBUG[OpenRouter] generateEcoRecommendation called")

        guard APIConfig.isOpenRouterConfigured() else {
            print("DEBUG[OpenRouter] Missing API key configuration")
            throw OpenRouterError.missingAPIKey
        }

        guard let url = URL(string: APIConfig.openRouterBaseURL) else {
            print("DEBUG[OpenRouter] Invalid URL: \(APIConfig.openRouterBaseURL)")
            throw OpenRouterError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: APIConfig.requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(APIConfig.openRouterAPIKey)", forHTTPHeaderField: "Authorization")

        if !APIConfig.openRouterReferer.isEmpty {
            request.setValue(APIConfig.openRouterReferer, forHTTPHeaderField: "HTTP-Referer")
        }
        if !APIConfig.openRouterTitle.isEmpty {
            request.setValue(APIConfig.openRouterTitle, forHTTPHeaderField: "X-OpenRouter-Title")
        }

        let body = ORChatRequest(
            model: APIConfig.openRouterModel,
            messages: [
                ORChatMessage(role: "system", content: "You are Eco, a friendly and motivational sustainability companion inside UniMarket, a student marketplace app for clothing only. Your job is to celebrate the user's progress and give them one specific, encouraging nudge based on their stats. Tone: warm, upbeat, like a supportive friend — never preachy or generic. Always address the user by name. Reference their actual numbers (XP, transactions, listings sold) to make it feel personal. Max 240 characters total."),
                ORChatMessage(role: "user", content: prompt)
            ]
        )

        request.httpBody = try JSONEncoder().encode(body)
        print("DEBUG[OpenRouter] Sending request model=\(APIConfig.openRouterModel) promptChars=\(prompt.count)")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            print("DEBUG[OpenRouter] Invalid non-HTTP response")
            throw OpenRouterError.invalidResponse
        }

        print("DEBUG[OpenRouter] Response status=\(http.statusCode)")

        guard (200...299).contains(http.statusCode) else {
            let apiError = try? JSONDecoder().decode(ORErrorResponse.self, from: data)
            print("DEBUG[OpenRouter] Request failed message=\(apiError?.error.message ?? "<none>")")
            throw OpenRouterError.server(statusCode: http.statusCode, message: apiError?.error.message)
        }

        let decoded = try JSONDecoder().decode(ORChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("DEBUG[OpenRouter] Empty content in successful response")
            throw OpenRouterError.emptyContent
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        print("DEBUG[OpenRouter] Success contentChars=\(trimmed.count)")
        return trimmed
    }
}

private struct ORChatRequest: Encodable {
    let model: String
    let messages: [ORChatMessage]
}

private struct ORChatMessage: Codable {
    let role: String
    let content: String
}

private struct ORChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: ORChatMessage
    }
}

private struct ORErrorResponse: Decodable {
    struct APIError: Decodable {
        let message: String
    }
    let error: APIError
}

enum OpenRouterError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case emptyContent
    case server(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenRouter API key is missing."
        case .invalidURL:
            return "OpenRouter URL is invalid."
        case .invalidResponse:
            return "Invalid response from OpenRouter."
        case .emptyContent:
            return "OpenRouter returned an empty recommendation."
        case .server(let statusCode, let message):
            if let message, !message.isEmpty {
                return "OpenRouter error \(statusCode): \(message)"
            }
            return "OpenRouter error \(statusCode)."
        }
    }
}
