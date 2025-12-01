//
//  ScreenshotCroppingService.swift
//  Stats
//
//  Created on 2025-11-19.
//  Purpose: Captures mouse coordinates and crops screenshots to blue question boxes
//

import Foundation
import AppKit
import CoreGraphics

// MARK: - LAB Color Space Types

/// Represents a color in LAB color space
private struct LABColor {
    let L: Double  // Lightness (0-100)
    let a: Double  // Green-Red component (-128 to 127)
    let b: Double  // Blue-Yellow component (-128 to 127)
}

/// Convert RGB (0-255) to LAB color space
private func rgbToLAB(r: UInt8, g: UInt8, b: UInt8) -> LABColor {
    // Step 1: RGB to XYZ (sRGB with D65 illuminant)
    var rLinear = Double(r) / 255.0
    var gLinear = Double(g) / 255.0
    var bLinear = Double(b) / 255.0

    // Apply gamma correction (sRGB)
    rLinear = rLinear > 0.04045 ? pow((rLinear + 0.055) / 1.055, 2.4) : rLinear / 12.92
    gLinear = gLinear > 0.04045 ? pow((gLinear + 0.055) / 1.055, 2.4) : gLinear / 12.92
    bLinear = bLinear > 0.04045 ? pow((bLinear + 0.055) / 1.055, 2.4) : bLinear / 12.92

    // Convert to XYZ (D65 reference white)
    let x = rLinear * 0.4124564 + gLinear * 0.3575761 + bLinear * 0.1804375
    let y = rLinear * 0.2126729 + gLinear * 0.7151522 + bLinear * 0.0721750
    let z = rLinear * 0.0193339 + gLinear * 0.1191920 + bLinear * 0.9503041

    // Step 2: XYZ to LAB
    // Reference white D65: X=0.95047, Y=1.0, Z=1.08883
    let xRef = x / 0.95047
    let yRef = y / 1.0
    let zRef = z / 1.08883

    func f(_ t: Double) -> Double {
        let delta: Double = 6.0 / 29.0
        return t > pow(delta, 3) ? pow(t, 1.0/3.0) : t / (3 * delta * delta) + 4.0/29.0
    }

    let L = 116.0 * f(yRef) - 16.0
    let a = 500.0 * (f(xRef) - f(yRef))
    let labB = 200.0 * (f(yRef) - f(zRef))

    return LABColor(L: L, a: a, b: labB)
}

/// Calculate Delta E (CIE76) color distance between two LAB colors
private func deltaE(_ lab1: LABColor, _ lab2: LABColor) -> Double {
    let dL = lab1.L - lab2.L
    let da = lab1.a - lab2.a
    let db = lab1.b - lab2.b
    return sqrt(dL * dL + da * da + db * db)
}

// MARK: - Robust Detection Configuration

/// Configuration for LAB-based robust detection algorithm
private struct RobustDetectionConfig {
    /// ΔE threshold for interior color matching (configurable: 12-16)
    static var interiorDeltaE: Double = 15.0

    /// ΔE threshold for border detection (configurable: 25-35)
    static var borderDeltaE: Double = 30.0

    /// ΔE threshold to distinguish border from white
    static var borderToWhiteDeltaE: Double = 10.0

    /// Minimum continuous border pixels required
    static let minContinuousBorderPixels: Int = 3

    /// Maximum pixels before aborting (safety limit)
    static let maxFloodFillPixels: Int = 800_000

    /// Sample region size for interior color
    static let sampleSize: Int = 5

    /// Max distance to scan for borders
    static let maxBorderScanDistance: Int = 50

    /// Reference white in LAB space
    static let whiteLAB = LABColor(L: 100.0, a: 0.0, b: 0.0)
}

/// Service for capturing mouse coordinates and cropping screenshots to specific regions
@MainActor
class ScreenshotCroppingService {

    // MARK: - Singleton

    static let shared = ScreenshotCroppingService()

    // MARK: - Configuration

    /// Blue color range for question box detection (typical quiz blue)
    /// RGB approximately (50-100, 100-180, 200-255)
    private struct BlueColorRange {
        // RGB ranges for blue detection
        static let redMin: UInt8 = 50
        static let redMax: UInt8 = 150
        static let greenMin: UInt8 = 100
        static let greenMax: UInt8 = 200
        static let blueMin: UInt8 = 180
        static let blueMax: UInt8 = 255
    }

    /// Padding around detected box (in pixels)
    private let boxPadding: CGFloat = 15.0

    /// Fallback crop size when no blue box detected
    private let fallbackCropSize = CGSize(width: 800, height: 600)

    /// Maximum sample region size for flood-fill
    private let maxSampleSize: CGFloat = 1200

    /// Maximum pixels to process in flood-fill (performance limit)
    private let maxFloodFillPixels = 500000

    // MARK: - Data Models

    struct CroppedScreenshot {
        let base64Image: String
        let mouseCoordinates: CGPoint  // Bottom-left origin
        let cropBounds: CGRect
        let originalDimensions: CGSize
        let timestamp: Date
    }

    struct MouseCoordinates {
        let x: CGFloat
        let y: CGFloat  // Bottom-left origin (NSEvent uses this)
        let screenHeight: CGFloat
        let timestamp: Date

        /// Convert to top-left origin (for CGImage operations)
        var topLeftY: CGFloat {
            return screenHeight - y
        }
    }

    // MARK: - Initialization

    private init() {
        print("🔧 [ScreenshotCropping] ScreenshotCroppingService initialized")
    }

    // MARK: - Public Methods

    /// Capture blue box at current mouse position and save as PNG file
    /// This method is an alias for captureAndCropScreenshot() for backward compatibility
    /// - Returns: Tuple of PNG file URL and mouse coordinates, or nil on failure
    func captureBlueBoxAtMousePosition() -> (imageURL: URL, mouseCoords: (x: CGFloat, y: CGFloat))? {
        guard let result = captureAndCropScreenshot() else {
            return nil
        }

        guard let imageURL = result.imageURL else {
            print("❌ [ScreenshotCropping] captureAndCropScreenshot returned nil imageURL")
            return nil
        }

        return (imageURL: imageURL, mouseCoords: result.mouseCoords)
    }

    // MARK: - Robust Blue Box Detection (LAB Color Space Algorithm)

