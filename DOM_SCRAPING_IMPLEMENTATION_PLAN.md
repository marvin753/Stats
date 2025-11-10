# 📋 DOM Scraping & AI Filtering - Complete Implementation Plan

**Created**: 2025-11-09 01:30 AM
**Status**: Ready for Review & Approval
**Estimated Total Time**: ~5 hours
**Goal**: Create robust DOM scraping with AI-powered question extraction

---

## 🎯 EXECUTIVE SUMMARY

### Problem Statement

Current workflow FAILS at DOM extraction:

1. ❌ Scraper tries to parse DOM directly (brittle, fails on different page structures)
2. ❌ AppleScript error -1719 when Chrome windows minimized (FIXED in code, need to restart app)
3. ❌ Keyboard logging floods console with every keystroke (FIXED in code, need to restart app)

### Solution Architecture

Create a NEW 3-tier AI-powered filtering system:

```
Browser URL → Scraper (captures RAW DOM) →
AI Filter Service (extracts Q&A) →
Backend (selects answers via OpenAI) →
Swift App (displays animations)
```

**Key Innovation**: Use AI to FILTER raw DOM instead of hardcoded selectors

---

## 🏗️ CURRENT STATE vs TARGET STATE

### Current Architecture (BROKEN)

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │ AppleScript gets URL
       ↓
┌─────────────┐
│  scraper.js │ ← ❌ FAILS HERE: Hardcoded DOM selectors
└──────┬──────┘
       │ Extracted Q&A (often empty)
       ↓
┌─────────────┐
│   Backend   │ OpenAI selects answers
└──────┬──────┘
       ↓
┌─────────────┐
│  Swift App  │ Displays animation
└─────────────┘
```

**Failure Points**:

- Scraper has 3 fallback strategies but all fail on complex pages
- Cannot handle JavaScript-rendered content
- Breaks when page structure changes
- No intelligence - just CSS selectors

### Target Architecture (ROBUST)

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │ AppleScript gets URL
       ↓
┌─────────────┐
│  scraper.js │ Captures ENTIRE page DOM + visible text
└──────┬──────┘
       │ Raw HTML + visible text + metadata
       ↓
┌─────────────────┐
│ AI Filter       │ ← NEW: GPT-4 extracts Q&A from raw DOM
│ Service         │
│ (port 3001)     │
└──────┬──────────┘
       │ Clean JSON: [{question, answers}, ...]
       ↓
┌─────────────┐
│   Backend   │ OpenAI selects correct answers
│ (port 3000) │
└──────┬──────┘
       │ Answer indices: [3, 2, 4, ...]
       ↓
┌─────────────┐
│  Swift App  │ HTTP server receives, displays animation
│ (port 8080) │
└─────────────┘
```

**Advantages**:

- ✅ Works with ANY page structure (AI adapts)
- ✅ Handles JavaScript-rendered content (wait for DOM to settle)
- ✅ Intelligent extraction (AI understands context)
- ✅ Robust to page changes (no hardcoded selectors)

---

## 📐 DETAILED IMPLEMENTATION PLAN

### ⚡ PHASE 0: Prerequisites (5 minutes)

**BEFORE STARTING IMPLEMENTATION, USER MUST REVIEW AND APPROVE THIS PLAN**

#### Task 0.1: Restart Stats App with New Binary

**Why**: Current app is running OLD binary without AppleScript/keyboard fixes

**Action**:

```bash
# Kill current Stats app
pkill Stats

# Restart with new binary
cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats
./run-swift.sh
```

**Verify**:

- Open Chrome with ANY webpage
- Press Cmd+Shift+Z
- Console should:
  - ✅ ONLY log when Cmd+Shift+Z is pressed (not every keystroke)
  - ✅ Detect Chrome URL successfully (no -1719 error)

If still fails → investigate Chrome window state

#### Task 0.2: Kill Background Processes

**Action**:

```bash
# Kill all background node processes
pkill -f "node ai-parser"
pkill -f "xcodebuild"

# Verify clean slate
ps aux | grep node
ps aux | grep xcodebuild
```

---

### 🔧 PHASE 1: Enhanced Scraper with Full DOM Capture (1 hour)

**Agent**: `typescript-pro` (Node.js specialist)

#### Task 1.1: Modify scraper.js to Capture Raw DOM

