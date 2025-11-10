//
//  VisionAIService.swift
//  Stats Quiz Extractor
//
//  Created on 2025-11-10
//  Purpose: Extract quiz questions from screenshots using AI vision models
//

import Foundation

// MARK: - Models

struct QuizQuestion: Codable {
    let question: String
    let answers: [String]
}

// MARK: - Errors

enum VisionAIError: LocalizedError {
    case apiKeyNotFound
    case invalidAPIKey
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case rateLimitExceeded
    case serverError(Int, String)
    case noScreenshots
    case malformedJSON(String)

    var errorDescription: String? {
        switch self {
        case .apiKeyNotFound:
            return "OpenAI API key not found. Please set OPENAI_API_KEY environment variable or add it to backend/.env file."
        case .invalidAPIKey:
            return "Invalid OpenAI API key. Please check your credentials."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Received invalid response from OpenAI API."
        case .decodingError(let error):
            return "Failed to decode API response: \(error.localizedDescription)"
        case .rateLimitExceeded:
            return "OpenAI API rate limit exceeded. Please try again later."
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .noScreenshots:
            return "No screenshots provided for processing."
        case .malformedJSON(let content):
            return "Malformed JSON response: \(content)"
        }
    }
}

// MARK: - OpenAI Response Models

struct OpenAIResponse: Codable {
    let choices: [Choice]
    let usage: Usage?

    struct Choice: Codable {
        let message: Message
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }

    struct Message: Codable {
        let role: String
        let content: String
    }

    struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

struct OpenAIErrorResponse: Codable {
    let error: ErrorDetail

    struct ErrorDetail: Codable {
        let message: String
        let type: String
        let code: String?
    }
}

// MARK: - Vision AI Service

class VisionAIService {

    // MARK: - Properties

    private let openAIEndpoint = "https://api.openai.com/v1/chat/completions"
    private let model = "gpt-4o"
    private let maxRetries = 1
    private var apiKey: String?

    // MARK: - Initialization

    init() {
        loadAPIKey()
    }

    // MARK: - API Key Management

    private func loadAPIKey() {
        // Priority 1: Environment variable
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !envKey.isEmpty {
            apiKey = envKey
            print("✓ Loaded OpenAI API key from environment variable")
            return
        }

        // Priority 2: Backend .env file
        let envPath = "/Users/marvinbarsal/Desktop/Universität/Stats/backend/.env"
        if let key = readAPIKeyFromFile(path: envPath) {
            apiKey = key
            print("✓ Loaded OpenAI API key from \(envPath)")
            return
        }

        print("⚠️ OpenAI API key not found in environment or .env file")
    }

    private func readAPIKeyFromFile(path: String) -> String? {
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }

        // Parse .env file for OPENAI_API_KEY=xxx
        let lines = contents.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("OPENAI_API_KEY=") {
                let key = trimmed.replacingOccurrences(of: "OPENAI_API_KEY=", with: "")
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                return key.isEmpty ? nil : key
            }
        }

