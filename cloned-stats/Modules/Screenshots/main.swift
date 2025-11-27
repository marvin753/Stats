//
//  main.swift
//  Screenshots
//
//  Created on 2025-11-24.
//  Copyright © 2025 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

public class Screenshots: Module {
    private let popupView: Popup
    private let settingsView: Settings

    public init() {
        self.settingsView = Settings(.screenshots)
        self.popupView = Popup(.screenshots)

        super.init(
            moduleType: .screenshots,
            popup: self.popupView,
            settings: self.settingsView
        )
        guard self.available else { return }
    }
}
