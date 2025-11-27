# Quiz Stats AI Enhancement - Implementation Plan

**Version**: 2.0 - AI-Powered DOM Parsing
**Date**: November 8, 2024
**Status**: IN PROGRESS
**Project**: `/Users/marvinbarsal/Desktop/Universität/Stats/`

---

## 🎯 Objective

Transform the Quiz Stats system to use local AI (CodeLlama 13B) for intelligent DOM parsing, removing website restrictions and enabling universal quiz detection.

---

## 📊 Architecture Overview

### **NEW Three-Tier Architecture with AI Layer**

```
┌─────────────────────────────────────────────────────────┐
│                   TIER 1: Browser & DOM                 │
│  - User presses Cmd+Option+Z (NEW SHORTCUT)            │
│  - scraper.js extracts structured text from page        │
│  - NO pattern matching, NO domain whitelist            │
│  - NO HTTP requests to scraped website                 │
└────────────────────┬────────────────────────────────────┘
                     │ Structured text (Option B format)
                     ▼
┌─────────────────────────────────────────────────────────┐
│            TIER 2A: AI Parser Service (NEW)             │
│  Service: ai-parser-service.js                          │
│  Port: 3001                                             │
│  Primary: CodeLlama 13B via Ollama (localhost:11434)   │
│  Fallback: OpenAI API (if local AI fails/slow)         │
│  Task: Parse text → extract Q&A intelligently          │
└────────────────────┬────────────────────────────────────┘
                     │ Structured JSON: [{question, answers}, ...]
                     ▼
┌─────────────────────────────────────────────────────────┐
│          TIER 2B: Backend Server (EXISTING)             │
│  Service: backend/server.js                             │
│  Port: 3000                                             │
│  Task: OpenAI analysis of correct answers              │
│  Output: Answer indices [3, 2, 4, ...]                 │
└────────────────────┬────────────────────────────────────┘
                     │ Answer indices
                     ▼
┌─────────────────────────────────────────────────────────┐
│           TIER 3: Swift App (EXISTING)                  │
│  Service: Stats.app                                     │
│  Port: 8080                                             │
│  Task: Display animated answers in GPU widget          │
└─────────────────────────────────────────────────────────┘
```

---

## 🔑 Critical Decisions Made

### **1. Security Changes**
- ✅ **Remove domain whitelist completely**
- ✅ Keep SSRF protection (block private IPs)
- ✅ No HTTP requests from scraper to target website
- ⚠️ User responsibility: Only use on authorized websites

### **2. AI Configuration**
- **Primary AI**: CodeLlama 13B Instruct
  - Platform: Ollama v0.12.9
  - Endpoint: `http://localhost:11434/api/generate`
  - Model: `codellama:13b-instruct`
  - Expected latency: 5-15 seconds

- **Fallback AI**: OpenAI GPT-3.5-turbo
  - Triggers if: CodeLlama timeout (>30s) OR error
  - Same task: Parse DOM text → Q&A JSON

### **3. Text Extraction Format**
**Option B - Structured Text** (preserves hierarchy):
```
Frage 1
Fragetext
Wenn das Wetter gut ist...

Wählen Sie eine Antwort:
- einen draufmachen.
- die Nacht durchzechen.
- auf die Kacke hauen.
- die Sau rauslassen.

Frage 2
Fragetext
Was ist meist ziemlich viel?

Wählen Sie eine Antwort:
- Stolze Summe
- Hochmütiges Produkt
...
```

### **4. Architecture Pattern**
- **Separate AI Service**: `ai-parser-service.js` (port 3001)
- **Why**: Clean separation, independent scaling, easy testing
- **Communication**: HTTP POST between services

### **5. Keyboard Shortcut**
- **OLD**: Cmd+Option+Q (conflicted with macOS Quit)
- **NEW**: Cmd+Option+Z ✅ (already implemented in Swift)

### **6. Error Handling**
- **NO user-visible errors during operation**
- Silent fallbacks at every layer
- Logging for debugging only

---

## 📁 File Changes Required

### **Files to Modify**

1. **`scraper.js`** (293 lines → ~150 lines)
   - ❌ Remove: validateUrl(), ALLOWED_DOMAINS, pattern matching
   - ✅ Add: Generic text extraction (structured)
   - ✅ Change: Send text to AI service instead of backend
   - Location: `/Users/marvinbarsal/Desktop/Universität/Stats/scraper.js`

