#!/usr/bin/swift
import Foundation
import AppKit

print("Testing screenshot capture...")

// Simulate the exact flow from ScreenshotCroppingService
let displayID = CGMainDisplayID()
guard let fullScreenImage = CGDisplayCreateImage(displayID) else {
    print("❌ Failed to capture screen")
    exit(1)
}

let screenWidth = CGFloat(fullScreenImage.width)
let screenHeight = CGFloat(fullScreenImage.height)
print("✓ Screen captured: \(Int(screenWidth))x\(Int(screenHeight))")

// Create a test crop (center 1200x900 region)
let cropRect = CGRect(
    x: (screenWidth - 1200) / 2,
    y: (screenHeight - 900) / 2,
    width: 1200,
    height: 900
)

guard let croppedImage = fullScreenImage.cropping(to: cropRect) else {
    print("❌ Failed to crop")
    exit(1)
}
print("✓ Cropped: \(croppedImage.width)x\(croppedImage.height)")

// THIS IS THE CRITICAL LINE - Create NSImage from CGImage
let croppedNSImage = NSImage(cgImage: croppedImage, size: cropRect.size)
print("✓ NSImage created")

// NOW TEST THE VALIDATION (the part that was crashing)
print("\n=== TESTING VALIDATION ===")
print("Size: \(croppedNSImage.size.width)x\(croppedNSImage.size.height)")
print("Representations: \(croppedNSImage.representations.count)")

// THIS WAS THE CRASH POINT - accessing tiffRepresentation
print("Testing CGImage extraction (NEW SAFE METHOD)...")
if let cgImage = croppedNSImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
    print("✓ CGImage extraction succeeded!")
} else {
    print("❌ CGImage extraction failed")
    exit(1)
}

// NOW TEST PNG CONVERSION
print("\n=== TESTING PNG CONVERSION ===")
if let cgImage = croppedNSImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
    let bitmapImage = NSBitmapImageRep(cgImage: cgImage)

    if let pngData = bitmapImage.representation(using: .png, properties: [:]) {
        print("✓ PNG conversion succeeded! Size: \(pngData.count) bytes")

        // Save to temp file
        let tempURL = URL(fileURLWithPath: "/tmp/test-screenshot.png")
        try? pngData.write(to: tempURL)
        print("✓ Saved to: \(tempURL.path)")
    } else {
        print("❌ PNG conversion failed")
        exit(1)
    }
} else {
    print("❌ CGImage extraction failed")
    exit(1)
}

print("\n✅ ALL TESTS PASSED - No crash!")