**Current Code** (scraper.js - BROKEN):

```javascript
// Lines ~50-120: Extract questions from DOM
async function scrapeQuestions(url) {
  const browser = await playwright.chromium.launch();
  const page = await browser.newPage();
  await page.goto(url);

  // Strategy 1: Try .question selectors
  const questions = await page.$$(".question");
  if (questions.length > 0) {
    // Extract and return
  }

  // Strategy 2: Try <li> elements
  // ...

  // Strategy 3: Generic fallback
  // ...

  return extractedQuestions; // ❌ Often empty
}
```

**New Code** (ROBUST - capture everything):

```javascript
async function captureFullDOM(url) {
  const browser = await playwright.chromium.launch({ headless: true });
  const page = await browser.newPage();

  console.log(`📄 Navigating to: ${url}`);

  // Navigate and wait for page to fully load
  await page.goto(url, {
    waitUntil: "networkidle", // Wait for network to settle
    timeout: 30000,
  });

  // Wait for dynamic content
  await page.waitForTimeout(2000);

  console.log(`✅ Page loaded, capturing DOM...`);

  // Capture EVERYTHING
  const domData = {
    url: page.url(),
    title: await page.title(),

    // Raw HTML
    rawHTML: await page.content(),

    // Visible text (cleaned)
    visibleText: await page.textContent("body"),

    // Structured data
    metadata: {
      timestamp: new Date().toISOString(),
      userAgent: await page.evaluate(() => navigator.userAgent),
      viewportSize: await page.viewportSize(),
    },

    // Questions context (if detectable)
    possibleQuestions: await page.$$eval(
      '[class*="question"], [id*="question"], h3, h4',
      (elements) => elements.map((el) => el.textContent.trim())
    ),
  };

  await browser.close();

  console.log(`📦 Captured ${domData.rawHTML.length} chars of HTML`);
  console.log(`📝 Visible text: ${domData.visibleText.length} chars`);

  return domData;
}
```

**New Workflow**:

```javascript
// Main scraper workflow
async function scrapeAndAnalyze(url) {
  try {
    // 1. Capture raw DOM
    const domData = await captureFullDOM(url);

    // 2. Send to AI Filter Service (not backend!)
    console.log(`🔄 Sending to AI Filter Service...`);

    const response = await axios.post(
      "http://localhost:3001/filter-dom",
      domData,
      {
        headers: { "Content-Type": "application/json" },
        timeout: 60000, // 60 second timeout for AI processing
      }
    );

    console.log(
      `✅ AI Filter extracted ${response.data.questionCount} questions`
    );
    console.log(`✅ Answers sent to backend and Swift app`);
  } catch (error) {
    console.error(`❌ Scraper error: ${error.message}`);
    throw error;
  }
}
```

**Files to Modify**:

- `/Users/marvinbarsal/Desktop/Universität/Stats/scraper.js`

**Testing**:

```bash
# Test with real URL
node scraper.js --url=https://example.com/quiz

# Expected output:
# 📄 Navigating to: https://example.com/quiz
# ✅ Page loaded, capturing DOM...
# 📦 Captured 45231 chars of HTML
# 📝 Visible text: 8934 chars
# 🔄 Sending to AI Filter Service...
# ✅ AI Filter extracted 5 questions
# ✅ Answers sent to backend and Swift app
```

---

### 🤖 PHASE 2: AI Filter Service (NEW Component) (1.5 hours)

**Agent**: `backend-architect` + `typescript-pro`

#### Task 2.1: Create AI Filter Service Architecture

**Service Purpose**: Use GPT-4 to intelligently extract Q&A from raw DOM

**Service Specifications**:

````javascript
// New file: /Users/marvinbarsal/Desktop/Universität/Stats/ai-filter-service.js

const express = require("express");
const axios = require("axios");
const dotenv = require("dotenv");

dotenv.config({ path: ".env.ai-filter" });

const app = express();
app.use(express.json({ limit: "50mb" })); // Large limit for DOM data

const PORT = process.env.AI_FILTER_PORT || 3001;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const OPENAI_FILTER_MODEL = process.env.OPENAI_FILTER_MODEL || "gpt-4";
const BACKEND_URL = process.env.BACKEND_URL || "http://localhost:3000";

