/**
 * Quiz Integration Manager
 * Coordinates all quiz components:
 * - Keyboard shortcut listening
 * - Animation control
 * - HTTP server for receiving commands
 * - Backend communication
 */

import Cocoa
import Combine
import GPU

@MainActor
class QuizIntegrationManager: NSObject, ObservableObject {

    // MARK: - Singleton
    static let shared = QuizIntegrationManager()

    // MARK: - Published Properties
    @Published var isEnabled: Bool = false
    @Published var currentDisplayValue: Int = 0
    @Published var isAnimating: Bool = false

    // MARK: - Components
    private let animationController = QuizAnimationController()
    private let httpServer = QuizHTTPServer()
    private let keyboardManager = KeyboardShortcutManager()
    private let screenshotCapture = ScreenshotCapture()
    private lazy var screenshotManager: ScreenshotStateManager = {
        return ScreenshotStateManager()
    }()
    private let visionService = VisionAIService()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Single-Capture Flow Components
    private let screenshotCroppingService = ScreenshotCroppingService.shared
    private let visionAIService = VisionAIService()
    private let questionFileManager = QuestionFileManager.shared

    // MARK: - GPU Module Reference (Phase 2B)
    private weak var gpuModule: GPU?

    // MARK: - Process Management (Security Fix #4, #5)
    private var scraperProcess: Process?
    private var isScraperRunning = false
    private var aiFilterProcess: Process?
    private var isAIFilterRunning = false

    // MARK: - Path Configuration (Security Fix #3)
    private let scraperPath: String = {
        // Try environment variable first
        if let envPath = ProcessInfo.processInfo.environment["SCRAPER_PATH"] {
            return envPath
        }

        // Fallback to default location
        return "/Users/marvinbarsal/Desktop/Universität/Stats/scraper.js"
    }()

    private let aiFilterPath: String = {
        // Try environment variable first
        if let envPath = ProcessInfo.processInfo.environment["AI_FILTER_PATH"] {
            return envPath
        }

        // Fallback to default location
        return "/Users/marvinbarsal/Desktop/Universität/Stats/ai-parser-service.js"
    }()

    // MARK: - Initialization
    override init() {
        super.init()
        setupBindings()
    }

    // MARK: - Public Methods

    /**
     * Initialize and start all quiz systems
     */
    func initialize() {
        print("\n🎬 [QuizIntegration] Initializing Quiz Integration Manager...")

        // Request Screen Recording permission at startup
        if #available(macOS 10.15, *) {
            print("🔒 [QuizIntegration] Checking Screen Recording permission...")

            // First check if we have permission
            let hasPermission = CGPreflightScreenCaptureAccess()

            if hasPermission {
                print("✅ [QuizIntegration] Screen Recording permission: GRANTED")
            } else {
                print("⚠️  [QuizIntegration] Screen Recording permission: DENIED")
                print("   Requesting permission...")

                // Request permission (this will show system dialog)
                let granted = CGRequestScreenCaptureAccess()

                if granted {
                    print("✅ [QuizIntegration] Permission granted by user")
                } else {
                    print("❌ [QuizIntegration] Permission denied by user")
                    print("   Screenshot capture will not work until permission is granted")

                    // Show notification to user
                    showNotification(
                        title: "Permission Required",
                        message: "Enable Screen Recording in System Preferences → Security & Privacy → Privacy → Screen Recording"
                    )
                }
            }
        }

        print("🔧 [QuizIntegration] Step 1: Setting up delegates...")
        httpServer.delegate = self
        keyboardManager.delegate = self
        print("   ✓ HTTP server delegate set")
        print("   ✓ Keyboard manager delegate set")

        print("🔧 [QuizIntegration] Step 2: Starting HTTP server...")
        httpServer.startServer()

        print("🔧 [QuizIntegration] Step 3: Registering keyboard shortcut...")
        keyboardManager.registerGlobalShortcut()

        print("🔧 [QuizIntegration] Step 4: Starting AI Filter Service...")
        startAIFilterService()

