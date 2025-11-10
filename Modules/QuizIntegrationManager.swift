//
//  QuizIntegrationManager.swift
//  Stats Quiz Integration
//
//  Created on 2025-11-10
//  Purpose: Coordinates screenshot-based quiz workflow using OpenAI Vision API
//

import Foundation
import AppKit
import Combine

// MARK: - Keyboard Shortcut Delegate Protocol

protocol KeyboardShortcutDelegate: AnyObject {
    func onCaptureScreenshot()
    func onProcessScreenshots()
}

// MARK: - Quiz Integration Manager

/// Coordinates the screenshot-based quiz workflow
/// Handles keyboard shortcuts, screenshot capture, AI processing, and animation
@MainActor
class QuizIntegrationManager: ObservableObject {

    // MARK: - Properties

    private let screenshotCapture = ScreenshotCapture()
    private let screenshotManager = ScreenshotStateManager()
    private let visionService = VisionAIService()

    private var animationController: QuizAnimationController?
    private var httpServer: QuizHTTPServer?
    private var keyboardManager: KeyboardShortcutManager?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        print("📱 [QuizIntegration] Initializing QuizIntegrationManager...")
        setupComponents()
    }

    private func setupComponents() {
        // Initialize animation controller
        animationController = QuizAnimationController()
        print("✅ Animation controller initialized")

        // Initialize HTTP server (if needed for other integrations)
        httpServer = QuizHTTPServer(onAnswersReceived: { [weak self] answers in
            Task { @MainActor in
                self?.handleAnswersReceived(answers)
            }
        })
        httpServer?.start()
        print("✅ HTTP server started on port 8080")

        // Note: Keyboard manager should be initialized separately
        // and delegate should be set externally

        print("✅ QuizIntegrationManager ready")
    }

    // MARK: - Public Methods

    func setKeyboardManager(_ manager: KeyboardShortcutManager) {
        self.keyboardManager = manager
        print("✅ Keyboard manager connected")
    }

    // MARK: - Private Helpers

    private func handleAnswersReceived(_ answers: [Int]) {
        guard let controller = animationController else {
            print("❌ Animation controller not available")
            return
        }

        print("📥 Received \(answers.count) answers from external source")
        controller.startAnimation(with: answers)
    }

    private func showNotification(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
}

// MARK: - KeyboardShortcutDelegate Implementation

extension QuizIntegrationManager: KeyboardShortcutDelegate {

    /// Handles Cmd+Shift+K: Capture screenshot
    func onCaptureScreenshot() {
        print("📸 [QuizIntegration] Capture screenshot triggered")

        // Check permission
        guard screenshotCapture.hasScreenRecordingPermission() else {
            print("⚠️  Screen recording permission not granted")
            showNotification(
                title: "Permission Required",
                message: "Grant Screen Recording permission in System Preferences > Privacy & Security > Screen Recording"
            )
            return
        }

        // Capture screenshot
        guard let base64Image = screenshotCapture.captureMainDisplay() else {
            print("❌ Failed to capture screenshot")
            showNotification(title: "Capture Failed", message: "Could not capture screenshot")
            return
        }

        // Add to manager
        let result = screenshotManager.addScreenshot(base64Image)
        if result.success {
            let count = screenshotManager.getScreenshotCount()
            print("✅ Screenshot \(count) captured")
            showNotification(
                title: "Screenshot Captured",
                message: "Screenshot \(count)/20 captured. Press Cmd+Shift+P to process."
            )

            if let warning = result.warning {
                print("⚠️  \(warning)")
            }
        } else {
            print("❌ Failed to add screenshot: \(result.warning ?? "unknown error")")
            showNotification(title: "Error", message: result.warning ?? "Failed to add screenshot")
        }
    }

    /// Handles Cmd+Shift+P: Process all screenshots
    func onProcessScreenshots() {
        print("🚀 [QuizIntegration] Process screenshots triggered")

        // Check if ready
        guard screenshotManager.isReadyToProcess() else {
            print("⚠️  No screenshots to process")
            showNotification(
                title: "No Screenshots",
                message: "Capture screenshots first with Cmd+Shift+K"
            )
            return
        }

        let count = screenshotManager.getScreenshotCount()
        print("📊 Processing \(count) screenshots...")
        showNotification(title: "Processing...", message: "Analyzing \(count) screenshots with AI")

        // Process asynchronously
        Task {
            do {
                // Get all screenshots
                let screenshots = screenshotManager.getAllScreenshots()
                print("📤 Sending \(screenshots.count) screenshots to OpenAI Vision...")

                // Extract questions with AI
                let questions = try await visionService.extractQuizQuestions(from: screenshots)
                print("✅ Extracted \(questions.count) questions")

                // Send to backend for answer analysis
                let answers = try await sendToBackend(questions: questions)
                print("✅ Received \(answers.count) answer indices")

                // Trigger animation
                await MainActor.run {
                    guard let controller = animationController else {
                        print("❌ Animation controller not available")
                        return
                    }

                    controller.startAnimation(with: answers)
                    print("🎬 Animation started")
                    showNotification(
                        title: "Success!",
                        message: "Extracted \(questions.count) questions, animating answers"
                    )
                }

                // Clear screenshots
                screenshotManager.clearScreenshots()
                print("🧹 Screenshots cleared")

            } catch {
                print("❌ Error processing screenshots: \(error.localizedDescription)")
                await MainActor.run {
                    showNotification(
                        title: "Processing Failed",
                        message: error.localizedDescription
                    )
                }
            }
        }
    }

