import Foundation

/// Errors for solution API operations
enum SolutionAPIError: Error, LocalizedError {
    case backendOffline
    case backendUnhealthy
    case noReferenceFile
    case uploadFailed(String)
    case solutionFailed(String)
    case invalidResponse
    case fileAccessDenied
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .backendOffline:
            return "Backend server is not reachable. Start the server with: cd backend && npm start"
        case .backendUnhealthy:
            return "Backend server is running but not healthy. Check OpenAI API key configuration."
        case .noReferenceFile:
            return "No reference PDF uploaded. Please upload a reference document first."
        case .uploadFailed(let message):
            return "Failed to upload PDF: \(message)"
        case .solutionFailed(let message):
            return "Failed to generate solution: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .fileAccessDenied:
            return "Cannot access the PDF file. Please re-select it."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

/// Response models
struct HealthResponse: Codable {
    let status: String
    let openaiConfigured: Bool?

    enum CodingKeys: String, CodingKey {
        case status
        case openaiConfigured = "openai_configured"
    }
}

struct UploadResponse: Codable {
    let fileId: String
    let filename: String?
    let status: String
}

struct ReferenceStatusResponse: Codable {
    let hasReference: Bool
    let filename: String?
    let fileId: String?
    let uploadedAt: String?
}

struct SolveResponse: Codable {
    let solution: String
    let status: String
}

/// API service for backend communication
/// Implements Safeguard 11: Backend Offline Fallback
class SolutionAPIService {

    // MARK: - Singleton
    static let shared = SolutionAPIService()

    // MARK: - Configuration
    private let baseURL = "http://localhost:3000/api"
    private let healthTimeout: TimeInterval = 3.0  // Fast timeout for health check
    private let uploadTimeout: TimeInterval = 120.0  // 2 minutes for large PDF upload
    private let solveTimeout: TimeInterval = 60.0   // 1 minute for solution generation

    // MARK: - State
    private var cachedHealthy: Bool = false
    private var lastHealthCheck: Date?
    private let healthCacheDuration: TimeInterval = 30.0  // Cache health for 30 seconds

    private init() {
        print("[SolutionAPIService] Initialized with baseURL: \(baseURL)")
    }

    // MARK: - Safeguard 11: Health Check

    /// Check if backend is healthy and reachable
    /// Uses fast 3-second timeout for quick failure detection
    func checkHealth() async throws -> Bool {
        // Check cache first
        if let lastCheck = lastHealthCheck,
           Date().timeIntervalSince(lastCheck) < healthCacheDuration,
           cachedHealthy {
            return true
        }

        print("[SolutionAPIService] Checking backend health...")

        guard let url = URL(string: "\(baseURL.replacingOccurrences(of: "/api", with: ""))/health") else {
            throw SolutionAPIError.backendOffline
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = healthTimeout
        request.httpMethod = "GET"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                cachedHealthy = false
                throw SolutionAPIError.backendOffline
            }

            guard httpResponse.statusCode == 200 else {
                cachedHealthy = false
                throw SolutionAPIError.backendUnhealthy
            }

            let health = try JSONDecoder().decode(HealthResponse.self, from: data)

            guard health.status == "ok" else {
                cachedHealthy = false
                throw SolutionAPIError.backendUnhealthy
            }

            // Check if OpenAI is configured
            if health.openaiConfigured == false {
                print("⚠️ [SolutionAPIService] OpenAI not configured in backend")
            }

            cachedHealthy = true
            lastHealthCheck = Date()
            print("✅ [SolutionAPIService] Backend is healthy")
            return true

        } catch let error as SolutionAPIError {
            throw error
        } catch {
            cachedHealthy = false
            throw SolutionAPIError.backendOffline
        }
    }

    // MARK: - Reference Status

