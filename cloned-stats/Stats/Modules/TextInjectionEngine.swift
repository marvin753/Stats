import Cocoa
import Carbon.HIToolbox

// MARK: - Debug Logging System

/// Centralized debug logging for text injection
final class TextInjectionDebug {
    static let shared = TextInjectionDebug()

    private let logQueue = DispatchQueue(label: "com.stats.injection.debug", qos: .utility)
    private var logBuffer: [String] = []
    private let maxBufferSize = 1000

    /// Enable/disable verbose logging
    var isVerbose: Bool = true

    private init() {}

    /// Log a debug message with timestamp
    static func log(_ message: String, file: String = #file, line: Int = #line) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(timestamp)] [TextInjection:\(fileName):\(line)] \(message)"

        // Always print to console
        print(logMessage)

        // Buffer for file logging
        shared.logQueue.async {
            shared.logBuffer.append(logMessage)
            if shared.logBuffer.count > shared.maxBufferSize {
                shared.logBuffer.removeFirst(shared.logBuffer.count - shared.maxBufferSize)
            }
        }
    }

    /// Log with specific category
    static func log(_ category: LogCategory, _ message: String) {
        let prefix: String
        switch category {
        case .event: prefix = "📥 EVENT"
        case .swallow: prefix = "🚫 SWALLOW"
        case .inject: prefix = "💉 INJECT"
        case .progress: prefix = "📊 PROGRESS"
        case .error: prefix = "❌ ERROR"
        case .state: prefix = "🔄 STATE"
        case .cleanup: prefix = "🧹 CLEANUP"
        }
        log("\(prefix): \(message)")
    }

    enum LogCategory {
        case event, swallow, inject, progress, error, state, cleanup
    }

    /// Get recent logs
    func getRecentLogs(count: Int = 100) -> [String] {
        logQueue.sync {
            return Array(logBuffer.suffix(count))
        }
    }

    /// Save logs to file
    func saveLogs(to path: String) {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            let content = self.logBuffer.joined(separator: "\n")
            try? content.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
}

/// Error types for text injection
enum TextInjectionError: Error, LocalizedError {
    case eventTapCreationFailed
    case systemDisabledTap
    case permissionDenied
    case noSolutionText
    case injectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .eventTapCreationFailed:
            return "Failed to create event tap - check Accessibility permissions"
        case .systemDisabledTap:
            return "Event tap was disabled by the system"
        case .permissionDenied:
            return "Accessibility or Input Monitoring permission denied"
        case .noSolutionText:
            return "Solution text is empty"
        case .injectionFailed(let reason):
            return "Character injection failed: \(reason)"
        }
    }
}

/// Delegate protocol for injection events
protocol TextInjectionEngineDelegate: AnyObject {
    func injectionDidStart()
    func injectionDidComplete()
    func injectionDidCancel()
    func injectionDidFail(error: TextInjectionError)
    func injectionProgress(current: Int, total: Int)
}

/// Extension for optional delegate methods
extension TextInjectionEngineDelegate {
    func injectionProgress(current: Int, total: Int) {}
    func injectionDidFail(error: TextInjectionError) {}
}

/// Notification names for injection events
extension Notification.Name {
    static let injectionCancelled = Notification.Name("TextInjectionCancelled")
    static let injectionCompleted = Notification.Name("TextInjectionCompleted")
}

/// Core text injection engine using CGEventTap
/// Intercepts user keystrokes and replaces them with solution text characters
final class TextInjectionEngine {

    // MARK: - Singleton
    static let shared = TextInjectionEngine()

    // MARK: - Delegate
    weak var delegate: TextInjectionEngineDelegate?

    // MARK: - Event Tap Properties
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // MARK: - Injection State
    private var solutionText: String = ""
    private var solutionCharacters: [Character] = []
    private var currentCharIndex: Int = 0
    private var isActive: Bool = false
    private var shouldAbort: Bool = false

