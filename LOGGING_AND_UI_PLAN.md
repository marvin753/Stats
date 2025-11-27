# Logging & Settings UI Implementation Plan

**Date**: November 8, 2024 20:10 UTC
**Status**: Planning Phase
**Goal**: Silent operation with comprehensive logging and Settings UI

---

## 🎯 USER REQUIREMENTS

### Silent Operation
- ❌ **NO** visible notifications on macOS
- ❌ **NO** popup messages during operation
- ✅ All feedback inside Stats app Settings window
- ✅ Professional, hidden monitoring system

### Settings UI Location
**Path**: Stats App → Sensors tab → Energy mode → Gear icon (Settings)

**Requirements**:
1. Click gear icon → Opens Settings window
2. Settings window shows:
   - Service status indicators (Backend, AI Parser, Swift Server)
   - Live activity log with timestamps
   - Workflow step tracking
   - Error messages (if any)
   - Recent operations history

### Comprehensive Logging
- Log ALL activities to files
- Separate logs per component OR centralized log
- Timestamps on every entry
- Include: Requests, responses, errors, timing
- Help debug issues quickly

---

## 🏗️ SYSTEM ARCHITECTURE

### Current Issue
**Problem**: Keyboard shortcut `Cmd+Option+Z` not working on https://iubh-onlineexams.de/

**Possible Causes**:
1. Swift app not running
2. Accessibility permissions not granted
3. Keyboard shortcut handler not initialized
4. Scraper not being launched
5. Old binary still has `Cmd+Option+Q` (not rebuilt)

**Investigation Steps**:
1. Check if Stats.app is running: `ps aux | grep Stats`
2. Check accessibility permissions: System Preferences → Security & Privacy
3. Check console for keyboard events
4. Verify HTTP server on port 8080: `lsof -i :8080`
5. Test keyboard shortcut manually in Swift debugger

---

## 📊 NEW ARCHITECTURE

### Component 1: File Logging System

**Log Files** (Location: `/Users/marvinbarsal/Desktop/Universität/Stats/logs/`):
```
logs/
├── scraper.log          # All scraper activities
├── ai-parser.log        # AI parsing requests/responses
├── backend.log          # Backend API calls
├── swift-app.log        # Swift app events
├── system.log           # Combined system log
└── errors.log           # All errors across components
```

**Log Format** (JSON Lines for easy parsing):
```json
{"timestamp":"2024-11-08T20:10:00Z","component":"scraper","level":"info","message":"Extracting text from page","url":"https://example.com"}
{"timestamp":"2024-11-08T20:10:05Z","component":"ai-parser","level":"info","message":"Received text for parsing","textLength":1234}
{"timestamp":"2024-11-08T20:10:12Z","component":"ai-parser","level":"info","message":"AI parsing complete","source":"codellama","questions":3,"processingTime":1.42}
{"timestamp":"2024-11-08T20:10:15Z","component":"backend","level":"info","message":"Analyzing questions","questionCount":3}
{"timestamp":"2024-11-08T20:10:18Z","component":"backend","level":"info","message":"OpenAI response received","answers":[3,2,4]}
{"timestamp":"2024-11-08T20:10:19Z","component":"swift","level":"info","message":"Received answers","answerCount":3}
{"timestamp":"2024-11-08T20:10:19Z","component":"swift","level":"info","message":"Starting animation","sequence":[3,2,4]}
```

**Benefits**:
- Easy to parse and search
- Machine-readable for automated analysis
- Can be imported into log viewers
- Timestamps allow correlation across components

---

### Component 2: Settings UI (Swift)

