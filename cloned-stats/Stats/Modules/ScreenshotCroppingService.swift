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

        // HSB alternative detection
        static let hueMin: CGFloat = 200.0 / 360.0  // 200°
        static let hueMax: CGFloat = 240.0 / 360.0  // 240°
        static let saturationMin: CGFloat = 0.3
        static let brightnessMin: CGFloat = 0.5
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
        print("   Screen height: \(Int(mouseCoords.screenHeight))")

        // Step 2: Capture full screen
        let displayID = CGMainDisplayID()
        guard let fullScreenImage = CGDisplayCreateImage(displayID) else {
            print("❌ [ScreenshotCropping] Failed to capture full screen")
            return nil
        }

        let screenWidth = CGFloat(fullScreenImage.width)
        let screenHeight = CGFloat(fullScreenImage.height)
        print("📺 Full screen captured: \(Int(screenWidth)) x \(Int(screenHeight))")

        // Convert mouse coordinates to top-left origin for CGImage
        let mouseX = Int(mouseCoords.x)
        let mouseY = Int(mouseCoords.topLeftY)

        // Step 3: Use BFS boundary detection to find blue box
        print("🌊 BFS BOUNDARY DETECTION ENABLED - detecting blue box...")

        guard let cropRect = detectBlueBoxFloodFill(
            in: fullScreenImage,
            startX: mouseX,
            startY: mouseY
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

        // Get main screen height for reference
        let screenHeight = NSScreen.main?.frame.height ?? 0

        let coordinates = MouseCoordinates(
            x: mouseLocation.x,
            y: mouseLocation.y,  // Keep native bottom-left origin
            screenHeight: screenHeight,
            timestamp: Date()
        )

        return coordinates
    }

    /// Capture screenshot of screen region at mouse location (async version)
    /// - Parameter mouseCoords: Mouse coordinates to use for cropping
    /// - Returns: Cropped screenshot with metadata
    /// - Throws: CroppingError if capture or cropping fails
    func captureAndCropToBlueBox(at mouseCoords: MouseCoordinates) async throws -> CroppedScreenshot {
        print("\n" + String(repeating: "=", count: 60))
        print("✂️  [ScreenshotCropping] CAPTURING SCREENSHOT AT MOUSE LOCATION")
        print(String(repeating: "=", count: 60))

        // Step 1: Detect blue box bounds at mouse location
        print("🔍 [ScreenshotCropping] Step 1: Detecting blue box at mouse location...")
        print("   Mouse position: X: \(mouseCoords.x), Y: \(mouseCoords.y)")

        guard let cropBounds = await detectBlueBoxAtMouse(mouseCoords) else {
            print("⚠️  [ScreenshotCropping] No blue box detected at mouse location")
            throw CroppingError.noBlueBoxDetected
        }

        print("   Detected box bounds: \(cropBounds)")

        // Step 2: Capture ONLY the detected region using macOS screen capture
        print("📸 [ScreenshotCropping] Step 2: Capturing screen region...")
        guard let screenshot = captureScreenRegion(cropBounds) else {
            throw CroppingError.croppingFailed
        }

        print("   Captured size: \(screenshot.size.width) x \(screenshot.size.height)")

        // Step 3: Convert to base64
        print("📦 [ScreenshotCropping] Step 3: Converting to base64...")
        guard let base64 = imageToBase64(screenshot) else {
            throw CroppingError.base64ConversionFailed
        }

        print("✅ [ScreenshotCropping] Screenshot captured successfully!")
        print("   Image size: ~\(base64.count / 1024)KB")
        print("   IMPORTANT: Captured locally - no browser/website interaction")
        print(String(repeating: "=", count: 60) + "\n")

        return CroppedScreenshot(
            base64Image: base64,
            mouseCoordinates: CGPoint(x: mouseCoords.x, y: mouseCoords.y),
            cropBounds: cropBounds,
            originalDimensions: screenshot.size,
            timestamp: mouseCoords.timestamp
        )
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

        // SAFETY CHECK 3: Validate starting pixel index
        let startIndex = (startY * bytesPerRow) + (startX * bytesPerPixel)
        guard startIndex + 2 < pixelDataLength else {
            print("   ❌ Starting pixel index out of data bounds: \(startIndex)")
            return createFallbackRect(mouseX: startX, mouseY: startY, screenWidth: width, screenHeight: height)
        }

        // Check if starting pixel is blue
        let startR = pixels[startIndex]
        let startG = pixels[startIndex + 1]
        let startB = pixels[startIndex + 2]

        print("   🎨 Starting pixel color: R=\(startR), G=\(startG), B=\(startB)")

        // Blue pixel detection with tolerance
        let isStartBlue = isBluePixel(r: startR, g: startG, b: startB)

        if !isStartBlue {
            print("   ⚠️  Starting position is not on a blue pixel - using fallback")
            return createFallbackRect(mouseX: startX, mouseY: startY, screenWidth: width, screenHeight: height)
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
            pixelDataLength: pixelDataLength
        )
    }

    /// Helper: Create fallback crop rectangle (1200x900 centered on mouse)
    private func createFallbackRect(mouseX: Int, mouseY: Int, screenWidth: Int, screenHeight: Int) -> CGRect {
        let fallbackWidth = min(1200, screenWidth)
        let fallbackHeight = min(900, screenHeight)

        let x = max(0, min(mouseX - fallbackWidth / 2, screenWidth - fallbackWidth))
        let y = max(0, min(mouseY - fallbackHeight / 2, screenHeight - fallbackHeight))

        print("   📦 Using fallback crop: \(fallbackWidth)x\(fallbackHeight) at (\(x), \(y))")
        return CGRect(x: x, y: y, width: fallbackWidth, height: fallbackHeight)
    }

    /// Blue pixel detection with tolerance (blue > 200 AND blue > red+green)
    private func isBluePixel(r: UInt8, g: UInt8, b: UInt8) -> Bool {
        // Blue must be dominant (> 200) AND greater than red+green combined
        return b > 200 && Int(b) > Int(r) + Int(g)
    }

    /// SAFE iterative BFS to find blue box boundaries
    private func detectBlueBoundariesBFS(
        pixels: UnsafePointer<UInt8>,
        startX: Int,
        startY: Int,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        bytesPerPixel: Int,
        pixelDataLength: Int
    ) -> CGRect? {

        // SAFETY LIMITS
        let maxPixelsToCheck = 500_000  // Stop after checking 500k pixels
        let maxBoxWidth = 2000
        let maxBoxHeight = 2000

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

        print("   🌊 [BFS] Starting iterative BFS flood-fill (queue-based, no recursion)")
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

            // Check 4-connected neighbors (up, down, left, right)
            let neighbors = [
                (currentX - 1, currentY),  // left
                (currentX + 1, currentY),  // right
                (currentX, currentY - 1),  // up
                (currentX, currentY + 1)   // down
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

                // PIXEL DATA BOUNDS CHECK
                let pixelIndex = (ny * bytesPerRow) + (nx * bytesPerPixel)
                guard pixelIndex + 2 < pixelDataLength else {
                    continue
                }

                // Get pixel color
                let r = pixels[pixelIndex]
                let g = pixels[pixelIndex + 1]
                let b = pixels[pixelIndex + 2]

                // Check if blue pixel
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

        let boxWidth = maxX - minX
        let boxHeight = maxY - minY

        print("   📏 [BFS] Detected dimensions: \(boxWidth) x \(boxHeight) pixels")

        // VALIDATION: Minimum box size (filter noise)
        if boxWidth < 50 || boxHeight < 50 {
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
    private func findNearestBluePixel(
        pixels: UnsafePointer<UInt8>,
        startX: Int,
        startY: Int,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        bytesPerPixel: Int,
        searchRadius: Int
    ) -> (x: Int, y: Int)? {

        // Search in expanding squares from center
        for radius in 1...searchRadius {
            // Check all points at this radius
            for dx in -radius...radius {
                for dy in -radius...radius {
                    // Only check points on the perimeter of the square
                    if abs(dx) != radius && abs(dy) != radius { continue }

                    let x = startX + dx
                    let y = startY + dy

                    // Validate pixel coordinates
                    guard isValidPixel(x: x, y: y, width: width, height: height) else { continue }

                    // Calculate pixel index and validate bounds
                    let index = (y * bytesPerRow) + (x * bytesPerPixel)
                    guard index + 2 < bytesPerRow * height else { continue }

                    let r = pixels[index]
                    let g = pixels[index + 1]
                    let b = pixels[index + 2]

                    if isBluePixelEnhanced(r: r, g: g, b: b) {
                        return (x, y)
                    }
                }
            }
        }

        return nil
    }

    /// Detect blue box boundaries from a confirmed blue starting point
    private func detectBlueBoxFromPoint(
        pixels: UnsafePointer<UInt8>,
        startX: Int,
        startY: Int,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        bytesPerPixel: Int
    ) -> CGRect? {

        print("   🌊 Starting flood-fill from (\(startX), \(startY))...")

        // Validate starting position
        guard isValidPixel(x: startX, y: startY, width: width, height: height) else {
            print("   ❌ Starting pixel out of bounds: (\(startX), \(startY))")
            return nil
        }

        // Initialize bounds
        var minX = startX
        var maxX = startX
        var minY = startY
        var maxY = startY

        // Flood-fill using BFS queue
        var visited = Set<Int>()  // Use single Int key for performance
        var queue: [(x: Int, y: Int)] = [(startX, startY)]
        let startKey = startY * width + startX
        visited.insert(startKey)

        var pixelCount = 0

        // Safety limit to prevent infinite loops
        let maxIterations = 500_000

        while !queue.isEmpty && pixelCount < maxIterations {
            let (x, y) = queue.removeFirst()
            pixelCount += 1

            // Update bounds
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)

            // Check 4 neighbors (up, down, left, right)
            let neighbors = [
                (x - 1, y),  // left
                (x + 1, y),  // right
                (x, y - 1),  // up
                (x, y + 1)   // down
            ]

            for (nx, ny) in neighbors {
                // CRITICAL: Bounds checking
                guard isValidPixel(x: nx, y: ny, width: width, height: height) else {
                    continue  // Skip out-of-bounds pixels
                }

                // Check if already visited
                let key = ny * width + nx
                guard !visited.contains(key) else { continue }

                // CRITICAL: Check if pixel index is within data bounds
                let pixelIndex = (ny * bytesPerRow) + (nx * bytesPerPixel)

                // Ensure we can safely read RGB values (need 3 bytes)
                guard pixelIndex + 2 < bytesPerRow * height else {
                    print("   ⚠️  Pixel index out of data bounds: \(pixelIndex)")
                    continue
                }

                // Get pixel color
                let r = pixels[pixelIndex]
                let g = pixels[pixelIndex + 1]
                let b = pixels[pixelIndex + 2]

                // Check if this pixel is part of the blue box (blue or inside the box)
                if isPartOfBlueBox(r: r, g: g, b: b, pixels: pixels, x: nx, y: ny,
                                   width: width, height: height, bytesPerRow: bytesPerRow,
                                   bytesPerPixel: bytesPerPixel) {
                    visited.insert(key)
                    queue.append((nx, ny))
                }
            }
        }

        if pixelCount >= maxIterations {
            print("   ⚠️  Flood-fill reached iteration limit (\(maxIterations))")
        }

        print("   📊 Flood-fill complete: processed \(pixelCount) pixels")
        print("   📐 Raw bounds: X[\(minX)-\(maxX)] Y[\(minY)-\(maxY)]")

        // Calculate box dimensions
        let boxWidth = maxX - minX
        let boxHeight = maxY - minY

        // Validate minimum box size (filter out noise)
        let minBoxSize = 50
        if boxWidth < minBoxSize || boxHeight < minBoxSize {
            print("   ⚠️  Detected region too small (\(boxWidth)x\(boxHeight)), likely noise")
            return nil
        }

        // Add padding and clamp to screen bounds
        let paddedMinX = max(0, CGFloat(minX) - boxPadding)
        let paddedMinY = max(0, CGFloat(minY) - boxPadding)
        let paddedMaxX = min(CGFloat(width), CGFloat(maxX) + boxPadding)
        let paddedMaxY = min(CGFloat(height), CGFloat(maxY) + boxPadding)

        let finalRect = CGRect(
            x: paddedMinX,
            y: paddedMinY,
            width: paddedMaxX - paddedMinX,
            height: paddedMaxY - paddedMinY
        )

        print("   ✅ Final crop rect with padding: \(finalRect)")
        print("   📦 Size: \(Int(finalRect.width))x\(Int(finalRect.height)) pixels")
        print("   🔁 Iterations: \(pixelCount)")

        return finalRect
    }

    /// Check if a pixel is part of the blue box (blue border or interior content)
    private func isPartOfBlueBox(
        r: UInt8, g: UInt8, b: UInt8,
        pixels: UnsafePointer<UInt8>,
        x: Int, y: Int,
        width: Int, height: Int,
        bytesPerRow: Int,
        bytesPerPixel: Int
    ) -> Bool {
        // Read RGB values safely (already validated by caller)
        let rInt = Int(r)
        let gInt = Int(g)
        let bInt = Int(b)

        // First check: is it a blue pixel (the box border)?
        if isBluePixelEnhanced(r: r, g: g, b: b) {
            return true
        }

        // Second check: is it light/white content inside the box?
        // Quiz boxes typically have white/light gray interior
        if isLightPixel(r: r, g: g, b: b) {
            return true
        }

        // Third check: is it dark text inside the box?
        if isDarkTextPixel(r: r, g: g, b: b) {
            return true
        }

        return false
    }

    /// Enhanced blue pixel detection using both RGB and HSB
    private func isBluePixelEnhanced(r: UInt8, g: UInt8, b: UInt8) -> Bool {
        // Method 1: RGB range check (typical quiz blue: RGB ~50-100, 100-180, 200-255)
        let rgbMatch = (
            r >= BlueColorRange.redMin && r <= BlueColorRange.redMax &&
            g >= BlueColorRange.greenMin && g <= BlueColorRange.greenMax &&
            b >= BlueColorRange.blueMin && b <= BlueColorRange.blueMax
        )

        if rgbMatch {
            return true
        }

        // Method 2: HSB check for broader blue detection
        let color = NSColor(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: 1.0
        )

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        // Convert to HSB
        if let hsbColor = color.usingColorSpace(.sRGB) {
            hsbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

            // Check HSB range: Hue 200-240°, Saturation > 0.3, Brightness > 0.5
            let hsbMatch = (
                hue >= BlueColorRange.hueMin && hue <= BlueColorRange.hueMax &&
                saturation >= BlueColorRange.saturationMin &&
                brightness >= BlueColorRange.brightnessMin
            )

            if hsbMatch {
                return true
            }
        }

        // Method 3: Simple blue dominance check
        let blueDominance: UInt8 = 40
        if b > 150 && b > r + blueDominance && b > g + blueDominance {
            return true
        }

        return false
    }

    /// Check if pixel is light (white/light gray - box interior)
    private func isLightPixel(r: UInt8, g: UInt8, b: UInt8) -> Bool {
        // Light pixels have high values in all channels and are roughly equal
        let threshold: UInt8 = 200
        let maxDiff: UInt8 = 30

        if r >= threshold && g >= threshold && b >= threshold {
            let maxVal = max(r, max(g, b))
            let minVal = min(r, min(g, b))
            return (maxVal - minVal) <= maxDiff
        }

        return false
    }

    /// Check if pixel is dark text
    private func isDarkTextPixel(r: UInt8, g: UInt8, b: UInt8) -> Bool {
        // Dark text pixels have low values in all channels
        let threshold: UInt8 = 80
        return r <= threshold && g <= threshold && b <= threshold
    }

    /// Create fallback crop rectangle centered on mouse position
    private func createFallbackCropRect(
        mouseX: CGFloat,
        mouseY: CGFloat,
        screenWidth: CGFloat,
        screenHeight: CGFloat
    ) -> CGRect {
        let halfWidth = fallbackCropSize.width / 2
        let halfHeight = fallbackCropSize.height / 2

        // Calculate bounds, clamping to screen
        let minX = max(0, mouseX - halfWidth)
        let minY = max(0, mouseY - halfHeight)
        let maxX = min(screenWidth, mouseX + halfWidth)
        let maxY = min(screenHeight, mouseY + halfHeight)

        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }

    // MARK: - Legacy Detection Method (Async)

    /// Detect blue box bounds at mouse location by sampling screen pixels
    /// Uses flood-fill algorithm to find exact boundaries - adapts to ANY box size
    /// - Parameter mouseCoords: Mouse coordinates
    /// - Returns: Bounding rectangle of detected blue box, or nil if not found
    private func detectBlueBoxAtMouse(_ mouseCoords: MouseCoordinates) async -> CGRect? {
        print("   🔍 Starting adaptive blue box detection...")

        // Step 1: Capture a larger sample region to work with
        let sampleSize: CGFloat = 800  // Large enough to capture full box
        let sampleRect = CGRect(
            x: mouseCoords.x - sampleSize / 2,
            y: mouseCoords.y - sampleSize / 2,
            width: sampleSize,
            height: sampleSize
        )

        guard let sampleImage = captureScreenRegion(sampleRect) else {
            print("   ❌ Failed to capture sample region")
            return nil
        }

        // Step 2: Convert to CGImage for pixel access
        guard let cgImage = sampleImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("   ❌ Failed to convert to CGImage")
            return nil
        }

        // Step 3: Get pixel data
        guard let dataProvider = cgImage.dataProvider,
              let pixelData = dataProvider.data,
              let pixels = CFDataGetBytePtr(pixelData) else {
            print("   ❌ Failed to get pixel data")
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = cgImage.bytesPerRow

        // Step 4: Find mouse position in sample image coordinates
        let mouseInSample = CGPoint(
            x: sampleSize / 2,
            y: sampleSize / 2
        )

        // Step 5: Check if mouse is over blue pixel
        let mousePixelX = Int(mouseInSample.x)
        let mousePixelY = Int(mouseInSample.y)

        guard mousePixelX >= 0 && mousePixelX < width && mousePixelY >= 0 && mousePixelY < height else {
            print("   ❌ Mouse position out of bounds")
            return nil
        }

        // Validate pixel index is within bounds
        let pixelIndex = (mousePixelY * bytesPerRow) + (mousePixelX * bytesPerPixel)
        let pixelDataLength = CFDataGetLength(pixelData)

        guard pixelIndex + 2 < pixelDataLength else {
            print("   ❌ Pixel index out of data bounds: \(pixelIndex)")
            return nil
        }

        let r = pixels[pixelIndex]
        let g = pixels[pixelIndex + 1]
        let b = pixels[pixelIndex + 2]

        if !isBluePixelEnhanced(r: r, g: g, b: b) {
            print("   ⚠️  Mouse not over blue pixel (R:\(r) G:\(g) B:\(b))")
            return nil
        }

        print("   ✅ Mouse over blue pixel - starting flood-fill...")

        // Step 6: Use flood-fill to find all connected blue pixels
        var visited = Set<String>()
        var minX = mousePixelX
        var maxX = mousePixelX
        var minY = mousePixelY
        var maxY = mousePixelY

        // Flood-fill using queue (BFS)
        var queue: [(x: Int, y: Int)] = [(mousePixelX, mousePixelY)]
        visited.insert("\(mousePixelX),\(mousePixelY)")

        // Safety limit to prevent infinite loops
        let maxIterations = 500_000
        var iterations = 0

        while !queue.isEmpty && iterations < maxIterations {
            let (x, y) = queue.removeFirst()
            iterations += 1

            // Update bounds
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)

            // Check 4 neighbors (up, down, left, right)
            let neighbors = [
                (x - 1, y),  // left
                (x + 1, y),  // right
                (x, y - 1),  // up
                (x, y + 1)   // down
            ]

            for (nx, ny) in neighbors {
                // CRITICAL: Bounds checking
                guard isValidPixel(x: nx, y: ny, width: width, height: height) else {
                    continue  // Skip out-of-bounds pixels
                }

                // Check if already visited
                let key = "\(nx),\(ny)"
                guard !visited.contains(key) else { continue }

                // CRITICAL: Check if pixel index is within data bounds
                let nPixelIndex = (ny * bytesPerRow) + (nx * bytesPerPixel)
                guard nPixelIndex + 2 < pixelDataLength else {
                    print("   ⚠️  Pixel index out of data bounds: \(nPixelIndex)")
                    continue
                }

                // Get pixel color
                let nr = pixels[nPixelIndex]
                let ng = pixels[nPixelIndex + 1]
                let nb = pixels[nPixelIndex + 2]

                // Check if blue or part of box content
                if isPartOfBlueBox(r: nr, g: ng, b: nb, pixels: pixels, x: nx, y: ny,
                                   width: width, height: height, bytesPerRow: bytesPerRow,
                                   bytesPerPixel: bytesPerPixel) {
                    visited.insert(key)
                    queue.append((nx, ny))
                }
            }
        }

        if iterations >= maxIterations {
            print("   ⚠️  Flood-fill reached iteration limit (\(maxIterations))")
        }

        print("   📊 Flood-fill complete: found \(visited.count) pixels")

        // Step 7: Calculate bounding box with padding
        let padding: CGFloat = boxPadding
        let boxWidth = CGFloat(maxX - minX)
        let boxHeight = CGFloat(maxY - minY)

        print("   📐 Detected box size: \(boxWidth) x \(boxHeight)")

        // Convert back to screen coordinates
        let screenX = sampleRect.origin.x + CGFloat(minX) - padding
        let screenY = sampleRect.origin.y + CGFloat(minY) - padding
        let screenWidth = boxWidth + (padding * 2)
        let screenHeight = boxHeight + (padding * 2)

        let bounds = CGRect(
            x: screenX,
            y: screenY,
            width: screenWidth,
            height: screenHeight
        )

        print("   ✅ Adaptive detection complete!")
        print("   📦 Final bounds: X:\(Int(screenX)) Y:\(Int(screenY)) W:\(Int(screenWidth)) H:\(Int(screenHeight))")
        print("   🎯 Algorithm automatically adapted to box size")

        return bounds
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