        print("🔧 [QuizIntegration] Step 5: Subscribing to animation updates...")
        animationController.$currentNumber
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.currentDisplayValue = value
            }
            .store(in: &cancellables)

        animationController.$isAnimating
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.isAnimating = value
            }
            .store(in: &cancellables)

        isEnabled = true
        print("✅ [QuizIntegration] Quiz Integration Manager initialized successfully")
        print("   - HTTP Server: \(httpServer)")
        print("   - Keyboard Manager: \(keyboardManager)")
        print("   - Animation Controller: \(animationController)")
    }

    /**
     * Connect to GPU module for display integration (Phase 2B)
     * Must be called AFTER modules are mounted in AppDelegate
     */
    func connectToGPUModule(_ gpu: GPU) {
        self.gpuModule = gpu
        print("🔗 Connected to GPU module for quiz display")

        // Observe currentNumber changes and update GPU widget
        animationController.$currentNumber
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak gpu] number in
                gpu?.updateQuizNumber(number)
                self?.currentDisplayValue = number
            }
            .store(in: &cancellables)

        // Initialize GPU widget with 0
        gpu.updateQuizNumber(0)
        print("✅ GPU widget integration complete - displaying default value: 0")
    }


    /**
     * Shutdown all quiz systems
     */
    func shutdown() {
        print("\n🛑 Shutting down Quiz Integration Manager...")

        animationController.stopAnimation()
        httpServer.stopServer()
        keyboardManager.unregisterGlobalShortcut()
        stopAIFilterService()

        isEnabled = false
        print("✓ Quiz Integration Manager shut down")
    }

    /**
     * Trigger quiz animation from external source
     */
    func triggerQuiz(with answers: [Int]) {
        print("▶️  Triggering quiz animation")
        animationController.startAnimation(with: answers)
    }

    // MARK: - Private Methods

    /**
     * Find Node.js executable path
     * Supports Intel Macs (/usr/local/bin) and M1/M2 Macs (/opt/homebrew/bin)
     * Security Fix (Code Review): Consolidates node path detection logic
     */
    private func findNodeExecutable() -> String? {
        let possiblePaths = [
            "/opt/homebrew/bin/node",    // M1/M2 Macs (Apple Silicon)
            "/usr/local/bin/node",       // Intel Macs
            "/usr/bin/node"              // System fallback
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        return nil
    }

    /**
     * Setup process pipes for output/error capture
     * Security Fix (Code Review): Prevents duplicate pipe setup code
     * @param process - The Process to configure
     * @param logPrefix - Prefix for log messages (e.g., "[AIFilter]" or "[Scraper]")
     * @returns Tuple of (outputPipe, errorPipe)
     */
    private func setupProcessPipes(_ process: Process, logPrefix: String) -> (output: Pipe, error: Pipe) {
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Read output asynchronously
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                print("📄 \(logPrefix) \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                print("⚠️  \(logPrefix) \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }

        return (outputPipe, errorPipe)
    }

    private func setupBindings() {
        // Subscribe to animation changes
        animationController.$currentNumber
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.currentDisplayValue = value
            }
            .store(in: &cancellables)

        animationController.$isAnimating
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.isAnimating = value
            }
            .store(in: &cancellables)
    }

    /**
     * Start the AI Filter Service (ai-parser-service.js)
     * This service receives raw DOM from scraper and uses Ollama to extract Q&A
     */
    private func startAIFilterService() {
        print("🤖 [AIFilter] Starting AI Filter Service...")

        // Validate AI filter script exists
        guard FileManager.default.fileExists(atPath: aiFilterPath) else {
            print("❌ [AIFilter] AI Filter script not found at: \(aiFilterPath)")
            return
        }

        // Security Fix (Code Review): Use consolidated node path detection
        guard let nodePath = findNodeExecutable() else {
            print("❌ [AIFilter] Node.js not found in standard locations")
            return
        }

        print("✓ [AIFilter] Using Node.js at: \(nodePath)")

        // Cancel any existing AI filter process
        if let existingProcess = aiFilterProcess, existingProcess.isRunning {
            print("⚠️  [AIFilter] Terminating existing AI filter process")
            existingProcess.terminate()
        }

        let task = Process()
        aiFilterProcess = task

        task.executableURL = URL(fileURLWithPath: nodePath)
        task.arguments = [aiFilterPath]

        // Security Fix (Code Review): Use helper method for pipe setup
        let pipes = setupProcessPipes(task, logPrefix: "[AIFilter]")

        // Warning #1 Fix: Add explicit file handle closure in termination handler
        task.terminationHandler = { [weak self] process in
            print("🔚 [AIFilter] AI Filter process terminated with status: \(process.terminationStatus)")

            // Clean up file handles
            pipes.output.fileHandleForReading.readabilityHandler = nil
            pipes.error.fileHandleForReading.readabilityHandler = nil

            // WARNING #1 FIX: Explicitly close file handles to prevent descriptor leaks
            try? pipes.output.fileHandleForReading.close()
            try? pipes.error.fileHandleForReading.close()

            // Update main actor-isolated properties on main actor
            Task { @MainActor in
                self?.aiFilterProcess = nil
                self?.isAIFilterRunning = false
            }
        }

        do {
            try task.run()
            isAIFilterRunning = true
            print("✅ [AIFilter] AI Filter Service launched successfully")
            print("   Running on port 3001 (Ollama integration)")
        } catch {
            print("❌ [AIFilter] Failed to launch AI Filter Service: \(error.localizedDescription)")
            aiFilterProcess = nil
            isAIFilterRunning = false
        }
    }

    /**
     * Stop the AI Filter Service
     * WARNING #2 FIX: Implements graceful termination with 3-second timeout
     */
    private func stopAIFilterService() {
        guard let process = aiFilterProcess, process.isRunning else {
            print("✓ [AIFilter] AI Filter Service not running")
            return
        }

        print("🛑 [AIFilter] Stopping AI Filter Service...")
        process.terminate()

        // WARNING #2 FIX: Wait up to 3 seconds for graceful termination
        let startTime = Date()
        let timeout: TimeInterval = 3.0
        var attempts = 0
        let maxAttempts = 30 // 30 * 100ms = 3 seconds

        while process.isRunning && attempts < maxAttempts {
            usleep(100_000) // Sleep 100ms (0.1 seconds)
            attempts += 1

            if Date().timeIntervalSince(startTime) >= timeout {
                break
            }
        }

        // WARNING #2 FIX: Force kill if process hasn't stopped gracefully
        if process.isRunning {
            print("⚠️  [AIFilter] Process did not terminate gracefully, forcing termination")
            process.interrupt() // Send SIGINT (stronger than SIGTERM)

            // Wait one more brief moment
            usleep(500_000) // 500ms

            if process.isRunning {
                print("❌ [AIFilter] Process still running after force kill attempt")
            }
        }

        aiFilterProcess = nil
        isAIFilterRunning = false
        print("✅ [AIFilter] AI Filter Service stopped")
    }

    /**
     * Get current browser tab URL using AppleScript
     * Supports Chrome and Safari
     */
    private func getCurrentBrowserURL() -> String? {
        // Try Chrome first with proper error handling
        let chromeScript = """
        tell application "Google Chrome"
            if it is running then
                if (count of windows) > 0 then
                    if (count of tabs of front window) > 0 then
                        return URL of active tab of front window
                    end if
                end if
            end if
        end tell
        return ""
        """

        if let chromeURL = executeAppleScript(chromeScript), !chromeURL.isEmpty {
            return chromeURL
        }

        // Try Safari as fallback
        let safariScript = """
        tell application "Safari"
            if it is running then
                if (count of windows) > 0 then
                    if (count of documents) > 0 then
                        return URL of front document
                    end if
                end if
            end if
        end tell
        return ""
        """

        if let safariURL = executeAppleScript(safariScript), !safariURL.isEmpty {
            return safariURL
        }

        print("⚠️  Could not get URL from Chrome or Safari")
        print("   Possible reasons: No browser windows open, all windows minimized, or browser not running")
        return nil
    }

    /**
     * Execute AppleScript and return result
     */
    private func executeAppleScript(_ script: String) -> String? {
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        let result = appleScript?.executeAndReturnError(&error)

        if let error = error {
            print("⚠️  AppleScript error: \(error)")
            return nil
        }

        return result?.stringValue
    }

    /**
     * Validates URL for security before passing to scraper (Security Fix #2)
     */
    private func validateURL(_ urlString: String) -> Bool {
        // Check for empty URL
        guard !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        // Parse as URL
        guard let url = URL(string: urlString) else {
            return false
        }

        // Check scheme (only allow HTTP/HTTPS)
        guard let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return false
        }

        return true
    }

    /**
     * Launch the Node.js scraper with the given URL
     */
    private func launchScraper(url: String) {
        print("🌐 Launching scraper for URL: \(url)")

        // Security Fix #1: Validate URL first
        guard let urlObject = URL(string: url),
              let scheme = urlObject.scheme,
              ["http", "https"].contains(scheme.lowercased()) else {
            print("❌ Invalid URL scheme detected: \(url)")
            isScraperRunning = false
            return
        }

        // Security Fix #3: Validate scraper exists
        guard FileManager.default.fileExists(atPath: scraperPath) else {
            print("❌ Scraper not found at: \(scraperPath)")
            isScraperRunning = false
            return
        }

        // Security Fix (Code Review): Use consolidated node path detection
        guard let nodePath = findNodeExecutable() else {
            print("❌ Node.js not found in standard locations")
            isScraperRunning = false
            return
        }

        print("✓ Using Node.js at: \(nodePath)")

        // Security Fix #4: Cancel any existing scraper
        if let existingProcess = scraperProcess, existingProcess.isRunning {
            print("⚠️  Terminating existing scraper process")
            existingProcess.terminate()
        }

        let task = Process()
        scraperProcess = task  // Retain reference

        task.executableURL = URL(fileURLWithPath: nodePath)

        // Security Fix #1: Pass URL as separate argument to prevent command injection
        task.arguments = [
            scraperPath,  // Use variable instead of hardcoded path
            "--url",      // Separate flag
            url           // Separate value - cannot be interpreted as shell command
        ]

        // Security Fix (Code Review): Use helper method for pipe setup
        let pipes = setupProcessPipes(task, logPrefix: "[Scraper]")

        // Security Fix #4 + WARNING #1 FIX: Add termination handler with explicit file handle closure
        task.terminationHandler = { [weak self] process in
            print("🔚 Scraper process terminated with status: \(process.terminationStatus)")

            // Clean up file handles
            pipes.output.fileHandleForReading.readabilityHandler = nil
            pipes.error.fileHandleForReading.readabilityHandler = nil

            // WARNING #1 FIX: Explicitly close file handles to prevent descriptor leaks
            try? pipes.output.fileHandleForReading.close()
            try? pipes.error.fileHandleForReading.close()

            // Update main actor-isolated properties on main actor
            Task { @MainActor in
                self?.scraperProcess = nil
                self?.isScraperRunning = false  // Reset flag
            }
        }

        do {
            try task.run()
            print("✅ Scraper launched successfully")
        } catch {
            print("❌ Failed to launch scraper: \(error.localizedDescription)")
            scraperProcess = nil
            isScraperRunning = false  // Reset flag
        }
    }

    // MARK: - Notification Helper

    /**
     * Show a system notification to the user
     * Uses UserNotifications framework for modern macOS
     * - Parameters:
     *   - title: Notification title
     *   - message: Notification body message
     */
    private func showNotification(title: String, message: String) {
        print("🔔 Notification: \(title) - \(message)")

        // Use NSUserNotification for broader compatibility
        // Note: NSUserNotification is deprecated but still works on macOS 10.14+
        // For production, consider migrating to UNUserNotificationCenter
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName

        NSUserNotificationCenter.default.deliver(notification)
    }
}