// Health check
app.get("/health", (req, res) => {
  res.json({
    status: "ok",
    service: "AI Filter Service",
    openai_configured: !!OPENAI_API_KEY,
  });
});

// Main endpoint: Filter raw DOM to extract questions
app.post("/filter-dom", async (req, res) => {
  const startTime = Date.now();
  const { rawHTML, visibleText, url, metadata } = req.body;

  console.log(`📥 Received DOM from: ${url}`);
  console.log(`   HTML size: ${rawHTML.length} chars`);
  console.log(`   Text size: ${visibleText.length} chars`);

  try {
    // Step 1: Send to OpenAI for intelligent extraction
    console.log(`🤖 Sending to OpenAI (${OPENAI_FILTER_MODEL})...`);

    const aiResponse = await axios.post(
      "https://api.openai.com/v1/chat/completions",
      {
        model: OPENAI_FILTER_MODEL,
        messages: [
          {
            role: "system",
            content: `You are a quiz question extractor. Your job is to analyze raw webpage content and extract ONLY the quiz questions and answer options.

CRITICAL RULES:
1. Extract ONLY actual quiz/test questions with multiple choice answers
2. Ignore navigation, headers, footers, ads, sidebars, comments
3. Each question must have 2-4 answer options
4. Preserve exact wording of questions and answers
5. Return ONLY valid JSON array (no markdown, no explanation)

Output format:
[
  {
    "question": "What is the capital of France?",
    "answers": ["London", "Paris", "Berlin", "Madrid"]
  },
  {
    "question": "What is 2+2?",
    "answers": ["3", "4", "5", "6"]
  }
]

If no quiz questions found, return empty array: []`,
          },
          {
            role: "user",
            content: `Extract quiz questions from this webpage:

URL: ${url}
Title: ${metadata?.title || "Unknown"}

Visible Text:
${visibleText.substring(0, 10000)}

${visibleText.length > 10000 ? "(truncated to 10000 chars)" : ""}

Return ONLY the JSON array.`,
          },
        ],
        temperature: 0.1, // Low temperature for consistent extraction
        max_tokens: 2000,
      },
      {
        headers: {
          Authorization: `Bearer ${OPENAI_API_KEY}`,
          "Content-Type": "application/json",
        },
      }
    );

    const aiContent = aiResponse.data.choices[0].message.content.trim();
    console.log(`🤖 OpenAI response: ${aiContent.substring(0, 200)}...`);

    // Step 2: Parse extracted questions
    let questions;
    try {
      // Remove markdown code blocks if present
      const jsonContent = aiContent
        .replace(/```json\n?/g, "")
        .replace(/```\n?/g, "")
        .trim();

      questions = JSON.parse(jsonContent);

      if (!Array.isArray(questions)) {
        throw new Error("Response is not an array");
      }
    } catch (parseError) {
      console.error(`❌ Failed to parse AI response: ${parseError.message}`);
      console.error(`   Raw content: ${aiContent}`);
      return res.status(500).json({
        error: "Failed to parse AI response",
        rawResponse: aiContent,
      });
    }

    console.log(`✅ Extracted ${questions.length} questions`);

    // Step 3: Validate question format
    const validQuestions = questions.filter((q) => {
      return (
        q.question &&
        Array.isArray(q.answers) &&
        q.answers.length >= 2 &&
        q.answers.length <= 4
      );
    });

    if (validQuestions.length < questions.length) {
      console.warn(
        `⚠️  Filtered out ${
          questions.length - validQuestions.length
        } invalid questions`
      );
    }

    if (validQuestions.length === 0) {
      console.warn(`⚠️  No valid questions found on page`);
      return res.json({
        status: "success",
        questionCount: 0,
        message: "No quiz questions detected on page",
      });
    }

    // Step 4: Forward to backend for answer selection
    console.log(
      `🔄 Forwarding ${validQuestions.length} questions to backend...`
    );

    const backendResponse = await axios.post(
      `${BACKEND_URL}/api/analyze`,
      { questions: validQuestions },
      { timeout: 30000 }
    );

    const elapsedTime = Date.now() - startTime;
    console.log(`✅ Complete workflow finished in ${elapsedTime}ms`);
    console.log(`   Questions extracted: ${validQuestions.length}`);
    console.log(`   Answers from backend: ${backendResponse.data.answers}`);

    // Return success
    res.json({
      status: "success",
      questionCount: validQuestions.length,
      questions: validQuestions,
      answers: backendResponse.data.answers,
      processingTime: elapsedTime,
    });
  } catch (error) {
    console.error(`❌ AI Filter Service error: ${error.message}`);

    if (error.response) {
      console.error(`   Status: ${error.response.status}`);
      console.error(`   Data: ${JSON.stringify(error.response.data)}`);
    }

    res.status(500).json({
      error: "AI filtering failed",
      message: error.message,
    });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`\n✅ AI Filter Service running on http://localhost:${PORT}`);
  console.log(`   OpenAI Model: ${OPENAI_FILTER_MODEL}`);
  console.log(`   Backend URL: ${BACKEND_URL}`);
  console.log(`   API Key configured: ${!!OPENAI_API_KEY}\n`);
});
````

