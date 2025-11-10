# DOM Scraping Implementation - Detailed Execution Plan

**Created**: 2025-11-09
**Status**: Ready for Implementation
**Estimated Duration**: 4-5 hours
**Based On**: DOM_SCRAPING_IMPLEMENTATION_PLAN.md
**Project Path**: `/Users/marvinbarsal/Desktop/Universität/Stats/`

---

## Executive Summary

This document provides a **step-by-step execution plan** for implementing the AI-powered DOM scraping system. It specifies:
- Which agents should handle each phase
- Exact files to modify
- Testing procedures for each component
- Integration validation steps
- Success criteria

**Key Architecture**: Raw DOM → AI Parser (Ollama/OpenAI) → Clean Q&A → Backend → Swift Animation

---

## Phase 0: Environment Validation (10 minutes)

### Task 0.1: Verify Ollama Configuration

**Agent**: None (manual verification)

**Steps**:
```bash
# Check Ollama is running
curl http://localhost:11434/api/tags

# Expected response:
# {"models":[{"name":"codellama:13b-instruct","size":...}]}

# If not running, start Ollama first:
ollama serve
```

**Files Checked**:
- `/Users/marvinbarsal/Desktop/Universität/Stats/.env.ai-parser` ✓ VERIFIED

**Current Status**:
```
PORT=3001
OLLAMA_URL=http://localhost:11434
OPENAI_API_KEY= (empty - disabled)
USE_OPENAI_FALLBACK=false
```

**Success Criteria**:
- Ollama endpoint responds with 200 OK
- CodeLlama model available
- `.env.ai-parser` correctly configured

---

### Task 0.2: Kill Background Processes

**Agent**: None (manual cleanup)

**Procedures**:
```bash
# Kill any existing Node.js services
pkill -f "node scraper"
pkill -f "node ai-parser"
pkill -f "node server"
pkill -f "xcodebuild"

# Verify clean state
ps aux | grep node | grep -v grep
ps aux | grep xcode | grep -v grep

# Both should return nothing (no running processes)
```

**Files Checked**:
- System process table

**Success Criteria**:
- No Node.js processes running on ports 3000, 3001, 8080
- `lsof -i :3000` returns empty
- `lsof -i :3001` returns empty
- `lsof -i :8080` returns empty

---

### Task 0.3: Restart Stats App Binary

**Agent**: None (manual step)

**Procedures**:
```bash
# Kill current running Stats app
pkill Stats

# Rebuild and run fresh binary
cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats
./build-swift.sh  # or: xcodebuild build

# Wait for build to complete (2-3 minutes)
# Verify build succeeded: "Build succeeded!"
```

**Verification**:
- Open Chrome with any webpage
- Press **Cmd+Shift+Z** (or configured shortcut)
- Check console output:
  - Should show URL detected (no -1719 errors)
  - Should NOT show keyboard logs for every keystroke
  - Only triggers on Cmd+Shift+Z press

**Success Criteria**:
- Build completes without errors
- Keyboard handler works (single trigger, not spam)
- AppleScript successfully gets Chrome URL

---

## Phase 1: Enhanced Scraper with Full DOM Capture (1.5 hours)

### Task 1.1: Analyze Current Scraper

**Agent**: `typescript-pro` (Node.js specialist)

**Responsibilities**:
- Review existing `scraper.js` (currently ~300 lines)
- Identify current DOM extraction strategies
- Verify it's read-only (✓ already verified)
- Plan modifications for full DOM capture

**File Location**: `/Users/marvinbarsal/Desktop/Universität/Stats/scraper.js`

**Current Code Analysis**:
```javascript
// Currently extracts:
- visibleText via extractStructuredText()
- DOM hierarchy preserved
- Headings (h3, h4, .qtext, .question-text)
- Question blocks with following content

// Already uses:
- Playwright (chromium headless)
- networkidle wait
- Moodle-specific selectors
- Structured text output

// Needs:
- Raw HTML capture
- Metadata (title, URL, viewport)
- Explicit full page wait
- Increased timeout (currently 30s - OK)
```

**Deliverable**:
- Code review document
- Implementation plan for modifications

---

### Task 1.2: Modify scraper.js for Full DOM Capture

**Agent**: `typescript-pro` (Node.js specialist)

**Files to Modify**:
- `/Users/marvinbarsal/Desktop/Universität/Stats/scraper.js`

**Exact Changes Required**:

**Section 1: Add New Function** (after line 67, before `extractText()`)
```javascript
/**
 * Capture full DOM data for AI parsing
 * @param {Page} page - Playwright page
 * @returns {Promise<Object>} DOM data object
 */
async function captureFullDOMData(page) {
  return {
    url: page.url(),
    title: await page.title(),
    rawHTML: await page.content(), // Full page HTML
    visibleText: await extractStructuredText(page), // Existing function
    metadata: {
      timestamp: new Date().toISOString(),
      userAgent: await page.evaluate(() => navigator.userAgent),
      viewportSize: page.viewportSize(),
    }
  };
}
```

**Section 2: Update Main Function** (around line 200)

**OLD CODE**:
```javascript
// Currently just extracts text and returns
const text = await extractText(url);
console.log('✓ Text extraction complete');
return text;
```

