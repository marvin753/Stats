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

    // Reference PDF UI elements
    private var referenceFileLabel: NSTextField?
    private var uploadButton: NSButton?
    private var clearButton: NSButton?
    private var statusIndicator: NSTextField?

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

        // Reference PDF section
        self.addArrangedSubview(createReferencePDFSection())
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

    // MARK: - Reference PDF Section

    private func createReferencePDFSection() -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 8
        container.distribution = .fill
        container.alignment = .leading

        // Description label
        let descLabel = createInfoLabel(
            "PDF document used as context for solution generation"
        )
        descLabel.font = NSFont.systemFont(ofSize: 11)

        // Current file label
        let fileLabel = NSTextField(frame: NSRect(x: 0, y: 0, width: 400, height: 20))
        fileLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        fileLabel.textColor = .labelColor
        fileLabel.isBezeled = false
        fileLabel.isEditable = false
        fileLabel.backgroundColor = .clear
        fileLabel.lineBreakMode = .byTruncatingMiddle
        self.referenceFileLabel = fileLabel

        // Status indicator
        let statusLabel = NSTextField(frame: NSRect(x: 0, y: 0, width: 400, height: 16))
        statusLabel.font = NSFont.systemFont(ofSize: 10)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.isBezeled = false
        statusLabel.isEditable = false
        statusLabel.backgroundColor = .clear
        self.statusIndicator = statusLabel

        // Button container
        let buttonContainer = NSStackView()
        buttonContainer.orientation = .horizontal
        buttonContainer.spacing = 8
        buttonContainer.distribution = .fillEqually

        // Select PDF button
        let selectButton = NSButton(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
        selectButton.title = "Select PDF"
        selectButton.bezelStyle = .rounded
        selectButton.target = self
        selectButton.action = #selector(selectReferencePDF)

        // Upload button
        let uploadBtn = NSButton(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
        uploadBtn.title = "Upload"
        uploadBtn.bezelStyle = .rounded
        uploadBtn.target = self
        uploadBtn.action = #selector(uploadReferencePDF)
        self.uploadButton = uploadBtn

        // Clear button
        let clearBtn = NSButton(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
        clearBtn.title = "Clear"
        clearBtn.bezelStyle = .rounded
        clearBtn.target = self
        clearBtn.action = #selector(clearReferencePDF)
        self.clearButton = clearBtn

        buttonContainer.addArrangedSubview(selectButton)
        buttonContainer.addArrangedSubview(uploadBtn)
        buttonContainer.addArrangedSubview(clearBtn)

        // Add all elements to container
        container.addArrangedSubview(descLabel)
        container.addArrangedSubview(fileLabel)
        container.addArrangedSubview(statusLabel)
        container.addArrangedSubview(buttonContainer)

        // Update UI with current state
        updateReferencePDFUI()

        return PreferencesSection([
            PreferencesRow("Reference PDF", component: container)
        ])
    }

    @objc private func selectReferencePDF() {
        ReferenceFileManager.shared.selectReferenceFile { [weak self] url in
            guard let url = url else { return }
            DispatchQueue.main.async {
                self?.updateReferencePDFUI()
            }
        }
    }

    @objc private func uploadReferencePDF() {
        guard ReferenceFileManager.shared.hasReferenceFile else {
            showAlert(title: "No PDF Selected", message: "Please select a PDF file first.")
            return
        }

        statusIndicator?.stringValue = "Uploading..."
        uploadButton?.isEnabled = false

        Task {
            do {
                _ = try await SolutionAPIService.shared.uploadCurrentReferencePDF()
                DispatchQueue.main.async { [weak self] in
                    self?.updateReferencePDFUI()
                    self?.showAlert(title: "Success", message: "PDF uploaded successfully.")
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.updateReferencePDFUI()
                    self?.showAlert(title: "Upload Failed", message: error.localizedDescription)
                }
            }
        }
    }

    @objc private func clearReferencePDF() {
        let alert = NSAlert()
        alert.messageText = "Clear Reference PDF"
        alert.informativeText = "This will remove the reference file from both the app and the backend. Continue?"
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            Task {
                do {
                    try await SolutionAPIService.shared.deleteReferenceFile()
                } catch {
                    print("Failed to delete reference from backend: \(error)")
                }
                ReferenceFileManager.shared.clearReferenceFile()
                DispatchQueue.main.async { [weak self] in
                    self?.updateReferencePDFUI()
                }
            }
        }
    }

    private func updateReferencePDFUI() {
        let hasFile = ReferenceFileManager.shared.hasReferenceFile
        let filename = ReferenceFileManager.shared.currentFileName ?? "No PDF selected"
        let hasUploadedId = ReferenceFileManager.shared.uploadedFileId != nil

        referenceFileLabel?.stringValue = filename

        if hasFile && hasUploadedId {
            statusIndicator?.stringValue = "Uploaded to backend"
            statusIndicator?.textColor = .systemGreen
        } else if hasFile {
            statusIndicator?.stringValue = "Not uploaded"
            statusIndicator?.textColor = .systemOrange
        } else {
            statusIndicator?.stringValue = ""
        }

        uploadButton?.isEnabled = hasFile && !hasUploadedId
        clearButton?.isEnabled = hasFile
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
}