    // MARK: - Statistics
    private var injectionStartTime: CFAbsoluteTime = 0
    private var successfulInjections: Int = 0
    private var failedInjections: Int = 0

    // MARK: - Safeguard 1: Recovery
    private var recoveryAttempts: Int = 0
    private let maxRecoveryAttempts: Int = 3

    // MARK: - Safeguard 2: Rapid Typing Protection
    private var pendingKeystrokes: Int = 0
    private let maxPendingKeystrokes: Int = 5

    // MARK: - Safeguard 8: Adaptive Delay
    private var currentDelayMicroseconds: UInt32 = 8_000  // Start at 8ms
    private var consecutiveDrops: Int = 0
    private var lastInjectionTime: CFAbsoluteTime = 0
    private let minDelay: UInt32 = 3_000   // 3ms minimum
    private let maxDelay: UInt32 = 15_000  // 15ms maximum (not 50ms - would cause rejection)

    // MARK: - Initialization

    private init() {
        TextInjectionDebug.log(.state, "TextInjectionEngine initialized")
    }

    // MARK: - Public Methods

    /// Start text injection with the given solution text
    func startInjection(with solution: String) {
        TextInjectionDebug.log(.state, "startInjection() called")
        TextInjectionDebug.log(.state, "Solution length: \(solution.count) characters")

        // Diagnostic #1: Verify solution is not empty
        guard !solution.isEmpty else {
            TextInjectionDebug.log(.error, "DIAGNOSTIC #1 FAIL: Solution text is EMPTY!")
            delegate?.injectionDidFail(error: .noSolutionText)
            return
        }
        TextInjectionDebug.log(.state, "DIAGNOSTIC #1 PASS: Solution text has \(solution.count) characters")

        // Diagnostic #2: Print solution length
        TextInjectionDebug.log(.progress, "DIAGNOSTIC #2: Solution preview: \"\(String(solution.prefix(100)))...\"")

        guard !isActive else {
            TextInjectionDebug.log(.error, "Already active - ignoring start request")
            return
        }

        // Store solution
        solutionText = solution
        solutionCharacters = Array(solution)
        currentCharIndex = 0
        isActive = true
        shouldAbort = false
        recoveryAttempts = 0
        pendingKeystrokes = 0
        currentDelayMicroseconds = 8_000
        consecutiveDrops = 0
        successfulInjections = 0
        failedInjections = 0
        injectionStartTime = CFAbsoluteTimeGetCurrent()

        TextInjectionDebug.log(.state, "State initialized:")
        TextInjectionDebug.log(.state, "  - solutionCharacters.count = \(solutionCharacters.count)")
        TextInjectionDebug.log(.state, "  - currentCharIndex = \(currentCharIndex)")
        TextInjectionDebug.log(.state, "  - isActive = \(isActive)")

        // Create event tap
        guard createEventTap() else {
            TextInjectionDebug.log(.error, "Failed to create event tap")
            cleanup()
            delegate?.injectionDidFail(error: .eventTapCreationFailed)
            return
        }

        delegate?.injectionDidStart()
        TextInjectionDebug.log(.state, "✅ Injection READY - press any key to inject characters, ESC to cancel")
        TextInjectionDebug.log(.state, "Waiting for keystrokes...")
    }

    /// Cancel the current injection
    func cancel() {
        guard isActive else { return }
        TextInjectionDebug.log(.state, "Cancellation requested")
        emergencyStop()
    }

    // MARK: - Event Tap Creation (Safeguard 9: .commonModes)