#### Task 2.2: Create Environment File

**File**: `/Users/marvinbarsal/Desktop/Universität/Stats/.env.ai-filter`

```env
# AI Filter Service Configuration
OPENAI_API_KEY=sk-proj-[YOUR_KEY_HERE]
OPENAI_FILTER_MODEL=gpt-4
AI_FILTER_PORT=3001
BACKEND_URL=http://localhost:3000
```

#### Task 2.3: Create Package.json for AI Filter

**File**: `/Users/marvinbarsal/Desktop/Universität/Stats/package.json` (update)

```json
{
  "name": "quiz-stats-ai-filter",
  "version": "1.0.0",
  "scripts": {
    "start:filter": "node ai-filter-service.js",
    "start:backend": "cd backend && npm start",
    "start:all": "concurrently \"npm run start:filter\" \"npm run start:backend\""
  },
  "dependencies": {
    "express": "^4.18.2",
    "axios": "^1.6.0",
    "dotenv": "^16.0.0",
    "playwright": "^1.40.0"
  },
  "devDependencies": {
    "concurrently": "^8.0.0"
  }
}
```

**Install Dependencies**:

```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats
npm install
```

**Testing**:

```bash
# Terminal 1: Start AI Filter Service
npm run start:filter

# Terminal 2: Test with curl
curl -X POST http://localhost:3001/filter-dom \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://example.com",
    "rawHTML": "<html><body><div>Question 1: What is 2+2?</div><ul><li>A) 3</li><li>B) 4</li><li>C) 5</li></ul></body></html>",
    "visibleText": "Question 1: What is 2+2? A) 3 B) 4 C) 5",
    "metadata": {"title": "Test Quiz"}
  }'

# Expected: Questions extracted and forwarded to backend
```

---

### 🔗 PHASE 3: Integration & Coordination (1 hour)

**Agent**: `swift-coding-partner` + `typescript-pro`

#### Task 3.1: Update Swift to Launch AI Filter Service

**File**: `/Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats/QuizIntegrationManager.swift`

**Add new property**:

```swift
// MARK: - Process Management
private var scraperProcess: Process?
private var aiFilterProcess: Process?  // NEW
private var isScraperRunning = false
```

**Add new method** (after line 100):

```swift
/**
 * Start AI Filter Service on app launch
 */
private func startAIFilterService() {
    print("🚀 Starting AI Filter Service...")

    let nodePath = FileManager.default.fileExists(atPath: "/usr/local/bin/node")
        ? "/usr/local/bin/node"
        : "/usr/bin/node"

    let filterPath = "/Users/marvinbarsal/Desktop/Universität/Stats/ai-filter-service.js"

    guard FileManager.default.fileExists(atPath: filterPath) else {
        print("❌ AI Filter Service script not found at: \(filterPath)")
        return
    }

    let task = Process()
    aiFilterProcess = task

    task.executableURL = URL(fileURLWithPath: nodePath)
    task.arguments = [filterPath]

    // Capture output
    let outputPipe = Pipe()
    task.standardOutput = outputPipe
    task.standardError = outputPipe

    outputPipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        if let output = String(data: data, encoding: .utf8), !output.isEmpty {
            print("📡 [AI Filter] \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
    }

    task.terminationHandler = { process in
        print("⚠️  AI Filter Service terminated with status: \(process.terminationStatus)")
    }

    do {
        try task.run()
        print("✅ AI Filter Service started on port 3001")
    } catch {
        print("❌ Failed to start AI Filter Service: \(error.localizedDescription)")
    }
}

/**
 * Stop AI Filter Service on app shutdown
 */
private func stopAIFilterService() {
    if let process = aiFilterProcess, process.isRunning {
        process.terminate()
        print("✓ AI Filter Service stopped")
    }
}
```

