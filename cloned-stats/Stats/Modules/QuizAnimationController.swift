/**
 * Quiz Animation Controller
 * Handles the animation logic for displaying quiz answer numbers
 *
 * Animation Sequence:
 * 1. For each answer number in the list:
 *    - Animate from 0 → answer_number (smooth)
 *    - Display for 7 seconds
 *    - Animate back to 0
 *    - Display 0 for 15 seconds
 * 2. After all answers shown:
 *    - Animate to 10
 *    - Display 10 for 15 seconds
 *    - Stop (do not restart until triggered again)
 */

import Cocoa
import Combine

class QuizAnimationController: NSObject, ObservableObject {

    // MARK: - Published Properties
    @Published var currentNumber: Int = 0
    @Published var isAnimating: Bool = false
    @Published var progress: Double = 0.0

    // MARK: - Private Properties
    private var animationTimer: Timer?
    private var displayTimer: Timer?
    private var answerIndices: [Int] = []
    private var currentAnswerIndex: Int = 0
    private var isRunning: Bool = false

    // Animation timing
    private let animationDuration: TimeInterval = 1.5 // 1.5 seconds to animate
    private let displayDuration: TimeInterval = 10.0  // 10 seconds to display answer (changed from 7s)
    private let restDuration: TimeInterval = 15.0     // 15 seconds at 0
    private let finalDisplayDuration: TimeInterval = 15.0 // 15 seconds at 10

    // MARK: - Animation States
    private enum AnimationState {
        case animatingUp(from: Int, to: Int, startTime: Date)
        case displayingAnswer(targetNumber: Int, startTime: Date)
        case animatingDown(from: Int, to: Int, startTime: Date)
        case resting(startTime: Date)
        case animatingToFinal(from: Int, startTime: Date)
        case displayingFinal(startTime: Date)
        case complete
    }

    private var currentState: AnimationState = .complete

    // MARK: - Initialization
    override init() {
        super.init()
    }

    // MARK: - Public Methods

    /**
     * Start animation with answer indices
     * @param answerIndices: Array of correct answer numbers (1-indexed)
     */
    func startAnimation(with answerIndices: [Int]) {
        print("🎬 Starting quiz animation with answers: \(answerIndices)")

        guard !isRunning && !answerIndices.isEmpty else {
            print("⚠️  Animation already running or no answers provided")
            return
        }

        self.answerIndices = answerIndices
        self.currentAnswerIndex = 0
        self.isRunning = true
        self.currentNumber = 0

        // Start the animation sequence
        animateToNextAnswer()
    }

    /**
     * Stop animation immediately
     */
    func stopAnimation() {
        print("⛔ Stopping quiz animation")

        isRunning = false
        currentAnswerIndex = 0
        answerIndices.removeAll()

        stopAllTimers()

        DispatchQueue.main.async {
            self.currentNumber = 0
            self.currentState = .complete
            self.isAnimating = false
        }
    }

    // MARK: - Private Methods

    /**
     * Animate to the next answer in the sequence
     */
    private func animateToNextAnswer() {
        guard currentAnswerIndex < answerIndices.count else {
            // All answers shown, animate to 10 for final display
            print("✅ All answers shown, animating to final display (10)")
            animateToFinal()
            return
        }

        let targetAnswer = answerIndices[currentAnswerIndex]
        print("→ Animating to answer #\(currentAnswerIndex + 1): \(targetAnswer)")

        currentState = .animatingUp(from: currentNumber, to: targetAnswer, startTime: Date())
        startAnimatingUp(to: targetAnswer)
    }

    /**
     * Animate from current value up to target
     */
    private func startAnimatingUp(to target: Int) {
        DispatchQueue.main.async {
            self.isAnimating = true
        }

        let startTime = Date()
        let fromValue = currentNumber

        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / self.animationDuration, 1.0)

            let currentValue = Int(Double(fromValue) + Double(target - fromValue) * progress)

            DispatchQueue.main.async {
                self.currentNumber = currentValue
                self.progress = progress
            }

