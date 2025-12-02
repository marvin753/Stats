/**
 * Keyboard Shortcut Manager
 * Registers global keyboard shortcuts for screenshot operations using CGEventTap
 * in safe .listenOnly mode to prevent macOS security termination.
 *
 * Supported Shortcuts:
 * - Cmd+Option+O: Capture screenshot (observed but not consumed)
 * - Cmd+Option+P: Process all screenshots (observed but not consumed)
 * - Cmd+I: Robust blue box capture (observed but not consumed)
 * - Cmd+Option+U: Solution injection (observed but not consumed)
 *
 * IMPORTANT: Uses .listenOnly mode exclusively to avoid triggering macOS security violations.
 * Events are observed and passed through without modification to prevent app termination.
 */

import Cocoa
import Carbon.HIToolbox

protocol KeyboardShortcutDelegate: AnyObject {
    func onCaptureScreenshot()  // Called when Cmd+Option+O is pressed
    func onProcessScreenshots() // Called when Cmd+Option+P is pressed (kept for future use)
    func onRobustCapture()      // Called when Cmd+Option+I is pressed
    func onSolutionShortcut()   // Called when Cmd+Option+U is pressed
}

extension KeyboardShortcutDelegate {
    func onSolutionShortcut() {}  // Default empty implementation
}

class KeyboardShortcutManager: NSObject {

    weak var delegate: KeyboardShortcutDelegate? {
        didSet {
            if delegate != nil {
                print("[KeyboardManager] Delegate set: \(type(of: delegate!))")
            } else {
                print("[KeyboardManager] Delegate cleared!")
            }
        }
    }

    // CGEventTap properties - stored to prevent deallocation
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // FIXED: Always use listenOnly to prevent macOS termination
    private var currentTapOptions: CGEventTapOptions = .listenOnly

    // MARK: - Initialization

    override init() {
        super.init()
        print("[KeyboardManager] Initialized for keyboard shortcuts: Cmd+Option+O (capture), Cmd+Option+P (process), Cmd+I (robust capture), Cmd+Option+U (solution)")
    }

    // MARK: - Public Methods

    /**
     * Check if accessibility permissions are granted
     */
    func checkAccessibilityPermissions() -> Bool {
        let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [checkOptPrompt: true] as CFDictionary
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)

        print("[KeyboardManager] Accessibility permissions check:")
        print("   Status: \(accessibilityEnabled ? "GRANTED" : "DENIED")")

        if !accessibilityEnabled {
            print("[KeyboardManager] Accessibility permissions NOT granted!")
            print("   To fix: System Preferences -> Security & Privacy -> Privacy -> Accessibility")
            print("   Add 'Stats' to the list and enable it")
        }