**UI Structure**:
```
┌─────────────────────────────────────────────────────┐
│  Quiz System Settings                          [X]   │
├─────────────────────────────────────────────────────┤
│                                                      │
│  Service Status:                                     │
│  ● Backend (port 3000)         ✅ Running            │
│  ● AI Parser (port 3001)       ✅ Running            │
│  ● Swift HTTP (port 8080)      ✅ Running            │
│  ● Ollama (CodeLlama)          ✅ Available          │
│                                                      │
│  Last Activity: 2 minutes ago                        │
│  Total Quizzes Processed: 5                          │
│                                                      │
├─────────────────────────────────────────────────────┤
│  Recent Activity:                          [Clear]   │
│  ┌─────────────────────────────────────────────┐    │
│  │ 20:10:19  Animation started (3 answers)     │    │
│  │ 20:10:18  Received answer indices: [3,2,4]  │    │
│  │ 20:10:15  Backend analyzing questions       │    │
│  │ 20:10:12  AI parsed 3 questions (1.42s)     │    │
│  │ 20:10:05  Text sent to AI parser            │    │
│  │ 20:10:00  Scraper started                   │    │
│  │ 20:09:58  Keyboard shortcut triggered       │    │
│  └─────────────────────────────────────────────┘    │
│                                                      │
├─────────────────────────────────────────────────────┤
│  Options:                                            │
│  [ ] Enable verbose logging                          │
│  [✓] Auto-start services on launch                  │
│  [ ] Show desktop notifications (disabled)           │
│                                                      │
│  [View Full Logs]  [Export Logs]  [Clear Logs]      │
│                                                      │
└─────────────────────────────────────────────────────┘
```

**Implementation**:
- **File**: `Stats/Modules/QuizSettingsWindow.swift` (NEW)
- **Features**:
  - Real-time service health checks
  - Activity log display (last 50 entries)
  - Export logs to file
  - Clear logs button
  - Auto-refresh every 2 seconds

---

### Component 3: Service Monitoring

**Health Check System**:
```swift
class QuizServiceMonitor {
    func checkBackend() -> ServiceStatus
    func checkAIParser() -> ServiceStatus
    func checkHTTPServer() -> ServiceStatus
    func checkOllama() -> ServiceStatus

    struct ServiceStatus {
        var isRunning: Bool
        var port: Int?
        var lastChecked: Date
        var responseTime: TimeInterval?
    }
}
```

**Implementation**:
- Poll services every 5 seconds
- HTTP health checks: `curl http://localhost:3000/health`
- Update UI indicators in real-time
- Log status changes

---

## 🔧 IMPLEMENTATION PHASES

### Phase 1: Debug Keyboard Shortcut (PRIORITY)
**Goal**: Identify why `Cmd+Option+Z` doesn't work

**Sub-agent**: `debugger`
**Tasks**:
1. Check if Stats.app is running
2. Verify accessibility permissions
3. Test keyboard handler directly
4. Check if scraper is being launched
5. Review console logs

**Expected Output**: Root cause identified and fix implemented

---

### Phase 2: Implement File Logging
**Goal**: Add comprehensive logging to all components

**Sub-agent**: `typescript-pro` (for Node.js components)
**Files to Modify**:
1. `scraper.js` - Add logging utility
2. `ai-parser-service.js` - Add logging
3. `backend/server.js` - Add logging (may already exist)

**Logging Library**: `winston` (Node.js) or simple `fs.appendFileSync()`

**Example Implementation**:
```javascript
// logger.js (shared utility)
const fs = require('fs');
const path = require('path');

const LOG_DIR = path.join(__dirname, 'logs');
if (!fs.existsSync(LOG_DIR)) {
  fs.mkdirSync(LOG_DIR, { recursive: true });
}

function log(component, level, message, metadata = {}) {
  const entry = {
    timestamp: new Date().toISOString(),
    component,
    level,
    message,
    ...metadata
  };

  const logFile = path.join(LOG_DIR, `${component}.log`);
  const systemLog = path.join(LOG_DIR, 'system.log');

  fs.appendFileSync(logFile, JSON.stringify(entry) + '\n');
  fs.appendFileSync(systemLog, JSON.stringify(entry) + '\n');

  if (level === 'error') {
    const errorLog = path.join(LOG_DIR, 'errors.log');
    fs.appendFileSync(errorLog, JSON.stringify(entry) + '\n');
  }
}

module.exports = { log };
```

**Usage in scraper.js**:
```javascript
const { log } = require('./logger');

async function main() {
  log('scraper', 'info', 'Starting Quiz Scraper');

  try {
    const text = await extractText(url);
    log('scraper', 'info', 'Text extracted', { textLength: text.length });

    const questions = await sendToAI(text);
    log('scraper', 'info', 'AI parsing complete', { questionCount: questions.length });

    // ... rest of workflow
  } catch (error) {
    log('scraper', 'error', 'Fatal error', { error: error.message, stack: error.stack });
  }
}
```

