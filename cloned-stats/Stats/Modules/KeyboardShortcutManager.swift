/**
 * Keyboard Shortcut Manager
 * Registers global keyboard shortcuts for screenshot operations
 *
 * Supported Shortcuts:
 * - Cmd+Option+O (⌘⌥O): Capture screenshot
 * - Cmd+Option+P (⌘⌥P): Process all screenshots
 */

import Cocoa
import Carbon

protocol KeyboardShortcutDelegate: AnyObject {
    func onCaptureScreenshot()  // Called when Cmd+Option+O is pressed
    func onProcessScreenshots() // Called when Cmd+Control+P is pressed (kept for future use)
}

class KeyboardShortcutManager: NSObject {

    weak var delegate: KeyboardShortcutDelegate? {
        didSet {
            if delegate != nil {
                print("✅ [KeyboardManager] Delegate set: \(type(of: delegate!))")
            } else {
                print("⚠️  [KeyboardManager] Delegate cleared!")
            }
        }
    }

    private var eventMonitor: Any?

    // MARK: - Initialization

    override init() {
        super.init()
        print("🔧 [KeyboardManager] Initialized for keyboard shortcuts: Cmd+Option+O (capture), Cmd+Option+P (process)")
    }

    // MARK: - Public Methods

    /**
     * Check if accessibility permissions are granted
     */
    func checkAccessibilityPermissions() -> Bool {
        let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [checkOptPrompt: true] as CFDictionary
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)

        print("🔐 [KeyboardManager] Accessibility permissions check:")
        print("   Status: \(accessibilityEnabled ? "✅ GRANTED" : "❌ DENIED")")

        if !accessibilityEnabled {
            print("⚠️  [KeyboardManager] Accessibility permissions NOT granted!")
            print("   To fix: System Preferences → Security & Privacy → Privacy → Accessibility")
            print("   Add 'Stats' to the list and enable it")
        }

        return accessibilityEnabled
    }

    /**
     * Register global keyboard shortcuts
     * Monitors for:
     * - Cmd+Option+O: Capture screenshot
     * - Cmd+Option+P: Process all screenshots
     */
    func registerGlobalShortcut() {
        print("🔧 [KeyboardManager] Starting keyboard shortcut registration...")
        print("🔧 [KeyboardManager] Monitoring for:")
        print("   - Cmd+Option+O: Capture screenshot")
        print("   - Cmd+Option+P: Process all screenshots")

        // Check permissions first
        let hasPermissions = checkAccessibilityPermissions()
        if !hasPermissions {
            print("⚠️  [KeyboardManager] Registration may fail due to missing permissions")
        }

        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: .keyDown
        ) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        if eventMonitor == nil {
            print("❌ [KeyboardManager] ERROR: NSEvent.addGlobalMonitorForEvents returned nil!")
            print("   This usually means accessibility permissions are denied.")
            print("   Check: System Preferences → Security & Privacy → Privacy → Accessibility")
        } else {
            print("✅ [KeyboardManager] Global keyboard shortcuts registered successfully")
            print("   Monitor object: \(eventMonitor!)")
        }
    }

    // MARK: - Private Methods

    /**
     * Handle keyboard event and determine which shortcut was triggered
     */
    private func handleKeyEvent(_ event: NSEvent) {
        // Extract modifiers and key character
        let flags = event.modifierFlags
        let hasCmd = flags.contains(.command)
        let hasOption = flags.contains(.option)
        let keyChar = event.charactersIgnoringModifiers?.lowercased() ?? ""

        // Check if we have the required modifiers (Cmd+Option)
        guard hasCmd && hasOption else {
            return
        }

        // Handle different keys
        switch keyChar {
        case "o":
            print("⌨️  [KeyboardManager] Cmd+Option+O detected: Capture screenshot")
            delegate?.onCaptureScreenshot()

        case "p":
            print("⌨️  [KeyboardManager] Cmd+Option+P detected: Process screenshots")
            delegate?.onProcessScreenshots()

        default:
            // Not a shortcut we care about
            break
        }
    }

    /**
     * Unregister global keyboard shortcut
     */
    func unregisterGlobalShortcut() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
            print("✓ Keyboard shortcut unregistered")
        }
    }

    deinit {
        unregisterGlobalShortcut()
    }
}