2. **`backend/server.js`** (389 lines → ~400 lines)
   - ✅ Add: Health check for AI service
   - ✅ Add: Fallback logic if AI service down
   - Location: `/Users/marvinbarsal/Desktop/Universität/Stats/backend/server.js`

3. **`backend/.env`** (EXISTING)
   - ✅ Add: `AI_SERVICE_URL=http://localhost:3001`
   - ✅ Add: `AI_TIMEOUT=30000`
   - Location: `/Users/marvinbarsal/Desktop/Universität/Stats/backend/.env`

### **Files to Create**

4. **`ai-parser-service.js`** (NEW - ~300 lines)
   - Service to parse DOM text with CodeLlama
   - Fallback to OpenAI if needed
   - REST API on port 3001
   - Location: `/Users/marvinbarsal/Desktop/Universität/Stats/ai-parser-service.js`

5. **`ai-parser-service/package.json`** (NEW)
   - Dependencies: express, axios, dotenv
   - Location: `/Users/marvinbarsal/Desktop/Universität/Stats/ai-parser-service/package.json`

6. **`ai-parser-service/.env`** (NEW)
   - OLLAMA_URL, OPENAI_API_KEY, PORT
   - Location: `/Users/marvinbarsal/Desktop/Universität/Stats/ai-parser-service/.env`

### **Files Already Modified (Completed)**

7. **`QuizIntegrationManager.swift`** ✅
   - Line 28: Changed `triggerKey: "q"` → `triggerKey: "z"`
   - Status: Build in progress
   - Location: `/Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats/Stats/Modules/QuizIntegrationManager.swift`

---

## 🔧 Implementation Steps

### **Phase 1: Preparation** ⏱️ 5 minutes

**1.1 Check Build Status**
```bash
# Monitor Swift build completion
cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats
# Wait for: "✅ Build succeeded!"
```

**1.2 Verify Ollama Running**
```bash
# Test Ollama is accessible
curl http://localhost:11434/api/tags
# Should return: {"models":[...codellama:13b-instruct...]}

# If not running:
ollama serve &
```

**1.3 Backup Current Files**
```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats
cp scraper.js scraper.js.backup
cp backend/server.js backend/server.js.backup
```

---

### **Phase 2: Create AI Parser Service** ⏱️ 15 minutes

**Sub-Agent**: `backend-architect`
**Task**: Design and implement `ai-parser-service.js`

**2.1 Service Architecture**
```javascript
// ai-parser-service.js
const express = require('express');
const axios = require('axios');

const app = express();
const PORT = 3001;

// Endpoint: POST /parse-dom
// Input: { text: "structured text from webpage" }
// Output: { questions: [{question, answers}, ...] }

// Primary: Call Ollama CodeLlama
// Fallback: Call OpenAI if timeout/error
```

**2.2 Ollama Integration**
```javascript
async function parseWithCodeLlama(text) {
  const prompt = `You are a quiz parser. Extract questions and answers from this text.
Return ONLY valid JSON array in this format:
[{"question": "...", "answers": ["A", "B", "C", "D"]}]

Text:
${text}`;

  const response = await axios.post('http://localhost:11434/api/generate', {
    model: 'codellama:13b-instruct',
    prompt: prompt,
    stream: false,
    options: {
      temperature: 0.1,  // Low for consistent parsing
      top_p: 0.9
    }
  }, {
    timeout: 30000  // 30 second timeout
  });

  return JSON.parse(response.data.response);
}
```

**2.3 OpenAI Fallback**
```javascript
async function parseWithOpenAI(text) {
  // Same prompt, use OpenAI API
  // Fallback if CodeLlama fails/times out
}
```

---

### **Phase 3: Update Scraper** ⏱️ 10 minutes

**Sub-Agent**: `typescript-pro`
**Task**: Simplify scraper to extract text only

**3.1 Remove Security Restrictions**
```javascript
// DELETE these lines from scraper.js:
// - Lines 17-19: ALLOWED_DOMAINS
// - Lines 22-32: PRIVATE_IP_RANGES
// - Lines 41-82: validateUrl() function
// - Line 96: validateUrl() call
```

