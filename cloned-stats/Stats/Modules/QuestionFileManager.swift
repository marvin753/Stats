//
//  QuestionFileManager.swift
//  Stats
//
//  Created on 2025-11-19.
//  Purpose: Manages question/answer files with 14-question limit per file
//

import Foundation

/// Manages storage of extracted questions and answers with automatic file rotation
@MainActor
class QuestionFileManager {

    // MARK: - Singleton

    static let shared = QuestionFileManager()

    // MARK: - Configuration

    /// Maximum questions per file before creating new file
    private let maxQuestionsPerFile = 14

    /// Base directory for storing question files (Stats project directory)
    private let basePath = "/Users/marvinbarsal/Desktop/Universität/Stats/ExtractedQuestions/"

    private var baseDirectory: URL {
        return URL(fileURLWithPath: basePath)
    }

    // MARK: - State

    /// Current file number
    private var currentFileNumber: Int = 1

    /// Questions in current file
    private var currentQuestions: [QuestionEntry] = []

    /// Current file creation timestamp
    private var currentFileCreatedAt: String?

    /// Current file URL
    private var currentFileURL: URL?

    // MARK: - Data Models

    struct QuestionEntry: Codable {
        let index: Int              // 1-14 within the file
        let timestamp: String       // ISO8601 format
        let mouseCoordinates: Coordinates
        let question: String
        let answers: [String]
        var correctAnswer: Int?     // 1, 2, 3, or 4 (nil if unknown)
    }

    struct Coordinates: Codable {
        let x: Double
        let y: Double
    }

    struct QuestionFile: Codable {
        let fileNumber: Int
        let createdAt: String
        var questions: [QuestionEntry]
    }

    // MARK: - Initialization

    private init() {
        print("[QuestionFileManager] Initialized")
        setupDirectory()
        loadCurrentState()
    }

    // MARK: - Public Methods

    /// Add a question to the current file (or create new file if limit reached)
    /// - Parameters:
    ///   - question: Question text
    ///   - answers: Array of answer options
    ///   - coordinates: Mouse coordinates where screenshot was taken
    ///   - correctAnswer: The correct answer number (1, 2, 3, etc.) or nil if unknown
    /// - Returns: Tuple containing file path and question index
    @discardableResult
    func addQuestion(question: String, answers: [String], coordinates: (x: Double, y: Double), correctAnswer: Int? = nil) -> (filePath: String, questionIndex: Int) {
        print("\n[QuestionFileManager] Adding question...")

        // Check if we need to create a new file
        if currentQuestions.count >= maxQuestionsPerFile {
            print("[QuestionFileManager] Current file full (\(maxQuestionsPerFile) questions)")
            print("   Creating new file...")
            createNewFile()
        }

        // Set file creation timestamp if this is the first question
        if currentQuestions.isEmpty {
            currentFileCreatedAt = ISO8601DateFormatter().string(from: Date())
        }

        // Create question entry with sequential index (1-based)
        let entry = QuestionEntry(
            index: currentQuestions.count + 1,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            mouseCoordinates: Coordinates(x: coordinates.x, y: coordinates.y),
            question: question,
            answers: answers,
            correctAnswer: correctAnswer
        )

        // Add to current questions (maintains chronological order)
        currentQuestions.append(entry)

        print("[QuestionFileManager] Question added:")
        print("   File: \(currentFileNumber)")
        print("   Question #: \(entry.index)")
        print("   Total in file: \(currentQuestions.count)/\(maxQuestionsPerFile)")
        print("   Coordinates: X: \(coordinates.x), Y: \(coordinates.y)")

        // Save to disk immediately
        saveCurrentFile()

        let filePath = getCurrentFileURL().path
        return (filePath: filePath, questionIndex: entry.index)
    }

    /// Get current file info including path and question count
    /// - Returns: Tuple containing file path and current question count
    func getCurrentFileInfo() -> (filePath: String, questionCount: Int) {
        let filePath = getCurrentFileURL().path
        return (filePath: filePath, questionCount: currentQuestions.count)
    }

