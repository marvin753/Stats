# Quiz Stats Animation System - Comprehensive Development Guide

**Version**: 1.2.0
**Status**: Production Ready - Screenshot-Based Extraction
**Last Updated**: November 10, 2024 (Screenshot Implementation)
**Project Location**: `/Users/marvinbarsal/Desktop/Universität/Stats/`

---

## 🔐 Test Credentials (For Development/Testing)

**IUBH Online Exams Platform:**
- **URL**: https://iubh-onlineexams.de/my/courses.php
- **Username**: barsalmarvin@gmail.com
- **Password**: hyjjuv-rIbke6-wygro&
- **Purpose**: Testing screenshot-based quiz extraction system

⚠️ **SECURITY NOTE**: These credentials are for testing only. Store securely and never commit to git.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Technology Stack](#technology-stack)
3. [Component Architecture](#component-architecture)
4. [GPU Widget Hijacking Architecture](#gpu-widget-hijacking-architecture-phase-2a2b)
5. [File Structure](#file-structure)
6. [Build & Setup Procedures](#build--setup-procedures)
7. [Configuration & Environment](#configuration--environment)
8. [Development Workflow](#development-workflow)
9. [VS Code Terminal Workflow](#vs-code-terminal-workflow-phase-4)
10. [Integration Points](#integration-points)
11. [API Reference](#api-reference)
12. [Testing Procedures](#testing-procedures)
13. [Agent Dispatch Protocol](#agent-dispatch-protocol)
14. [Troubleshooting Guide](#troubleshooting-guide)
15. [Security Considerations](#security-considerations)
16. [Performance Metrics](#performance-metrics)

---

## Project Overview

### System Purpose

The Quiz Stats Animation System is a sophisticated, fully-automated solution that:

1. **Extracts** multiple-choice questions from any webpage using DOM scraping
2. **Analyzes** questions with OpenAI's GPT API to identify correct answers
3. **Animates** answer numbers in a macOS application with precise timing

The entire workflow is triggered by a single keyboard shortcut (`Cmd+Option+Q`), making it seamless for real-time quiz participation.

### Three-Tier Architecture

```
┌─────────────────────────────────────────────────────┐
│          TIER 1: Browser & Scraper (Node.js)         │
│  - DOM extraction with Playwright                    │
│  - Keyboard shortcut trigger (Cmd+Option+Q)          │
│  - Security validation (URL whitelist, SSRF checks)  │
└─────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────┐
│   TIER 2: Backend Server (Node.js/Express)          │
│  - REST API on port 3000                            │
│  - OpenAI API integration (gpt-3.5-turbo/gpt-4)      │
│  - Answer analysis & routing                         │
│  - WebSocket support for real-time updates           │
└─────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────┐
│      TIER 3: Stats App (Swift macOS)                │
│  - HTTP Server on port 8080                         │
│  - Animation controller with state machine          │
│  - Keyboard shortcut handler                        │
│  - Integration coordinator                          │
└─────────────────────────────────────────────────────┘
```

### System Data Flow

```
User Press: Cmd+Option+Q
        ↓
Scraper (Node.js/Playwright)
        ↓
Extract Q&A from DOM
        ↓
POST to Backend /api/analyze
        ↓
Backend calls OpenAI API
        ↓
Receives answer indices [3, 2, 4, ...]
        ↓
HTTP POST to Stats app /display-answers
        ↓
Swift animates sequence:
  0 → answer₁ (1.5s) → display (10s) → 0 (1.5s) → rest (15s)
  0 → answer₂ (1.5s) → display (10s) → 0 (1.5s) → rest (15s)
  ...
  0 → 10 (1.5s) → display (15s) → STOP
```

### Key Features

- ✅ **Fully Automated**: Single keyboard shortcut triggers entire workflow
- ✅ **Intelligent Analysis**: Uses OpenAI GPT for accurate answer detection
- ✅ **Precise Animations**: 60 FPS animations with exact timing
- ✅ **Security-First**: URL validation, SSRF protection, API key in environment
- ✅ **Error Handling**: Graceful degradation with detailed logging
- ✅ **Production Ready**: Tested, documented, and deployable

---

## Technology Stack

### Frontend/Scraper

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **Runtime** | Node.js | 18+ | JavaScript execution |
| **Browser Automation** | Playwright | ^1.40.0 | DOM scraping, browser control |
| **HTTP Client** | Axios | ^1.6.0 | API communication |
| **Environment** | dotenv | ^16.0.0 | Configuration management |

**Key Files**:
- `scraper.js` (293 lines) - DOM extraction with 3 fallback strategies

### Backend Server

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **Framework** | Express.js | ^4.18.2 | REST API server |
| **API Client** | Axios | ^1.6.0 | OpenAI API calls |
| **Real-time** | WebSocket (ws) | ^8.13.0 | Real-time updates |
| **Security** | express-rate-limit | ^6.7.0 | Rate limiting |
| **CORS** | cors | ^2.8.5 | Cross-origin requests |
| **Configuration** | dotenv | ^16.0.0 | Environment variables |

**Key Files**:
- `backend/server.js` (389 lines) - Express server with OpenAI integration
- `backend/package.json` - Dependencies configuration
- `backend/.env` - API keys and configuration (GITIGNORED)

### Backend Server Features

- **Port**: 3000 (configurable via `BACKEND_PORT`)
- **Endpoints**:
  - `POST /api/analyze` - Receive questions, return answer indices
  - `GET /health` - Health check endpoint
  - `WebSocket /ws` - Real-time connection (optional)
- **Security**:
  - CORS restricted to `CORS_ALLOWED_ORIGINS`
  - Optional API key authentication via `X-API-Key` header
  - Rate limiting to prevent abuse
  - JSON payload limit: 10MB

### Swift macOS App

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **OS Framework** | Cocoa | UI and system integration |
| **Networking** | URLSession | HTTP server for receiving data |
| **Keyboard Handling** | Combine + CFRunLoop | Global keyboard shortcuts |
| **Animation** | CABasicAnimation + Timer | Smooth number animations |
| **Concurrency** | GCD + OperationQueue | Thread-safe operations |

**Key Files**:
- `QuizAnimationController.swift` (317 lines) - Animation state machine
- `QuizHTTPServer.swift` (248 lines) - HTTP server (port 8080)
- `KeyboardShortcutManager.swift` (66 lines) - Global keyboard handler
- `QuizIntegrationManager.swift` (197 lines) - Coordinator
- **Total**: 828 lines of Swift code

### External APIs

| Service | Purpose | Authentication |
|---------|---------|-----------------|
| **OpenAI** | Question analysis | API key in `OPENAI_API_KEY` |
| **Model** | gpt-3.5-turbo or gpt-4 | Configurable via `OPENAI_MODEL` |

---

## Component Architecture

### Component 1: Browser Scraper (`scraper.js`)

**Purpose**: Extract questions and answers from webpage DOM

**Responsibilities**:
- Launch headless browser (Playwright)
- Query DOM for question/answer patterns
- Support multiple HTML structures (3 fallback strategies)
- Validate URLs for security
- Send JSON to backend

**Key Functions**:
```javascript
validateUrl(urlString) → boolean
// Security validation: whitelist, IP filtering, protocol check

scrapeQuestions(url) → Promise<Array>
// Extract Q&A from DOM with fallbacks

sendToBackend(questions) → Promise<response>
// HTTP POST to /api/analyze
```

**Extraction Strategies** (in order):
1. `.question` + `.answer` selectors
2. `<li>` elements with question/answer pattern
3. Generic paragraph extraction with keyword matching

**Security Features**:
- URL validation against whitelist (`ALLOWED_DOMAINS`)
- Private IP blocking (RFC 1918, RFC 4193)
- Protocol restriction (http/https only)
- Domain suffix matching

### Component 2: Backend Server (`backend/server.js`)

**Purpose**: Analyze questions with OpenAI, route answers to app

**Responsibilities**:
- Receive question arrays via REST API
- Call OpenAI API with system prompt
- Extract answer indices from AI response
- Forward results to Stats app
- Handle errors gracefully
- Log all requests

**Key Routes**:
```
POST /api/analyze
  ├─ Input: { questions: [...] }
  ├─ Process: Call OpenAI
  └─ Output: { answers: [3,2,4,...] }

GET /health
  └─ Output: { status: "ok", openai_configured: true/false }

WebSocket /ws (optional)
  └─ Real-time updates to connected clients
```

**Environment Variables**:
```env
OPENAI_API_KEY=sk-proj-[YOUR_KEY]      # Required
OPENAI_MODEL=gpt-3.5-turbo             # Default: gpt-3.5-turbo
BACKEND_PORT=3000                       # Default: 3000
STATS_APP_URL=http://localhost:8080    # Default: localhost:8080
CORS_ALLOWED_ORIGINS=http://localhost:8080,http://localhost:3000
API_KEY=your-optional-api-key          # Optional: for auth
```

**OpenAI Integration**:
- **System Prompt**: Forces JSON-only response
- **Input Format**: Question array with answers
- **Output Format**: `[index1, index2, ...]` (1-indexed)
- **Model Options**: `gpt-3.5-turbo` (default) or `gpt-4`
- **Timeout**: 30 seconds

### Component 3: Stats macOS App

#### QuizAnimationController.swift (317 lines)

**Purpose**: Handle animation sequence with state machine

**Published Properties**:
```swift
@Published var currentNumber: Int = 0
@Published var isAnimating: Bool = false
@Published var progress: Double = 0.0
```

**Animation State Machine**:
```
animatingUp(from, to, startTime)
    ↓ (1.5s elapsed)
displayingAnswer(targetNumber, startTime)
    ↓ (10s elapsed)
animatingDown(from, to, startTime)
    ↓ (1.5s elapsed)
resting(startTime)
    ↓ (15s elapsed, repeat for next answer)
animatingToFinal(from, startTime)
    ↓ (1.5s elapsed)
displayingFinal(startTime)
    ↓ (15s elapsed)
complete
```

**Timing Constants**:
- `animationDuration`: 1.5 seconds (0 → answer or answer → 0)
- `displayDuration`: 10 seconds (display answer number) ← **Updated from 7s in Phase 2C**
- `restDuration`: 15 seconds (display 0 between answers)
- `finalDisplayDuration`: 15 seconds (display 10 at end)

**Key Methods**:
```swift
func startAnimation(with answerIndices: [Int])
  // Start the animation sequence

private func animateToNextAnswer()
  // Advance to next answer or final sequence

private func updateAnimation()
  // Timer callback to update currentNumber

func cancel()
  // Stop animation and cleanup
```

#### QuizHTTPServer.swift (248 lines)

**Purpose**: Listen for incoming requests from backend

**Server Details**:
- **Port**: 8080
- **Protocol**: HTTP (CFSocket-based)
- **Endpoint**: `POST /display-answers`
- **Request Format**: `{ "answers": [3, 2, 4, ...] }`

**Flow**:
1. Listen on port 8080
2. Receive HTTP POST with answer array
3. Parse JSON
4. Delegate to QuizAnimationController
5. Send HTTP response (200 OK)

#### KeyboardShortcutManager.swift (66 lines)

**Purpose**: Global keyboard shortcut handler

**Details**:
- **Shortcut**: Cmd+Option+Q (customizable)
- **Trigger**: System-wide global hotkey
- **Callback**: Notifies integration manager to start scraper

**Implementation**:
- Uses `CFRunLoop` for global event listener
- Delegate pattern for callback
- Graceful error handling

#### QuizIntegrationManager.swift (197 lines)

**Purpose**: Coordinate all components

**Responsibilities**:
- Initialize all modules on app start
- Handle keyboard shortcut triggers
- Launch scraper via shell command
- Coordinate HTTP server and animation controller
- Manage error states and recovery

**Initialization Flow**:
```swift
init() {
  keyboardManager = KeyboardShortcutManager(triggerKey: "q")
  httpServer = QuizHTTPServer(onAnswersReceived: handleAnswers)
  animationController = QuizAnimationController()
  httpServer.start()
  keyboardManager.delegate = self
}

func handleKeyboardTrigger() {
  // Launch scraper process
  // Scraper → Backend → HTTP Server → Animation
}
```

---

## GPU Widget Hijacking Architecture (Phase 2A/2B)

**Critical Architectural Change**: The GPU monitoring system has been completely disabled and repurposed to display real-time quiz answer numbers instead of GPU utilization metrics.

### Justification for Hijacking

The GPU widget was chosen as the display mechanism because:
- Widget already visible in menu bar during quiz sessions
- Efficient reuse of existing UI infrastructure
- No additional windows or widgets needed
- Minimal performance impact
- Familiar location for users

### Implementation Details

**1. GPU Monitoring Status: COMPLETELY DISABLED**

The GPU module (`Modules/GPU/main.swift`) has been modified:
- GPU reader initialization commented out (lines 144-165)
- No GPU metrics are collected or processed
- GPU syscalls completely removed from monitoring loop
- Performance benefit: Reduced system call overhead

**2. Widget Data Source: QuizAnimationController**

Instead of GPU metrics, the widget now displays:
- Current value from `QuizAnimationController.currentNumber`
- Range: 0-10 (answer indices and final state)
- Updates in real-time via Combine reactive subscriptions

**3. Data Flow**:

```
Backend POST /display-answers { answers: [3, 2, 4, ...] }
    ↓
QuizHTTPServer receives answer array
    ↓
QuizIntegrationManager.didReceiveAnswers([3, 2, 4, ...])
    ↓
QuizAnimationController.startAnimation(with: [3, 2, 4, ...])
    ↓
currentNumber changes trigger Combine publisher
    ↓
QuizIntegrationManager observes via $currentNumber subscription
    ↓
GPU.updateQuizNumber(newNumber) called
    ↓
GPU Mini widget updates display in menu bar
    ↓
User sees: 0 → 3 (1.5s) → "3" (10s) → 0 (1.5s) → rest (15s) → repeat
```

**4. Widget Display Behavior**:

| State | Display Value | Duration |
|-------|---------------|----------|
| **Default (no quiz)** | 0 | Indefinite |
| **Animating up** | 0 → answer number | 1.5 seconds |
| **Displaying answer** | Answer number (1-10) | 10 seconds |
| **Animating down** | Answer → 0 | 1.5 seconds |
| **Resting** | 0 | 15 seconds |
| **Final animation** | 0 → 10 | 1.5 seconds |
| **Final display** | 10 | 15 seconds |
| **Complete** | 0 | Indefinite |

**5. Integration Point**:

- **New file**: `Stats/Modules/QuizIntegrationManager.swift` (line 78-94)
- **Method**: `connectToGPUModule(_ gpu: GPU)`
- **Called from**: `AppDelegate.swift` after modules mounted
- **Connection type**: Combine subscription to `@Published` property
- **Memory management**: Weak references prevent retain cycles

**6. Code Changes Summary**:

```swift
// In QuizIntegrationManager.swift (NEW)
func connectToGPUModule(_ gpu: GPU) {
    self.gpuModule = gpu
    animationController.$currentNumber
        .receive(on: DispatchQueue.main)
        .sink { [weak gpu] number in
            gpu?.updateQuizNumber(number)
        }
        .store(in: &cancellables)
    gpu.updateQuizNumber(0) // Initialize to 0
}

// In GPU main.swift (NEW)
public func updateQuizNumber(_ number: Int) {
    let displayValue = Double(number) / 100.0
    // Updates all active widgets with quiz number
    widgets.forEach { $0.setValue(displayValue) }
}
```

**7. Performance Impact**:

- **Eliminated**: GPU monitoring syscalls (reduces CPU usage)
- **Added**: Combine subscription overhead (negligible)
- **Net effect**: Improved performance (fewer system calls)
- **Animation**: Smooth 60 FPS (handled by Timer in QuizAnimationController)

**8. Testing the Integration**:

To verify GPU widget displays quiz numbers:

1. Start Stats app: `./run-swift.sh`
2. Check menu bar: GPU widget should show "0"
3. Start backend: `cd backend && npm start`
4. Send test answers:
   ```bash
   curl -X POST http://localhost:8080/display-answers \
     -H "Content-Type: application/json" \
     -d '{"answers": [3, 2, 4]}'
   ```
5. Observe GPU widget: Should animate through 0 → 3 → 0 → 2 → 0 → 4 → 0 → 10 → 0

Expected console output:
```
🔗 Connected to GPU module for quiz display
✅ GPU widget integration complete - displaying default value: 0
🔢 GPU widget updated: displaying quiz number 3
🔢 GPU widget updated: displaying quiz number 0
...
```

---

## File Structure

```
Stats/
├── CLAUDE.md                                    ← You are here
│
├── build-swift.sh                              (24 lines - xcodebuild wrapper)
├── run-swift.sh                                (21 lines - App launcher)
├── check-prerequisites.sh                      (Environment validation)
│
├── .vscode/                                    (VS Code Configuration - Phase 4)
│   ├── tasks.json                              (Build tasks: 4 tasks defined)
│   └── launch.json                             (Debugger configs: 3 configurations)
│
├── Documentation/
│   ├── COMPLETE_SYSTEM_README.md               (Production overview)
│   ├── API_KEY_GUIDE.md                        (OpenAI setup)
│   ├── SYSTEM_ARCHITECTURE.md                  (Design details)
│   ├── SETUP_GUIDE.md                          (Installation steps)
│   ├── QUICK_START.md                          (5-minute setup)
│   └── START_HERE.md                           (Entry point)
│
├── Tier 1: Browser Scraper
│   ├── scraper.js                              (293 lines - DOM extraction)
│   ├── package.json                            (Dependencies)
│   └── .env                                    (Config - GITIGNORED)
│
├── Tier 2: Backend Server
│   ├── backend/
│   │   ├── server.js                           (389 lines - Express API)
│   │   ├── package.json                        (Dependencies)
│   │   ├── .env                                (API keys - GITIGNORED)
│   │   ├── .env.example                        (Template)
│   │   └── tests/                              (Unit & integration tests)
│   │       ├── server.test.js
│   │       ├── security.test.js
│   │       └── integration.test.js
│   └── frontend/
│       └── (JavaScript utilities for backend testing)
│
├── Tier 3: Swift App
│   └── cloned-stats/
│       └── Stats/
│           └── Modules/
│               ├── QuizAnimationController.swift     (317 lines)
│               ├── QuizHTTPServer.swift              (248 lines)
│               ├── KeyboardShortcutManager.swift     (66 lines)
│               └── QuizIntegrationManager.swift      (197 lines)
│
├── Testing/
│   ├── tests/                                  (Integration tests)
│   ├── jest.config.js                          (Jest configuration)
│   └── TEST_COMMANDS.md                        (How to run tests)
│
└── Configuration/
    ├── .env.example                            (Template for all .env files)
    ├── .gitignore                              (Excludes .env)
    └── docker-compose.yml                      (Optional: containerization)
```

### Total Code Size

| Component | File | Lines | Language |
|-----------|------|-------|----------|
| Scraper | scraper.js | 293 | JavaScript |
| Backend | backend/server.js | 389 | JavaScript |
| Animation | QuizAnimationController.swift | 317 | Swift |
| HTTP Server | QuizHTTPServer.swift | 248 | Swift |
| Keyboard | KeyboardShortcutManager.swift | 66 | Swift |
| Integration | QuizIntegrationManager.swift | 197 | Swift |
| Build Script | build-swift.sh | 24 | Bash |
| Run Script | run-swift.sh | 21 | Bash |
| **TOTAL** | | **1,555** | Mixed |

---

## Build & Setup Procedures

### Phase 1: Prerequisites

```bash
# Verify Node.js is installed
node --version          # Should be 18+
npm --version           # Should be 9+

# Verify Xcode is installed (for Swift)
xcode-select --install  # If needed

# Verify you have an OpenAI account
# Visit: https://platform.openai.com/account/api-keys
```

### Phase 2: Backend Setup

```bash
# Navigate to backend
cd /Users/marvinbarsal/Desktop/Universität/Stats/backend

# Install dependencies
npm install

# Create .env file from template
cp .env.example .env

# Edit .env with your actual OpenAI API key
nano .env
# Expected content:
# OPENAI_API_KEY=sk-proj-[YOUR_NEW_KEY]
# OPENAI_MODEL=gpt-3.5-turbo
# BACKEND_PORT=3000
# STATS_APP_URL=http://localhost:8080

# Verify .env is valid
cat .env
```

### Phase 3: Scraper Setup

```bash
# Navigate to project root
cd /Users/marvinbarsal/Desktop/Universität/Stats

# Install scraper dependencies
npm install

# Verify scraper loads correctly
node -e "require('./scraper.js'); console.log('✓ Scraper loaded')" 2>&1
```

### Phase 4: Swift App Setup

```bash
# Navigate to Swift app
cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats

# Open in Xcode
open Stats.xcodeproj

# In Xcode:
# 1. Select target "Stats"
# 2. Build: Cmd+B
# 3. Verify no compilation errors
# 4. Run: Cmd+R to test
```

### Phase 5: Verification

```bash
# Terminal 1: Start backend
cd /Users/marvinbarsal/Desktop/Universität/Stats/backend
npm start
# Should output: ✅ Backend server running on http://localhost:3000

# Terminal 2: Test health endpoint
curl http://localhost:3000/health
# Should return: {"status":"ok","openai_configured":true}

# Terminal 3: Test full analysis
curl -X POST http://localhost:3000/api/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "questions": [
      {"question": "What is 2+2?", "answers": ["1","2","3","4"]}
    ]
  }'
# Should return: {"status":"success","answers":[4],...}

# Terminal 4: Start Swift app
open /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats/Stats.xcodeproj
# Then press Cmd+R in Xcode

# Test HTTP server (from another terminal)
curl http://localhost:8080
# Should return: 200 OK or similar response

# Press Cmd+Option+Q to trigger full workflow
```

---

## Configuration & Environment

### Environment Variables

#### Backend (.env)

**Required**:
```env
OPENAI_API_KEY=sk-proj-[YOUR_KEY]
```
- Location: `/Users/marvinbarsal/Desktop/Universität/Stats/backend/.env`
- Must be kept in .gitignore
- Contains actual API key (never commit)

**Recommended**:
```env
OPENAI_MODEL=gpt-3.5-turbo
BACKEND_PORT=3000
STATS_APP_URL=http://localhost:8080
CORS_ALLOWED_ORIGINS=http://localhost:8080
```

**Optional**:
```env
API_KEY=your-backend-api-key
DEBUG=* # Enable debug logging
NODE_ENV=development|production
```

#### Scraper (.env)

**Optional**:
```env
BACKEND_URL=http://localhost:3000
BACKEND_API_KEY=your-key
ALLOWED_DOMAINS=example.com,quizplatform.com
```

### Port Configuration

| Service | Port | Purpose | Configurable |
|---------|------|---------|--------------|
| Backend API | 3000 | Express server | YES (`BACKEND_PORT`) |
| Stats HTTP Server | 8080 | Receive answers | NO (hardcoded in Swift) |

### Customization Points

**Animation Timing** (QuizAnimationController.swift):
```swift
private let animationDuration: TimeInterval = 1.5    // seconds
private let displayDuration: TimeInterval = 10.0     // seconds (updated Phase 2C)
private let restDuration: TimeInterval = 15.0        // seconds
private let finalDisplayDuration: TimeInterval = 15.0 // seconds
```

**Keyboard Shortcut** (QuizIntegrationManager.swift):
```swift
let keyboardManager = KeyboardShortcutManager(triggerKey: "q") // Cmd+Option+Q
// Change "q" to any letter for different shortcut
```

**OpenAI Model** (.env):
```env
OPENAI_MODEL=gpt-4  # Use GPT-4 instead of gpt-3.5-turbo
```

---

## Development Workflow

### Starting Development

**Terminal 1 - Backend Server**:
```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/backend
DEBUG=* npm start
```

**Terminal 2 - Swift App**:
```bash
open /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats/Stats.xcodeproj
# In Xcode: Cmd+R to run
```

**Terminal 3 - Manual Testing**:
```bash
# Test scraper
node /Users/marvinbarsal/Desktop/Universität/Stats/scraper.js --url=https://example.com

# Or send test data directly to backend
curl -X POST http://localhost:3000/api/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "questions": [
      {"question": "Q1?", "answers": ["A","B","C","D"]},
      {"question": "Q2?", "answers": ["X","Y","Z"]}
    ]
  }'
```

### Making Changes

#### Scraper Changes
1. Edit `scraper.js`
2. Test extraction: `node scraper.js --url=https://test-site.com`
3. Verify JSON output to backend

#### Backend Changes
1. Edit `backend/server.js`
2. Restart backend (Ctrl+C, then `npm start`)
3. Test endpoint with curl
4. Verify logs for errors

#### Swift Changes
1. Edit Swift files in Xcode
2. Build: Cmd+B
3. Run: Cmd+R
4. Test with keyboard shortcut

### Development Best Practices

1. **Always run backend separately**: Makes debugging easier
2. **Use debug logging**: `DEBUG=* npm start`
3. **Test components independently**: Frontend, backend, Swift separately
4. **Keep .env secure**: Never commit API keys
5. **Version your changes**: Use git commits with clear messages
6. **Test with real websites**: Different HTML structures require fallback testing

### Debugging Tips

**Backend Debugging**:
```bash
# Run with debug logging
DEBUG=* npm start

# Check if port 3000 is in use
lsof -i :3000

# Kill process on port 3000
lsof -ti:3000 | xargs kill -9

# Test OpenAI directly
curl -X POST https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-3.5-turbo","messages":[{"role":"user","content":"test"}]}'
```

**Scraper Debugging**:
```bash
# Run scraper with debug output
NODE_DEBUG=http node scraper.js

# Check what scraper is extracting
node -e "
  const scraper = require('./scraper.js');
  scraper.scrapeQuestions('https://example.com').then(q => console.log(JSON.stringify(q, null, 2)))
"
```

**Swift Debugging**:
1. Use Xcode debugger: Set breakpoints
2. Check Console output: Cmd+Shift+C
3. Check HTTP Server: `curl http://localhost:8080`
4. Monitor keyboard events: Use Xcode profiler

---

## VS Code Terminal Workflow (Phase 4)

The Stats application can now be fully developed and executed from VS Code terminal without requiring Xcode GUI.

### Prerequisites Check

Run the environment validation script before first use:

```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats
chmod +x check-prerequisites.sh
./check-prerequisites.sh
```

Expected output: All checks should show checkmarks (green status)

**What the script checks**:
- Node.js v18+ installed
- npm v9+ installed
- Xcode command line tools available
- xcodebuild accessible
- OpenAI API key configured in `backend/.env`
- Backend dependencies installed (`node_modules`)

### Available Build Tasks

VS Code includes pre-configured build tasks accessible via `Terminal > Run Task`:

**1. Build Swift App** (Keyboard: **Cmd+Shift+B**)
```bash
./build-swift.sh
```
- Compiles Stats.app using xcodebuild
- Output: `build/Build/Products/Debug/Stats.app`
- Success: "Build succeeded!"
- Failure: Script exits with code 1, shows compilation errors

**2. Run Swift App**
```bash
./run-swift.sh
```
- Runs the compiled Stats application
- HTTP Server starts on port 8080
- Keyboard shortcut available: Cmd+Option+Q
- GPU widget displays answer numbers
- Displays logs in VS Code terminal

**3. Start Backend Server**
```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/backend
npm start
```
- Starts Express server on port 3000
- Runs in separate terminal pane
- Logs all API requests and OpenAI responses
- Ctrl+C to stop

**4. Full System Launch** (Compound Task)
- Runs Backend Server and Swift App simultaneously
- Useful for complete system testing
- Backend starts first, then Swift app launches
- Both run in separate terminal panes

### VS Code Configuration Files

**`.vscode/tasks.json`** - Build task configuration
- Defines all 4 build tasks
- Binds Cmd+Shift+B to Swift build
- Configures task dependencies (e.g., run depends on build)
- Sets up error matchers for compilation errors

**`.vscode/launch.json`** - Debugger configuration
- Launch configurations for Swift (LLDB) and Node.js apps
- Allows debugging with breakpoints and variable inspection
- Compound configurations for simultaneous debugging
- Pre-launch tasks (build before debug)

### Typical Development Workflow

**1. Start Development Session**:
```bash
Terminal > Run Task > Full System Launch
```
This starts both backend and Swift app in separate terminals.

**2. Edit Code**:
- Edit Swift files in `Stats/Modules/QuizAnimationController.swift`
- OR edit backend in `backend/server.js`
- VS Code provides full IntelliSense and code completion

**3. Rebuild After Changes**:
- Press **Cmd+Shift+B** to rebuild Swift app
- Backend auto-reloads if using nodemon (otherwise restart task)
- Swift app restarts automatically via run-swift.sh

**4. Test Quiz Automation**:
- Press **Cmd+Option+Q** to trigger quiz scraping
- Watch GPU widget animate answer numbers
- Monitor backend logs for OpenAI API responses
- Verify Stats app logs show animation sequence

**5. View Logs**:
- Swift app logs: "Run Swift App" terminal pane
- Backend logs: "Start Backend Server" terminal pane
- Both logs show timestamps and request details
- Console output includes debug emoji markers

### Debugging with VS Code

**Debug Swift App**:
1. Press **F5** or select "Debug Swift App" from Run menu
2. Set breakpoints in `.swift` files
3. App runs with LLDB debugger attached
4. Inspect variables, step through code, view call stack

**Debug Backend**:
1. Select "Debug Backend" from Run menu
2. Set breakpoints in `server.js`
3. Node.js debugger attaches automatically
4. Inspect request/response objects in real-time

**Debug Both Simultaneously**:
1. Select "Debug Full System" compound configuration
2. Both Swift app and backend run with debuggers attached
3. Can debug end-to-end request flow
4. Useful for troubleshooting integration issues

### Keyboard Shortcuts Summary

| Shortcut | Action |
|----------|--------|
| **Cmd+Shift+B** | Build Swift app (VS Code default build) |
| **Cmd+Option+Q** | Trigger quiz scraping (app keyboard handler) |
| **F5** | Start debugging |
| **Shift+F5** | Stop debugging |
| **Ctrl+C** | Stop running task in terminal |

### Comparison: Xcode vs VS Code Workflow

**Previous Workflow (Xcode GUI)**:
1. Open Xcode: `open Stats.xcodeproj`
2. Wait for Xcode to index project (~30 seconds)
3. Select target "Stats" from dropdown
4. Build with Cmd+B (slow, ~2 minutes)
5. Run with Cmd+R (spawns separate app window)
6. View logs in Xcode console (limited filtering)
7. Close Xcode to stop app
8. Backend requires separate terminal session

**New Workflow (VS Code Terminal)**:
1. Open VS Code in project directory
2. Terminal > Run Task > Full System Launch
3. Both backend and app start immediately
4. Edit code with full IDE support
5. Ctrl+C to stop either service
6. Rebuild with **Cmd+Shift+B** (~30 seconds)
7. All logs visible in VS Code terminals
8. No Xcode GUI overhead

### Advantages of Terminal Workflow

- Fast builds: Incremental compilation without Xcode indexing
- Better logging: Unified view of all system output
- Easier debugging: Breakpoints and inspection in VS Code
- Faster iteration: Quick rebuild cycle (30s vs 2min)
- Team friendly: Consistent workflow across developers
- CI/CD ready: Same scripts used for automated builds
- Lower memory: No Xcode GUI (~2GB saved)
- Multi-service: Backend + app in same IDE

### Build Script Details

**`build-swift.sh`** (24 lines):
```bash
#!/bin/bash
xcodebuild -project Stats.xcodeproj \
  -scheme Stats \
  -configuration Debug \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
```

**`run-swift.sh`** (21 lines):
```bash
#!/bin/bash
APP_PATH="build/Build/Products/Debug/Stats.app/Contents/MacOS/Stats"
if [ ! -f "$APP_PATH" ]; then
  echo "Stats app not built. Run ./build-swift.sh first"
  exit 1
fi
echo "Starting Stats app..."
"$APP_PATH"
```

**Permissions**:
```bash
chmod +x build-swift.sh run-swift.sh check-prerequisites.sh
```

---

## Integration Points

### 1. Scraper → Backend

**Trigger**: Keyboard shortcut (Cmd+Option+Q)
**Flow**:
```
KeyboardShortcutManager.swift triggers
    ↓
QuizIntegrationManager launches scraper process
    ↓
scraper.js extracts DOM
    ↓
POST to http://localhost:3000/api/analyze
    ↓
Backend receives and processes
```

**Request Format**:
```json
POST http://localhost:3000/api/analyze
Content-Type: application/json

{
  "questions": [
    {"question": "What is 2+2?", "answers": ["1","2","3","4"]},
    {"question": "Capital of France?", "answers": ["London","Paris","Berlin"]}
  ]
}
```

### 2. Backend → OpenAI API

**Purpose**: Analyze questions, get answer indices
**Flow**:
```
Backend receives /api/analyze request
    ↓
Constructs system prompt (force JSON response)
    ↓
Sends to OpenAI API (gpt-3.5-turbo or gpt-4)
    ↓
Receives answer indices array
    ↓
Validates response format
```

**System Prompt**:
```
"You are a quiz expert. Analyze the questions and answers.
Return ONLY a JSON array with the indices of the correct answers.
Format: [answer_index1, answer_index2, ...]
No explanation, no text, just the array."
```

**Response Parsing**:
```javascript
// OpenAI returns: [4, 3, 1, ...]
// Sent directly to Swift app
```

### 3. Backend → Swift App

**Purpose**: Display animation
**Flow**:
```
Backend has answer indices [3, 2, 4, ...]
    ↓
HTTP POST to http://localhost:8080/display-answers
    ↓
Swift QuizHTTPServer receives
    ↓
Parses JSON
    ↓
Calls QuizAnimationController.startAnimation()
    ↓
Animation executes
```

**Request Format**:
```json
POST http://localhost:8080/display-answers
Content-Type: application/json

{
  "answers": [3, 2, 4, 1],
  "status": "success"
}
```

### 4. Swift HTTP Server → Animation Controller

**Purpose**: Connect received answers to animation
**Flow**:
```
HTTP request arrives at port 8080
    ↓
Parse JSON body
    ↓
Extract "answers" array
    ↓
Call animationController.startAnimation(with: [3, 2, 4, 1])
    ↓
Animation state machine begins
```

### 5. Keyboard Shortcut → Integration Manager

**Purpose**: Trigger entire workflow
**Flow**:
```
User presses Cmd+Option+Q
    ↓
CFRunLoop global event handler fires
    ↓
KeyboardShortcutManager.delegate.onKeyboardTrigger()
    ↓
QuizIntegrationManager launches scraper:
   Process(launchPath: "/usr/bin/node", arguments: ["scraper.js"])
    ↓
Scraper runs in subprocess
    ↓
Rest of flow continues automatically
```

### 6. QuizIntegrationManager → GPU Module (Phase 2B)

**Purpose**: Display quiz answer numbers in GPU widget

**Flow**:
```
QuizAnimationController.currentNumber changes
    ↓ (Combine subscription)
QuizIntegrationManager observes via $currentNumber
    ↓
Calls GPU.updateQuizNumber(newValue)
    ↓
GPU Mini widget updates in menu bar
    ↓
User sees current answer number (0-10)
```

**Details**:
- Connection established in `AppDelegate.swift` after modules mount
- Uses Combine framework for reactive updates
- Weak references prevent memory leaks
- GPU monitoring completely disabled (hijacked for quiz display)
- Widget shows: 0 (default) → answer numbers during quiz → 0 (complete)

---

## API Reference

### Backend Endpoints

#### 1. Health Check

```http
GET /health
```

**Response** (200 OK):
```json
{
  "status": "ok",
  "openai_configured": true,
  "timestamp": "2024-11-07T12:34:56Z"
}
```

**Use Case**: Verify backend is running and configured

---

#### 2. Analyze Questions

```http
POST /api/analyze
Content-Type: application/json
X-API-Key: your-api-key (optional)

{
  "questions": [
    {
      "question": "What is 2+2?",
      "answers": ["1", "2", "3", "4"]
    },
    {
      "question": "What is the capital of France?",
      "answers": ["London", "Berlin", "Paris", "Madrid"]
    }
  ]
}
```

**Response** (200 OK):
```json
{
  "status": "success",
  "answers": [4, 3],
  "questionCount": 2,
  "message": "Questions analyzed successfully"
}
```

**Error Responses**:
```json
// 400 Bad Request
{
  "error": "Invalid JSON",
  "message": "..."
}

// 401 Unauthorized
{
  "error": "Authentication required",
  "message": "X-API-Key header is missing"
}

// 500 Internal Server Error
{
  "error": "OpenAI API Error",
  "message": "..."
}
```

**Constraints**:
- Maximum 10 questions per request
- Maximum 4 answers per question
- JSON payload limit: 10MB
- Rate limit: 60 requests/minute (default)

---

#### 3. WebSocket Connection (Optional)

```javascript
const ws = new WebSocket('ws://localhost:3000/ws');

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  // { "answers": [3, 2, 4, ...] }
};
```

---

### Swift HTTP Server Endpoint

#### Receive Answers

```http
POST /display-answers
Content-Type: application/json

{
  "answers": [3, 2, 4, 1],
  "status": "success"
}
```

**Swift Handler**:
```swift
func handleAnswersRequest(_ answers: [Int]) {
  animationController.startAnimation(with: answers)
}
```

---

## Testing Procedures

### Unit Tests

```bash
# Run all tests
npm test

# Run with coverage
npm run test:coverage

# Run specific test file
npm test -- tests/backend/server.test.js

# Watch mode (for development)
npm run test:watch
```

### Integration Tests

```bash
# Run integration tests
npm run test:integration

# Expected: All components communicate correctly
```

### End-to-End Tests

```bash
# Requires all services running
npm run test:e2e

# Manual E2E workflow:
# 1. Start backend: npm start
# 2. Start Swift app: Cmd+R in Xcode
# 3. Press Cmd+Option+Q
# 4. Observe animation sequence
```

### Security Tests

```bash
# Run security-focused tests
npm run test:security

# Tests cover:
# - URL validation (SSRF prevention)
# - API key protection
# - CORS restrictions
# - Rate limiting
# - Error message sanitization
```

### Manual Test Cases

#### Test Case 1: Simple Question

```bash
curl -X POST http://localhost:3000/api/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "questions": [
      {"question": "What is 2+2?", "answers": ["1","2","3","4"]}
    ]
  }'

# Expected: {"status":"success","answers":[4],...}
```

#### Test Case 2: Multiple Questions

```bash
curl -X POST http://localhost:3000/api/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "questions": [
      {"question": "Q1?", "answers": ["A","B","C","D"]},
      {"question": "Q2?", "answers": ["X","Y","Z"]},
      {"question": "Q3?", "answers": ["1","2"]}
    ]
  }'

# Expected: {"status":"success","answers":[3,2,1],...}
```

#### Test Case 3: Invalid JSON

```bash
curl -X POST http://localhost:3000/api/analyze \
  -H "Content-Type: application/json" \
  -d 'invalid json'

# Expected: 400 Bad Request
```

#### Test Case 4: Real Website Scraping

```bash
# Terminal 1: Start backend
npm start

# Terminal 2: Run scraper on live website
node scraper.js --url=https://www.example.com

# Expected: Questions extracted and sent to backend
```

#### Test Case 5: Keyboard Shortcut

```
1. Start Swift app
2. Open any webpage with quiz
3. Press Cmd+Option+Q
4. Observe:
   - Scraper launches
   - Backend analyzes
   - Swift animates answer sequence
   - Final animation to 10
   - Returns to 0
```

### Expected Animation Sequence

For answers `[4, 2, 3]`:

```
Answer 1 (4):
  Time 0.0s: currentNumber = 0
  Time 0.75s: currentNumber ≈ 2
  Time 1.5s: currentNumber = 4
  Time 11.5s: currentNumber = 4
  Time 13.0s: currentNumber ≈ 2
  Time 14.5s: currentNumber = 0
  Time 29.5s: currentNumber = 0

Answer 2 (2):
  Time 29.5s: currentNumber = 0
  Time 31.0s: currentNumber = 2
  Time 41.0s: currentNumber = 2
  Time 42.5s: currentNumber = 0
  Time 57.5s: currentNumber = 0

Answer 3 (3):
  Time 57.5s: currentNumber = 0
  Time 59.0s: currentNumber = 3
  Time 69.0s: currentNumber = 3
  Time 70.5s: currentNumber = 0
  Time 85.5s: currentNumber = 0

Final:
  Time 85.5s: currentNumber = 0
  Time 87.0s: currentNumber = 10
  Time 102.0s: currentNumber = 10
  Time 102.0s: Animation stops, stays at 0
```

---

## Agent Dispatch Protocol

### When to Use Sub-Agents

The system may benefit from parallel development using multiple agents:

#### Agent 1: Backend/Node.js Specialist
**Responsibilities**:
- Maintain `scraper.js`
- Maintain `backend/server.js`
- Handle API/integration issues
- Testing and debugging Node components
- OpenAI API integration

**Trigger Conditions**:
- Backend compilation errors
- API endpoint failures
- OpenAI integration issues
- Scraper DOM extraction problems

#### Agent 2: Swift/macOS Specialist
**Responsibilities**:
- Maintain Swift modules
- Fix compilation errors
- Animation logic
- Keyboard shortcut handling
- HTTP server issues

**Trigger Conditions**:
- Swift compilation errors
- Animation timing issues
- Keyboard shortcut failures
- HTTP server connection problems

#### Agent 3: Documentation/Integration Specialist
**Responsibilities**:
- Maintain this CLAUDE.md
- Create/update guides
- Document integrations
- Handle cross-component issues

**Trigger Conditions**:
- Need for documentation updates
- Integration between components failing
- Testing procedures outdated
- Architecture changes

### Communication Protocol

**When dispatching to agents**:
1. **Clearly specify scope**: Single component or cross-component
2. **Provide context**: Current state, what's broken, expected behavior
3. **Reference files**: Absolute paths to relevant files
4. **Include timing**: Animation sequences, port numbers, timeouts
5. **Specify constraints**: Security requirements, backwards compatibility

**Example dispatch**:
```
Agent: Swift Specialist
Task: Fix QuizAnimationController animation timing
Scope: QuizAnimationController.swift only
Issue: Animation jumps from 0 to 4 instead of smoothing
Reference: /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats/Stats/Modules/QuizAnimationController.swift
Timing: Animation should take 1.5 seconds (currently instant)
Constraints: Must not break keyboard shortcut triggering
```

### Handoff Protocol

**When handing off work**:
1. Verify code compiles
2. Run tests to establish baseline
3. Document current state in CLAUDE.md
4. Provide clear error logs/stack traces
5. List exact files that need changes

**When receiving work**:
1. Read entire CLAUDE.md first
2. Understand three-tier architecture
3. Check current test results
4. Ask for clarification on unclear points
5. Don't assume fixes without understanding root cause

---

## Troubleshooting Guide

### Backend Issues

#### Problem: "Cannot find module 'express'"

**Solution**:
```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/backend
npm install
npm start
```

#### Problem: "Port 3000 already in use"

**Solution**:
```bash
# Find process using port 3000
lsof -i :3000

# Kill it
lsof -ti:3000 | xargs kill -9

# Verify it's free
lsof -i :3000  # Should return nothing
```

#### Problem: "OPENAI_API_KEY not configured"

**Solution**:
```bash
# Verify .env file exists
ls -la /Users/marvinbarsal/Desktop/Universität/Stats/backend/.env

# Check contents
cat /Users/marvinbarsal/Desktop/Universität/Stats/backend/.env

# Should see:
# OPENAI_API_KEY=sk-proj-[YOUR_KEY]

# If missing, create it:
echo "OPENAI_API_KEY=sk-proj-[YOUR_KEY]" > .env
echo "OPENAI_MODEL=gpt-3.5-turbo" >> .env
echo "BACKEND_PORT=3000" >> .env
```

#### Problem: "Invalid API key" from OpenAI

**Solution**:
1. Verify key exists at: https://platform.openai.com/account/api-keys
2. Delete old key if exposed
3. Create new key
4. Copy entire key (no spaces)
5. Update .env file
6. Restart backend

#### Problem: "Cannot connect to OpenAI API"

**Solution**:
```bash
# Check internet connection
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY"

# If fails, check:
# 1. API key is valid
# 2. Internet connection is active
# 3. Firewall not blocking api.openai.com
# 4. No rate limits hit
```

### Scraper Issues

#### Problem: "No questions found on page"

**Solution**:
1. Verify website has quiz format
2. Try different website with clear Q&A structure
3. Enable debug logging:
   ```bash
   DEBUG=* node scraper.js --url=https://example.com
   ```
4. Check if website blocks Playwright
5. Try with different browser engine

#### Problem: "Cannot connect to backend"

**Solution**:
```bash
# Verify backend is running
curl http://localhost:3000/health

# Should return 200 OK

# If fails:
# 1. Start backend: npm start
# 2. Verify port 3000 is listening: lsof -i :3000
# 3. Check firewall isn't blocking
```

#### Problem: "URL validation failed"

**Solution**:
```bash
# Check domain is whitelisted
ALLOWED_DOMAINS=example.com,quizplatform.com node scraper.js

# Or update environment:
export ALLOWED_DOMAINS="example.com,quizplatform.com,newsite.com"
node scraper.js
```

### Swift App Issues

#### Problem: "Keyboard shortcut not triggering"

**Solution** (in Xcode):
1. Check System Preferences: Security & Privacy → Accessibility
2. Add Stats app to accessibility list
3. Verify `KeyboardShortcutManager` is initialized in AppDelegate
4. Try pressing Cmd+Option+Q multiple times
5. Check console for error messages

#### Problem: "HTTP Server on port 8080 not starting"

**Solution**:
```bash
# Check if port 8080 is in use
lsof -i :8080

# Kill process using it
lsof -ti:8080 | xargs kill -9

# Rebuild Swift app in Xcode: Cmd+B
# Run again: Cmd+R
```

#### Problem: "Animation doesn't appear"

**Solution**:
1. Verify HTTP server is listening: `curl http://localhost:8080`
2. Send test data manually:
   ```bash
   curl -X POST http://localhost:8080/display-answers \
     -H "Content-Type: application/json" \
     -d '{"answers":[3,2,4]}'
   ```
3. Check Xcode console for errors
4. Verify animation controller is not in "complete" state
5. Check animation timing hasn't been modified

#### Problem: "CORS errors in Swift"

**Solution**:
- This usually doesn't apply to Swift (native URLSession)
- If using web frontend, verify `CORS_ALLOWED_ORIGINS` in backend .env

### Integration Issues

#### Problem: "Scraper runs but Swift doesn't animate"

**Diagnosis**:
```bash
# 1. Check scraper output reaches backend
curl -X POST http://localhost:3000/api/analyze \
  -H "Content-Type: application/json" \
  -d '{"questions":[{"question":"Q?","answers":["A","B"]}]}'

# 2. Verify response
# Should return: {"status":"success","answers":[1],...}

# 3. Manually send to Swift HTTP server
curl -X POST http://localhost:8080/display-answers \
  -H "Content-Type: application/json" \
  -d '{"answers":[1]}'

# 4. Watch Xcode console for animation start message
```

**Fix**:
- If backend works but Swift doesn't receive: Check HTTP server in Swift
- If HTTP server works: Check animation controller initialization
- If animation controller: Check timer callbacks are executing

#### Problem: "OpenAI returns wrong answers"

**Issue**: Model hallucinating or misunderstanding questions

**Solution**:
1. Check question format is clear
2. Switch to GPT-4:
   ```env
   OPENAI_MODEL=gpt-4
   ```
3. Check system prompt is being used
4. Verify questions don't have ambiguous answers
5. Check for special characters breaking JSON parsing

#### Problem: "Full workflow fails end-to-end"

**Systematic troubleshooting**:

```bash
# Step 1: Verify backend is running
curl http://localhost:3000/health
# Should show: {"status":"ok","openai_configured":true}

# Step 2: Test API analysis
curl -X POST http://localhost:3000/api/analyze \
  -H "Content-Type: application/json" \
  -d '{"questions":[{"question":"Test?","answers":["A","B","C"]}]}'
# Should return answers array

# Step 3: Verify Swift app is running
curl http://localhost:8080
# Should return 200 or similar

# Step 4: Send test data to Swift
curl -X POST http://localhost:8080/display-answers \
  -H "Content-Type: application/json" \
  -d '{"answers":[2]}'
# Watch Xcode console for animation start

# Step 5: If all pass, test with actual website
node scraper.js --url=https://example.com

# Step 6: If scraper output looks wrong, check HTML structure
# May need to add new extraction strategy
```

---

## Security Considerations

### API Key Management

**Protect your API key**:
1. ✅ Store in `.env` file (GITIGNORED)
2. ✅ Never commit `.env` to git
3. ✅ Verify `.gitignore` contains `backend/.env`
4. ✅ Rotate keys regularly
5. ✅ Use different keys for different projects

**If exposed**:
1. Go to: https://platform.openai.com/account/api-keys
2. Delete compromised key
3. Create new key
4. Update `.env` file
5. Restart backend

### URL Validation (Scraper)

**Protections**:
- ✅ Whitelist enforcement: Only allowed domains
- ✅ Private IP blocking: RFC 1918, RFC 4193, RFC 3927
- ✅ Protocol restriction: HTTP/HTTPS only
- ✅ Subdomain matching: `example.com` includes `sub.example.com`

**Custom whitelist**:
```bash
export ALLOWED_DOMAINS="example.com,quizplatform.com,mysite.edu"
node scraper.js
```

### CORS Configuration (Backend)

**Default allowed origins**:
```env
CORS_ALLOWED_ORIGINS=http://localhost:8080,http://localhost:3000
```

**Production update**:
```env
CORS_ALLOWED_ORIGINS=https://yourdomain.com,https://app.yourdomain.com
```

### Rate Limiting

**Default**: 60 requests per minute per IP

**In production**, consider:
```javascript
// In backend/server.js
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100                   // limit each IP to 100 requests per windowMs
});
```

### Error Messages

**Best practices**:
- ✅ Don't expose stack traces to frontend
- ✅ Don't reveal API keys in logs
- ✅ Don't show internal file paths
- ✅ Log detailed errors to file, show generic messages to users

### Network Security

**Local development** (default):
- Scraper → Backend: `localhost:3000` (same machine)
- Backend → Swift: `localhost:8080` (same machine)
- Backend → OpenAI: HTTPS encrypted

**Production**:
- Consider firewall rules
- Use VPN for remote deployment
- Monitor API usage for anomalies
- Set up alerting for quota changes

---

## Performance Metrics

### Target Metrics

| Metric | Target | Notes |
|--------|--------|-------|
| Scraper execution | < 5 seconds | DOM extraction + JSON serialization |
| Backend response | < 2 seconds | Excluding OpenAI API time |
| OpenAI API | 5-15 seconds | Variable based on load |
| Total end-to-end | < 30 seconds | From Cmd+Option+Q to animation start |
| Animation FPS | 60 FPS | Smooth visual experience |
| Memory (Node.js) | < 100MB | Backend + scraper |
| Memory (Swift) | < 150MB | Typical app memory |
| HTTP latency | < 100ms | Local network requests |

### Performance Optimization

**Scraper**:
- Use Playwright headless mode (default)
- Parallel question extraction if multiple patterns match
- Cache DOM queries

**Backend**:
- Reuse HTTP connections to OpenAI
- Implement request caching for identical questions
- Use connection pooling

**Swift**:
- Offload animation to GPU via CABasicAnimation
- Use GCD for background tasks
- Avoid main thread blocking

### Monitoring

**Backend metrics to track**:
```bash
# Number of requests
curl http://localhost:3000/stats

# API usage
cat backend/logs/api-usage.log

# Error rate
grep ERROR backend/logs/app.log | wc -l
```

---

## Quick Reference

### Essential Commands

**Start Backend**:
```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/backend && npm start
```

**Test Health**:
```bash
curl http://localhost:3000/health
```

**Test Full Analysis**:
```bash
curl -X POST http://localhost:3000/api/analyze \
  -H "Content-Type: application/json" \
  -d '{"questions":[{"question":"Q?","answers":["A","B","C"]}]}'
```

**Run Tests**:
```bash
npm test
npm run test:coverage
npm run test:e2e
```

**Start Swift App**:
```bash
open /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats/Stats.xcodeproj
# Then Cmd+R in Xcode
```

**Kill Port 3000**:
```bash
lsof -ti:3000 | xargs kill -9
```

**View .env**:
```bash
cat /Users/marvinbarsal/Desktop/Universität/Stats/backend/.env
```

**Edit .env**:
```bash
nano /Users/marvinbarsal/Desktop/Universität/Stats/backend/.env
```

### File Locations

| File | Path |
|------|------|
| Scraper | `/Users/marvinbarsal/Desktop/Universität/Stats/scraper.js` |
| Backend | `/Users/marvinbarsal/Desktop/Universität/Stats/backend/server.js` |
| Backend Config | `/Users/marvinbarsal/Desktop/Universität/Stats/backend/.env` |
| Animation Controller | `/Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats/Stats/Modules/QuizAnimationController.swift` |
| HTTP Server | `/Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats/Stats/Modules/QuizHTTPServer.swift` |
| Keyboard Manager | `/Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats/Stats/Modules/KeyboardShortcutManager.swift` |
| Integration Manager | `/Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats/Stats/Modules/QuizIntegrationManager.swift` |

### Port Usage

- **3000**: Backend API (configurable)
- **8080**: Swift HTTP Server (hardcoded)

### Keyboard Shortcut

- **Default**: Cmd+Option+Q
- **Customizable**: Edit `QuizIntegrationManager.swift`

### Environment Variables

**Required**:
- `OPENAI_API_KEY` - Must be set

**Recommended**:
- `OPENAI_MODEL` - Default: `gpt-3.5-turbo`
- `BACKEND_PORT` - Default: `3000`
- `STATS_APP_URL` - Default: `http://localhost:8080`

---

## Additional Resources

### Documentation Files
- **COMPLETE_SYSTEM_README.md** - Full system overview and validation
- **API_KEY_GUIDE.md** - OpenAI API key setup
- **SETUP_GUIDE.md** - Step-by-step installation
- **QUICK_START.md** - 5-minute quick start
- **SYSTEM_ARCHITECTURE.md** - Architecture details

### External Resources
- **OpenAI Documentation**: https://platform.openai.com/docs/
- **Playwright Docs**: https://playwright.dev/
- **Express.js Docs**: https://expressjs.com/
- **Swift Documentation**: https://developer.apple.com/swift/

### Support Contacts
For issues:
1. Check this CLAUDE.md first
2. Search existing documentation
3. Check error logs
4. Refer to troubleshooting section
5. Test components independently

---

## Document Information

**Document Title**: Quiz Stats Animation System - Comprehensive Development Guide
**Version**: 1.1.0
**Location**: `/Users/marvinbarsal/Desktop/Universität/Stats/CLAUDE.md`
**Last Updated**: November 7, 2024 (Phase 2A-4 Updates)
**Scope**: Complete system documentation for development and maintenance
**Audience**: Developers, system administrators, sub-agents
**Recent Updates**: GPU widget hijacking, VS Code terminal workflow, animation timing (10s), backend logging, build scripts

### How to Update This Document

1. Whenever system architecture changes, update Section 3
2. When adding new endpoints, update Section 10 (API Reference)
3. For new environment variables, update Section 7
4. When troubleshooting an issue, add to Section 12
5. Always maintain section cross-references

### Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.1.0 | Nov 7, 2024 | Phase 2A-4 updates: GPU widget hijacking, VS Code workflow, animation timing (10s), backend logging, new build scripts |
| 1.0.0 | Nov 7, 2024 | Initial comprehensive documentation |

---

## Conclusion

This CLAUDE.md serves as the **single source of truth** for the Quiz Stats Animation System. It contains all necessary information for:

- Setting up and running the system
- Understanding the three-tier architecture
- Integrating components
- Troubleshooting issues
- Deploying to production
- Onboarding new developers
- Dispatching work to sub-agents

For questions or updates, refer to the relevant section or check the external documentation files.

**Status**: ✅ **Complete and Production Ready**
