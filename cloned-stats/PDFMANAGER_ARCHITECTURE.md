# PDF Manager Module - Architecture

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Stats App (Main Target)                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                      AppDelegate.swift                       │  │
│  │  - Initializes all modules including PDFManager()            │  │
│  │  - Calls QuizIntegrationManager.shared.initialize()          │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │              QuizIntegrationManager.swift                    │  │
│  │  - Implements KeyboardShortcutDelegate                       │  │
│  │  - onOpenPDFPicker() → Opens NSOpenPanel                     │  │
│  │  - Calls PDFDataManager.shared.addPDF(from: url)             │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │            KeyboardShortcutManager.swift                     │  │
│  │  - Listens for Cmd+Option+L via CGEventTap                   │  │
│  │  - Calls delegate.onOpenPDFPicker()                          │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                                    ↓
                           Imports PDFManager
                                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│                  PDFManager Framework (New Target)                  │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                        main.swift                            │  │
│  │  - class PDFManager: Module                                  │  │
│  │  - Registers popup, settings, portal views                   │  │
│  │  - Initializes PDFDataManager.shared                         │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                      manager.swift                           │  │
│  │  - class PDFDataManager: ObservableObject                    │  │
│  │  - @Published var pdfs: [PDFDocument]                        │  │
│  │  - @Published var activeId: String?                          │  │
│  │  - func addPDF(from: URL)                                    │  │
│  │  - func setActivePDF(_ id: String)                           │  │
│  │  - func deletePDF(_ id: String)                              │  │
│  │  - func getActivePDFPath() -> String?                        │  │
│  │  - Handles storage: ~/Library/Application Support/Stats/     │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                       popup.swift                            │  │
│  │  - SwiftUI Views:                                            │  │
│  │    • PDFManagerView (main container)                         │  │
│  │    • DropZoneView (drag & drop + file picker)                │  │
│  │    • PDFListView (scrollable list)                           │  │
│  │    • PDFRowView (individual PDF with radio + delete)         │  │
│  │  - NSHostingView wrapper for Cocoa integration              │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                     settings.swift                           │  │
│  │  - class Settings: Settings_v                                │  │
│  │  - Shows module description                                  │  │
│  │  - Displays storage path                                     │  │
│  │  - "Open Folder" button                                      │  │
│  │  - Keyboard shortcut info                                    │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                      portal.swift                            │  │
│  │  - class Portal: Portal_p                                    │  │
│  │  - Widget integration (if needed)                            │  │
│  │  - Shows PDF count status                                    │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                     config.plist                             │  │
│  │  - Module metadata                                           │  │
│  │  - Name: "PDF Manager"                                       │  │
│  │  - State: false (hidden by default)                          │  │
│  │  - Symbol: doc.text.fill                                     │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                                    ↓
                            Uses Kit Framework
                                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│                        Kit Framework (Shared)                       │
│  - Module base class                                                │
│  - Settings_v, Popup_p, Portal_p protocols                          │
│  - ModuleType enum (includes .pdfManager)                           │
└─────────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. User Triggers Upload (Cmd+Option+L)

```
User presses Cmd+Option+L
    ↓
KeyboardShortcutManager detects keycode 37 (L key)
    ↓
Calls delegate.onOpenPDFPicker()
    ↓
QuizIntegrationManager.onOpenPDFPicker()
    ↓
Creates NSOpenPanel with .pdf filter
    ↓
User selects PDF file
    ↓
Calls PDFDataManager.shared.addPDF(from: url)
    ↓
PDFDataManager:
  - Validates file is PDF
  - Copies to ~/Library/Application Support/Stats/PDFs/
  - Creates PDFDocument metadata
  - Updates @Published var pdfs
  - Saves to pdfs.json
    ↓
SwiftUI views auto-update (via @ObservedObject)
    ↓
PDF appears in popup list
```

### 2. User Drags PDF onto Drop Zone

```
User drags PDF file
    ↓
DropZoneView.onDrop(of: [.fileURL])
    ↓
handleDrop() extracts file URL
    ↓
Calls PDFDataManager.shared.addPDF(from: url)
    ↓
[Same flow as keyboard shortcut from here]
```

### 3. User Selects Active PDF

```
User clicks radio button on PDFRowView
    ↓
Calls manager.setActivePDF(pdf.id)
    ↓
PDFDataManager.setActivePDF():
  - Deactivates all PDFs (isActive = false)
  - Activates selected PDF (isActive = true)
  - Updates activeId
  - Saves metadata to pdfs.json
    ↓
SwiftUI re-renders with blue highlight
```

### 4. User Deletes PDF

```
User clicks trash icon
    ↓
confirmDelete() shows NSAlert
    ↓
User confirms deletion
    ↓
Calls manager.deletePDF(pdf.id)
    ↓
PDFDataManager.deletePDF():
  - Removes file from disk
  - Removes from pdfs array
  - If was active, sets first remaining PDF as active
  - Saves metadata
    ↓
SwiftUI removes row from list
```

### 5. OpenAI Integration Gets Active PDF

```
OpenAI analysis code needs PDF context
    ↓
Calls PDFDataManager.shared.getActivePDFPath()
    ↓
Returns: Optional<String> path to active PDF
    ↓
If not nil:
  - Read PDF content
  - Include in OpenAI prompt
If nil:
  - Analyze without PDF context
```