    private func createEventTap() -> Bool {
        TextInjectionDebug.log(.state, "Creating event tap...")

        // Event mask for keyDown only (NOT keyUp - we only need to intercept keyDown)
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        TextInjectionDebug.log(.state, "Event mask: keyDown only")

        // Get pointer to self for callback
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        // Diagnostic #13: Create event tap with .cgSessionEventTap and .defaultTap
        TextInjectionDebug.log(.state, "DIAGNOSTIC #13: Creating tap with .cgSessionEventTap, .defaultTap")

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,        // Diagnostic #13: Session level tap
            place: .headInsertEventTap,
            options: .defaultTap,           // Diagnostic #13: NOT .listenOnly - we need to consume events
            eventsOfInterest: CGEventMask(eventMask),
            callback: TextInjectionEngine.eventTapCallback,
            userInfo: selfPtr
        ) else {
            TextInjectionDebug.log(.error, "DIAGNOSTIC #13 FAIL: Failed to create event tap!")
            TextInjectionDebug.log(.error, "Check Accessibility permissions in System Preferences")
            return false
        }

        TextInjectionDebug.log(.state, "DIAGNOSTIC #13 PASS: Event tap created successfully")

        self.eventTap = tap

        // Diagnostic #14: Add to main run loop with .commonModes
        TextInjectionDebug.log(.state, "DIAGNOSTIC #14: Adding to main run loop with .commonModes")

        guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            TextInjectionDebug.log(.error, "DIAGNOSTIC #14 FAIL: Failed to create run loop source")
            return false
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        self.runLoopSource = runLoopSource

        TextInjectionDebug.log(.state, "DIAGNOSTIC #14 PASS: Run loop source added to main run loop")

        // Enable the tap
        CGEvent.tapEnable(tap: tap, enable: true)
        TextInjectionDebug.log(.state, "Event tap ENABLED")