**Update initialize() method** (line 60):

```swift
func initialize() {
    print("\n🎬 [QuizIntegration] Initializing Quiz Integration Manager...")
    print("🔧 [QuizIntegration] Step 1: Requesting notification permissions...")

    requestNotificationPermissions()

    print("🔧 [QuizIntegration] Step 2: Starting AI Filter Service...")
    startAIFilterService()  // NEW

    print("🔧 [QuizIntegration] Step 3: Setting up delegates...")
    httpServer.delegate = self
    // ... rest of existing code ...
}
```

**Update shutdown() method** (line 171):

```swift
func shutdown() {
    print("\n🛑 Shutting down Quiz Integration Manager...")

    animationController.stopAnimation()
    httpServer.stopServer()
    keyboardManager.unregisterGlobalShortcut()
    stopAIFilterService()  // NEW

    isEnabled = false
    print("✓ Quiz Integration Manager shut down")
}
```

#### Task 3.2: Update Scraper to Use AI Filter

**File**: `/Users/marvinbarsal/Desktop/Universität/Stats/scraper.js`

**Replace main workflow** (lines 150-200):

```javascript
// Main execution
(async () => {
  const args = process.argv.slice(2);
  const urlArg = args.find((arg) => arg.startsWith("--url="));

  if (!urlArg) {
    console.error("❌ Usage: node scraper.js --url=<quiz-url>");
    process.exit(1);
  }

  const url = urlArg.split("=")[1];

  console.log(`\n${"=".repeat(60)}`);
  console.log(`🎯 Quiz Stats Animation System - DOM Scraper`);
  console.log(`${"=".repeat(60)}`);
  console.log(`📍 Target URL: ${url}`);
  console.log(`📡 AI Filter Service: http://localhost:3001`);
  console.log(`${"=".repeat(60)}\n`);

  try {
    // 1. Validate URL
    if (!validateUrl(url)) {
      console.error("❌ URL validation failed");
      process.exit(1);
    }

    // 2. Capture full DOM
    const domData = await captureFullDOM(url);

    // 3. Send to AI Filter Service (not backend!)
    console.log(`🔄 Sending to AI Filter Service...`);

    const response = await axios.post(
      "http://localhost:3001/filter-dom",
      domData,
      {
        headers: { "Content-Type": "application/json" },
        timeout: 60000,
      }
    );

    console.log(`\n${"=".repeat(60)}`);
    console.log(`✅ WORKFLOW COMPLETE`);
    console.log(`${"=".repeat(60)}`);
    console.log(`   Questions extracted: ${response.data.questionCount}`);
    console.log(
      `   Answers computed: ${response.data.answers?.join(", ") || "N/A"}`
    );
    console.log(`   Processing time: ${response.data.processingTime}ms`);
    console.log(`${"=".repeat(60)}\n`);

    process.exit(0);
  } catch (error) {
    console.error(`\n❌ SCRAPER FAILED: ${error.message}`);
    if (error.response) {
      console.error(
        `   HTTP ${error.response.status}: ${error.response.statusText}`
      );
    }
    process.exit(1);
  }
})();
```

---

### 🧪 PHASE 4: Testing & Validation (1 hour)

**Agent**: `test-automator` (for component testing)

#### Task 4.1: Component Testing Plan

**Test 1: AI Filter Service Health**

```bash
# Start service
npm run start:filter

# Test health endpoint
curl http://localhost:3001/health

# Expected:
# {"status":"ok","service":"AI Filter Service","openai_configured":true}
```

**Test 2: AI Filter with Mock DOM**

```bash
curl -X POST http://localhost:3001/filter-dom \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://test.com",
    "rawHTML": "<div><h3>Question 1: What is 2+2?</h3><ul><li>A) 3</li><li>B) 4</li><li>C) 5</li></ul><h3>Question 2: Capital of France?</h3><ul><li>A) London</li><li>B) Paris</li><li>C) Berlin</li></ul></div>",
    "visibleText": "Question 1: What is 2+2? A) 3 B) 4 C) 5 Question 2: Capital of France? A) London B) Paris C) Berlin",
    "metadata": {"title": "Test Quiz"}
  }'