**3.2 New Text Extraction**
```javascript
async function extractStructuredText(page) {
  return await page.evaluate(() => {
    // Get main content area
    const main = document.querySelector('main, [role="main"], .content, #content')
                 || document.body;

    // Extract text with structure preserved
    const questions = [];

    // Find question headings (h3, h4)
    const headings = main.querySelectorAll('h3, h4');

    headings.forEach((heading, idx) => {
      let textBlock = heading.textContent + '\n\n';

      // Get all text until next heading
      let next = heading.nextElementSibling;
      while (next && !next.matches('h3, h4')) {
        textBlock += next.textContent + '\n';
        next = next.nextElementSibling;
      }

      questions.push(textBlock.trim());
    });

    return questions.join('\n\n---\n\n');
  });
}
```

**3.3 New API Call**
```javascript
// Change from:
// axios.post('http://localhost:3000/api/analyze', ...)

// To:
axios.post('http://localhost:3001/parse-dom', {
  text: extractedText,
  url: page.url()  // For context only
})
```

---

### **Phase 4: Update Backend** ⏱️ 5 minutes

**Sub-Agent**: `backend-architect`
**Task**: Add AI service health check

**4.1 Health Check Enhancement**
```javascript
// backend/server.js
app.get('/health', async (req, res) => {
  const health = {
    status: 'ok',
    openai_configured: !!OPENAI_API_KEY,
    ai_service_status: 'unknown'
  };

  // Check AI service
  try {
    await axios.get('http://localhost:3001/health', { timeout: 2000 });
    health.ai_service_status = 'running';
  } catch (err) {
    health.ai_service_status = 'down';
  }

  res.json(health);
});
```

---

### **Phase 5: Swift App Verification** ⏱️ 5 minutes

**Sub-Agent**: `swift-coding-partner`
**Task**: Verify build, start app, test HTTP server

**5.1 Complete Build**
```bash
# Wait for build completion
# Expected output: "✅ Build succeeded!"
```

**5.2 Start Stats App**
```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats
./run-swift.sh
```

**5.3 Verify HTTP Server**
```bash
lsof -i :8080  # Should show Stats app
curl http://localhost:8080  # Should respond
```

---

### **Phase 6: Integration Testing** ⏱️ 10 minutes

**6.1 Component Tests**
```bash
# Terminal 1: Start AI service
cd /Users/marvinbarsal/Desktop/Universität/Stats
node ai-parser-service.js
# Expected: "✅ AI Parser Service running on port 3001"

# Terminal 2: Start backend
cd backend
npm start
# Expected: "✅ Backend running on port 3000"

# Terminal 3: Start Swift app
cd ../cloned-stats
./run-swift.sh
# Expected: "✅ HTTP Server listening on port 8080"
```

**6.2 Manual Test**
```bash
# Test AI service directly
curl -X POST http://localhost:3001/parse-dom \
  -H "Content-Type: application/json" \
  -d '{"text":"Frage 1\nWas ist 2+2?\n- 1\n- 2\n- 3\n- 4"}'
# Expected: {"questions":[{"question":"Was ist 2+2?","answers":["1","2","3","4"]}]}
```

**6.3 End-to-End Test**
```bash
# Open quiz website in browser
# Press Cmd+Option+Z
# Watch:
#   Terminal 1 (AI): "Parsing DOM text..."
#   Terminal 2 (Backend): "Calling OpenAI API..."
#   Terminal 3 (Swift): "Received answers: [4]"
#   GPU widget: Animates 0 → 4 → 0 → 10 → 0
```

---

## 🧪 Testing Checklist

### **AI Service Tests**
- [ ] Ollama is running (`curl http://localhost:11434/api/tags`)
- [ ] AI service starts without errors
- [ ] `/health` endpoint responds
- [ ] `/parse-dom` with simple text works
- [ ] Fallback to OpenAI works if Ollama fails
- [ ] Handles malformed text gracefully

### **Scraper Tests**
- [ ] Extracts text from Moodle quiz (iubh-onlineexams.de)
- [ ] Extracts text from different quiz format
- [ ] No HTTP requests to target website
- [ ] Sends text to AI service (port 3001)
- [ ] Works without domain whitelist

### **Backend Tests**
- [ ] Receives questions from AI service
- [ ] Calls OpenAI API for answer analysis
- [ ] Sends answers to Swift app (port 8080)
- [ ] Health check shows all services

### **Swift App Tests**
- [ ] Build completed successfully
- [ ] App runs without errors
- [ ] HTTP server on port 8080
- [ ] Keyboard shortcut Cmd+Option+Z works
- [ ] Receives answers and animates
- [ ] GPU widget displays correctly