    /// Capture blue box using robust LAB color space flood-fill algorithm
    /// This algorithm is designed to handle boxes with 80%+ white interior content
    /// - Returns: Tuple of image URL and mouse coordinates, or nil on failure
    func captureBlueBoxRobust() -> (imageURL: URL?, mouseCoords: (x: CGFloat, y: CGFloat))? {
        print("\n" + String(repeating: "=", count: 60))
        print("🎯 [RobustCapture] ROBUST BLUE BOX DETECTION (LAB Color Space)")
        print(String(repeating: "=", count: 60))

        // BUG FIX #1: Check Screen Recording permission FIRST
        if #available(macOS 10.15, *) {
            let hasPermission = CGPreflightScreenCaptureAccess()
            if !hasPermission {
                print("❌ [RobustCapture] Screen Recording permission NOT GRANTED")
                print("   Go to System Preferences → Security & Privacy → Privacy → Screen Recording")
                print("   Add Stats to the list and enable it")
                CGRequestScreenCaptureAccess()
                return nil
            }
            print("✅ [RobustCapture] Screen Recording permission granted")
        }

        // STEP 1: Capture full-screen screenshot
        let displayID = CGMainDisplayID()
        guard let fullScreenImage = CGDisplayCreateImage(displayID) else {
            print("❌ [RobustCapture] Failed to capture full screen")
            return nil
        }

        // STEP 2: Get mouse position
        let mouseCoords = captureMouseCoordinates()
        let scale = NSScreen.main?.backingScaleFactor ?? 1.0
        let screenHeightPoints = mouseCoords.screenHeight
        let actualScaling = CGFloat(fullScreenImage.height) / screenHeightPoints

        let mouseXPixels = Int(mouseCoords.x * actualScaling)
        let mouseYTopLeftPoints = screenHeightPoints - mouseCoords.y
        let mouseYPixels = Int(mouseYTopLeftPoints * actualScaling)

        print("🖱️  Mouse pixels: (\(mouseXPixels), \(mouseYPixels))")

        // STEP 3-8: Detect blue box using LAB flood-fill
        guard let cropRect = detectBlueBoxLAB(
            in: fullScreenImage,
            startX: mouseXPixels,
            startY: mouseYPixels
        ) else {
            print("❌ [RobustCapture] LAB detection failed")
            return nil
        }

        // Crop and save
        guard let croppedImage = fullScreenImage.cropping(to: cropRect) else {
            print("❌ [RobustCapture] Failed to crop image")
            return nil
        }

        let croppedNSImage = NSImage(cgImage: croppedImage, size: cropRect.size)
        guard let fileURL = ScreenshotFileManager.shared.saveScreenshot(croppedNSImage) else {
            print("❌ [RobustCapture] Failed to save screenshot")
            return nil
        }