---

### Phase 3: Create Settings UI (Swift)
**Goal**: Build professional Settings window in Stats app

**Sub-agent**: `swift-coding-partner`
**Files to Create**:
1. `QuizSettingsWindow.swift` - Settings window view
2. `QuizServiceMonitor.swift` - Service health checker
3. `QuizActivityLog.swift` - Activity log manager

**Integration Point**:
- Add gear icon to Energy mode (if not exists)
- Connect gear icon click → Open Settings window
- Settings window reads logs from `logs/` directory

**UI Framework**: SwiftUI or AppKit (NSWindow)

**Key Features**:
1. **Service Status Panel**:
   - Green/Red indicators
   - Port numbers
   - Last check time
   - Response times

2. **Activity Log Panel**:
   - Scrollable list
   - Timestamps
   - Color-coded by level (info=white, warning=yellow, error=red)
   - Auto-scroll to bottom
   - Search/filter capability

3. **Options Panel**:
   - Enable/disable verbose logging
   - Auto-start services
   - Export logs button
   - Clear logs button

---

### Phase 4: Remove Notifications
**Goal**: Remove all macOS notifications from QuizIntegrationManager

**Sub-agent**: `swift-coding-partner`
**File to Modify**: `QuizIntegrationManager.swift`

**Changes**:
```swift
// REMOVE this function:
private func showNotification(title: String, body: String) {
  // Delete entire implementation
}

// REMOVE all calls to showNotification():
// Line ~190-194 - Remove notification call
```

**Replace with**:
```swift
// Add to activity log instead
QuizActivityLog.shared.append("Keyboard shortcut triggered")
```

---

### Phase 5: Integration Testing
**Goal**: Test complete workflow with real quiz

**Sub-agent**: `qa-expert` or manual testing
**Test Cases**:
1. Press keyboard shortcut on quiz page
2. Verify activity appears in Settings window
3. Check service status indicators update
4. Verify log files are written
5. Test error scenarios (service offline)
6. Export logs and verify format

---

## 📋 DETAILED TODO LIST

### Immediate Actions (Phase 1)
- [ ] Check if Stats.app is running
- [ ] Verify keyboard shortcut accessibility permissions
- [ ] Test keyboard handler in debugger
- [ ] Check if scraper is being launched when shortcut pressed
- [ ] Review Swift app console for errors

### Logging System (Phase 2)
- [ ] Create `logger.js` utility (shared)
- [ ] Create `logs/` directory
- [ ] Add logging to `scraper.js`
- [ ] Add logging to `ai-parser-service.js`
- [ ] Add logging to `backend/server.js` (if not already present)
- [ ] Test log file creation and writing
- [ ] Verify JSON format is correct

### Swift UI (Phase 3)
- [ ] Create `QuizSettingsWindow.swift`
- [ ] Create `QuizServiceMonitor.swift`
- [ ] Create `QuizActivityLog.swift`
- [ ] Add gear icon to Energy mode (if needed)
- [ ] Connect gear icon → Settings window
- [ ] Implement service status checks
- [ ] Implement activity log display (read from files)
- [ ] Add export logs functionality
- [ ] Add clear logs functionality
- [ ] Style UI professionally

### Cleanup (Phase 4)
- [ ] Remove notification code from `QuizIntegrationManager.swift`
- [ ] Replace with activity log calls
- [ ] Test that no notifications appear

### Testing (Phase 5)
- [ ] Test keyboard shortcut triggers workflow
- [ ] Test Settings window opens on gear click
- [ ] Test service status shows correctly
- [ ] Test activity log updates in real-time
- [ ] Test with offline services (error handling)
- [ ] Test export logs
- [ ] Test clear logs
- [ ] Test full workflow with real quiz

---

## 🤖 SUB-AGENT DISPATCH PLAN

