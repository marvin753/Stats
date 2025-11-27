//
//  ScreenshotStateManager.swift
//  Stats
//
//  Created on 2025-11-10.
//  Purpose: Manages accumulation of multiple screenshots captured via Cmd+Option+O
//  before batch processing with Cmd+Control+P
//

import Foundation
import Combine

/// Manages the accumulation and state of screenshots captured during quiz navigation
@MainActor
final class ScreenshotStateManager: ObservableObject {

    // MARK: - Configuration

    /// Maximum number of screenshots that can be accumulated before warning
    private let maxScreenshots: Int = 20

    // MARK: - Published Properties

    /// Current count of accumulated screenshots (observable for UI updates)
    @Published private(set) var screenshotCount: Int = 0

    /// Indicates if the manager is currently accepting screenshots
    @Published private(set) var isAcceptingScreenshots: Bool = true

    /// Warning message when limits are reached
    @Published private(set) var warningMessage: String?

    /// Expected number of questions for validation
    @Published private(set) var expectedQuestionCount: Int? = nil

    // MARK: - Private Properties

    /// Thread-safe storage for screenshot base64 strings
    private var screenshots: [String] = []

    /// Serial queue for thread-safe operations
    private let queue = DispatchQueue(label: "com.stats.screenshotmanager", qos: .userInitiated)

    // MARK: - Initialization

    init() {
        print("[ScreenshotManager] ScreenshotStateManager initialized")
    }

    // MARK: - Public Methods

    /// Adds a screenshot to the accumulation list
    /// - Parameter base64Image: Base64-encoded screenshot string
    /// - Returns: Success status and optional warning message
    @discardableResult
    func addScreenshot(_ base64Image: String) -> (success: Bool, warning: String?) {
        return queue.sync { [weak self] in
            guard let self = self else {
                return (false, "Manager deallocated")
            }

            // Validate input
            guard !base64Image.isEmpty else {
                print("[ScreenshotManager] ERROR: Attempted to add empty screenshot")
                return (false, "Invalid screenshot data")
            }

            // Check if at capacity
            if self.screenshots.count >= self.maxScreenshots {
                let warning = "Maximum screenshot limit (\(self.maxScreenshots)) reached. Cannot add more screenshots."
                print("[ScreenshotManager] WARNING: \(warning)")

                Task { @MainActor in
                    self.isAcceptingScreenshots = false
                    self.warningMessage = warning
                }

                return (false, warning)
            }

            // Add screenshot
            self.screenshots.append(base64Image)
            let newCount = self.screenshots.count

            print("[ScreenshotManager] Screenshot added. Total count: \(newCount)")

            // Update published properties on main actor
            Task { @MainActor in
                self.screenshotCount = newCount

                // Show warning when approaching limit
                if newCount >= self.maxScreenshots - 5 {
                    let remaining = self.maxScreenshots - newCount
                    self.warningMessage = "Warning: Only \(remaining) screenshot(s) remaining before limit."
                } else {
                    self.warningMessage = nil
                }

                // Disable accepting screenshots if at max
                if newCount >= self.maxScreenshots {
                    self.isAcceptingScreenshots = false
                }
            }

            return (true, nil)
        }
    }

    /// Retrieves all accumulated screenshots for processing
    /// - Returns: Array of base64-encoded screenshot strings
    func getAllScreenshots() -> [String] {
        return queue.sync { [weak self] in
            guard let self = self else { return [] }

            let count = self.screenshots.count
            print("[ScreenshotManager] Retrieving \(count) screenshot(s) for processing")

            return self.screenshots
        }
    }

    /// Clears all accumulated screenshots after processing
    func clearScreenshots() {
        queue.sync { [weak self] in
            guard let self = self else { return }

            let clearedCount = self.screenshots.count
            self.screenshots.removeAll()

            print("[ScreenshotManager] Cleared \(clearedCount) screenshot(s)")

            // Reset published properties on main actor
            Task { @MainActor in
                self.screenshotCount = 0
                self.isAcceptingScreenshots = true
                self.warningMessage = nil
            }
        }
    }

    /// Returns the current count of accumulated screenshots
    /// - Returns: Number of screenshots currently stored
    func getScreenshotCount() -> Int {
        return queue.sync { [weak self] in
            guard let self = self else { return 0 }
            return self.screenshots.count
        }
    }

    /// Checks if the manager has screenshots ready for processing
    /// - Returns: True if at least one screenshot is available
    func isReadyToProcess() -> Bool {
        return queue.sync { [weak self] in
            guard let self = self else { return false }
            let ready = !self.screenshots.isEmpty

            if !ready {
                print("[ScreenshotManager] WARNING: Processing requested but no screenshots available")
            }

            return ready
        }
    }

