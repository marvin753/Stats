//
//  ScreenshotFileManager.swift
//  Stats
//
//  Created on 2025-11-24.
//  Manages screenshot storage with automatic session organization.
//  Screenshots are saved as INDIVIDUAL PNG files (14 per session folder).
//

import Foundation
import AppKit

/// Manages screenshot storage with automatic session organization.
/// Screenshots are organized into session folders, with each session containing up to 14 INDIVIDUAL PNG files.
class ScreenshotFileManager {

    // MARK: - Singleton

    static let shared = ScreenshotFileManager()

    // MARK: - Properties

    private let baseDirectory: URL
    private let maxScreenshotsPerSession = 14
    private var currentSessionNumber: Int
    private var currentSessionScreenshotCount: Int
    private let queue = DispatchQueue(label: "com.stats.screenshotmanager", attributes: .concurrent)

    // MARK: - Initialization

    private init() {
        // Set up base directory in Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.baseDirectory = appSupport
            .appendingPathComponent("Stats", isDirectory: true)
            .appendingPathComponent("Screenshots", isDirectory: true)

        // Initialize properties with default values
        self.currentSessionNumber = 1
        self.currentSessionScreenshotCount = 0

        print("ScreenshotFileManager: Initializing...")

        // Ensure base directory exists
        self.ensureDirectoryExists(baseDirectory)

        // Scan existing sessions to determine current state
        let sessions = self.scanExistingSessions()

        if sessions.isEmpty {
            // No sessions exist, keep defaults
            print("ScreenshotFileManager: Starting fresh with Session_001")
        } else {
            // Find the highest session number
            let highestSession = sessions.max() ?? 0
            self.currentSessionNumber = highestSession

            // Count screenshots in current session
            self.currentSessionScreenshotCount = self.getScreenshotCount(inSession: highestSession)

            print("ScreenshotFileManager: Resumed at Session_\(String(format: "%03d", highestSession)) with \(currentSessionScreenshotCount) screenshots")

            // If current session is full, prepare for next session
            if self.currentSessionScreenshotCount >= maxScreenshotsPerSession {
                self.currentSessionNumber += 1
                self.currentSessionScreenshotCount = 0
                print("ScreenshotFileManager: Current session full, prepared Session_\(String(format: "%03d", currentSessionNumber))")
            }
        }
    }

    // MARK: - Public Methods

