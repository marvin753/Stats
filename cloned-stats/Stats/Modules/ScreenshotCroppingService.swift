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