            // Check if animation complete
            if progress >= 1.0 {
                self.animationTimer?.invalidate()
                self.animationTimer = nil

                DispatchQueue.main.async {
                    self.currentNumber = target
                    self.isAnimating = false
                }

                // Display answer for 7 seconds
                self.displayAnswer(target)
            }
        }
    }

    /**
     * Display answer at target value for configured duration
     */
    private func displayAnswer(_ target: Int) {
        print("⏸️  Displaying answer: \(target) for \(displayDuration) seconds")
        currentState = .displayingAnswer(targetNumber: target, startTime: Date())

        displayTimer = Timer.scheduledTimer(withTimeInterval: displayDuration, repeats: false) { [weak self] _ in
            self?.displayTimer?.invalidate()
            self?.displayTimer = nil

            // Animate back down to 0
            self?.startAnimatingDown(from: target)
        }
    }

    /**
     * Animate from current value down to 0
     */
    private func startAnimatingDown(from current: Int) {
        print("↓ Animating back down to 0 from \(current)")
        currentState = .animatingDown(from: current, to: 0, startTime: Date())

        DispatchQueue.main.async {
            self.isAnimating = true
        }

        let startTime = Date()

        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / self.animationDuration, 1.0)

            let currentValue = Int(Double(current) * (1.0 - progress))

            DispatchQueue.main.async {
                self.currentNumber = currentValue
                self.progress = 1.0 - progress
            }

            // Check if animation complete
            if progress >= 1.0 {
                self.animationTimer?.invalidate()
                self.animationTimer = nil

                DispatchQueue.main.async {
                    self.currentNumber = 0
                    self.isAnimating = false
                }

                // Rest at 0 for 15 seconds
                self.restAtZero()
            }
        }
    }

    /**
     * Rest at 0 for 15 seconds before next answer
     */
    private func restAtZero() {
        print("⏸️  Resting at 0 for 15 seconds")
        currentState = .resting(startTime: Date())

        displayTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            self?.displayTimer?.invalidate()
            self?.displayTimer = nil

            // Move to next answer
            self?.currentAnswerIndex += 1
            self?.animateToNextAnswer()
        }
    }

    /**
     * Animate to final value of 10
     */
    private func animateToFinal() {
        print("→ Animating to final value: 10")
        currentState = .animatingToFinal(from: currentNumber, startTime: Date())

        DispatchQueue.main.async {
            self.isAnimating = true
        }

        let startTime = Date()
        let fromValue = currentNumber

        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / self.animationDuration, 1.0)

            let currentValue = Int(Double(fromValue) + Double(10 - fromValue) * progress)

            DispatchQueue.main.async {
                self.currentNumber = currentValue
                self.progress = progress
            }

            // Check if animation complete
            if progress >= 1.0 {
                self.animationTimer?.invalidate()
                self.animationTimer = nil

                DispatchQueue.main.async {
                    self.currentNumber = 10
                    self.isAnimating = false
                }

                // Display 10 for 15 seconds, then stop
                self.displayFinal()
            }
        }
    }

    /**
     * Display final value (10) for 15 seconds
     */
    private func displayFinal() {
        print("⏸️  Displaying final value: 10 for 15 seconds")
        currentState = .displayingFinal(startTime: Date())

        displayTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            self?.displayTimer?.invalidate()
            self?.displayTimer = nil

            // Animation complete, reset to ready state
            print("✅ Quiz animation sequence complete")

            self?.isRunning = false
            DispatchQueue.main.async {
                self?.currentState = .complete
                // Keep displaying 10 or return to 0?
                // Based on requirements: "animate down to 0 and remain at 0"
                self?.currentNumber = 0
            }
        }
    }

    /**
     * Stop all running timers
     */
    private func stopAllTimers() {
        animationTimer?.invalidate()
        animationTimer = nil

        displayTimer?.invalidate()
        displayTimer = nil
    }

    // MARK: - Deinitialization
    deinit {
        stopAllTimers()
    }
}
