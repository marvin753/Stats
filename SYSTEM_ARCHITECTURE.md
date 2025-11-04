# Stats Quiz Automation System - Complete Architecture

## System Overview

```
User triggers keyboard shortcut
           ↓
   Scraper Script (Node.js)
           ↓
  Extracts Q&A from DOM
           ↓
  Sends JSON to Backend API
           ↓
   Backend Server (Express)
           ↓
  Calls OpenAI/ChatGPT API
           ↓
 Receives answer indices [3,2,4,1,...]
           ↓
  Sends to Stats Swift App (WebSocket/HTTP)
           ↓
  Swift animates numbers with logic:
  - Animate 0 → answer_number
  - Stay 7 seconds
  - Animate back to 0
  - Stay 15 seconds
  - Next answer
  - After all: animate to 10, stay 15s, stop
           ↓
      Display complete
```

## Component Breakdown

### 1. **Scraper Script** (Node.js + Playwright)
- **Location**: `/Users/marvinbarsal/Desktop/Universität/Stats/scraper.js`
- **Triggered**: Keyboard shortcut (via system integration)
- **Input**: Current webpage DOM
- **Output**: JSON array of questions and answers
- **Sends to**: Backend API POST `/api/analyze`

### 2. **Backend Server** (Node.js/Express)
- **Location**: `/Users/marvinbarsal/Desktop/Universität/Stats/backend/server.js`
- **Port**: 3000
- **Routes**:
  - `POST /api/analyze` - Receives scraped data
  - `POST /api/get-answers` - Calls OpenAI, returns answer indices
  - `WebSocket /ws` - Pushes results to Swift app
- **Calls**: OpenAI API with system prompt

### 3. **OpenAI/ChatGPT Integration**
- **API Endpoint**: https://api.openai.com/v1/chat/completions
- **Model**: gpt-4 or gpt-3.5-turbo
- **System Prompt**: Force model to return ONLY JSON array of answer indices
- **Input Format**: Question array with answers
- **Output Format**: `[3, 2, 4, 1, ...]`

### 4. **Swift Stats App**
- **File**: `cloned-stats/Stats/View/...` (modify display logic)
- **Communication**: Receives JSON via HTTP POST or WebSocket
- **Animation Logic**:
  1. Loop through each answer number
  2. Animate: 0 → answer_number (smooth animation)
  3. Wait: 7 seconds at target number
  4. Animate back: answer_number → 0
  5. Wait: 15 seconds at 0
  6. Repeat for next answer
  7. After all answers: animate to 10, wait 15s, stop
  8. Reset to 0 and await next trigger

## Communication Flow & JSON Structures

### Step 1: Scraper Output (Q&A Extraction)
```json
POST /api/analyze
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

### Step 2: Backend Sends to OpenAI
```
System Prompt:
"You are a quiz expert. Analyze the questions and answers.
Return ONLY a JSON array with the indices (1-based) of the correct answers.
Format: [answer_index1, answer_index2, ...]
No explanation, no text, just the array."

User Prompt:
[Same JSON as above]
```

### Step 3: OpenAI Response (Expected)
```json
[4, 3, 1, 2, ...]
```

### Step 4: Backend Sends to Swift App
```json
POST http://localhost:8080/display-answers
{
  "answers": [4, 3, 1, 2, ...],
  "status": "success"
}
```

## File Structure
```
Stats/
├── SYSTEM_ARCHITECTURE.md (this file)
├── scraper.js (Node.js Playwright scraper)
├── backend/
│   ├── server.js (Express server)
│   ├── package.json
│   └── .env (API keys - GITIGNORED)
├── cloned-stats/
│   ├── Stats/
│   │   ├── Modules/
│   │   │   └── Quiz/
│   │   │       ├── QuizViewController.swift (NEW - handles display)
│   │   │       └── QuizAnimationController.swift (NEW - animation logic)
│   │   └── ...existing files...
│   └── ...
└── README_SETUP.md
```

## Environment Variables
```
Backend .env:
OPENAI_API_KEY=sk-proj-[YOUR_NEW_KEY]
OPENAI_MODEL=gpt-3.5-turbo
BACKEND_PORT=3000
STATS_APP_URL=http://localhost:8080
```

## Data Flow Validation Checklist
- [ ] Scraper extracts DOM correctly
- [ ] JSON structure matches API contract
- [ ] OpenAI integration returns valid answer indices
- [ ] Backend forwards to Swift correctly
- [ ] Swift receives and parses JSON
- [ ] Animation executes exact timing
- [ ] Loop logic correct (7s display, 15s rest)
- [ ] Final animation to 10 and stop
- [ ] No automatic restart
- [ ] Awaits next trigger