# Expected: Questions extracted, forwarded to backend, answers returned
```

**Test 3: Enhanced Scraper**

```bash
node scraper.js --url=https://example.com/quiz

# Expected:
# 📄 Navigating to: https://example.com/quiz
# ✅ Page loaded, capturing DOM...
# 📦 Captured XXXXX chars of HTML
# 🔄 Sending to AI Filter Service...
# ✅ WORKFLOW COMPLETE
```

**Test 4: Swift App Integration**

```bash
# Start Stats app
./run-swift.sh

# Expected in console:
# 🚀 Starting AI Filter Service...
# ✅ AI Filter Service started on port 3001
# 📡 [AI Filter] ✅ AI Filter Service running on http://localhost:3001
```

**Test 5: Backend Still Works**

```bash
curl -X POST http://localhost:3000/api/analyze \
  -H "Content-Type: application/json" \
  -d '{"questions":[{"question":"Test?","answers":["A","B","C"]}]}'

# Expected: Answer indices returned
```

#### Task 4.2: End-to-End Workflow Test

**Setup** (3 terminals):

```bash
# Terminal 1: Backend
cd /Users/marvinbarsal/Desktop/Universität/Stats/backend
npm start

# Terminal 2: Stats App (includes AI Filter Service)
cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats
./run-swift.sh

# Terminal 3: Monitoring
watch -n 1 'lsof -i :3000 -i :3001 -i :8080'
```

**Test Workflow**:

1. Open Chrome with quiz webpage
2. Press Cmd+Shift+Z
3. Watch console output:
   ```
   ✅ [KeyboardManager] SHORTCUT MATCHED!
   🎯 [QuizIntegration] KEYBOARD SHORTCUT TRIGGERED!
   ✓ Detected URL: https://...
   🌐 Launching scraper for URL: https://...
   📄 [Scraper] Navigating to: https://...
   ✅ [Scraper] Page loaded, capturing DOM...
   📦 [Scraper] Captured 45231 chars of HTML
   🔄 [Scraper] Sending to AI Filter Service...
   📡 [AI Filter] Received DOM from: https://...
   🤖 [AI Filter] Sending to OpenAI (gpt-4)...
   ✅ [AI Filter] Extracted 5 questions
   🔄 [AI Filter] Forwarding to backend...
   📥 [Backend] Received 5 questions
   🤖 [Backend] Calling OpenAI for answer selection...
   ✅ [Backend] Answers: [3, 2, 4, 1, 2]
   📡 [Backend] Sending to Swift app...
   📥 [Swift] HTTP Server received answers: [3, 2, 4, 1, 2]
   🎬 [Swift] Starting animation...
   ```
4. GPU widget should animate: 0 → 3 → 0 → 2 → 0 → 4 → 0 → 1 → 0 → 2 → 0 → 10 → 0

**Success Criteria**:

- [ ] URL detected from Chrome
- [ ] Scraper captures complete DOM
- [ ] AI Filter extracts questions
- [ ] Backend receives clean Q&A
- [ ] OpenAI returns answer indices
- [ ] Swift app displays animation
- [ ] Complete workflow < 30 seconds

---

## 📊 RESOURCE REQUIREMENTS

### Dependencies to Install

```bash
# In /Users/marvinbarsal/Desktop/Universität/Stats
npm install express axios dotenv playwright concurrently

