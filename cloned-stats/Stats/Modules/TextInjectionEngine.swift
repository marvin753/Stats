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

    // MARK: - HID Event Injection (R1, R5, R8)
    /// Tag to identify self-injected events (prevents reprocessing loops)
    /// "TEXTINJ\0" encoded as hex: 0x54455854494E4A00
    private static let injectedEventTag: Int64 = 0x54455854_494E4A00

    /// Persistent HID event source - created once per injection session (R1)
    /// macOS tracks HID state IDs; inconsistent source IDs cause event rejection
    private var hidEventSource: CGEventSource?

    /// Track if we have an unpaired KeyDown posted (R5)
    /// If cleanup/emergencyStop occurs, we must emit matching KeyUp to prevent stuck keys
    private var pendingKeyDown: Bool = false
    private var pendingKeyCode: CGKeyCode = 0

    // MARK: - Virtual Key Code Mapping (US ANSI Keyboard)
    /// Maps ASCII characters to (virtualKeyCode, requiresShift)
    /// Used to generate proper HID-level key events with correct keycodes
    private static let asciiToVirtualKey: [Character: (keyCode: Int, shift: Bool)] = [
        // Row 1: Numbers and their shifted symbols
        "1": (kVK_ANSI_1, false), "!": (kVK_ANSI_1, true),
        "2": (kVK_ANSI_2, false), "@": (kVK_ANSI_2, true),
        "3": (kVK_ANSI_3, false), "#": (kVK_ANSI_3, true),
        "4": (kVK_ANSI_4, false), "$": (kVK_ANSI_4, true),
        "5": (kVK_ANSI_5, false), "%": (kVK_ANSI_5, true),
        "6": (kVK_ANSI_6, false), "^": (kVK_ANSI_6, true),
        "7": (kVK_ANSI_7, false), "&": (kVK_ANSI_7, true),
        "8": (kVK_ANSI_8, false), "*": (kVK_ANSI_8, true),
        "9": (kVK_ANSI_9, false), "(": (kVK_ANSI_9, true),
        "0": (kVK_ANSI_0, false), ")": (kVK_ANSI_0, true),

        // Row 1 additional keys
        "-": (kVK_ANSI_Minus, false), "_": (kVK_ANSI_Minus, true),
        "=": (kVK_ANSI_Equal, false), "+": (kVK_ANSI_Equal, true),

        // Row 2: QWERTY
        "q": (kVK_ANSI_Q, false), "Q": (kVK_ANSI_Q, true),
        "w": (kVK_ANSI_W, false), "W": (kVK_ANSI_W, true),
        "e": (kVK_ANSI_E, false), "E": (kVK_ANSI_E, true),
        "r": (kVK_ANSI_R, false), "R": (kVK_ANSI_R, true),
        "t": (kVK_ANSI_T, false), "T": (kVK_ANSI_T, true),
        "y": (kVK_ANSI_Y, false), "Y": (kVK_ANSI_Y, true),
        "u": (kVK_ANSI_U, false), "U": (kVK_ANSI_U, true),
        "i": (kVK_ANSI_I, false), "I": (kVK_ANSI_I, true),
        "o": (kVK_ANSI_O, false), "O": (kVK_ANSI_O, true),
        "p": (kVK_ANSI_P, false), "P": (kVK_ANSI_P, true),
        "[": (kVK_ANSI_LeftBracket, false), "{": (kVK_ANSI_LeftBracket, true),
        "]": (kVK_ANSI_RightBracket, false), "}": (kVK_ANSI_RightBracket, true),
        "\\": (kVK_ANSI_Backslash, false), "|": (kVK_ANSI_Backslash, true),

        // Row 3: ASDF
        "a": (kVK_ANSI_A, false), "A": (kVK_ANSI_A, true),
        "s": (kVK_ANSI_S, false), "S": (kVK_ANSI_S, true),
        "d": (kVK_ANSI_D, false), "D": (kVK_ANSI_D, true),
        "f": (kVK_ANSI_F, false), "F": (kVK_ANSI_F, true),
        "g": (kVK_ANSI_G, false), "G": (kVK_ANSI_G, true),
        "h": (kVK_ANSI_H, false), "H": (kVK_ANSI_H, true),
        "j": (kVK_ANSI_J, false), "J": (kVK_ANSI_J, true),
        "k": (kVK_ANSI_K, false), "K": (kVK_ANSI_K, true),
        "l": (kVK_ANSI_L, false), "L": (kVK_ANSI_L, true),
        ";": (kVK_ANSI_Semicolon, false), ":": (kVK_ANSI_Semicolon, true),
        "'": (kVK_ANSI_Quote, false), "\"": (kVK_ANSI_Quote, true),

        // Row 4: ZXCV
        "z": (kVK_ANSI_Z, false), "Z": (kVK_ANSI_Z, true),
        "x": (kVK_ANSI_X, false), "X": (kVK_ANSI_X, true),
        "c": (kVK_ANSI_C, false), "C": (kVK_ANSI_C, true),
        "v": (kVK_ANSI_V, false), "V": (kVK_ANSI_V, true),
        "b": (kVK_ANSI_B, false), "B": (kVK_ANSI_B, true),
        "n": (kVK_ANSI_N, false), "N": (kVK_ANSI_N, true),
        "m": (kVK_ANSI_M, false), "M": (kVK_ANSI_M, true),
        ",": (kVK_ANSI_Comma, false), "<": (kVK_ANSI_Comma, true),
        ".": (kVK_ANSI_Period, false), ">": (kVK_ANSI_Period, true),
        "/": (kVK_ANSI_Slash, false), "?": (kVK_ANSI_Slash, true),

        // Grave/Tilde key
        "`": (kVK_ANSI_Grave, false), "~": (kVK_ANSI_Grave, true),
    ]

    /// Lookup virtual key code for a character
    /// Returns (keyCode, requiresShift) or nil if character has no standard key mapping
    private func lookupVirtualKey(for char: Character) -> (keyCode: Int, shift: Bool)? {
        return Self.asciiToVirtualKey[char]
    }

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

        // R1: Create persistent HID event source for this injection session
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            TextInjectionDebug.log(.error, "Failed to create HID event source")
            delegate?.injectionDidFail(error: .eventTapCreationFailed)
            return
        }
        self.hidEventSource = source
        TextInjectionDebug.log(.state, "Persistent HID event source created")

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

    // MARK: - Event Tap Creation (HID-level with .tailAppendEventTap)

    private func createEventTap() -> Bool {
        TextInjectionDebug.log(.state, "Creating HID-level event tap...")

        // Event mask for keyDown only (NOT keyUp - we only need to intercept keyDown)
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        TextInjectionDebug.log(.state, "Event mask: keyDown only")

        // Get pointer to self for callback
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        // R4: Create HID-level event tap with .tailAppendEventTap for proper queue ordering
        TextInjectionDebug.log(.state, "Creating tap with .cghidEventTap, .tailAppendEventTap")

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,            // HID-level tap for hardware-like events
            place: .tailAppendEventTap,     // R4: Proper HID queue ordering, prevents replay attack classification
            options: .defaultTap,           // NOT .listenOnly - we need to consume events
            eventsOfInterest: CGEventMask(eventMask),
            callback: TextInjectionEngine.eventTapCallback,
            userInfo: selfPtr
        ) else {
            TextInjectionDebug.log(.error, "Failed to create HID-level event tap!")
            TextInjectionDebug.log(.error, "Requires Input Monitoring permission in System Preferences")
            TextInjectionDebug.log(.error, "Security & Privacy -> Privacy -> Input Monitoring -> Add Stats")
            return false
        }

        TextInjectionDebug.log(.state, "HID-level event tap created successfully")

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

    // MARK: - Secure Input Check

    /// Check if Secure Input is active (password fields, etc.)
    private func isSecureInputActive() -> Bool {
        return IsSecureEventInputEnabled()
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
        // R8: Check for self-injected events FIRST - prevent infinite loops
        let userData = event.getIntegerValueField(.eventSourceUserData)
        if userData == Self.injectedEventTag {
            TextInjectionDebug.log(.event, "Passing through self-injected event")
            return Unmanaged.passUnretained(event)
        }

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

        // R6: NEVER inject during Secure Input - causes app termination
        if isSecureInputActive() {
            TextInjectionDebug.log(.error, "Secure Input active - skipping injection")
            return nil  // Swallow but don't inject
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

        // R1: Use persistent event source
        guard let source = hidEventSource else {
            TextInjectionDebug.log(.error, "No HID event source available")
            return false
        }

        var success = false

        // Handle special keys
        if char == "\n" || char == "\r" {
            TextInjectionDebug.log(.inject, "Injecting RETURN key")
            success = injectVirtualKey(kVK_Return, shift: false, unicodeChar: nil, source: source)
        } else if char == "\t" {
            TextInjectionDebug.log(.inject, "Injecting TAB key")
            success = injectVirtualKey(kVK_Tab, shift: false, unicodeChar: nil, source: source)
        } else if char == " " {
            TextInjectionDebug.log(.inject, "Injecting SPACE key")
            success = injectVirtualKey(kVK_Space, shift: false, unicodeChar: " ", source: source)
        } else if let (keyCode, needsShift) = lookupVirtualKey(for: char) {
            // Mapped character with known virtual key
            TextInjectionDebug.log(.inject, "Injecting '\(char)' via virtualKey \(keyCode), shift=\(needsShift)")
            success = injectMappedCharacter(char, keyCode: keyCode, shift: needsShift, source: source)
        } else {
            // Unicode-only fallback for emojis, accented chars, CJK, etc.
            TextInjectionDebug.log(.inject, "Injecting Unicode character (no virtual key): '\(char)'")
            success = injectUnicodeOnlyCharacter(char, source: source)
        }

        // Adaptive delay check
        if currentDelayMicroseconds > 15_000 {
            TextInjectionDebug.log(.error, "Delay too high (\(currentDelayMicroseconds)us), resetting to 10000")
            currentDelayMicroseconds = 10_000
        }

        usleep(currentDelayMicroseconds)
        lastInjectionTime = CFAbsoluteTimeGetCurrent()

        return success
    }

    /// Inject a virtual key (for special keys like Return, Tab, Space)
    private func injectVirtualKey(_ keyCode: Int, shift: Bool, unicodeChar: Character?, source: CGEventSource) -> Bool {
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true) else {
            TextInjectionDebug.log(.error, "Failed to create keyDown event for virtualKey \(keyCode)")
            return false
        }
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: false) else {
            TextInjectionDebug.log(.error, "Failed to create keyUp event for virtualKey \(keyCode)")
            return false
        }

        // R2/R7: Set Shift on KeyDown if needed
        if shift {
            keyDown.flags = .maskShift
        }
        // R7: KeyUp ALWAYS clears all modifiers
        keyUp.flags = []

        // R9: Unicode on BOTH events
        if let char = unicodeChar {
            var utf16 = Array(String(char).utf16)
            keyDown.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            keyUp.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
        }

        // R8: Tag both events
        keyDown.setIntegerValueField(.eventSourceUserData, value: Self.injectedEventTag)
        keyUp.setIntegerValueField(.eventSourceUserData, value: Self.injectedEventTag)

        // R5: Track pending KeyDown
        pendingKeyDown = true
        pendingKeyCode = CGKeyCode(keyCode)

        // Post to HID level
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        // R5: Clear pending state
        pendingKeyDown = false

        TextInjectionDebug.log(.inject, "Posted virtualKey \(keyCode) to .cghidEventTap")
        return true
    }

    /// Inject a character that has a known virtual key code mapping
    private func injectMappedCharacter(_ char: Character, keyCode: Int, shift: Bool, source: CGEventSource) -> Bool {
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true) else {
            TextInjectionDebug.log(.error, "Failed to create keyDown event for '\(char)' (keyCode \(keyCode))")
            return false
        }
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: false) else {
            TextInjectionDebug.log(.error, "Failed to create keyUp event for '\(char)'")
            return false
        }

        // R2/R7: Modifier handling
        if shift {
            keyDown.flags = .maskShift
        }
        keyUp.flags = []  // R7: Always clear on KeyUp

        // R9: Unicode on BOTH
        var utf16 = Array(String(char).utf16)
        keyDown.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
        keyUp.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)

        // R8: Tag events
        keyDown.setIntegerValueField(.eventSourceUserData, value: Self.injectedEventTag)
        keyUp.setIntegerValueField(.eventSourceUserData, value: Self.injectedEventTag)

        // R5: Track and post
        pendingKeyDown = true
        pendingKeyCode = CGKeyCode(keyCode)

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        pendingKeyDown = false

        TextInjectionDebug.log(.inject, "Posted mapped char '\(char)' (key \(keyCode), shift=\(shift)) to .cghidEventTap")
        return true
    }

    /// Fallback for characters without virtual key mapping (emojis, accented, CJK)
    private func injectUnicodeOnlyCharacter(_ char: Character, source: CGEventSource) -> Bool {
        var utf16 = Array(String(char).utf16)

        TextInjectionDebug.log(.inject, "Unicode-only injection for '\(char)', utf16 length=\(utf16.count)")

        // Use Space as neutral base key
        let neutralKey = CGKeyCode(kVK_Space)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: neutralKey, keyDown: true) else {
            TextInjectionDebug.log(.error, "Failed to create keyDown event for Unicode char")
            return false
        }
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: neutralKey, keyDown: false) else {
            TextInjectionDebug.log(.error, "Failed to create keyUp event for Unicode char")
            return false
        }

        // R9: Unicode on BOTH
        keyDown.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
        keyUp.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)

        // R7: Clear modifiers on KeyUp
        keyUp.flags = []

        // R8: Tag events
        keyDown.setIntegerValueField(.eventSourceUserData, value: Self.injectedEventTag)
        keyUp.setIntegerValueField(.eventSourceUserData, value: Self.injectedEventTag)

        // R3: Do NOT manually override keycode - macOS handles it correctly
        // (removed: setIntegerValueField(.keyboardEventKeycode, value: 0))

        // R5: Track and post
        pendingKeyDown = true
        pendingKeyCode = neutralKey

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        pendingKeyDown = false

        TextInjectionDebug.log(.inject, "Posted Unicode-only '\(char)' to .cghidEventTap (fallback mode)")
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

        // R5: Release any pending KeyDown immediately to prevent stuck keys
        if pendingKeyDown, let source = hidEventSource {
            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: pendingKeyCode, keyDown: false) {
                keyUp.flags = []
                keyUp.setIntegerValueField(.eventSourceUserData, value: Self.injectedEventTag)
                keyUp.post(tap: .cghidEventTap)
                TextInjectionDebug.log(.state, "Released pending KeyUp during emergency stop")
            }
            pendingKeyDown = false
        }

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

        // R5: Ensure no pending KeyDown remains unpaired
        if pendingKeyDown, let source = hidEventSource {
            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: pendingKeyCode, keyDown: false) {
                keyUp.flags = []
                keyUp.setIntegerValueField(.eventSourceUserData, value: Self.injectedEventTag)
                keyUp.post(tap: .cghidEventTap)
                TextInjectionDebug.log(.cleanup, "Released pending KeyUp for stuck key \(pendingKeyCode)")
            }
            pendingKeyDown = false
        }

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
        hidEventSource = nil
        pendingKeyDown = false
        pendingKeyCode = 0

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
