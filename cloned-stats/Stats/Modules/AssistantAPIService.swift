//
//  AssistantAPIService.swift
//  Stats
//
//  OpenAI Assistant API Service for Large PDF Processing
//  Handles 140+ page PDF documents for quiz context
//

import Foundation

/// OpenAI Assistant API Service
/// Manages PDF uploads and quiz analysis using OpenAI's Assistant API with file search
class AssistantAPIService {

    // MARK: - Singleton

    static let shared = AssistantAPIService()

    // MARK: - Configuration

    private let baseURL = "http://localhost:3000/api"
    private let session = URLSession.shared

    // MARK: - Initialization

    private init() {
        print("📚 AssistantAPIService initialized")
    }

    // MARK: - PDF Upload

    /// Upload PDF to OpenAI and create thread
    /// - Parameter pdfPath: Local file path to PDF
    /// - Returns: AssistantThread with thread ID and metadata
    func uploadPDF(_ pdfPath: String) async throws -> AssistantThread {
        print("\n📤 Uploading PDF to Assistant API...")
        print("   File: \(pdfPath)")

        // Verify file exists
        let fileURL = URL(fileURLWithPath: pdfPath)
        guard FileManager.default.fileExists(atPath: pdfPath) else {
            throw AssistantError.fileNotFound(pdfPath)
        }

        // Get file size
        let attributes = try FileManager.default.attributesOfItem(atPath: pdfPath)
        let fileSize = attributes[.size] as? UInt64 ?? 0
        let fileSizeMB = Double(fileSize) / 1024 / 1024
        print("   Size: \(String(format: "%.2f", fileSizeMB)) MB")

        // Read PDF as base64
        let pdfData = try Data(contentsOf: fileURL)
        let base64PDF = pdfData.base64EncodedString()

        print("   Encoded: \(base64PDF.count) characters")

        // Prepare request
        let url = URL(string: "\(baseURL)/upload-pdf")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180 // 3 minutes for large files

        let body: [String: Any] = [
            "pdfBase64": base64PDF,
            "filename": fileURL.lastPathComponent
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Send request
        print("   ⏳ Uploading...")
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AssistantError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("   ❌ Upload failed: \(errorMessage)")
            throw AssistantError.uploadFailed(httpResponse.statusCode, errorMessage)
        }

        // Parse response
        let thread = try JSONDecoder().decode(AssistantThread.self, from: data)

        // Cache thread ID and PDF path
        UserDefaults.standard.set(thread.threadId, forKey: "activeThreadId")
        UserDefaults.standard.set(pdfPath, forKey: "activePDFPath")
        UserDefaults.standard.set(Date(), forKey: "threadCreatedAt")

        print("   ✅ PDF uploaded successfully")
        print("   Thread ID: \(thread.threadId)")
        print("   Assistant ID: \(thread.assistantId)")
        print("   File ID: \(thread.fileId ?? "N/A")")
        print("   Vector Store ID: \(thread.vectorStoreId ?? "N/A")")

        return thread
    }

    // MARK: - Quiz Analysis

    /// Analyze quiz screenshot with PDF context
    /// - Parameter screenshotBase64: Base64-encoded quiz screenshot
    /// - Returns: QuizAnalysisResult with answers for all questions
    func analyzeQuiz(screenshot screenshotBase64: String) async throws -> QuizAnalysisResult {
        print("\n🔍 Analyzing quiz with PDF context...")

        // Get active thread ID
        guard let threadId = UserDefaults.standard.string(forKey: "activeThreadId") else {
            throw AssistantError.noActiveThread
        }

        print("   Thread ID: \(threadId)")
        print("   Screenshot size: \(screenshotBase64.count) characters")

        // Prepare request
        let url = URL(string: "\(baseURL)/analyze-quiz")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180 // 3 minutes (Assistant API can be slow)

        let body: [String: Any] = [
            "threadId": threadId,
            "screenshotBase64": screenshotBase64
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Send request
        print("   ⏳ Waiting for Assistant response...")
        let startTime = Date()
        let (data, response) = try await session.data(for: request)
        let elapsed = Date().timeIntervalSince(startTime)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AssistantError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("   ❌ Analysis failed: \(errorMessage)")
            throw AssistantError.analysisFailed(httpResponse.statusCode, errorMessage)
        }

        // Parse response
        let result = try JSONDecoder().decode(QuizAnalysisResult.self, from: data)

        print("   ✅ Quiz analyzed in \(String(format: "%.1f", elapsed))s")
        print("   Answers: \(result.answers.count)")

        // Log summary
        let mcCount = result.answers.filter { $0.type == "multiple-choice" }.count
        let writtenCount = result.answers.filter { $0.type == "written" }.count
        print("   Multiple-choice: \(mcCount), Written: \(writtenCount)")

        return result
    }

