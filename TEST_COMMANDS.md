# Test Commands Reference

Quick reference for running tests in the Stats project.

## Quick Commands

### Run ALL Tests
```bash
npm test
```

### Run All Tests (No Coverage Reports)
```bash
npm test -- --no-coverage
```

### Run Backend Tests Only
```bash
npm run test:backend
```

### Run Frontend Tests Only
```bash
npm run test:frontend
```

### Run Specific Test File
```bash
npm test -- backend/tests/health.test.js
```

### Run Tests with Coverage Report
```bash
npm run test:coverage
```
Coverage report will be in: `coverage/lcov-report/index.html`

### Run E2E Tests Only
```bash
npm run test:e2e
```

### Run Security Tests Only
```bash
npm run test:security
```

## Advanced Options

### Run Tests in Watch Mode (Auto-rerun on file changes)
```bash
npm run test:watch
```

### Run with Verbose Output
```bash
npm run test:verbose
```

### Run Specific Test Suite
```bash
npm test -- --testNamePattern="Health Check"
```

### Run Tests from Specific Directory
```bash
npm test -- backend/tests/
```

## Troubleshooting

### Tests Hanging? <- Important!!
```bash
# Kill all node processes
killall -9 node

# Then run tests again
npm test
```

### Clean Test Run
```bash
# Use the clean test runner script
./run-tests-clean.sh
```

### Check Test Configuration
```bash
# View Jest config
cat jest.config.js

# List all test files that will run
npm test -- --listTests
```

## Test Files Location

- **Backend Tests**: `backend/tests/`
  - `api.test.js` - API endpoint tests
  - `health.test.js` - Health check tests
  - `security.test.js` - Security tests
  - `integration.test.js` - Backend integration tests

- **Frontend Tests**: `frontend/tests/`
  - `api-client.test.js` - API client tests
  - `error-handler.test.js` - Error handling tests
  - `url-validator.test.js` - URL validation tests
  - `integration.test.js` - Frontend integration tests

- **E2E Tests**: `tests/`
  - `e2e.test.js` - End-to-end tests

## Test Reports

After running tests with coverage:

- **HTML Report**: Open `coverage/lcov-report/index.html` in browser
- **Console Summary**: Displayed at end of test run

## Quick Tips

1. **Always run tests before committing code**
2. **Use `--no-coverage` for faster test runs during development**
3. **Use `test:watch` mode when actively writing tests**
4. **Check coverage reports to ensure adequate test coverage**
5. **All tests must pass before deployment**

## Environment Variables

Tests use these environment variables (set in test files):
- `NODE_ENV=test`
- `OPENAI_API_KEY=sk-test...` (mock key for tests)
- `API_KEY=test-key` (backend API key)
- `CORS_ALLOWED_ORIGINS=http://localhost:8080`
- `STATS_APP_URL=http://localhost:8080`

## CI/CD Commands

For continuous integration:
```bash
npm run test:ci
```
This runs tests with CI-specific settings (max 2 workers, coverage enabled)