**NEW CODE**:
```javascript
// Capture raw DOM data
browser = await playwright.chromium.launch({ headless: true });
const page = await browser.newPage();
await page.goto(url, {
  waitUntil: 'networkidle',
  timeout: 30000
});

console.log('📄 Capturing full DOM...');
const domData = await captureFullDOMData(page);
await browser.close();

console.log(`✅ DOM captured: ${domData.rawHTML.length} chars`);
console.log(`📝 Visible text: ${domData.visibleText.length} chars`);

return domData;
```

**Testing the Changes**:
```bash
# After modifying scraper.js
node /Users/marvinbarsal/Desktop/Universität/Stats/scraper.js \
  --url=https://example.com

# Expected output:
# 📍 Target URL: https://example.com
# 🌐 Loading page...
# ✓ Page loaded
# 📄 Capturing full DOM...
# ✅ DOM captured: XXXXX chars
# 📝 Visible text: XXXXX chars
```

**Files Modified**: 1
- `/Users/marvinbarsal/Desktop/Universität/Stats/scraper.js` (+30 lines)

**Success Criteria**:
- Script runs without errors
- Returns object with: `url`, `title`, `rawHTML`, `visibleText`, `metadata`
- No network requests made (read-only ✓)
- Processes complete within 30 seconds

---

### Task 1.3: Update package.json

**Agent**: `typescript-pro` (Node.js specialist)

**File to Modify**: `/Users/marvinbarsal/Desktop/Universität/Stats/package.json`

**Current Status**: Need to verify if exists

**Required Changes**:
If package.json already has scripts, ensure these exist:
```json
{
  "scripts": {
    "test:scraper": "node scraper.js --url=https://example.com",
    "start:filter": "node ai-parser-service.js",
    "start:backend": "cd backend && npm start"
  }
}
```

**Testing**:
```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats
npm run test:scraper
```

**Files Modified**: 1
- `/Users/marvinbarsal/Desktop/Universität/Stats/package.json`

**Success Criteria**:
- npm scripts defined
- `npm run test:scraper` runs scraper successfully

---

## Phase 2: AI Parser Service - ALREADY EXISTS (20 minutes)

### Task 2.1: Verify Existing AI Parser Service

**Agent**: `backend-architect` (Server specialist)

**Files to Review**:
- `/Users/marvinbarsal/Desktop/Universität/Stats/ai-parser-service.js`
- `/Users/marvinbarsal/Desktop/Universität/Stats/.env.ai-parser`

**Current Status**: Service exists and configured for Ollama

**Verification Steps**:

**Step 1: Check Service Health**
```bash
# Terminal 1: Start AI Parser Service
cd /Users/marvinbarsal/Desktop/Universität/Stats
node ai-parser-service.js

# Expected output:
# ✅ AI Parser Service running on http://localhost:3001
# 📍 Using Ollama at http://localhost:11434
```

**Step 2: Test Health Endpoint** (Terminal 2)
```bash
curl http://localhost:3001/health

# Expected:
# {"status":"ok","service":"AI Parser Service","ollama_configured":true}
```

**Step 3: Test with Mock DOM** (Terminal 2)
```bash
curl -X POST http://localhost:3001/filter-dom \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://test.com",
    "rawHTML": "<div><h3>Question 1: What is 2+2?</h3><ul><li>A) 3</li><li>B) 4</li><li>C) 5</li></ul></div>",
    "visibleText": "Question 1: What is 2+2? A) 3 B) 4 C) 5",
    "metadata": {"title": "Test Quiz"}
  }'

# Expected:
# {"status":"success","questionCount":1,"questions":[...]}
```

**Issues to Check**:
- Is Ollama running? (`curl http://localhost:11434/api/tags`)
- Does CodeLlama model exist?
- Is port 3001 available?
- Is `.env.ai-parser` properly configured?

**Files Reviewed**: 2
- `ai-parser-service.js` (VERIFIED - uses Ollama)
- `.env.ai-parser` (VERIFIED - correct config)

**Success Criteria**:
- Service starts without errors
- Health endpoint returns 200 OK
- Mock DOM test returns valid JSON
- No OpenAI fallback attempted

---

### Task 2.2: Test AI Parser with Real DOM

**Agent**: `backend-architect` (Server specialist)

**Procedures**:

**Step 1: Keep AI Parser running from 2.1**
```
Terminal 1: node ai-parser-service.js (still running)
```

**Step 2: Get real DOM from scraper**
```bash
# Terminal 2
node /Users/marvinbarsal/Desktop/Universität/Stats/scraper.js \
  --url=https://www.example.com

# Capture the raw HTML output (first ~500 chars)
```

**Step 3: Send to AI Parser**
```bash
# Use the domData output from scraper
# Send to AI Parser and verify extraction

curl -X POST http://localhost:3001/filter-dom \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://www.example.com",
    "rawHTML": "[PASTE ACTUAL HTML FROM SCRAPER]",
    "visibleText": "[PASTE ACTUAL TEXT FROM SCRAPER]",
    "metadata": {"title": "Example Domain"}
  }'
```

