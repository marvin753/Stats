# Chrome CDP Screenshot Service

A production-ready Node.js/TypeScript service that connects to Chrome via the Chrome DevTools Protocol (CDP) to capture full-page screenshots. Designed with stealth capabilities to be completely undetectable by websites.

## Features

- **Silent Full-Page Capture**: Captures entire web pages beyond the viewport using `Page.captureScreenshot` with `captureBeyondViewport: true`
- **Anti-Detection**: Stealth Chrome launch flags that disable automation signatures
- **Zero User Interference**: No DOM interaction, no scrolling, no visible UI changes
- **Auto-Recovery**: Automatic Chrome launch with retry logic
- **HTTP API**: Simple REST endpoints for integration with other applications
- **TypeScript**: Full type safety and IntelliSense support

## Requirements

- Node.js 18+ (recommended: Node.js 20+)
- Chrome/Chromium installed on the system
- macOS, Linux, or Windows

## Installation

```bash
# Navigate to the service directory
cd /Users/marvinbarsal/Desktop/Universität/Stats/chrome-cdp-service

# Install dependencies
npm install

# Build TypeScript (optional, for production)
npm run build
```

## Usage

### Starting the Service

```bash
# Development mode (with TypeScript hot reload)
npm run dev

# Production mode (requires build first)
npm run build
npm run serve

# Quick start (via ts-node)
npm start
```

The service will:
1. Launch Chrome with stealth flags on port 9222 (if not already running)
2. Start HTTP server on port 9223
3. Display available endpoints and test commands

### API Endpoints

#### 1. Health Check
```bash
GET http://localhost:9223/health
```

Response:
```json
{
  "status": "ok",
  "chrome": "connected",
  "port": 9222,
  "timestamp": "2025-11-13T12:00:00.000Z",
  "version": "Chrome/120.0.6099.109"
}
```

#### 2. Capture Active Tab Screenshot
```bash
POST http://localhost:9223/capture-active-tab
```

Response:
```json
{
  "success": true,
  "base64Image": "iVBORw0KGgoAAAANSUhEUgAA...",
  "url": "https://example.com",
  "title": "Example Domain",
  "timestamp": "2025-11-13T12:00:00.000Z",
  "dimensions": {
    "width": 1280,
    "height": 3500
  }
}
```

#### 3. List Chrome Targets (Debug)
```bash
GET http://localhost:9223/targets
```

Response:
```json
{
  "success": true,
  "count": 3,
  "targets": [
    {
      "id": "...",
      "type": "page",
      "title": "Example Domain",
      "url": "https://example.com"
    }
  ],
  "timestamp": "2025-11-13T12:00:00.000Z"
}
```

## Testing

### Test with cURL

```bash
# Health check
curl http://localhost:9223/health

# Capture screenshot
curl -X POST http://localhost:9223/capture-active-tab | jq '.base64Image' -r | base64 -d > screenshot.png

# List all tabs
curl http://localhost:9223/targets | jq
```

### Test with HTTPie

```bash
# Health check
http GET :9223/health

# Capture screenshot
http POST :9223/capture-active-tab
```

### Verify Stealth Mode

Open Chrome's DevTools console and run:

```javascript
// Should be undefined (not true)
console.log(navigator.webdriver);
```

If `navigator.webdriver` is `undefined`, the stealth flags are working correctly.

## Configuration

Edit `src/types.ts` to modify default configuration:

```typescript
export const DEFAULT_CONFIG: ServiceConfig = {
  port: 9223,                // Service HTTP port
  chromeDebugPort: 9222,     // Chrome remote debugging port
  stealthMode: true,         // Enable stealth flags
  maxRetries: 3,             // Retry attempts for screenshot capture
  retryDelay: 1000,          // Delay between retries (ms)
};
```

## Stealth Chrome Flags

The service launches Chrome with the following anti-detection flags:

```typescript
--disable-blink-features=AutomationControlled  // Removes navigator.webdriver
--disable-dev-shm-usage
--no-first-run
--no-default-browser-check
--disable-background-networking
--disable-background-timer-throttling
--disable-backgrounding-occluded-windows
--disable-breakpad
--disable-component-extensions-with-background-pages
--disable-extensions
--disable-features=TranslateUI
--disable-ipc-flooding-protection
--disable-renderer-backgrounding
--force-color-profile=srgb
--metrics-recording-only
--no-sandbox
--disable-setuid-sandbox
--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36...
```

