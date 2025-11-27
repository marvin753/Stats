# PDF Manager Module - Setup Instructions

## Wave 2B Implementation Complete

All Swift source files have been created and integrated. **One manual step remains**: Adding the PDFManager framework target to the Xcode project.

---

## Files Created

### Module Files (in `/Modules/PDFManager/`)
1. **main.swift** - Module initialization and registration
2. **popup.swift** - SwiftUI popup view with drag-and-drop UI
3. **manager.swift** - Core business logic (PDFDataManager)
4. **settings.swift** - Settings view
5. **portal.swift** - Portal/widget integration
6. **config.plist** - Module configuration

### Files Modified

1. **Kit/constants.swift**
   - Added `case pdfManager` to `ModuleType` enum
   - Added `"PDFManager"` to `stringValue` switch

2. **Stats/AppDelegate.swift**
   - Added `import PDFManager`
   - Added `PDFManager()` to modules array

3. **Stats/Modules/KeyboardShortcutManager.swift**
   - Added `func onOpenPDFPicker()` to delegate protocol
   - Wired up Cmd+Option+L to call delegate method

4. **Stats/Modules/QuizIntegrationManager.swift**
   - Added `import PDFManager`
   - Added `import UniformTypeIdentifiers`
   - Implemented `onOpenPDFPicker()` delegate method

---

## Manual Xcode Setup Required

### Step 1: Add PDFManager Framework Target

1. Open Xcode project:
   ```bash
   open /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats/Stats.xcodeproj
   ```

2. In Xcode, select the **Stats** project in the navigator

3. Click the **+** button at the bottom of the targets list

4. Select **Framework** (under macOS)

5. Configure the new target:
   - **Product Name**: `PDFManager`
   - **Organization**: (same as Stats)
   - **Bundle Identifier**: `eu.exelban.PDFManager`
   - **Language**: Swift
   - **Framework**: Cocoa

6. Click **Finish**

### Step 2: Add Source Files to PDFManager Target

1. In the Project Navigator, locate `/Modules/PDFManager/`

2. Select all Swift files in PDFManager folder:
   - `main.swift`
   - `popup.swift`
   - `manager.swift`
   - `settings.swift`
   - `portal.swift`

3. For each file, open the **File Inspector** (right panel)

4. Under **Target Membership**, check the box for **PDFManager**

5. Also add `config.plist` to the PDFManager target

### Step 3: Link PDFManager Framework to Stats App

1. Select the **Stats** target (main app)

2. Go to **General** tab

3. Scroll to **Frameworks, Libraries, and Embedded Content**

4. Click the **+** button

5. Select **PDFManager.framework** from the list

6. Set **Embed** to **Embed & Sign**

### Step 4: Link Kit Framework to PDFManager

1. Select the **PDFManager** target

2. Go to **General** tab

3. Scroll to **Frameworks, Libraries, and Embedded Content**

4. Click the **+** button

5. Select **Kit.framework**

6. Set **Do Not Embed** (Kit is already embedded in Stats app)

### Step 5: Configure Build Settings

1. Select **PDFManager** target

2. Go to **Build Settings** tab

3. Search for **Defines Module**

4. Set to **Yes**

5. Search for **Module Name**

6. Ensure it's set to `PDFManager`

### Step 6: Build the Project

1. Select the **Stats** scheme from the scheme picker

2. Press **Cmd+B** to build

3. Fix any build errors (should compile cleanly)

4. Press **Cmd+R** to run

---

## Verification Steps

### 1. Check Module Appears in Settings

1. Run the Stats app

2. Click the Stats menu bar icon

3. Select **Settings**

4. The **PDF Manager** module should appear in the module list (at the bottom)

5. Enable the module by checking its checkbox

### 2. Test Popup View

1. With PDF Manager enabled, click the Stats menu bar icon

2. Click on **PDF Manager** in the dropdown

3. The popup should display:
   - Title: "PDF Reference Manager"
   - Drag-and-drop zone
   - Empty state message: "No PDFs uploaded"

### 3. Test Drag-and-Drop Upload

1. Download a test PDF file

2. Drag it onto the drop zone in the popup

3. The PDF should appear in the list below

4. Verify:
   - PDF name is displayed
   - File size is shown
   - Upload date is shown
   - Radio button appears (checked for first PDF)

### 4. Test Keyboard Shortcut (Cmd+Option+L)

1. Press **Cmd+Option+L** anywhere in macOS

2. A file picker dialog should appear

3. Select a PDF file

4. The PDF should be added to the list

5. Check console logs for:
   ```
   📄 [QuizIntegration] OPEN PDF PICKER (Cmd+Option+L)
   📄 PDF selected: filename.pdf
   ✅ PDF added successfully
   ```

### 5. Test Active PDF Selection

1. Upload multiple PDFs

2. Click the radio button next to a PDF

3. The PDF should be highlighted with blue background

