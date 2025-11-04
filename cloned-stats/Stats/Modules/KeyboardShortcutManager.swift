/**
 * Keyboard Shortcut Manager
 * Registers global keyboard shortcuts to trigger quiz scraping and animation
 *
 * Default Shortcut: Cmd+Option+Q (⌘⌥Q)
 */

import Cocoa
import Carbon

protocol KeyboardShortcutDelegate: AnyObject {
    func keyboardShortcutTriggered()
}

class KeyboardShortcutManager: NSObject {

    weak var delegate: KeyboardShortcutDelegate?

    private var eventMonitor: Any?
    private let triggerKey: String

    // MARK: - Initialization

    init(triggerKey: String = "z") {
        self.triggerKey = triggerKey.lowercased()
        super.init()
    }

    // MARK: - Public Methods

    /**
     * Register global keyboard shortcut
     * Uses: Cmd+Shift+Z by default (can be customized)
     */
    func registerGlobalShortcut() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: .keyDown
        ) { [weak self] event in
            // Check for Cmd+Shift+Z (custom key binding)
            let cmdKey = event.modifierFlags.contains(.command)
            let shiftKey = event.modifierFlags.contains(.shift)
            let keyChar = event.charactersIgnoringModifiers?.lowercased() ?? ""

            if cmdKey && shiftKey && keyChar == self?.triggerKey {
                self?.delegate?.keyboardShortcutTriggered()
            }
        }

        print("⌨️  Global keyboard shortcut registered: Cmd+Shift+Z")
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