    /// Get current file URL
    /// - Returns: URL of current question file
    func getCurrentFileURL() -> URL {
        return currentFileURL ?? getFileURL(for: currentFileNumber)
    }

    /// Get current question count in active file
    /// - Returns: Number of questions in current file
    func getCurrentQuestionCount() -> Int {
        return currentQuestions.count
    }

    /// Get total number of files created
    /// - Returns: Current file number
    func getTotalFileCount() -> Int {
        return currentFileNumber
    }

    /// Force create a new file (for manual reset)
    func createNewFile() {
        currentFileNumber += 1
        currentQuestions = []
        currentFileCreatedAt = nil
        currentFileURL = nil

        print("[QuestionFileManager] Created new file #\(currentFileNumber)")
    }

    /// Reset to start fresh (for testing)
    func reset() {
        print("[QuestionFileManager] Resetting...")
        currentFileNumber = 1
        currentQuestions = []
        currentFileCreatedAt = nil
        currentFileURL = nil
        print("[QuestionFileManager] Reset complete")
    }

    // MARK: - Private Methods

    /// Setup base directory for question files
    private func setupDirectory() {
        do {
            try FileManager.default.createDirectory(
                at: baseDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            print("[QuestionFileManager] Directory ready: \(baseDirectory.path)")
        } catch {
            print("[QuestionFileManager] Failed to create directory: \(error.localizedDescription)")
        }
    }

    /// Load current state from disk (find latest file)
    private func loadCurrentState() {
        do {
            // Check if directory exists
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: basePath, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                print("[QuestionFileManager] No existing directory found, starting fresh")
                return
            }

            let files = try FileManager.default.contentsOfDirectory(
                at: baseDirectory,
                includingPropertiesForKeys: nil
            )

            // Find highest numbered file
            let questionFiles = files.filter { $0.lastPathComponent.hasPrefix("questions_") && $0.pathExtension == "json" }

            if questionFiles.isEmpty {
                print("[QuestionFileManager] No existing files found, starting fresh")
                return
            }

            // Extract file numbers and find max
            let fileNumbers = questionFiles.compactMap { url -> Int? in
                let filename = url.deletingPathExtension().lastPathComponent
                let numberString = filename.replacingOccurrences(of: "questions_", with: "")
                return Int(numberString)
            }

            if let maxNumber = fileNumbers.max() {
                currentFileNumber = maxNumber

                // Try to load this file
                let fileURL = getFileURL(for: currentFileNumber)
                if let data = try? Data(contentsOf: fileURL),
                   let file = try? JSONDecoder().decode(QuestionFile.self, from: data) {
                    currentQuestions = file.questions
                    currentFileCreatedAt = file.createdAt
                    currentFileURL = fileURL

                    print("[QuestionFileManager] Loaded existing file #\(currentFileNumber)")
                    print("   Questions: \(currentQuestions.count)/\(maxQuestionsPerFile)")

                    // If current file is full, prepare for next file
                    if currentQuestions.count >= maxQuestionsPerFile {
                        print("   File is full, will create new file on next add")
                        currentFileNumber += 1
                        currentQuestions = []
                        currentFileCreatedAt = nil
                        currentFileURL = nil
                    }
                }
            }
        } catch {
            print("[QuestionFileManager] Error loading state: \(error.localizedDescription)")
        }
    }

    /// Save current questions to disk
    private func saveCurrentFile() {
        let fileURL = getFileURL(for: currentFileNumber)
        currentFileURL = fileURL

        let questionFile = QuestionFile(
            fileNumber: currentFileNumber,
            createdAt: currentFileCreatedAt ?? ISO8601DateFormatter().string(from: Date()),
            questions: currentQuestions
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(questionFile)
            try data.write(to: fileURL)

            print("[QuestionFileManager] Saved to: \(fileURL.lastPathComponent)")
        } catch {
            print("[QuestionFileManager] Failed to save: \(error.localizedDescription)")
        }
    }

