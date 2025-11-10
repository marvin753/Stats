# End-to-End Testing with Playwright - Complete Guide

## Overview

This guide covers the comprehensive E2E testing strategy for the Quiz Stats Animation System using Playwright MCP tools and browser automation.

**Status**: Production Ready
**Last Updated**: November 7, 2024
**Test Framework**: Jest + Playwright
**Coverage**: Browser automation, DOM extraction, backend integration, stats app communication

---

## Quick Start

### Prerequisites

- Node.js 18+
- Backend running on port 3000
- Stats app running on port 8080
- Quiz website accessible: http://www.iubh-onlineexams.de/
- Valid login credentials

### Run E2E Tests

```bash
# Navigate to project root
cd /Users/marvinbarsal/Desktop/Universität/Stats

# Run all E2E Playwright tests
npm run test:e2e

# Run with verbose output
npm run test:verbose

# Run with coverage report
npm run test:coverage

# Run tests in watch mode
npm run test:watch
```

---

## Test Architecture

### Test Pyramid

```
┌─────────────────────────────────────────┐
│   E2E Tests (Playwright Browser)        │  ← You are here
│   - Full workflow testing               │
│   - Browser automation                  │
│   - DOM extraction                      │
│   - Visual regression                   │
│   Count: 15-20 tests                    │
└─────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────┐
│   Integration Tests                     │
│   - Backend API                         │
│   - Component interaction                │
│   - Database queries                    │
│   Count: 30-40 tests                    │
└─────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────┐
│   Unit Tests                            │
│   - Individual functions                │
│   - Business logic                      │
│   - Utility functions                   │
│   Count: 100+ tests                     │
└─────────────────────────────────────────┘
```

### Test Organization

```
tests/
├── e2e.playwright.js          ← Main Playwright E2E tests
├── e2e.test.js                ← API integration tests
├── E2E_PLAYWRIGHT_GUIDE.md     ← This file
│
backend/tests/
├── api.test.js                ← Backend endpoint tests
├── integration.test.js         ← Full workflow tests
├── security.test.js            ← Security validation tests
└── health.test.js              ← Health check tests
│
frontend/tests/
├── api-client.test.js          ← Frontend API client tests
├── error-handler.test.js       ← Error handling tests
└── url-validator.test.js       ← URL validation tests
```

---

## Test Scenarios

### Scenario 1: Browser Navigation and Page Loading

**File**: `tests/e2e.playwright.js` - `Browser Launch and Navigation` suite

**Steps**:
1. Launch Chromium browser
2. Navigate to quiz website
3. Verify page loads and DOM is available
4. Capture screenshots for visual verification

**Expected Results**:
- Browser launches successfully
- Page title is loaded
- Page content is > 100 bytes
- HTML elements are accessible

**Timeout**: 30 seconds

**Artifacts**:
- `test-screenshots/01-homepage.png` - Homepage screenshot
- `test-screenshots/05-dashboard.png` - Post-login dashboard

---

### Scenario 2: Login Flow

**File**: `tests/e2e.playwright.js` - `Login Flow` suite

**Steps**:
1. Find email input field (multiple selectors tried)
2. Fill email: `barsalmarvin@gmail.com`
3. Find password input field
4. Fill password: `hyjjuv-rIbke6-wygro&`
5. Find and click submit button
6. Wait for page navigation
7. Verify login success

**Expected Results**:
- Email input field found and filled
- Password field found and filled
- Submit button clicked successfully
- Page redirects to dashboard/quiz list
- Content loaded on new page

**Selectors Used**:
```javascript
Email: input[type="email"], input[name="email"], [placeholder*="email"]
Password: input[type="password"], input[name="password"]
Submit: button[type="submit"], button:has-text("Login"), button:has-text("Anmelden")
```

**Screenshots**:
- `02-email-filled.png` - After email entry
- `03-password-filled.png` - After password entry
- `04-login-result.png` - Login result page
- `05-dashboard.png` - Authenticated dashboard

---

### Scenario 3: Exam Selection

**File**: `tests/e2e.playwright.js` - `Exam/Quiz Selection` suite

**Steps**:
1. Look for exam link/button with text "Probeklausur ohne Proctoring"
2. Try multiple matching strategies:
   - Exact text match: `text="Probeklausur ohne Proctoring"`
   - Partial text match: elements containing "Probeklausur"
   - Keyword match: elements with "probe" or "exam"
3. Click selected exam
4. Wait for quiz page to load
5. Verify quiz page URL has changed

**Expected Results**:
- Exam element found on dashboard
- Exam clicked successfully
- Page navigates to quiz
- Quiz page loads with questions/answers visible