    /// Removes the most recently added screenshot (undo functionality)
    /// - Returns: True if a screenshot was removed, false if empty
    @discardableResult
    func removeLastScreenshot() -> Bool {
        return queue.sync { [weak self] in
            guard let self = self else { return false }

            guard !self.screenshots.isEmpty else {
                print("[ScreenshotManager] WARNING: Attempted to remove screenshot from empty collection")
                return false
            }

            self.screenshots.removeLast()
            let newCount = self.screenshots.count

            print("[ScreenshotManager] Last screenshot removed. Remaining count: \(newCount)")

            // Update published properties on main actor
            Task { @MainActor in
                self.screenshotCount = newCount
                self.isAcceptingScreenshots = true

                if newCount < self.maxScreenshots - 5 {
                    self.warningMessage = nil
                }
            }

            return true
        }
    }

    /// Gets memory usage estimate for accumulated screenshots
    /// - Returns: Approximate memory usage in megabytes
    func getMemoryUsageEstimate() -> Double {
        return queue.sync { [weak self] in
            guard let self = self else { return 0.0 }

            let totalBytes = self.screenshots.reduce(0) { $0 + $1.utf8.count }
            let megabytes = Double(totalBytes) / 1_048_576.0 // Convert to MB

            return megabytes
        }
    }

    /// Sets the expected number of questions for validation
    /// - Parameter count: Expected number of questions (typically 10-15)
    func setExpectedQuestionCount(_ count: Int) {
        queue.sync {
            Task { @MainActor in
                self.expectedQuestionCount = count
                print("✅ Expected question count set to: \(count)")
            }
        }
    }

    /// Clears the expected question count
    func clearExpectedQuestionCount() {
        queue.sync {
            Task { @MainActor in
                self.expectedQuestionCount = nil
            }
        }
    }

    /// Gets the expected question count
    /// - Returns: Expected number of questions, or nil if not set
    func getExpectedQuestionCount() -> Int? {
        return queue.sync {
            return expectedQuestionCount
        }
    }

    /// Validates all screenshots are properly formatted base64 strings
    /// - Returns: Tuple with validation result and invalid indices
    func validateScreenshots() -> (isValid: Bool, invalidIndices: [Int]) {
        return queue.sync { [weak self] in
            guard let self = self else { return (false, []) }

            var invalidIndices: [Int] = []

            for (index, screenshot) in self.screenshots.enumerated() {
                // Basic validation: check if string can be decoded as base64
                if Data(base64Encoded: screenshot) == nil {
                    invalidIndices.append(index)
                }
            }

            let isValid = invalidIndices.isEmpty

            if !isValid {
                print("[ScreenshotManager] ERROR: Validation failed. Invalid screenshots at indices: \(invalidIndices)")
            }

            return (isValid, invalidIndices)
        }
    }

    // MARK: - Debug Methods

    #if DEBUG
    /// Returns debug information about the current state
    func getDebugInfo() -> String {
        return queue.sync { [weak self] in
            guard let self = self else { return "Manager deallocated" }

            let memoryUsage = self.getMemoryUsageEstimate()

            return """
            ScreenshotStateManager Debug Info:
            - Screenshot Count: \(self.screenshots.count)
            - Max Screenshots: \(self.maxScreenshots)
            - Accepting Screenshots: \(self.isAcceptingScreenshots)
            - Memory Usage: \(String(format: "%.2f", memoryUsage)) MB
            - Warning Message: \(self.warningMessage ?? "None")
            """
        }
    }
    #endif
}

// MARK: - Error Types

extension ScreenshotStateManager {
    enum ScreenshotError: LocalizedError {
        case noScreenshotsAvailable
        case limitReached(max: Int)
        case invalidScreenshotData
        case managerDeallocated

        var errorDescription: String? {
            switch self {
            case .noScreenshotsAvailable:
                return "No screenshots available for processing. Please capture at least one screenshot using Cmd+Option+O."
            case .limitReached(let max):
                return "Maximum screenshot limit of \(max) reached. Please process current screenshots before capturing more."
            case .invalidScreenshotData:
                return "Invalid screenshot data detected. Please try capturing the screenshot again."
            case .managerDeallocated:
                return "Screenshot manager is no longer available."
            }
        }
    }

    /// Attempts to process screenshots with error handling
    /// - Throws: ScreenshotError if validation or processing fails
    func processScreenshots() throws -> [String] {
        guard isReadyToProcess() else {
            throw ScreenshotError.noScreenshotsAvailable
        }

        let validation = validateScreenshots()
        guard validation.isValid else {
            throw ScreenshotError.invalidScreenshotData
        }

        let screenshots = getAllScreenshots()
        print("[ScreenshotManager] Processing \(screenshots.count) validated screenshots")

        return screenshots
    }
}
