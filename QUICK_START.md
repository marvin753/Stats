# Quick Start Guide - 5 Minutes

Get the Quiz Stats System running in 5 minutes.

## ⚠️ CRITICAL FIRST STEP

**You exposed your OpenAI API key in your request!**

1. Go to: https://platform.openai.com/account/api-keys
2. **DELETE** the exposed key immediately
3. Create a **NEW** API key
4. Use the new key below

---

## Step 1: Setup Backend (2 minutes)

```bash
# Install dependencies
cd ~/Desktop/Universität/Stats/backend
npm install

# Create .env file
cat > .env << 'EOF'
OPENAI_API_KEY=sk-proj-[PASTE_YOUR_NEW_KEY_HERE]
OPENAI_MODEL=gpt-3.5-turbo
BACKEND_PORT=3000
STATS_APP_URL=http://localhost:8080
EOF

# Start backend (keep terminal open)
npm start
```

Expected output:
```
✅ Backend server running on http://localhost:3000
```

---

## Step 2: Setup Scraper (1 minute)

```bash
# Install scraper dependencies
cd ~/Desktop/Universität/Stats
npm install
```

---

## Step 3: Setup Swift App (2 minutes)

```bash
# The Swift modules are already created in:
# ~/Desktop/Universität/Stats/cloned-stats/Stats/Modules/
# - QuizAnimationController.swift
# - QuizHTTPServer.swift
# - KeyboardShortcutManager.swift
# - QuizIntegrationManager.swift

# You may need to add these to your Xcode project:
# 1. Open Xcode: open ~/Desktop/Universität/Stats/cloned-stats/*.xcodeproj
# 2. File → Add Files to Project
# 3. Select Stats/Modules/ folder
# 4. Check "Copy items if needed"
# 5. Click Add

# Then build and run
```

---

## Step 4: Test (1 minute)

### Test 1: Backend Health
```bash
curl http://localhost:3000/health
```

Should return:
```json
{"status":"ok","openai_configured":true}
```

### Test 2: Full Analysis
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

Should return:
```json
{
  "status": "success",
  "answers": [4, 2],
  "questionCount": 2
}
```

---

## Usage

### Trigger Quiz
```bash
# Press: Cmd+Option+Q (in any application)
# This should:
# 1. Launch the scraper
# 2. Extract questions from current webpage
# 3. Send to backend
# 4. Backend calls OpenAI
# 5. Stats app animates with answers
```

### Manual Scraping
```bash
# Scrape and analyze a webpage
node ~/Desktop/Universität/Stats/scraper.js --url=https://example.com
```

---

## Troubleshooting

**Backend not starting?**
```bash
# Kill existing process
lsof -ti:3000 | xargs kill -9

# Check .env file
cat ~/Desktop/Universität/Stats/backend/.env

# Restart
npm start
```

**OpenAI API error?**
- Verify you created a NEW API key
- Check the key is copied correctly in .env
- Ensure you have API credits

**Stats app not receiving data?**
```bash
# Check backend is running
curl http://localhost:3000/health

# Check port 8080 is available
lsof -i :8080
```

---

## File Structure

```
Stats/
├── QUICK_START.md (this file)
├── SETUP_GUIDE.md (detailed setup)
├── SYSTEM_ARCHITECTURE.md (design docs)
├── VALIDATION_REPORT.md (validation)
├── package.json (scraper deps)
├── scraper.js (DOM extractor)
├── backend/
│   ├── server.js (main server)
│   ├── package.json
│   ├── .env (YOUR SECRETS - don't commit)
│   └── .env.example
└── cloned-stats/
    └── Stats/
        └── Modules/
            ├── QuizAnimationController.swift
            ├── QuizHTTPServer.swift
            ├── KeyboardShortcutManager.swift
            └── QuizIntegrationManager.swift
```

---

## System Flow (Overview)

```
Cmd+Option+Q pressed
    ↓
Scraper runs
    ↓
Extracts Q&A from webpage
    ↓
Sends to backend (localhost:3000)
    ↓
Backend calls OpenAI API
    ↓
Gets answer indices [3,2,4,1,...]
    ↓
Sends to Swift app (localhost:8080)
    ↓
App animates numbers:
  0→3 (up, 1.5s)
  display 3 (7s)
  3→0 (down, 1.5s)
  display 0 (15s)
  [repeat for each answer]
  0→10 (final, 1.5s)
  display 10 (15s)
  stop
```

---

## Important Notes

1. ⚠️ **Create NEW API key** - Don't reuse the exposed one
2. ✅ Keep backend running in a terminal
3. ✅ Stats app must be running
4. ✅ Cmd+Option+Q triggers the entire workflow
5. ✅ No auto-restart - each trigger starts fresh

---

## Next Steps

1. Complete setup above
2. Test with curl requests
3. Test with real webpage
4. Customize keyboard shortcut if needed
5. Deploy and monitor

For detailed setup: See `SETUP_GUIDE.md`
For full validation: See `VALIDATION_REPORT.md`
For architecture: See `SYSTEM_ARCHITECTURE.md`