**Debugging if Fails**:
1. Check Ollama logs: `ollama logs`
2. Verify CodeLlama is loaded: `ollama list`
3. Test Ollama directly: `ollama run codellama:13b-instruct "What is 2+2?"`

**Success Criteria**:
- AI Parser processes real DOM without errors
- Returns valid JSON with extracted questions
- Ollama processes request in < 30 seconds

---

## Phase 3: Integration with Backend (1 hour)

### Task 3.1: Update Backend to Use AI Parser

**Agent**: `backend-architect` (Server specialist)

**Files to Modify**:
- `/Users/marvinbarsal/Desktop/Universität/Stats/backend/server.js`

**Current Status**: Backend needs to be updated to receive from AI Parser, not from scraper directly

**Changes Required**:

**Current Flow** (BROKEN):
```
Scraper → Backend (/api/analyze) → OpenAI
```

**New Flow** (CORRECT):
```
Scraper → AI Parser (/filter-dom) → Backend (/api/analyze) → OpenAI → Swift
```

**Specific Code Changes**:

**In backend/server.js**:

Add new endpoint to receive from AI Parser:
```javascript
/**
 * Endpoint called by AI Parser after extracting questions
 * AI Parser already has clean Q&A format
 */
app.post('/api/analyze-from-filter', async (req, res) => {
  try {
    const { questions, answers } = req.body;

    if (!questions || questions.length === 0) {
      return res.json({
        status: 'success',
        message: 'No questions to analyze',
        answers: []
      });
    }

    // Questions are already clean from AI Parser
    // Just need to return answers (or further process if needed)

    res.json({
      status: 'success',
      questionCount: questions.length,
      questions: questions,
      answers: answers || []
    });
  } catch (error) {
    console.error(`❌ Error in analyze-from-filter: ${error.message}`);
    res.status(500).json({
      error: 'Analysis failed',
      message: error.message
    });
  }
});
```

**Update existing /api/analyze endpoint**:
```javascript
// Keep for backward compatibility with direct scraper calls
app.post('/api/analyze', async (req, res) => {
  try {
    const { questions } = req.body;

    // Route through AI Parser if available
    const aiParserUrl = process.env.AI_PARSER_URL || 'http://localhost:3001';

    const domData = {
      url: 'direct-api-call',
      rawHTML: JSON.stringify(questions),
      visibleText: questions.map(q => q.question).join('\n'),
      metadata: { source: 'api' }
    };

    try {
      const aiResponse = await axios.post(
        `${aiParserUrl}/filter-dom`,
        domData,
        { timeout: 60000 }
      );

      res.json(aiResponse.data);
    } catch (aiError) {
      // Fallback: call OpenAI directly
      res.json({
        status: 'error',
        message: 'AI Parser unavailable, using fallback',
        questions: questions
      });
    }
  } catch (error) {
    res.status(500).json({
      error: 'Analysis failed',
      message: error.message
    });
  }
});
```

**Update environment file**:
```bash
# In backend/.env, add:
AI_PARSER_URL=http://localhost:3001
OLLAMA_ENABLED=true
```

**Testing the Changes**:
```bash
# Terminal 1: Start AI Parser
node /Users/marvinbarsal/Desktop/Universität/Stats/ai-parser-service.js

# Terminal 2: Start Backend
cd /Users/marvinbarsal/Desktop/Universität/Stats/backend
npm start

# Terminal 3: Test the endpoint
curl -X POST http://localhost:3000/api/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "questions": [
      {"question": "What is 2+2?", "answers": ["1","2","3","4"]}
    ]
  }'

# Expected: Questions flow through AI Parser and return clean JSON
```

**Files Modified**: 1
- `/Users/marvinbarsal/Desktop/Universität/Stats/backend/server.js`

**Success Criteria**:
- Backend starts without errors
- Health endpoint works: `curl http://localhost:3000/health`
- New endpoint processes questions through AI Parser
- Fallback to direct processing if AI Parser unavailable

---

### Task 3.2: Update Scraper to Send to AI Parser

**Agent**: `typescript-pro` (Node.js specialist)

**Files to Modify**:
- `/Users/marvinbarsal/Desktop/Universität/Stats/scraper.js`

**Changes Required**:

Add new function (after main DOM capture):
```javascript
/**
 * Send DOM data to AI Parser Service
 * @param {Object} domData - Captured DOM data
 * @returns {Promise<Object>} Parsed questions and answers
 */
async function sendToAIParser(domData) {
  const aiParserUrl = process.env.AI_PARSER_URL || 'http://localhost:3001';

  try {
    console.log(`🔄 Sending to AI Parser Service (${aiParserUrl})...`);

    const response = await axios.post(
      `${aiParserUrl}/filter-dom`,
      domData,
      {
        headers: { 'Content-Type': 'application/json' },
        timeout: 60000 // 60 seconds for AI processing
      }
    );

    console.log(`✅ AI Parser extracted ${response.data.questionCount} questions`);
    return response.data;
  } catch (error) {
    console.error(`❌ AI Parser error: ${error.message}`);
    throw error;
  }
}
```