// MARK: - Keyboard Shortcut Delegate
extension QuizIntegrationManager: KeyboardShortcutDelegate {
    /**
     * Called when Cmd+Option+O is pressed - Capture screenshot and extract question
     * New single-capture flow:
     * 1. Capture blue box at mouse position
     * 2. Call OpenAI to extract question
     * 3. Save to file (with 14-question limit auto-rotation)
     * 4. Show notification with result
     */
    func onCaptureScreenshot() {
        print("\n" + String(repeating: "=", count: 60))
        print("📸 [QuizIntegration] CAPTURE SCREENSHOT (Cmd+Option+O)")
        print(String(repeating: "=", count: 60))

        // Step 1: Capture blue box at mouse position
        guard let result = screenshotCroppingService.captureAndCropScreenshot() else {
            print("❌ Could not capture blue box at mouse position")
            showNotification(title: "Capture Failed", message: "Could not capture blue box at mouse position")
            return
        }

        guard let imageURL = result.imageURL else {
            print("❌ Screenshot was captured but image URL is nil")
            showNotification(title: "Capture Failed", message: "Failed to save screenshot image")
            return
        }

        let mouseCoords = result.mouseCoords

        print("✅ Blue box captured successfully")
        print("   Mouse position: X=\(Int(mouseCoords.x)), Y=\(Int(mouseCoords.y))")
        print("   Image saved to: \(imageURL.path)")

        // Step 2: Call OpenAI to extract question (async)
        Task {
            do {
                print("🤖 Calling OpenAI Vision API to extract question...")

                guard let extracted = try await visionAIService.extractSingleQuestion(
                    from: imageURL,
                    mouseCoords: (x: mouseCoords.x, y: mouseCoords.y)
                ) else {
                    print("❌ Could not extract question from image")
                    showNotification(title: "Extraction Failed", message: "Could not extract question from image")
                    return
                }

                print("✅ Question extracted successfully")
                print("   Question: \(extracted.question.prefix(60))...")
                print("   Answers: \(extracted.answers.count) options")

                // Step 3: Analyze correct answer using OpenAI
                print("🤖 Analyzing correct answer with OpenAI...")
                let correctAnswer = try? await visionAIService.getCorrectAnswer(
                    for: extracted.question,
                    with: extracted.answers
                )

                if let answer = correctAnswer {
                    print("✅ Correct answer determined: \(answer)")
                } else {
                    print("⚠️ Could not determine correct answer (will save as null)")
                }

                // Step 4: Save to file WITH correct answer
                let (filePath, questionIndex) = questionFileManager.addQuestion(
                    question: extracted.question,
                    answers: extracted.answers,
                    coordinates: (x: Double(mouseCoords.x), y: Double(mouseCoords.y)),
                    correctAnswer: correctAnswer
                )

                print("💾 Question saved to file:")
                print("   File: \(filePath)")
                print("   Question index: \(questionIndex)")

                // Step 4: Show success notification
                let fileInfo = questionFileManager.getCurrentFileInfo()
                let truncatedQuestion = String(extracted.question.prefix(50))
                showNotification(
                    title: "Question Captured (\(fileInfo.questionCount)/14)",
                    message: "Q: \(truncatedQuestion)..."
                )

                print(String(repeating: "=", count: 60))
                print("✅ SINGLE-CAPTURE FLOW COMPLETE")
                print(String(repeating: "=", count: 60) + "\n")

            } catch {
                print("❌ Error during question extraction: \(error.localizedDescription)")
                showNotification(title: "Error", message: error.localizedDescription)
            }
        }
    }