        return nil
    }

    func isOpenAIConfigured() -> Bool {
        return apiKey != nil && !apiKey!.isEmpty
    }

    // MARK: - Main Extraction Method

    /// Extract quiz questions from screenshots using OpenAI Vision API
    /// - Parameter screenshots: Array of base64-encoded PNG images
    /// - Returns: Array of dictionaries with question and answers
    func extractQuizQuestions(from screenshots: [String]) async throws -> [[String: Any]] {
        guard !screenshots.isEmpty else {
            throw VisionAIError.noScreenshots
        }

        guard isOpenAIConfigured() else {
            throw VisionAIError.apiKeyNotFound
        }

        print("📸 Processing \(screenshots.count) screenshot(s) with OpenAI GPT-4o Vision...")

        // Define batch size (2-3 screenshots per batch to avoid timeout)
        let batchSize = 3
        var allQuestions: [[String: Any]] = []

        // Split into batches
        let batches = stride(from: 0, to: screenshots.count, by: batchSize).map {
            Array(screenshots[$0..<min($0 + batchSize, screenshots.count)])
        }

        print("📦 Split into \(batches.count) batch(es) of up to \(batchSize) screenshots")

        // Process each batch sequentially
        for (index, batch) in batches.enumerated() {
            print("🔄 Processing batch \(index + 1)/\(batches.count) (\(batch.count) screenshots)...")

            do {
                let batchQuestions = try await processBatch(batch, batchNumber: index + 1)
                allQuestions.append(contentsOf: batchQuestions)
                print("✅ Batch \(index + 1) completed: \(batchQuestions.count) questions extracted")
            } catch {
                print("❌ Batch \(index + 1) failed: \(error.localizedDescription)")
                throw error
            }
        }

        print("🎉 All batches processed successfully! Total: \(allQuestions.count) questions")
        return allQuestions
    }

    // MARK: - Batch Processing

    private func processBatch(_ screenshots: [String], batchNumber: Int) async throws -> [[String: Any]] {
        var lastError: Error?

        // Try with retry logic (2 attempts per batch)
        for attempt in 1...2 {
            do {
                let questions = try await performOpenAIRequest(screenshots: screenshots, batchNumber: batchNumber)
                return questions
            } catch {
                lastError = error
                if attempt < 2 {
                    print("⚠️ Batch \(batchNumber) attempt \(attempt) failed, retrying...")
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
                } else {
                    print("✗ Batch \(batchNumber) failed after all attempts")
                }
            }
        }

        throw lastError ?? VisionAIError.invalidResponse
    }

    // MARK: - OpenAI API Request

    private func performOpenAIRequest(screenshots: [String], batchNumber: Int? = nil) async throws -> [[String: Any]] {
        guard let url = URL(string: openAIEndpoint) else {
            throw VisionAIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey!)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60.0 // 60 seconds per batch

        let requestBody = buildRequestBody(screenshots: screenshots)
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // Log request size with batch info
        let requestSize = (request.httpBody?.count ?? 0) / 1024
        if let batch = batchNumber {
            print("📤 Sending batch \(batch) request (\(requestSize) KB) to OpenAI API...")
        } else {
            print("📤 Sending request (\(requestSize) KB) to OpenAI API...")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VisionAIError.invalidResponse
        }

        // Log response
        print("📥 Received response: HTTP \(httpResponse.statusCode)")

        // Handle HTTP errors
        try handleHTTPErrors(statusCode: httpResponse.statusCode, data: data)

        // Parse OpenAI response
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)

        // Log token usage
        if let usage = openAIResponse.usage {
            print("📊 Token usage - Prompt: \(usage.promptTokens), Completion: \(usage.completionTokens), Total: \(usage.totalTokens)")
        }

        guard let firstChoice = openAIResponse.choices.first else {
            throw VisionAIError.invalidResponse
        }

        let content = firstChoice.message.content
        print("📝 Raw response content length: \(content.count) characters")

        // Parse JSON from content
        return try parseQuizQuestions(from: content)
    }

    // MARK: - Request Building

    private func buildRequestBody(screenshots: [String]) -> [String: Any] {
        var contentArray: [[String: Any]] = []

        // Add system instruction
        let systemPrompt = """
        You are a quiz extraction expert. Extract all quiz questions and their answer options from the provided screenshots.

        IMPORTANT RULES:
        1. Some questions may span multiple screenshots - combine them into single questions
        2. Each question should have exactly 4 answer options (A, B, C, D) when possible
        3. Return a valid JSON array with this exact structure:
        [
          {
            "question": "Complete question text here",
            "answers": ["Option A text", "Option B text", "Option C text", "Option D text"]
          }
        ]
        4. Do not include any explanation or markdown - ONLY return the JSON array
        5. Preserve exact question wording and answer options as shown in images
        6. If you see partial questions, wait for complete context before extracting
        """

        // Add user message with text instruction
        contentArray.append([
            "type": "text",
            "text": "Extract all quiz questions and answer options from these screenshots. Return only a JSON array of questions with their answers."
        ])

        // Add all screenshots as image_url content
        for (index, screenshot) in screenshots.enumerated() {
            let dataURL = "data:image/png;base64,\(screenshot)"
            contentArray.append([
                "type": "image_url",
                "image_url": [
                    "url": dataURL,
                    "detail": "high" // Request high-detail analysis
                ]
            ])
            print("  └─ Added screenshot \(index + 1)/\(screenshots.count)")
        }

        return [
            "model": model,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": contentArray
                ]
            ],
            "max_tokens": 2000,
            "temperature": 0.1 // Low temperature for consistent, factual extraction
        ]
    }

    // MARK: - Response Parsing

    private func parseQuizQuestions(from content: String) throws -> [[String: Any]] {
        // Clean content - remove markdown code blocks if present
        var cleanedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown JSON code blocks
        if cleanedContent.hasPrefix("```json") {
            cleanedContent = cleanedContent.replacingOccurrences(of: "```json", with: "")
        }
        if cleanedContent.hasPrefix("```") {
            cleanedContent = cleanedContent.replacingOccurrences(of: "```", with: "")
        }
        if cleanedContent.hasSuffix("```") {
            cleanedContent = String(cleanedContent.dropLast(3))
        }

        cleanedContent = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleanedContent.data(using: .utf8) else {
            throw VisionAIError.malformedJSON("Could not convert content to data")
        }

        // Parse as JSON array
        guard let jsonArray = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            throw VisionAIError.malformedJSON("Expected array of objects, got: \(cleanedContent.prefix(100))")
        }

        // Validate structure
        for (index, item) in jsonArray.enumerated() {
            guard let question = item["question"] as? String,
                  let answers = item["answers"] as? [String],
                  !question.isEmpty,
                  !answers.isEmpty else {
                print("⚠️ Invalid question structure at index \(index): \(item)")
                throw VisionAIError.malformedJSON("Invalid question structure at index \(index)")
            }

            print("  ✓ Question \(index + 1): \"\(question.prefix(60))...\" (\(answers.count) answers)")
        }

        return jsonArray
    }

    // MARK: - Error Handling

    private func handleHTTPErrors(statusCode: Int, data: Data) throws {
        switch statusCode {
        case 200...299:
            return // Success

        case 401:
            throw VisionAIError.invalidAPIKey

        case 429:
            throw VisionAIError.rateLimitExceeded

        case 400...499, 500...599:
            // Try to parse error message
            if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                throw VisionAIError.serverError(statusCode, errorResponse.error.message)
            } else if let errorString = String(data: data, encoding: .utf8) {
                throw VisionAIError.serverError(statusCode, errorString)
            } else {
                throw VisionAIError.serverError(statusCode, "Unknown error")
            }

        default:
            throw VisionAIError.serverError(statusCode, "Unexpected status code")
        }
    }

    // MARK: - Future: Ollama LLaVA Integration

    /*
    /// Extract quiz questions using local Ollama LLaVA model (future implementation)
    /// - Parameter screenshots: Array of base64-encoded images
    /// - Returns: Array of dictionaries with question and answers
    func extractWithOllama(from screenshots: [String]) async throws -> [[String: Any]] {
        // TODO: Implement Ollama LLaVA integration
        // Endpoint: http://localhost:11434/api/generate
        // Model: llava:13b or llava:7b
        //
        // Benefits:
        // - Free, runs locally
        // - No API key needed
        // - Privacy-focused
        // - No rate limits
        //
        // Implementation steps:
        // 1. Check if Ollama is running (curl http://localhost:11434/api/tags)
        // 2. Ensure LLaVA model is installed (ollama pull llava:13b)
        // 3. Send POST request with images and prompt
        // 4. Parse streaming JSON responses
        // 5. Extract and validate quiz questions

        throw VisionAIError.invalidResponse // Placeholder
    }

    func isOllamaAvailable() async -> Bool {
        // TODO: Check if Ollama service is running
        return false
    }
    */
}
