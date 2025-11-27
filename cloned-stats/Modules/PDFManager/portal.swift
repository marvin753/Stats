//
//  portal.swift
//  PDFManager
//
//  Portal view for widget integration (optional)
//

import Cocoa
import Kit

internal class Portal: Portal_p {
    private let title: String = "PDF Manager"
    private var portalView: PortalView?

    init(_ module: ModuleType) {
        super.init()
        self.setup()
    }

    deinit {
        self.portalView = nil
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        let view = PortalView()
        self.portalView = view
        self.addArrangedSubview(view)
    }
}

// MARK: - Portal View
private class PortalView: NSStackView {
    init() {
        super.init(frame: NSRect.zero)

        self.orientation = .vertical
        self.spacing = 8

        // Status label
        let statusLabel = NSTextField()
        statusLabel.stringValue = "PDF Manager Active"
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.drawsBackground = false
        statusLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .labelColor
        statusLabel.alignment = .center

        self.addArrangedSubview(statusLabel)

        // PDF count
        let manager = PDFDataManager.shared
        let countLabel = NSTextField()
        countLabel.stringValue = "\(manager.pdfs.count) PDF(s) uploaded"
        countLabel.isEditable = false
        countLabel.isBordered = false
        countLabel.drawsBackground = false
        countLabel.font = NSFont.systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor
        countLabel.alignment = .center

        self.addArrangedSubview(countLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
