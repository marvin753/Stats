# Screenshots Module - Xcode Integration Guide

## Overview
This guide walks you through adding the Screenshots module framework to the Stats Xcode project. The module files have been created and AppDelegate has been updated, but Xcode needs to be configured to build the Screenshots framework.

## Files Created
✅ `/Modules/Screenshots/main.swift` - Module initialization
✅ `/Modules/Screenshots/popup.swift` - Session list UI (11,015 bytes)
✅ `/Modules/Screenshots/settings.swift` - Settings panel (4,536 bytes)
✅ `/Modules/Screenshots/config.plist` - Configuration
✅ `/Modules/Screenshots/Info.plist` - Framework metadata (just created)
✅ `/Stats/AppDelegate.swift` - Updated to import Screenshots module

## Code Changes Summary
✅ Fixed ScreenshotFileManager.swift crash (lines 108-140)
✅ AppDelegate now imports Screenshots module (line 23)
✅ AppDelegate includes Screenshots() in modules array (line 36)

---

## Integration Steps

### Step 1: Open Xcode Project
```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats
open Stats.xcodeproj
```

### Step 2: Create Screenshots Framework Target

1. **File → New → Target**
2. Select **macOS → Framework**
3. Configure:
   - Product Name: `Screenshots`
   - Team: `RP2S87B72W` (same as other modules)
   - Language: Swift
   - Include Unit Tests: NO
4. Click **Finish**

### Step 3: Add Source Files to Framework

1. In Xcode's Project Navigator (left sidebar), locate the **Screenshots** folder under **Modules**
2. Right-click the **Screenshots** target in the targets list
3. Select **Add Files to "Screenshots"...**
4. Navigate to: `/Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats/Modules/Screenshots/`
5. Select **all 5 files**:
   - `main.swift`
   - `popup.swift`
   - `settings.swift`
   - `config.plist`
   - `Info.plist`
6. Make sure:
   - ✅ **"Copy items if needed"** is UNCHECKED (files already in correct location)
   - ✅ **"Create groups"** is selected (not folder references)
   - ✅ **"Add to targets"** has "Screenshots" checked
7. Click **Add**

### Step 4: Configure Framework Dependencies

1. Select **Stats** target in the project settings
2. Go to **Build Phases** tab
3. Expand **"Link Binary With Libraries"**
4. Click the **"+"** button
5. Select **Screenshots.framework** from the list
6. Click **Add**

### Step 5: Set Framework Search Paths

1. Select **Stats** target
2. Go to **Build Settings** tab
3. Search for **"Framework Search Paths"**
4. Add: `$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)`
5. This allows the Stats app to find the Screenshots framework at runtime

### Step 6: Configure Info.plist References

1. Select **Screenshots** target
2. Go to **Build Settings**
3. Search for **"Info.plist File"**
4. Set value to: `Modules/Screenshots/Info.plist`

### Step 7: Verify Module Imports

The code should already have these (already done):
```swift
// In AppDelegate.swift
import Screenshots  // Line 23 ✅

var modules: [Module] = [
    CPU(),
    GPU(),
    RAM(),
    Disk(),
    Sensors(),
    Network(),
    Battery(),
    Bluetooth(),
    Clock(),
    Screenshots()  // Line 36 ✅
]
```

---

## Build & Test

### Build the Project
```bash
# Command line build
cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats
xcodebuild -project Stats.xcodeproj \
  -scheme Stats \
  -configuration Debug \
  build
```

Or in Xcode: **Product → Build** (Cmd+B)

### Expected Results

**If successful:**
- Build completes without errors
- Screenshots.framework appears in Build Products
- Stats app includes Screenshots module

**If you see "No such module 'Screenshots'":**
- Verify Screenshots framework target exists
- Check that source files are added to Screenshots target (Step 3)
- Verify framework is linked to Stats target (Step 4)
- Clean build folder: **Product → Clean Build Folder** (Cmd+Shift+K), then rebuild

### Run the App
```bash
# Kill any existing instances
killall Stats 2>/dev/null

# Run from Xcode
# Product → Run (Cmd+R)
```

### Verify Screenshots Tab Appears

1. Launch Stats app
2. Look for **Screenshots** in the left sidebar
3. It should appear alongside CPU, GPU, RAM, etc.
4. Click on Screenshots tab
5. Should show:
   - List of session folders (Session_001, Session_002, etc.)
   - Current session marked as "🟢 Active"
   - Screenshot counts (X/14)

---

## Testing Screenshot Capture

### Test 1: Trigger Screenshot with Keyboard
1. Make sure app is running
2. Press **Cmd+Option+O** (screenshot shortcut)
3. Should capture active browser tab
4. Check console for: "✅ Screenshot saved successfully!"
5. Verify no crash occurs