    /// Get file URL for given file number
    /// - Parameter number: File number
    /// - Returns: URL for the file
    private func getFileURL(for number: Int) -> URL {
        let filename = String(format: "questions_%03d.json", number)
        return baseDirectory.appendingPathComponent(filename)
    }

    // MARK: - Get Last Question (Safeguard 5: Edge Cases)

    /// Get the last question from the latest JSON file
    /// Handles: empty files, invalid JSON, concurrent writes, empty arrays
    /// Falls back to previous files if latest is unusable
    func getLastQuestion() -> (question: String, answers: [String], correctAnswer: Int?)? {
        print("[QuestionFileManager] Getting last question...")

        // 1. Find all JSON files in ExtractedQuestions directory
        let files = findQuestionFiles()
        guard !files.isEmpty else {
            print("⚠️ [QuestionFileManager] No question files found")
            return nil
        }

        // 2. Sort by file number (descending) - try newest first
        let sortedFiles = files.sorted { extractFileNumber($0) > extractFileNumber($1) }

        // 3. Try each file until we find a valid question
        for fileURL in sortedFiles {
            if let result = loadLastQuestionFromFile(fileURL) {
                return result
            }
        }

        print("⚠️ [QuestionFileManager] No valid questions found in any file")
        return nil
    }

    /// Find all question JSON files in the directory
    private func findQuestionFiles() -> [URL] {
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: baseDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            return files.filter {
                $0.lastPathComponent.hasPrefix("questions_") &&
                $0.pathExtension == "json"
            }
        } catch {
            print("❌ [QuestionFileManager] Error listing files: \(error)")
            return []
        }
    }

    /// Extract file number from filename (e.g., "questions_003.json" -> 3)
    private func extractFileNumber(_ url: URL) -> Int {
        let filename = url.deletingPathExtension().lastPathComponent
        let numberString = filename.replacingOccurrences(of: "questions_", with: "")
        return Int(numberString) ?? 0
    }

    /// Load the last question from a specific file with file coordination
    private func loadLastQuestionFromFile(_ fileURL: URL) -> (question: String, answers: [String], correctAnswer: Int?)? {
        print("[QuestionFileManager] Trying file: \(fileURL.lastPathComponent)")

        // Use NSFileCoordinator to handle concurrent access
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?
        var result: (String, [String], Int?)?

        coordinator.coordinate(
            readingItemAt: fileURL,
            options: .withoutChanges,
            error: &coordinatorError
        ) { url in
            // Read file data
            guard let data = try? Data(contentsOf: url) else {
                print("   ⚠️ Cannot read file data")
                return
            }

            // Check for empty file
            guard !data.isEmpty else {
                print("   ⚠️ File is empty")
                return
            }

            // Parse JSON with error handling
            do {
                let questionFile = try JSONDecoder().decode(QuestionFile.self, from: data)

                // Check for empty questions array
                guard !questionFile.questions.isEmpty else {
                    print("   ⚠️ Questions array is empty")
                    return
                }

                // Get last question (highest index)
                guard let lastQuestion = questionFile.questions.max(by: { $0.index < $1.index }) else {
                    print("   ⚠️ Could not find question with highest index")
                    return
                }

                // Validate question has required data
                guard !lastQuestion.question.isEmpty, !lastQuestion.answers.isEmpty else {
                    print("   ⚠️ Question or answers are empty")
                    return
                }

                result = (lastQuestion.question, lastQuestion.answers, lastQuestion.correctAnswer)
                print("   ✅ Found question #\(lastQuestion.index): \"\(lastQuestion.question.prefix(50))...\"")

            } catch {
                print("   ⚠️ JSON decode error: \(error.localizedDescription)")
            }
        }

        if let error = coordinatorError {
            print("   ❌ File coordination error: \(error.localizedDescription)")
        }

        return result
    }
}
