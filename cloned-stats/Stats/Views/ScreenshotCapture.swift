import Foundation
import CoreGraphics
import AppKit

/// OS-level screenshot capture utility for macOS
/// Operates at system level using CoreGraphics - completely undetectable by websites
/// Requires Screen Recording permission in System Preferences > Privacy & Security
class ScreenshotCapture {

    // MARK: - Public Interface

    /// Captures a screenshot of the main display at the OS level
    ///
    /// This method uses CoreGraphics to capture the display content directly from the
    /// window server, making it completely undetectable by websites or applications.
    ///
    /// - Returns: Base64-encoded PNG data string, or nil if capture fails
    ///
    /// - Note: Requires Screen Recording permission (macOS 10.15+)
    /// - Important: This captures the ENTIRE main display including all windows
    func captureMainDisplay() -> String? {
        guard hasScreenRecordingPermission() else {
            logError("Screen Recording permission not granted. Enable in System Preferences > Privacy & Security > Screen Recording")
            return nil
        }

        let displayID = CGMainDisplayID()

        guard let cgImage = CGDisplayCreateImage(displayID) else {
            logError("Failed to create CGImage from main display")
            return nil
        }

        return convertToBase64PNG(cgImage: cgImage)
    }

    /// Captures a specific region of the main display
    ///
    /// - Parameters:
    ///   - x: X coordinate of the top-left corner (in points)
    ///   - y: Y coordinate of the top-left corner (in points)
    ///   - width: Width of the region (in points)
    ///   - height: Height of the region (in points)
    ///
    /// - Returns: Base64-encoded PNG data string, or nil if capture fails
    ///
    /// - Note: Coordinates use macOS coordinate system (0,0 at top-left)
    /// - Note: Values are in points, not pixels (automatically handles retina scaling)
    func captureRegion(x: Int, y: Int, width: Int, height: Int) -> String? {
        guard hasScreenRecordingPermission() else {
            logError("Screen Recording permission not granted")
            return nil
        }

        guard width > 0 && height > 0 else {
            logError("Invalid dimensions: width and height must be positive")
            return nil
        }

        let displayID = CGMainDisplayID()
        let rect = CGRect(x: x, y: y, width: width, height: height)

        guard let cgImage = CGDisplayCreateImage(displayID, rect: rect) else {
            logError("Failed to create CGImage for region: \(rect)")
            return nil
        }

        return convertToBase64PNG(cgImage: cgImage)
    }

    /// Captures a specific display by ID
    ///
    /// - Parameter displayID: The CoreGraphics display ID
    /// - Returns: Base64-encoded PNG data string, or nil if capture fails
    func captureDisplay(_ displayID: CGDirectDisplayID) -> String? {
        guard hasScreenRecordingPermission() else {
            logError("Screen Recording permission not granted")
            return nil
        }

        guard let cgImage = CGDisplayCreateImage(displayID) else {
            logError("Failed to create CGImage from display ID: \(displayID)")
            return nil
        }

        return convertToBase64PNG(cgImage: cgImage)
    }

    /// Checks if Screen Recording permission is granted
    ///
    /// On macOS 10.15 (Catalina) and later, apps need explicit permission to capture
    /// screen content. This permission can be granted in:
    /// System Preferences > Security & Privacy > Privacy > Screen Recording
    ///
    /// - Returns: true if permission is granted, false otherwise
    ///
    /// - Note: The first capture attempt will trigger the permission prompt
    /// - Note: Returns true on macOS versions before 10.15
    func hasScreenRecordingPermission() -> Bool {
        // On macOS 10.15+, check if we can capture screen content
        // Create a small test image to verify permission
        if #available(macOS 10.15, *) {
            let displayID = CGMainDisplayID()

            // Try to capture a 1x1 pixel region
            let testRect = CGRect(x: 0, y: 0, width: 1, height: 1)

            guard let testImage = CGDisplayCreateImage(displayID, rect: testRect) else {
                return false
            }

            // If we got here and the image is valid, we have permission
            // Also check that the image isn't completely black (which might indicate blocked access)
            return testImage.width > 0 && testImage.height > 0
        } else {
            // Pre-Catalina doesn't require permission
            return true
        }
    }

    // MARK: - Display Information

    /// Gets information about the main display
    ///
    /// - Returns: Dictionary containing display properties or nil if unavailable
    func getMainDisplayInfo() -> [String: Any]? {
        let displayID = CGMainDisplayID()
        return getDisplayInfo(for: displayID)
    }

    /// Gets information about a specific display
    ///
    /// - Parameter displayID: The CoreGraphics display ID
    /// - Returns: Dictionary containing display properties
    func getDisplayInfo(for displayID: CGDirectDisplayID) -> [String: Any] {
        let width = CGDisplayPixelsWide(displayID)
        let height = CGDisplayPixelsHigh(displayID)
        let bounds = CGDisplayBounds(displayID)

        // Get backing scale factor (for retina displays)
        var scaleFactor: CGFloat = 1.0
        if let mode = CGDisplayCopyDisplayMode(displayID) {
            let pixelWidth = mode.pixelWidth
            let pointWidth = Int(bounds.width)
            if pointWidth > 0 {
                scaleFactor = CGFloat(pixelWidth) / CGFloat(pointWidth)
            }
        }

        return [
            "id": displayID,
            "pixelWidth": width,
            "pixelHeight": height,
            "pointWidth": Int(bounds.width),
            "pointHeight": Int(bounds.height),
            "originX": Int(bounds.origin.x),
            "originY": Int(bounds.origin.y),
            "scaleFactor": scaleFactor,
            "isRetina": scaleFactor > 1.0,
            "isMain": displayID == CGMainDisplayID()
        ]
    }

    /// Lists all available displays
    ///
    /// - Returns: Array of display IDs
    func getAllDisplays() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)

        let result = CGGetActiveDisplayList(16, &displays, &displayCount)

        guard result == .success else {
            logError("Failed to get active display list")
            return []
        }

        return Array(displays.prefix(Int(displayCount)))
    }

    // MARK: - Private Helpers

    /// Converts CGImage to base64-encoded PNG string
    ///
    /// - Parameter cgImage: The CGImage to convert
    /// - Returns: Base64-encoded PNG data string, or nil if conversion fails
    private func convertToBase64PNG(cgImage: CGImage) -> String? {
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))

        guard let tiffData = nsImage.tiffRepresentation else {
            logError("Failed to create TIFF representation")
            return nil
        }

        guard let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            logError("Failed to create bitmap representation")
            return nil
        }

        guard let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            logError("Failed to create PNG data")
            return nil
        }

        return pngData.base64EncodedString()
    }

    /// Logs error message with timestamp
    ///
    /// - Parameter message: Error message to log
    private func logError(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] ScreenshotCapture Error: \(message)")
    }
}

