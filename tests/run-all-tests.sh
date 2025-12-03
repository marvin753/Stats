#!/bin/bash

echo "============================================================"
echo "Stats Quiz System - Wave 5A Integration Test Suite"
echo "============================================================"
echo ""
echo "Testing complete system integration:"
echo "  • Chrome CDP Service (port 9223)"
echo "  • Backend Assistant API (port 3000)"
echo "  • Stats App HTTP Server (port 8080)"
echo "  • End-to-End Workflow"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
TEST_DIR="/Users/marvinbarsal/Desktop/Universität/Stats/tests"
LOG_FILE="$TEST_DIR/test-results.log"
REPORT_FILE="$TEST_DIR/test-report.md"

# Clear previous logs
> "$LOG_FILE"

echo "============================================================"
echo "Step 1: Checking Prerequisites"
echo "============================================================"
echo ""

# Check if services are running
SERVICES_OK=true

echo -n "Checking CDP Service (port 9223)... "
if lsof -i :9223 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Running${NC}"
else
    echo -e "${RED}❌ Not running${NC}"
    echo "   Start it: cd chrome-cdp-service && npm start"
    SERVICES_OK=false
fi

echo -n "Checking Backend API (port 3000)... "
if lsof -i :3000 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Running${NC}"
else
    echo -e "${RED}❌ Not running${NC}"
    echo "   Start it: cd backend && npm start"
    SERVICES_OK=false
fi

echo -n "Checking Stats App (port 8080)... "
if lsof -i :8080 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Running${NC}"
else
    echo -e "${YELLOW}⚠️  Not running (optional)${NC}"
    echo "   Some E2E tests will be skipped"
    echo "   Start it: ./run-swift.sh"
fi

echo ""

if [ "$SERVICES_OK" = false ]; then
    echo -e "${RED}============================================================${NC}"
    echo -e "${RED}❌ Required services are not running${NC}"
    echo -e "${RED}============================================================${NC}"
    echo ""
    echo "Please start the required services:"
    echo ""
    echo "Terminal 1 - CDP Service:"
    echo "  cd /Users/marvinbarsal/Desktop/Universität/Stats/chrome-cdp-service"
    echo "  npm start"
    echo ""
    echo "Terminal 2 - Backend API:"
    echo "  cd /Users/marvinbarsal/Desktop/Universität/Stats/backend"
    echo "  npm start"
    echo ""
    echo "Terminal 3 (Optional) - Stats App:"
    echo "  cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats"
    echo "  ./run-swift.sh"
    echo ""
    exit 1
fi

echo "============================================================"
echo "Step 2: Installing Test Dependencies"
echo "============================================================"
echo ""

cd "$TEST_DIR"

if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install 2>&1 | tee -a "$LOG_FILE"
    echo ""
else
    echo "✅ Dependencies already installed"
    echo ""
fi

echo "============================================================"
echo "Step 3: Running Health Checks"
echo "============================================================"
echo ""

echo -n "CDP Service Health... "
CDP_HEALTH=$(curl -s http://localhost:9223/health)
if echo "$CDP_HEALTH" | grep -q "ok"; then
    echo -e "${GREEN}✅ Healthy${NC}"
else
    echo -e "${RED}❌ Unhealthy${NC}"
fi

echo -n "Backend API Health... "
BACKEND_HEALTH=$(curl -s http://localhost:3000/health)
if echo "$BACKEND_HEALTH" | grep -q "ok"; then
    echo -e "${GREEN}✅ Healthy${NC}"
else
    echo -e "${RED}❌ Unhealthy${NC}"
fi

echo ""

echo "============================================================"
echo "Step 4: Running Integration Test Suite"
echo "============================================================"
echo ""

START_TIME=$(date +%s)

# Run tests with Jest
npm test -- --verbose 2>&1 | tee -a "$LOG_FILE"

TEST_EXIT_CODE=${PIPESTATUS[0]}
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "============================================================"
echo "Step 5: Generating Test Report"
echo "============================================================"
echo ""

# Generate markdown report
cat > "$REPORT_FILE" << EOF
# Wave 5A Integration Test Report

**Date:** $(date '+%Y-%m-%d %H:%M:%S')
**Duration:** ${DURATION}s
**Exit Code:** $TEST_EXIT_CODE

## System Configuration

| Service | Status | Port |
|---------|--------|------|
| CDP Service | ✅ Running | 9223 |
| Backend API | ✅ Running | 3000 |
| Stats App | $(lsof -i :8080 > /dev/null 2>&1 && echo "✅ Running" || echo "⚠️ Not Running") | 8080 |

## Test Suites

### Integration Tests

#### 1. CDP Service Tests
- Health check validation
- Full-page screenshot capture
- Screenshot quality validation
- Error handling
- Performance benchmarks

#### 2. Backend API Tests
- Health check
- PDF upload and thread creation
- Thread management
- Quiz analysis with screenshot
- Thread deletion
- Security validation

#### 3. End-to-End Workflow Tests
- Service availability checks
- Complete screenshot-based analysis workflow
- Data flow integrity
- Error recovery and resilience
- Performance benchmarks

## Test Results

\`\`\`
$(tail -100 "$LOG_FILE")
\`\`\`

## Summary

EOF

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}" | tee -a "$REPORT_FILE"
    cat >> "$REPORT_FILE" << EOF

**Status:** ✅ **ALL TESTS PASSED**

All integration tests completed successfully. The system is ready for production use.

## Next Steps

1. Review test coverage metrics
2. Deploy to production environment
3. Set up continuous integration
4. Monitor system performance

EOF
else
    echo -e "${RED}❌ Some tests failed${NC}" | tee -a "$REPORT_FILE"
    cat >> "$REPORT_FILE" << EOF

**Status:** ❌ **SOME TESTS FAILED**

Please review the test output above and fix any failing tests.

## Troubleshooting

1. Check service logs for errors
2. Verify environment configuration
3. Ensure all dependencies are installed
4. Review test-results.log for details

EOF
fi

echo ""
echo "============================================================"
echo "Test Summary"
echo "============================================================"
echo ""
echo "Duration: ${DURATION}s"
echo "Log file: $LOG_FILE"
echo "Report: $REPORT_FILE"
echo ""

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅✅✅ ALL TESTS PASSED ✅✅✅${NC}"
    echo ""
    echo "Test coverage:"
    echo "  • CDP Service: Full integration"
    echo "  • Backend API: Complete workflow"
    echo "  • End-to-End: Screenshot → Analysis → Display"
    echo ""
else
    echo -e "${RED}❌ Tests failed with exit code $TEST_EXIT_CODE${NC}"
    echo ""
    echo "Check logs for details:"
    echo "  cat $LOG_FILE"
    echo ""
fi

echo "View full report:"
echo "  cat $REPORT_FILE"
echo ""

exit $TEST_EXIT_CODE
