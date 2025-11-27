# Chrome CDP Screenshot Service - Installation Guide

## Quick Start (5 Minutes)

```bash
# 1. Navigate to service directory
cd /Users/marvinbarsal/Desktop/Universität/Stats/chrome-cdp-service

# 2. Install dependencies
npm install

# 3. Start the service
npm start

# 4. Test it (in another terminal)
curl http://localhost:9223/health
```

That's it! The service is now running and ready to capture screenshots.

## What Just Happened?

When you ran `npm start`, the service:

1. **Checked for Chrome** - If Chrome with remote debugging is already running on port 9222, it connects to it
2. **Launched Chrome (if needed)** - With stealth flags to avoid detection:
   - `--disable-blink-features=AutomationControlled` - Removes `navigator.webdriver` signature
   - Custom user agent matching standard Chrome
   - All automation indicators disabled
3. **Started HTTP server** - Listening on port 9223 for screenshot requests
4. **Ready to capture** - Waiting for POST requests to `/capture-active-tab`

## Verifying Installation

### 1. Check Service Status

```bash
curl http://localhost:9223/health
```

Expected output:
```json
{
  "status": "ok",
  "chrome": "connected",
  "port": 9222,
  "timestamp": "2025-11-13T...",
  "version": "Chrome/120.0.6099.109"
}
```

### 2. Verify Stealth Mode

Open this file in Chrome:
```bash
open /Users/marvinbarsal/Desktop/Universität/Stats/chrome-cdp-service/verify-stealth.html
```

You should see:
- ✅ `navigator.webdriver is undefined`
- ✅ All stealth tests passing

### 3. Test Screenshot Capture

First, open a website in Chrome:
```bash
open "https://example.com"
```

Then capture it:
```bash
curl -X POST http://localhost:9223/capture-active-tab > response.json
cat response.json | python3 -m json.tool | head -20
```

Expected output:
```json
{
  "success": true,
  "base64Image": "iVBORw0KGgoAAAANSUhEUgAA...",
  "url": "https://example.com",
  "title": "Example Domain",
  "timestamp": "2025-11-13T...",
  "dimensions": {
    "width": 1280,
    "height": 2500
  }
}
```

### 4. Save Screenshot to File

```bash
curl -X POST http://localhost:9223/capture-active-tab | \
  python3 -c "import sys, json, base64; data=json.load(sys.stdin); open('screenshot.png', 'wb').write(base64.b64decode(data['base64Image']))"

open screenshot.png
```

## Directory Structure

After installation, you should have:

```
chrome-cdp-service/
├── node_modules/           (146 packages installed)
├── dist/                   (Compiled JavaScript from TypeScript)
├── src/
│   ├── index.ts            (Express server - port 9223)
│   ├── chrome-manager.ts   (Chrome launcher with stealth flags)
│   ├── cdp-client.ts       (CDP screenshot logic)
│   └── types.ts            (TypeScript interfaces)
├── package.json
├── tsconfig.json
├── README.md
├── INSTALLATION.md         (This file)
├── test-capture.sh         (Test script)
└── verify-stealth.html     (Stealth mode verification page)
```

## Common Issues

### Issue: "Port 9223 already in use"

**Solution:**
```bash
# Find and kill the process
lsof -ti:9223 | xargs kill -9

# Restart service
npm start
```

### Issue: "Chrome won't connect"

**Solution:**
```bash
# Kill all Chrome instances with remote debugging
pkill -f "Chrome.*remote-debugging-port"

# Restart service (it will launch Chrome automatically)
npm start
```

### Issue: "navigator.webdriver is true"

This means stealth flags aren't working. **Solution:**

1. Stop the service (Ctrl+C)
2. Kill all Chrome instances:
   ```bash
   pkill -f Chrome
   ```
3. Restart service:
   ```bash
   npm start
   ```
4. Verify stealth mode again:
   ```bash
   open verify-stealth.html
   ```

### Issue: "No active tab found"

This means Chrome has no open web pages. **Solution:**
```bash
# Open a test page
open "https://example.com"

# Wait for it to load, then capture
sleep 2
curl -X POST http://localhost:9223/capture-active-tab
```

## Next Steps

### Integrate with Swift App

The Swift app will call this service via HTTP:

```swift
var request = URLRequest(url: URL(string: "http://localhost:9223/capture-active-tab")!)
request.httpMethod = "POST"

let task = URLSession.shared.dataTask(with: request) { data, response, error in
    if let data = data,
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let base64Image = json["base64Image"] as? String,
       let imageData = Data(base64Encoded: base64Image) {
        // Use imageData to create NSImage
        let image = NSImage(data: imageData)
    }
}
task.resume()
```

### Running as Background Service

To keep the service running in the background:

```bash
# Option 1: Use nohup
nohup npm start > cdp-service.log 2>&1 &

# Option 2: Use pm2 (install first: npm install -g pm2)
pm2 start npm --name "chrome-cdp-service" -- start
pm2 save
pm2 startup  # Auto-start on system boot
```

### Production Deployment

For production use:

1. **Build TypeScript:**
   ```bash
   npm run build
   ```

2. **Run compiled version:**
   ```bash
   npm run serve
   ```

3. **Set up monitoring:**
   ```bash
   pm2 start npm --name "chrome-cdp-service" -- run serve
   pm2 monit  # Monitor service
   ```

4. **Check logs:**
   ```bash
   pm2 logs chrome-cdp-service
   ```

## Configuration

All configuration is in `src/types.ts`:

```typescript
export const DEFAULT_CONFIG: ServiceConfig = {
  port: 9223,                // Service HTTP port
  chromeDebugPort: 9222,     // Chrome remote debugging port
  stealthMode: true,         // Enable stealth flags
  maxRetries: 3,             // Retry attempts for capture
  retryDelay: 1000,          // Delay between retries (ms)
};
```

To change ports, edit `src/types.ts` and rebuild:
```bash
npm run build
npm start
```

## Stopping the Service

Press **Ctrl+C** in the terminal where the service is running.

The service will:
1. Gracefully shut down the HTTP server
2. Clean up Chrome instance (if it launched it)
3. Exit cleanly

## Uninstallation

```bash
# Stop the service first (Ctrl+C)

# Remove the directory
cd /Users/marvinbarsal/Desktop/Universität/Stats
rm -rf chrome-cdp-service
```

## Getting Help

1. Check the main [README.md](/Users/marvinbarsal/Desktop/Universität/Stats/chrome-cdp-service/README.md)
2. Review the [API documentation](#api-endpoints)
3. Test with `curl` commands
4. Check service logs for errors

## Summary

You've successfully installed the Chrome CDP Screenshot Service!

Key points:
- ✅ Service runs on port **9223**
- ✅ Chrome runs with stealth flags (port **9222**)
- ✅ Full-page screenshots captured via CDP
- ✅ Zero macOS notifications or visible UI changes
- ✅ Base64 PNG returned via HTTP API

Test command:
```bash
curl -X POST http://localhost:9223/capture-active-tab | \
  python3 -c "import sys, json; print('✅ Captured:', json.load(sys.stdin).get('url'))"
```

Happy capturing! 📸