    /**
     * Called when Cmd+Control+P is pressed - Process all screenshots
     */
    func onProcessScreenshots() {
        print("\n" + String(repeating: "=", count: 60))
        print("🚀 [QuizIntegration] PROCESS SCREENSHOTS (Cmd+Control+P)")
        print(String(repeating: "=", count: 60))

        // Check if we have screenshots to process
        guard screenshotManager.isReadyToProcess() else {
            print("⚠️  No screenshots to process")
            print("   Press Cmd+Option+O to capture screenshots first")
            return
        }

        let count = screenshotManager.getScreenshotCount()
        print("📤 Processing \(count) screenshots...")

        // Process asynchronously
        Task { @MainActor in
            do {
                // Get all screenshots
                let screenshots = screenshotManager.getAllScreenshots()
                print("📸 Sending \(screenshots.count) screenshots to OpenAI Vision API...")

                // Extract questions using Vision API
                let questions = try await visionService.extractQuizQuestions(from: screenshots)
                print("✅ Extracted \(questions.count) questions from screenshots")

                // Send questions to backend for answer analysis
                print("📤 Sending questions to backend for analysis...")
                let answers = try await sendToBackend(questions: questions)
                print("✅ Received \(answers.count) answer indices from backend")

                // Trigger animation
                animationController.startAnimation(with: answers)
                print("🎬 Animation started with \(answers.count) answers")

                // Clear screenshots after successful processing
                screenshotManager.clearScreenshots()
                print("🧹 Screenshots cleared - ready for next quiz")

            } catch {
                print("❌ Error processing screenshots: \(error.localizedDescription)")
            }
        }
    }

