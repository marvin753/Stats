# Screenshots Module Setup Guide

## Overview

The Screenshots module has been successfully created for the Stats macOS app. This module displays screenshot sessions in the sidebar and allows users to view and manage their captured screenshots.

## Files Created

### 1. Module Structure
All files are located in `/Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats/Modules/Screenshots/`:

- **main.swift** (576 bytes) - Module initialization and entry point
- **popup.swift** (11,015 bytes) - Main UI with session list display
- **settings.swift** (4,536 bytes) - Settings view with module info
- **config.plist** (466 bytes) - Module configuration file

### 2. Framework Updates

**Kit/constants.swift**:
- Added `.screenshots` case to `ModuleType` enum
- Added string value mapping "Screenshots"

**Stats/AppDelegate.swift**:
- Added `import Screenshots`
- Added `Screenshots()` to the modules array

## Module Features

### Popup View (popup.swift)
The popup displays a scrollable list of screenshot sessions with the following features:

- **Header**: Shows "Screenshots" title with refresh icon
- **Session List**: Displays all sessions in descending order (newest first)
- **Session Information**:
  - Session number (e.g., "Session 001")
  - Screenshot count (e.g., "8/14 screenshots")
  - Status badge:
    - "🟢 Active" - Current active session
    - "✓ Complete" - Session with 14 screenshots
- **Click to Open**: Sessions with combined PNG files can be clicked to open in default viewer
- **Auto-refresh**: Automatically updates every 5 seconds when visible
- **Empty State**: Shows helpful message when no sessions exist

### Settings View (settings.swift)
The settings view provides:

- **Module Info**: Description of how the module works
- **Storage Location**: Display of screenshot folder path
- **Open Folder Button**: Quick access to screenshots directory
- **Current Status**: Real-time display of:
  - Current session name
  - Screenshots in current session
  - Total number of sessions

### Integration Points

The module integrates with `ScreenshotFileManager` to:
- Read session folders from `~/Library/Application Support/Stats/Screenshots/`
- Get current session information
- Count screenshots per session
- Detect combined PNG files (Session_XXX.png)

## Xcode Project Integration

### Required Steps

To complete the integration, you need to add the Screenshots module to the Xcode project:

1. **Open Xcode Project**:
   ```bash
   open /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats/Stats.xcodeproj
   ```

2. **Add Screenshots Target**:
   - In Xcode, go to File → New → Target
   - Select "Framework" under macOS
   - Name it "Screenshots"
   - Language: Swift
   - Organization: Same as existing modules

3. **Add Source Files to Target**:
   - Right-click on the project navigator
   - Select "Add Files to Stats..."
   - Navigate to `Modules/Screenshots/`
   - Select all .swift files (main.swift, popup.swift, settings.swift)
   - Ensure "Copy items if needed" is **unchecked**
   - Select the "Screenshots" target
   - Click "Add"

4. **Add config.plist to Target**:
   - Drag `config.plist` into the Screenshots target folder
   - Ensure it's included in "Copy Bundle Resources"

5. **Configure Module Dependencies**:
   - Select the Screenshots target
   - Go to "Build Phases"
   - Add "Kit" framework to "Link Binary With Libraries"

6. **Add to App Target**:
   - Select the "Stats" (app) target
   - Go to "General" → "Frameworks, Libraries, and Embedded Content"
   - Add the "Screenshots.framework"
   - Set "Embed & Sign"

## Build Configuration

After adding to Xcode, build the project:

```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats
xcodebuild -project Stats.xcodeproj -scheme Stats -configuration Debug build
```

Or use the build script:
```bash
./build-swift.sh
```

## Testing the Module

### 1. Verify Module Appears in Sidebar
After building and running the app:
- The Screenshots module should appear in the left sidebar
- It should have a photo stack icon
- Clicking it should show the popup

### 2. Test Popup Functionality
- Open the popup by clicking the Screenshots module
- Verify the session list displays correctly
- Check that the refresh button works
- Confirm empty state displays if no sessions exist

### 3. Test Session Display
If you have existing sessions:
- Verify session names are displayed (Session_001, etc.)
- Check screenshot counts are accurate
- Confirm active session is marked with 🟢
- Verify completed sessions show ✓
- Click on a session with combined PNG to open it

### 4. Test Settings View
- Click the settings icon in the popup header
- Verify module information is displayed
- Check storage location path is correct
- Click "Open Screenshots Folder" button
- Verify it opens the correct directory

## Icon Configuration

The module uses SF Symbols for icons:
- **Primary**: `photo.stack` (stack of photos)
- **Fallback**: `folder.fill` (filled folder)

Both icons work on macOS 11.0+. For older versions, ensure fallback handling is in place.

## Session Data Structure

The module expects screenshot sessions to be organized as:

```
~/Library/Application Support/Stats/Screenshots/
├── Session_001/
│   ├── screenshot_001_01_2025-11-24_10-30-00.png
│   ├── screenshot_001_02_2025-11-24_10-30-15.png
│   └── Session_001.png (combined PNG)
├── Session_002/
│   ├── screenshot_002_01_2025-11-24_11-00-00.png
│   └── Session_002.png (combined PNG - if exists)
```

## Troubleshooting

### Module Not Appearing
- Verify all files are added to Xcode project
- Check that Screenshots target builds successfully
- Ensure Screenshots.framework is linked to Stats app target
- Verify import statement in AppDelegate.swift

### Empty Session List
- Check that screenshots exist in the correct directory
- Verify folder naming follows "Session_XXX" pattern
- Ensure ScreenshotFileManager has proper permissions

### Combined PNG Not Clickable
- Verify the PNG file exists: `Session_XXX.png`
- Check file permissions are readable
- Ensure file naming matches expected pattern

### Settings Not Loading
- Verify PreferencesSection is imported from Kit
- Check that ScreenshotFileManager.shared is accessible
- Ensure settings view is properly initialized in main.swift

## Code Architecture

### Module Initialization Flow
```swift
Screenshots.init()
  ↓
Creates Settings(.screenshots)
  ↓
Creates Popup(.screenshots)
  ↓
Calls super.init(moduleType: .screenshots, popup:, settings:)
  ↓
Module is mounted in AppDelegate
```

### Data Flow
```
ScreenshotFileManager.shared
  ↓
getAllSessions() → Returns session folder URLs
  ↓
getScreenshotCount(inSession:) → Returns count per session
  ↓
getCurrentSessionFolder() → Returns active session
  ↓
Popup.loadSessions() → Parses data
  ↓
updateSessionList() → Updates UI
```

## Performance Considerations

- **Auto-refresh**: Updates every 5 seconds when popup is visible
- **Lazy loading**: Sessions are loaded on-demand
- **Background thread**: File system operations run on background queue
- **Main thread UI**: UI updates dispatched to main queue

## Future Enhancements

Potential improvements for future versions:
1. Add search/filter functionality for sessions
2. Implement session deletion from UI
3. Add preview thumbnails for combined PNGs
4. Display individual screenshots within sessions
5. Export/share functionality
6. Session naming/tagging system
7. Statistics view (total screenshots, storage size, etc.)

## Summary

The Screenshots module is now fully implemented and ready to be integrated into the Xcode project. Follow the "Required Steps" section to add it to your build, then test using the guidelines provided.

All code follows the existing Stats app patterns and integrates seamlessly with the ScreenshotFileManager for session management.
