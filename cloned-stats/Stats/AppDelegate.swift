//
//  AppDelegate.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 28.05.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

import Kit
import UserNotifications

import CPU
import RAM
import Disk
import Net
import Battery
import Sensors
import GPU
import Bluetooth
import Clock
import Screenshots

let updater = Updater(github: "exelban/stats", url: "https://api.mac-stats.com/release/latest")
var modules: [Module] = [
    CPU(),
    GPU(),
    RAM(),
    Disk(),
    Sensors(),
    Network(),
    Battery(),
    Bluetooth(),
    Clock(),
    Screenshots()
]

@main
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    internal let settingsWindow: SettingsWindow = SettingsWindow()
    internal let updateWindow: UpdateWindow = UpdateWindow()
    internal let setupWindow: SetupWindow = SetupWindow()
    internal let supportWindow: SupportWindow = SupportWindow()
    internal let updateActivity = NSBackgroundActivityScheduler(identifier: "eu.exelban.Stats.updateCheck")
    internal let supportActivity = NSBackgroundActivityScheduler(identifier: "eu.exelban.Stats.support")
    internal var clickInNotification: Bool = false
    internal var menuBarItem: NSStatusItem? = nil
    internal var combinedView: CombinedView = CombinedView()
    
    internal var pauseState: Bool {
        Store.shared.bool(key: "pause", defaultValue: false)
    }
    
    private var startTS: Date?
    
    static func main() {
        // CRITICAL FAILSAFE LOGGING - If this doesn't appear, Swift isn't running at all
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🚀 STATS APP MAIN() CALLED - SWIFT CODE IS EXECUTING!")
        print("   Timestamp: \(Date())")
        print("   Process ID: \(ProcessInfo.processInfo.processIdentifier)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate

        print("📱 NSApplication created, delegate set")
        print("⏳ About to call app.run()...")
        fflush(stdout)  // Force flush to ensure logs appear

        app.run()
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("\n" + String(repeating: "=", count: 80))
        print("🎉 APPLICATION DID FINISH LAUNCHING - APP STARTED!")
        print("   Timestamp: \(Date())")
        print(String(repeating: "=", count: 80) + "\n")
        fflush(stdout)

        // Initialize Quiz Animation System
        print("🔄 About to call QuizIntegrationManager.shared.initialize()...")
        fflush(stdout)
        QuizIntegrationManager.shared.initialize()
        print("✅ Quiz Animation System initialized")
        fflush(stdout)
        let startingPoint = Date()

        self.parseArguments()
        self.parseVersion()
        SMCHelper.shared.checkForUpdate()
        self.setup {
            modules.reversed().forEach{ $0.mount() }
            self.settingsWindow.setModules()

            // PHASE 2B: Connect quiz controller to GPU widget
            // GPU module is at index 1 in modules array
            if let gpuModule = modules[1] as? GPU {
                QuizIntegrationManager.shared.connectToGPUModule(gpuModule)
            } else {
                print("⚠️  GPU module not found at expected index")
            }
        }
        self.defaultValues()
        self.icon()
        
        NotificationCenter.default.addObserver(self, selector: #selector(listenForAppPause), name: .pause, object: nil)
        NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
        
        info("Stats started in \((startingPoint.timeIntervalSinceNow * -1).rounded(toPlaces: 4)) seconds")
        self.startTS = Date()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        modules.forEach{ $0.terminate() }
        Remote.shared.terminate()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if self.clickInNotification {
            self.clickInNotification = false
            return true
        }
        guard let startTS = self.startTS, Date().timeIntervalSince(startTS) > 2 else { return false }
        
        if flag {
            self.settingsWindow.makeKeyAndOrderFront(self)
        } else {
            self.settingsWindow.setIsVisible(true)
        }
        
        return true
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        self.clickInNotification = true
        
        if let uri = response.notification.request.content.userInfo["url"] as? String {
            debug("Downloading new version of app...")
            if let url = URL(string: uri) {
                updater.download(url, completion: { path in
                    updater.install(path: path) { error in
                        if let error {
                            DispatchQueue.main.async {
                                showAlert("Error update Stats", error, .critical)
                            }
                        }
                    }
                })
            }
        }
        
        completionHandler()
    }
}