    /**
     * Called when Cmd+I is pressed - Robust blue box capture
     * Uses LAB color space algorithm for reliable detection
     */
    func onRobustCapture() {
        print("\n" + String(repeating: "=", count: 60))
        print("🎯 [QuizIntegration] ROBUST CAPTURE (Cmd+I)")
        print(String(repeating: "=", count: 60))

        // Use robust LAB-based detection
        guard let result = screenshotCroppingService.captureBlueBoxRobust() else {
            print("❌ Could not capture blue box using robust algorithm")
            showNotification(title: "Capture Failed", message: "Robust detection could not find blue box")
            return
        }

        guard let imageURL = result.imageURL else {
            print("❌ Robust capture succeeded but image URL is nil")
            showNotification(title: "Capture Failed", message: "Failed to save screenshot")
            return
        }

        let mouseCoords = result.mouseCoords
        print("✅ Robust capture successful")
        print("   Image: \(imageURL.lastPathComponent)")

        // Continue with Vision API extraction (same as existing flow)
        Task {
            do {
                print("🤖 Calling OpenAI Vision API to extract question...")
                guard let extracted = try await visionAIService.extractSingleQuestion(
                    from: imageURL,
                    mouseCoords: (x: mouseCoords.x, y: mouseCoords.y)
                ) else {
                    print("❌ Could not extract question from image")
                    showNotification(title: "Extraction Failed", message: "Could not extract question from image")
                    return
                }

                print("✅ Question extracted successfully")

                // Analyze correct answer using OpenAI
                print("🤖 Analyzing correct answer with OpenAI...")
                let correctAnswer = try? await visionAIService.getCorrectAnswer(
                    for: extracted.question,
                    with: extracted.answers
                )

                if let answer = correctAnswer {
                    print("✅ Correct answer determined: \(answer)")
                } else {
                    print("⚠️ Could not determine correct answer (will save as null)")
                }

                // Save to file WITH correct answer
                let (filePath, questionIndex) = questionFileManager.addQuestion(
                    question: extracted.question,
                    answers: extracted.answers,
                    coordinates: (x: Double(mouseCoords.x), y: Double(mouseCoords.y)),
                    correctAnswer: correctAnswer
                )

                let fileInfo = questionFileManager.getCurrentFileInfo()
                let truncatedQuestion = String(extracted.question.prefix(50))
                showNotification(
                    title: "Robust Capture (\(fileInfo.questionCount)/14)",
                    message: "Q: \(truncatedQuestion)..."
                )

                print("✅ ROBUST CAPTURE FLOW COMPLETE\n")
            } catch {
                print("❌ Error: \(error.localizedDescription)")
                showNotification(title: "Error", message: error.localizedDescription)
            }
        }
    }

