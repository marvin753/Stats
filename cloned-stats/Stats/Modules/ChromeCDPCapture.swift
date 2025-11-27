//
//  ChromeCDPCapture.swift
//  Stats
//
//  Created on 2025-11-13.
//  Purpose: Swift client for Chrome CDP screenshot service (Wave 3A)
//  Replaces old screen recording approach with notification-free CDP solution
//

import Foundation
import AppKit

/// Swift client for the Chrome CDP screenshot service
/// Connects to localhost:9223 to capture full-page screenshots without macOS notifications
@MainActor
class ChromeCDPCapture {

    // MARK: - Singleton

    static let shared = ChromeCDPCapture()

    // MARK: - Configuration

    private let serviceURL = "http://localhost:9223"
    private let timeout: TimeInterval = 30.0

    // MARK: - Initialization

    private init() {
        print("🔧 [ChromeCDP] ChromeCDPCapture initialized")
    }

    // MARK: - Public Methods

    /// Check if CDP service is running and available
    /// - Returns: true if service is healthy, false otherwise
    func isServiceAvailable() async -> Bool {
        guard let url = URL(string: "\(serviceURL)/health") else {
            print("❌ [ChromeCDP] Invalid health check URL")
            return false
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ [ChromeCDP] Health check failed - invalid response")
                return false
            }

            let json = try JSONDecoder().decode(HealthResponse.self, from: data)
            let isHealthy = json.status == "ok"

            if isHealthy {
                print("✅ [ChromeCDP] Service is healthy")
                print("   Chrome status: \(json.chrome)")
            } else {
                print("⚠️  [ChromeCDP] Service returned unhealthy status: \(json.status)")
            }

            return isHealthy

        } catch {
            print("❌ [ChromeCDP] Service not available: \(error.localizedDescription)")
            return false
        }
    }

    /// Capture screenshot of active Chrome tab
    /// - Returns: Base64-encoded PNG screenshot
    /// - Throws: CDPError if capture fails
    func captureActiveTab() async throws -> String {
        print("\n" + String(repeating: "=", count: 60))
        print("📸 [ChromeCDP] CAPTURING ACTIVE TAB")
        print(String(repeating: "=", count: 60))

        // Step 1: Check service availability
        print("🔍 [ChromeCDP] Step 1: Checking service availability...")
        guard await isServiceAvailable() else {
            throw CDPError.serviceUnavailable
        }

        // Step 2: Prepare capture request
        print("📤 [ChromeCDP] Step 2: Sending capture request...")
        guard let url = URL(string: "\(serviceURL)/capture-active-tab") else {
            throw CDPError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Step 3: Execute request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CDPError.invalidResponse
        }

        print("📥 [ChromeCDP] Step 3: Received response (status \(httpResponse.statusCode))")

        // Handle different status codes
        switch httpResponse.statusCode {
        case 200:
            // Success - parse response
            break

        case 404:
            print("❌ [ChromeCDP] No active Chrome tab found")
            throw CDPError.noActiveTab

        case 500:
            print("❌ [ChromeCDP] Server error during capture")
            throw CDPError.captureFailed

        default:
            print("❌ [ChromeCDP] Unexpected status code: \(httpResponse.statusCode)")
            throw CDPError.requestFailed(statusCode: httpResponse.statusCode)
        }

        // Step 4: Parse JSON response
        let captureResponse = try JSONDecoder().decode(CaptureResponse.self, from: data)

        guard captureResponse.success else {
            print("❌ [ChromeCDP] Capture reported failure")
            throw CDPError.captureFailed
        }

        // Step 5: Success!
        print("✅ [ChromeCDP] Screenshot captured successfully!")
        print("   URL: \(captureResponse.url)")
        print("   Title: \(captureResponse.title)")
        print("   Dimensions: \(captureResponse.dimensions.width)x\(captureResponse.dimensions.height)")
        print("   Screenshot size: ~\(captureResponse.base64Image.count / 1024)KB")
        print("   Timestamp: \(captureResponse.timestamp)")
        print(String(repeating: "=", count: 60) + "\n")

        return captureResponse.base64Image
    }

    /// Show user-friendly alert when service is unavailable
    func showServiceUnavailableAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Chrome CDP Service Not Running"
            alert.informativeText = """
            The screenshot capture service is not available.

            To start the service:
            1. Open Terminal
            2. Navigate to the service directory:
               cd ~/Desktop/Universität/Stats/chrome-cdp-service
            3. Start the service:
               npm start

            The service will run on port 9223.
            """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Open Terminal")

            let response = alert.runModal()

            if response == .alertSecondButtonReturn {
                // User clicked "Open Terminal" - open Terminal app
                NSWorkspace.shared.launchApplication("Terminal")
            }
        }
    }

    // MARK: - Testing

    /// Test the CDP integration
    func test() async {
        print("\n" + String(repeating: "=", count: 70))
        print("🧪 [ChromeCDP] TESTING CHROME CDP INTEGRATION")
        print(String(repeating: "=", count: 70))

        // Test 1: Health check
        print("\n📋 Test 1: Health Check")
        print("   Checking if service is running on \(serviceURL)...")
        let available = await isServiceAvailable()

        if available {
            print("   ✅ PASS: Service is running and healthy")
        } else {
            print("   ❌ FAIL: Service not available")
            print("   💡 Start service with: cd chrome-cdp-service && npm start")
            return
        }

        // Test 2: Capture screenshot
        print("\n📋 Test 2: Screenshot Capture")
        print("   Attempting to capture active Chrome tab...")

        do {
            let base64 = try await captureActiveTab()
            print("   ✅ PASS: Screenshot captured successfully")
            print("   Screenshot preview: \(base64.prefix(80))...")
            print("   Total size: ~\(base64.count / 1024)KB")

            // Validate base64
            if let _ = Data(base64Encoded: base64) {
                print("   ✅ PASS: Base64 decoding successful")
            } else {
                print("   ⚠️  WARNING: Base64 decoding failed")
            }

        } catch CDPError.noActiveTab {
            print("   ⚠️  SKIP: No active Chrome tab (open a webpage and retry)")
        } catch {
            print("   ❌ FAIL: Capture failed - \(error.localizedDescription)")
        }

        print("\n" + String(repeating: "=", count: 70))
        print("🧪 [ChromeCDP] TESTS COMPLETE")
        print(String(repeating: "=", count: 70) + "\n")
    }
}