    /// Saves a screenshot to the current session folder as an individual PNG file.
    /// Automatically creates a new session if the current one reaches 14 screenshots.
    /// - Parameter image: The NSImage to save as a PNG screenshot
    /// - Returns: The file URL where the screenshot was saved, or nil if saving failed
    func saveScreenshot(_ image: NSImage) -> URL? {
        return queue.sync(flags: .barrier) {
            print("ScreenshotFileManager: Saving screenshot (current count: \(self.currentSessionScreenshotCount)/\(self.maxScreenshotsPerSession))")

            // CRITICAL: Validate image before processing to prevent crashes
            guard self.validateImage(image) else {
                print("ScreenshotFileManager Error: Image validation failed - cannot save")
                return nil
            }

            // Check if we need to create a new session
            // CRITICAL: Use unsafe version since we're already inside queue.sync
            self.createNewSessionIfNeededUnsafe()

            // Get current session folder
            // CRITICAL: Use unsafe version since we're already inside queue.sync
            let sessionFolder = self.getCurrentSessionFolderUnsafe()
            self.ensureDirectoryExists(sessionFolder)

            // Increment screenshot count
            self.currentSessionScreenshotCount += 1

            // Generate filename
            let filename = self.generateFilename(
                session: self.currentSessionNumber,
                index: self.currentSessionScreenshotCount
            )

            let fileURL = sessionFolder.appendingPathComponent(filename)

            print("ScreenshotFileManager: Attempting to save to: \(fileURL.lastPathComponent)")

            // SAFE PNG CONVERSION with comprehensive error handling
            // FIX: Bypass problematic tiffRepresentation by using CGImage directly
            do {
                var bitmapImage: NSBitmapImageRep?

                // Step 1: Try to get CGImage directly from NSImage (most reliable method)
                if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    print("ScreenshotFileManager: Creating bitmap from CGImage (direct method)")
                    bitmapImage = NSBitmapImageRep(cgImage: cgImage)
                } else {
                    // Step 2: Fallback to TIFF method if CGImage extraction fails
                    print("ScreenshotFileManager: Falling back to TIFF method")
                    guard let tiffData = image.tiffRepresentation else {
                        print("ScreenshotFileManager Error: Failed to create TIFF representation")
                        self.currentSessionScreenshotCount -= 1
                        return nil
                    }
                    bitmapImage = NSBitmapImageRep(data: tiffData)
                }

                // Step 3: Verify bitmap was created
                guard let bitmapImage = bitmapImage else {
                    print("ScreenshotFileManager Error: Failed to create bitmap representation")
                    self.currentSessionScreenshotCount -= 1
                    return nil
                }

                // Step 4: Convert to PNG data
                guard let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
                    print("ScreenshotFileManager Error: Failed to create PNG data")
                    self.currentSessionScreenshotCount -= 1
                    return nil
                }

                print("ScreenshotFileManager: PNG data created: \(pngData.count) bytes")

                // Step 4: Write to file with atomic operation
                try pngData.write(to: fileURL, options: .atomic)

                print("ScreenshotFileManager: ✅ Screenshot saved successfully!")
                print("   File: \(fileURL.lastPathComponent)")
                print("   Size: \(pngData.count / 1024) KB")
                print("   Session: \(self.currentSessionNumber)")
                print("   Count: \(self.currentSessionScreenshotCount)/\(self.maxScreenshotsPerSession)")

                return fileURL

            } catch {
                print("ScreenshotFileManager Error: Failed to write PNG file: \(error.localizedDescription)")
                // Rollback count increment
                self.currentSessionScreenshotCount -= 1
                return nil
            }
        }
    }

    /// Returns the URL for the current session folder (internal version - assumes already on queue)
    /// CRITICAL: This method assumes it's already called from within the queue context!
    private func getCurrentSessionFolderUnsafe() -> URL {
        let sessionName = String(format: "Session_%03d", self.currentSessionNumber)
        return self.baseDirectory.appendingPathComponent(sessionName, isDirectory: true)
    }

    /// Returns the URL of the current session folder (public thread-safe version)
    /// - Returns: URL pointing to the current session directory
    /// FIX: Use async dispatch to avoid deadlock when called from within queue context
    func getCurrentSessionFolder() -> URL {
        var result: URL!
        let semaphore = DispatchSemaphore(value: 0)
        queue.async {
            result = self.getCurrentSessionFolderUnsafe()
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }

    /// Returns the current session number (internal version - assumes already on queue)
    private func getCurrentSessionNumberUnsafe() -> Int {
        return self.currentSessionNumber
    }

    /// Returns the current session number (public thread-safe version)
    /// FIX: Use async dispatch to avoid deadlock when called from within queue context
    func getCurrentSessionNumber() -> Int {
        var result: Int = 0
        let semaphore = DispatchSemaphore(value: 0)
        queue.async {
            result = self.getCurrentSessionNumberUnsafe()
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }

    /// Returns the current screenshot count in the active session
    /// FIX: Use async dispatch to avoid deadlock when called from within queue context
    func getCurrentSessionCount() -> Int {
        var result: Int = 0
        let semaphore = DispatchSemaphore(value: 0)
        queue.async {
            result = self.currentSessionScreenshotCount
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }

    /// Creates a new session folder if the current session has reached the maximum screenshot count.
    /// CRITICAL: This method assumes it's already called from within the queue context!
    /// It does NOT wrap in queue.sync to avoid deadlock.
    private func createNewSessionIfNeededUnsafe() {
        if self.currentSessionScreenshotCount >= self.maxScreenshotsPerSession {
            self.currentSessionNumber += 1
            self.currentSessionScreenshotCount = 0
            print("ScreenshotFileManager: Created new session - Session_\(String(format: "%03d", currentSessionNumber))")
        }
    }

    /// Public wrapper that safely calls createNewSessionIfNeededUnsafe with proper queue synchronization
    func createNewSessionIfNeeded() {
        queue.sync(flags: .barrier) {
            self.createNewSessionIfNeededUnsafe()
        }
    }

    /// Counts the number of screenshots in a specific session.
    /// - Parameter session: The session number to count screenshots in
    /// - Returns: The number of screenshot files found in the session folder
    func getScreenshotCount(inSession session: Int) -> Int {
        let sessionName = String(format: "Session_%03d", session)
        let sessionURL = baseDirectory.appendingPathComponent(sessionName, isDirectory: true)

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: sessionURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            // Filter for PNG files that match the screenshot naming pattern
            let screenshots = contents.filter { url in
                url.pathExtension == "png" && url.lastPathComponent.hasPrefix("screenshot_")
            }

            return screenshots.count
        } catch {
            // Directory doesn't exist or other error
            return 0
        }
    }

    /// Returns all session folder URLs sorted by session number.
    /// - Returns: Array of URLs pointing to session directories
    func getAllSessions() -> [URL] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: baseDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            // Filter for directories that match the Session_XXX pattern
            let sessions = contents.filter { url in
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                return isDirectory.boolValue && url.lastPathComponent.hasPrefix("Session_")
            }

            // Sort by session number
            return sessions.sorted { url1, url2 in
                let name1 = url1.lastPathComponent
                let name2 = url2.lastPathComponent
                return name1 < name2
            }
        } catch {
            print("ScreenshotFileManager Error: Failed to list sessions - \(error.localizedDescription)")
            return []
        }
    }

    /// Returns all screenshot files in a specific session
    /// - Parameter sessionNumber: The session number
    /// - Returns: Array of URLs pointing to PNG files in the session
    func getScreenshots(inSession sessionNumber: Int) -> [URL] {
        let sessionName = String(format: "Session_%03d", sessionNumber)
        let sessionURL = baseDirectory.appendingPathComponent(sessionName, isDirectory: true)

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: sessionURL,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )

            // Filter for PNG files and sort by creation date
            let screenshots = contents.filter { url in
                url.pathExtension == "png" && url.lastPathComponent.hasPrefix("screenshot_")
            }

            return screenshots.sorted { url1, url2 in
                let name1 = url1.lastPathComponent
                let name2 = url2.lastPathComponent
                return name1 < name2
            }
        } catch {
            print("ScreenshotFileManager Error: Failed to list screenshots in session \(sessionNumber) - \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Private Methods - Image Validation

    /// Validate that an NSImage is safe to convert to PNG
    /// CRITICAL: Prevents crash by checking image data before conversion
    /// FIX: Removed TIFF check to avoid SIGTRAP crash - uses CGImage instead
    private func validateImage(_ image: NSImage) -> Bool {
        print("ScreenshotFileManager: Starting image validation...")

        // Check 1: Image has valid size
        guard image.size.width > 0 && image.size.height > 0 else {
            print("ScreenshotFileManager Error: Image validation failed - Invalid size (\(image.size.width)x\(image.size.height))")
            return false
        }
        print("ScreenshotFileManager: ✓ Size valid: \(Int(image.size.width))x\(Int(image.size.height))")

        // Check 2: Image has representations
        guard !image.representations.isEmpty else {
            print("ScreenshotFileManager Error: Image validation failed - No image representations")
            return false
        }
        print("ScreenshotFileManager: ✓ Has \(image.representations.count) representation(s)")

        // Check 3: Can extract CGImage (SAFE - does not trigger TIFF conversion)
        // This is the SAME method we use for conversion, so if it works here, it will work later
        guard image.cgImage(forProposedRect: nil, context: nil, hints: nil) != nil else {
            print("ScreenshotFileManager Error: Image validation failed - Cannot extract CGImage")
            return false
        }
        print("ScreenshotFileManager: ✓ CGImage extraction successful")

        print("ScreenshotFileManager: ✅ Image validation passed: \(Int(image.size.width))x\(Int(image.size.height))")
        return true
    }

    // MARK: - Private Methods - Directory Management

    /// Ensures a directory exists at the specified URL, creating it if necessary.
    /// - Parameter url: The directory URL to create
    private func ensureDirectoryExists(_ url: URL) {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)

        if !exists || !isDirectory.boolValue {
            do {
                try FileManager.default.createDirectory(
                    at: url,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                print("ScreenshotFileManager: Created directory at \(url.path)")
            } catch {
                print("ScreenshotFileManager Error: Failed to create directory - \(error.localizedDescription)")
            }
        }
    }

    /// Scans the base directory for existing session folders and returns their numbers.
    /// - Returns: Array of session numbers found in the base directory
    private func scanExistingSessions() -> [Int] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: baseDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            var sessionNumbers: [Int] = []

            for url in contents {
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)

                guard isDirectory.boolValue else { continue }

                let folderName = url.lastPathComponent

                // Parse session number from "Session_XXX" format
                if folderName.hasPrefix("Session_"),
                   let numberString = folderName.split(separator: "_").last,
                   let sessionNumber = Int(numberString) {
                    sessionNumbers.append(sessionNumber)
                }
            }

            return sessionNumbers.sorted()
        } catch {
            print("ScreenshotFileManager Error: Failed to scan sessions - \(error.localizedDescription)")
            return []
        }
    }

    /// Generates a filename for a screenshot following the pattern:
    /// screenshot_{session}_{index}_{timestamp}.png
    /// - Parameters:
    ///   - session: The session number
    ///   - index: The screenshot index within the session (1-14)
    /// - Returns: The generated filename string
    private func generateFilename(session: Int, index: Int) -> String {
        let sessionString = String(format: "%03d", session)
        let indexString = String(format: "%02d", index)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())

        return "screenshot_\(sessionString)_\(indexString)_\(timestamp).png"
    }
}
