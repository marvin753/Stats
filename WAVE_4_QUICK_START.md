# Wave 4 Quick Start Guide

**Version**: 2.1.0
**Status**: ✅ Production Ready

---

## Quick Setup (5 Minutes)

### 1. Start Backend

```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/backend
npm start
```

Expected output:
```
✅ Backend server running on http://localhost:3000
   OpenAI Model: gpt-4-turbo-preview
```

### 2. Build Swift App

```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats
./build-swift.sh
```

### 3. Run Swift App

```bash
./run-swift.sh
```

---

## Using the System

### Step 1: Upload PDF Script (One-Time Setup)

**Keyboard**: `Cmd+Option+L`

1. Press `Cmd+Option+L`
2. Select your PDF script file (e.g., `Stats_Script_140_pages.pdf`)
3. Wait for notification: "PDF Loaded - Ready to analyze quizzes"
4. Backend creates Assistant thread and uploads PDF to OpenAI

**What Happens**:
- PDF is uploaded to OpenAI Assistant API
- Vector store is created for file search
- Thread ID is cached (persists across quiz sessions)

---

### Step 2: Capture Quiz Screenshot

**Keyboard**: `Cmd+Option+O`

1. Open quiz in Chrome browser
2. Press `Cmd+Option+O` to capture screenshot
3. Console shows: "Screenshot 1 captured successfully via CDP"

**Repeat** for multiple quiz pages if needed (up to 10 screenshots)

---

### Step 3: Process Quiz & Animate

**Keyboard**: `Cmd+Option+P`

1. Press `Cmd+Option+P` to process screenshots
2. System validates PDF is uploaded
3. Sends screenshots to Assistant API
4. Receives answers (Q1-14: multiple-choice, Q15-20: written)
5. Animates correct answers in GPU widget

**Expected Console Output**:
```
📸 Processing 1 screenshot(s) with Assistant API...
📤 Sending screenshot to Assistant API...
✅ Received 20 answers from Assistant API
📊 Question breakdown:
   Multiple-choice: 14
   Written: 6
   Total: 20
🎬 Animation started with 20 answers
```

---

## Keyboard Shortcuts Summary

| Shortcut | Action |
|----------|--------|
| `Cmd+Option+L` | Upload PDF reference script |
| `Cmd+Option+O` | Capture quiz screenshot (CDP) |
| `Cmd+Option+P` | Process quiz and animate answers |
| `Cmd+Option+0-5` | Set expected question count (optional) |

---

## Testing the Integration

### Backend Test

```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/backend

# Run integration test
node test-integration.js /path/to/test.pdf /path/to/quiz-screenshot.png
```

**Expected Output**:
```
✅ All integration tests passed!

Summary:
  ✅ Health check passed
  ✅ PDF upload and thread creation
  ✅ Thread listing and info retrieval
  ✅ Quiz analysis with Assistant API
  ✅ Thread cleanup
```

### Swift App Test

1. Start backend: `npm start`
2. Start Swift app: `./run-swift.sh`
3. Press `Cmd+Option+L` → Select PDF
4. Press `Cmd+Option+O` → Capture quiz
5. Press `Cmd+Option+P` → Process

**Expected GPU Widget Animation**:
```
0 → answer₁ (1.5s) → display (10s) → 0 (1.5s) → rest (15s)
0 → answer₂ (1.5s) → display (10s) → 0 (1.5s) → rest (15s)
...
0 → 10 (1.5s) → display (15s) → STOP
```

---

## Troubleshooting

### "No PDF uploaded" Error

**Solution**: Press `Cmd+Option+L` first to upload PDF

### "PDF upload failed" Error

**Check**:
1. Backend is running: `curl http://localhost:3000/health`
2. OpenAI API key is set: `cat backend/.env | grep OPENAI_API_KEY`
3. PDF file exists and is valid

### "Analysis failed" Error

**Possible causes**:
- Thread expired (24+ hours old) → Re-upload PDF
- OpenAI rate limit → Wait and retry
- Invalid screenshot → Recapture quiz

**Solution**: Re-upload PDF with `Cmd+Option+L`

---

## API Endpoints (Backend)

### Upload PDF
```http
POST http://localhost:3000/api/upload-pdf
Content-Type: application/json

{
  "pdfPath": "/path/to/script.pdf"
}
```

**Response**:
```json
{
  "threadId": "thread_abc123",
  "assistantId": "asst_xyz789",
  "fileId": "file_...",
  "vectorStoreId": "vs_...",
  "fileSizeMB": "15.23",
  "createdAt": "2025-11-13T10:30:00Z"
}
```

### Analyze Quiz
```http
POST http://localhost:3000/api/analyze-quiz
Content-Type: application/json

{
  "threadId": "thread_abc123",
  "screenshotBase64": "iVBORw0KGgoAAAANSUhEUgAA..."
}
```

**Response**:
```json
{
  "answers": [
    {
      "questionNumber": 1,
      "type": "multiple-choice",
      "question": "What is...?",
      "options": ["A", "B", "C", "D"],
      "correctAnswer": 3
    },
    {
      "questionNumber": 15,
      "type": "written",
      "question": "Explain...",
      "answerText": "Detailed answer based on PDF..."
    }
  ],
  "threadId": "thread_abc123",
  "timestamp": "2025-11-13T10:32:00Z"
}
```

### List Threads
```http
GET http://localhost:3000/api/threads
```

### Delete Thread
```http
DELETE http://localhost:3000/api/thread/thread_abc123
```

---

## Configuration

### Backend (.env)

```env
OPENAI_API_KEY=sk-proj-YOUR_KEY_HERE
OPENAI_MODEL=gpt-4-turbo-preview
ASSISTANT_ID=asst_... (auto-generated)
BACKEND_PORT=3000
```

### Swift App (UserDefaults)

The app automatically caches:
- `activeThreadId` - Current thread
- `activePDFPath` - PDF file path
- `threadCreatedAt` - Upload timestamp

---

## Performance Metrics

| Metric | Expected Time |
|--------|---------------|
| PDF Upload (140 pages) | 20-40 seconds |
| Thread Creation | 5-10 seconds |
| Quiz Analysis (20 questions) | 30-90 seconds |
| Screenshot Capture | < 1 second |
| Animation Duration | ~5 minutes (20 questions) |

---

## Best Practices

1. **Upload PDF once** per quiz session (persists across multiple quizzes)
2. **Capture all screenshots** before processing
3. **Wait for notifications** before next step
4. **Monitor backend logs** for debugging

---

## Support

- **System Docs**: `/Users/marvinbarsal/Desktop/Universität/Stats/CLAUDE.md`
- **Wave 4 Details**: `/Users/marvinbarsal/Desktop/Universität/Stats/WAVE_4_COMPLETION_SUMMARY.md`
- **Backend Logs**: Check terminal running `npm start`
- **Swift Logs**: Check terminal running `./run-swift.sh`

---

**Ready to analyze quizzes with PDF context!** 🎉
