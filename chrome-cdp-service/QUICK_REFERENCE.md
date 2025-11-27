# Chrome CDP Service - Quick Reference Card

## Start/Stop

```bash
# Start service
cd /Users/marvinbarsal/Desktop/Universität/Stats/chrome-cdp-service
npm start

# Stop service
Ctrl+C
```

## Test Endpoints

```bash
# Health check
curl http://localhost:9223/health

# Capture active tab
curl -X POST http://localhost:9223/capture-active-tab

# List Chrome targets
curl http://localhost:9223/targets
```

## Save Screenshot

```bash
curl -X POST http://localhost:9223/capture-active-tab | \
  python3 -c "import sys, json, base64; open('screenshot.png', 'wb').write(base64.b64decode(json.load(sys.stdin)['base64Image']))"

open screenshot.png
```

## Verify Stealth Mode

```bash
open verify-stealth.html
```

Expected: All tests pass, `navigator.webdriver` is `undefined`

## Troubleshooting

```bash
# Port in use
lsof -ti:9223 | xargs kill -9

# Chrome won't connect
pkill -f "Chrome.*remote-debugging-port"

# No active tab
open "https://example.com"
```

## Ports

- **Service:** 9223
- **Chrome Debug:** 9222

## Files

- **Source:** `src/*.ts`
- **Compiled:** `dist/*.js`
- **Config:** `package.json`, `tsconfig.json`

## Key Features

✅ Full-page screenshots via CDP
✅ Stealth mode (no `navigator.webdriver`)
✅ Auto-retry (3 attempts)
✅ Zero macOS notifications
✅ Base64 PNG output

## Swift Integration

```swift
var request = URLRequest(url: URL(string: "http://localhost:9223/capture-active-tab")!)
request.httpMethod = "POST"

URLSession.shared.dataTask(with: request) { data, response, error in
    if let data = data,
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let base64Image = json["base64Image"] as? String,
       let imageData = Data(base64Encoded: base64Image),
       let image = NSImage(data: imageData) {
        // Use image
    }
}.resume()
```

## Documentation

- **README.md** - Full documentation
- **INSTALLATION.md** - Setup guide
- **WAVE_2A_COMPLETION_REPORT.md** - Implementation details

---

**Service Location:** `/Users/marvinbarsal/Desktop/Universität/Stats/chrome-cdp-service/`
**Status:** ✅ Production Ready
