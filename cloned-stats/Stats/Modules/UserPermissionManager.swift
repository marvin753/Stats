//
//  UserPermissionManager.swift
//  Stats
//
//  Created for text injection feature
//  Manages Input Monitoring and Accessibility permission checks
//

import Cocoa
import ApplicationServices

/// Manages Input Monitoring and Accessibility permission checks
class UserPermissionManager {
    static let shared = UserPermissionManager()

    private init() {}

    // MARK: - Permission Checks

    /// Check all required permissions
    func checkAllPermissions() -> (inputMonitoring: Bool, accessibility: Bool) {
        return (checkInputMonitoring(), checkAccessibility())
    }

    /// Check Accessibility permission using AXIsProcessTrustedWithOptions
    func checkAccessibility() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Check Input Monitoring by attempting to create a minimal event tap
    func checkInputMonitoring() -> Bool {
        // Create a minimal tap to test permissions
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
            userInfo: nil
        ) else {
            return false
        }
        // Clean up immediately
        CFMachPortInvalidate(tap)
        return true
    }

    // MARK: - Settings Navigation

    /// Open Accessibility settings pane
    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Open Input Monitoring settings pane
    func openInputMonitoringSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - User Guidance

    /// Show permission guidance alert
    func showPermissionGuidance() {
        let permissions = checkAllPermissions()

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Permissions Required"

            var message = "The text injection feature requires additional permissions:\n\n"

            if !permissions.accessibility {
                message += "❌ Accessibility: Required for keyboard control\n"
            } else {
                message += "✅ Accessibility: Granted\n"
            }

            if !permissions.inputMonitoring {
                message += "❌ Input Monitoring: Required for keystroke handling\n"
            } else {
                message += "✅ Input Monitoring: Granted\n"
            }

            message += "\nPlease grant permissions in System Settings → Privacy & Security"

            alert.informativeText = message
            alert.alertStyle = .warning

            if !permissions.accessibility {
                alert.addButton(withTitle: "Open Accessibility Settings")
            }
            if !permissions.inputMonitoring {
                alert.addButton(withTitle: "Open Input Monitoring Settings")
            }
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                if !permissions.accessibility {
                    self.openAccessibilitySettings()
                } else if !permissions.inputMonitoring {
                    self.openInputMonitoringSettings()
                }
            } else if response == .alertSecondButtonReturn && !permissions.accessibility && !permissions.inputMonitoring {
                self.openInputMonitoringSettings()
            }
        }
    }

    /// Request Accessibility permission with prompt
    func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
