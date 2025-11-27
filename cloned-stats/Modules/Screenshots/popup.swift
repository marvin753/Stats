//
//  popup.swift
//  Screenshots
//
//  Created on 2025-11-24.
//  Copyright © 2025 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class Popup: PopupWrapper {
    private var sessionListView: NSScrollView? = nil
    private var sessionStackView: NSStackView? = nil
    private let rowHeight: CGFloat = 44
    private var sessions: [(number: Int, count: Int, isCurrent: Bool, combinedPNG: URL?)] = []
    private var refreshTimer: Timer? = nil
    private var sessionURLs: [Int: URL] = [:]  // Maps session number to combined PNG URL

    public init(_ module: ModuleType) {
        super.init(module, frame: NSRect(x: 0, y: 0, width: Constants.Popup.width, height: 400))

        self.orientation = .vertical
        self.spacing = 0

        self.addArrangedSubview(self.initHeader())
        self.addArrangedSubview(self.initSessionList())

        self.loadSessions()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.refreshTimer?.invalidate()
    }

    public override func appear() {
        super.appear()
        self.loadSessions()
        self.startAutoRefresh()
    }

    public override func disappear() {
        super.disappear()
        self.stopAutoRefresh()
    }

    // MARK: - UI Initialization

    private func initHeader() -> NSView {
        let header = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: Constants.Popup.headerHeight))
        header.heightAnchor.constraint(equalToConstant: Constants.Popup.headerHeight).isActive = true

        let iconView: NSImageView = NSImageView(frame: NSRect(x: 10, y: 10, width: 22, height: 22))
        if #available(macOS 11.0, *) {
            iconView.image = NSImage(systemSymbolName: "photo.stack", accessibilityDescription: "Screenshots")
        }
        iconView.contentTintColor = .labelColor

        let titleField = NSTextField(frame: NSRect(x: 40, y: 12, width: 150, height: 18))
        titleField.stringValue = "Screenshots"
        titleField.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        titleField.textColor = .labelColor
        titleField.isBezeled = false
        titleField.isEditable = false
        titleField.backgroundColor = .clear

        let refreshButton = NSButton(frame: NSRect(x: self.frame.width - 40, y: 8, width: 30, height: 26))
        refreshButton.bezelStyle = .rounded
        refreshButton.isBordered = true
        if #available(macOS 11.0, *) {
            refreshButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh")
            refreshButton.contentTintColor = .labelColor
        } else {
            refreshButton.title = "↻"
        }
        refreshButton.target = self
        refreshButton.action = #selector(refreshSessions)

        header.addSubview(iconView)
        header.addSubview(titleField)
        header.addSubview(refreshButton)

        return header
    }

    private func initSessionList() -> NSView {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: self.frame.width, height: 350))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.heightAnchor.constraint(equalToConstant: 350).isActive = true

        let stackView = NSStackView(frame: NSRect(x: 0, y: 0, width: self.frame.width - 20, height: 0))
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        scrollView.documentView = stackView

        self.sessionListView = scrollView
        self.sessionStackView = stackView

        return scrollView
    }

    // MARK: - Data Loading

    private func loadSessions() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let fileManager = ScreenshotFileManager.shared
            let allSessionFolders = fileManager.getAllSessions()
            let currentSession = fileManager.getCurrentSessionFolder()

            var sessionData: [(number: Int, count: Int, isCurrent: Bool, combinedPNG: URL?)] = []

            for sessionFolder in allSessionFolders {
                let folderName = sessionFolder.lastPathComponent
                guard folderName.hasPrefix("Session_"),
                      let numberString = folderName.split(separator: "_").last,
                      let sessionNumber = Int(numberString) else {
                    continue
                }

                let count = fileManager.getScreenshotCount(inSession: sessionNumber)
                let isCurrent = sessionFolder.path == currentSession.path

                // Look for combined PNG file
                let combinedPNGName = "Session_\(String(format: "%03d", sessionNumber)).png"
                let combinedPNGURL = sessionFolder.appendingPathComponent(combinedPNGName)
                let combinedPNG = FileManager.default.fileExists(atPath: combinedPNGURL.path) ? combinedPNGURL : nil

                sessionData.append((sessionNumber, count, isCurrent, combinedPNG))
            }

            // Sort by session number descending (newest first)
            sessionData.sort { $0.number > $1.number }

            DispatchQueue.main.async {
                self.sessions = sessionData
                self.updateSessionList()
            }
        }
    }

    private func updateSessionList() {
        guard let stackView = self.sessionStackView else { return }

        // Clear existing views
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if sessions.isEmpty {
            let emptyLabel = NSTextField(frame: NSRect(x: 0, y: 0, width: self.frame.width - 20, height: 100))
            emptyLabel.stringValue = "No screenshot sessions yet.\n\nScreenshots will appear here as they are captured."
            emptyLabel.font = NSFont.systemFont(ofSize: 13)
            emptyLabel.textColor = .secondaryLabelColor
            emptyLabel.alignment = .center
            emptyLabel.isBezeled = false
            emptyLabel.isEditable = false
            emptyLabel.backgroundColor = .clear
            stackView.addArrangedSubview(emptyLabel)
            return
        }

        // Add session rows
        for session in sessions {
            let rowView = self.createSessionRow(
                sessionNumber: session.number,
                screenshotCount: session.count,
                isCurrent: session.isCurrent,
                combinedPNG: session.combinedPNG
            )
            stackView.addArrangedSubview(rowView)
        }
    }

    private func createSessionRow(sessionNumber: Int, screenshotCount: Int, isCurrent: Bool, combinedPNG: URL?) -> NSView {
        let row = NSView(frame: NSRect(x: 0, y: 0, width: self.frame.width - 20, height: self.rowHeight))
        row.heightAnchor.constraint(equalToConstant: self.rowHeight).isActive = true
        row.wantsLayer = true
        row.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        row.layer?.cornerRadius = 8

        // Icon
        let iconView = NSImageView(frame: NSRect(x: 12, y: 11, width: 22, height: 22))
        if #available(macOS 11.0, *) {
            if combinedPNG != nil {
                iconView.image = NSImage(systemSymbolName: "photo.on.rectangle", accessibilityDescription: nil)
                iconView.contentTintColor = .systemBlue
            } else {
                iconView.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
                iconView.contentTintColor = .secondaryLabelColor
            }
        }
        row.addSubview(iconView)

        // Session name
        let sessionLabel = NSTextField(frame: NSRect(x: 44, y: 16, width: 120, height: 16))
        sessionLabel.stringValue = "Session \(String(format: "%03d", sessionNumber))"
        sessionLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        sessionLabel.textColor = .labelColor
        sessionLabel.isBezeled = false
        sessionLabel.isEditable = false
        sessionLabel.backgroundColor = .clear
        row.addSubview(sessionLabel)

        // Screenshot count
        let countLabel = NSTextField(frame: NSRect(x: 44, y: 2, width: 120, height: 14))
        let maxCount = 14
        countLabel.stringValue = "\(screenshotCount)/\(maxCount) screenshots"
        countLabel.font = NSFont.systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor
        countLabel.isBezeled = false
        countLabel.isEditable = false
        countLabel.backgroundColor = .clear
        row.addSubview(countLabel)

        // Status badge
        if isCurrent {
            let badge = NSTextField(frame: NSRect(x: row.frame.width - 100, y: 12, width: 80, height: 20))
            badge.stringValue = "🟢 Active"
            badge.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            badge.textColor = .systemGreen
            badge.alignment = .right
            badge.isBezeled = false
            badge.isEditable = false
            badge.backgroundColor = .clear
            row.addSubview(badge)
        } else if screenshotCount >= maxCount {
            let badge = NSTextField(frame: NSRect(x: row.frame.width - 100, y: 12, width: 80, height: 20))
            badge.stringValue = "✓ Complete"
            badge.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            badge.textColor = .systemGray
            badge.alignment = .right
            badge.isBezeled = false
            badge.isEditable = false
            badge.backgroundColor = .clear
            row.addSubview(badge)
        }

        // Make clickable if combined PNG exists
        if let pngURL = combinedPNG {
            // Store URL in dictionary for later retrieval
            self.sessionURLs[sessionNumber] = pngURL

            let clickArea = NSButton(frame: row.bounds)
            clickArea.isBordered = false
            clickArea.title = ""
            clickArea.target = self
            clickArea.action = #selector(openCombinedPNG(_:))
            clickArea.tag = sessionNumber
            clickArea.toolTip = "Click to open Session_\(String(format: "%03d", sessionNumber)).png"

            row.addSubview(clickArea)
        }

        return row
    }

    // MARK: - Actions

    @objc private func refreshSessions() {
        self.loadSessions()
    }

    @objc private func openCombinedPNG(_ sender: NSButton) {
        let sessionNumber = sender.tag
        guard let pngURL = self.sessionURLs[sessionNumber] else { return }

        // Open with Quick Look or default image viewer
        NSWorkspace.shared.open(pngURL)
    }

    // MARK: - Auto Refresh

    private func startAutoRefresh() {
        self.refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.loadSessions()
        }
    }

    private func stopAutoRefresh() {
        self.refreshTimer?.invalidate()
        self.refreshTimer = nil
    }
}