## Architecture

```
chrome-cdp-service/
├── src/
│   ├── index.ts           # Express server (port 9223)
│   ├── chrome-manager.ts  # Chrome launcher with stealth flags
│   ├── cdp-client.ts      # CDP connection and screenshot logic
│   └── types.ts           # TypeScript interfaces
├── package.json
├── tsconfig.json
└── README.md
```

### Component Responsibilities

- **index.ts**: HTTP API server with endpoints for health checks and screenshot capture
- **chrome-manager.ts**: Manages Chrome browser lifecycle, launches with stealth flags
- **cdp-client.ts**: Handles Chrome DevTools Protocol communication and screenshot capture
- **types.ts**: TypeScript type definitions and configuration

## Error Handling

The service includes comprehensive error handling:

1. **Chrome Not Running**: Automatically launches Chrome with stealth flags
2. **CDP Connection Fails**: Retries up to 3 times with 1-second delay
3. **No Active Tab**: Returns meaningful error message
4. **Screenshot Capture Fails**: Returns detailed error information

Example error response:
```json
{
  "success": false,
  "error": "Failed to capture screenshot",
  "details": "No active tab found. Please open a web page in Chrome.",
  "timestamp": "2025-11-13T12:00:00.000Z"
}
```

## Integration with Swift App

The Swift app can communicate with this service via HTTP:

```swift
// Health check
let healthURL = URL(string: "http://localhost:9223/health")!
let healthTask = URLSession.shared.dataTask(with: healthURL) { data, response, error in
    // Handle health check response
}
healthTask.resume()

// Capture screenshot
var captureRequest = URLRequest(url: URL(string: "http://localhost:9223/capture-active-tab")!)
captureRequest.httpMethod = "POST"
let captureTask = URLSession.shared.dataTask(with: captureRequest) { data, response, error in
    if let data = data,
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let base64Image = json["base64Image"] as? String,
       let imageData = Data(base64Encoded: base64Image) {
        // Use imageData to create UIImage/NSImage
    }
}
captureTask.resume()
```

## Stopping the Service

Press `Ctrl+C` in the terminal where the service is running. The service will:
1. Gracefully shut down the HTTP server
2. Clean up Chrome instance (if launched by the service)
3. Exit cleanly

## Troubleshooting

### Chrome won't connect
```bash
# Kill existing Chrome instances
pkill -f "Chrome.*remote-debugging-port"

# Restart service
npm start
```

### Port 9223 already in use
```bash
# Find and kill process using port 9223
lsof -ti:9223 | xargs kill -9

# Or change port in src/types.ts
```

### Screenshot returns empty/blank image
- Ensure the tab has finished loading
- Check that the URL is not a Chrome internal page (chrome://, about:blank)
- Verify the page allows screenshots (some DRM-protected content may not work)

### navigator.webdriver is true
- Ensure Chrome was launched with the `--disable-blink-features=AutomationControlled` flag
- Restart the service to relaunch Chrome with correct flags

## Performance

- **Startup Time**: ~2 seconds (Chrome launch + initialization)
- **Screenshot Capture**: ~500ms - 2s (depends on page size)
- **Memory Usage**: ~100MB (Node.js) + ~200MB (Chrome per tab)
- **Concurrent Requests**: Supports multiple capture requests (queued execution)

## Security Considerations

- Service runs on localhost only (not exposed to network)
- No authentication required (assumes local trust boundary)
- Chrome launched with `--no-sandbox` for compatibility (consider removing in production)
- Service can access any page in Chrome (ensure proper access controls in parent application)

## License

MIT

## Credits

Built with:
- [chrome-launcher](https://github.com/GoogleChrome/chrome-launcher) - Google Chrome launcher
- [chrome-remote-interface](https://github.com/cyrus-and/chrome-remote-interface) - Chrome DevTools Protocol client
- [Express.js](https://expressjs.com/) - HTTP server framework
- [TypeScript](https://www.typescriptlang.org/) - Type-safe JavaScript
