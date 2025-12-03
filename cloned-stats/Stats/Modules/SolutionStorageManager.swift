import Foundation

/// Manages persistent storage of OpenAI solution responses
/// Handles both historical tracking (JSON) and current solution storage (plain text)
final class SolutionStorageManager {

    // MARK: - Singleton

    static let shared = SolutionStorageManager()

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    // File paths
    private let allSolutionsPath = "/Users/marvinbarsal/Desktop/Universität/Stats/all_solutions.json"
    private let currentSolutionPath = "/Users/marvinbarsal/Desktop/Universität/Stats/current_solution.txt"

    // Thread-safe access
    private let queue = DispatchQueue(label: "com.stats.solutionStorage", attributes: .concurrent)

    // MARK: - Models

    struct Solution: Codable, Identifiable {
        let id: String
        let timestamp: String
        let question: String
        let answers: [String]
        let solution: String
        let characterCount: Int

        init(id: String = UUID().uuidString,
             timestamp: String = ISO8601DateFormatter().string(from: Date()),
             question: String,
             answers: [String],
             solution: String) {
            self.id = id
            self.timestamp = timestamp
            self.question = question
            self.answers = answers
            self.solution = solution
            self.characterCount = solution.count
        }
    }

    struct SolutionHistory: Codable {
        var solutions: [Solution]
        var totalCount: Int
        var lastUpdated: String

        init(solutions: [Solution] = []) {
            self.solutions = solutions
            self.totalCount = solutions.count
            self.lastUpdated = ISO8601DateFormatter().string(from: Date())
        }
    }

    // MARK: - Initialization

    private init() {
        // Configure JSON encoder/decoder
        jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        jsonDecoder = JSONDecoder()

        // Ensure files exist
        ensureFilesExist()
    }

    // MARK: - Logging Helper

    private func log(_ message: String) {
        print("[SolutionStorage] \(message)")
    }

    // MARK: - Public Methods

    /// Saves a new solution to both storage files
    /// - Parameters:
    ///   - question: The question text
    ///   - answers: Array of answer options
    ///   - solution: The complete solution text from OpenAI
    /// - Returns: Success status
    @discardableResult
    func saveSolution(question: String, answers: [String], solution: String) -> Bool {
        log("💾 Saving new solution (length: \(solution.count) chars)")

        var success = true

        // Create solution object
        let newSolution = Solution(
            question: question,
            answers: answers,
            solution: solution
        )

        // Save to history (JSON)
        if !saveToHistory(newSolution) {
            log("❌ Failed to save solution to history")
            success = false
        }

        // Save as current solution (plain text)
        if !saveCurrentSolution(solution) {
            log("❌ Failed to save current solution text")
            success = false
        }

        if success {
            log("✅ Solution saved successfully (ID: \(newSolution.id))")
        }

        return success
    }

    /// Retrieves the current solution text for injection
    /// - Returns: The plain text solution or nil if not available
    func getCurrentSolutionText() -> String? {
        return queue.sync {
            log("📖 Reading current solution text")

            guard fileManager.fileExists(atPath: currentSolutionPath) else {
                log("⚠️ Current solution file does not exist")
                return nil
            }

            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: currentSolutionPath))
                let text = String(data: data, encoding: .utf8)