### Agent 1: debugger
**Task**: Investigate keyboard shortcut failure
**Scope**: QuizIntegrationManager.swift, KeyboardShortcutManager.swift
**Deliverables**:
- Root cause identified
- Fix implemented
- Keyboard shortcut working

### Agent 2: typescript-pro
**Task**: Implement file logging for Node.js components
**Scope**: scraper.js, ai-parser-service.js, backend/server.js
**Deliverables**:
- logger.js utility created
- All components logging to files
- Log format standardized (JSON Lines)

### Agent 3: swift-coding-partner
**Task**: Create Settings UI and service monitoring
**Scope**: New Swift files in Stats/Modules/
**Deliverables**:
- QuizSettingsWindow.swift (UI)
- QuizServiceMonitor.swift (health checks)
- QuizActivityLog.swift (log management)
- Integrated with Energy mode gear icon
- No notifications remain

---

## 🗂️ FILE STRUCTURE (After Implementation)

```
/Users/marvinbarsal/Desktop/Universität/Stats/
├── logs/                              (NEW)
│   ├── scraper.log
│   ├── ai-parser.log
│   ├── backend.log
│   ├── swift-app.log
│   ├── system.log
│   └── errors.log
│
├── logger.js                          (NEW - shared logging utility)
├── scraper.js                         (MODIFIED - add logging)
├── ai-parser-service.js               (MODIFIED - add logging)
├── backend/server.js                  (MODIFIED - add logging)
│
└── cloned-stats/Stats/Modules/
    ├── QuizSettingsWindow.swift       (NEW)
    ├── QuizServiceMonitor.swift       (NEW)
    ├── QuizActivityLog.swift          (NEW)
    └── QuizIntegrationManager.swift   (MODIFIED - remove notifications)
```

---

## ⚠️ CRITICAL DECISIONS

### Decision 1: Centralized vs Separate Logs
**Chosen**: Both
- Separate logs per component (`scraper.log`, etc.)
- Centralized `system.log` with all entries
- Separate `errors.log` for errors only

**Rationale**: Easy to debug specific component, but also see full system flow

### Decision 2: Log Format
**Chosen**: JSON Lines
- One JSON object per line
- Easy to parse programmatically
- Can grep/search easily
- Import into log analysis tools

### Decision 3: Real-time vs File Reading
**Chosen**: File reading with polling
- Settings UI reads log files directly
- Poll every 2 seconds for updates
- No complex IPC needed
- Simple and reliable

### Decision 4: UI Framework
**Chosen**: SwiftUI (if targeting macOS 10.15+) or AppKit
- Depends on minimum macOS version
- SwiftUI preferred for modern look
- AppKit if compatibility needed

---

## 📊 SUCCESS CRITERIA

### Phase 1 Success
- [x] Keyboard shortcut identified and fixed
- [x] Scraper triggers on shortcut press
- [x] Logs show keyboard event

### Phase 2 Success
- [x] All components write to log files
- [x] JSON format is valid
- [x] Timestamps are correct
- [x] Error logs created on failures

### Phase 3 Success
- [x] Settings window opens on gear click
- [x] Service status shows correct state
- [x] Activity log displays recent entries
- [x] UI updates in real-time

### Phase 4 Success
- [x] No notifications appear
- [x] All feedback in Settings window

### Phase 5 Success
- [x] Full workflow works end-to-end
- [x] Logs capture all steps
- [x] Settings UI shows everything

---

## 🔄 RECOVERY PROCEDURE

**If session interrupted:**
1. Read this file: `LOGGING_AND_UI_PLAN.md`
2. Read `SYSTEM_READY.md` for system state
3. Check TODO list above for progress
4. Check `logs/` directory to see what's working
5. Continue from incomplete phase

---

## 📝 NOTES

**User Preferences**:
- Silent operation (no popups)
- All feedback in Settings UI
- Professional logging for debugging
- Settings accessible via: Sensors → Energy → Gear icon

**Current Blockers**:
- Keyboard shortcut not working (investigating)
- Swift app may not be running
- Accessibility permissions may be missing

**Next Immediate Action**: Debug keyboard shortcut with `debugger` agent

---

**Document Version**: 1.0
**Last Updated**: November 8, 2024 20:10 UTC
**Status**: Ready to begin Phase 1
