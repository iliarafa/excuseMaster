import Foundation

// MARK: - Error Types

/// Errors that can occur during excuse generation.
enum ExcuseGeneratorError: LocalizedError {
    case invalidURL
    case invalidAPIKey
    case networkError(String)
    case httpError(statusCode: Int, body: String)
    case noContent
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL configuration."
        case .invalidAPIKey:
            return "Invalid or missing API key. Check your key in Settings."
        case .networkError(let detail):
            return "Network error: \(detail)"
        case .httpError(let statusCode, let body):
            // Provide user-friendly messages for common HTTP errors
            switch statusCode {
            case 401:
                return "Authentication failed. Your API key is invalid or expired."
            case 403:
                return "Access denied. Your API key may lack the required permissions."
            case 429:
                return "Rate limited. Please wait a moment and try again."
            case 500...599:
                return "Server error (\(statusCode)). The API is temporarily unavailable."
            default:
                return "HTTP \(statusCode): \(body)"
            }
        case .noContent:
            return "The API returned an empty response. Try again."
        case .parsingFailed:
            return "Failed to parse the response. The raw text has been preserved."
        }
    }
}

// MARK: - Service

/// Handles communication with the x.ai API to generate excuses.
class ExcuseGeneratorService {
    var apiKey: String
    var model: String
    var temperature: Double

    private let baseURL = "https://api.x.ai/v1"

    init(apiKey: String, model: String = "grok-3-mini", temperature: Double = 0.8) {
        self.apiKey = apiKey
        self.model = model
        self.temperature = temperature
    }

    // MARK: - Test Connection

    /// Sends a minimal request to verify the API key and connectivity.
    func testConnection() async throws -> Bool {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExcuseGeneratorError.invalidAPIKey
        }

        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw ExcuseGeneratorError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": "Say OK"]],
            "max_tokens": 5
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await performRequest(request)

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let responseBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ExcuseGeneratorError.httpError(statusCode: httpResponse.statusCode, body: responseBody)
        }

        return true
    }

    // MARK: - Generate Excuses

    /// Generates excuses based on the user's inputs.
    func generateExcuses(
        for situation: String,
        category: String,
        tone: String,
        details: String
    ) async throws -> [Excuse] {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExcuseGeneratorError.invalidAPIKey
        }

        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw ExcuseGeneratorError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = """
        You are an expert excuse architect. Build excuses using these mechanics:

        1. Plausibility Anchor — common, hard-to-disprove situations
        2. Specificity Balance — 1–2 vivid but flexible details only
        3. Future-Oriented Close — finish with a meaningful and plausible future commitment
        4. Emotional Layer — show genuine empathy, sincere regret, apology, and wish the other person well
        5. Risk Mitigation — avoid high-verification or dramatic lies (hospital, death, accidents, police, etc.)
        6. Relationship Tuning — match tone to the relationship (professional for work/boss, warm & casual for friends/partner/family)
        7. Brevity & Natural Flow — keep it very short, natural, conversational, text-friendly

        Situation: \(situation)
        Category: \(category)
        Tone requested: \(tone)
        Extra user details: \(details)

        Generate exactly 3 excuses.

        For each return:
        • the excuse text (ready to copy-paste)
        • very short "Why it works" (1–2 sentences)
        • strongest mechanics used (just list the numbers)

        Stay concise overall.
        """

        let body: [String: Any] = [
            "model": model,
            "temperature": temperature,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "Generate the 3 excuses now."]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await performRequest(request)

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let responseBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ExcuseGeneratorError.httpError(statusCode: httpResponse.statusCode, body: responseBody)
        }

        // Extract the content string from the OpenAI-style response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw ExcuseGeneratorError.noContent
        }

        return parseExcuses(from: content)
    }

    // MARK: - Networking

    /// Wraps URLSession.shared.data(for:) with user-friendly error handling.
    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet:
                throw ExcuseGeneratorError.networkError("No internet connection.")
            case .timedOut:
                throw ExcuseGeneratorError.networkError("Request timed out. Try again.")
            case .cannotFindHost, .cannotConnectToHost:
                throw ExcuseGeneratorError.networkError("Cannot reach the API server.")
            default:
                throw ExcuseGeneratorError.networkError(error.localizedDescription)
            }
        }
    }

    // MARK: - Parsing

    /// Parses the raw LLM response text into structured Excuse objects.
    /// Uses heuristics to find excuse boundaries and extract fields.
    /// Falls back to returning the raw text as a single excuse if parsing fails.
    private func parseExcuses(from content: String) -> [Excuse] {
        let excusePattern = /(?:Excuse\s*\d|^\s*\d\s*[\.\)\:])/
        let blocks = content.components(separatedBy: "\n\n")

        var excuses: [Excuse] = []
        var currentText = ""
        var currentReason = ""
        var currentMechanics: [Int] = []
        var inExcuse = false

        for block in blocks {
            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            // Detect the start of a new numbered excuse
            let isNewExcuse = trimmed.contains(excusePattern)
                || trimmed.hasPrefix("**Excuse")
                || trimmed.hasPrefix("**1") || trimmed.hasPrefix("**2") || trimmed.hasPrefix("**3")

            if isNewExcuse {
                // Save the previous excuse before starting a new one
                if inExcuse && !currentText.isEmpty {
                    excuses.append(Excuse(text: currentText, reason: currentReason, mechanics: currentMechanics))
                }
                inExcuse = true
                currentText = ""
                currentReason = ""
                currentMechanics = []
            }

            // Parse individual lines within the block
            for line in trimmed.components(separatedBy: "\n") {
                let l = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "**", with: "")

                if l.isEmpty { continue }

                let lower = l.lowercased()

                if lower.contains("why it works") || lower.hasPrefix("why:") || lower.hasPrefix("reason:") {
                    // Extract the "why it works" explanation
                    let parts = l.split(separator: ":", maxSplits: 1)
                    currentReason = parts.count > 1
                        ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                        : l
                } else if lower.contains("mechanic") || (lower.hasPrefix("strongest") && lower.contains("used")) {
                    // Extract mechanic numbers (digits 1-7)
                    currentMechanics = l.compactMap { c in
                        guard let n = Int(String(c)), (1...7).contains(n) else { return nil }
                        return n
                    }
                } else if lower.hasPrefix("excuse text") || lower.hasPrefix("• \"") || lower.hasPrefix("\"") {
                    // Line explicitly labeled as excuse text
                    let cleaned = l
                        .replacingOccurrences(of: "Excuse text:", with: "")
                        .replacingOccurrences(of: "• ", with: "")
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"").union(.whitespaces))
                    if !cleaned.isEmpty { currentText = cleaned }
                } else if currentText.isEmpty, let first = l.first, !first.isNumber {
                    // First non-header, non-numbered line is likely the excuse text
                    let cleaned = l
                        .replacingOccurrences(of: "• ", with: "")
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"").union(.whitespaces))
                    if !cleaned.isEmpty { currentText = cleaned }
                }
            }
        }

        // Capture the final excuse
        if inExcuse && !currentText.isEmpty {
            excuses.append(Excuse(text: currentText, reason: currentReason, mechanics: currentMechanics))
        }

        // Fallback: return raw content if parsing produced nothing
        if excuses.isEmpty {
            return [Excuse(text: content, reason: "Raw API response — parsing could not split into individual excuses.", mechanics: [])]
        }

        return excuses
    }
}