    /// Get current reference file status from backend
    func getReferenceStatus() async throws -> ReferenceStatusResponse {
        // First check health
        _ = try await checkHealth()

        guard let url = URL(string: "\(baseURL)/reference-status") else {
            throw SolutionAPIError.invalidResponse
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(ReferenceStatusResponse.self, from: data)
    }

    /// Check if backend has a reference file
    var hasReferenceFile: Bool {
        get async {
            do {
                let status = try await getReferenceStatus()
                return status.hasReference
            } catch {
                return false
            }
        }
    }

    // MARK: - PDF Upload (Safeguard 10: Multipart)

    /// Upload reference PDF to backend using multipart/form-data
    func uploadReferencePDF(data: Data, filename: String) async throws -> String {
        // First check health
        _ = try await checkHealth()

        print("[SolutionAPIService] Uploading PDF: \(filename) (\(data.count / 1024) KB)")

        guard let url = URL(string: "\(baseURL)/upload-reference") else {
            throw SolutionAPIError.invalidResponse
        }

        // Create multipart request
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = uploadTimeout
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Build multipart body
        var body = Data()

        // Add file part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"pdf\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw SolutionAPIError.uploadFailed("Invalid response")
            }

            guard httpResponse.statusCode == 200 else {
                if let errorJson = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                   let errorMessage = errorJson["error"] as? String {
                    throw SolutionAPIError.uploadFailed(errorMessage)
                }
                throw SolutionAPIError.uploadFailed("HTTP \(httpResponse.statusCode)")
            }

            let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: responseData)

            guard uploadResponse.status == "success" else {
                throw SolutionAPIError.uploadFailed("Upload failed")
            }

            print("✅ [SolutionAPIService] PDF uploaded: \(uploadResponse.fileId)")

            // Store fileId in ReferenceFileManager
            ReferenceFileManager.shared.uploadedFileId = uploadResponse.fileId

            return uploadResponse.fileId

        } catch let error as SolutionAPIError {
            throw error
        } catch {
            throw SolutionAPIError.networkError(error)
        }
    }

    /// Upload PDF from ReferenceFileManager
    func uploadCurrentReferencePDF() async throws -> String {
        guard let fileData = ReferenceFileManager.shared.getFileDataForUpload() else {
            throw SolutionAPIError.fileAccessDenied
        }

        return try await uploadReferencePDF(data: fileData.data, filename: fileData.filename)
    }

    // MARK: - Delete Reference

    /// Delete current reference file from backend
    func deleteReferenceFile() async throws {
        _ = try await checkHealth()

        guard let url = URL(string: "\(baseURL)/delete-reference") else {
            throw SolutionAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SolutionAPIError.invalidResponse
        }

        // Clear local file ID
        ReferenceFileManager.shared.uploadedFileId = nil

        print("✅ [SolutionAPIService] Reference file deleted")
    }

    // MARK: - Get Solution

    /// Get detailed solution for a question using the reference PDF
    func getSolution(question: String, answers: [String]) async throws -> String {
        // Safeguard 11: Check backend health first
        _ = try await checkHealth()

        print("[SolutionAPIService] Getting solution for question...")
        print("   Question: \"\(question.prefix(50))...\"")
        print("   Answers: \(answers.count) options")

        guard let url = URL(string: "\(baseURL)/solve") else {
            throw SolutionAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = solveTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "question": question,
            "answers": answers
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw SolutionAPIError.solutionFailed("Invalid response")
            }

            guard httpResponse.statusCode == 200 else {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorJson["error"] as? String {
                    if errorMessage.contains("No reference PDF") {
                        throw SolutionAPIError.noReferenceFile
                    }
                    throw SolutionAPIError.solutionFailed(errorMessage)
                }
                throw SolutionAPIError.solutionFailed("HTTP \(httpResponse.statusCode)")
            }

            let solveResponse = try JSONDecoder().decode(SolveResponse.self, from: data)

            guard solveResponse.status == "success" else {
                throw SolutionAPIError.solutionFailed("Solution generation failed")
            }

            print("✅ [SolutionAPIService] Solution received (\(solveResponse.solution.count) chars)")
            return solveResponse.solution

        } catch let error as SolutionAPIError {
            throw error
        } catch {
            throw SolutionAPIError.networkError(error)
        }
    }

    // MARK: - Utilities

    /// Invalidate health cache
    func invalidateHealthCache() {
        cachedHealthy = false
        lastHealthCheck = nil
    }
}
