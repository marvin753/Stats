//
//  popup.swift
//  PDFManager
//
//  PDF Management Popup View with Drag & Drop
//

import Cocoa
import Kit
import SwiftUI
import UniformTypeIdentifiers

internal class Popup: PopupWrapper {
    private var pdfListView: PDFListHostingView?

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    internal func setup() {
        // Create SwiftUI view
        let listView = PDFListHostingView()
        self.pdfListView = listView

        // Add to popup
        self.addSubview(listView)
    }
}

// MARK: - SwiftUI Hosting View
class PDFListHostingView: NSView {
    private var hostingView: NSHostingView<PDFManagerView>?

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 400, height: 500))

        let swiftUIView = PDFManagerView(manager: PDFDataManager.shared)
        let hosting = NSHostingView(rootView: swiftUIView)
        hosting.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(hosting)

        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: self.topAnchor),
            hosting.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            hosting.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])

        self.hostingView = hosting
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - SwiftUI Views
struct PDFManagerView: View {
    @ObservedObject var manager: PDFDataManager
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("PDF Reference Manager")
                .font(.headline)
                .padding(.top, 8)

            // Drag and drop zone
            DropZoneView(isDragging: $isDragging, manager: manager)

            // PDF list
            if manager.pdfs.isEmpty {
                EmptyStateView()
            } else {
                PDFListView(manager: manager)
            }

            Spacer()
        }
        .padding()
        .frame(width: 400, height: 500)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No PDFs uploaded")
                .font(.body)
                .foregroundColor(.secondary)
            Text("Drag PDF files above or use Cmd+Option+L")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
    }
}

struct DropZoneView: View {
    @Binding var isDragging: Bool
    let manager: PDFDataManager

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDragging ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
            )
            .frame(height: 100)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: isDragging ? "doc.badge.arrow.up.fill" : "doc.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(isDragging ? .blue : .gray)
                    Text(isDragging ? "Drop PDF here" : "Drag PDF here or click to select")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            )
            .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                handleDrop(providers)
            }
            .onTapGesture {
                openFilePicker()
            }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            if let error = error {
                print("Error loading dropped item: \(error.localizedDescription)")
                return
            }

            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                return
            }

            DispatchQueue.main.async {
                do {
                    try manager.addPDF(from: url)
                } catch {
                    print("Error adding PDF: \(error.localizedDescription)")
                    showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }

        return true
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a PDF file to use as quiz reference"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            do {
                try manager.addPDF(from: url)
            } catch {
                print("Error adding PDF: \(error.localizedDescription)")
                showAlert(title: "Error", message: error.localizedDescription)
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

struct PDFListView: View {
    @ObservedObject var manager: PDFDataManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Uploaded PDFs")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(manager.pdfs) { pdf in
                        PDFRowView(pdf: pdf, manager: manager)
                    }
                }
            }
            .frame(maxHeight: 280)
        }
    }
}

struct PDFRowView: View {
    let pdf: PDFDocument
    let manager: PDFDataManager

    var body: some View {
        HStack(spacing: 12) {
            // Radio button for active selection
            Button(action: {
                manager.setActivePDF(pdf.id)
            }) {
                Image(systemName: pdf.isActive ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(pdf.isActive ? .blue : .gray)
            }
            .buttonStyle(PlainButtonStyle())

            // PDF icon
            Image(systemName: "doc.text.fill")
                .foregroundColor(.red)

            // PDF info
            VStack(alignment: .leading, spacing: 2) {
                Text(pdf.name)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(formatFileSize(pdf.fileSize))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(formatDate(pdf.uploadedAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Delete button
            Button(action: {
                confirmDelete(pdf)
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(10)
        .background(pdf.isActive ? Color.blue.opacity(0.08) : Color.clear)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(pdf.isActive ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func confirmDelete(_ pdf: PDFDocument) {
        let alert = NSAlert()
        alert.messageText = "Delete PDF?"
        alert.informativeText = "Are you sure you want to delete \"\(pdf.name)\"? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            manager.deletePDF(pdf.id)
        }
    }
}
