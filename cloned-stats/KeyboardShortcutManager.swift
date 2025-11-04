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

    init(triggerKey: String = "q") {
        self.triggerKey = triggerKey.lowercased()
        super.init()
    }

    // MARK: - Public Methods

    /**
     * Register global keyboard shortcut
     * Uses: Cmd+Option+Q by default (can be customized)
     */
    func registerGlobalShortcut() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: .keyDown
        ) { [weak self] event in
            // Check for Cmd+Option+Q (custom key binding)
            let cmdKey = event.modifierFlags.contains(.command)
            let optionKey = event.modifierFlags.contains(.option)
            let keyChar = event.charactersIgnoringModifiers?.lowercased() ?? ""

            if cmdKey && optionKey && keyChar == self?.triggerKey {
                self?.delegate?.keyboardShortcutTriggered()
            }
        }

        print("⌨️  Global keyboard shortcut registered: Cmd+Option+Q")
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