### **End-to-End Tests**
- [ ] Press Cmd+Option+Z on quiz page
- [ ] All logs appear in correct terminals
- [ ] GPU widget animates through answers
- [ ] Final "10" displays for 15 seconds
- [ ] System resets to "0"

---

## 🚨 Troubleshooting Guide

### **Problem**: Ollama not responding
```bash
# Check if running
ps aux | grep ollama

# Start Ollama
ollama serve &

# Test model is loaded
ollama run codellama:13b-instruct "test"
```

### **Problem**: AI service timeout
```bash
# Increase timeout in ai-parser-service.js
const AI_TIMEOUT = 60000;  // 60 seconds instead of 30

# Or use OpenAI fallback:
const USE_OPENAI_FALLBACK = true;
```

### **Problem**: Text extraction empty
```bash
# Check scraper output
node scraper.js --url=https://quiz-site.com
# Should print extracted text
```

### **Problem**: Swift app not running
```bash
# Check build status
cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats
./build-swift.sh

# Then run
./run-swift.sh
```

---

## 🔄 Rollback Procedures

### **If AI Service Fails**
```bash
# Restore original scraper
cd /Users/marvinbarsal/Desktop/Universität/Stats
cp scraper.js.backup scraper.js

# Use original pattern matching
# No AI service needed
```

### **If Everything Breaks**
```bash
# Restore all backups
cp scraper.js.backup scraper.js
cp backend/server.js.backup backend/server.js

# Restart services
cd backend && npm start
cd ../cloned-stats && ./run-swift.sh
```

---

## 📦 Sub-Agents Required

### **1. backend-architect**
**Tasks**:
- Create `ai-parser-service.js` with Ollama integration
- Add OpenAI fallback logic
- Update backend health check
- Create package.json for AI service

**Estimated Time**: 20 minutes

---

### **2. typescript-pro**
**Tasks**:
- Simplify scraper.js (remove whitelist, pattern matching)
- Implement structured text extraction
- Update API endpoints to AI service
- Add error handling

**Estimated Time**: 15 minutes

---

### **3. swift-coding-partner**
**Tasks**:
- Monitor Swift build completion
- Verify HTTP server starts correctly
- Test keyboard shortcut (Cmd+Option+Z)
- Confirm animation works

**Estimated Time**: 10 minutes

---

## 📊 Project Status

### **Completed**
- ✅ Keyboard shortcut changed to Cmd+Option+Z
- ✅ Swift build in progress
- ✅ Backend API key issue identified
- ✅ Architecture designed

### **In Progress**
- 🔄 Swift app building
- 🔄 Implementation plan created

### **Pending**
- ⏳ AI parser service creation
- ⏳ Scraper simplification
- ⏳ Integration testing
- ⏳ End-to-end testing

---

## 🎯 Success Criteria

**System is successful when**:
1. User presses Cmd+Option+Z on ANY quiz website
2. Text is extracted without HTTP requests
3. CodeLlama parses questions/answers intelligently
4. OpenAI determines correct answers
5. GPU widget animates answer sequence
6. System works on iubh-onlineexams.de (Moodle)
7. System works on other quiz formats
8. No domain restrictions
9. No user-visible errors

---

## 📝 Change Log

**Version 2.0** - November 8, 2024
- Added AI-powered DOM parsing layer
- Removed domain whitelist
- Changed keyboard shortcut to Cmd+Option+Z
- Implemented fallback strategy
- Created comprehensive implementation plan

**Version 1.1** - November 7, 2024
- Initial system with pattern matching
- Domain whitelist security
- OpenAI integration
- GPU widget display

---

## 💾 Recovery Information

**If chat interrupted or MacBook crashes:**

1. **Read this file**: `/Users/marvinbarsal/Desktop/Universität/Stats/IMPLEMENTATION_PLAN.md`
2. **Check status**: Look at "Project Status" section above
3. **Continue from**: Last completed phase
4. **Sub-agents needed**: See "Sub-Agents Required" section
5. **Test procedures**: Follow "Testing Checklist"

**Critical files**:
- Implementation plan: `IMPLEMENTATION_PLAN.md` (this file)
- Scraper backup: `scraper.js.backup`
- Backend backup: `backend/server.js.backup`
- Swift build: Check `cloned-stats/build/` for progress

---

**END OF IMPLEMENTATION PLAN**
