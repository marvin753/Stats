# Chrome CDP Capture - Quick Reference

**Wave 3A** | **November 13, 2025**

---

## Quick Start

### 1. Start CDP Service
```bash
cd ~/Desktop/Universität/Stats/chrome-cdp-service
npm start
```

### 2. Run Stats App
```bash
cd ~/Desktop/Universität/Stats/cloned-stats
./run-swift.sh
```

### 3. Capture Screenshot
- Open Chrome with any webpage
- Press **Cmd+Option+O**
- No notification appears ✅

---

## Common Commands

### Check Service Health
```bash
curl http://localhost:9223/health
```

**Expected Response**:
```json
{
  "status": "ok",
  "chrome": "running"
}
```

### Manual Screenshot Capture
```bash
curl -X POST http://localhost:9223/capture-active-tab
```

**Returns**: JSON with base64 screenshot

---

## Troubleshooting

### Problem: "Service Not Available" Alert

**Solution**:
```bash
# Check if service is running
lsof -i :9223

# If not running, start it
cd ~/Desktop/Universität/Stats/chrome-cdp-service
npm start
```

---

### Problem: "No Active Chrome Tab"

**Solution**:
1. Open Google Chrome
2. Navigate to any webpage
3. Press Cmd+Option+O again

---

### Problem: Service Won't Start

**Solution**:
```bash
# Kill any process on port 9223
lsof -ti:9223 | xargs kill -9

# Restart service
npm start
```

---

### Problem: Stats App Can't Connect

**Solution**:
```bash
# Verify service is accessible
curl http://localhost:9223/health

# Check firewall isn't blocking port 9223
# System Preferences > Security & Privacy > Firewall Options
```

---

## Code Examples

### Basic Capture
```swift
Task {
    do {
        let screenshot = try await ChromeCDPCapture.shared.captureActiveTab()
        print("Captured: \(screenshot.count) bytes")
    } catch {
        print("Failed: \(error)")
    }
}
```

### Check Service Before Capture
```swift
Task {
    guard await ChromeCDPCapture.shared.isServiceAvailable() else {
        print("Service not running")
        return
    }

    let screenshot = try await ChromeCDPCapture.shared.captureActiveTab()
    // Process screenshot...
}
```

### Run Built-in Tests
```swift
Task {
    await ChromeCDPCapture.shared.test()
}
```

---

## Error Handling

### CDPError Types

| Error | Meaning | Solution |
|-------|---------|----------|
| `serviceUnavailable` | CDP service not running | Start service with `npm start` |
| `noActiveTab` | No Chrome tab open | Open a webpage in Chrome |
| `invalidURL` | Bad service URL | Check localhost:9223 |
| `invalidResponse` | Bad HTTP response | Restart service |
| `requestFailed(code)` | HTTP error | Check logs |
| `captureFailed` | Server-side error | Retry or check logs |

---

## Performance Tips

1. **Keep Service Running**: Start once, capture many times
2. **Wait for Page Load**: Let page fully render before capture
3. **Close Unused Tabs**: Reduces Chrome memory usage
4. **Monitor Logs**: Check console for errors

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **Cmd+Option+O** | Capture screenshot (CDP) |
| **Cmd+Control+P** | Process all screenshots |
| **Cmd+Option+[0-5]** | Set expected question count |

---

## File Locations

```
Stats/
├── chrome-cdp-service/          # CDP service (Node.js)
│   ├── src/server.ts            # Service implementation
│   └── package.json
│
└── cloned-stats/Stats/Modules/
    ├── ChromeCDPCapture.swift   # Swift CDP client (NEW)
    └── ScreenshotCapture.swift  # Old approach (DEPRECATED)
```

---

## Integration Flow

```
User: Cmd+Option+O
    ↓
QuizIntegrationManager.onCaptureScreenshot()
    ↓
ChromeCDPCapture.shared.captureActiveTab()
    ↓
HTTP POST http://localhost:9223/capture-active-tab
    ↓
CDP Service → Chrome DevTools Protocol
    ↓
Screenshot returned (base64 PNG)
    ↓
ScreenshotStateManager.addScreenshot()
    ↓
Console: "✅ Screenshot N captured successfully via CDP"
```

---

## Comparison: Old vs New

### Before (Screen Recording)
```swift
let capture = ScreenshotCapture()
if capture.hasScreenRecordingPermission() {
    let screenshot = capture.captureMainDisplay()
}
// ⚠️ Shows macOS notification
```

### After (Chrome CDP)
```swift
let screenshot = try await ChromeCDPCapture.shared.captureActiveTab()
// ✅ No notification!
```

---

## Status Indicators

### Console Emoji Guide

| Emoji | Meaning |
|-------|---------|
| 🔧 | Initialization |
| 🔍 | Health check |
| 📤 | Sending request |
| 📥 | Receiving response |
| ✅ | Success |
| ❌ | Error |
| ⚠️ | Warning |
| 🌐 | Network operation |
| 📸 | Screenshot capture |

---

## Testing Checklist

- [ ] CDP service starts successfully (`npm start`)
- [ ] Health check returns "ok" (`curl localhost:9223/health`)
- [ ] Chrome opens automatically if not running
- [ ] Capture works with webpage open
- [ ] No macOS notification appears
- [ ] Screenshot stored in ScreenshotStateManager
- [ ] Error alert shown when service unavailable
- [ ] Multiple screenshots can be captured
- [ ] Screenshots processable with Cmd+Control+P

---

## Getting Help

### Check Logs
```bash
# CDP service logs
cd chrome-cdp-service
npm start  # Shows console output

# Swift app logs
./run-swift.sh  # Shows Xcode console output
```

### Debug Mode
```bash
# CDP service with verbose logging
DEBUG=* npm start

# Swift app - use Xcode for breakpoints
open Stats.xcodeproj
# Cmd+R to run with debugger
```

---

## Further Reading

- **Wave 2A Report**: `chrome-cdp-service/WAVE_2A_COMPLETION_REPORT.md`
- **Wave 3A Report**: `WAVE_3A_COMPLETION_REPORT.md`
- **Main Documentation**: `CLAUDE.md`
- **CDP Service README**: `chrome-cdp-service/README.md`

---

**Last Updated**: November 13, 2025
**Wave**: 3A
**Status**: Production Ready ✅
