# Wave 2C Quick Start Guide
## Get Started with Large PDF Processing in 5 Minutes

---

## Prerequisites

- ✅ Backend running: `cd backend && npm start`
- ✅ OpenAI API key in `.env`
- ✅ Test PDF file (any size, preferably 10+ pages)

---

## Step 1: Verify Backend (30 seconds)

```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/backend

# Start backend
npm start

# In another terminal, test health
curl http://localhost:3000/health
```

Expected response:
```json
{
  "status": "ok",
  "openai_configured": true
}
```

---

## Step 2: Test PDF Upload (2 minutes)

```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/backend

# Run test with your PDF
node test-assistant-api.js --pdf /path/to/your/test.pdf
```

**What happens**:
1. ✅ Uploads PDF to OpenAI
2. ✅ Creates Assistant with file search
3. ✅ Creates thread with PDF context
4. ✅ Runs mock quiz analysis
5. ✅ Shows thread info

**Expected output**:
```
🧪 OpenAI Assistant API Integration Tests
==========================================

=== TEST 0: Health Check ===
✅ Backend is healthy

=== TEST 1: PDF Upload ===
📄 PDF: test.pdf (12.34 MB)
✅ Upload successful in 15.2s
   Thread ID: thread_abc123
   Assistant ID: asst_xyz789

=== TEST 2: Quiz Analysis ===
✅ Analysis successful in 45.3s
   Answers extracted: 20

✅ All tests completed

📊 Summary:
   Save to .env: ASSISTANT_ID=asst_xyz789
```

---

## Step 3: Save Assistant ID (1 minute)

Copy the `ASSISTANT_ID` from the test output and add it to `.env`:

```bash
# Edit .env
nano /Users/marvinbarsal/Desktop/Universität/Stats/backend/.env

# Add this line:
ASSISTANT_ID=asst_xyz789  # Use the actual ID from test output
```

**Why?** Reusing the same assistant saves time on future runs.

---

## Step 4: Test from Swift (Optional)

Open Xcode and test the Swift integration:

```swift
import Foundation

// Test in your app or playground
let service = AssistantAPIService.shared

Task {
    do {
        // Upload PDF
        let thread = try await service.uploadPDF("/path/to/test.pdf")
        print("✅ Thread created: \(thread.threadId)")

        // Get thread info
        if let info = service.getActiveThreadInfo() {
            print("📄 Active thread: \(info.threadId)")
            print("   PDF: \(info.pdfPath)")
        }

    } catch {
        print("❌ Error: \(error)")
    }
}
```

---

## Step 5: Cleanup (30 seconds)

```bash
# List active threads
curl http://localhost:3000/api/threads

# Delete specific thread
curl -X DELETE http://localhost:3000/api/thread/thread_abc123
```

Or run cleanup test:
```bash
CLEANUP=true node test-assistant-api.js --pdf /path/to/test.pdf
```

---

## Quick Test with Real Quiz Screenshot

1. **Upload PDF**:
   ```bash
   node test-assistant-api.js --pdf /path/to/script.pdf
   ```

2. **Take quiz screenshot** and save as PNG

3. **Analyze quiz**:
   ```bash
   node test-assistant-api.js \
     --pdf /path/to/script.pdf \
     --screenshot /path/to/quiz.png
   ```

4. **Expected result**: 20 answers (14 multiple-choice + 6 written)

---

## Troubleshooting

### "Cannot connect to backend"
```bash
# Start backend first
cd backend && npm start
```

### "PDF file not found"
```bash
# Use absolute path
node test-assistant-api.js --pdf /Users/you/Documents/test.pdf
```

### "OpenAI API error"
```bash
# Check API key in .env
cat backend/.env | grep OPENAI_API_KEY

# Verify key is valid at: https://platform.openai.com/account/api-keys
```

### "Assistant run timeout"
- Normal for large PDFs (140+ pages)
- Timeout is 3 minutes - should be enough
- If fails, try smaller PDF first

---

## Next Steps

1. **Read full guide**: `WAVE_2C_IMPLEMENTATION_GUIDE.md`
2. **Integrate with app**: Add PDF upload UI
3. **Test with real quizzes**: 140-page scripts
4. **Monitor costs**: Check OpenAI usage dashboard

---

## Summary

You now have:
- ✅ OpenAI Assistant API configured
- ✅ PDF upload working
- ✅ Thread creation successful
- ✅ Quiz analysis tested
- ✅ Assistant ID cached for reuse

**Total time**: ~5 minutes

**Ready for production**: Yes! 🎉

---

## Support

- Full guide: `WAVE_2C_IMPLEMENTATION_GUIDE.md`
- Main docs: `CLAUDE.md`
- Backend code: `backend/assistant-service.js`
- Swift code: `Stats/Modules/AssistantAPIService.swift`
