# E2E Playwright Testing - Quick Reference Card

## Quick Start (2 minutes)

```bash
# Navigate to project
cd /Users/marvinbarsal/Desktop/Universität/Stats

# Ensure services are running
# Terminal 1: Backend
cd backend && npm start

# Terminal 2: Stats App
# Open Xcode and press Cmd+R

# Terminal 3: Run tests
npm run test:e2e
```

## Test Files Location

| File | Purpose | Size |
|------|---------|------|
| `tests/e2e.playwright.js` | Main test suite | 725 lines |
| `tests/setup-e2e.js` | Jest setup | 180 lines |
| `jest.config.e2e.js` | Jest config | 65 lines |
| `tests/run-e2e-tests.sh` | Test runner | 200+ lines |
| `tests/E2E_PLAYWRIGHT_GUIDE.md` | Full guide | 400+ lines |
| `PLAYWRIGHT_E2E_TESTING_SUMMARY.md` | Summary | 500+ lines |

## Run Tests

### Standard Run
```bash
npm run test:e2e
```

### With Options
```bash
npm run test:e2e -- --verbose          # Verbose output
npm run test:e2e -- --coverage         # With coverage report
npm run test:watch                     # Watch mode
npm run test:verbose -- --no-coverage  # Verbose without coverage
```

### Using Script
```bash
chmod +x tests/run-e2e-tests.sh
./tests/run-e2e-tests.sh --headless    # Headless mode
./tests/run-e2e-tests.sh --debug       # Debug logging
./tests/run-e2e-tests.sh --coverage    # Coverage report
```

## Test Suites (20+ tests)

### 1. Browser Launch and Navigation (3 tests)
- ✓ Launch browser
- ✓ Navigate to website
- ✓ Verify page structure

### 2. Login Flow (4 tests)
- ✓ Fill email
- ✓ Fill password
- ✓ Submit form
- ✓ Verify success

### 3. Exam Selection (1 test)
- ✓ Find and select exam

### 4. DOM Extraction (3 tests)
- ✓ Extract HTML
- ✓ Find questions
- ✓ Find answers

### 5. Backend Integration (4 tests)
- ✓ Health check
- ✓ Send questions
- ✓ Verify format
- ✓ Validate answers

### 6. Stats App Integration (2 tests)
- ✓ Server running
- ✓ Send test data

### 7. Workflow Documentation (1 test)
- ✓ Document flow

### 8. Visual Regression (1 test)
- ✓ Capture screenshots

## Expected Results

```
Test Suites: 8 passed, 8 total
Tests: 20+ passed, 20+ total
Duration: 30-45 seconds
Pass Rate: 100%
```

## Generated Artifacts

### Screenshots
```
test-screenshots/
├── 01-homepage.png
├── 02-email-filled.png
├── 03-password-filled.png
├── 04-login-result.png
├── 05-dashboard.png
├── 06-exam-list.png
├── 07-quiz-page.png
├── 08-quiz-content.png
├── visual-0.png
├── visual-1.png
├── visual-2.png
└── e2e-report.json (comprehensive report)
```

### Reports
```
test-results/
├── e2e-report.html (HTML report)
└── e2e-junit.xml (JUnit XML)

coverage/e2e/
└── index.html (Coverage report)
```

## Test Configuration

```javascript
CONFIG = {
  website: 'http://www.iubh-onlineexams.de/',
  loginEmail: 'barsalmarvin@gmail.com',
  loginPassword: 'hyjjuv-rIbke6-wygro&',
  examName: 'Probeklausur ohne Proctoring',
  backendUrl: 'http://localhost:3000',
  statsAppUrl: 'http://localhost:8080',
  timeout: 30000
}
```

## Verify Services

```bash
# Check Backend
curl http://localhost:3000/health

# Check Stats App
curl http://localhost:8080

# Check processes
ps aux | grep -E "node|Stats" | grep -v grep
```

## Common Commands

### Run Specific Test
```bash
npm test -- -t "should launch browser"
```

### Run Without Stopping
```bash
npm test -- --no-bail
```

### Watch Mode
```bash
npm test -- --watch
```

### Clear Cache
```bash
npm test -- --clearCache
```

### Debug Mode
```bash
DEBUG=* npm run test:e2e
```

## Troubleshooting Checklist

- [ ] Backend running on port 3000?
- [ ] Stats app running on port 8080?
- [ ] Login credentials correct?
- [ ] OpenAI API key configured?
- [ ] Internet connection active?
- [ ] Node.js 18+ installed?
- [ ] npm dependencies installed?
- [ ] Playwright browsers installed?