4. Only one PDF should be active at a time

5. Verify in console:
   ```
   [PDFManager] Setting active PDF: <uuid>
   [PDFManager] Active PDF set to: filename.pdf
   ```

### 6. Test PDF Deletion

1. Click the trash icon next to a PDF

2. A confirmation dialog should appear

3. Click **Delete**

4. The PDF should be removed from the list

5. Verify in console:
   ```
   [PDFManager] Deleting PDF: <uuid>
   [PDFManager] File deleted: <path>
   [PDFManager] PDF deleted successfully
   ```

### 7. Test Persistence

1. Upload 2-3 PDFs

2. Set one as active

3. Quit the Stats app

4. Relaunch the app

5. Open PDF Manager popup

6. All PDFs should still be in the list

7. The active PDF should still be marked as active

### 8. Verify Storage Directory

1. Open Finder

2. Press **Cmd+Shift+G**

3. Go to: `~/Library/Application Support/Stats/PDFs/`

4. You should see all uploaded PDFs

5. Also check for `pdfs.json` metadata file in `~/Library/Application Support/Stats/`

### 9. Test Get Active PDF Path (For OpenAI Integration)

In Swift console or code:
```swift
if let path = PDFDataManager.shared.getActivePDFPath() {
    print("Active PDF path: \(path)")
} else {
    print("No active PDF")
}
```

---

## Integration with OpenAI (Future)

When you implement OpenAI quiz analysis with PDF context:

```swift
import PDFManager

// In your OpenAI analysis code:
if let pdfPath = PDFDataManager.shared.getActivePDFPath() {
    // Read PDF content
    // Include in OpenAI prompt as context
    print("Using PDF reference: \(pdfPath)")
} else {
    // No PDF available - analyze without context
    print("No PDF reference available")
}
```

The active PDF path can be passed to your backend or used directly in Swift.

---

## Module Settings

The PDF Manager module settings can be accessed via:

1. Stats menu bar icon → **Settings**

2. Select **PDF Manager** from the module list

3. Settings show:
   - Description of PDF manager functionality
   - Storage location: `~/Library/Application Support/Stats/PDFs/`
   - **Open Folder** button to view PDFs in Finder
   - Keyboard shortcut info: Cmd+Option+L

---

## Keyboard Shortcuts Summary

| Shortcut | Action |
|----------|--------|
| **Cmd+Option+L** | Open PDF file picker |
| **Cmd+Option+O** | Capture screenshot (existing) |
| **Cmd+Option+P** | Process screenshots (existing) |
| **Cmd+Option+0-5** | Set question count (existing) |

---

## Troubleshooting

### Module doesn't appear in Settings

- Verify all source files are added to PDFManager target
- Verify PDFManager.framework is linked to Stats app
- Clean build folder: **Product > Clean Build Folder**
- Rebuild: **Cmd+Shift+K**, then **Cmd+B**

### Cmd+Option+L doesn't work

- Check that Input Monitoring permission is granted
- Go to: **System Settings > Privacy & Security > Input Monitoring**
- Enable **Stats** in the list
- Restart the app

### PDFs not appearing after upload

- Check console logs for errors
- Verify storage directory exists: `~/Library/Application Support/Stats/PDFs/`
- Check file permissions on storage directory

### Build errors

Common issues:
- **Missing Kit framework**: Link Kit to PDFManager target
- **Cannot find PDFManager**: Verify import in QuizIntegrationManager.swift
- **Module 'PDFManager' not found**: Set "Defines Module" to Yes in build settings

---

## File Paths Reference

All files are in: `/Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats/`

**PDFManager Module:**
- `Modules/PDFManager/main.swift`
- `Modules/PDFManager/popup.swift`
- `Modules/PDFManager/manager.swift`
- `Modules/PDFManager/settings.swift`
- `Modules/PDFManager/portal.swift`
- `Modules/PDFManager/config.plist`

**Modified Files:**
- `Kit/constants.swift`
- `Stats/AppDelegate.swift`
- `Stats/Modules/KeyboardShortcutManager.swift`
- `Stats/Modules/QuizIntegrationManager.swift`

**Storage:**
- PDFs: `~/Library/Application Support/Stats/PDFs/`
- Metadata: `~/Library/Application Support/Stats/pdfs.json`

---

## Summary

Wave 2B is **95% complete**. All Swift code is written and integrated. The remaining 5% is the manual Xcode project configuration (adding framework target and linking).

After completing the Xcode setup steps above, the PDF Manager module will be fully functional and ready for testing.

The module provides:
- Hidden by default (user must enable in settings)
- Drag-and-drop PDF upload
- Keyboard shortcut (Cmd+Option+L) for file picker
- Active PDF selection (radio buttons)
- PDF deletion with confirmation
- Persistent storage with metadata
- Integration point for OpenAI (getActivePDFPath())

Next wave can focus on passing the active PDF content to OpenAI for quiz analysis.
