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
import UserNotifications
import GPU

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
    private let keyboardManager = KeyboardShortcutManager(triggerKey: "z")
    private var cancellables = Set<AnyCancellable>()

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
        print("🔧 [QuizIntegration] Step 1: Requesting notification permissions...")

        // Request notification permissions
        requestNotificationPermissions()

        print("🔧 [QuizIntegration] Step 2: Setting up delegates...")
        httpServer.delegate = self
        keyboardManager.delegate = self
        print("   ✓ HTTP server delegate set")
        print("   ✓ Keyboard manager delegate set")

        print("🔧 [QuizIntegration] Step 3: Starting HTTP server...")
        httpServer.startServer()

        print("🔧 [QuizIntegration] Step 4: Registering keyboard shortcut...")
        keyboardManager.registerGlobalShortcut()

        print("🔧 [QuizIntegration] Step 5: Starting AI Filter Service...")
        startAIFilterService()

        print("🔧 [QuizIntegration] Step 6: Subscribing to animation updates...")
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
     * Request notification permissions (required for UserNotifications framework)
     */
    private func requestNotificationPermissions() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("✓ Notification permissions granted")
            } else if let error = error {
                print("⚠️  Notification permission error: \(error.localizedDescription)")
            } else {
                print("⚠️  Notification permissions denied")
            }
        }
    }

    /**
     * Show notification using modern UserNotifications framework
     * @param title - Notification title
     * @param body - Notification body text
     */
    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // Create a unique identifier for the notification
        let identifier = UUID().uuidString

        // Create trigger (immediate delivery)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)

        // Create request
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        // Schedule notification
        let center = UNUserNotificationCenter.current()
        center.add(request) { error in
            if let error = error {
                print("⚠️  Failed to show notification: \(error.localizedDescription)")
            }
        }
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
            showNotification(
                title: "AI Filter Error",
                body: "AI Filter script not found at: \(aiFilterPath)"
            )
            return
        }

        // Security Fix (Code Review): Use consolidated node path detection
        guard let nodePath = findNodeExecutable() else {
            print("❌ [AIFilter] Node.js not found in standard locations")
            showNotification(
                title: "AI Filter Error",
                body: "Node.js not installed. Please install Node.js first."
            )
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

            self?.aiFilterProcess = nil
            self?.isAIFilterRunning = false
        }

        do {
            try task.run()
            isAIFilterRunning = true
            print("✅ [AIFilter] AI Filter Service launched successfully")
            print("   Running on port 3001 (Ollama integration)")
        } catch {
            print("❌ [AIFilter] Failed to launch AI Filter Service: \(error.localizedDescription)")
            showNotification(
                title: "AI Filter Error",
                body: "Failed to launch AI Filter Service: \(error.localizedDescription)"
            )
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
            showNotification(
                title: "Quiz Scraper Error",
                body: "Invalid URL format. Only HTTP/HTTPS URLs are allowed."
            )
            isScraperRunning = false
            return
        }

        // Security Fix #3: Validate scraper exists
        guard FileManager.default.fileExists(atPath: scraperPath) else {
            print("❌ Scraper not found at: \(scraperPath)")
            showNotification(
                title: "Quiz Scraper Error",
                body: "Scraper script not found at: \(scraperPath)"
            )
            isScraperRunning = false
            return
        }

        // Security Fix (Code Review): Use consolidated node path detection
        guard let nodePath = findNodeExecutable() else {
            print("❌ Node.js not found in standard locations")
            showNotification(
                title: "Quiz Scraper Error",
                body: "Node.js not installed. Please install Node.js first."
            )
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

        // Security Fix #1: Pass URL as argument to prevent command injection
        task.arguments = [
            scraperPath,     // Script to run
            "--url=\(url)"   // Combined flag and value as scraper expects
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

            self?.scraperProcess = nil
            self?.isScraperRunning = false  // Reset flag
        }

        do {
            try task.run()
            print("✅ Scraper launched successfully")
        } catch {
            print("❌ Failed to launch scraper: \(error.localizedDescription)")
            showNotification(
                title: "Quiz Scraper Error",
                body: "Failed to launch scraper: \(error.localizedDescription)"
            )
            scraperProcess = nil
            isScraperRunning = false  // Reset flag
        }
    }
}

// MARK: - Keyboard Shortcut Delegate
extension QuizIntegrationManager: KeyboardShortcutDelegate {
    func keyboardShortcutTriggered() {
        print("\n" + String(repeating: "=", count: 60))
        print("🎯 [QuizIntegration] KEYBOARD SHORTCUT TRIGGERED!")
        print(String(repeating: "=", count: 60))
        print("⌨️  Keyboard shortcut triggered!")
        print("🚀 Triggering scraper and quiz workflow...")

        // Security Fix #5: Prevent multiple simultaneous invocations
        guard !isScraperRunning else {
            print("⚠️  Scraper already running, ignoring duplicate trigger")
            showNotification(
                title: "Quiz Scraper",
                body: "Scraper is already running. Please wait."
            )
            return
        }

        isScraperRunning = true

        // Get current browser URL
        guard let url = getCurrentBrowserURL() else {
            print("❌ Could not get current browser URL")
            showNotification(
                title: "Quiz Scraper Error",
                body: "Could not detect browser URL. Please ensure Chrome or Safari is open."
            )
            isScraperRunning = false  // Reset flag
            return
        }

        print("✓ Detected URL: \(url)")

        // Security Fix #2: Validate URL before launching scraper
        guard validateURL(url) else {
            print("❌ URL validation failed: \(url)")
            showNotification(
                title: "Quiz Scraper Error",
                body: "URL validation failed. Only HTTP/HTTPS URLs are allowed."
            )
            isScraperRunning = false  // Reset flag
            return
        }

        // Show notification
        showNotification(
            title: "Quiz Scraper",
            body: "Analyzing webpage: \(url)"
        )

        // Launch scraper with URL
        launchScraper(url: url)

        // The scraper will:
        // 1. Extract quiz questions from webpage
        // 2. Send to AI parser (port 3001)
        // 3. AI parser sends to backend (port 3000)
        // 4. Backend sends answers via HTTP to QuizHTTPServer (port 8080)
        // 5. HTTP server triggers triggerQuiz()
    }
}

// MARK: - HTTP Server Delegate
extension QuizIntegrationManager: QuizHTTPServerDelegate {
    func didReceiveAnswers(_ answers: [Int]) {
        print("📨 Integration Manager received answers: \(answers)")
        triggerQuiz(with: answers)
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