    /**
     * Send questions to backend for OpenAI answer analysis
     */
    private func sendToBackend(questions: [[String: Any]]) async throws -> [Int] {
        let backendURL = URL(string: "http://localhost:3000/api/analyze")!
        var request = URLRequest(url: backendURL)
        request.httpMethod = "POST"

        let payload: [String: Any] = [
            "questions": questions,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        // Set Content-Type AFTER httpBody to prevent URLSession from adding charset=UTF-8
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "Backend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Backend returned error"])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let answers = json["answers"] as? [Int] else {
            throw NSError(domain: "Backend", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid backend response"])
        }

        return answers
    }

    // MARK: - Solution Injection (Cmd+Option+U)

    func onSolutionShortcut() {
        print("🎯 [QuizIntegration] Solution shortcut triggered (Cmd+Option+U)")

        Task { @MainActor in
            await performSolutionWorkflow()
        }
    }

    @MainActor
    private func performSolutionWorkflow() async {
        // Safeguard 11: Check backend health FIRST
        do {
            let isHealthy = try await SolutionAPIService.shared.checkHealth()
            guard isHealthy else {
                showAlert(
                    title: "Backend Unavailable",
                    message: "The backend server is not responding.\n\nPlease start it with:\ncd backend && npm start"
                )
                return
            }
        } catch {
            showAlert(
                title: "Cannot Connect to Backend",
                message: "Error: \(error.localizedDescription)\n\nPlease ensure the backend server is running on localhost:3000"
            )
            return
        }

        // Check permissions
        let permissions = UserPermissionManager.shared.checkAllPermissions()
        guard permissions.inputMonitoring && permissions.accessibility else {
            print("⚠️ [QuizIntegration] Missing permissions")
            UserPermissionManager.shared.showPermissionGuidance()
            return
        }

        // Check reference file configured
        guard ReferenceFileManager.shared.hasReferenceFile else {
            showAlert(
                title: "No Reference PDF",
                message: "No reference PDF is selected.\n\nPlease select a PDF in the Screenshots settings."
            )
            return
        }

        // Check if reference is uploaded to backend
        let hasBackendReference = await SolutionAPIService.shared.hasReferenceFile
        if !hasBackendReference {
            print("[QuizIntegration] Reference not uploaded to backend - uploading now...")
            do {
                _ = try await SolutionAPIService.shared.uploadCurrentReferencePDF()
            } catch {
                showAlert(
                    title: "Upload Failed",
                    message: "Failed to upload reference PDF: \(error.localizedDescription)"
                )
                return
            }
        }

        // Get last question from JSON files
        guard let lastQuestion = await getLastQuestionAsync() else {
            showAlert(
                title: "No Questions Found",
                message: "No questions found in the JSON files.\n\nCapture some questions first using Cmd+Option+O"
            )
            return
        }

        print("[QuizIntegration] Last question: \"\(lastQuestion.question.prefix(50))...\"")
        print("[QuizIntegration] Answers: \(lastQuestion.answers)")

        // Get solution from backend
        do {
            print("[QuizIntegration] Requesting solution from backend...")
            let solution = try await SolutionAPIService.shared.getSolution(
                question: lastQuestion.question,
                answers: lastQuestion.answers
            )

            print("✅ [QuizIntegration] Solution received:")
            print("   - Length: \(solution.count) characters")
            print("   - Preview: \"\(String(solution.prefix(200)))...\"")
            print("   - Is empty: \(solution.isEmpty)")

            // Verify solution is not empty
            guard !solution.isEmpty else {
                print("❌ [QuizIntegration] ERROR: Solution is EMPTY!")
                showAlert(
                    title: "Empty Solution",
                    message: "The backend returned an empty solution. Please try again."
                )
                return
            }

            // Save solution to files
            saveSolution(solution, for: lastQuestion)

            // Start text injection
            print("[QuizIntegration] Starting text injection...")
            print("[QuizIntegration] Setting delegate and calling startInjection()...")
            TextInjectionEngine.shared.delegate = self
            TextInjectionEngine.shared.startInjection(with: solution)
            print("[QuizIntegration] startInjection() called successfully")

        } catch {
            print("❌ [QuizIntegration] Solution request failed: \(error)")
            showAlert(
                title: "Solution Failed",
                message: "Failed to get solution: \(error.localizedDescription)"
            )
        }
    }

