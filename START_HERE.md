# 🚀 START HERE - Complete Step-by-Step Guide

This guide will walk you through **exactly how to start everything** from scratch.

---

## ⚠️ STEP 0: Create NEW OpenAI API Key (CRITICAL!)

Your old API key was exposed and **MUST be deleted immediately**.

### What You Need To Do:

1. **Go to OpenAI website**:
   - Open browser
   - Visit: https://platform.openai.com/account/api-keys

2. **Delete the OLD key**:
   - Look for the key starting with: `sk-proj-B8Elsnwgwamnb8V6...`
   - Click the trash/delete icon
   - Confirm deletion

3. **Create NEW key**:
   - Click "+ Create new secret key"
   - Copy the entire key (it starts with `sk-proj-...`)
   - Keep it safe (you'll use it in next steps)

**Example of what your new key looks like:**
```
sk-proj-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

✅ **Write it down or copy it to Notes app for now**

---

## STEP 1: Prepare Your Folders

Open Terminal and navigate to your Stats folder:

```bash
cd ~/Desktop/Universität/Stats
```

You should see:
```
Stats/
├── scraper.js
├── package.json
├── backend/
│   ├── server.js
│   ├── package.json
│   └── .env.example
└── cloned-stats/
    └── Stats/
        └── Modules/
            ├── QuizAnimationController.swift
            ├── QuizHTTPServer.swift
            ├── KeyboardShortcutManager.swift
            └── QuizIntegrationManager.swift
```

If you don't see these files, something went wrong. Contact support.

---

## STEP 2: Setup Backend Server

The backend is the "brain" that talks to OpenAI and receives scraper data.

### 2.1 Install Backend Dependencies

```bash
cd ~/Desktop/Universität/Stats/backend
npm install
```

This will download all required packages (Express, Axios, etc.)
**This takes 1-2 minutes**

### 2.2 Create .env File (WHERE TO PUT YOUR API KEY)

This is the **most important step**.

**Option A: Using Terminal (Recommended)**

```bash
cd ~/Desktop/Universität/Stats/backend
nano .env
```

This opens a text editor. Type exactly:

```
OPENAI_API_KEY=sk-proj-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
OPENAI_MODEL=gpt-3.5-turbo
BACKEND_PORT=3000
STATS_APP_URL=http://localhost:8080
```

**Replace `XXXXX...` with your NEW API key you copied above.**

Then:
- Press `Control + X`
- Press `Y` (for yes)
- Press `Enter`

**Option B: Using Text Editor (If terminal is confusing)**

1. Open Finder
2. Navigate to: `~/Desktop/Universität/Stats/backend/`
3. Right-click → New File
4. Name it: `.env` (yes, with the dot at the start)
5. Open with TextEdit
6. Paste this:
```
OPENAI_API_KEY=sk-proj-YOUR_NEW_KEY_HERE
OPENAI_MODEL=gpt-3.5-turbo
BACKEND_PORT=3000
STATS_APP_URL=http://localhost:8080
```
7. Replace `YOUR_NEW_KEY_HERE` with your actual key
8. Save

### 2.3 Verify .env File Was Created

```bash
cd ~/Desktop/Universität/Stats/backend
cat .env
```

You should see your API key printed out. ✅

---

## STEP 3: Start Backend Server

Keep Terminal open for this:

```bash
cd ~/Desktop/Universität/Stats/backend
npm start
```

You should see:
```
✅ Backend server running on http://localhost:3000
   OpenAI Model: gpt-3.5-turbo
   Stats App URL: http://localhost:8080
   WebSocket: ws://localhost:3000
```

**✅ Leave this Terminal window OPEN** - the backend must keep running!

---

## STEP 4: Setup Scraper (In NEW Terminal Window)

The scraper extracts questions from webpages.

### 4.1 Open a NEW Terminal

- Keep the first Terminal with backend running
- Open a new Terminal window (`Cmd+T`)

### 4.2 Install Scraper Dependencies

```bash
cd ~/Desktop/Universität/Stats
npm install
```

This takes 1-2 minutes (downloads Playwright browser automation).

---

## STEP 5: Setup Swift App

The Swift app displays the animated numbers.

### 5.1 Open Xcode

```bash
open ~/Desktop/Universität/Stats/cloned-stats
```

This should open the Stats app in Xcode.

### 5.2 Add Swift Modules to Project

1. In Xcode, right-click on the `Stats` folder (left sidebar)
2. Select "Add Files to 'Stats'..."
3. Navigate to: `~/Desktop/Universität/Stats/cloned-stats/Stats/Modules/`
4. Select all 4 files:
   - QuizAnimationController.swift
   - QuizHTTPServer.swift
   - KeyboardShortcutManager.swift
   - QuizIntegrationManager.swift
5. Click "Add"

### 5.3 Update AppDelegate

1. Find `AppDelegate.swift` in Xcode
2. Add these lines at the top (after imports):

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

### 5.4 Build and Run

In Xcode:
1. Press `Cmd+B` to build (wait for "Build Successful")
2. Press `Cmd+R` to run the app

The Stats app should launch.

---

## STEP 6: Test Everything is Working

### Test 6.1: Backend is Running

Open a **THIRD Terminal** and test:

```bash
curl http://localhost:3000/health
```

Should show:
```json
{"status":"ok","timestamp":"...","openai_configured":true}
```

✅ If you see `openai_configured: true` → Your API key is working!

### Test 6.2: Full Test

Still in your third Terminal:

```bash
curl -X POST http://localhost:3000/api/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "questions": [
      {"question": "What is 2+2?", "answers": ["1","2","3","4"]},
      {"question": "What is 3+3?", "answers": ["5","6","7","8"]}
    ]
  }'