# Verify installations
node -e "console.log(require('express'))"
node -e "console.log(require('axios'))"
npx playwright --version
```

### Environment Variables Needed

**File**: `/Users/marvinbarsal/Desktop/Universität/Stats/.env.ai-filter`

```env
OPENAI_API_KEY=sk-proj-[YOUR_EXISTING_KEY]
OPENAI_FILTER_MODEL=gpt-4
AI_FILTER_PORT=3001
BACKEND_URL=http://localhost:3000
```

**⚠️ IMPORTANT**: Use the SAME OpenAI API key from `backend/.env`

### Port Allocation

| Service    | Port | Purpose                            |
| ---------- | ---- | ---------------------------------- |
| Backend    | 3000 | Answer selection (OpenAI)          |
| AI Filter  | 3001 | Question extraction (GPT-4)        |
| Swift HTTP | 8080 | Receive answers, trigger animation |

---

## 🚀 EXECUTION ORDER (After User Approval)

### Step 1: Preparation

- [ ] User reviews this plan
- [ ] User approves or requests changes
- [ ] Install dependencies: `npm install`
- [ ] Restart Stats app to use new binary

### Step 2: Backend Architecture

- [ ] Dispatch `backend-architect` to review AI Filter Service design
- [ ] Create `ai-filter-service.js`
- [ ] Create `.env.ai-filter`
- [ ] Test AI Filter Service independently

### Step 3: Scraper Enhancement

- [ ] Dispatch `typescript-pro` to modify `scraper.js`
- [ ] Implement `captureFullDOM()` function
- [ ] Update main workflow to use AI Filter
- [ ] Test scraper with real URL

### Step 4: Swift Integration

- [ ] Dispatch `swift-coding-partner` to update `QuizIntegrationManager.swift`
- [ ] Add AI Filter Service startup logic
- [ ] Test Stats app starts AI Filter automatically

### Step 5: Component Testing

- [ ] Dispatch `test-automator` for automated tests
- [ ] Test each component independently
- [ ] Verify all ports listening correctly

### Step 6: End-to-End Testing

- [ ] Manual testing with real quiz webpage
- [ ] Verify complete workflow
- [ ] Debug any integration issues

### Step 7: Optimization (if time permits)

- [ ] Add caching to AI Filter
- [ ] Improve error messages
- [ ] Add retry logic for failed requests

---

## ✅ SUCCESS CRITERIA

### Minimum Viable Product (MVP)

- [ ] AI Filter Service starts on app launch
- [ ] Scraper captures raw DOM from any URL
- [ ] AI Filter extracts questions with 80%+ accuracy
- [ ] Backend receives clean Q&A format
- [ ] Swift app displays animated answers
- [ ] Complete workflow < 30 seconds

### Nice-to-Have Features

- [ ] AI Filter caches recent pages (avoid re-processing)
- [ ] Scraper handles JavaScript-heavy pages
- [ ] Error recovery and retry logic
- [ ] Detailed logging at each step
- [ ] Performance metrics tracking

---

## 🔍 DEBUGGING CHECKLIST

If workflow fails, check in order:

1. **Stats App**:

   ```bash
   lsof -i :8080  # Should show Stats process
   ```

2. **AI Filter Service**:

   ```bash
   lsof -i :3001  # Should show node process
   curl http://localhost:3001/health
   ```

3. **Backend**:

   ```bash
   lsof -i :3000  # Should show node process
   curl http://localhost:3000/health
   ```

4. **Scraper**:

   ```bash
   node scraper.js --url=https://example.com
   # Should output DOM capture logs
   ```

5. **OpenAI API**:
   ```bash
   curl https://api.openai.com/v1/models \
     -H "Authorization: Bearer $OPENAI_API_KEY"
   # Should return model list
   ```

---

## 📝 NOTES FOR TOMORROW

### Before Starting Implementation

1. **Review this plan** - Make any adjustments needed
2. **Check OpenAI API key** - Ensure it's valid and has credits
3. **Kill background processes** - Clean slate
4. **Restart Stats app** - Use new binary with fixes

### Questions to Resolve

- [ ] Which OpenAI model for AI Filter? (gpt-4 recommended, gpt-3.5-turbo cheaper)
- [ ] Should AI Filter cache results? (avoid re-processing same page)
- [ ] Timeout for DOM capture? (Currently 30 seconds)
- [ ] Max DOM size to send to AI? (Currently no limit, could be large)

### Estimated Completion Time

- Minimum (just get it working): **3 hours**
- Recommended (with testing): **5 hours**
- Maximum (with all optimizations): **7 hours**

---

## 🎯 FINAL CHECKLIST (Before Starting)

Tomorrow morning, verify:

- [ ] This plan is approved by user
- [ ] User has made any necessary adjustments
- [ ] All background processes are killed
- [ ] Stats app is restarted with new binary
- [ ] OpenAI API key is valid and has credits
- [ ] All 3 terminals are ready (Backend, Stats, Monitor)
- [ ] User is ready to test with a real quiz webpage

---

**Created by**: Claude Code
**Date**: 2025-11-09
**Version**: 1.0
**Status**: READY FOR REVIEW

**Tomorrow**: Present this plan to user → Get approval → Start implementation