    private func getLastQuestionAsync() async -> (question: String, answers: [String], correctAnswer: Int?)? {
        return QuestionFileManager.shared.getLastQuestion()
    }

    private func saveSolution(_ solution: String, for question: (question: String, answers: [String], correctAnswer: Int?)) {
        // Use SolutionStorageManager for dual-file storage:
        // - all_solutions.json (history)
        // - current_solution.txt (for injection)
        let success = SolutionStorageManager.shared.saveSolution(
            question: question.question,
            answers: question.answers,
            solution: solution
        )

        if success {
            print("✅ [QuizIntegration] Solution saved via SolutionStorageManager")
            print("   - Total solutions: \(SolutionStorageManager.shared.getTotalSolutionCount())")
        } else {
            print("⚠️ [QuizIntegration] SolutionStorageManager failed to save solution")
        }

        // Also save to legacy files for backwards compatibility
        saveLegacySolution(solution, for: question)
    }

    /// Save to legacy file locations for backwards compatibility
    private func saveLegacySolution(_ solution: String, for question: (question: String, answers: [String], correctAnswer: Int?)) {
        let timestamp = ISO8601DateFormatter().string(from: Date())

        let solutionData: [String: Any] = [
            "question": question.question,
            "answers": question.answers,
            "correctAnswer": question.correctAnswer as Any,
            "solution": solution,
            "timestamp": timestamp
        ]

        // Save to latest_solution.json (overwrites)
        let latestSolutionURL = URL(fileURLWithPath: "/Users/marvinbarsal/Desktop/Universität/Stats/latest_solution.json")

        do {
            let data = try JSONSerialization.data(withJSONObject: solutionData, options: .prettyPrinted)
            try data.write(to: latestSolutionURL)
            print("✅ [QuizIntegration] Legacy solution saved to: \(latestSolutionURL.path)")
        } catch {
            print("⚠️ [QuizIntegration] Failed to save legacy solution: \(error)")
        }

        // Append to solutions_history.json (legacy master file)
        appendToLegacyHistory(solutionData)
    }

    /// Append solution to the legacy history file
    private func appendToLegacyHistory(_ solutionData: [String: Any]) {
        let historyURL = URL(fileURLWithPath: "/Users/marvinbarsal/Desktop/Universität/Stats/solutions_history.json")

        // Create history structure
        var historyEntry: [String: Any] = solutionData
        historyEntry["id"] = UUID().uuidString

        do {
            var historyArray: [[String: Any]] = []

            // Load existing history if file exists
            if FileManager.default.fileExists(atPath: historyURL.path) {
                let existingData = try Data(contentsOf: historyURL)
                if let existingHistory = try JSONSerialization.jsonObject(with: existingData) as? [String: Any],
                   let entries = existingHistory["solutions"] as? [[String: Any]] {
                    historyArray = entries
                }
            }

            // Append new entry
            historyArray.append(historyEntry)

            // Create history document
            let historyDocument: [String: Any] = [
                "version": "1.0",
                "lastUpdated": ISO8601DateFormatter().string(from: Date()),
                "totalSolutions": historyArray.count,
                "solutions": historyArray
            ]

            // Save updated history
            let historyData = try JSONSerialization.data(withJSONObject: historyDocument, options: .prettyPrinted)
            try historyData.write(to: historyURL)

            print("✅ [QuizIntegration] Legacy history updated (total: \(historyArray.count))")

        } catch {
            print("⚠️ [QuizIntegration] Failed to append to legacy history: \(error)")
        }
    }

    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    // MARK: - Migration

