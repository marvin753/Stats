# Quick Test Guide: AI Parser Integration

## Step 1: Start AI Parser Service

```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats
npm run ai-parser
```

**Expected Output**:
```
============================================================
AI Parser Service
============================================================
Server running on: http://localhost:3001
Ollama URL: http://localhost:11434
OpenAI configured: No
Fallback enabled: No
AI timeout: 30000ms
============================================================
Endpoints:
  POST http://localhost:3001/parse-dom
  GET  http://localhost:3001/health
============================================================
Ready to parse quiz questions!
============================================================
```

## Step 2: Run Integration Tests

Open a **new terminal** and run:

```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats
node test-scraper-ai-integration.js
```

**Expected Output**:
```
╔══════════════════════════════════════════════════════════════╗
║  Test Results Summary                                        ║
╚══════════════════════════════════════════════════════════════╝

1. AI Parser Health Check: ✅ PASS
2. AI Parser Parsing: ✅ PASS
3. Backend Compatibility: ✅ PASS
4. Scraper Function: ✅ PASS
5. Error Handling: ✅ PASS

══════════════════════════════════════════════════════════════
✅ ALL TESTS PASSED - Integration is working correctly!
══════════════════════════════════════════════════════════════
```

## Step 3: Test with Backend (Optional)

If you want to test the full workflow:

**Terminal 1** - AI Parser:
```bash
npm run ai-parser
```

**Terminal 2** - Backend:
```bash
cd backend
npm start
```

**Terminal 3** - Run tests:
```bash
node test-scraper-ai-integration.js
```

## Step 4: Manual Test with curl

Test AI Parser directly:

```bash
curl -X POST http://localhost:3001/parse-dom \
  -H "Content-Type: application/json" \
  -d '{
    "text": "What is 2+2?\n1\n2\n3\n4"
  }'
```

**Expected Response**:
```json
{
  "questions": [
    {
      "question": "What is 2+2?",
      "answers": ["1", "2", "3", "4"]
    }
  ],
  "source": "codellama",
  "processingTime": 5.14
}
```

## Troubleshooting

### AI Parser not starting?

**Check Ollama is running**:
```bash
curl http://localhost:11434/api/tags
```

If this fails, start Ollama:
```bash
ollama serve
```

### Test fails with "socket hang up"?

**Restart AI Parser**:
```bash
# Kill existing process
pkill -f ai-parser-service

# Start again
npm run ai-parser
```

### Port 3001 already in use?

**Find and kill the process**:
```bash
lsof -i :3001
kill -9 <PID>
```

## Verify Integration Points

### 1. Check scraper sends to correct URL

```bash
grep -n "AI_PARSER_URL" scraper.js
```

Should show: `const AI_PARSER_URL = process.env.AI_PARSER_URL || 'http://localhost:3001';`

### 2. Check correct endpoint

```bash
grep -n "parse-dom" scraper.js
```

Should show: `const response = await axios.post(\`${AI_PARSER_URL}/parse-dom\`, {`

### 3. Test scraper function directly

```bash
node -e "require('./scraper.js').sendToAI('Test question?\nA\nB\nC').then(q => console.log(JSON.stringify(q, null, 2)))"
```

## Quick Status Check

```bash
# Check all services
echo "AI Parser:" && curl -s http://localhost:3001/health | python3 -m json.tool
echo "\nBackend:" && curl -s http://localhost:3000/health | python3 -m json.tool
echo "\nSwift App:" && curl -s http://localhost:8080 -I | head -1
```

## Full System Test

After all services are running, test the complete workflow:

```bash
node scraper.js --url=https://example.com/quiz
```

**Expected Flow**:
1. Scraper extracts DOM text ✅
2. Sends to AI Parser (port 3001) ✅
3. AI Parser processes with CodeLlama ✅
4. Returns questions to scraper ✅
5. Scraper sends to backend (port 3000) ✅
6. Backend analyzes with OpenAI ✅
7. Backend sends answers to Swift app (port 8080) ✅
8. Swift app animates answers ✅

---

**All tests passing = Integration verified ✅**