## File Storage Structure

```
~/Library/Application Support/Stats/
├── PDFs/                          ← PDF files directory
│   ├── Quantum_Mechanics.pdf
│   ├── Linear_Algebra.pdf
│   └── Statistics_Notes.pdf
│
└── pdfs.json                      ← Metadata file
    {
      "pdfs": [
        {
          "id": "uuid-1234",
          "name": "Quantum_Mechanics.pdf",
          "path": "/Users/.../Stats/PDFs/Quantum_Mechanics.pdf",
          "isActive": true,
          "uploadedAt": "2025-11-13T10:30:00Z",
          "fileSize": 15728640
        },
        ...
      ],
      "activeId": "uuid-1234"
    }
```

## Module States

### 1. Module Disabled (Default)

- Module not visible in menu bar dropdown
- Functionality still works (keyboard shortcut active)
- PDFs can still be uploaded and managed programmatically
- Storage directory exists

### 2. Module Enabled (User activates in Settings)

- Popup appears in menu bar dropdown
- User can see uploaded PDFs
- Drag-and-drop UI visible
- Settings accessible

### 3. No PDFs Uploaded

- Empty state message shown
- Drag zone prompts user to upload
- Keyboard shortcut info displayed
- No active PDF path available

### 4. PDFs Uploaded, One Active

- List shows all PDFs
- Active PDF highlighted in blue
- Radio button checked for active PDF
- getActivePDFPath() returns valid path

## SwiftUI Components Hierarchy

```
PDFManagerView (VStack)
    ├── Text("PDF Reference Manager")
    ├── DropZoneView
    │       └── RoundedRectangle + onDrop + onTapGesture
    └── Conditional:
            ├── EmptyStateView (if no PDFs)
            └── PDFListView (if PDFs exist)
                    └── ScrollView
                            └── VStack of PDFRowView
                                    ├── Radio button (Image)
                                    ├── PDF icon (Image)
                                    ├── VStack (name + size + date)
                                    └── Delete button (Image)
```

## Dependencies

```
Stats App
    ↓
├── PDFManager Framework
│       ↓
│       └── Kit Framework
│               ├── Module base class
│               ├── Settings_v protocol
│               ├── Popup_p protocol
│               └── Portal_p protocol
│
├── QuizIntegrationManager
│       ├── PDFDataManager (from PDFManager)
│       └── KeyboardShortcutManager
│
└── KeyboardShortcutManager
        └── Delegates to QuizIntegrationManager
```

## Thread Safety

- **PDFDataManager**: Uses @Published properties (main thread)
- **File operations**: Synchronous on calling thread
- **UI updates**: Automatic via Combine (main thread)
- **Keyboard events**: Captured on system thread, dispatched to main

## Error Handling

```swift
enum PDFError: LocalizedError {
    case invalidFormat       // File is not PDF
    case fileNotFound        // Source file missing
    case copyFailed          // Cannot copy to storage
    case invalidMetadata     // Corrupt pdfs.json
    case storageError        // Cannot create directory
}
```

All errors are:
1. Thrown from manager methods
2. Caught in UI layer
3. Displayed via NSAlert to user
4. Logged to console

## Performance Considerations

- **Lazy loading**: PDFs not read into memory until needed
- **Metadata only**: List shows metadata, not PDF content
- **Efficient updates**: Combine publishes only changed properties
- **File operations**: Synchronous but fast (local disk only)

## Future Enhancements

1. **PDF preview** in popup (thumbnail or first page)
2. **Multiple active PDFs** (checkbox instead of radio)
3. **PDF annotations** (highlight important sections)
4. **Cloud sync** (iCloud Drive integration)
5. **Search within PDFs** (extract and index text)
6. **Tags/categories** for organizing PDFs

## Integration Examples

### Example 1: OpenAI Prompt with PDF Context

```swift
func analyzeQuizWithPDF(questions: [[String: Any]]) async throws -> [Int] {
    var prompt = "Analyze these quiz questions:\n"

    // Add PDF context if available
    if let pdfPath = PDFDataManager.shared.getActivePDFPath() {
        let pdfContent = extractTextFromPDF(at: pdfPath)
        prompt += "Reference material: \(pdfContent)\n\n"
    }

    prompt += "Questions: \(questions)"

    // Send to OpenAI...
}
```

### Example 2: Backend Integration

```swift
func sendToBackend(questions: [[String: Any]]) async throws -> [Int] {
    var payload: [String: Any] = ["questions": questions]

    // Include active PDF path for backend to use
    if let pdfPath = PDFDataManager.shared.getActivePDFPath() {
        payload["pdfReference"] = pdfPath
    }

    // POST to backend...
}
```

### Example 3: Check if PDF Available

```swift
func shouldUseAIAnalysis() -> Bool {
    // Only use AI if PDF reference is available
    return PDFDataManager.shared.getActivePDFPath() != nil
}
```

---

## Summary

The PDF Manager module is a self-contained framework that:

- Manages PDF file storage and metadata
- Provides SwiftUI UI for user interaction
- Integrates with keyboard shortcuts (Cmd+Option+L)
- Exposes active PDF path for OpenAI integration
- Follows Stats app module architecture
- Uses Combine for reactive state management
- Persists data across app launches

All components are loosely coupled and follow MVVM pattern.