Update main execution (around line 180-200):
```javascript
// OLD: Post to backend directly
// POST to backend/api/analyze

// NEW: Post to AI Parser
(async () => {
  const args = process.argv.slice(2);
  const urlArg = args.find((arg) => arg.startsWith('--url='));

  if (!urlArg) {
    console.error("❌ Usage: node scraper.js --url=<quiz-url>");
    process.exit(1);
  }

  const url = urlArg.split("=")[1];

  console.log(`\n${"=".repeat(60)}`);
  console.log(`🎯 Quiz Stats Animation System - DOM Scraper`);
  console.log(`${"=".repeat(60)}`);
  console.log(`📍 Target URL: ${url}`);
  console.log(`${"=".repeat(60)}\n`);

  try {
    // 1. Capture full DOM
    const domData = await extractText(url);

    // 2. Send to AI Parser (new)
    const aiResult = await sendToAIParser(domData);

    console.log(`\n${"=".repeat(60)}`);
    console.log(`✅ WORKFLOW COMPLETE`);
    console.log(`${"=".repeat(60)}`);
    console.log(`   Questions extracted: ${aiResult.questionCount}`);
    console.log(`${"=".repeat(60)}\n`);

    process.exit(0);
  } catch (error) {
    console.error(`\n❌ SCRAPER FAILED: ${error.message}`);
    process.exit(1);
  }
})();
```

**Testing**:
```bash
# Terminal 1: AI Parser
node ai-parser-service.js

# Terminal 2: Test scraper with new flow
node scraper.js --url=https://example.com

# Expected output:
# 📍 Target URL: https://example.com
# 🌐 Loading page...
# 📄 Capturing full DOM...
# 🔄 Sending to AI Parser Service...
# ✅ WORKFLOW COMPLETE
# Questions extracted: N
```

**Files Modified**: 1
- `/Users/marvinbarsal/Desktop/Universität/Stats/scraper.js`

**Success Criteria**:
- Scraper captures DOM successfully
- Sends to AI Parser without errors
- Receives parsed questions back
- Total execution < 30 seconds

---

## Phase 4: Swift Integration (1 hour)

### Task 4.1: Review Current Swift Integration

**Agent**: `swift-coding-partner` (Swift specialist)

**Files to Review**:
- `/Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats/Stats/Modules/QuizIntegrationManager.swift`
- `/Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats/Stats/Modules/QuizAnimationController.swift`

**Current Status from CLAUDE.md**:
- QuizIntegrationManager exists and coordinates components
- HTTP Server listens on port 8080
- Keyboard shortcut handler works (Cmd+Option+Q)
- Animation controller manages timing

**Verification Checklist**:
```
✅ QuizIntegrationManager.swift exists and initializes
✅ KeyboardShortcutManager.swift listens for Cmd+Option+Q
✅ QuizHTTPServer.swift listens on port 8080
✅ QuizAnimationController.swift handles animation sequence
```

**Issue**: Need to verify QuizIntegrationManager launches scraper with AI Parser URL set

**Files Reviewed**: 4 Swift files

**Success Criteria**:
- All Swift files compile without errors
- Integration manager properly coordinates components
- Keyboard shortcut and HTTP server tested

---

### Task 4.2: Update QuizIntegrationManager to Set Environment Variables

**Agent**: `swift-coding-partner` (Swift specialist)

**File to Modify**:
- `/Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats/Stats/Modules/QuizIntegrationManager.swift`

**Changes Required**:

When launching scraper process, set environment variables:

```swift
// In the function that launches scraper:
func launchScraper(with url: String) {
    let process = Process()

    // Set environment variables for Node.js scraper
    var env = ProcessInfo.processInfo.environment
    env["AI_PARSER_URL"] = "http://localhost:3001"
    env["BACKEND_URL"] = "http://localhost:3000"
    process.environment = env

    // Rest of scraper launch code...
    process.executableURL = URL(fileURLWithPath: "/usr/local/bin/node")
    process.arguments = [
      "/Users/marvinbarsal/Desktop/Universität/Stats/scraper.js",
      "--url=\(url)"
    ]
    // ...
}
```

**Testing**:
1. Build Swift app: `Cmd+B` in Xcode
2. Run app: `Cmd+R` in Xcode
3. Open Chrome with quiz webpage
4. Press Cmd+Option+Q
5. Monitor console output to verify environment variables are used

**Files Modified**: 1
- `QuizIntegrationManager.swift`

**Success Criteria**:
- Swift compiles without errors
- Scraper launches with correct environment variables
- AI Parser URL is accessible to scraper process

---

## Phase 5: Component Testing (1 hour)

### Test Suite 1: AI Parser Service Testing

**Agent**: `test-automator` (Testing specialist)

**Tests to Run**:

**Test 1.1: Service Health**
```bash
# Command
curl http://localhost:3001/health

# Expected Response
{
  "status": "ok",
  "service": "AI Parser Service",
  "ollama_configured": true
}

# Success Criteria
- HTTP 200 response
- ollama_configured is true
```

