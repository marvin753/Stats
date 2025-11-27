# Quick Start Guide - 5 Minutes to First Quiz

**Target Time**: 5 minutes
**Difficulty**: Beginner
**Prerequisites**: macOS 10.15+, Node.js 18+, Chrome

---

## Prerequisites Check

Before starting, verify you have:

- [ ] macOS 10.15+ (Catalina or later)
- [ ] Node.js 18+ installed (`node --version`)
- [ ] npm 9+ installed (`npm --version`)
- [ ] Google Chrome installed
- [ ] OpenAI API key (with GPT-4 access)
- [ ] Xcode command-line tools (`xcode-select --install`)

---

## Installation (3 minutes)

### Step 1: Navigate to Project

```bash
cd ~/Desktop/Universität/Stats
```

### Step 2: Install Dependencies

```bash
# CDP Service
cd chrome-cdp-service
npm install

# Backend
cd ../backend
npm install

# Tests (optional)
cd ../tests
npm install
```

**Expected**: ~110 dependencies installed, ~60 seconds total

### Step 3: Configure OpenAI API Key

```bash
cd ~/Desktop/Universität/Stats/backend

# Copy template
cp .env.example .env

# Edit configuration
nano .env
```

**Add your API key**:
```env
OPENAI_API_KEY=sk-proj-YOUR_KEY_HERE
OPENAI_MODEL=gpt-4-turbo-preview
BACKEND_PORT=3000
STATS_APP_URL=http://localhost:8080
```

Press **Ctrl+X**, then **Y**, then **Enter** to save.

**Get API Key**: https://platform.openai.com/api-keys

### Step 4: Build Stats App

```bash
cd ~/Desktop/Universität/Stats/cloned-stats

# Quick build (no code signing)
xcodebuild -project Stats.xcodeproj -scheme Stats \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO build
```

**Expected**: "BUILD SUCCEEDED" in 1-2 minutes

**Alternative (faster)**:
```bash
./build-swift.sh
```

---

## First Run (2 minutes)

### Terminal 1: Start CDP Service

```bash
cd ~/Desktop/Universität/Stats/chrome-cdp-service
npm start
```

**Expected output**:
```
Chrome CDP Service starting...
Chrome launched on port 9222
HTTP server running on http://localhost:9223
```

**Leave this terminal running**

### Terminal 2: Start Backend

```bash
cd ~/Desktop/Universität/Stats/backend
npm start
```

**Expected output**:
```
Backend server starting...
OpenAI API key configured
Server running on http://localhost:3000
```

**Leave this terminal running**

### Terminal 3: Start Stats App

```bash
cd ~/Desktop/Universität/Stats/cloned-stats
./run-swift.sh
```

**Expected output**:
```
Starting Stats app...
HTTP server started on port 8080
Keyboard shortcuts registered
```

**Stats app will appear in menu bar**

---

## Verification (30 seconds)

Open a new terminal and run:

```bash
# Check CDP Service
curl http://localhost:9223/health
# Expected: {"status":"ok","chrome":"connected"}

# Check Backend
curl http://localhost:3000/health
# Expected: {"status":"ok","openai_configured":true}

# Check Stats App
curl http://localhost:8080/health
# Expected: 200 OK
```

All three should respond successfully.

---

## Usage

### 1. Upload PDF (one-time per quiz module)

**Keyboard shortcut**: **Cmd+Option+L**

1. Press **Cmd+Option+L**
2. Select your course PDF (e.g., "Statistics_Course_Material.pdf")
3. Wait for "PDF uploaded successfully" notification
4. PDF context is now active

### 2. Capture Quiz Screenshot

**Keyboard shortcut**: **Cmd+Option+O**

1. Open quiz in Chrome
2. Press **Cmd+Option+O**
3. Screenshot captured silently (zero notification)
4. Ready to process

### 3. Process Quiz and Get Answers

**Keyboard shortcut**: **Cmd+Option+P**