    /**
     * Migrate existing JSON files to add correctAnswer field
     * Calls OpenAI for each question that doesn't have a correctAnswer
     */
    func migrateExistingQuestions() async {
        print("\n" + String(repeating: "=", count: 60))
        print("📦 MIGRATING EXISTING QUESTIONS")
        print(String(repeating: "=", count: 60))

        let questionsDir = URL(fileURLWithPath: "/Users/marvinbarsal/Desktop/Universität/Stats/ExtractedQuestions")

        guard let files = try? FileManager.default.contentsOfDirectory(at: questionsDir, includingPropertiesForKeys: nil) else {
            print("   ❌ No questions directory found")
            return
        }

        let jsonFiles = files.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        print("   Found \(jsonFiles.count) JSON files to process")

        for fileURL in jsonFiles {
            print("\n   📄 Processing: \(fileURL.lastPathComponent)")

            guard let data = try? Data(contentsOf: fileURL) else {
                print("      ❌ Failed to read file")
                continue
            }

            // Parse existing file
            guard var questionFile = try? JSONDecoder().decode(QuestionFileManager.QuestionFile.self, from: data) else {
                print("      ❌ Failed to decode JSON")
                continue
            }

            var updated = false

            for i in 0..<questionFile.questions.count {
                // Skip if already has correct answer
                if questionFile.questions[i].correctAnswer != nil {
                    print("      Q\(questionFile.questions[i].index): Already has answer (\(questionFile.questions[i].correctAnswer!))")
                    continue
                }

                let entry = questionFile.questions[i]

                // Get correct answer from OpenAI
                print("      Q\(entry.index): Analyzing '\(String(entry.question.prefix(40)))...'")

                if let answer = try? await visionAIService.getCorrectAnswer(
                    for: entry.question,
                    with: entry.answers
                ) {
                    questionFile.questions[i].correctAnswer = answer
                    updated = true
                    print("      Q\(entry.index): ✅ Correct answer = \(answer)")
                } else {
                    print("      Q\(entry.index): ⚠️ Could not determine answer")
                }

                // Small delay to avoid rate limiting
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }

            // Save updated file if changes were made
            if updated {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

                if let updatedData = try? encoder.encode(questionFile) {
                    do {
                        try updatedData.write(to: fileURL)
                        print("      ✅ Saved updated file")
                    } catch {
                        print("      ❌ Failed to save: \(error)")
                    }
                }
            } else {
                print("      ℹ️ No changes needed")
            }
        }

        print("\n" + String(repeating: "=", count: 60))
        print("✅ MIGRATION COMPLETE!")
        print(String(repeating: "=", count: 60))
    }
}

// MARK: - HTTP Server Delegate
extension QuizIntegrationManager: QuizHTTPServerDelegate {
    func didReceiveAnswers(_ answers: [Int]) {
        print("📨 Integration Manager received answers: \(answers)")
        triggerQuiz(with: answers)
    }
}

// MARK: - TextInjectionEngineDelegate

extension QuizIntegrationManager: TextInjectionEngineDelegate {
    func injectionDidStart() {
        print("✅ [QuizIntegration] Text injection started")
    }

    func injectionDidComplete() {
        print("✅ [QuizIntegration] Text injection completed")
    }

    func injectionDidCancel() {
        print("⚠️ [QuizIntegration] Text injection cancelled by user (ESC)")
    }

    func injectionDidFail(error: TextInjectionError) {
        print("❌ [QuizIntegration] Text injection failed: \(error.localizedDescription)")
        showAlert(
            title: "Injection Failed",
            message: "Text injection failed: \(error.localizedDescription)"
        )
    }

    func injectionProgress(current: Int, total: Int) {
        // Optional: Update UI with progress
        // print("[QuizIntegration] Injection progress: \(current)/\(total)")
    }
}

// MARK: - Display Value Publisher
extension QuizIntegrationManager {
    /**
     * Get current display value as observable
     */
    var displayValuePublisher: AnyPublisher<Int, Never> {
        $currentDisplayValue.eraseToAnyPublisher()
    }

    /**
     * Get animation state as observable
     */
    var animatingPublisher: AnyPublisher<Bool, Never> {
        $isAnimating.eraseToAnyPublisher()
    }
}
