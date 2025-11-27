//
//  main.swift
//  PDFManager
//
//  Created for Stats Quiz Integration
//  Wave 2B - PDF Management UI Module
//

import Cocoa
import Kit

public class PDFManager: Module {
    private let popupView: Popup
    private let settingsView: Settings
    private let portalView: Portal

    private let pdfDataManager = PDFDataManager.shared

    public init() {
        self.settingsView = Settings(.pdfManager)
        self.popupView = Popup()
        self.portalView = Portal(.pdfManager)

        super.init(
            moduleType: .pdfManager,
            popup: self.popupView,
            settings: self.settingsView,
            portal: self.portalView
        )

        guard self.available else { return }

        // Initialize PDF storage
        pdfDataManager.initializeStorage()

        // Setup views
        self.popupView.setup()
    }
}
