# Quick Test Guide - Screenshot Collage System

## Quick Start (3 Commands)

```bash
# 1. Build the app
cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats
./build-swift.sh

# 2. Run the app
./run-swift.sh

# 3. Capture screenshots (trigger via your cropping service)
# Watch console output for collage progress
```

---

## What to Expect

### First Screenshot (1/14)
```
ScreenshotFileManager: Adding screenshot to session (current count: 0)
ScreenshotFileManager: Image validation passed: 1200x900
ScreenshotFileManager: Screenshot added successfully. Total in session: 1/14
📝 Screenshots in session: 1/14
```

### Middle Screenshots (2-13/14)
```
ScreenshotFileManager: Adding screenshot to session (current count: 5)
ScreenshotFileManager: Image validation passed: 1200x900
ScreenshotFileManager: Screenshot added successfully. Total in session: 6/14
📝 Screenshots in session: 6/14
```

### 14th Screenshot (Collage Creation!)
```
ScreenshotFileManager: Session complete! Creating collage from 14 screenshots
ScreenshotFileManager: Cell size: 1200x900
ScreenshotFileManager: Canvas size: 8470x1820
ScreenshotFileManager: Collage image created successfully
ScreenshotFileManager: Saving collage to: ~/Library/Application Support/Stats/Screenshots/Session_001/Session_001.png
ScreenshotFileManager: PNG data created successfully: 2458624 bytes
ScreenshotFileManager: Collage saved successfully: Session_001.png (2400 KB)
🎉 Session collage saved to: ~/Library/Application Support/Stats/Screenshots/Session_001/Session_001.png
ScreenshotFileManager: Starting new session: Session_002
```

---

## Verify Collage File

```bash
# View saved collages
open ~/Library/Application\ Support/Stats/Screenshots/

# Expected structure:
# Session_001/
#   └── Session_001.png   ← Collage image (7x2 grid)
# Session_002/
#   └── Session_002.png   ← Next collage
```

---

## Test Scenarios

### Scenario 1: Normal Flow (14 Screenshots)
1. Start app
2. Capture 14 screenshots
3. On 14th: Collage auto-created
4. Session_001.png saved
5. New session starts

**Expected Result**: Single PNG with 7x2 grid of screenshots

### Scenario 2: Partial Session (App Quit Early)
1. Start app
2. Capture 7 screenshots
3. Quit app (Cmd+Q)

**Expected Result**:
- Partial collage saved with first row filled
- On restart: Session resumes (but in-memory screenshots lost)

### Scenario 3: Multiple Sessions
1. Capture 14 screenshots → Session_001.png
2. Capture 14 more → Session_002.png
3. Capture 14 more → Session_003.png

**Expected Result**: 3 separate collage files

---

## Troubleshooting

### Problem: "Image validation failed"
**Cause**: Screenshot has invalid data
**Fix**: Check screenshot cropping service for nil/empty images

### Problem: "Failed to create collage"
**Cause**: Memory issue or corrupted image in session
**Fix**: Restart app, capture screenshots again

### Problem: Collage not created after 14 screenshots
**Cause**: Counter not reaching 14
**Fix**: Check UserDefaults state with:
```bash
defaults read eu.exelban.Stats
```

### Problem: Crash on PNG save
**Cause**: SHOULD NOT HAPPEN (validation added)
**Fix**: Report with full console log

---

## Console Output Cheat Sheet

| Message | Meaning |
|---------|---------|
| `Initializing` | ScreenshotFileManager starting |
| `Starting with Session_001` | New session created |
| `Image validation passed` | Screenshot OK |
| `Total in session: X/14` | Progress counter |
| `Session complete!` | 14th screenshot captured |
| `Collage saved successfully` | PNG written to disk |
| `Starting new session` | Ready for next 14 |
| `ERROR: Image validation failed` | Bad screenshot rejected |
| `ERROR: Failed to create collage` | Collage creation error |

---

## Quick Checks

### Check Current Session State
```bash
# View UserDefaults
defaults read eu.exelban.Stats | grep Screenshot

# Expected output:
# ScreenshotSessionCount = 5;
# ScreenshotSessionNumber = 1;
```

### Check Disk Usage
```bash
# List all sessions
ls -lh ~/Library/Application\ Support/Stats/Screenshots/*/

# Expected output:
# Session_001.png  (2.4M)
# Session_002.png  (2.4M)
```

### Force Reset Session
```bash
# Clear session state
defaults delete eu.exelban.Stats ScreenshotSessionNumber
defaults delete eu.exelban.Stats ScreenshotSessionCount

# Delete old sessions
rm -rf ~/Library/Application\ Support/Stats/Screenshots/*
```

---

## API Usage Example

```swift
import Foundation

// Get file manager
let manager = ScreenshotFileManager.shared

// Add screenshot
let image = NSImage(contentsOfFile: "/path/to/screenshot.png")!
let result = manager.addScreenshot(image)

if result.sessionComplete {
    print("Collage created: \(result.fileURL!.path)")
} else if result.saved {
    print("Progress: \(manager.getCurrentSessionCount())/14")
} else {
    print("Error: Screenshot rejected")
}

// On app quit (in AppDelegate)
func applicationWillTerminate(_ notification: Notification) {
    ScreenshotFileManager.shared.savePartialCollage()
}
```

---

## File Locations

| File | Path |
|------|------|
| **Implementation** | `Stats/Modules/ScreenshotFileManager.swift` |
| **Integration** | `Stats/Modules/ScreenshotCroppingService.swift` |
| **Collage Output** | `~/Library/Application Support/Stats/Screenshots/Session_XXX/` |
| **Build Script** | `build-swift.sh` |
| **Run Script** | `run-swift.sh` |

---

## Success Criteria

✅ App builds without errors
✅ No crashes on screenshot capture
✅ 14 screenshots combined into single PNG
✅ Collage has 7x2 grid layout
✅ Session number increments automatically
✅ Partial collages saved on app quit
✅ State persists across app restarts

---

**Ready to Test!**