        return accessibilityEnabled
    }

    /**
     * Register global keyboard shortcuts using CGEventTap with automatic fallback
     * Tries multiple configurations until one works without crashing
     * Monitors for:
     * - Cmd+Option+O: Capture screenshot
     * - Cmd+Option+P: Process all screenshots
     * - Cmd+I: Robust blue box capture
     * - Cmd+Option+U: Solution injection
     */
    @discardableResult
    func registerGlobalShortcut() -> Bool {
        print("\n" + String(repeating: "=", count: 60))
        print("🔑 [KeyboardManager] Attempting Multiple Event Tap Configurations")
        print("   Input Monitoring Permission: Granted")
        print("   Goal: Find working event consumption approach")
        print(String(repeating: "=", count: 60))

        // Check Accessibility permission
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)

        if !accessEnabled {
            print("❌ [KeyboardManager] Accessibility permission denied")
            return false
        }

        // Define event mask
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        // Get pointer to self for callback
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        // FIXED: Use only safe listenOnly mode to prevent macOS termination
        // This avoids triggering security violations from event modification
        let configurations: [(tapLocation: CGEventTapLocation, options: CGEventTapOptions, name: String)] = [
            (.cgSessionEventTap, .listenOnly, "Safe session-level tap with listenOnly (no event consumption)")
        ]

        // Try each configuration
        for (index, config) in configurations.enumerated() {
            print("\n🔧 [KeyboardManager] Trying configuration #\(index + 1)...")
            print("   Tap Location: \(config.tapLocation)")
            print("   Options: \(config.options)")
            print("   Description: \(config.name)")

            guard let tap = CGEvent.tapCreate(
                tap: config.tapLocation,
                place: .headInsertEventTap,
                options: config.options,
                eventsOfInterest: CGEventMask(eventMask),
                callback: createCallback(for: config.options),
                userInfo: selfPtr
            ) else {
                print("   ❌ Failed to create event tap with this configuration")
                continue
            }

            // Success! Store the tap
            self.eventTap = tap
            self.currentTapOptions = config.options

            // Add to run loop
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = runLoopSource

            // Enable the tap
            CGEvent.tapEnable(tap: tap, enable: true)

            print("   ✅ Event tap created successfully!")
            print("\n" + String(repeating: "=", count: 60))
            print("✅ [KeyboardManager] Global keyboard shortcuts registered")
            print("   Configuration: \(config.name)")
            print("   Monitoring: Cmd+Option+O, Cmd+Option+P, Cmd+I, Cmd+Option+U")
            print("   Event consumption: \(config.options == .defaultTap ? "ENABLED" : "DISABLED")")
            print(String(repeating: "=", count: 60))

            return true
        }

        // All configurations failed
        print("\n❌ [KeyboardManager] All event tap configurations failed")
        print("   This may indicate a system-level restriction")
        return false
    }

    /**
     * Create callback based on tap options
     * This generates the appropriate event handler for the selected tap configuration
     */
    private func createCallback(for options: CGEventTapOptions) -> CGEventTapCallBack {
        let callback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
            // Handle special events
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                print("⚠️  [KeyboardManager] Event tap disabled by system")
                return Unmanaged.passUnretained(event)
            }

            guard type == .keyDown else {
                return Unmanaged.passUnretained(event)
            }

            // Get reference to self
            guard let refcon = refcon else {
                return Unmanaged.passUnretained(event)
            }
            let manager = Unmanaged<KeyboardShortcutManager>.fromOpaque(refcon).takeUnretainedValue()

            // Check for our shortcuts
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags

            let hasCommand = flags.contains(.maskCommand)
            let hasOption = flags.contains(.maskAlternate)

            // Cmd+I (WITHOUT Option) - Robust blue box capture
            // Check this FIRST before the Cmd+Option guard
            if hasCommand && !hasOption && keyCode == Int64(kVK_ANSI_I) {
                print("[KeyboardManager] Cmd+I detected: Robust blue box capture")
                DispatchQueue.main.async {
                    manager.delegate?.onRobustCapture()
                }
                print("[KeyboardManager] Event observed (listenOnly mode - not consumed)")
                return Unmanaged.passUnretained(event)
            }

            // For Cmd+Option+O and Cmd+Option+P
            guard hasCommand && hasOption else {
                return Unmanaged.passUnretained(event)
            }

            // Cmd+Option+O - Capture screenshot
            if keyCode == Int64(kVK_ANSI_O) {
                print("[KeyboardManager] Cmd+Option+O detected: Capture screenshot")

                // Call delegate on main thread
                DispatchQueue.main.async {
                    manager.delegate?.onCaptureScreenshot()
                }

                // FIXED: In listenOnly mode, we always pass through the original event
                // This prevents macOS from terminating the app for security violations
                print("[KeyboardManager] Event observed (listenOnly mode - not consumed)")
                return Unmanaged.passUnretained(event)
            }

            // Cmd+Option+P - Process screenshots
            if keyCode == Int64(kVK_ANSI_P) {
                print("[KeyboardManager] Cmd+Option+P detected: Process screenshots")

                DispatchQueue.main.async {
                    manager.delegate?.onProcessScreenshots()
                }

                // FIXED: In listenOnly mode, we always pass through the original event
                print("[KeyboardManager] Event observed (listenOnly mode - not consumed)")
                return Unmanaged.passUnretained(event)
            }

            // Cmd+Option+U - Solution injection
            if keyCode == Int64(kVK_ANSI_U) {  // kVK_ANSI_U = 32
                print("[KeyboardManager] Cmd+Option+U detected: Solution injection")
                DispatchQueue.main.async {
                    manager.delegate?.onSolutionShortcut()
                }
                print("[KeyboardManager] Event observed (listenOnly mode - not consumed)")
                return Unmanaged.passUnretained(event)
            }

            // Not our shortcut
            return Unmanaged.passUnretained(event)
        }

        return callback
    }

    /**
     * Unregister global keyboard shortcut
     */
    func unregisterGlobalShortcut() {
        // Disable and remove the event tap
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        // Remove run loop source
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }

        // Invalidate the mach port
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
            self.eventTap = nil
        }

        print("[KeyboardManager] Keyboard shortcut unregistered")
    }

    /**
     * Alias for registerGlobalShortcut for compatibility
     */
    func startMonitoring() {
        registerGlobalShortcut()
    }

    /**
     * Alias for unregisterGlobalShortcut for compatibility
     */
    func stopMonitoring() {
        unregisterGlobalShortcut()
    }

    deinit {
        unregisterGlobalShortcut()
    }
}
