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
    private let keyboardManager = KeyboardShortcutManager(triggerKey: "q")
    private var cancellables = Set<AnyCancellable>()

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
        print("\n🎬 Initializing Quiz Integration Manager...")

        // Set up delegates
        httpServer.delegate = self
        keyboardManager.delegate = self

        // Start HTTP server
        httpServer.startServer()

        // Register keyboard shortcut
        keyboardManager.registerGlobalShortcut()

        // Subscribe to animation updates
        animationController.$currentNumber
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentDisplayValue)

        animationController.$isAnimating
            .receive(on: DispatchQueue.main)
            .assign(to: &$isAnimating)

        isEnabled = true
        print("✅ Quiz Integration Manager initialized")
    }

    /**
     * Shutdown all quiz systems
     */
    func shutdown() {
        print("\n🛑 Shutting down Quiz Integration Manager...")

        animationController.stopAnimation()
        httpServer.stopServer()
        keyboardManager.unregisterGlobalShortcut()

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
}

// MARK: - Keyboard Shortcut Delegate
extension QuizIntegrationManager: KeyboardShortcutDelegate {
    func keyboardShortcutTriggered() {
        print("⌨️  Keyboard shortcut triggered!")
        print("🚀 Triggering scraper and quiz workflow...")

        // This should trigger the scraper script
        // For now, we'll show a notification
        let notification = NSUserNotification()
        notification.title = "Quiz Scraper"
        notification.informativeText = "Starting webpage analysis..."
        NSUserNotificationCenter.default.deliver(notification)

        // The backend will send answers via HTTP to QuizHTTPServer
        // which will then trigger triggerQuiz()
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