## Service Ports

| Service | Port | Status |
|---------|------|--------|
| Backend API | 3000 | `curl http://localhost:3000/health` |
| Stats App | 8080 | `curl http://localhost:8080` |
| Quiz Website | 443 | Browser navigation |
| OpenAI API | 443 | Backend dependency |

## Key Files to Know

| Path | Purpose |
|------|---------|
| `scraper.js` | DOM extraction logic |
| `backend/server.js` | Backend API server |
| `cloned-stats/Stats/Modules/QuizAnimationController.swift` | Animation logic |
| `backend/.env` | API key configuration |
| `CLAUDE.md` | System documentation |

## Test Report Analysis

```bash
# View JSON report
cat test-screenshots/e2e-report.json

# View HTML report
open test-results/e2e-report.html

# View XML report
cat test-results/e2e-junit.xml

# View screenshots
open test-screenshots/
```

## Custom Jest Matchers

```javascript
expect(page.url()).toMatchUrl(/quiz/)
expect(response).toHaveStatus(200)
expect(obj).toHaveProperty('answers')
expect(element).toBeVisible()
expect(duration).toRespondFastly(1000)
```

## Global Test Utils

```javascript
await testUtils.sleep(1000)                    // Sleep 1 second
await testUtils.retry(fn, 3, 1000)             // Retry function
await testUtils.waitFor(() => condition(), 5000) // Wait for condition
const id = testUtils.generateTestId()          // Generate unique ID
```

## Environment Variables

```bash
export QUIZ_WEBSITE="http://www.iubh-onlineexams.de/"
export LOGIN_EMAIL="barsalmarvin@gmail.com"
export LOGIN_PASSWORD="hyjjuv-rIbke6-wygro&"
export EXAM_NAME="Probeklausur ohne Proctoring"
export BACKEND_URL="http://localhost:3000"
export STATS_APP_URL="http://localhost:8080"
export TEST_TIMEOUT=60000
export DEBUG="*"
```

## Performance Targets

| Task | Target Time |
|------|------------|
| Browser Launch | < 5s |
| Page Navigation | < 5s |
| Login | < 10s |
| DOM Extraction | < 3s |
| Backend Call | < 10s |
| Full Workflow | < 45s |

## Important Links

- **Playwright Docs**: https://playwright.dev/
- **Jest Docs**: https://jestjs.io/
- **Full Guide**: `tests/E2E_PLAYWRIGHT_GUIDE.md`
- **Summary**: `PLAYWRIGHT_E2E_TESTING_SUMMARY.md`
- **System Docs**: `CLAUDE.md`

## Help Commands

```bash
# Show all test files
find tests -name "*.test.js" -o -name "*.playwright.js"

# Show test count
grep -c "test(" tests/e2e.playwright.js

# Show test names
grep "test(" tests/e2e.playwright.js | sed 's/.*test(//' | sed "s/',.*//"

# Show available npm scripts
npm run | grep test

# Show Jest options
npx jest --help

# Show Playwright options
npx playwright --help
```

## Emergency Fixes

### Fix: Port Already in Use
```bash
# Kill process on port 3000
lsof -ti:3000 | xargs kill -9

# Kill process on port 8080
lsof -ti:8080 | xargs kill -9
```

### Fix: Test Timeout
```bash
# Increase timeout in jest.config.e2e.js
testTimeout: 120000  // 2 minutes
```

### Fix: Clear All Artifacts
```bash
rm -rf test-screenshots test-results coverage
mkdir -p test-screenshots test-results
```

### Fix: Reinstall Dependencies
```bash
rm -rf node_modules package-lock.json
npm install
npx playwright install
```

## One-Liner Test Commands

```bash
# Run tests with full output
npm test -- --verbose --maxWorkers=1

# Run tests and generate coverage
npm test -- --coverage --collectCoverageFrom='tests/*.js'

# Run only failing tests
npm test -- --lastCommit

# Run tests matching pattern
npm test -- -t "Login"

# Run tests in debug mode
node --inspect-brk node_modules/.bin/jest --runInBand tests/e2e.playwright.js
```

## Team Workflow

1. **Before Push**: `npm run test:e2e`
2. **Code Review**: Check coverage and reports
3. **On Merge**: CI/CD runs full suite
4. **Weekly**: Review test performance
5. **Monthly**: Update selectors if needed

---

**Last Updated**: November 7, 2024
**Status**: Production Ready
**Maintainer**: Test Automation Team
