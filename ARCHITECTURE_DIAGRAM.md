# Stats Quiz System - Architecture Diagrams

**Version**: 2.0.0
**Last Updated**: November 13, 2025

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Component Architecture](#component-architecture)
3. [Data Flow Diagrams](#data-flow-diagrams)
4. [Sequence Diagrams](#sequence-diagrams)
5. [Deployment Architecture](#deployment-architecture)
6. [Network Topology](#network-topology)

---

## System Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                            USER (macOS)                              │
│                                                                      │
│  Keyboard Shortcuts:                                                 │
│  • Cmd+Option+O  → Capture Screenshot                               │
│  • Cmd+Option+P  → Process Quiz                                     │
│  • Cmd+Option+L  → Upload PDF Script                                │
│                                                                      │
│  Visual Feedback:                                                    │
│  • GPU Widget (Menu Bar) → Animated answer display                  │
│  • Notifications → Success/error messages                           │
└──────────────────────────────┬───────────────────────────────────────┘
                               │
                               │ CGEvent Tap
                               │
        ┌──────────────────────┴──────────────────────┐
        │                                             │
        │        Stats App (Swift macOS)              │
        │        Port: 8080                           │
        │                                             │
        │  ┌─────────────────────────────────────┐   │
        │  │  KeyboardShortcutManager            │   │
        │  │  • CGEvent monitoring               │   │
        │  │  • Accessibility permission         │   │
        │  └────────────┬────────────────────────┘   │
        │               │                             │
        │  ┌────────────▼────────────────────────┐   │
        │  │  QuizIntegrationManager             │   │
        │  │  • Workflow coordinator             │   │
        │  │  • Service orchestration            │   │
        │  └───┬─────────┬──────────┬────────────┘   │
        │      │         │          │                 │
        │  ┌───▼───┐ ┌──▼─────┐ ┌──▼──────────────┐ │
        │  │CDP    │ │Vision  │ │Animation        │ │
        │  │Capture│ │AI      │ │Controller       │ │
        │  │       │ │Service │ │                 │ │
        │  └───┬───┘ └──┬─────┘ └──┬──────────────┘ │
        │      │         │          │                 │
        │  ┌───▼─────────▼──────────▼──────────────┐ │
        │  │     QuizHTTPServer (port 8080)        │ │
        │  │     • Receives answers from backend   │ │
        │  └───────────────────────────────────────┘ │
        └──────────┬────────────┬──────────────────────┘
                   │            │
                   │ HTTP       │ HTTP
                   │            │
    ┌──────────────▼───┐   ┌───▼─────────────────────┐
    │                  │   │                         │
    │  CDP Service     │   │  Backend Server         │
    │  Port: 9223      │   │  Port: 3000             │
    │  TypeScript      │   │  Node.js/Express        │
    │                  │   │                         │
    │  ┌────────────┐  │   │  ┌──────────────────┐  │
    │  │Chrome      │  │   │  │Assistant         │  │
    │  │Manager     │  │   │  │API Service       │  │
    │  └─────┬──────┘  │   │  └────────┬─────────┘  │
    │        │         │   │           │             │
    │  ┌─────▼──────┐  │   │  ┌────────▼─────────┐  │
    │  │CDP Client  │  │   │  │PDF Text          │  │
    │  │(WebSocket) │  │   │  │Extractor         │  │
    │  └─────┬──────┘  │   │  └──────────────────┘  │
    └────────┼─────────┘   └──────────┬──────────────┘
             │                        │
             │ WebSocket              │ HTTPS
             │ Port 9222              │
    ┌────────▼───────┐       ┌────────▼──────────────┐
    │                │       │                       │
    │  Chrome        │       │  OpenAI API           │
    │  Browser       │       │                       │
    │  (Debug Mode)  │       │  • gpt-4-turbo        │
    │                │       │  • Assistant API      │
    │  • DOM         │       │  • Vector Store       │
    │  • Rendering   │       │  • Retrieval Tool     │
    │  • DevTools    │       │                       │
    │                │       │                       │
    └────────────────┘       └───────────────────────┘
```

---

## Component Architecture

### Stats App Internal Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Stats App (Swift)                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │              AppDelegate (Entry Point)                  │    │
│  │  • Initializes all modules                              │    │
│  │  • Manages app lifecycle                                │    │
│  │  • Coordinates module connections                       │    │
│  └───────────┬────────────────────────────────────────────┘    │
│              │                                                   │
│              │ Initializes                                      │
│              │                                                   │
│  ┌───────────▼────────────────────────────────────────────┐    │
│  │         QuizIntegrationManager                          │    │
│  │  Role: Central Coordinator                              │    │
│  │  • Manages component lifecycle                          │    │
│  │  • Orchestrates workflows                               │    │
│  │  • Handles keyboard shortcut callbacks                  │    │
│  │  • Manages PDF upload flow                              │    │
│  └──┬────────┬────────┬────────┬──────────┬──────────────┘    │
│     │        │        │        │          │                    │
│     │        │        │        │          │                    │
│  ┌──▼───┐ ┌─▼─────┐ ┌▼───────┐ ┌▼────────┐ ┌▼───────────┐   │
│  │Kbd   │ │CDP    │ │Vision  │ │Anim     │ │HTTP        │   │
│  │Mgr   │ │Capture│ │AI Svc  │ │Ctrl     │ │Server      │   │
│  └──────┘ └───────┘ └────────┘ └─────────┘ └────────────┘   │
│  361 ln    323 ln    173 ln     317 ln      248 ln           │
│                                                                │
│  Supporting Services:                                          │
│  ┌────────────────────┐  ┌───────────────────────────────┐   │
│  │AssistantAPIService │  │PDFTextExtractor               │   │
│  │• Thread management │  │• Text extraction              │   │
│  │• OpenAI client     │  │• PDF parsing                  │   │
│  └────────────────────┘  └───────────────────────────────┘   │
│                                                                │
│  Data Models:                                                  │
│  ┌────────────────────────────────────────────────────────┐   │
│  │• ThreadInfo, PDFInfo, QuizQuestion, AnswerIndex        │   │
│  └────────────────────────────────────────────────────────┘   │
│                                                                │
└─────────────────────────────────────────────────────────────────┘

Communication:
  → Delegate patterns
  → Combine publishers (@Published properties)
  → Async/await for asynchronous operations
  → HTTP requests via URLSession
```

### CDP Service Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                Chrome CDP Service (TypeScript)                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │               index.ts (HTTP Server)                    │    │
│  │  • Express.js server on port 9223                       │    │
│  │  • REST API endpoints                                   │    │
│  │  • Request validation                                   │    │
│  │  • Error handling                                       │    │
│  └───┬────────────────────────────────────────────────────┘    │
│      │                                                           │
│      │ Uses                                                      │
│      │                                                           │
│  ┌───▼─────────────────────────────────────────────────────┐   │
│  │          chrome-manager.ts (Lifecycle)                   │   │
│  │  • Chrome process management                             │   │
│  │  • Launch with stealth flags                             │   │
│  │  • Auto-restart on crash                                 │   │
│  │  • Port management (9222)                                │   │
│  │  • Health monitoring                                     │   │
│  └───┬─────────────────────────────────────────────────────┘   │
│      │                                                           │
│      │ Uses                                                      │
│      │                                                           │
│  ┌───▼─────────────────────────────────────────────────────┐   │
│  │          cdp-client.ts (Protocol)                        │   │
│  │  • Chrome DevTools Protocol client                       │   │
│  │  • WebSocket connection (port 9222)                      │   │
│  │  • Page.captureScreenshot command                        │   │
│  │  • Target discovery                                      │   │
│  │  • Error recovery                                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │              types.ts (Interfaces)                      │    │
│  │  • ScreenshotResponse                                   │    │
│  │  • TargetInfo                                           │    │
│  │  • HealthResponse                                       │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

External Dependencies:
  → chrome-remote-interface (CDP communication)
  → express (HTTP server)
  → child_process (Chrome process management)
```

### Backend Service Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                Backend Server (Node.js/Express)                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │              server.js (Main Server)                    │    │
│  │  • Express.js on port 3000                              │    │
│  │  • Route definitions                                    │    │
│  │  • Middleware stack                                     │    │
│  │  • Error handling                                       │    │
│  │  • CORS configuration                                   │    │
│  │  • Rate limiting                                        │    │
│  └───┬────────────────────────────────────────────────────┘    │
│      │                                                           │
│      │ Uses                                                      │
│      │                                                           │
│  ┌───▼─────────────────────────────────────────────────────┐   │
│  │        assistant-service.js (OpenAI Integration)         │   │
│  │  • OpenAI client configuration                           │   │
│  │  • Assistant creation                                    │   │
│  │  • Thread management (create, list, delete)              │   │
│  │  • File upload to OpenAI                                 │   │
│  │  • Run management (create, poll, retrieve)               │   │
│  │  • Vector store integration                              │   │
│  │  • Message handling                                      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  API Endpoints:                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  GET  /health                                           │    │
│  │  POST /api/upload-pdf                                   │    │
│  │  POST /api/analyze-quiz                                 │    │
│  │  GET  /api/thread/:threadId                             │    │
│  │  DELETE /api/thread/:threadId                           │    │
│  │  GET  /api/threads                                      │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
│  Middleware:                                                     │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  • express.json() - Body parsing                        │    │
│  │  • cors() - Cross-origin requests                       │    │
│  │  • express-rate-limit - Rate limiting                   │    │
│  │  • Custom error handler                                 │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

External Dependencies:
  → openai (OpenAI SDK)
  → express (HTTP server)
  → pdf-parse (PDF text extraction)
  → axios (HTTP client for Stats app)
```

---

## Data Flow Diagrams

### PDF Upload Flow

```
┌────────┐
│  User  │ Press Cmd+Option+L
└───┬────┘
    │
    ▼
┌─────────────────────────┐
│ KeyboardShortcutManager │
│ Captures keyboard event │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────────┐
│ QuizIntegrationManager      │
│ onOpenPDFPicker()           │
│ Opens NSOpenPanel           │
└───────────┬─────────────────┘
            │
            ▼ User selects file
┌─────────────────────────────┐
│ handlePDFSelection(url)     │
│ 1. Extract PDF path         │
│ 2. Call VisionAIService     │
└───────────┬─────────────────┘
            │
            ▼
┌─────────────────────────────┐
│ VisionAIService             │
│ uploadPDFForContext(path)   │
└───────────┬─────────────────┘
            │
            ▼ HTTP POST /api/upload-pdf
┌─────────────────────────────┐
│ Backend Server              │
│ assistant-service.js        │
│ uploadPDF(req, res)         │
└───────────┬─────────────────┘
            │
            ├─► 1. Read PDF file
            ├─► 2. Extract text
            ├─► 3. Create Assistant
            │       with retrieval tool
            ├─► 4. Create Thread
            ├─► 5. Upload file to
            │       OpenAI
            └─► 6. Store thread ID
                    │
                    ▼
            ┌─────────────────┐
            │  OpenAI API     │
            │  • File upload  │
            │  • Vector store │
            │  • Indexing     │
            └─────────┬───────┘
                      │
                      ▼ Success
            ┌─────────────────┐
            │ Response:       │
            │ {               │
            │   threadId,     │
            │   fileId,       │
            │   assistantId   │
            │ }               │
            └─────────┬───────┘
                      │
                      ▼
            ┌─────────────────┐
            │ Stats App       │
            │ Caches thread   │
            │ Shows success   │
            └─────────────────┘
```

### Screenshot Capture Flow

```
┌────────┐
│  User  │ Press Cmd+Option+O
└───┬────┘
    │
    ▼
┌─────────────────────────┐
│ KeyboardShortcutManager │
│ Captures keyboard event │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────────┐
│ QuizIntegrationManager      │
│ onCaptureScreenshot()       │
└───────────┬─────────────────┘
            │
            ▼
┌─────────────────────────────┐
│ ChromeCDPCapture            │
│ captureScreenshot()         │
└───────────┬─────────────────┘
            │
            ▼ HTTP POST /capture-active-tab
┌─────────────────────────────┐
│ CDP Service (port 9223)     │
│ index.ts                    │
└───────────┬─────────────────┘
            │
            ├─► 1. Get active tab
            ├─► 2. Create CDP client
            └─► 3. Page.captureScreenshot()
                    │
                    ▼ WebSocket CDP (port 9222)
            ┌─────────────────┐
            │  Chrome Browser │
            │  • Renders page │
            │  • Captures PNG │
            └─────────┬───────┘
                      │
                      ▼ PNG binary
            ┌─────────────────┐
            │ CDP Service     │
            │ • Encode base64 │
            │ • Add metadata  │
            └─────────┬───────┘
                      │
                      ▼ JSON Response
            ┌─────────────────┐
            │ {               │
            │   success,      │
            │   base64Image,  │
            │   url,          │
            │   dimensions    │
            │ }               │
            └─────────┬───────┘
                      │
                      ▼
            ┌─────────────────┐
            │ ChromeCDPCapture│
            │ • Decode base64 │
            │ • Store in mem  │
            └─────────┬───────┘
                      │
                      ▼
            ┌─────────────────┐
            │ Stats App       │
            │ Screenshot ready│
            │ Shows success   │
            └─────────────────┘
```

### Quiz Processing Flow

```
┌────────┐
│  User  │ Press Cmd+Option+P
└───┬────┘
    │
    ▼
┌─────────────────────────┐
│ KeyboardShortcutManager │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────────┐
│ QuizIntegrationManager      │
│ onProcessQuiz()             │
│ 1. Check screenshot exists  │
│ 2. Check PDF uploaded       │
└───────────┬─────────────────┘
            │
            ▼
┌─────────────────────────────┐
│ VisionAIService             │
│ extractQuizQuestions(img)   │
└───────────┬─────────────────┘
            │
            ▼ HTTP POST /api/analyze-quiz
┌─────────────────────────────┐
│ Backend Server              │
│ assistant-service.js        │
│ analyzeQuiz(req, res)       │
└───────────┬─────────────────┘
            │
            ├─► 1. Get thread ID
            ├─► 2. Add screenshot
            │       to message
            ├─► 3. Create Run with
            │       retrieval tool
            └─► 4. Poll until complete
                    │
                    ▼ HTTPS
            ┌─────────────────┐
            │  OpenAI API     │
            │  • Vision model │
            │  • Read PDF     │
            │  • Analyze      │
            └─────────┬───────┘
                      │
                      ▼ Reasoning
            ┌─────────────────────────┐
            │ 1. Extract questions    │
            │    from screenshot      │
            │ 2. Search PDF context   │
            │    using retrieval tool │
            │ 3. Match answers with   │
            │    course material      │
            │ 4. Return answer indices│
            └─────────┬───────────────┘
                      │
                      ▼ Response: [3, 2, 4, 1, 5]
            ┌─────────────────┐
            │ Backend Server  │
            │ Extract answers │
            └─────────┬───────┘
                      │
                      ├─► HTTP POST http://localhost:8080/display-answers
                      │   Body: {"answers": [3,2,4,1,5]}
                      │
                      ▼
            ┌─────────────────┐
            │ Stats App       │
            │ QuizHTTPServer  │
            │ (port 8080)     │
            └─────────┬───────┘
                      │
                      ▼
            ┌─────────────────────────┐
            │ QuizAnimationController │
            │ startAnimation(answers) │
            └─────────┬───────────────┘
                      │
                      ▼ State Machine
            ┌─────────────────────────┐
            │ Animation Loop:         │
            │ For each answer:        │
            │   0 → 3 (1.5s)         │
            │   Display 3 (10s)       │
            │   3 → 0 (1.5s)         │
            │   Rest at 0 (15s)       │
            │ Final:                  │
            │   0 → 10 (1.5s)        │
            │   Display 10 (15s)      │
            │   Return to 0           │
            └─────────┬───────────────┘
                      │
                      ▼
            ┌─────────────────┐
            │ GPU Widget      │
            │ Menu Bar        │
            │ User sees nums  │
            └─────────────────┘
```

---

## Sequence Diagrams

### Complete End-to-End Sequence

```
User  KbdMgr  QIM   CDP   Backend  OpenAI  Stats
 |      |     |     |       |        |      |
 │      │     │     │       │        │      │
 ├─Cmd+Option+L────►│       │        │      │
 │      │     │     │       │        │      │
 │      │     ├─openPDFPicker()      │      │
 │      │     │     │       │        │      │
 │◄────┤Select PDF│ │       │        │      │
 │      │     │     │       │        │      │
 │      │     ├─────┼─POST /api/upload-pdf─►│
 │      │     │     │       │        │      │
 │      │     │     │       ├─Create Assistant+Thread─►
 │      │     │     │       │        │      │
 │      │     │     │       │◄──threadId────┤
 │      │     │     │       │        │      │
 │      │     │◄────┼───Success msg──┤      │
 │◄────┤"PDF uploaded"     │        │      │
 │      │     │     │       │        │      │
 ├─Cmd+Option+O────►│       │        │      │
 │      │     │     │       │        │      │
 │      │     ├─────┼─POST /capture-active-tab
 │      │     │     │       │        │      │
 │      │     │     ├─CDP.Page.captureScreenshot()
 │      │     │     │       │        │      │
 │      │     │     │◄─PNG (base64)──┤      │
 │      │     │     │       │        │      │
 │      │     │◄────┤       │        │      │
 │◄────┤"Screenshot captured" │      │      │
 │      │     │     │       │        │      │
 ├─Cmd+Option+P────►│       │        │      │
 │      │     │     │       │        │      │
 │      │     ├─────┼───────┼POST /api/analyze-quiz─►
 │      │     │     │       │        │      │
 │      │     │     │       ├─Run Assistant with─────►
 │      │     │     │       │  screenshot+retrieval   │
 │      │     │     │       │        │      │
 │      │     │     │       │◄──answers: [3,2,4,1,5]─┤
 │      │     │     │       │        │      │
 │      │     │     │       ├─POST :8080/display-answers
 │      │     │     │       │        │      │
 │      │     │◄────┼───────┼────────┼──────┤
 │      │     │     │       │        │      │
 │      │     ├─startAnimation([3,2,4,1,5])─►
 │      │     │     │       │        │      │
 │◄────┤Widget: 0→3→0→2→0→4→0→1→0→5→0→10→0  │
 │      │     │     │       │        │      │
```

---

## Deployment Architecture

### Development Deployment

```
┌─────────────────────────────────────────────────────────────┐
│                    Developer Machine (macOS)                 │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Terminal 1: CDP Service                             │    │
│  │ cd chrome-cdp-service && npm start                  │    │
│  │ Port 9223 (HTTP API)                                │    │
│  │ Port 9222 (Chrome Debug)                            │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Terminal 2: Backend Server                          │    │
│  │ cd backend && npm start                             │    │
│  │ Port 3000 (HTTP API)                                │    │
│  │ .env file with OPENAI_API_KEY                       │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Terminal 3: Stats App                               │    │
│  │ cd cloned-stats && ./run-swift.sh                   │    │
│  │ Port 8080 (HTTP Server)                             │    │
│  │ Menu bar icon visible                               │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Chrome Browser (user instance)                      │    │
│  │ --remote-debugging-port=9222                        │    │
│  │ Quiz pages open                                     │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  Network: localhost only (127.0.0.1)                        │
│  No external access required (except OpenAI API)            │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                               │
                               │ HTTPS
                               ▼
                    ┌──────────────────────┐
                    │   OpenAI API         │
                    │   api.openai.com     │
                    │   Port 443 (HTTPS)   │
                    └──────────────────────┘
```

### Production Deployment (Single User)

```
┌─────────────────────────────────────────────────────────────┐
│                    Production Machine (macOS)                │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │ launchd daemon: CDP Service                         │    │
│  │ Auto-start on login                                 │    │
│  │ Restart on crash                                    │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │ launchd daemon: Backend Server                      │    │
│  │ Auto-start on login                                 │    │
│  │ Environment: /etc/quiz-system/.env                  │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Login Item: Stats.app                               │    │
│  │ Code-signed                                         │    │
│  │ Notarized                                           │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  Security:                                                   │
│  • Firewall enabled (block all incoming)                    │
│  • Services bound to localhost only                         │
│  • OpenAI API key in secure environment                     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Network Topology

### Port Allocation

```
                    ┌──────────────────┐
                    │   localhost      │
                    │   127.0.0.1      │
                    └────────┬─────────┘
                             │
           ┌─────────────────┼─────────────────┐
           │                 │                 │
      ┌────▼────┐       ┌────▼────┐      ┌────▼────┐
      │ :9223   │       │ :3000   │      │ :8080   │
      │ CDP     │       │ Backend │      │ Stats   │
      │ Service │       │ Server  │      │ App     │
      └────┬────┘       └────┬────┘      └─────────┘
           │                 │
           │ Manages         │ Sends to
           │                 │
      ┌────▼────┐       ┌────▼─────────┐
      │ :9222   │       │ :443 HTTPS   │
      │ Chrome  │       │ api.openai   │
      │ Debug   │       │ .com         │
      └─────────┘       └──────────────┘

Legend:
  :XXXX  = TCP port number
  ───    = Direct communication
  127.0.0.1 = Localhost (no external network)
```

### Request Flow by Port

```
User Input
    │
    ▼
┌─────────────┐
│ Stats App   │
│ :8080       │
└──────┬──────┘
       │
       ├────► CDP Service (:9223)
       │      └─► Chrome (:9222)
       │
       └────► Backend (:3000)
              └─► OpenAI (:443)
                  ▲
                  │
                  └─ HTTPS to Internet
```

---

## Security Architecture

### Trust Boundaries

```
┌──────────────────────────────────────────────────────────┐
│                 Trusted Zone (localhost)                  │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐            │
│  │ Stats    │   │   CDP    │   │ Backend  │            │
│  │ App      │◄─►│ Service  │   │ Server   │            │
│  └──────────┘   └──────────┘   └────┬─────┘            │
│       ▲                              │                   │
│       │                              │                   │
│       └──────────────────────────────┘                   │
│                  Localhost only                          │
│              No firewall traversal                       │
│                                                           │
└─────────────────────────────────┬─────────────────────────┘
                                  │
                                  │ HTTPS (TLS 1.3)
                                  │ API Key Authentication
                                  │
┌─────────────────────────────────▼─────────────────────────┐
│               Untrusted Zone (Internet)                    │
├──────────────────────────────────────────────────────────┤
│                                                           │
│                   ┌──────────────┐                       │
│                   │   OpenAI     │                       │
│                   │   API        │                       │
│                   │ api.openai   │                       │
│                   │ .com:443     │                       │
│                   └──────────────┘                       │
│                                                           │
│  Security Controls:                                       │
│  • TLS certificate validation                             │
│  • API key in Authorization header                        │
│  • Rate limiting                                          │
│  • Request/response encryption                            │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

---

## Appendix: Component Dependencies

### Swift Module Dependencies

```
QuizIntegrationManager
    ├── KeyboardShortcutManager
    │   └── CoreGraphics (CGEvent)
    │   └── ApplicationServices
    ├── ChromeCDPCapture
    │   └── Foundation (URLSession)
    ├── VisionAIService
    │   ├── AssistantAPIService
    │   │   └── Foundation (URLSession)
    │   └── PDFTextExtractor
    │       └── PDFKit
    ├── QuizAnimationController
    │   ├── Combine (@Published)
    │   └── Foundation (Timer)
    └── QuizHTTPServer
        └── Network (CFSocket)
```

### npm Package Dependencies

**CDP Service**:
```
chrome-remote-interface
express
typescript
ts-node
@types/node
@types/express
```

**Backend**:
```
openai
express
pdf-parse
axios
cors
dotenv
express-rate-limit
```

**Tests**:
```
jest
axios
@types/jest
```

---

**Architecture Diagram Version**: 2.0.0
**Last Updated**: November 13, 2025
**Status**: Production Documentation

---

**END OF ARCHITECTURE DOCUMENTATION**
