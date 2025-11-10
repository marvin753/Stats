# Testing Quick Start Guide

## 🚀 Get Started in 60 Seconds

### 1. Install Dependencies (30 seconds)

```bash
npm install
cd backend && npm install && cd ..
```

### 2. Run Tests (30 seconds)

```bash
npm test
```

That's it! ✅

---

## 📊 View Coverage Report

```bash
# Generate coverage report
npm run test:coverage

# Open in browser
open coverage/index.html
```

---

## 🎯 Common Commands

### Run Specific Test Suites

```bash
# Backend tests only
npm run test:backend

# Frontend tests only
npm run test:frontend

# Security tests
npm run test:security

# E2E tests
npm run test:e2e
```

### Development Mode

```bash
# Watch mode (auto-rerun on changes)
npm run test:watch

# Verbose output
npm run test:verbose
```

### CI Mode

```bash
# Run like in CI/CD
npm run test:ci
```

---

## 🔧 Using Test Runner Script

```bash
# Make executable (first time only)
chmod +x test-runner.sh

# Run all tests
./test-runner.sh

# Run with options
./test-runner.sh --backend --coverage
./test-runner.sh --frontend --verbose
./test-runner.sh --e2e
./test-runner.sh --security
```

---

## 📁 Test File Locations

```
backend/tests/
  ├── security.test.js      # Security tests
  ├── api.test.js            # API endpoint tests
  └── integration.test.js    # Backend integration

frontend/tests/
  ├── api-client.test.js     # API client tests
  ├── error-handler.test.js  # Error handler tests
  ├── url-validator.test.js  # URL validator tests
  └── integration.test.js    # Frontend integration

tests/
  └── e2e.test.js            # End-to-end tests
```

---

## 🆘 Troubleshooting

### Tests Failing?

```bash
# Clear cache
npm test -- --clearCache

# Reinstall dependencies
rm -rf node_modules
npm install
```

### Port Conflicts?

```bash
# Kill process on port 3000
lsof -ti:3000 | xargs kill -9
```

### Need Help?

```bash
# Show test runner help
./test-runner.sh --help

# Run single test file
npm test backend/tests/security.test.js
```

---

## 📚 Full Documentation

For complete documentation, see:
- **TESTING_COMPLETE.md** - Comprehensive guide
- **TEST_SUITE_SUMMARY.md** - Overview and statistics

---

## ✅ Quick Test Checklist

- [ ] Dependencies installed
- [ ] Tests run successfully
- [ ] Coverage > 80%
- [ ] All test suites pass
- [ ] CI/CD configured (optional)

---

**Need more details?** Read `TESTING_COMPLETE.md`
