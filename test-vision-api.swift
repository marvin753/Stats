import Foundation

// Simple test to verify VisionAI extracts all 20 questions from screenshot
// Run with: swift test-vision-api.swift

let screenshotPath = "/Users/marvinbarsal/Desktop/Universität/Stats/Screenshots/screenshot_001.png"

// Read the screenshot
guard let imageData = try? Data(contentsOf: URL(fileURLWithPath: screenshotPath)) else {
    print("❌ Failed to read screenshot at \(screenshotPath)")
    exit(1)
}

// Convert to base64
let base64String = imageData.base64EncodedString()
print("✅ Screenshot loaded: \(imageData.count) bytes")

// Load OpenAI API key from backend .env file
let envPath = "/Users/marvinbarsal/Desktop/Universität/Stats/backend/.env"
var apiKey = ""
if let envContents = try? String(contentsOfFile: envPath) {
    let lines = envContents.components(separatedBy: "\n")
    for line in lines {
        if line.hasPrefix("OPENAI_API_KEY=") {
            apiKey = String(line.dropFirst("OPENAI_API_KEY=".count))
            break
        }
    }
}

guard !apiKey.isEmpty else {
    print("❌ No OpenAI API key found in backend/.env")
    exit(1)
}
print("✅ API key loaded")

// Create the request payload (matching VisionAIService.swift)
let systemPrompt = """
Extract quiz questions from screenshots. Return ONLY a JSON array, no explanation.

Format: [{"questionNumber": N, "question": "text", "answers": ["A","B","C","D"]}, ...]

Rules:
1. Extract question number (1., 2), Frage 3, etc.)
2. Include ALL questions seen - EXPECT UP TO 20-25 QUESTIONS
3. For questions with visible answers: include all options
4. For questions without visible answers (essay questions): use empty array []
5. Preserve exact wording
6. Return COMPLETE JSON array - do not truncate

CRITICAL: This quiz has approximately 20 questions total (14 multiple-choice + 6 essay).
Return the FULL array of ALL questions. Do not stop early.
"""

let requestBody: [String: Any] = [
    "model": "gpt-4o",
    "messages": [
        ["role": "system", "content": systemPrompt],
        ["role": "user", "content": [
            ["type": "text", "text": "Extract all quiz questions from this screenshot. Return the complete JSON array of all questions."],
            ["type": "image_url", "image_url": ["url": "data:image/png;base64,\(base64String)"]]
        ]]
    ],
    "max_tokens": 8000,  // Increased from 4000
    "temperature": 0
]

// Send request to OpenAI
let url = URL(string: "https://api.openai.com/v1/chat/completions")!
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.httpBody = try! JSONSerialization.data(withJSONObject: requestBody)

print("📤 Sending request to OpenAI API...")
print("   Model: gpt-4o")
print("   Max tokens: 8000")
print("   System prompt expects: 20-25 questions")

let semaphore = DispatchSemaphore(value: 0)
var responseData: Data?
var responseError: Error?

let task = URLSession.shared.dataTask(with: request) { data, response, error in
    responseData = data
    responseError = error
    semaphore.signal()
}

task.resume()
semaphore.wait()

if let error = responseError {
    print("❌ Network error: \(error)")
    exit(1)
}

guard let data = responseData else {
    print("❌ No response data")
    exit(1)
}

// Parse OpenAI response
do {
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

    // Check for errors
    if let error = json["error"] as? [String: Any] {
        print("❌ OpenAI API error: \(error)")
        exit(1)
    }

    // Get usage info
    if let usage = json["usage"] as? [String: Any] {
        let promptTokens = usage["prompt_tokens"] as? Int ?? 0
        let completionTokens = usage["completion_tokens"] as? Int ?? 0
        let totalTokens = usage["total_tokens"] as? Int ?? 0
        print("📊 Token usage - Prompt: \(promptTokens), Completion: \(completionTokens), Total: \(totalTokens)")

        // Check if completion tokens suggest truncation
        if completionTokens < 1000 {
            print("⚠️  WARNING: Only \(completionTokens) completion tokens used - response may be truncated!")
        }
    }

    // Get the response content
    guard let choices = json["choices"] as? [[String: Any]],
          let firstChoice = choices.first,
          let message = firstChoice["message"] as? [String: Any],
          let content = message["content"] as? String else {
        print("❌ Failed to parse response structure")
        exit(1)
    }

    // Check finish reason
    if let finishReason = firstChoice["finish_reason"] as? String {
        print("🏁 Finish reason: \(finishReason)")
        if finishReason == "length" {
            print("⚠️  WARNING: Response was truncated due to max_tokens limit!")
        }
    }

    print("📄 Response length: \(content.count) characters")

    // Try to parse the questions JSON
    let cleanedContent = content
        .replacingOccurrences(of: "```json", with: "")
        .replacingOccurrences(of: "```", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    if let questionsData = cleanedContent.data(using: .utf8),
       let questions = try? JSONSerialization.jsonObject(with: questionsData) as? [[String: Any]] {

        print("\n✅ Successfully extracted \(questions.count) questions!")

        // Count question types
        var multipleChoice = 0
        var essay = 0

        for (index, question) in questions.enumerated() {
            let questionNumber = question["questionNumber"] as? Int ?? (index + 1)
            let questionText = question["question"] as? String ?? ""
            let answers = question["answers"] as? [String] ?? []

            if answers.isEmpty {
                essay += 1
                print("   Question \(questionNumber): [ESSAY] \(questionText.prefix(50))...")
            } else {
                multipleChoice += 1
                print("   Question \(questionNumber): [MC-\(answers.count)] \(questionText.prefix(50))...")
            }
        }

        print("\n📊 Summary:")
        print("   Total questions: \(questions.count)")
        print("   Multiple choice: \(multipleChoice)")
        print("   Essay questions: \(essay)")

        if questions.count == 20 {
            print("\n🎉 SUCCESS: All 20 questions were extracted correctly!")
        } else if questions.count < 20 {
            print("\n⚠️  WARNING: Only \(questions.count) questions extracted (expected 20)")
            print("   This suggests the response was truncated or questions were missed")
        }

    } else {
        print("❌ Failed to parse questions JSON")
        print("Response preview: \(cleanedContent.prefix(500))")
    }

} catch {
    print("❌ Error parsing response: \(error)")
    if let dataString = String(data: data, encoding: .utf8) {
        print("Raw response: \(dataString.prefix(1000))")
    }
}