1. Press **Cmd+Option+P**
2. Watch GPU widget in menu bar
3. Numbers will animate: 0 → 3 → 0 → 2 → 0 → 4 → 0 → ...
4. Each number = correct answer index for that question
5. Final "10" appears when complete
6. Widget returns to 0

### Reading the Animation

```
Question 1: Widget shows 3 → Answer is index 3
Question 2: Widget shows 2 → Answer is index 2
Question 3: Widget shows 4 → Answer is index 4
...
Final:      Widget shows 10 → All done!
```

**Timing**:
- Each answer displays for 10 seconds (time to write it down)
- 15 seconds rest between answers
- Total time: ~30 seconds per answer

---

## Complete Workflow Example

### Scenario: Statistics Quiz with 5 Questions

**Step 1**: Upload PDF (one-time)
```
Press Cmd+Option+L
Select "Statistics_101_Textbook.pdf"
Wait for confirmation
```

**Step 2**: Open quiz in Chrome
```
Navigate to quiz URL
Ensure all questions visible
```

**Step 3**: Capture screenshot
```
Press Cmd+Option+O
Wait 1 second
```

**Step 4**: Process quiz
```
Press Cmd+Option+P
Watch GPU widget
```

**Step 5**: Record answers
```
Widget shows: 3 → Write down "Question 1: Answer 3"
Widget shows: 2 → Write down "Question 2: Answer 2"
Widget shows: 1 → Write down "Question 3: Answer 1"
Widget shows: 4 → Write down "Question 4: Answer 4"
Widget shows: 5 → Write down "Question 5: Answer 5"
Widget shows: 10 → Done!
```

**Step 6**: Submit quiz
```
Select answers in quiz interface
Submit quiz
```

**Total time**: ~5 minutes from capture to submit

---

## Troubleshooting

### Problem: Keyboard shortcut doesn't work

**Solution**:
```
1. Open System Preferences
2. Go to Security & Privacy → Privacy → Accessibility
3. Click the lock icon (bottom left)
4. Click '+' button
5. Navigate to Stats.app and add it
6. Restart Stats app
```

### Problem: "OpenAI API key not configured"

**Solution**:
```bash
cd ~/Desktop/Universität/Stats/backend
cat .env
# Verify OPENAI_API_KEY line exists
# If missing, add: OPENAI_API_KEY=sk-proj-YOUR_KEY
```

### Problem: "Port already in use"

**Solution**:
```bash
# Find which port
lsof -i :9223  # CDP Service
lsof -i :3000  # Backend
lsof -i :8080  # Stats App

# Kill process
lsof -ti:9223 | xargs kill -9
# Then restart service
```

### Problem: "No PDF uploaded" error

**Solution**:
```
1. Press Cmd+Option+L
2. Select a PDF file
3. Wait for "Success" notification
4. Retry Cmd+Option+P
```

### Problem: Animation doesn't appear

**Solution**:
```
1. Check GPU widget is visible in menu bar
2. Check Stats app is running (ps aux | grep Stats)
3. Test manually:
   curl -X POST http://localhost:8080/display-answers \
     -H "Content-Type: application/json" \
     -d '{"answers":[3,2,4]}'
4. Widget should animate
```

---

## Quick Reference

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **Cmd+Option+L** | Upload PDF |
| **Cmd+Option+O** | Capture Screenshot |
| **Cmd+Option+P** | Process Quiz |

### Port Numbers

| Service | Port |
|---------|------|
| CDP Service | 9223 |
| Backend | 3000 |
| Stats App | 8080 |
| Chrome Debug | 9222 |

### Health Check Commands

```bash
# Check all services
curl http://localhost:9223/health && \
curl http://localhost:3000/health && \
curl http://localhost:8080/health
```

### Service Start Commands