**Screenshots**:
- `06-exam-list.png` - Exam list before selection
- `07-quiz-page.png` - Quiz page after selection

---

### Scenario 4: DOM Extraction

**File**: `tests/e2e.playwright.js` - `DOM Extraction` suite

**Steps**:
1. Extract full HTML content from quiz page
2. Store raw DOM for analysis
3. Identify question elements using selectors
4. Identify answer elements using selectors
5. Extract question and answer text
6. Count total elements extracted

**Expected Results**:
- Full HTML extracted (500+ bytes)
- Question elements identified
- Answer elements identified
- Text content extracted from questions
- Text content extracted from answers

**DOM Selectors Tried**:
```javascript
Questions: .question, .quiz-question, [class*="question"], h3, h4, h5
Answers: .answer, .option, [class*="answer"], label, input[type="radio"]
```

**Stored Data**:
- `report.domContent` - Full HTML of quiz page
- `report.extractedQuestions` - Parsed questions and answers

---

### Scenario 5: Backend Integration

**File**: `tests/e2e.playwright.js` - `Backend Integration` suite

**Steps**:
1. Check backend health endpoint
   ```
   GET http://localhost:3000/health
   ```
2. Send sample questions to backend
   ```
   POST http://localhost:3000/api/analyze
   Body: { questions: [...] }
   ```
3. Verify response contains answer indices
4. Validate response format (status, answers, questionCount)
5. Verify all answers are numeric

**Expected Results**:
- Health check returns status: "ok"
- OpenAI configuration verified
- Analysis request succeeds (200 OK)
- Response contains numeric answer indices
- Question count matches sent questions

**Sample Request**:
```json
POST http://localhost:3000/api/analyze
{
  "questions": [
    {
      "question": "What is 2+2?",
      "answers": ["1", "2", "3", "4"]
    },
    {
      "question": "Capital of France?",
      "answers": ["London", "Paris", "Berlin", "Madrid"]
    }
  ]
}
```

**Expected Response**:
```json
{
  "status": "success",
  "answers": [4, 2],
  "questionCount": 2,
  "message": "Questions analyzed successfully"
}
```

---

### Scenario 6: Stats App Integration

**File**: `tests/e2e.playwright.js` - `Stats App Integration` suite

**Steps**:
1. Check stats app HTTP server is running on port 8080
2. Send test answer data to stats app
   ```
   POST http://localhost:8080/display-answers
   Body: { answers: [3, 2, 4], status: "success" }
   ```
3. Verify stats app receives and responds to request
4. Check for any errors in response

**Expected Results**:
- Stats app server is responsive
- HTTP endpoint accepts POST requests
- Server responds with status code
- No connection errors

**Test Request**:
```json
POST http://localhost:8080/display-answers
{
  "answers": [3, 2, 4],
  "status": "success"
}
```

---

### Scenario 7: Visual Regression Testing

**File**: `tests/e2e.playwright.js` - `E2E Tests - Visual Verification` suite

**Steps**:
1. Navigate to website multiple times
2. Capture screenshots at each step
3. Store screenshots for visual comparison
4. Monitor for unexpected UI changes

**Expected Results**:
- Screenshots captured without errors
- All visual elements render correctly
- Page layout is consistent across runs

**Artifacts**:
- `visual-0.png`, `visual-1.png`, `visual-2.png` - Visual progression

---

## Test Report

All tests generate a comprehensive JSON report with the following structure:

```json
{
  "startTime": "2024-11-07T12:00:00Z",
  "endTime": "2024-11-07T12:05:00Z",
  "duration": 300000,
  "results": {
    "navigation": {
      "passed": true,
      "timestamp": "2024-11-07T12:00:05Z",
      "details": {
        "pageTitle": "IUBH Online Exams",
        "url": "http://www.iubh-onlineexams.de/"
      }
    },
    "login": {
      "passed": true,
      "timestamp": "2024-11-07T12:01:30Z",
      "details": {
        "emailEntered": true,
        "passwordEntered": true,
        "submitted": true,
        "postLoginUrl": "http://www.iubh-onlineexams.de/dashboard"
      }
    },
    "examSelection": {
      "passed": true,
      "timestamp": "2024-11-07T12:02:00Z",
      "details": {
        "examName": "Probeklausur ohne Proctoring",
        "quizPageUrl": "http://www.iubh-onlineexams.de/quiz/123"
      }
    },
    "domExtraction": {
      "passed": true,
      "timestamp": "2024-11-07T12:02:30Z",
      "details": {
        "htmlLength": 45230,
        "questionElementsFound": 5,
        "answerElementsFound": 20
      }
    },
    "backendProcessing": {
      "passed": true,
      "timestamp": "2024-11-07T12:03:00Z",
      "details": {
        "backendRunning": true,
        "analysisSuccessful": true,
        "answersReceived": [4, 2, 3, 1],
        "questionCount": 4
      }
    },
    "statsAppResponse": {
      "passed": true,
      "timestamp": "2024-11-07T12:04:00Z",
      "details": {
        "statsAppRunning": true,
        "testDataSent": true,
        "responseStatus": 200
      }
    },
    "animation": {
      "passed": true,
      "timestamp": "2024-11-07T12:05:00Z",
      "details": {
        "workflowDocumented": true,
        "quizPageUrl": "http://www.iubh-onlineexams.de/quiz/123",
        "testDuration": 300000
      }
    }
  },
  "errors": [
    {
      "test": "examSelection",
      "message": "Element not found after 5000ms",
      "stack": "Error: Element not found...",
      "timestamp": "2024-11-07T12:02:00Z"
    }
  ],
  "screenshots": [
    {
      "test": "navigation",
      "path": "/path/to/test-screenshots/01-homepage.png",
      "timestamp": "2024-11-07T12:00:05Z"
    }
  ],
  "domContent": "<html>...</html>",
  "extractedQuestions": [
    {
      "text": "What is 2+2?",
      "selector": "[object Object]"
    }
  ],
  "backendResponse": {
    "status": "success",
    "answers": [4, 2, 3, 1],
    "questionCount": 4
  },
  "summary": {
    "totalTests": 7,
    "passedTests": 6,
    "failedTests": 1,
    "totalErrors": 1
  }
}
```

**Report Location**: `test-screenshots/e2e-report.json`

---

## Troubleshooting

### Issue: "Target URL is not reachable"

```bash
# Check if website is accessible
curl -I http://www.iubh-onlineexams.de/

# Verify VPN connection if required
networksetup -getairportnetwork

# Check DNS resolution
nslookup www.iubh-onlineexams.de
```

**Solution**:
- Ensure internet connection is active
- Check if VPN is required and connected
- Verify firewall allows connections to external URLs
- Check proxy settings

---

### Issue: "Login credentials rejected"

**Possible Causes**:
- Account is locked
- Password expired
- Account doesn't exist
- Account is suspended

**Solution**:
1. Verify credentials are correct
2. Test login manually in browser
3. Check IUBH account status
4. Reset password if needed
5. Update credentials in test configuration

---

### Issue: "Exam not found in list"

**Possible Causes**:
- Exam name has changed
- Exam not available in current period
- Incorrect exam name in config
- DOM selectors not matching current page structure

**Solution**:
1. Log in manually and verify exam exists
2. Check exact exam name (case-sensitive)
3. Update `CONFIG.examName` in test file
4. Check browser console for JavaScript errors
5. Verify page loaded fully before selecting exam

---

### Issue: "Backend returns 401 Unauthorized"

**Possible Causes**:
- API key missing from environment
- API key is invalid
- CORS origin not allowed

**Solution**:
```bash
# Check backend .env file
cat /Users/marvinbarsal/Desktop/Universität/Stats/backend/.env

# Verify API_KEY is set
echo $API_KEY

# Check backend is running
curl http://localhost:3000/health

# Restart backend
pkill -f "node server.js"
cd /Users/marvinbarsal/Desktop/Universität/Stats/backend && npm start
```

---

### Issue: "Stats app not responding"

**Possible Causes**:
- Stats app not running
- Port 8080 is in use
- HTTP server not started
- Firewall blocking connections

**Solution**:
```bash
# Check if port 8080 is in use
lsof -i :8080

# Kill process if needed
lsof -ti:8080 | xargs kill -9

# Verify Stats app is running
ps aux | grep -i "Stats.app"

# Check Stats app logs
cat /tmp/stats-final.log

# Restart Stats app
# In Xcode: Cmd+B (Build) then Cmd+R (Run)
```

---

### Issue: "Screenshots not being saved"

**Possible Causes**:
- Screenshot directory doesn't exist
- No write permissions
- Playwright not initialized

**Solution**:
```bash
# Create screenshots directory
mkdir -p /Users/marvinbarsal/Desktop/Universität/Stats/test-screenshots

# Check permissions
ls -la /Users/marvinbarsal/Desktop/Universität/Stats/test-screenshots

# Ensure directory is writable
chmod 755 /Users/marvinbarsal/Desktop/Universität/Stats/test-screenshots
```

---

## Best Practices

### 1. Test Independence

Each test should be independent and not rely on results from previous tests:

```javascript
// ✗ Bad - Test depends on previous test
test('should select exam', async () => {
  await page.click('[exam-selector]');
  // Relies on being logged in
});

// ✓ Good - Test is self-contained
test('should select exam when logged in', async () => {
  // Setup: ensure we're logged in
  // Act: select exam
  // Assert: verify selection
});
```

