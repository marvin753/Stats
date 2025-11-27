//
//  PDFTextExtractor.swift
//  Stats
//
//  Fallback PDF text extraction utility
//  Extracts full text from PDF for direct GPT API calls (non-Assistant approach)
//

import Foundation
import PDFKit

/// PDF text extraction utility
/// Fallback approach for when Assistant API is not available
class PDFTextExtractor {

    // MARK: - Text Extraction

    /// Extract all text from PDF document
    /// - Parameter pdfPath: Local file path to PDF
    /// - Returns: Full text content with page markers
    static func extractText(from pdfPath: String) -> String? {
        print("\n📄 Extracting text from PDF...")
        print("   File: \(pdfPath)")

        // Verify file exists
        guard FileManager.default.fileExists(atPath: pdfPath) else {
            print("   ❌ File not found")
            return nil
        }

        // Load PDF document
        let pdfURL = URL(fileURLWithPath: pdfPath)
        guard let pdfDoc = PDFDocument(url: pdfURL) else {
            print("   ❌ Failed to load PDF")
            return nil
        }

        let pageCount = pdfDoc.pageCount
        print("   Pages: \(pageCount)")

        // Extract text from all pages
        var fullText = ""

        for pageIndex in 0..<pageCount {
            guard let page = pdfDoc.page(at: pageIndex),
                  let pageText = page.string else {
                continue
            }

            // Add page marker
            fullText += "--- Page \(pageIndex + 1) ---\n"
            fullText += pageText
            fullText += "\n\n"

            // Progress indicator every 10 pages
            if (pageIndex + 1) % 10 == 0 {
                print("   Extracted: \(pageIndex + 1)/\(pageCount) pages")
            }
        }

        let characterCount = fullText.count
        let wordCount = fullText.split(separator: " ").count

        print("   ✅ Extraction complete")
        print("   Characters: \(characterCount)")
        print("   Words: \(wordCount)")
        print("   Estimated tokens: ~\(wordCount / 4)")

        return fullText
    }

    // MARK: - Chunked Extraction

    /// Extract text in chunks (useful for large PDFs)
    /// - Parameters:
    ///   - pdfPath: Local file path to PDF
    ///   - maxChunkSize: Maximum characters per chunk
    /// - Returns: Array of text chunks with page ranges
    static func extractChunks(from pdfPath: String, maxChunkSize: Int = 50000) -> [(text: String, pageRange: String)]? {
        print("\n📄 Extracting PDF in chunks...")
        print("   File: \(pdfPath)")
        print("   Max chunk size: \(maxChunkSize) characters")

        guard FileManager.default.fileExists(atPath: pdfPath) else {
            print("   ❌ File not found")
            return nil
        }

        let pdfURL = URL(fileURLWithPath: pdfPath)
        guard let pdfDoc = PDFDocument(url: pdfURL) else {
            print("   ❌ Failed to load PDF")
            return nil
        }

        let pageCount = pdfDoc.pageCount
        print("   Total pages: \(pageCount)")

        var chunks: [(text: String, pageRange: String)] = []
        var currentChunk = ""
        var chunkStartPage = 1

        for pageIndex in 0..<pageCount {
            guard let page = pdfDoc.page(at: pageIndex),
                  let pageText = page.string else {
                continue
            }

            let pageWithMarker = "--- Page \(pageIndex + 1) ---\n\(pageText)\n\n"

            // Check if adding this page would exceed chunk size
            if currentChunk.count + pageWithMarker.count > maxChunkSize && !currentChunk.isEmpty {
                // Save current chunk
                let pageRange = chunkStartPage == pageIndex ? "\(chunkStartPage)" : "\(chunkStartPage)-\(pageIndex)"
                chunks.append((text: currentChunk, pageRange: pageRange))

                // Start new chunk
                currentChunk = pageWithMarker
                chunkStartPage = pageIndex + 1
            } else {
                currentChunk += pageWithMarker
            }
        }

        // Add final chunk
        if !currentChunk.isEmpty {
            let pageRange = chunkStartPage == pageCount ? "\(chunkStartPage)" : "\(chunkStartPage)-\(pageCount)"
            chunks.append((text: currentChunk, pageRange: pageRange))
        }

        print("   ✅ Extraction complete")
        print("   Chunks: \(chunks.count)")

        for (index, chunk) in chunks.enumerated() {
            let wordCount = chunk.text.split(separator: " ").count
            print("   Chunk \(index + 1): Pages \(chunk.pageRange), ~\(wordCount) words")
        }

        return chunks
    }

    // MARK: - Page Range Extraction