// MARK: - Data Models

/// Response from /health endpoint
struct HealthResponse: Codable {
    let status: String
    let chrome: String
}

/// Response from /capture-active-tab endpoint
struct CaptureResponse: Codable {
    let success: Bool
    let base64Image: String
    let url: String
    let title: String
    let timestamp: String
    let dimensions: Dimensions
}

/// Screenshot dimensions
struct Dimensions: Codable {
    let width: Int
    let height: Int
}

/// CDP-specific errors
enum CDPError: LocalizedError {
    case serviceUnavailable
    case invalidURL
    case invalidResponse
    case noActiveTab
    case requestFailed(statusCode: Int)
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "Chrome CDP service is not running on port 9223. Please start the service with: cd chrome-cdp-service && npm start"

        case .invalidURL:
            return "Invalid service URL configuration"

        case .invalidResponse:
            return "Invalid response from CDP service"

        case .noActiveTab:
            return "No active Chrome tab found. Please open a webpage in Chrome and try again."

        case .requestFailed(let code):
            return "Request failed with HTTP status code \(code)"

        case .captureFailed:
            return "Screenshot capture failed on the server side"
        }
    }
}

// MARK: - Usage Examples

/*

 Example 1: Basic screenshot capture
 ------------------------------------
 Task {
     do {
         let base64Screenshot = try await ChromeCDPCapture.shared.captureActiveTab()
         print("Screenshot captured: \(base64Screenshot.count) bytes")

         // Use screenshot (e.g., send to Vision API)
         await screenshotStateManager.addScreenshot(base64Screenshot)

     } catch CDPError.serviceUnavailable {
         ChromeCDPCapture.shared.showServiceUnavailableAlert()

     } catch {
         print("Capture failed: \(error.localizedDescription)")
     }
 }


 Example 2: Check service before capture
 ----------------------------------------
 Task {
     guard await ChromeCDPCapture.shared.isServiceAvailable() else {
         print("CDP service not running")
         ChromeCDPCapture.shared.showServiceUnavailableAlert()
         return
     }

     let screenshot = try await ChromeCDPCapture.shared.captureActiveTab()
     // Process screenshot...
 }


 Example 3: Test integration
 ----------------------------
 Task {
     await ChromeCDPCapture.shared.test()
 }

 */
