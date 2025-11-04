# Quiz Stats System - Setup Guide

Complete step-by-step setup for the entire quiz automation system.

## Prerequisites

- macOS 10.15+
- Node.js 16+
- Swift 5.0+
- Xcode 12+
- Python 3.8+ (optional, for alternative scraper)

## System Architecture Overview

```
Keyboard Shortcut (Cmd+Option+Q)
        ↓
Swift App → Triggers Scraper Script
        ↓
Scraper extracts Q&A from webpage
        ↓
Sends JSON to Backend API (localhost:3000)
        ↓
Backend calls OpenAI/ChatGPT API
        ↓
Receives answer indices [3,2,4,1,...]
        ↓
Sends via HTTP to Swift App (localhost:8080)
        ↓
Swift animates display with answers
```

## Step 1: Setup Backend Server

### 1.1 Install Dependencies

```bash
cd ~/Desktop/Universität/Stats/backend
npm install
```

### 1.2 Configure Environment

```bash
# Copy example config
cp .env.example .env

# Edit .env with your NEW OpenAI API key
nano .env
```

**IMPORTANT**: You MUST create a NEW OpenAI API key and NOT use the exposed one!

1. Go to: https://platform.openai.com/account/api-keys
2. Delete the old exposed key
3. Create a new key
4. Paste it in `.env`:

```
OPENAI_API_KEY=sk-proj-[YOUR_NEW_KEY]
OPENAI_MODEL=gpt-3.5-turbo
BACKEND_PORT=3000
STATS_APP_URL=http://localhost:8080
```

### 1.3 Start Backend Server

```bash
cd ~/Desktop/Universität/Stats/backend
npm start
```

Expected output:
```
✅ Backend server running on http://localhost:3000
   OpenAI Model: gpt-3.5-turbo
   Stats App URL: http://localhost:8080
   WebSocket: ws://localhost:3000
```

**Keep this terminal open!**

## Step 2: Setup Scraper

### 2.1 Install Scraper Dependencies

```bash
cd ~/Desktop/Universität/Stats
npm install
```

### 2.2 Test Scraper

Create a test HTML file to verify scraper works:

```bash
# Create test file
cat > test.html << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Quiz Test</title></head>
<body>
  <div class="question">
    <h3>What is 2+2?</h3>
    <label><input type="radio" name="q1"> 1</label>
    <label><input type="radio" name="q1"> 2</label>
    <label><input type="radio" name="q1"> 3</label>
    <label><input type="radio" name="q1"> 4</label>
  </div>
</body>
</html>
EOF

# Test scraper on a real website
node scraper.js --url=https://example.com
```

## Step 3: Setup Swift Stats App

### 3.1 Create Modules Directory

```bash
mkdir -p ~/Desktop/Universität/Stats/cloned-stats/Stats/Modules
```

The following files should already be created:
- `QuizAnimationController.swift` - Animation logic
- `QuizHTTPServer.swift` - HTTP server for receiving commands
- `KeyboardShortcutManager.swift` - Keyboard shortcut handling
- `QuizIntegrationManager.swift` - Coordinates all components

### 3.2 Integrate into AppDelegate

Edit `~/Desktop/Universität/Stats/cloned-stats/Stats/AppDelegate.swift` and add:

```swift
import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var quizManager: QuizIntegrationManager?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Initialize quiz system
        quizManager = QuizIntegrationManager.shared
        quizManager?.initialize()

        // ... rest of your app initialization
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        quizManager?.shutdown()
    }
}
```

### 3.3 Update Display View

Modify the view that displays the number to use the quiz manager:

```swift
import SwiftUI

struct QuizDisplayView: View {
    @ObservedObject var quizManager = QuizIntegrationManager.shared

    var body: some View {
        VStack {
            Text("\(quizManager.currentDisplayValue)")
                .font(.system(size: 64, weight: .bold))
                .monospacedDigit()

            if quizManager.isAnimating {
                Text("Animating...")
                    .foregroundColor(.green)
            }
        }
    }
}
```

### 3.4 Build and Run Swift App

```bash
cd ~/Desktop/Universität/Stats/cloned-stats
xcodebuild -scheme Stats build
# Then run from Xcode or:
open -a Stats
```

## Step 4: Create Launcher Script

Create a shell script to start everything:

```bash
# Create ~/Desktop/Universität/Stats/start_quiz_system.sh
#!/bin/bash

echo "🚀 Starting Quiz Stats System..."

# Kill any existing processes
pkill -f "node.*backend" || true

# Start backend
echo "Starting backend..."
cd ~/Desktop/Universität/Stats/backend
npm start &
BACKEND_PID=$!

# Wait for backend to start
sleep 2

# Start Stats app
echo "Starting Stats app..."
open ~/Desktop/Universität/Stats/cloned-stats

echo "✅ System started!"
echo "Press Cmd+Option+Q to trigger quiz scraping"

wait
```

Make it executable:
```bash
chmod +x ~/Desktop/Universität/Stats/start_quiz_system.sh
```

## Step 5: Test the Complete Workflow

### Manual Test

1. **Start backend** (in Terminal 1):
```bash
cd ~/Desktop/Universität/Stats/backend
npm start
```

2. **Start Stats app** (in Terminal 2):
```bash
cd ~/Desktop/Universität/Stats/cloned-stats
xcodebuild -scheme Stats run
```

3. **Send test data to backend** (in Terminal 3):
```bash
curl -X POST http://localhost:3000/api/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "questions": [
      {"question": "What is 2+2?", "answers": ["1", "2", "3", "4"]},
      {"question": "What is 3+3?", "answers": ["5", "6", "7", "8"]},
      {"question": "What is 4+4?", "answers": ["8", "9", "10", "11"]}
    ]
  }'
```

Expected response:
```json
{
  "status": "success",
  "answers": [4, 2, 1],
  "questionCount": 3,
  "message": "Questions analyzed successfully"
}
```

4. **Check Swift app** - Should see animated numbers:
- Animate 0 → 4, stay 7s, animate down to 0, wait 15s
- Animate 0 → 2, stay 7s, animate down to 0, wait 15s
- Animate 0 → 1, stay 7s, animate down to 0, wait 15s
- Animate 0 → 10, stay 15s, stop

### Automated Test with Real Webpage

```bash
# In Terminal 3, trigger the scraper
node ~/Desktop/Universität/Stats/scraper.js --url=https://www.example.com
```

The scraper will:
1. Extract questions from webpage
2. Send to backend
3. Backend calls OpenAI
4. Results sent to Stats app
5. Animation starts

## Step 6: Keyboard Shortcut Integration

The system uses **Cmd+Option+Q** to trigger:

1. Opens browser and scrapes current page
2. Sends data to backend
3. Backend analyzes with OpenAI
4. Stats app animates with answers

To customize the key, edit `KeyboardShortcutManager.swift`:
```swift
init(triggerKey: String = "q") // Change "q" to another key
```

## Troubleshooting

### Backend not responding
```bash
# Check if running
lsof -i :3000

# Kill if stuck
kill -9 $(lsof -ti:3000)

# Restart
cd ~/Desktop/Universität/Stats/backend && npm start
```

### Stats app not receiving data
- Check backend is running: `curl http://localhost:3000/health`
- Check HTTP server on port 8080 is listening
- Check logs in Xcode console

### OpenAI API errors
- Verify new API key is valid
- Check you have API credits
- Ensure model name is correct (gpt-3.5-turbo or gpt-4)

### Scraper not finding questions
- Verify website has clear question structure
- Check browser console for errors
- Try a different website to test

## File Structure

```
Stats/
├── SYSTEM_ARCHITECTURE.md
├── SETUP_GUIDE.md (this file)
├── package.json (scraper dependencies)
├── scraper.js (DOM scraper)
├── backend/
│   ├── server.js (Express backend)
│   ├── package.json
│   ├── .env (KEEP SECRET - DO NOT COMMIT)
│   └── .env.example
├── cloned-stats/
│   └── Stats/
│       └── Modules/
│           ├── QuizAnimationController.swift
│           ├── QuizHTTPServer.swift
│           ├── KeyboardShortcutManager.swift
│           └── QuizIntegrationManager.swift
└── start_quiz_system.sh
```

## Security Notes

⚠️ **CRITICAL**:
1. **Never** commit `.env` file to git
2. **Never** share your OpenAI API key
3. Use `.gitignore` to exclude:
   ```
   backend/.env
   node_modules/
   .DS_Store
   ```

## Next Steps

1. Complete setup following steps 1-5 above
2. Test with manual curl requests
3. Test with real website scraping
4. Customize keyboard shortcut if needed
5. Deploy/automate as needed

## Support

If you encounter issues:
1. Check the logs in each component
2. Verify all services are running (`lsof -i`)
3. Test with curl directly to backend
4. Check OpenAI API status
5. Verify network connectivity
