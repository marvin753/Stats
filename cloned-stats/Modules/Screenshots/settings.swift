//
//  settings.swift
//  Screenshots
//
//  Created on 2025-11-24.
//  Copyright © 2025 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Settings: NSStackView, Settings_v {
    private let title: String

    public init(_ module: ModuleType) {
        self.title = module.stringValue

        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: 0))

        self.orientation = .vertical
        self.distribution = .gravityAreas
        self.translatesAutoresizingMaskIntoConstraints = false
        self.spacing = Constants.Settings.margin
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func load(widgets: [widget_t]) {
        self.subviews.forEach { $0.removeFromSuperview() }

        // Info section
        self.addArrangedSubview(PreferencesSection([
            PreferencesRow("Module status", component: self.createInfoLabel(
                "The Screenshots module displays your screenshot sessions.\n\n" +
                "Screenshots are organized into sessions of up to 14 images each. " +
                "Each session folder contains a combined PNG file that can be opened with a click."
            ))
        ]))

        // Storage location section
        let storageLabel = NSTextField(frame: NSRect(x: 0, y: 0, width: 400, height: 40))
        storageLabel.stringValue = "Storage Location:\n~/Library/Application Support/Stats/Screenshots/"
        storageLabel.font = NSFont.systemFont(ofSize: 12)
        storageLabel.textColor = .secondaryLabelColor
        storageLabel.isBezeled = false
        storageLabel.isEditable = false
        storageLabel.backgroundColor = .clear
        storageLabel.lineBreakMode = .byWordWrapping
        storageLabel.maximumNumberOfLines = 0

        let openButton = NSButton(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        openButton.title = "Open Screenshots Folder"
        openButton.bezelStyle = .rounded
        openButton.target = self
        openButton.action = #selector(openScreenshotsFolder)

        self.addArrangedSubview(PreferencesSection([
            PreferencesRow("Storage", component: storageLabel),
            PreferencesRow("", component: openButton)
        ]))

        // Session info section
        let sessionInfo = self.getSessionInfo()
        let sessionLabel = NSTextField(frame: NSRect(x: 0, y: 0, width: 400, height: 60))
        sessionLabel.stringValue = sessionInfo
        sessionLabel.font = NSFont.systemFont(ofSize: 12)
        sessionLabel.textColor = .labelColor
        sessionLabel.isBezeled = false
        sessionLabel.isEditable = false
        sessionLabel.backgroundColor = .clear
        sessionLabel.lineBreakMode = .byWordWrapping
        sessionLabel.maximumNumberOfLines = 0

        self.addArrangedSubview(PreferencesSection([
            PreferencesRow("Current Status", component: sessionLabel)
        ]))
    }

    // MARK: - Helper Methods

    private func createInfoLabel(_ text: String) -> NSTextField {
        let label = NSTextField(frame: NSRect(x: 0, y: 0, width: 400, height: 80))
        label.stringValue = text
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.isBezeled = false
        label.isEditable = false
        label.backgroundColor = .clear
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        return label
    }

    private func getSessionInfo() -> String {
        let fileManager = ScreenshotFileManager.shared
        let currentFolder = fileManager.getCurrentSessionFolder()
        let sessionName = currentFolder.lastPathComponent

        // Extract session number
        guard let numberString = sessionName.split(separator: "_").last,
              let sessionNumber = Int(numberString) else {
            return "Current Session: Unknown\nScreenshots: 0/14"
        }

        let count = fileManager.getScreenshotCount(inSession: sessionNumber)
        let totalSessions = fileManager.getAllSessions().count

        return "Current Session: \(sessionName)\n" +
               "Screenshots in current session: \(count)/14\n" +
               "Total sessions: \(totalSessions)"
    }

    // MARK: - Actions

    @objc private func openScreenshotsFolder() {
        let fileManager = ScreenshotFileManager.shared
        let baseURL = fileManager.getCurrentSessionFolder().deletingLastPathComponent()
        NSWorkspace.shared.open(baseURL)
    }
}