    /// Sends questions to backend for answer analysis
    /// - Parameter questions: Array of question dictionaries
    /// - Returns: Array of answer indices (1-indexed)
    private func sendToBackend(questions: [[String: Any]]) async throws -> [Int] {
        let url = URL(string: "http://localhost:3000/api/analyze")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60.0

        let body: [String: Any] = ["questions": questions]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("📤 Sending \(questions.count) questions to backend...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "Backend",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response from backend"]
            )
        }

        print("📥 Backend responded with status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "Backend",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Backend error: \(errorMessage)"]
            )
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let answers = json["answers"] as? [Int] else {
            throw NSError(
                domain: "Backend",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid backend response format"]
            )
        }

        return answers
    }
}

// MARK: - Helper Types

/// Simple HTTP Server wrapper for receiving answers
class QuizHTTPServer {
    private var onAnswersReceived: ([Int]) -> Void

    init(onAnswersReceived: @escaping ([Int]) -> Void) {
        self.onAnswersReceived = onAnswersReceived
    }

    func start() {
        // HTTP server implementation would go here
        // For now, this is a placeholder for compatibility
        print("ℹ️  HTTP Server placeholder initialized")
    }
}

// MARK: - Keyboard Shortcut Manager Stub

/// Manages global keyboard shortcuts
/// This should be initialized in AppDelegate and connected to QuizIntegrationManager
class KeyboardShortcutManager {
    weak var delegate: KeyboardShortcutDelegate?

    init() {
        setupKeyboardMonitoring()
    }

    private func setupKeyboardMonitoring() {
        // Keyboard monitoring setup would go here
        // This requires Carbon framework or CGEvent monitoring
        print("⌨️  Keyboard shortcut manager initialized")
        print("   Cmd+Shift+K = Capture screenshot")
        print("   Cmd+Shift+P = Process screenshots")
    }
}

// MARK: - Animation Controller Stub

/// Handles quiz answer animations
/// This should be the actual QuizAnimationController from the Stats app
class QuizAnimationController: ObservableObject {
    @Published var currentNumber: Int = 0
    @Published var isAnimating: Bool = false

    func startAnimation(with answers: [Int]) {
        print("🎬 Starting animation with \(answers.count) answers: \(answers)")
        isAnimating = true

        // Animation logic would be implemented here
        // This is a simplified placeholder

        Task {
            for (index, answer) in answers.enumerated() {
                print("   Animating answer \(index + 1): \(answer)")
                await MainActor.run {
                    self.currentNumber = answer
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
            }

            await MainActor.run {
                self.currentNumber = 0
                self.isAnimating = false
                print("✅ Animation complete")
            }
        }
    }
}

// MARK: - Usage Example

/*

 Example usage in AppDelegate or main app:

 ```swift
 @MainActor
 class AppDelegate: NSApplicationDelegate {
     var quizIntegration: QuizIntegrationManager!
     var keyboardManager: KeyboardShortcutManager!

     func applicationDidFinishLaunching(_ notification: Notification) {
         // Initialize integration manager
         quizIntegration = QuizIntegrationManager()

         // Initialize keyboard manager
         keyboardManager = KeyboardShortcutManager()

         // Connect keyboard manager to integration manager
         keyboardManager.delegate = quizIntegration
         quizIntegration.setKeyboardManager(keyboardManager)

         print("✅ Quiz integration ready")
         print("   Press Cmd+Shift+K to capture screenshots")
         print("   Press Cmd+Shift+P to process and animate")
     }
 }
 ```

 Workflow:
 1. User presses Cmd+Shift+K → Screenshot captured and accumulated
 2. User scrolls down and presses Cmd+Shift+K again → Another screenshot added
 3. ... (repeat as needed)
 4. User presses Cmd+Shift+P → All screenshots sent to OpenAI Vision
 5. AI extracts questions/answers
 6. Backend analyzes answers
 7. Animation displays results
 8. Screenshots cleared, ready for next quiz

 */