### 2. Explicit Waits

Always wait for elements explicitly, don't rely on arbitrary timeouts:

```javascript
// ✗ Bad - Arbitrary wait
await page.waitForTimeout(5000);
await page.click('[button]');

// ✓ Good - Wait for specific condition
await page.waitForSelector('[button]', { visible: true });
await page.click('[button]');
```

### 3. Multiple Selectors

Try multiple selector strategies for robustness:

```javascript
// ✓ Good - Multiple strategies
const selectors = [
  'input[type="email"]',
  'input[name="email"]',
  '[placeholder*="email"]'
];

for (const selector of selectors) {
  const element = await page.$(selector);
  if (element) {
    // Use this selector
    break;
  }
}
```

### 4. Error Handling

Always handle errors gracefully:

```javascript
try {
  // Test logic
} catch (error) {
  console.error('Test failed:', error.message);
  report.addError('testName', error);
  // Continue or fail appropriately
}
```

### 5. Logging and Reporting

Log detailed information for debugging:

```javascript
console.log(`✓ Successfully navigated to ${page.url()}`);
console.log(`✗ Failed to find element: ${selector}`);
console.log(`  Error: ${error.message}`);

report.addResult('testName', passed, details);
report.addError('testName', error);
report.addScreenshot('testName', filePath);
```

---

## Performance Benchmarks

Expected execution times for each test scenario:

| Scenario | Duration | Notes |
|----------|----------|-------|
| Browser Launch | 2-3s | One-time startup cost |
| Page Navigation | 3-5s | Depends on network speed |
| Login Flow | 5-8s | Multiple form interactions |
| Exam Selection | 2-3s | Single click and navigation |
| DOM Extraction | 1-2s | JavaScript evaluation |
| Backend Health | 0.2s | Single HTTP request |
| Backend Analysis | 2-15s | Depends on OpenAI API latency |
| Stats App Check | 0.2s | Single HTTP request |
| **Total** | **20-40s** | Full workflow execution |

---

## CI/CD Integration

### GitHub Actions Configuration

```yaml
name: E2E Tests

on: [push, pull_request]

jobs:
  e2e:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v2

      - name: Setup Node.js
        uses: actions/setup-node@v2
        with:
          node-version: '18'

      - name: Install dependencies
        run: npm install

      - name: Start backend
        run: npm start --prefix backend &
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}

      - name: Wait for backend
        run: npx wait-on http://localhost:3000 --timeout 10000

      - name: Run E2E tests
        run: npm run test:e2e
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v2
        with:
          name: e2e-test-results
          path: test-screenshots/
```

---

## Advanced Usage

### Custom Test Configuration

```javascript
const CONFIG = {
  website: process.env.QUIZ_WEBSITE || 'http://www.iubh-onlineexams.de/',
  loginEmail: process.env.LOGIN_EMAIL || 'test@example.com',
  loginPassword: process.env.LOGIN_PASSWORD || 'password',
  examName: process.env.EXAM_NAME || 'Probeklausur ohne Proctoring',
  backendUrl: process.env.BACKEND_URL || 'http://localhost:3000',
  statsAppUrl: process.env.STATS_APP_URL || 'http://localhost:8080',
  timeout: parseInt(process.env.TEST_TIMEOUT) || 30000,
  headless: process.env.HEADLESS !== 'false'
};
```

### Debug Mode

Run tests with detailed logging:

```bash
# Debug mode
DEBUG=* npm run test:e2e

# Verbose output
npm run test:verbose -- --detectOpenHandles

# Run single test
npm test -- e2e.playwright.js -t "should launch browser"
```

---

## References

- **Playwright Documentation**: https://playwright.dev/
- **Jest Testing**: https://jestjs.io/
- **Quiz System**: `/Users/marvinbarsal/Desktop/Universität/Stats/CLAUDE.md`
- **Backend API**: `http://localhost:3000/health`
- **Test Report**: `test-screenshots/e2e-report.json`

---

## Summary

This E2E testing suite provides comprehensive coverage of the Quiz Stats Animation System workflow:

✓ **Browser Automation**: Full navigation, form filling, interaction
✓ **DOM Extraction**: Question and answer identification
✓ **Backend Integration**: API communication and data validation
✓ **Stats App Integration**: HTTP endpoint testing
✓ **Visual Regression**: Screenshot comparison
✓ **Performance Monitoring**: Execution time tracking
✓ **Error Handling**: Comprehensive error reporting
✓ **Test Reporting**: JSON report generation

All tests follow industry best practices and include detailed logging and error handling.