                if let text = text, !text.isEmpty {
                    log("✅ Current solution loaded (\(text.count) chars)")
                    return text
                } else {
                    log("⚠️ Current solution file is empty")
                    return nil
                }
            } catch {
                log("❌ Error reading current solution: \(error.localizedDescription)")
                return nil
            }
        }
    }

    /// Retrieves all saved solutions from history
    /// - Returns: Array of all solutions, newest first
    func getAllSolutions() -> [Solution] {
        return queue.sync {
            log("📚 Loading all solutions from history")

            guard fileManager.fileExists(atPath: allSolutionsPath) else {
                log("⚠️ History file does not exist")
                return []
            }

            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: allSolutionsPath))
                let history = try jsonDecoder.decode(SolutionHistory.self, from: data)
                log("✅ Loaded \(history.solutions.count) solutions from history")
                return history.solutions.reversed() // Newest first
            } catch {
                log("❌ Error reading solution history: \(error.localizedDescription)")
                return []
            }
        }
    }

    /// Clears the current solution text file
    /// - Returns: Success status
    @discardableResult
    func clearCurrentSolution() -> Bool {
        return queue.sync(flags: .barrier) {
            log("🗑️ Clearing current solution")

            do {
                if fileManager.fileExists(atPath: currentSolutionPath) {
                    try "".write(toFile: currentSolutionPath, atomically: true, encoding: .utf8)
                    log("✅ Current solution cleared")
                }
                return true
            } catch {
                log("❌ Error clearing current solution: \(error.localizedDescription)")
                return false
            }
        }
    }

    /// Gets the total number of saved solutions
    /// - Returns: Total count
    func getTotalSolutionCount() -> Int {
        return queue.sync {
            guard fileManager.fileExists(atPath: allSolutionsPath) else {
                return 0
            }

            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: allSolutionsPath))
                let history = try jsonDecoder.decode(SolutionHistory.self, from: data)
                return history.totalCount
            } catch {
                log("❌ Error reading solution count: \(error.localizedDescription)")
                return 0
            }
        }
    }

    /// Gets the most recent solution
    /// - Returns: The latest solution or nil
    func getLatestSolution() -> Solution? {
        let solutions = getAllSolutions()
        return solutions.first // Already sorted newest first
    }

    /// Searches solutions by question text
    /// - Parameter searchText: Text to search for in questions
    /// - Returns: Matching solutions
    func searchSolutions(containing searchText: String) -> [Solution] {
        let allSolutions = getAllSolutions()
        return allSolutions.filter { solution in
            solution.question.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Deletes a specific solution by ID
    /// - Parameter id: The solution ID to delete
    /// - Returns: Success status
    @discardableResult
    func deleteSolution(id: String) -> Bool {
        return queue.sync(flags: .barrier) {
            log("🗑️ Deleting solution with ID: \(id)")

            guard fileManager.fileExists(atPath: allSolutionsPath) else {
                log("⚠️ History file does not exist")
                return false
            }

            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: allSolutionsPath))
                var history = try jsonDecoder.decode(SolutionHistory.self, from: data)

                let originalCount = history.solutions.count
                history.solutions.removeAll { $0.id == id }

                if history.solutions.count == originalCount {
                    log("⚠️ Solution with ID \(id) not found")
                    return false
                }

                history.totalCount = history.solutions.count
                history.lastUpdated = ISO8601DateFormatter().string(from: Date())

                let encodedData = try jsonEncoder.encode(history)
                try encodedData.write(to: URL(fileURLWithPath: allSolutionsPath), options: .atomic)

                log("✅ Solution deleted successfully")
                return true
            } catch {
                log("❌ Error deleting solution: \(error.localizedDescription)")
                return false
            }
        }
    }

    // MARK: - Private Methods

    private func ensureFilesExist() {
        queue.sync(flags: .barrier) {
            log("🔍 Ensuring storage files exist")

            // Create all_solutions.json if it doesn't exist
            if !fileManager.fileExists(atPath: allSolutionsPath) {
                log("📝 Creating all_solutions.json")
                let emptyHistory = SolutionHistory()
                do {
                    let data = try jsonEncoder.encode(emptyHistory)
                    try data.write(to: URL(fileURLWithPath: allSolutionsPath), options: .atomic)
                    log("✅ Created all_solutions.json")
                } catch {
                    log("❌ Failed to create all_solutions.json: \(error.localizedDescription)")
                }
            }

            // Create current_solution.txt if it doesn't exist
            if !fileManager.fileExists(atPath: currentSolutionPath) {
                log("📝 Creating current_solution.txt")
                do {
                    try "".write(toFile: currentSolutionPath, atomically: true, encoding: .utf8)
                    log("✅ Created current_solution.txt")
                } catch {
                    log("❌ Failed to create current_solution.txt: \(error.localizedDescription)")
                }
            }
        }
    }

    private func saveToHistory(_ solution: Solution) -> Bool {
        return queue.sync(flags: .barrier) {
            log("💾 Saving to history file")

            do {
                var history: SolutionHistory

                // Load existing history or create new
                if fileManager.fileExists(atPath: allSolutionsPath) {
                    let data = try Data(contentsOf: URL(fileURLWithPath: allSolutionsPath))
                    history = try jsonDecoder.decode(SolutionHistory.self, from: data)
                } else {
                    history = SolutionHistory()
                }

                // Add new solution
                history.solutions.append(solution)
                history.totalCount = history.solutions.count
                history.lastUpdated = ISO8601DateFormatter().string(from: Date())

                // Save back to file
                let encodedData = try jsonEncoder.encode(history)
                try encodedData.write(to: URL(fileURLWithPath: allSolutionsPath), options: .atomic)

                log("✅ Solution added to history (total: \(history.totalCount))")
                return true
            } catch {
                log("❌ Error saving to history: \(error.localizedDescription)")
                return false
            }
        }
    }

    private func saveCurrentSolution(_ solution: String) -> Bool {
        return queue.sync(flags: .barrier) {
            log("💾 Saving current solution text")

            do {
                try solution.write(toFile: currentSolutionPath, atomically: true, encoding: .utf8)
                log("✅ Current solution text saved (\(solution.count) chars)")
                return true
            } catch {
                log("❌ Error saving current solution: \(error.localizedDescription)")
                return false
            }
        }
    }
}

// MARK: - Convenience Extensions

extension SolutionStorageManager {

    /// Exports all solutions to a formatted string for debugging
    func exportDebugInfo() -> String {
        let _ = getAllSolutions()
        var output = "=== Solution Storage Debug Info ===\n"
        output += "Total Solutions: \(getTotalSolutionCount())\n"
        output += "Files:\n"
        output += "  - History: \(allSolutionsPath)\n"
        output += "  - Current: \(currentSolutionPath)\n\n"

        if let latest = getLatestSolution() {
            output += "Latest Solution:\n"
            output += "  ID: \(latest.id)\n"
            output += "  Time: \(latest.timestamp)\n"
            output += "  Question: \(latest.question.prefix(50))...\n"
            output += "  Chars: \(latest.characterCount)\n"
        }

        return output
    }

    /// Validates the integrity of both storage files
    func validateStorage() -> (isValid: Bool, errors: [String]) {
        var errors: [String] = []

        // Check if files exist
        if !fileManager.fileExists(atPath: allSolutionsPath) {
            errors.append("History file does not exist")
        }

        if !fileManager.fileExists(atPath: currentSolutionPath) {
            errors.append("Current solution file does not exist")
        }

        // Try to read and parse JSON
        if fileManager.fileExists(atPath: allSolutionsPath) {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: allSolutionsPath))
                _ = try jsonDecoder.decode(SolutionHistory.self, from: data)
            } catch {
                errors.append("Cannot parse history JSON: \(error.localizedDescription)")
            }
        }

        return (errors.isEmpty, errors)
    }
}
