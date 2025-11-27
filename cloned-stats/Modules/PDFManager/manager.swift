//
//  manager.swift
//  PDFManager
//
//  Core business logic for PDF file management
//

import Foundation
import Cocoa

// MARK: - PDF Document Model
struct PDFDocument: Identifiable, Codable {
    let id: String
    var name: String
    var path: String
    var isActive: Bool
    var uploadedAt: Date
    var fileSize: Int64
}

// MARK: - Metadata Structure
struct PDFMetadata: Codable {
    var pdfs: [PDFDocument]
    var activeId: String?
}

// MARK: - PDF Error Types
enum PDFError: LocalizedError {
    case invalidFormat
    case fileNotFound
    case copyFailed
    case invalidMetadata
    case storageError

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "File is not a valid PDF document"
        case .fileNotFound:
            return "PDF file not found"
        case .copyFailed:
            return "Failed to copy PDF to storage"
        case .invalidMetadata:
            return "PDF metadata is corrupted"
        case .storageError:
            return "Failed to access PDF storage directory"
        }
    }
}

// MARK: - PDF Data Manager
class PDFDataManager: ObservableObject {
    static let shared = PDFDataManager()

    @Published var pdfs: [PDFDocument] = []
    @Published var activeId: String?

    private let storageDir: URL
    private let metadataURL: URL

    private init() {
        // Setup storage paths
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        storageDir = appSupport.appendingPathComponent("Stats/PDFs")
        metadataURL = appSupport.appendingPathComponent("Stats/pdfs.json")

        print("[PDFManager] Storage directory: \(storageDir.path)")
        print("[PDFManager] Metadata file: \(metadataURL.path)")
    }

    // MARK: - Initialization
    func initializeStorage() {
        createStorageDirectory()
        loadMetadata()
    }

    private func createStorageDirectory() {
        do {
            try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true, attributes: nil)
            print("[PDFManager] Storage directory created/verified")
        } catch {
            print("[PDFManager] Error creating storage directory: \(error.localizedDescription)")
        }
    }

    // MARK: - PDF Operations
    func addPDF(from url: URL) throws {
        print("[PDFManager] Adding PDF from: \(url.path)")

        // Validate PDF
        guard url.pathExtension.lowercased() == "pdf" else {
            throw PDFError.invalidFormat
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PDFError.fileNotFound
        }

        // Generate unique filename if duplicate
        var destinationURL = storageDir.appendingPathComponent(url.lastPathComponent)
        var counter = 1

        while FileManager.default.fileExists(atPath: destinationURL.path) {
            let name = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            destinationURL = storageDir.appendingPathComponent("\(name)_\(counter).\(ext)")
            counter += 1
        }

        // Copy to storage directory
        do {
            try FileManager.default.copyItem(at: url, to: destinationURL)
            print("[PDFManager] PDF copied to: \(destinationURL.path)")
        } catch {
            print("[PDFManager] Copy failed: \(error.localizedDescription)")
            throw PDFError.copyFailed
        }

        // Get file size
        let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        // Create metadata
        let pdf = PDFDocument(
            id: UUID().uuidString,
            name: destinationURL.lastPathComponent,
            path: destinationURL.path,
            isActive: pdfs.isEmpty, // First PDF is automatically active
            uploadedAt: Date(),
            fileSize: fileSize
        )

        // Add to list
        DispatchQueue.main.async {
            self.pdfs.append(pdf)
            if pdf.isActive {
                self.activeId = pdf.id
            }
            self.saveMetadata()
        }

        print("[PDFManager] PDF added successfully: \(pdf.name)")
    }

    func setActivePDF(_ id: String) {
        print("[PDFManager] Setting active PDF: \(id)")

        guard let index = pdfs.firstIndex(where: { $0.id == id }) else {
            print("[PDFManager] Warning: PDF not found")
            return
        }

        // Deactivate all PDFs
        for i in pdfs.indices {
            pdfs[i].isActive = false
        }

        // Activate selected PDF
        pdfs[index].isActive = true
        activeId = id

        saveMetadata()

        print("[PDFManager] Active PDF set to: \(pdfs[index].name)")
    }

    func deletePDF(_ id: String) {
        print("[PDFManager] Deleting PDF: \(id)")

        guard let index = pdfs.firstIndex(where: { $0.id == id }) else {
            print("[PDFManager] Warning: PDF not found")
            return
        }

        let pdf = pdfs[index]

        // Delete file from storage
        do {
            try FileManager.default.removeItem(atPath: pdf.path)
            print("[PDFManager] File deleted: \(pdf.path)")
        } catch {
            print("[PDFManager] Warning: Could not delete file: \(error.localizedDescription)")
        }

        // Remove from list
        pdfs.remove(at: index)

        // If deleted PDF was active, activate first remaining PDF
        if pdf.isActive && !pdfs.isEmpty {
            setActivePDF(pdfs[0].id)
        } else if pdfs.isEmpty {
            activeId = nil
        }

        saveMetadata()

        print("[PDFManager] PDF deleted successfully")
    }

    func getActivePDFPath() -> String? {
        guard let activeId = activeId,
              let pdf = pdfs.first(where: { $0.id == activeId }) else {
            return nil
        }

        // Verify file still exists
        guard FileManager.default.fileExists(atPath: pdf.path) else {
            print("[PDFManager] Warning: Active PDF file not found at path")
            return nil
        }

        return pdf.path
    }

    // MARK: - Metadata Persistence
    private func saveMetadata() {
        let metadata = PDFMetadata(pdfs: pdfs, activeId: activeId)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted

            let data = try encoder.encode(metadata)
            try data.write(to: metadataURL)

            print("[PDFManager] Metadata saved: \(pdfs.count) PDFs")
        } catch {
            print("[PDFManager] Error saving metadata: \(error.localizedDescription)")
        }
    }

    private func loadMetadata() {
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            print("[PDFManager] No metadata file found (first launch)")
            return
        }

        do {
            let data = try Data(contentsOf: metadataURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let metadata = try decoder.decode(PDFMetadata.self, from: data)

            // Verify all files still exist
            var validPDFs: [PDFDocument] = []
            for pdf in metadata.pdfs {
                if FileManager.default.fileExists(atPath: pdf.path) {
                    validPDFs.append(pdf)
                } else {
                    print("[PDFManager] Warning: PDF file missing, removing from list: \(pdf.name)")
                }
            }

            DispatchQueue.main.async {
                self.pdfs = validPDFs
                self.activeId = metadata.activeId

                // If active PDF was deleted, set first as active
                if let activeId = self.activeId,
                   !self.pdfs.contains(where: { $0.id == activeId }),
                   !self.pdfs.isEmpty {
                    self.setActivePDF(self.pdfs[0].id)
                }
            }

            print("[PDFManager] Metadata loaded: \(validPDFs.count) PDFs")
        } catch {
            print("[PDFManager] Error loading metadata: \(error.localizedDescription)")
        }
    }
}