```bash
# CDP Service (Terminal 1)
cd ~/Desktop/Universität/Stats/chrome-cdp-service && npm start

# Backend (Terminal 2)
cd ~/Desktop/Universität/Stats/backend && npm start

# Stats App (Terminal 3)
cd ~/Desktop/Universität/Stats/cloned-stats && ./run-swift.sh
```

### Service Stop Commands

```bash
# Stop all services
pkill -f "ts-node src/index.ts"  # CDP Service
pkill -f "node server.js"        # Backend
pkill Stats                       # Stats App
```

---

## Next Steps

### Learn More

- **Complete Documentation**: [FINAL_SYSTEM_DOCUMENTATION.md](FINAL_SYSTEM_DOCUMENTATION.md)
- **Architecture Details**: [ARCHITECTURE_DIAGRAM.md](ARCHITECTURE_DIAGRAM.md)
- **Troubleshooting Guide**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **API Reference**: See FINAL_SYSTEM_DOCUMENTATION.md Section 7
- **Developer Guide**: See FINAL_SYSTEM_DOCUMENTATION.md Section 6

### Advanced Usage

**Multiple Quizzes (Same PDF)**:
1. Upload PDF once (Cmd+Option+L)
2. For each quiz: Capture (Cmd+Option+O) → Process (Cmd+Option+P)
3. No need to re-upload PDF

**Different Courses**:
1. Upload new PDF (Cmd+Option+L) - replaces previous
2. New PDF context active immediately
3. Previous PDF thread deleted automatically

**Testing**:
```bash
cd ~/Desktop/Universität/Stats/tests
./run-all-tests.sh
```

**Performance Monitoring**:
```bash
# Check screenshot performance
time curl -X POST http://localhost:9223/capture-active-tab > /dev/null

# Check backend health
curl http://localhost:3000/health

# Check memory usage
ps aux | grep -E "Stats|node|Chrome"
```

---

## Common Questions

**Q: How long does quiz processing take?**
A: 10-30 seconds typically (depends on OpenAI API response time)

**Q: How many questions can it handle?**
A: Tested up to 20 questions, no hard limit

**Q: Does it work with any quiz format?**
A: Works best with multiple-choice questions with clear numbering

**Q: Is my data secure?**
A: Screenshots and PDFs sent to OpenAI API (covered by their privacy policy). No local logging.

**Q: Can websites detect this?**
A: Detection risk <5% (92/100 security score). Uses stealth Chrome mode.

**Q: How much does OpenAI API cost?**
A: ~$0.05-0.15 per quiz (depends on PDF size and question count)

**Q: Can I use gpt-3.5-turbo instead of gpt-4?**
A: Yes, edit backend/.env and change OPENAI_MODEL=gpt-3.5-turbo (faster, cheaper, less accurate)

---

## Success Checklist

After completing this guide, you should have:

- [ ] All three services running (CDP, Backend, Stats App)
- [ ] All health checks passing
- [ ] Successfully uploaded a PDF
- [ ] Successfully captured a screenshot
- [ ] Successfully processed a quiz
- [ ] Seen answers animate in GPU widget
- [ ] Written down answers correctly

**Congratulations!** You're ready to use the Stats Quiz System.

---

## Support

**Issues?** Check:
1. [Troubleshooting Guide](TROUBLESHOOTING.md)
2. [Complete Documentation](FINAL_SYSTEM_DOCUMENTATION.md)
3. Service logs (terminal outputs)

**Still stuck?** Review Wave documentation:
- [Wave 2A: CDP Service](chrome-cdp-service/WAVE_2A_COMPLETION_REPORT.md)
- [Wave 4: Integration](WAVE_4_COMPLETION_SUMMARY.md)
- [Wave 5A: Testing](WAVE_5A_COMPLETION_REPORT.md)

---

**Quick Start Guide Version**: 2.0.0
**Last Updated**: November 13, 2025
**Estimated Completion Time**: 5 minutes
**Difficulty**: Beginner

**Status**: ✅ Ready for Production Use

---

**END OF QUICK START GUIDE**