**Test 1.2: Simple Question Extraction**
```bash
# Command
curl -X POST http://localhost:3001/filter-dom \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://test.com",
    "rawHTML": "<div><h3>Question 1: What is 2+2?</h3><ul><li>3</li><li>4</li><li>5</li></ul></div>",
    "visibleText": "Question 1: What is 2+2? 3 4 5",
    "metadata": {"title": "Test"}
  }'

# Expected Response
{
  "status": "success",
  "questionCount": 1,
  "questions": [
    {
      "question": "What is 2+2?",
      "answers": ["3", "4", "5"]
    }
  ]
}

# Success Criteria
- HTTP 200 response
- questionCount >= 1
- Valid question/answers array
```

**Test 1.3: Multiple Questions**
```bash
# Command
curl -X POST http://localhost:3001/filter-dom \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://test.com",
    "rawHTML": "<div><h3>Q1: 2+2?</h3><ul><li>3</li><li>4</li></ul><h3>Q2: Capital?</h3><ul><li>Paris</li><li>London</li></ul></div>",
    "visibleText": "Q1: 2+2? 3 4 Q2: Capital? Paris London",
    "metadata": {"title": "Test"}
  }'

# Expected Response
{
  "status": "success",
  "questionCount": 2,
  "questions": [...]
}

# Success Criteria
- Both questions extracted
- questionCount == 2
```

**Test 1.4: Invalid/No Questions**
```bash
# Command
curl -X POST http://localhost:3001/filter-dom \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://test.com",
    "rawHTML": "<div>Just some regular text, no questions here</div>",
    "visibleText": "Just some regular text",
    "metadata": {"title": "No Quiz"}
  }'

# Expected Response
{
  "status": "success",
  "questionCount": 0,
  "message": "No quiz questions detected"
}

# Success Criteria
- HTTP 200 response
- graceful handling of no questions
```

**Test Results Log**:
```
Test 1.1 Health Check:       [ PASS/FAIL ]
Test 1.2 Simple Question:    [ PASS/FAIL ]
Test 1.3 Multiple Questions: [ PASS/FAIL ]
Test 1.4 Invalid Input:      [ PASS/FAIL ]
```

---

### Test Suite 2: Scraper Component Testing

**Agent**: `test-automator` (Testing specialist)

**Tests to Run**:

**Test 2.1: Scraper Execution**
```bash
# Command
node /Users/marvinbarsal/Desktop/Universität/Stats/scraper.js \
  --url=https://www.example.com

# Expected Output
# 📍 Target URL: https://www.example.com
# 🌐 Loading page...
# ✓ Page loaded
# 📄 Capturing full DOM...
# 🔄 Sending to AI Parser Service...
# ✅ WORKFLOW COMPLETE

# Success Criteria
- No errors
- All stages completed
- Output contains DOM capture info
```

**Test 2.2: Scraper Error Handling**
```bash
# Command (invalid URL)
node /Users/marvinbarsal/Desktop/Universität/Stats/scraper.js \
  --url=https://this-domain-definitely-does-not-exist-12345.com

# Expected Behavior
- Graceful error message
- Exit code 1
- No hanging

# Success Criteria
- Error message is clear
- Process exits cleanly
```

**Test 2.3: Scraper with Real Quiz**
```bash
# Command (find a real quiz site)
node /Users/marvinbarsal/Desktop/Universität/Stats/scraper.js \
  --url=https://actual-quiz-site.com/quiz

# Expected Output
- Questions extracted
- AI Parser processes successfully
- Valid JSON response

# Success Criteria
- Real questions extracted
- questionCount > 0
```

**Test Results Log**:
```
Test 2.1 Scraper Execution:  [ PASS/FAIL ]
Test 2.2 Error Handling:     [ PASS/FAIL ]
Test 2.3 Real Quiz Extract:  [ PASS/FAIL ]
```

---

### Test Suite 3: Backend Integration Testing

**Agent**: `test-automator` (Testing specialist)

**Tests to Run**:

**Test 3.1: Backend Health**
```bash
# Command
curl http://localhost:3000/health

# Expected Response
{
  "status": "ok",
  "openai_configured": true
}

# Success Criteria
- HTTP 200
- status is "ok"
```

**Test 3.2: Backend Receives from AI Parser**
```bash
# Command
curl -X POST http://localhost:3000/api/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "questions": [
      {"question": "Q1?", "answers": ["A", "B", "C"]}
    ]
  }'

# Expected Response
{
  "status": "success",
  "questionCount": 1,
  "answers": [...]
}

# Success Criteria
- HTTP 200
- Questions processed
- Answers array returned
```

**Test 3.3: Backend Routes to Swift**
```bash
# Command (if implemented)
# Backend should POST answers to Swift app at localhost:8080

# Expected Behavior
- Swift HTTP server receives POST
- Animation starts

# Success Criteria
- Swift console shows "Received answers"
- Widget animates
```

**Test Results Log**:
```
Test 3.1 Backend Health:     [ PASS/FAIL ]
Test 3.2 Question Analysis:  [ PASS/FAIL ]
Test 3.3 Swift Routing:      [ PASS/FAIL ]
```

---

### Test Suite 4: Swift Component Testing

**Agent**: `test-automator` (Testing specialist)

**Tests to Run**:

**Test 4.1: HTTP Server Listening**
```bash
# Command (while Swift app running)
curl http://localhost:8080

# Expected Response
- HTTP response (200 or 405)
- Port 8080 accepting connections

# Success Criteria
- Server responds (not connection refused)
- No errors
```

**Test 4.2: Animation Trigger via HTTP**
```bash
# Command
curl -X POST http://localhost:8080/display-answers \
  -H "Content-Type: application/json" \
  -d '{"answers": [3, 2, 4]}'

# Expected Behavior
- Swift console shows animation start
- GPU widget animates
- Sequence: 0 → 3 → 0 → 2 → 0 → 4 → 0 → 10 → 0

# Success Criteria
- Animation starts
- Widget updates visible
- Sequence matches expected
```

**Test 4.3: Keyboard Shortcut**
```bash
# Steps
1. Start Swift app
2. Open Chrome with any webpage
3. Press Cmd+Option+Q

# Expected Behavior
- Scraper launches
- AI Parser processes
- Animation sequence plays
- Returns to 0

# Success Criteria
- Complete workflow < 30 seconds
- No errors in console
- Animation visible
```

**Test Results Log**:
```
Test 4.1 HTTP Server:        [ PASS/FAIL ]
Test 4.2 Animation Trigger:  [ PASS/FAIL ]
Test 4.3 Keyboard Shortcut:  [ PASS/FAIL ]
```

---

## Phase 6: End-to-End Integration Testing (1 hour)

### E2E Test Setup

**Agent**: `test-automator` (Testing specialist)

**Setup Requirements** (3 terminals):

**Terminal 1: Ollama**
```bash
# Ensure Ollama is running
ollama serve

# Verify:
curl http://localhost:11434/api/tags
# Should show codellama:13b-instruct model
```

**Terminal 2: AI Parser Service**
```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats
node ai-parser-service.js

# Verify:
curl http://localhost:3001/health
# Should return: {"status":"ok",...}
```

**Terminal 3: Backend**
```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/backend
npm start

# Verify:
curl http://localhost:3000/health
# Should return: {"status":"ok",...}
```

**Terminal 4: Monitoring**
```bash
# Watch for all three services running
watch -n 1 'lsof -i :3000 -i :3001 -i :8080 -i :11434'

# All four ports should show LISTEN status
```

---

### E2E Test 1: Manual Scraper Invocation

**Steps**:
```bash
# Terminal 5
node /Users/marvinbarsal/Desktop/Universität/Stats/scraper.js \
  --url=https://www.example.com

# Watch output for:
# 1. DOM capture completion
# 2. AI Parser processing
# 3. Clean questions extracted
# 4. Response returned to scraper
```

**Success Criteria**:
- [ ] Scraper completes without errors
- [ ] AI Parser processes DOM
- [ ] Questions extracted (even if 0)
- [ ] Total time < 30 seconds

---

### E2E Test 2: Full Keyboard Shortcut Workflow

**Steps**:
```
1. Start Swift app: open .../Stats.xcodeproj, Cmd+R
2. Open Chrome with a webpage
3. Press Cmd+Option+Q
4. Observe full workflow
```

**Expected Console Output**:
```
✅ [KeyboardManager] SHORTCUT MATCHED!
🎯 [QuizIntegration] KEYBOARD SHORTCUT TRIGGERED!
✓ Detected URL: https://...
🌐 Launching scraper for URL: https://...
📍 Target URL: https://...
🌐 Loading page...
✓ Page loaded
📄 Capturing full DOM...
✅ DOM captured
🔄 Sending to AI Parser Service...
🤖 [AI Parser] Received DOM from: https://...
🤖 [AI Parser] Processing with Ollama...
✅ [AI Parser] Extracted N questions
📡 [Backend] Received N questions
🤖 [Backend] Calling OpenAI for answer selection...
✅ [Backend] Answers: [3, 2, 1, ...]
📡 [Backend] Sending to Swift app...
📥 [Swift] HTTP Server received answers
🎬 [Swift] Starting animation...
```

**Widget Sequence**:
```
0 → 3 (1.5s) → 3 (10s) → 0 (1.5s) →
0 → 2 (1.5s) → 2 (10s) → 0 (1.5s) →
0 → 1 (1.5s) → 1 (10s) → 0 (1.5s) →
[rest for 15s] →
0 → 10 (1.5s) → 10 (15s) → 0
```

**Success Criteria**:
- [ ] URL detected from Chrome
- [ ] Scraper captures complete DOM
- [ ] AI Parser extracts questions
- [ ] Backend receives clean Q&A
- [ ] OpenAI returns answer indices
- [ ] Swift app displays animation
- [ ] Complete workflow < 30 seconds

---

### E2E Test 3: Error Scenarios

**Scenario A: Ollama Offline**
```bash
# Kill Ollama in Terminal 1
# Try keyboard shortcut in Swift app
# Expected: Graceful error message, no crash
```

**Scenario B: Invalid URL**
```bash
# Modify scraper to use: --url=https://invalid-site-xyz.com
# Expected: Timeout or connection error, handled gracefully
```

**Scenario C: Quiz with No Questions**
```bash
# Try with: --url=https://example.com (no quiz)
# Expected: {"questionCount": 0, "message": "No quiz found"}
```