### Test 2: Check Session Folder
```bash
# View screenshots directory
open ~/Library/Application\ Support/Stats/Screenshots/

# Should see Session_001 folder with PNG files
ls -lh ~/Library/Application\ Support/Stats/Screenshots/Session_001/
```

Expected output:
```
screenshot_001_01_2025-11-24_21-30-45.png
screenshot_001_02_2025-11-24_21-31-12.png
...
```

### Test 3: Manual Screenshot API Test
```bash
# With app running, send test request
curl -X POST http://localhost:9223/capture-active-tab

# Should return JSON with base64 image data
# Check console logs for save confirmation
```

---

## Troubleshooting

### Problem: "No such module 'Screenshots'"

**Cause**: Screenshots framework not added to Xcode project

**Solution**:
1. Verify Screenshots framework target exists in Xcode
2. Check Steps 2-6 above
3. Clean build: Cmd+Shift+K
4. Rebuild: Cmd+B

### Problem: Screenshots tab not appearing

**Causes**:
- Framework not linked to Stats target
- AppDelegate not importing module
- Module not instantiated in modules array

**Solution**:
1. Verify Step 4 (Link Binary With Libraries)
2. Check AppDelegate.swift has `import Screenshots` (line 23)
3. Check AppDelegate.swift has `Screenshots()` in modules array (line 36)

### Problem: Build errors in Screenshots module files

**Common Errors**:
```
Use of undeclared type 'Module'
Use of undeclared type 'ModuleType'
```

**Solution**: Add Kit framework dependency to Screenshots target
1. Select Screenshots target
2. Build Phases → Link Binary With Libraries
3. Add Kit.framework

### Problem: Screenshots files shown as red in Xcode

**Cause**: Files not found at expected path

**Solution**:
1. Right-click red file → Show in Finder
2. If file doesn't exist, something went wrong
3. Re-add files using Step 3 above

---

## Verification Checklist

Before considering integration complete:

- [ ] Screenshots framework target exists in Xcode
- [ ] All 5 files added to Screenshots target
- [ ] Screenshots.framework linked to Stats target
- [ ] Project builds without errors (Cmd+B succeeds)
- [ ] Stats app runs without crashing
- [ ] Screenshots tab visible in sidebar
- [ ] Can click Screenshots tab without crash
- [ ] Cmd+Option+O captures screenshot
- [ ] No "Trace/BPT trap: 5" crash
- [ ] Screenshots saved to Session folders

---

## Next Steps After Integration

Once Screenshots tab is visible and working:

1. **Test Screenshot Capture**:
   - Press Cmd+Option+O
   - Verify screenshot saves without crash
   - Check session folder has PNG file

2. **Test Session Management**:
   - Capture 14 screenshots
   - Verify Session_002 folder created automatically
   - Check session count resets to 0

3. **Test UI Functionality**:
   - Click session folder in UI
   - Verify individual screenshots open
   - Check "Active" badge on current session
   - Verify "Complete" badge on full sessions

---

## File Locations Reference

| Component | Path |
|-----------|------|
| **Module Files** | `/Modules/Screenshots/` |
| **Main Module** | `main.swift` (576 bytes) |
| **Popup UI** | `popup.swift` (11,015 bytes) |
| **Settings** | `settings.swift` (4,536 bytes) |
| **Config** | `config.plist` (466 bytes) |
| **Info.plist** | `Info.plist` (NEW - just created) |
| **AppDelegate** | `/Stats/AppDelegate.swift` (updated) |
| **File Manager** | `/Stats/Modules/ScreenshotFileManager.swift` (fixed crash) |
| **Screenshot Storage** | `~/Library/Application Support/Stats/Screenshots/` |

---

## Summary

This integration adds the Screenshots module as a proper framework within the Stats app, following the same pattern as CPU, GPU, RAM, and other modules. The module provides:

- **UI Tab**: Screenshots section in sidebar
- **Session Management**: Automatic folder organization (14 screenshots per session)
- **File Storage**: Individual PNG files in Application Support
- **Crash Fix**: Safe PNG conversion using direct CGImage method

The integration requires manual Xcode steps because:
- Creating framework targets requires GUI interaction
- Adding files to targets is best done through Xcode UI
- Setting up dependencies ensures proper linking
- This follows Apple's recommended workflow for modular Swift frameworks

---

## Support

If you encounter issues during integration:

1. Check this guide's Troubleshooting section
2. Verify all checkboxes in Verification Checklist
3. Clean build folder: Cmd+Shift+K
4. Rebuild: Cmd+B
5. Check Xcode console for specific error messages

For crash-related issues:
- View ScreenshotFileManager.swift lines 108-140 (crash fix)
- Check console logs for detailed error messages
- Verify CGImage conversion is being used (not tiffRepresentation)

**Status**: Ready for integration. Follow steps above to enable Screenshots tab in Stats app.
