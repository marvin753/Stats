//
//  settings.swift
//  PDFManager
//
//  Settings view for PDF Manager module
//

import Cocoa
import Kit

internal class Settings: Settings_v {
    private var storagePathView: NSTextField?

    public init(_ module: ModuleType) {
        super.init(frame: NSRect(x: 0, y: 0, width: 500, height: 200))

        self.setup(module)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(_ module: ModuleType) {
        let headerView = NSStackView()
        headerView.orientation = .vertical
        headerView.spacing = 8
        headerView.translatesAutoresizingMaskIntoConstraints = false

        // Title
        let title = NSTextField()
        title.stringValue = "PDF Reference Manager"
        title.isEditable = false
        title.isBordered = false
        title.drawsBackground = false
        title.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        title.textColor = .labelColor
        headerView.addArrangedSubview(title)

        // Description
        let description = NSTextField()
        description.stringValue = "Upload PDF files to use as reference material for quiz analysis. OpenAI will use the active PDF as context when analyzing quiz questions."
        description.isEditable = false
        description.isBordered = false
        description.drawsBackground = false
        description.font = NSFont.systemFont(ofSize: 12)
        description.textColor = .secondaryLabelColor
        description.lineBreakMode = .byWordWrapping
        description.maximumNumberOfLines = 3
        headerView.addArrangedSubview(description)

        // Storage location
        let storageStack = NSStackView()
        storageStack.orientation = .horizontal
        storageStack.spacing = 8
        storageStack.translatesAutoresizingMaskIntoConstraints = false

        let storageLabel = NSTextField()
        storageLabel.stringValue = "Storage:"
        storageLabel.isEditable = false
        storageLabel.isBordered = false
        storageLabel.drawsBackground = false
        storageLabel.font = NSFont.systemFont(ofSize: 12)
        storageLabel.textColor = .secondaryLabelColor
        storageStack.addArrangedSubview(storageLabel)

        let storagePath = NSTextField()
        storagePath.stringValue = "~/Library/Application Support/Stats/PDFs/"
        storagePath.isEditable = false
        storagePath.isBordered = false
        storagePath.drawsBackground = false
        storagePath.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        storagePath.textColor = .tertiaryLabelColor
        self.storagePathView = storagePath
        storageStack.addArrangedSubview(storagePath)

        let openFolderButton = NSButton(title: "Open Folder", target: self, action: #selector(openStorageFolder))
        openFolderButton.bezelStyle = .rounded
        openFolderButton.setButtonType(.momentaryPushIn)
        storageStack.addArrangedSubview(openFolderButton)

        headerView.addArrangedSubview(storageStack)

        // Keyboard shortcut info
        let shortcutLabel = NSTextField()
        shortcutLabel.stringValue = "Keyboard Shortcut: Cmd+Option+L - Open file picker"
        shortcutLabel.isEditable = false
        shortcutLabel.isBordered = false
        shortcutLabel.drawsBackground = false
        shortcutLabel.font = NSFont.systemFont(ofSize: 11)
        shortcutLabel.textColor = .tertiaryLabelColor
        headerView.addArrangedSubview(shortcutLabel)

        // Add to settings view
        self.addSubview(headerView)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: self.topAnchor, constant: 20),
            headerView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 20),
            headerView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -20)
        ])
    }

    @objc private func openStorageFolder() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let storageDir = appSupport.appendingPathComponent("Stats/PDFs")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)

        // Open in Finder
        NSWorkspace.shared.open(storageDir)
    }
}