**Success Criteria**:
- [ ] All error scenarios handled gracefully
- [ ] No crashes or hangs
- [ ] User receives clear error messages

---

## Phase 7: Integration Review (30 minutes)

### Code Review Task

**Agent**: `code-reviewer` (Code quality specialist)

**Files to Review**:
1. `/Users/marvinbarsal/Desktop/Universität/Stats/scraper.js`
2. `/Users/marvinbarsal/Desktop/Universität/Stats/ai-parser-service.js`
3. `/Users/marvinbarsal/Desktop/Universität/Stats/backend/server.js`
4. `/Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats/Stats/Modules/QuizIntegrationManager.swift`

**Review Checklist**:
- [ ] Error handling is comprehensive
- [ ] Timeouts are properly configured
- [ ] No hardcoded credentials or secrets
- [ ] Code is properly documented
- [ ] Logging includes relevant debug info
- [ ] Memory leaks prevented (Swift)
- [ ] Process cleanup on exit (Node.js)
- [ ] Network requests have error handlers
- [ ] Environment variables properly validated

**Output**: Code review report with any needed fixes

---

## Phase 8: Documentation Update (30 minutes)

### Update CLAUDE.md

**Agent**: `documentation-expert` (Documentation specialist)

**Sections to Update**:
1. AI Parser Service section
2. Scraper modifications
3. New API endpoints
4. Integration points
5. Testing procedures
6. Troubleshooting

**Files to Create/Modify**:
- `/Users/marvinbarsal/Desktop/Universität/Stats/CLAUDE.md`
- `/Users/marvinbarsal/Desktop/Universität/Stats/DOM_SCRAPING_IMPLEMENTATION_PLAN.md` (mark as implemented)

**Documentation Requirements**:
- Update architecture diagram to show AI Parser
- Add new environment variables
- Document testing procedures
- Add troubleshooting section
- Update quick reference

---

## Parallel Execution Strategy

### Tasks That Can Run in Parallel

**Group 1: Component Development** (Parallel - Phases 1-3)
- Task 1.2: Scraper enhancement (typescript-pro)
- Task 2: AI Parser testing (backend-architect)
- Task 3: Backend updates (backend-architect)
- Task 4: Swift integration (swift-coding-partner)

**Group 2: Testing** (Parallel - Phase 5)
- Test Suite 1: AI Parser (test-automator)
- Test Suite 2: Scraper (test-automator)
- Test Suite 3: Backend (test-automator)
- Test Suite 4: Swift (test-automator)

**Group 3: Quality Assurance** (Sequential after Phase 5)
- Phase 6: E2E testing
- Phase 7: Code review
- Phase 8: Documentation

### Recommended Team Schedule

**Timeline: 4-5 Hours**

```
Time 0:00-0:20   │ Phases 0-1: Environment Setup, Scraper Enhancement
                 │   typescript-pro: Task 1.2 (modify scraper.js)
                 │
Time 0:20-1:00   │ Phase 2-3: AI Parser & Backend Integration
                 │   backend-architect: Task 2.1-2.2, 3.1
                 │   typescript-pro: Task 3.2 (scraper routing)
                 │   swift-coding-partner: Task 4 (environment vars)
                 │
Time 1:00-2:00   │ Phase 5: Component Testing (PARALLEL)
                 │   test-automator: All test suites
                 │
Time 2:00-3:00   │ Phase 6: End-to-End Testing
                 │   test-automator: E2E tests 1-3
                 │
Time 3:00-3:30   │ Phase 7: Code Review
                 │   code-reviewer: Review all modifications
                 │
Time 3:30-4:00   │ Phase 8: Documentation
                 │   documentation-expert: Update CLAUDE.md
                 │
Time 4:00+       │ Final Validation & Cleanup
```

---

## Success Metrics & Validation Checklist

### Phase Completion Checklist

**Phase 0: Environment Validation**
- [ ] Ollama running and responding
- [ ] Background processes cleaned
- [ ] Stats app binary rebuilt
- [ ] Keyboard shortcut verified

**Phase 1: Scraper Enhancement**
- [ ] scraper.js captures full DOM
- [ ] Returns object with: url, title, rawHTML, visibleText, metadata
- [ ] No network requests made (read-only)
- [ ] Executes within 30 seconds

**Phase 2: AI Parser Service**
- [ ] Service starts on port 3001
- [ ] Health endpoint responds
- [ ] Processes sample DOM without errors
- [ ] Extracts questions in correct JSON format
- [ ] Uses Ollama (not OpenAI)

**Phase 3: Backend Integration**
- [ ] Backend starts on port 3000
- [ ] Receives DOM from scraper/AI Parser
- [ ] Routes questions correctly
- [ ] Returns clean answer array
- [ ] Fallback logic works if AI Parser unavailable

**Phase 4: Swift Integration**
- [ ] QuizIntegrationManager launches scraper with correct env vars
- [ ] Scraper process receives AI_PARSER_URL
- [ ] HTTP server on port 8080 listens
- [ ] Animation controller responds to triggers