        return true
    }

    // MARK: - Event Tap Callback

    private static let eventTapCallback: CGEventTapCallBack = { proxy, type, event, refcon in
        guard let refcon = refcon else {
            return Unmanaged.passUnretained(event)
        }

        let engine = Unmanaged<TextInjectionEngine>.fromOpaque(refcon).takeUnretainedValue()
        return engine.handleEvent(proxy: proxy, type: type, event: event)
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {

        // Diagnostic #4: Log that event tap callback was triggered
        TextInjectionDebug.log(.event, "DIAGNOSTIC #4: Event tap callback triggered, type=\(type.rawValue)")

        // Safeguard 1: Handle system-initiated tap disable
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            TextInjectionDebug.log(.error, "Event tap disabled by system! type=\(type.rawValue)")
            handleSystemDisable()
            return Unmanaged.passUnretained(event)
        }

        // Only process keyDown events
        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        TextInjectionDebug.log(.event, "DIAGNOSTIC #4 PASS: Received keyDown event")

        // Check if we should abort
        guard isActive && !shouldAbort else {
            TextInjectionDebug.log(.state, "Not active or should abort - passing through event")
            return Unmanaged.passUnretained(event)
        }

        // Safeguard 7: Filter key repeats
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat)
        if isRepeat != 0 {
            TextInjectionDebug.log(.event, "DIAGNOSTIC #7: Ignoring key repeat event")
            return nil  // Swallow repeat but don't inject
        }

        // Get key code
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        TextInjectionDebug.log(.event, "Key code: \(keyCode)")

        // Safeguard 6: ESC handling
        if keyCode == Int64(kVK_Escape) {  // 53
            TextInjectionDebug.log(.state, "DIAGNOSTIC #6: ESC pressed - emergency stop")
            DispatchQueue.main.async { [weak self] in
                self?.emergencyStop()
            }
            return nil  // Swallow ESC
        }

        // Safeguard 2: Rapid typing protection
        pendingKeystrokes += 1
        if pendingKeystrokes > maxPendingKeystrokes {
            TextInjectionDebug.log(.error, "DIAGNOSTIC #2: Dropping keystroke - buffer overflow protection")
            pendingKeystrokes = maxPendingKeystrokes
            return nil  // Swallow but don't inject
        }

        // Diagnostic #3: Check currentCharIndex
        TextInjectionDebug.log(.progress, "DIAGNOSTIC #3: currentCharIndex=\(currentCharIndex), total=\(solutionCharacters.count)")

        // Diagnostic #10: Verify currentCharIndex is not being reset
        if currentCharIndex == 0 && successfulInjections > 0 {
            TextInjectionDebug.log(.error, "DIAGNOSTIC #10 WARNING: currentCharIndex was reset to 0 after \(successfulInjections) injections!")
        }

        // Check if we have more characters to inject
        guard currentCharIndex < solutionCharacters.count else {
            TextInjectionDebug.log(.state, "All characters injected - completing")
            DispatchQueue.main.async { [weak self] in
                self?.completeInjection()
            }
            return nil
        }

        // Get next character
        let char = solutionCharacters[currentCharIndex]
        TextInjectionDebug.log(.inject, "DIAGNOSTIC #5: About to inject character[\(currentCharIndex)]: '\(char)' (remaining: \(solutionCharacters.count - currentCharIndex - 1))")

        // Diagnostic #5 & #6: Inject character synchronously and return nil
        let injectionSuccess = injectCharacterSynchronous(char)

        if injectionSuccess {
            // Diagnostic #3: Increment currentCharIndex
            currentCharIndex += 1
            successfulInjections += 1
            TextInjectionDebug.log(.inject, "DIAGNOSTIC #3: currentCharIndex incremented to \(currentCharIndex)")

            pendingKeystrokes = max(0, pendingKeystrokes - 1)

            // Report progress asynchronously (doesn't affect injection)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.injectionProgress(current: self.currentCharIndex, total: self.solutionCharacters.count)
            }

            // Check if complete
            if currentCharIndex >= solutionCharacters.count {
                TextInjectionDebug.log(.state, "Injection complete after \(successfulInjections) characters")
                DispatchQueue.main.async { [weak self] in
                    self?.completeInjection()
                }
            }
        } else {
            failedInjections += 1
            TextInjectionDebug.log(.error, "Character injection FAILED for '\(char)'")
        }

        // Diagnostic #5: Return nil to swallow the original keystroke
        TextInjectionDebug.log(.swallow, "DIAGNOSTIC #5: Returning nil to swallow original keystroke")
        return nil
    }

    // MARK: - Character Injection (FIXED)

    /// Inject a character SYNCHRONOUSLY - called directly from event tap callback
    /// Diagnostic #6: This must be synchronous, not async
    private func injectCharacterSynchronous(_ char: Character) -> Bool {
        TextInjectionDebug.log(.inject, "injectCharacterSynchronous() called for '\(char)'")

        // Diagnostic #9: Create CGEventSource with .privateState (NOT .hidSystemState)
        // Using .privateState avoids conflicts with the system HID state
        guard let source = CGEventSource(stateID: .privateState) else {
            TextInjectionDebug.log(.error, "DIAGNOSTIC #9 FAIL: Failed to create CGEventSource with .privateState")
            return false
        }
        TextInjectionDebug.log(.inject, "DIAGNOSTIC #9 PASS: CGEventSource created with .privateState")

        var success = false

        // Handle special characters
        if char == "\n" || char == "\r" {
            TextInjectionDebug.log(.inject, "Injecting RETURN key")
            success = injectVirtualKey(kVK_Return, source: source)
        } else if char == "\t" {
            TextInjectionDebug.log(.inject, "Injecting TAB key")
            success = injectVirtualKey(kVK_Tab, source: source)
        } else if char == " " {
            TextInjectionDebug.log(.inject, "Injecting SPACE key")
            success = injectVirtualKey(kVK_Space, source: source)
        } else {
            // Regular character via Unicode
            TextInjectionDebug.log(.inject, "Injecting Unicode character: '\(char)'")
            success = injectUnicodeCharacter(char, source: source)
        }

        // Diagnostic #12: Check adaptive delay is not too high
        if currentDelayMicroseconds > 15_000 {
            TextInjectionDebug.log(.error, "DIAGNOSTIC #12 WARNING: Delay is \(currentDelayMicroseconds)μs which is too high!")
            currentDelayMicroseconds = 10_000  // Reset to reasonable value
        }

        // Apply minimal delay AFTER injection (not blocking the callback too long)
        // Use a very short delay to allow system to process the event
        usleep(currentDelayMicroseconds)
        lastInjectionTime = CFAbsoluteTimeGetCurrent()

        return success
    }

    /// Inject a virtual key (for special keys like Return, Tab, Space)
    private func injectVirtualKey(_ keyCode: Int, source: CGEventSource) -> Bool {
        // Create key down event
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true) else {
            TextInjectionDebug.log(.error, "Failed to create keyDown event for virtualKey \(keyCode)")
            return false
        }

        // Create key up event
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: false) else {
            TextInjectionDebug.log(.error, "Failed to create keyUp event for virtualKey \(keyCode)")
            return false
        }

        // CRITICAL FIX: Post to .cgAnnotatedSessionEventTap to bypass our own event tap
        // Using .cgSessionEventTap causes infinite loop (our tap catches its own events)
        // .cgAnnotatedSessionEventTap bypasses event taps and goes directly to the target app
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)

        TextInjectionDebug.log(.inject, "Posted virtualKey \(keyCode) to .cgAnnotatedSessionEventTap (bypass event tap)")
        return true
    }

    /// Inject a Unicode character
    /// Diagnostic #9: Uses proper Unicode string injection without conflicting virtualKey
    private func injectUnicodeCharacter(_ char: Character, source: CGEventSource) -> Bool {
        let charString = String(char)
        var utf16Array = Array(charString.utf16)

        TextInjectionDebug.log(.inject, "DIAGNOSTIC #9: Injecting Unicode, utf16 length=\(utf16Array.count)")

        // Create key down event with a neutral virtual key
        // Using kVK_ANSI_A (0) as base but immediately setting Unicode string
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else {
            TextInjectionDebug.log(.error, "DIAGNOSTIC #9 FAIL: Failed to create keyDown event")
            return false
        }

        // CRITICAL: Set the Unicode string BEFORE posting
        keyDown.keyboardSetUnicodeString(stringLength: utf16Array.count, unicodeString: &utf16Array)

        // Create key up event (no need for Unicode on key up)
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            TextInjectionDebug.log(.error, "Failed to create keyUp event")
            return false
        }

        // CRITICAL FIX: Post to .cgAnnotatedSessionEventTap to bypass our own event tap
        // Using .cgSessionEventTap causes infinite loop (our tap catches its own events)
        // .cgAnnotatedSessionEventTap bypasses event taps and goes directly to the target app
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)

        TextInjectionDebug.log(.inject, "DIAGNOSTIC #9 PASS: Posted Unicode '\(char)' to .cgAnnotatedSessionEventTap (bypass event tap)")
        return true
    }

    // MARK: - Safeguard 1: System Disable Recovery

    private func handleSystemDisable() {
        recoveryAttempts += 1
        TextInjectionDebug.log(.error, "Recovery attempt \(recoveryAttempts)/\(maxRecoveryAttempts)")

        if recoveryAttempts > maxRecoveryAttempts {
            TextInjectionDebug.log(.error, "Max recovery attempts exceeded - forcing cleanup")
            DispatchQueue.main.async { [weak self] in
                self?.forceCleanup()
                self?.delegate?.injectionDidFail(error: .systemDisabledTap)
            }
            return
        }

        // Try to re-enable the tap
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
            TextInjectionDebug.log(.state, "Event tap re-enabled")
        }
    }

    // MARK: - Safeguard 6: Emergency Stop

    private func emergencyStop() {
        TextInjectionDebug.log(.state, "🛑 Emergency stop initiated")

        // 1. Set flags immediately
        isActive = false
        shouldAbort = true

        // 2. Log statistics
        TextInjectionDebug.log(.state, "Statistics: \(successfulInjections) successful, \(failedInjections) failed")

        // 3. Reset state
        solutionText = ""
        solutionCharacters = []
        currentCharIndex = 0
        pendingKeystrokes = 0

        // 4. Immediately disable event tap
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        // 5. Full cleanup
        cleanup()

        // 6. Notify delegate
        delegate?.injectionDidCancel()

        // 7. Post notification for UI
        NotificationCenter.default.post(name: .injectionCancelled, object: nil)

        TextInjectionDebug.log(.state, "✅ Emergency stop complete - keyboard restored")
    }

    // MARK: - Injection Complete

    private func completeInjection() {
        // Diagnostic #11: Check cleanup is not called prematurely
        guard isActive else {
            TextInjectionDebug.log(.error, "DIAGNOSTIC #11: completeInjection called but isActive=false!")
            return
        }

        let duration = CFAbsoluteTimeGetCurrent() - injectionStartTime
        TextInjectionDebug.log(.state, "✅ Injection COMPLETE")
        TextInjectionDebug.log(.state, "  - Characters injected: \(currentCharIndex)")
        TextInjectionDebug.log(.state, "  - Successful: \(successfulInjections)")
        TextInjectionDebug.log(.state, "  - Failed: \(failedInjections)")
        TextInjectionDebug.log(.state, "  - Duration: \(String(format: "%.2f", duration))s")

        isActive = false
        cleanup()
        delegate?.injectionDidComplete()
        NotificationCenter.default.post(name: .injectionCompleted, object: nil)
    }

    // MARK: - Force Cleanup

    private func forceCleanup() {
        isActive = false
        shouldAbort = true
        cleanup()
    }

    // MARK: - Safeguard 12: Memory Safety & Cleanup

    private func cleanup() {
        TextInjectionDebug.log(.cleanup, "Starting cleanup...")

        // 1. Disable tap first (prevents new events)
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            TextInjectionDebug.log(.cleanup, "Event tap disabled")
        }

        // 2. Remove from run loop
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
            TextInjectionDebug.log(.cleanup, "RunLoop source removed")
        }

        // 3. Invalidate mach port
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
            self.eventTap = nil
            TextInjectionDebug.log(.cleanup, "Mach port invalidated")
        }

        // 4. Reset all state
        solutionText = ""
        solutionCharacters = []
        currentCharIndex = 0
        pendingKeystrokes = 0
        isActive = false
        shouldAbort = false
        recoveryAttempts = 0
        currentDelayMicroseconds = 8_000
        consecutiveDrops = 0
        lastInjectionTime = 0

        // 5. Verify cleanup (Diagnostic #11)
        if eventTap != nil {
            TextInjectionDebug.log(.error, "DIAGNOSTIC #11 FAIL: Event tap not properly cleaned up!")
        }
        if runLoopSource != nil {
            TextInjectionDebug.log(.error, "DIAGNOSTIC #11 FAIL: RunLoop source not properly cleaned up!")
        }

        TextInjectionDebug.log(.cleanup, "✅ Cleanup complete - all resources freed")
    }

    // MARK: - Deinit Safety Net

    deinit {
        if eventTap != nil || runLoopSource != nil {
            TextInjectionDebug.log(.error, "deinit called with active resources - forcing cleanup")
            cleanup()
        }
    }

    // MARK: - Debug Helpers

    /// Get current injection state for debugging
    func getDebugState() -> [String: Any] {
        return [
            "isActive": isActive,
            "shouldAbort": shouldAbort,
            "currentCharIndex": currentCharIndex,
            "totalCharacters": solutionCharacters.count,
            "successfulInjections": successfulInjections,
            "failedInjections": failedInjections,
            "pendingKeystrokes": pendingKeystrokes,
            "currentDelayMicroseconds": currentDelayMicroseconds,
            "hasEventTap": eventTap != nil,
            "hasRunLoopSource": runLoopSource != nil
        ]
    }
}