        print("✅ [RobustCapture] Screenshot saved: \(fileURL.lastPathComponent)")
        return (imageURL: fileURL, mouseCoords: (x: mouseCoords.x, y: mouseCoords.y))
    }

    /// Capture blue box at current mouse position and save as PNG - MAIN METHOD
    /// This method:
    /// 1. Captures current mouse position
    /// 2. Takes a full screen screenshot
    /// 3. Uses BFS boundary detection to find blue box (ENABLED)
    /// 4. Saves cropped image as PNG file
    /// - Returns: Tuple of image URL and mouse coordinates, or nil on failure
    func captureAndCropScreenshot() -> (imageURL: URL?, mouseCoords: (x: CGFloat, y: CGFloat))? {
        print("\n" + String(repeating: "=", count: 60))
        print("📸 [ScreenshotCropping] CAPTURING SCREENSHOT AT MOUSE POSITION")
        print(String(repeating: "=", count: 60))

        // Check Screen Recording permission before attempting capture
        if #available(macOS 10.15, *) {
            let hasPermission = CGPreflightScreenCaptureAccess()
            if !hasPermission {
                print("❌ [ScreenshotCropping] Screen Recording permission NOT GRANTED")
                print("   To fix:")
                print("   1. Open System Preferences")
                print("   2. Go to Security & Privacy → Privacy → Screen Recording")
                print("   3. Add 'Stats' to the list and enable it")
                print("   4. Restart the Stats app")
                return nil
            } else {
                print("✅ [ScreenshotCropping] Screen Recording permission granted")
            }
        }

        // Step 1: Capture current mouse position
        let mouseCoords = captureMouseCoordinates()
        print("🖱️  Mouse position: X=\(Int(mouseCoords.x)), Y=\(Int(mouseCoords.y)) (bottom-left origin)")
        print("   Screen height: \(Int(mouseCoords.screenHeight)) points")

        // Step 2: Capture full screen
        let displayID = CGMainDisplayID()
        guard let fullScreenImage = CGDisplayCreateImage(displayID) else {
            print("❌ [ScreenshotCropping] Failed to capture full screen")
            return nil
        }

        let screenWidth = CGFloat(fullScreenImage.width)
        let screenHeight = CGFloat(fullScreenImage.height)
        print("📺 Full screen captured: \(Int(screenWidth)) x \(Int(screenHeight)) pixels")

        // FIX 1: Detect Retina display scaling
        let scale = NSScreen.main?.backingScaleFactor ?? 1.0
        print("🖥️  Display scale factor: \(scale)x (Retina: \(scale > 1.0))")

        // Calculate scaling relationship
        let screenHeightPoints = mouseCoords.screenHeight
        let actualScaling = screenHeight / screenHeightPoints
        print("📏 Actual scaling: \(actualScaling) (pixels/points)")

        // Convert mouse coordinates to pixel space (accounting for Retina)
        let mouseXPixels = Int(mouseCoords.x * actualScaling)
        let mouseYPoints = mouseCoords.y  // In points from bottom
        let mouseYTopLeftPoints = screenHeightPoints - mouseYPoints  // Convert to top-left origin in points
        let mouseYPixels = Int(mouseYTopLeftPoints * actualScaling)  // Convert to pixels

        print("🔄 Coordinate conversion:")
        print("   Mouse points: (\(Int(mouseCoords.x)), \(Int(mouseCoords.y)))")
        print("   Mouse pixels: (\(mouseXPixels), \(mouseYPixels)) [top-left origin]")

        // Step 3: Use BFS boundary detection to find blue box
        print("🌊 BFS BOUNDARY DETECTION ENABLED - detecting blue box...")

        guard let cropRect = detectBlueBoxFloodFill(
            in: fullScreenImage,
            startX: mouseXPixels,  // FIX: Use pixel coordinates, not points
            startY: mouseYPixels   // FIX: Use pixel coordinates, not points
        ) else {
            print("❌ [ScreenshotCropping] BFS detection failed")
            return nil
        }

        print("📐 BFS detected boundary: X=\(Int(cropRect.origin.x)), Y=\(Int(cropRect.origin.y)), W=\(Int(cropRect.width)), H=\(Int(cropRect.height))")

        // Step 4: Crop the screenshot
        guard let croppedImage = fullScreenImage.cropping(to: cropRect) else {
            print("❌ [ScreenshotCropping] Failed to crop image")
            return nil
        }

        print("✂️  Cropped to: \(croppedImage.width) x \(croppedImage.height)")

        // Step 5: Convert to NSImage and save as individual PNG file
        let croppedNSImage = NSImage(cgImage: croppedImage, size: cropRect.size)

        let screenshotFileManager = ScreenshotFileManager.shared

        guard let fileURL = screenshotFileManager.saveScreenshot(croppedNSImage) else {
            print("❌ [ScreenshotCropping] Failed to save screenshot")
            return nil
        }

        print("✅ Screenshot captured and saved successfully!")
        print("   File: \(fileURL.lastPathComponent)")
        print("   Session: \(screenshotFileManager.getCurrentSessionNumber())")
        print("   Count: \(screenshotFileManager.getCurrentSessionCount())/14")
        print("   Image size: \(croppedImage.width) x \(croppedImage.height)")
        print(String(repeating: "=", count: 60) + "\n")

        return (imageURL: fileURL, mouseCoords: (x: mouseCoords.x, y: mouseCoords.y))
    }

    /// Capture current mouse coordinates (native macOS coordinates)
    /// - Returns: MouseCoordinates with bottom-left origin
    func captureMouseCoordinates() -> MouseCoordinates {
        // Get mouse location in screen coordinates (bottom-left origin)
        let mouseLocation = NSEvent.mouseLocation

        // FIX: Get the screen that actually contains the mouse, not just the main screen
        // This fixes multi-monitor issues where NSScreen.main may differ from the display being captured
        let screenContainingMouse = NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        } ?? NSScreen.main

        let screenHeight = screenContainingMouse?.frame.height ?? NSScreen.main?.frame.height ?? 0

        let coordinates = MouseCoordinates(
            x: mouseLocation.x,
            y: mouseLocation.y,  // Keep native bottom-left origin
            screenHeight: screenHeight,
            timestamp: Date()
        )

        return coordinates
    }


    /// LAB-based blue box detection using FLOOD-FILL algorithm with Delta E
    /// Uses LAB color space for perceptual color matching
    /// FIX: Now uses same blue detection as detectBlueBoxFloodFill() with safety limits
    private func detectBlueBoxLAB(in image: CGImage, startX: Int, startY: Int) -> CGRect? {
        let width = image.width
        let height = image.height

        guard startX >= 0 && startX < width && startY >= 0 && startY < height else {
            return nil
        }

        guard let dataProvider = image.dataProvider,
              let pixelData = dataProvider.data,
              let ptr = CFDataGetBytePtr(pixelData) else {
            return nil
        }

        let bytesPerRow = image.bytesPerRow
        let bytesPerPixel = 4  // BGRA format

        // SAFETY LIMITS - prevent infinite loops and performance issues
        let maxPixelsToCheck = 2_000_000  // Maximum pixels to process
        let maxBoxWidth = 3000
        let maxBoxHeight = 2500

        print("   🎯 LAB FLOOD-FILL: Using same blue detection as working method")
        print("   🖱️  Start position: (\(startX), \(startY))")
        print("   📐 Image dimensions: \(width) x \(height)")
        print("   🛡️  Safety limits: max \(maxPixelsToCheck) pixels, box ≤ \(maxBoxWidth)x\(maxBoxHeight)")

        // Helper: Get pixel RGB values (BGRA format)
        func getPixelRGB(x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8)? {
            guard x >= 0 && x < width && y >= 0 && y < height else { return nil }
            let offset = (y * bytesPerRow) + (x * bytesPerPixel)
            // BGRA format: Blue, Green, Red, Alpha
            let b = ptr[offset + 0]
            let g = ptr[offset + 1]
            let r = ptr[offset + 2]
            return (r, g, b)
        }

        // Helper: Check if color is blue using SAME logic as working detectBlueBoxFloodFill()
        // This is the CORRECT blue detection that works for quiz boxes
        func isBluePixel(r: UInt8, g: UInt8, b: UInt8) -> Bool {
            let rInt = Int(r)
            let gInt = Int(g)
            let bInt = Int(b)

            // Use the same 5 criteria as the working method
            // Criteria 1: Light blue with blue > green > red pattern
            let lightBluePattern = bInt > gInt && gInt > rInt && b > 200

            // Criteria 2: Blue is highest channel by at least 10 points
            let blueHighestInLightColor = bInt > max(rInt, gInt) + 10 &&
                                          r > 150 && g > 150 && b > 200

            // Criteria 3: Blue tint - not white, not gray
            let isNotWhite = r < 250 || g < 250 || b < 250
            let hasBlueTint = bInt >= gInt && gInt >= rInt && (bInt - rInt) > 30
            let blueTintedColor = isNotWhite && hasBlueTint && b > 180

            // Criteria 4: Strong blue dominance
            let strongBlueDominance = bInt > max(rInt, gInt) + 20 && b > 100

            // Criteria 5: Exact match for quiz blue (R:195, G:222, B:239) with tolerance ±30
            let matchesQuizBlue = (r >= 165 && r <= 225) &&
                                  (g >= 192 && g <= 252) &&
                                  (b >= 209 && b <= 255) &&
                                  bInt > gInt && gInt > rInt

            return lightBluePattern || blueHighestInLightColor ||
                   blueTintedColor || strongBlueDominance || matchesQuizBlue
        }

        // Visited set and queue
        var visited = Set<Int>()
        func idx(_ x: Int, _ y: Int) -> Int { y * width + x }
        var queue: [(Int, Int)] = []

        // 1) Find start point (search ±5 pixels around mouse for better coverage)
        var foundStart = false
        outerLoop: for dy in -5...5 {
            for dx in -5...5 {
                let x = startX + dx, y = startY + dy
                if x >= 0 && y >= 0 && x < width && y < height {
                    if let (r, g, b) = getPixelRGB(x: x, y: y), isBluePixel(r: r, g: g, b: b) {
                        queue.append((x, y))
                        foundStart = true
                        print("   ✅ Found blue start pixel at (\(x), \(y)) - RGB: (\(r), \(g), \(b))")
                        break outerLoop
                    }
                }
            }
        }

        if !foundStart {
            print("   ❌ No blue pixel found within ±5 of mouse position")
            return nil
        }

        var minX = width, minY = height, maxX = 0, maxY = 0
        var pixelsChecked = 0

        // 2) Flood-fill through connected blue pixels with SAFETY LIMITS
        while !queue.isEmpty && pixelsChecked < maxPixelsToCheck {
            let (x, y) = queue.removeFirst()
            let id = idx(x, y)

            if visited.contains(id) { continue }
            visited.insert(id)
            pixelsChecked += 1

            // Validate pixel is still blue
            guard let (r, g, b) = getPixelRGB(x: x, y: y), isBluePixel(r: r, g: g, b: b) else {
                continue
            }

            // Update bounding box
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)

            // SAFETY CHECK: Box size exceeded maximum
            let boxWidth = maxX - minX
            let boxHeight = maxY - minY
            if boxWidth > maxBoxWidth || boxHeight > maxBoxHeight {
                print("   ⚠️  Box size exceeded maximum (\(boxWidth)x\(boxHeight)) - stopping early")
                break
            }

            // Add 8-connected neighbors (includes diagonals for anti-aliased edges)
            let neighbors = [
                (x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1),
                (x - 1, y - 1), (x + 1, y - 1), (x - 1, y + 1), (x + 1, y + 1)
            ]

            for (nx, ny) in neighbors {
                if nx >= 0 && ny >= 0 && nx < width && ny < height {
                    let nid = idx(nx, ny)
                    if !visited.contains(nid) {
                        queue.append((nx, ny))
                    }
                }
            }
        }

        // Check if we hit safety limits
        if pixelsChecked >= maxPixelsToCheck {
            print("   ⚠️  Hit safety limit of \(maxPixelsToCheck) pixels - likely wrong detection")
        }

        // Validate result
        let boxWidth = maxX - minX + 1
        let boxHeight = maxY - minY + 1

        print("   📊 Flood-fill visited \(visited.count) pixels (checked \(pixelsChecked))")
        print("   📐 Bounding box: \(boxWidth)x\(boxHeight) at (\(minX), \(minY))")

        if boxWidth < 50 || boxHeight < 50 {
            print("   ❌ Detected box too small: \(boxWidth)x\(boxHeight)")
            return nil
        }

        print("   ✅ Blue box detected: \(boxWidth)x\(boxHeight) at (\(minX), \(minY))")

        // Add padding
        let padding: CGFloat = 10
        let paddedX = max(0, CGFloat(minX) - padding)
        let paddedY = max(0, CGFloat(minY) - padding)
        let paddedWidth = min(CGFloat(width) - paddedX, CGFloat(boxWidth) + 2 * padding)
        let paddedHeight = min(CGFloat(height) - paddedY, CGFloat(boxHeight) + 2 * padding)

        return CGRect(x: paddedX, y: paddedY, width: paddedWidth, height: paddedHeight)
    }

    /// Check if a pixel has stronger blue saturation than the interior (for border detection)
    private func hasStrongerBlueSaturation(_ pixel: LABColor, than interior: LABColor) -> Bool {
        // In LAB: negative 'b' = blue, positive 'b' = yellow
        // Stronger blue = more negative 'b' value
        return pixel.b < interior.b - 5.0  // At least 5 units more blue
    }

    /// Check if a pixel is darker than the interior (for border detection)
    private func isDarkerThanInterior(_ pixel: LABColor, interior: LABColor) -> Bool {
        // Border is darker (lower L value) than interior
        return pixel.L < interior.L - 10.0  // At least 10 units darker on L scale
    }

    /// STEP 6: Scan outward from inner rectangle edges to find border
    /// CRITICAL: Must find 2-3 CONTINUOUS border pixels with:
    ///   - ΔE to interior > 25
    ///   - ΔE to white > 10
    ///   - Stronger blue saturation than interior
    /// ROBUST: Scans at 3 sampling lines (25%, 50%, 75%) and takes MEDIAN
    ///         This prevents failures when white diagrams overlap the midpoint
    private func scanForBorders(
        pixels: UnsafePointer<UInt8>,
        bytesPerRow: Int,
        bytesPerPixel: Int,
        pixelDataLength: Int,
        width: Int,
        height: Int,
        interiorLAB: LABColor,
        innerMinX: Int,
        innerMaxX: Int,
        innerMinY: Int,
        innerMaxY: Int,
        isBGRA: Bool,
        hasAlphaFirst: Bool
    ) -> (left: Int, right: Int, top: Int, bottom: Int) {

        let borderDeltaE = RobustDetectionConfig.borderDeltaE
        let borderToWhiteDeltaE = RobustDetectionConfig.borderToWhiteDeltaE
        let minContinuousPixels = RobustDetectionConfig.minContinuousBorderPixels
        let maxScanDistance = RobustDetectionConfig.maxBorderScanDistance
        let whiteLAB = RobustDetectionConfig.whiteLAB

        /// Get pixel LAB value with correct byte order
        func getPixelLAB(x: Int, y: Int) -> LABColor? {
            guard x >= 0 && x < width && y >= 0 && y < height else { return nil }
            let idx = y * bytesPerRow + x * bytesPerPixel
            guard idx + 3 < pixelDataLength else { return nil }

            let pR: UInt8, pG: UInt8, pB: UInt8
            if isBGRA {
                pR = pixels[idx + 2]
                pG = pixels[idx + 1]
                pB = pixels[idx]
            } else if hasAlphaFirst {
                pR = pixels[idx + 1]
                pG = pixels[idx + 2]
                pB = pixels[idx + 3]
            } else {
                pR = pixels[idx]
                pG = pixels[idx + 1]
                pB = pixels[idx + 2]
            }
            return rgbToLAB(r: pR, g: pG, b: pB)
        }

        func isBorderPixel(_ lab: LABColor) -> Bool {
            let distToInterior = deltaE(interiorLAB, lab)
            let distToWhite = deltaE(whiteLAB, lab)

            // Relaxed border detection: must be different from both interior AND white
            // Removed strict darkness/blue requirements that were too restrictive
            return distToInterior > borderDeltaE && distToWhite > borderToWhiteDeltaE
        }

        /// Check if pixel qualifies as interior (close to sampled interior color)
        func isInteriorPixel(_ lab: LABColor) -> Bool {
            return deltaE(interiorLAB, lab) < RobustDetectionConfig.interiorDeltaE
        }

        /// Check for N continuous border pixels in given direction
        /// INCLUDES border thickness verification:
        /// - One pixel outward must also be border (≥2px thick)
        /// - One pixel inward must be interior
        func findContinuousBorder(startX: Int, startY: Int, dx: Int, dy: Int) -> Int? {
            var consecutiveCount = 0
            var borderPosition: Int? = nil
            var firstBorderX: Int? = nil
            var firstBorderY: Int? = nil

            for step in 0..<maxScanDistance {
                let x = startX + step * dx
                let y = startY + step * dy

                guard let lab = getPixelLAB(x: x, y: y) else {
                    // Out of bounds = edge of screen, use as border
                    return dx != 0 ? x - dx : y - dy
                }

                if isBorderPixel(lab) {
                    consecutiveCount += 1
                    if borderPosition == nil {
                        borderPosition = dx != 0 ? x : y
                        firstBorderX = x
                        firstBorderY = y
                    }
                    if consecutiveCount >= minContinuousPixels {
                        // RELAXED THICKNESS VERIFICATION
                        guard let bx = firstBorderX, let by = firstBorderY else {
                            return borderPosition
                        }

                        // Check one pixel INWARD from detected border (should be interior or white)
                        let inwardX = bx - dx
                        let inwardY = by - dy
                        let inwardIsValid: Bool
                        if let inwardLab = getPixelLAB(x: inwardX, y: inwardY) {
                            // Accept if inward pixel is interior OR very close to white (content)
                            let isInterior = isInteriorPixel(inwardLab)
                            let isWhiteContent = deltaE(whiteLAB, inwardLab) < 20.0
                            inwardIsValid = isInterior || isWhiteContent
                        } else {
                            inwardIsValid = false
                        }

                        // Accept if inward check passes (relaxed from requiring both inward AND outward)
                        if inwardIsValid {
                            return borderPosition
                        } else if consecutiveCount >= minContinuousPixels + 2 {
                            // If we have many continuous border pixels, accept anyway
                            return borderPosition
                        } else {
                            // Failed check - continue scanning
                            consecutiveCount = 0
                            borderPosition = nil
                            firstBorderX = nil
                            firstBorderY = nil
                        }
                    }
                } else {
                    consecutiveCount = 0
                    borderPosition = nil
                    firstBorderX = nil
                    firstBorderY = nil
                }
            }

            return nil
        }

        /// Helper to compute median of up to 3 values (ignores nil)
        func median(_ values: [Int?]) -> Int? {
            let valid = values.compactMap { $0 }.sorted()
            guard !valid.isEmpty else { return nil }
            return valid[valid.count / 2]  // Middle element (or lower-middle for even count)
        }

        // Calculate 3 sampling positions at 25%, 50%, 75% of each span
        let ySpan = innerMaxY - innerMinY
        let xSpan = innerMaxX - innerMinX

        let y25 = innerMinY + ySpan / 4
        let y50 = innerMinY + ySpan / 2
        let y75 = innerMinY + (3 * ySpan) / 4

        let x25 = innerMinX + xSpan / 4
        let x50 = innerMinX + xSpan / 2
        let x75 = innerMinX + (3 * xSpan) / 4

        // Scan RIGHT at 3 lines (y25, y50, y75), take median (X-axis priority)
        let rightCandidates = [
            findContinuousBorder(startX: innerMaxX, startY: y25, dx: 1, dy: 0),
            findContinuousBorder(startX: innerMaxX, startY: y50, dx: 1, dy: 0),
            findContinuousBorder(startX: innerMaxX, startY: y75, dx: 1, dy: 0)
        ]
        let borderRight = median(rightCandidates) ?? innerMaxX + 10

        // Scan LEFT at 3 lines
        let leftCandidates = [
            findContinuousBorder(startX: innerMinX, startY: y25, dx: -1, dy: 0),
            findContinuousBorder(startX: innerMinX, startY: y50, dx: -1, dy: 0),
            findContinuousBorder(startX: innerMinX, startY: y75, dx: -1, dy: 0)
        ]
        let borderLeft = median(leftCandidates) ?? max(0, innerMinX - 10)

        // Scan DOWN at 3 lines (x25, x50, x75)
        let bottomCandidates = [
            findContinuousBorder(startX: x25, startY: innerMaxY, dx: 0, dy: 1),
            findContinuousBorder(startX: x50, startY: innerMaxY, dx: 0, dy: 1),
            findContinuousBorder(startX: x75, startY: innerMaxY, dx: 0, dy: 1)
        ]
        let borderBottom = median(bottomCandidates) ?? innerMaxY + 10

        // Scan UP at 3 lines
        let topCandidates = [
            findContinuousBorder(startX: x25, startY: innerMinY, dx: 0, dy: -1),
            findContinuousBorder(startX: x50, startY: innerMinY, dx: 0, dy: -1),
            findContinuousBorder(startX: x75, startY: innerMinY, dx: 0, dy: -1)
        ]
        let borderTop = median(topCandidates) ?? max(0, innerMinY - 10)

        print("   🔍 Border scan (3-line median, requires \(minContinuousPixels) continuous):")
        print("      Right candidates: \(rightCandidates) → median: \(borderRight)")
        print("      Left candidates: \(leftCandidates) → median: \(borderLeft)")
        print("      Bottom candidates: \(bottomCandidates) → median: \(borderBottom)")
        print("      Top candidates: \(topCandidates) → median: \(borderTop)")

        return (borderLeft, borderRight, borderTop, borderBottom)
    }

    // MARK: - Blue Box Detection (Flood-Fill Algorithm)

    /// Helper method to validate pixel coordinates are within image bounds
    /// - Parameters:
    ///   - x: X coordinate to check
    ///   - y: Y coordinate to check
    ///   - width: Image width
    ///   - height: Image height
    /// - Returns: true if pixel is within bounds, false otherwise
    private func isValidPixel(x: Int, y: Int, width: Int, height: Int) -> Bool {
        return x >= 0 && x < width && y >= 0 && y < height
    }

    /// Helper method to read pixel RGB values with correct byte order
    /// FIX: Simplified to assume BGRA (little-endian) which is the standard on macOS
    /// macOS CGDisplayCreateImage always returns BGRA format (byteOrder32Little with premultiplied alpha)
    /// - Parameters:
    ///   - pixels: Raw pixel data
    ///   - index: Starting index for this pixel
    /// - Returns: Tuple of (R, G, B) values
    private func readPixelRGB(pixels: UnsafePointer<UInt8>, index: Int) -> (r: UInt8, g: UInt8, b: UInt8) {
        // macOS CGDisplayCreateImage returns BGRA format (most common):
        // Byte 0 = Blue, Byte 1 = Green, Byte 2 = Red, Byte 3 = Alpha
        let b = pixels[index]
        let g = pixels[index + 1]
        let r = pixels[index + 2]
        // Alpha at index + 3 (unused)
        return (r, g, b)
    }

    /// Legacy method for compatibility - delegates to simplified version
    private func readPixelBGRA(pixels: UnsafePointer<UInt8>, index: Int, isBGRA: Bool, hasAlphaFirst: Bool) -> (r: UInt8, g: UInt8, b: UInt8) {
        // Always use the simplified BGRA reader for macOS screenshots
        return readPixelRGB(pixels: pixels, index: index)
    }

    /// SAFE boundary detection algorithm using iterative BFS (NO RECURSION)
    /// Detects blue box boundaries starting from mouse position
    /// - Parameters:
    ///   - image: The full screen CGImage
    ///   - startX: Starting X coordinate (top-left origin)
    ///   - startY: Starting Y coordinate (top-left origin)
    /// - Returns: Bounding rectangle of detected blue box with padding, or nil if not found
    private func detectBlueBoxFloodFill(in image: CGImage, startX: Int, startY: Int) -> CGRect? {
        let width = image.width
        let height = image.height

        print("   🔍 Starting SAFE boundary detection from (\(startX), \(startY))")
        print("   📐 Image dimensions: \(width) x \(height)")
        print("   🌊 Using BFS boundary detection...")

        // SAFETY CHECK 1: Validate starting position
        guard startX >= 0 && startX < width && startY >= 0 && startY < height else {
            print("   ❌ Start position out of bounds: (\(startX), \(startY))")
            return createFallbackRect(mouseX: startX, mouseY: startY, screenWidth: width, screenHeight: height)
        }

        // SAFETY CHECK 2: Get pixel data
        guard let dataProvider = image.dataProvider,
              let pixelData = dataProvider.data,
              let pixels = CFDataGetBytePtr(pixelData) else {
            print("   ❌ Failed to get pixel data")
            return createFallbackRect(mouseX: startX, mouseY: startY, screenWidth: width, screenHeight: height)
        }

        let bytesPerPixel = image.bitsPerPixel / 8
        let bytesPerRow = image.bytesPerRow
        let pixelDataLength = CFDataGetLength(pixelData)

        print("   📊 Pixel format: \(bytesPerPixel) bytes/pixel, \(bytesPerRow) bytes/row")

        // FIX 2: Detect pixel byte order (BGRA vs RGBA vs ARGB)
        let bitmapInfo = image.bitmapInfo
        let alphaInfo = CGImageAlphaInfo(rawValue: bitmapInfo.rawValue & CGBitmapInfo.alphaInfoMask.rawValue)
        let byteOrderInfo = bitmapInfo.rawValue & CGBitmapInfo.byteOrderMask.rawValue

        // Determine pixel component positions
        let isBGRA = byteOrderInfo == CGBitmapInfo.byteOrder32Little.rawValue
        let hasAlphaFirst = (alphaInfo == .premultipliedFirst || alphaInfo == .first)

        print("   🎨 Pixel format detection:")
        print("      Bitmap info: \(bitmapInfo.rawValue)")
        print("      Alpha info: \(alphaInfo?.rawValue ?? 0)")
        print("      Byte order: \(byteOrderInfo == CGBitmapInfo.byteOrder32Little.rawValue ? "Little (BGRA)" : "Big (RGBA)")")
        print("      Format: \(isBGRA ? "BGRA" : "RGBA") with alpha \(hasAlphaFirst ? "first" : "last")")

        // SAFETY CHECK 3: Validate starting pixel index
        let startIndex = (startY * bytesPerRow) + (startX * bytesPerPixel)
        guard startIndex + 3 < pixelDataLength else {  // Need 4 bytes for BGRA/RGBA
            print("   ❌ Starting pixel index out of data bounds: \(startIndex)")
            return createFallbackRect(mouseX: startX, mouseY: startY, screenWidth: width, screenHeight: height)
        }

        // Read pixel with correct byte order
        let (startR, startG, startB) = readPixelBGRA(pixels: pixels, index: startIndex, isBGRA: isBGRA, hasAlphaFirst: hasAlphaFirst)

        print("   🎨 Starting pixel color: R=\(startR), G=\(startG), B=\(startB)")

        // Blue pixel detection with tolerance
        let isStartBlue = isBluePixel(r: startR, g: startG, b: startB)

        // Debug: Show blue detection criteria
        print("   🔍 Blue detection analysis:")
        print("      Blue dominance: B(\(startB)) > max(R(\(startR)),G(\(startG)))+30 = \(Int(startB) > max(Int(startR), Int(startG)) + 30)")
        print("      Minimum blue: B(\(startB)) > 120 = \(startB > 120)")
        let totalRGB = Int(startR) + Int(startG) + Int(startB)
        let blueRatio = totalRGB > 0 ? Double(startB) / Double(totalRGB) : 0.0
        print("      Blue ratio: B/Total = \(String(format: "%.2f", blueRatio)) > 0.35 = \(blueRatio > 0.35)")
        print("      Result: \(isStartBlue ? "✅ IS BLUE" : "❌ NOT BLUE")")

        if !isStartBlue {
            print("   ⚠️  Starting position is not on a blue pixel")
            print("   🔍 Searching for nearby blue pixel within 50px radius...")

            // FIX 1: Try to find nearby blue pixel before falling back
            if let nearbyBlue = findNearestBluePixel(
                pixels: pixels,
                startX: startX,
                startY: startY,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow,
                bytesPerPixel: bytesPerPixel,
                searchRadius: 100,  // Increased from 50 for better blue box detection
                isBGRA: isBGRA,
                hasAlphaFirst: hasAlphaFirst
            ) {
                print("   ✅ Found blue pixel at (\(nearbyBlue.x), \(nearbyBlue.y)) - starting BFS from there")

                // Use the nearby blue pixel as starting point for BFS
                return detectBlueBoundariesBFS(
                    pixels: pixels,
                    startX: nearbyBlue.x,
                    startY: nearbyBlue.y,
                    width: width,
                    height: height,
                    bytesPerRow: bytesPerRow,
                    bytesPerPixel: bytesPerPixel,
                    pixelDataLength: pixelDataLength,
                    isBGRA: isBGRA,
                    hasAlphaFirst: hasAlphaFirst
                )
            } else {
                print("   ❌ No blue pixels found within 50px radius - using fallback")
                print("   💡 Tip: Ensure mouse is positioned closer to the blue border")
                return createFallbackRect(mouseX: startX, mouseY: startY, screenWidth: width, screenHeight: height)
            }
        }

        print("   ✅ Starting pixel is blue - beginning BFS boundary detection")

        // ITERATIVE BFS (NO RECURSION) with safety limits
        return detectBlueBoundariesBFS(
            pixels: pixels,
            startX: startX,
            startY: startY,
            width: width,
            height: height,
            bytesPerRow: bytesPerRow,
            bytesPerPixel: bytesPerPixel,
            pixelDataLength: pixelDataLength,
            isBGRA: isBGRA,
            hasAlphaFirst: hasAlphaFirst
        )
    }

    /// Helper: Create fallback crop rectangle (800x600 centered on mouse)
    private func createFallbackRect(mouseX: Int, mouseY: Int, screenWidth: Int, screenHeight: Int) -> CGRect {
        // FIX 3: Reduced fallback size from 1200x900 to 800x600 for more reasonable default
        let fallbackWidth = min(800, screenWidth)
        let fallbackHeight = min(600, screenHeight)

        let x = max(0, min(mouseX - fallbackWidth / 2, screenWidth - fallbackWidth))
        let y = max(0, min(mouseY - fallbackHeight / 2, screenHeight - fallbackHeight))

        print("   📦 Using fallback crop: \(fallbackWidth)x\(fallbackHeight) at (\(x), \(y))")
        return CGRect(x: x, y: y, width: fallbackWidth, height: fallbackHeight)
    }

    /// Blue pixel detection for light pastel blue (R:195, G:222, B:239)
    /// This is a light UI blue with HIGH values in all channels
    private func isBluePixel(r: UInt8, g: UInt8, b: UInt8) -> Bool {
        let rInt = Int(r)
        let gInt = Int(g)
        let bInt = Int(b)

        // CRITICAL: Detect the exact quiz blue (R:195, G:222, B:239)
        // This is a light pastel blue with HIGH values in all channels

        // Criteria 1: Light blue with blue > green > red pattern
        // For R:195, G:222, B:239: blue(239) > green(222) > red(195) ✓
        let lightBluePattern = bInt > gInt && gInt > rInt && b > 200

        // Criteria 2: Blue is highest channel by at least 10 points
        // AND all channels are high (light color, > 150)
        let blueHighestInLightColor = bInt > max(rInt, gInt) + 10 &&
                                       r > 150 && g > 150 && b > 200

        // Criteria 3: Blue tint - not white, not gray, blue component highest
        // White: R≈G≈B≈255, Gray: R≈G≈B
        // Blue tint: B >= G >= R, and difference from white
        let isNotWhite = r < 250 || g < 250 || b < 250
        let hasBlueTint = bInt >= gInt && gInt >= rInt && (bInt - rInt) > 30
        let blueTintedColor = isNotWhite && hasBlueTint && b > 180

        // Criteria 4: Strong blue dominance (keep for darker blues)
        let strongBlueDominance = bInt > max(rInt, gInt) + 20 && b > 100

        // Criteria 5: Exact match for quiz blue (with tolerance ±30)
        // Target: R:195, G:222, B:239
        let matchesQuizBlue = (r >= 165 && r <= 225) &&
                              (g >= 192 && g <= 252) &&
                              (b >= 209 && b <= 255) &&
                              bInt > gInt && gInt > rInt

        return lightBluePattern || blueHighestInLightColor ||
               blueTintedColor || strongBlueDominance || matchesQuizBlue
    }

    /// SAFE iterative BFS to find blue box boundaries
    /// FIX: Uses 8-connected neighbors for better coverage of anti-aliased edges
    private func detectBlueBoundariesBFS(
        pixels: UnsafePointer<UInt8>,
        startX: Int,
        startY: Int,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        bytesPerPixel: Int,
        pixelDataLength: Int,
        isBGRA: Bool,
        hasAlphaFirst: Bool
    ) -> CGRect? {

        // SAFETY LIMITS - FIX: Increased from 500k to 2 million for larger boxes
        let maxPixelsToCheck = 2_000_000
        let maxBoxWidth = 3000
        let maxBoxHeight = 2500

        // Track visited pixels using Set (fast lookup)
        var visited = Set<Int>()

        // BFS queue (iterative, NO recursion)
        var queue: [(x: Int, y: Int)] = [(startX, startY)]

        // Bounding box
        var minX = startX
        var maxX = startX
        var minY = startY
        var maxY = startY

        // Mark starting pixel as visited
        visited.insert(startY * width + startX)

        var pixelsChecked = 0

        print("   🌊 [BFS] Starting iterative BFS flood-fill (8-connected, queue-based)")
        print("   📊 [BFS] Starting point: (\(startX), \(startY))")
        print("   📊 [BFS] Image dimensions: \(width) x \(height)")
        print("   📊 [BFS] Max pixels to check: \(maxPixelsToCheck)")

        // ITERATIVE BFS LOOP
        while !queue.isEmpty && pixelsChecked < maxPixelsToCheck {
            // Dequeue next pixel
            let (currentX, currentY) = queue.removeFirst()
            pixelsChecked += 1

            // Update bounding box
            minX = min(minX, currentX)
            maxX = max(maxX, currentX)
            minY = min(minY, currentY)
            maxY = max(maxY, currentY)

            // SAFETY CHECK: Box size exceeded
            if (maxX - minX) > maxBoxWidth || (maxY - minY) > maxBoxHeight {
                print("   ⚠️  Box size exceeded maximum (\(maxX - minX)x\(maxY - minY)) - stopping")
                break
            }

            // FIX: Check 8-connected neighbors (includes diagonals for anti-aliased edges)
            let neighbors = [
                (currentX - 1, currentY),      // left
                (currentX + 1, currentY),      // right
                (currentX, currentY - 1),      // up
                (currentX, currentY + 1),      // down
                (currentX - 1, currentY - 1),  // top-left diagonal
                (currentX + 1, currentY - 1),  // top-right diagonal
                (currentX - 1, currentY + 1),  // bottom-left diagonal
                (currentX + 1, currentY + 1)   // bottom-right diagonal
            ]

            for (nx, ny) in neighbors {
                // BOUNDS CHECK
                guard nx >= 0 && nx < width && ny >= 0 && ny < height else {
                    continue
                }

                // VISITED CHECK
                let visitKey = ny * width + nx
                guard !visited.contains(visitKey) else {
                    continue
                }

                // PIXEL DATA BOUNDS CHECK - use bytesPerRow for proper stride
                let pixelIndex = (ny * bytesPerRow) + (nx * bytesPerPixel)
                guard pixelIndex + 3 < pixelDataLength else {
                    continue
                }

                // Get pixel color using simplified BGRA reader
                let (r, g, b) = readPixelRGB(pixels: pixels, index: pixelIndex)

                // Check if blue pixel with relaxed threshold
                if isBluePixel(r: r, g: g, b: b) {
                    visited.insert(visitKey)
                    queue.append((nx, ny))
                }
            }
        }

        print("   ✅ [BFS] BFS complete!")
        print("   📊 [BFS] Total pixels checked: \(pixelsChecked)")
        print("   📊 [BFS] Blue pixels found: \(visited.count)")
        print("   📐 [BFS] Raw detected bounds: X[\(minX)-\(maxX)] Y[\(minY)-\(maxY)]")

        // FIX: Add +1 for correct width/height calculation (maxX - minX is off by one)
        let boxWidth = maxX - minX + 1
        let boxHeight = maxY - minY + 1

        print("   📏 [BFS] Detected dimensions: \(boxWidth) x \(boxHeight) pixels")

        // VALIDATION: Minimum box size (filter noise) - FIX: Reduced to 15x15
        if boxWidth < 15 || boxHeight < 15 {
            print("   ⚠️  [BFS] Detected box too small (\(boxWidth)x\(boxHeight)) - likely noise, using fallback")
            return createFallbackRect(mouseX: startX, mouseY: startY, screenWidth: width, screenHeight: height)
        }

        // Add 10-pixel padding
        let padding: CGFloat = 10
        let paddedX = max(0, CGFloat(minX) - padding)
        let paddedY = max(0, CGFloat(minY) - padding)
        let paddedWidth = min(CGFloat(width) - paddedX, CGFloat(boxWidth) + 2 * padding)
        let paddedHeight = min(CGFloat(height) - paddedY, CGFloat(boxHeight) + 2 * padding)

        let finalRect = CGRect(x: paddedX, y: paddedY, width: paddedWidth, height: paddedHeight)

        print("   📦 [BFS] Final crop with padding: \(Int(paddedWidth))x\(Int(paddedHeight)) at (\(Int(paddedX)), \(Int(paddedY)))")

        return finalRect
    }

    /// Find nearest blue pixel within search radius
    /// FIX: Uses true spiral search checking ALL points, not just perimeter
    /// This ensures we don't miss blue pixels that are closer but not on the perimeter ring
    private func findNearestBluePixel(
        pixels: UnsafePointer<UInt8>,
        startX: Int,
        startY: Int,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        bytesPerPixel: Int,
        searchRadius: Int,
        isBGRA: Bool,
        hasAlphaFirst: Bool
    ) -> (x: Int, y: Int)? {

        // FIX: Use true spiral search by distance (Euclidean) for better nearest-pixel finding
        // Collect all candidates within radius and sort by actual distance
        var candidates: [(x: Int, y: Int, distance: Double)] = []

        for dy in -searchRadius...searchRadius {
            for dx in -searchRadius...searchRadius {
                let x = startX + dx
                let y = startY + dy

                // Skip if out of bounds
                guard isValidPixel(x: x, y: y, width: width, height: height) else { continue }

                // Calculate actual Euclidean distance
                let distance = sqrt(Double(dx * dx + dy * dy))

                // Skip if beyond circular radius
                if distance > Double(searchRadius) { continue }

                // Calculate pixel index and validate bounds
                let index = (y * bytesPerRow) + (x * bytesPerPixel)
                guard index + 3 < bytesPerRow * height else { continue }

                // Use simplified BGRA reader
                let (r, g, b) = readPixelRGB(pixels: pixels, index: index)

                // Check if blue pixel
                if isBluePixel(r: r, g: g, b: b) {
                    candidates.append((x: x, y: y, distance: distance))
                }
            }
        }

        // Return the closest blue pixel found
        if let nearest = candidates.min(by: { $0.distance < $1.distance }) {
            return (nearest.x, nearest.y)
        }

        return nil
    }



    // MARK: - Screen Capture Methods

    /// Capture a specific region of the screen using macOS APIs (LOCAL ONLY)
    /// - Parameter rect: Screen region to capture
    /// - Returns: Captured image, or nil if capture fails
    private func captureScreenRegion(_ rect: CGRect) -> NSImage? {
        // Use CGWindowListCreateImage to capture screen region
        // This is completely local - no browser/website interaction
        guard let cgImage = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            return nil
        }

        let image = NSImage(cgImage: cgImage, size: rect.size)
        return image
    }

    // MARK: - Image Conversion Methods

    /// Convert CGImage to base64 PNG string
    /// - Parameter image: CGImage to convert
    /// - Returns: Base64-encoded PNG string, or nil if conversion fails
    private func cgImageToBase64(_ image: CGImage) -> String? {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return nil
        }
        return pngData.base64EncodedString()
    }

    /// Convert NSImage to base64 PNG string
    /// - Parameter image: Image to convert
    /// - Returns: Base64-encoded PNG string, or nil if conversion fails
    private func imageToBase64(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            return nil
        }

        return pngData.base64EncodedString()
    }
}

// MARK: - Error Types

enum CroppingError: LocalizedError {
    case invalidImageData
    case noBlueBoxDetected
    case croppingFailed
    case base64ConversionFailed

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Failed to convert screenshot to image format"
        case .noBlueBoxDetected:
            return "No blue question box detected at mouse location. Please position mouse over a question box."
        case .croppingFailed:
            return "Failed to crop image to detected bounds"
        case .base64ConversionFailed:
            return "Failed to convert cropped image to base64"
        }
    }
}