```

Should show:
```json
{
  "status": "success",
  "answers": [4, 2],
  "questionCount": 2,
  "message": "Questions analyzed successfully"
}
```

✅ If you see this → Everything is working!

---

## STEP 7: Actually Use It!

Now that everything is setup, here's how to use the system:

### Method 1: Keyboard Shortcut (Automated)

1. Open any webpage with multiple-choice questions
2. Press **Cmd+Option+Q** anywhere in macOS
3. The scraper will:
   - Extract questions from current page
   - Send to backend
   - Call OpenAI API
   - Stats app will animate the answers

### Method 2: Manual Scraping (Testing)

In your third Terminal, run:

```bash
node ~/Desktop/Universität/Stats/scraper.js --url=https://www.example.com
```

This will:
1. Scrape the website
2. Send data to backend
3. Analyze with OpenAI
4. Stats app animates

---

## 📊 What to Expect

When you trigger the system, the Stats app display should show:

```
Answer 1 (e.g., index 4):
  0 ──→ 4 (animates up, 1.5 seconds)
  4 ──→ 4 (stays at 4, 7 seconds)
  4 ──→ 0 (animates down, 1.5 seconds)
  0 ──→ 0 (rests at 0, 15 seconds)

Answer 2 (e.g., index 2):
  0 ──→ 2 (animates up, 1.5 seconds)
  [continues same pattern]

...and so on for each answer...

Final:
  0 ──→ 10 (animates to 10, 1.5 seconds)
  10 ──→ 10 (stays at 10, 15 seconds)
  10 ──→ 0 (returns to 0)
  STOPS ✅
```

---

## 🎯 Summary - What's Running Where

After you complete all steps:

| Component | Location | Status | Port |
|-----------|----------|--------|------|
| Backend Server | Terminal 1 | Running | 3000 |
| Scraper | Terminal 2 | Ready | N/A |
| Stats App | Xcode | Running | 8080 |
| Testing | Terminal 3 | Ready | N/A |

---

## 🐛 Troubleshooting

### Backend won't start
```bash
# Kill any existing process
lsof -ti:3000 | xargs kill -9

# Try starting again
cd ~/Desktop/Universität/Stats/backend && npm start
```

### "API key not found" error
- Check `.env` file exists: `ls ~/Desktop/Universität/Stats/backend/.env`
- Check content: `cat ~/Desktop/Universität/Stats/backend/.env`
- Make sure key starts with `sk-proj-`

### Stats app doesn't show anything
- Make sure Stats app is running in Xcode
- Check all 4 Swift files are added to Xcode project
- Check AppDelegate.swift is updated

### curl commands not working
- Make sure backend is running in Terminal 1
- Make sure you're in correct directory
- Copy-paste the command exactly

### OpenAI API errors
- Verify API key is correct (copy from OpenAI website)
- Check you have API credits
- Check API key hasn't expired

---

## ✅ Quick Checklist

- [ ] Created NEW OpenAI API key
- [ ] Deleted OLD exposed key
- [ ] Backend dependencies installed (`npm install`)
- [ ] `.env` file created with API key
- [ ] Backend server running (`npm start`)
- [ ] Scraper dependencies installed (`npm install`)
- [ ] Swift modules added to Xcode
- [ ] AppDelegate.swift updated
- [ ] Stats app builds successfully
- [ ] Backend health check passes (`curl http://localhost:3000/health`)
- [ ] Full test API call works

---

## 📖 Next Steps After Everything Works

1. **Read the documentation**
   - `COMPLETE_SYSTEM_README.md` - Full overview
   - `SYSTEM_ARCHITECTURE.md` - How it works

2. **Try with real websites**
   - Find a page with quiz questions
   - Press Cmd+Option+Q
   - Watch it animate

3. **Customize (Optional)**
   - Change keyboard shortcut in `KeyboardShortcutManager.swift`
   - Change animation timing in `QuizAnimationController.swift`
   - Use different OpenAI model (GPT-4)

---

## 🆘 Still Having Issues?

1. **Check logs**: Look at Terminal output for error messages
2. **Verify files**: Make sure all files are in correct locations
3. **Re-read steps**: Make sure you didn't skip anything
4. **Test each part**: Use curl commands to test backend alone
5. **Read documentation**: `SETUP_GUIDE.md` has detailed troubleshooting

---

## 📞 Quick Reference

**Start Backend:**
```bash
cd ~/Desktop/Universität/Stats/backend && npm start
```

**Run Scraper Manually:**
```bash
node ~/Desktop/Universität/Stats/scraper.js --url=https://example.com
```

**Test Backend:**
```bash
curl http://localhost:3000/health
```

**Edit Environment Config:**
```bash
nano ~/Desktop/Universität/Stats/backend/.env
```

**View Your API Key:**
```bash
cat ~/Desktop/Universität/Stats/backend/.env
```

---

**Once you complete these steps, your system is ready to use!**

Press **Cmd+Option+Q** on any webpage and watch the magic happen! ✨

---

**Need help?** Check `SETUP_GUIDE.md` or `QUICK_START.md`