**Phase 5: Component Testing**
- [ ] AI Parser: 4/4 tests pass
- [ ] Scraper: 3/3 tests pass
- [ ] Backend: 3/3 tests pass
- [ ] Swift: 3/3 tests pass
- [ ] **Total: 13/13 tests passing**

**Phase 6: E2E Testing**
- [ ] Manual scraper test completes successfully
- [ ] Full keyboard shortcut workflow succeeds
- [ ] All error scenarios handled gracefully
- [ ] Complete workflow < 30 seconds
- [ ] Widget animation displays correctly

**Phase 7: Code Review**
- [ ] No critical issues identified
- [ ] Error handling comprehensive
- [ ] No security vulnerabilities
- [ ] Code properly documented
- [ ] Logging includes debug info

**Phase 8: Documentation**
- [ ] CLAUDE.md updated with AI Parser info
- [ ] All new endpoints documented
- [ ] Testing procedures documented
- [ ] Troubleshooting section updated

---

## Troubleshooting Guide for Implementation

### Common Issues & Resolutions

**Issue 1: "Cannot connect to AI Parser at :3001"**
```
Diagnosis:
- Is AI Parser running? (ps aux | grep ai-parser)
- Is port 3001 available? (lsof -i :3001)
- Is Ollama running? (curl http://localhost:11434/api/tags)

Resolution:
1. Kill any process on 3001: lsof -ti:3001 | xargs kill -9
2. Start AI Parser: node ai-parser-service.js
3. Verify: curl http://localhost:3001/health
```

**Issue 2: "Ollama model not found"**
```
Diagnosis:
- Ollama is running but CodeLlama missing
- curl http://localhost:11434/api/tags shows no models

Resolution:
1. Pull the model: ollama pull codellama:13b-instruct
2. Verify: ollama list (should show codellama)
3. Restart AI Parser service
```

**Issue 3: "Backend receiving empty questions"**
```
Diagnosis:
- AI Parser returns questionCount: 0
- Scraper sent valid DOM

Resolution:
1. Check Ollama is processing requests
2. Review DOM structure - might not match question patterns
3. Test with different website
4. Check AI Parser logs for Ollama errors
```

**Issue 4: "Swift app not receiving answers"**
```
Diagnosis:
- Backend posts but HTTP server doesn't receive
- Port 8080 not listening

Resolution:
1. Verify Swift app is running: lsof -i :8080
2. Check Swift console for errors
3. Test directly: curl -X POST http://localhost:8080/display-answers
4. Rebuild Swift app: Cmd+B, Cmd+R in Xcode
```

**Issue 5: "Keyboard shortcut not triggering"**
```
Diagnosis:
- Cmd+Option+Q pressed but nothing happens
- Scraper doesn't launch

Resolution:
1. Verify keyboard manager initialized
2. Check System Preferences > Security & Privacy > Accessibility
3. Add Stats app to accessibility list
4. Restart Swift app
5. Try pressing shortcut multiple times
```

---

## Files Summary

### Files to Create
```
None - all files already exist or will be modified
```

### Files to Modify
```
1. scraper.js                          (+40 lines)
2. backend/server.js                   (+30 lines)
3. QuizIntegrationManager.swift        (+10 lines)
4. CLAUDE.md                           (sections updated)
```

### Files to Keep (No Changes)
```
✓ ai-parser-service.js (already correct)
✓ .env.ai-parser (already configured)
✓ QuizAnimationController.swift (timing correct at 10s display)
✓ QuizHTTPServer.swift (listening on 8080)
✓ KeyboardShortcutManager.swift (Cmd+Option+Q handler)
```

---

## Total Effort Estimate

| Phase | Duration | Agent(s) | Status |
|-------|----------|----------|--------|
| Phase 0: Environment | 10 min | Manual | Ready |
| Phase 1: Scraper | 30 min | typescript-pro | Ready |
| Phase 2: AI Parser | 20 min | backend-architect | COMPLETE |
| Phase 3: Backend | 30 min | backend-architect | Ready |
| Phase 4: Swift | 30 min | swift-coding-partner | Ready |
| Phase 5: Testing | 60 min | test-automator | Ready |
| Phase 6: E2E Testing | 60 min | test-automator | Ready |
| Phase 7: Code Review | 30 min | code-reviewer | Ready |
| Phase 8: Documentation | 30 min | documentation-expert | Ready |
| **TOTAL** | **4.5 hours** | **6 agents** | **Ready** |

---

## Next Steps

1. **Review this execution plan** - Ensure all steps are clear
2. **Approve phases** - Confirm order and assignments
3. **Dispatch agents** - Start with Phase 0 environment validation
4. **Execute sequentially** - Follow the timeline
5. **Track progress** - Check success criteria for each phase
6. **Document issues** - Any blockers discovered

---

## Questions Resolved from Original Plan

1. **OpenAI Model**: Using Ollama CodeLlama 13B instead (local, no API key needed)
2. **AI Filter Caching**: Not implemented in Phase 0 (can add later)
3. **DOM Size**: Whole page HTML sent to AI Parser (Ollama handles it)
4. **Timeout**: Set to 30-60 seconds (reasonable for Ollama)

---

**Document Version**: 1.0
**Created**: 2025-11-09
**Status**: Ready for Execution