    /// Extract text from specific page range
    /// - Parameters:
    ///   - pdfPath: Local file path to PDF
    ///   - startPage: Starting page (1-based)
    ///   - endPage: Ending page (1-based)
    /// - Returns: Text from specified pages
    static func extractPages(from pdfPath: String, startPage: Int, endPage: Int) -> String? {
        print("\n📄 Extracting pages \(startPage)-\(endPage)...")

        guard FileManager.default.fileExists(atPath: pdfPath) else {
            print("   ❌ File not found")
            return nil
        }

        let pdfURL = URL(fileURLWithPath: pdfPath)
        guard let pdfDoc = PDFDocument(url: pdfURL) else {
            print("   ❌ Failed to load PDF")
            return nil
        }

        let pageCount = pdfDoc.pageCount
        guard startPage >= 1, endPage <= pageCount, startPage <= endPage else {
            print("   ❌ Invalid page range (PDF has \(pageCount) pages)")
            return nil
        }

        var text = ""

        for pageIndex in (startPage - 1)..<endPage {
            guard let page = pdfDoc.page(at: pageIndex),
                  let pageText = page.string else {
                continue
            }

            text += "--- Page \(pageIndex + 1) ---\n"
            text += pageText
            text += "\n\n"
        }

        print("   ✅ Extracted \(endPage - startPage + 1) pages")
        return text
    }

    // MARK: - Search

    /// Search for text in PDF
    /// - Parameters:
    ///   - pdfPath: Local file path to PDF
    ///   - searchTerm: Text to search for
    /// - Returns: Array of (pageNumber, matchingText) tuples
    static func search(in pdfPath: String, for searchTerm: String) -> [(pageNumber: Int, context: String)]? {
        print("\n🔍 Searching for '\(searchTerm)'...")

        guard FileManager.default.fileExists(atPath: pdfPath) else {
            print("   ❌ File not found")
            return nil
        }

        let pdfURL = URL(fileURLWithPath: pdfPath)
        guard let pdfDoc = PDFDocument(url: pdfURL) else {
            print("   ❌ Failed to load PDF")
            return nil
        }

        var results: [(pageNumber: Int, context: String)] = []

        for pageIndex in 0..<pdfDoc.pageCount {
            guard let page = pdfDoc.page(at: pageIndex),
                  let pageText = page.string else {
                continue
            }

            // Check if search term exists on this page (case-insensitive)
            if pageText.range(of: searchTerm, options: .caseInsensitive) != nil {
                // Extract context (200 characters around match)
                let context = extractContext(from: pageText, searchTerm: searchTerm, contextLength: 200)
                results.append((pageNumber: pageIndex + 1, context: context))
            }
        }

        print("   ✅ Found \(results.count) matches")
        return results
    }

    // MARK: - Helper Methods

    /// Extract context around search term
    private static func extractContext(from text: String, searchTerm: String, contextLength: Int) -> String {
        guard let range = text.range(of: searchTerm, options: .caseInsensitive) else {
            return text.prefix(contextLength).description
        }

        let startIndex = text.index(range.lowerBound, offsetBy: -contextLength/2, limitedBy: text.startIndex) ?? text.startIndex
        let endIndex = text.index(range.upperBound, offsetBy: contextLength/2, limitedBy: text.endIndex) ?? text.endIndex

        var context = String(text[startIndex..<endIndex])

        // Add ellipsis if truncated
        if startIndex != text.startIndex {
            context = "..." + context
        }
        if endIndex != text.endIndex {
            context = context + "..."
        }

        return context
    }

    // MARK: - Token Estimation

    /// Estimate GPT token count for PDF
    /// - Parameter pdfPath: Local file path to PDF
    /// - Returns: Estimated token count
    static func estimateTokenCount(for pdfPath: String) -> Int? {
        guard let text = extractText(from: pdfPath) else {
            return nil
        }

        // Rough estimation: 1 token ≈ 4 characters
        // More accurate: 1 token ≈ 0.75 words
        let wordCount = text.split(separator: " ").count
        return Int(Double(wordCount) * 0.75)
    }
}

// MARK: - Usage Example

/*

 Usage Example:

 // 1. Extract full text
 if let fullText = PDFTextExtractor.extractText(from: "/path/to/script.pdf") {
     print("Extracted \(fullText.count) characters")
 }

 // 2. Extract in chunks (for large PDFs)
 if let chunks = PDFTextExtractor.extractChunks(from: "/path/to/script.pdf", maxChunkSize: 50000) {
     for (index, chunk) in chunks.enumerated() {
         print("Chunk \(index + 1): Pages \(chunk.pageRange)")
         // Process each chunk separately
     }
 }

 // 3. Extract specific pages
 if let text = PDFTextExtractor.extractPages(from: "/path/to/script.pdf", startPage: 1, endPage: 10) {
     print("Pages 1-10: \(text.count) characters")
 }

 // 4. Search in PDF
 if let results = PDFTextExtractor.search(in: "/path/to/script.pdf", for: "machine learning") {
     for result in results {
         print("Page \(result.pageNumber): \(result.context)")
     }
 }

 // 5. Estimate token usage
 if let tokenCount = PDFTextExtractor.estimateTokenCount(for: "/path/to/script.pdf") {
     print("Estimated tokens: \(tokenCount)")
 }

 */
