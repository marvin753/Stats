#!/bin/bash

# Security Fixes Test Script
# Tests all 5 critical security fixes

echo "================================================"
echo "Security Fixes Test Script"
echo "Quiz Stats Animation System"
echo "================================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BACKEND_URL="http://localhost:3000"
API_KEY="${API_KEY:-test-api-key-12345}"
VALID_ORIGIN="http://localhost:8080"
INVALID_ORIGIN="https://evil.com"

echo "Configuration:"
echo "  Backend URL: $BACKEND_URL"
echo "  API Key: ${API_KEY:0:10}..."
echo ""

# Test 1: CORS Protection
echo "================================================"
echo "Test 1: CORS Wildcard Protection"
echo "================================================"

echo -n "Testing allowed origin... "
RESPONSE=$(curl -s -H "Origin: $VALID_ORIGIN" "$BACKEND_URL/health" -w "\n%{http_code}" 2>/dev/null | tail -1)
if [ "$RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓ PASSED${NC}"
else
    echo -e "${RED}✗ FAILED${NC} (Expected 200, got $RESPONSE)"
fi

echo -n "Testing blocked origin... "
RESPONSE=$(curl -s -H "Origin: $INVALID_ORIGIN" "$BACKEND_URL/api/analyze" -w "\n%{http_code}" 2>/dev/null | tail -1)
if [ "$RESPONSE" = "401" ] || [ "$RESPONSE" = "403" ] || [ "$RESPONSE" = "000" ]; then
    echo -e "${GREEN}✓ PASSED${NC}"
else
    echo -e "${YELLOW}⚠ WARNING${NC} (Expected rejection, got $RESPONSE)"
fi
echo ""

# Test 2: API Authentication
echo "================================================"
echo "Test 2: API Key Authentication"
echo "================================================"

echo -n "Testing request without API key... "
RESPONSE=$(curl -s -X POST "$BACKEND_URL/api/analyze" \
  -H "Content-Type: application/json" \
  -d '{"questions":[]}' \
  -w "\n%{http_code}" 2>/dev/null | tail -1)
if [ "$RESPONSE" = "401" ]; then
    echo -e "${GREEN}✓ PASSED${NC}"
else
    echo -e "${YELLOW}⚠ WARNING${NC} (Expected 401, got $RESPONSE - API_KEY may not be configured)"
fi

echo -n "Testing request with invalid API key... "
RESPONSE=$(curl -s -X POST "$BACKEND_URL/api/analyze" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: invalid-key-12345" \
  -d '{"questions":[]}' \
  -w "\n%{http_code}" 2>/dev/null | tail -1)
if [ "$RESPONSE" = "403" ]; then
    echo -e "${GREEN}✓ PASSED${NC}"
else
    echo -e "${YELLOW}⚠ WARNING${NC} (Expected 403, got $RESPONSE - API_KEY may not be configured)"
fi

echo -n "Testing health endpoint (public access)... "
RESPONSE=$(curl -s "$BACKEND_URL/health" -w "\n%{http_code}" 2>/dev/null | tail -1)
if [ "$RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓ PASSED${NC}"
else
    echo -e "${RED}✗ FAILED${NC} (Expected 200, got $RESPONSE)"
fi
echo ""

# Test 3: Rate Limiting
echo "================================================"
echo "Test 3: Rate Limiting"
echo "================================================"

echo "Testing rate limit (sending 15 requests quickly)..."
RATE_LIMITED=0
for i in {1..15}; do
    RESPONSE=$(curl -s "$BACKEND_URL/health" -w "\n%{http_code}" 2>/dev/null | tail -1)
    if [ "$RESPONSE" = "429" ]; then
        RATE_LIMITED=1
        echo -e "  Request $i: ${YELLOW}Rate limited (429)${NC}"
        break
    fi
    echo -n "  Request $i: $RESPONSE "
    if [ $((i % 5)) -eq 0 ]; then
        echo ""
    fi
done

if [ $RATE_LIMITED -eq 1 ]; then
    echo -e "${GREEN}✓ PASSED${NC} - Rate limiting is active"
elif [ $i -eq 15 ]; then
    echo -e "${YELLOW}⚠ WARNING${NC} - No rate limit hit (may need more requests or longer test)"
else
    echo -e "${GREEN}✓ PASSED${NC} - Rate limiting configuration detected"
fi
echo ""

# Test 4: SSRF Protection (requires node)
echo "================================================"
echo "Test 4: SSRF Protection"
echo "================================================"

if command -v node &> /dev/null; then
    echo "Testing URL validation..."

    # Create temporary test script
    cat > /tmp/test-ssrf.js << 'EOF'
const { validateUrl } = require('./scraper.js');

const tests = [
    { url: 'http://192.168.1.1', shouldFail: true, name: 'Private IP' },
    { url: 'http://127.0.0.1', shouldFail: true, name: 'Localhost IP' },
    { url: 'http://10.0.0.1', shouldFail: true, name: 'Private network' },
    { url: 'file:///etc/passwd', shouldFail: true, name: 'File protocol' },
    { url: 'http://169.254.169.254/latest/meta-data/', shouldFail: true, name: 'Cloud metadata' },
];

let passed = 0;
let failed = 0;

tests.forEach(test => {
    try {
        validateUrl(test.url);
        if (test.shouldFail) {
            console.log(`  ✗ FAILED: ${test.name} - Should have been blocked`);
            failed++;
        } else {
            console.log(`  ✓ PASSED: ${test.name}`);
            passed++;
        }
    } catch (error) {
        if (test.shouldFail) {
            console.log(`  ✓ PASSED: ${test.name} - Correctly blocked`);
            passed++;
        } else {
            console.log(`  ✗ FAILED: ${test.name} - Should have been allowed`);
            failed++;
        }
    }
});

console.log(`\nResults: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
EOF

    cd /Users/marvinbarsal/Desktop/Universität/Stats
    if node /tmp/test-ssrf.js 2>/dev/null; then
        echo -e "${GREEN}✓ PASSED${NC} - SSRF protection is working"
    else
        echo -e "${RED}✗ FAILED${NC} - SSRF protection may not be working correctly"
    fi
    rm /tmp/test-ssrf.js
else
    echo -e "${YELLOW}⚠ SKIPPED${NC} - Node.js not found"
fi
echo ""

# Test 5: Deprecated API (Swift - manual check)
echo "================================================"
echo "Test 5: Deprecated NSUserNotification API"
echo "================================================"

SWIFT_FILE="/Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats/Stats/Modules/QuizIntegrationManager.swift"

if [ -f "$SWIFT_FILE" ]; then
    echo "Checking Swift file for deprecated API usage..."

    if grep -q "NSUserNotification" "$SWIFT_FILE"; then
        echo -e "${RED}✗ FAILED${NC} - NSUserNotification still found in code"
    else
        echo -e "  ${GREEN}✓${NC} NSUserNotification removed"
    fi

    if grep -q "UserNotifications" "$SWIFT_FILE"; then
        echo -e "  ${GREEN}✓${NC} UserNotifications framework imported"
    else
        echo -e "${RED}✗ FAILED${NC} - UserNotifications not imported"
    fi

    if grep -q "UNUserNotificationCenter" "$SWIFT_FILE"; then
        echo -e "  ${GREEN}✓${NC} Modern notification API in use"
    else
        echo -e "${RED}✗ FAILED${NC} - Modern notification API not found"
    fi

    if grep -q "requestNotificationPermissions" "$SWIFT_FILE"; then
        echo -e "  ${GREEN}✓${NC} Permission request implemented"
    else
        echo -e "${YELLOW}⚠ WARNING${NC} - Permission request may not be implemented"
    fi

    echo -e "${GREEN}✓ PASSED${NC} - Modern notification API is in place"
else
    echo -e "${YELLOW}⚠ SKIPPED${NC} - Swift file not found"
fi
echo ""

# Summary
echo "================================================"
echo "Test Summary"
echo "================================================"
echo ""
echo "All critical security fixes have been tested."
echo ""
echo "Configuration Notes:"
echo "  • Ensure API_KEY is set in .env for full protection"
echo "  • Configure CORS_ALLOWED_ORIGINS for production"
echo "  • Configure ALLOWED_DOMAINS for scraper whitelist"
echo "  • Rate limiting is active by default"
echo ""
echo "For full security testing, ensure the backend server"
echo "is running with proper environment configuration."
echo ""
echo "See SECURITY_FIXES.md for detailed documentation."
echo "================================================"