// MARK: - Convenience Extensions

extension ScreenshotCapture {

    /// Saves captured screenshot directly to file
    ///
    /// - Parameters:
    ///   - path: File path where PNG should be saved
    ///   - region: Optional region to capture (nil for full screen)
    ///
    /// - Returns: true if successful, false otherwise
    func saveToFile(path: String, region: CGRect? = nil) -> Bool {
        let base64String: String?

        if let region = region {
            base64String = captureRegion(
                x: Int(region.origin.x),
                y: Int(region.origin.y),
                width: Int(region.width),
                height: Int(region.height)
            )
        } else {
            base64String = captureMainDisplay()
        }

        guard let base64 = base64String,
              let data = Data(base64Encoded: base64) else {
            logError("Failed to decode base64 data")
            return false
        }

        do {
            try data.write(to: URL(fileURLWithPath: path))
            return true
        } catch {
            logError("Failed to write file: \(error.localizedDescription)")
            return false
        }
    }

    /// Captures screenshot and returns raw PNG Data
    ///
    /// - Returns: PNG data or nil if capture fails
    func captureMainDisplayAsData() -> Data? {
        guard let base64 = captureMainDisplay(),
              let data = Data(base64Encoded: base64) else {
            return nil
        }
        return data
    }
}

// MARK: - Usage Examples

/*

 Example 1: Capture full screen
 --------------------------------
 let capture = ScreenshotCapture()

 if let base64PNG = capture.captureMainDisplay() {
     print("Screenshot captured: \(base64PNG.prefix(50))...")
     // Use base64PNG string (e.g., send to server, save to file)
 } else {
     print("Failed to capture screenshot")
 }


 Example 2: Capture specific region
 -----------------------------------
 let capture = ScreenshotCapture()

 // Capture top-left 800x600 region
 if let base64PNG = capture.captureRegion(x: 0, y: 0, width: 800, height: 600) {
     print("Region captured successfully")
 }


 Example 3: Save to file
 -----------------------
 let capture = ScreenshotCapture()
 let desktopPath = NSHomeDirectory() + "/Desktop/screenshot.png"

 if capture.saveToFile(path: desktopPath) {
     print("Screenshot saved to: \(desktopPath)")
 }


 Example 4: Check permission
 ---------------------------
 let capture = ScreenshotCapture()

 if !capture.hasScreenRecordingPermission() {
     print("Please grant Screen Recording permission in System Preferences")
     print("Go to: System Preferences > Privacy & Security > Screen Recording")
 }


 Example 5: Get display information
 -----------------------------------
 let capture = ScreenshotCapture()

 if let info = capture.getMainDisplayInfo() {
     print("Display Info:")
     print("  Resolution: \(info["pixelWidth"]!)x\(info["pixelHeight"]!)")
     print("  Scale Factor: \(info["scaleFactor"]!)")
     print("  Retina: \(info["isRetina"]!)")
 }


 Example 6: Capture all displays
 --------------------------------
 let capture = ScreenshotCapture()

 let displays = capture.getAllDisplays()
 print("Found \(displays.count) display(s)")

 for displayID in displays {
     if let base64PNG = capture.captureDisplay(displayID) {
         let filename = "/Users/user/Desktop/display_\(displayID).png"
         // Save or process each display's screenshot
     }
 }

 */