    // MARK: - Thread Management

    /// Get active thread information
    func getActiveThreadInfo() -> (threadId: String, pdfPath: String, createdAt: Date)? {
        guard let threadId = UserDefaults.standard.string(forKey: "activeThreadId"),
              let pdfPath = UserDefaults.standard.string(forKey: "activePDFPath"),
              let createdAt = UserDefaults.standard.object(forKey: "threadCreatedAt") as? Date else {
            return nil
        }

        return (threadId, pdfPath, createdAt)
    }

    /// Clear cached thread
    func clearActiveThread() {
        UserDefaults.standard.removeObject(forKey: "activeThreadId")
        UserDefaults.standard.removeObject(forKey: "activePDFPath")
        UserDefaults.standard.removeObject(forKey: "threadCreatedAt")
        print("🧹 Cleared active thread cache")
    }

    /// Delete thread from backend
    func deleteThread(_ threadId: String) async throws {
        print("🧹 Deleting thread: \(threadId)")

        let url = URL(string: "\(baseURL)/thread/\(threadId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AssistantError.deleteFailed(errorMessage)
        }

        print("   ✅ Thread deleted")

        // Clear cache if it's the active thread
        if let activeThreadId = UserDefaults.standard.string(forKey: "activeThreadId"),
           activeThreadId == threadId {
            clearActiveThread()
        }
    }
}

// MARK: - Data Models

/// Assistant thread response
struct AssistantThread: Codable {
    let threadId: String
    let assistantId: String
    let fileId: String?
    let vectorStoreId: String?
    let fileSizeMB: String?
    let createdAt: String
}

/// Quiz analysis result
struct QuizAnalysisResult: Codable {
    let answers: [QuizAnswer]
    let threadId: String?
    let timestamp: String
}

/// Individual quiz answer
struct QuizAnswer: Codable {
    let questionNumber: Int
    let type: String // "multiple-choice" or "written"
    let question: String
    let options: [String]? // Only for multiple-choice
    let correctAnswer: Int? // 1-4 for multiple-choice (1-based)
    let answerText: String? // For written questions
}

// MARK: - Error Types

enum AssistantError: Error, LocalizedError {
    case fileNotFound(String)
    case uploadFailed(Int, String)
    case noActiveThread
    case invalidResponse
    case analysisFailed(Int, String)
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "PDF file not found: \(path)"
        case .uploadFailed(let code, let message):
            return "Upload failed (HTTP \(code)): \(message)"
        case .noActiveThread:
            return "No active thread. Upload a PDF first."
        case .invalidResponse:
            return "Invalid response from server"
        case .analysisFailed(let code, let message):
            return "Analysis failed (HTTP \(code)): \(message)"
        case .deleteFailed(let message):
            return "Failed to delete thread: \(message)"
        }
    }
}

// MARK: - Usage Example

/*

 Usage Example:

 // 1. Upload PDF
 let thread = try await AssistantAPIService.shared.uploadPDF("/path/to/script.pdf")
 print("Thread ID: \(thread.threadId)")

 // 2. Capture quiz screenshot
 let screenshotBase64 = captureScreenshot() // Your screenshot capture function

 // 3. Analyze quiz
 let result = try await AssistantAPIService.shared.analyzeQuiz(screenshot: screenshotBase64)

 // 4. Process answers
 for answer in result.answers {
     if answer.type == "multiple-choice" {
         print("Q\(answer.questionNumber): Option \(answer.correctAnswer!)")
     } else {
         print("Q\(answer.questionNumber): \(answer.answerText!)")
     }
 }

 // 5. Cleanup (optional)
 try await AssistantAPIService.shared.deleteThread(thread.threadId)

 */
