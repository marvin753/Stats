# Quick Start: Integration Testing

**5-Minute Guide to Running Tests**

---

## Prerequisites

### 1. Start Services

**Terminal 1 - CDP Service:**
```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/chrome-cdp-service
npm start
```

**Terminal 2 - Backend API:**
```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/backend
npm start
```

**Terminal 3 - Stats App (Optional):**
```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats
./run-swift.sh
```

---

## Run Tests

### All Tests (Recommended)

```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/tests
./run-all-tests.sh
```

**Expected output:**
```
✅✅✅ ALL TESTS PASSED ✅✅✅

Test Suites: 4 passed, 4 total
Tests:       67 passed, 67 total
Time:        ~120s
```

### Specific Test Suites

**Integration tests only:**
```bash
npm run test:integration
```

**Unit tests only:**
```bash
npm run test:unit
```

**With coverage report:**
```bash
npm run test:coverage
```

---

## View Results

**Test log:**
```bash
cat test-results.log
```

**Test report:**
```bash
cat test-report.md
```

---

## Troubleshooting

### Services not running?

Check service status:
```bash
lsof -i :9223  # CDP service
lsof -i :3000  # Backend API
lsof -i :8080  # Stats app
```

### Dependencies missing?

Install dependencies:
```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/tests
npm install
```

### Tests failing?

Check service health:
```bash
curl http://localhost:9223/health
curl http://localhost:3000/health
```

---

## Test Files

| File | Purpose |
|------|---------|
| `integration/test-cdp-service.js` | CDP service tests |
| `integration/test-backend-api.js` | Backend API tests |
| `integration/test-end-to-end.js` | E2E workflow tests |
| `unit/test-screenshot-quality.js` | Screenshot validation |

**Total:** 67 automated tests

---

## Quick Commands

```bash
# Run all tests
./run-all-tests.sh

# Run specific suite
npm test -- integration/test-cdp-service.js

# Run with verbose output
npm run test:verbose

# Check service health
curl http://localhost:9223/health
curl http://localhost:3000/health
```

---

**That's it! You're ready to test the system.**

For full documentation, see: `WAVE_5A_TEST_IMPLEMENTATION.md`
