#!/bin/bash

##########################################################################
# E2E Test Runner Script
#
# This script automates the execution of E2E Playwright tests for the
# Quiz Stats Animation System.
#
# Usage:
#   chmod +x tests/run-e2e-tests.sh
#   ./tests/run-e2e-tests.sh
#
# Options:
#   --headless         Run in headless mode (default: interactive)
#   --debug            Enable debug logging
#   --coverage         Generate coverage report
#   --watch            Run in watch mode
#   --ui               Show test UI
##########################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="/Users/marvinbarsal/Desktop/Universität/Stats"
BACKEND_PORT=3000
STATS_PORT=8080
TEST_TIMEOUT=60000

# Parse command-line arguments
HEADLESS=false
DEBUG=false
COVERAGE=false
WATCH=false
UI=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --headless)
      HEADLESS=true
      shift
      ;;
    --debug)
      DEBUG=true
      shift
      ;;
    --coverage)
      COVERAGE=true
      shift
      ;;
    --watch)
      WATCH=true
      shift
      ;;
    --ui)
      UI=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Header
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   E2E PLAYWRIGHT TEST RUNNER                   ║${NC}"
echo -e "${BLUE}║   Quiz Stats Animation System                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}\n"

# Step 1: Check prerequisites
echo -e "${YELLOW}[1/6] Checking prerequisites...${NC}"

# Check Node.js
if ! command -v node &> /dev/null; then
  echo -e "${RED}✗ Node.js not found${NC}"
  exit 1
fi
NODE_VERSION=$(node -v)
echo -e "${GREEN}✓ Node.js ${NODE_VERSION}${NC}"

# Check npm
if ! command -v npm &> /dev/null; then
  echo -e "${RED}✗ npm not found${NC}"
  exit 1
fi
NPM_VERSION=$(npm -v)
echo -e "${GREEN}✓ npm ${NPM_VERSION}${NC}"

# Check Playwright
if ! npm list playwright &> /dev/null 2>&1; then
  echo -e "${YELLOW}Installing Playwright...${NC}"
  npm install playwright
fi
echo -e "${GREEN}✓ Playwright installed${NC}\n"

# Step 2: Create necessary directories
echo -e "${YELLOW}[2/6] Creating test directories...${NC}"

mkdir -p "${PROJECT_ROOT}/test-screenshots"
mkdir -p "${PROJECT_ROOT}/test-results"

echo -e "${GREEN}✓ Test directories ready${NC}"
echo -e "  Screenshots: ${PROJECT_ROOT}/test-screenshots"
echo -e "  Results: ${PROJECT_ROOT}/test-results\n"

# Step 3: Check required services
echo -e "${YELLOW}[3/6] Checking required services...${NC}"

# Check backend
if ! curl -s http://localhost:${BACKEND_PORT}/health > /dev/null 2>&1; then
  echo -e "${RED}✗ Backend not running on port ${BACKEND_PORT}${NC}"
  echo -e "${YELLOW}  Start it with: cd ${PROJECT_ROOT}/backend && npm start${NC}"
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
else
  echo -e "${GREEN}✓ Backend running on port ${BACKEND_PORT}${NC}"
fi

# Check Stats app
if ! curl -s http://localhost:${STATS_PORT}/ > /dev/null 2>&1; then
  echo -e "${RED}✗ Stats app not running on port ${STATS_PORT}${NC}"
  echo -e "${YELLOW}  Start it with: Xcode - open Stats.xcodeproj and press Cmd+R${NC}"
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
else
  echo -e "${GREEN}✓ Stats app running on port ${STATS_PORT}${NC}"
fi
echo ""

# Step 4: Install dependencies
echo -e "${YELLOW}[4/6] Installing dependencies...${NC}"

cd "${PROJECT_ROOT}"
npm install > /dev/null 2>&1

if [ -d "${PROJECT_ROOT}/backend" ]; then
  cd "${PROJECT_ROOT}/backend"
  npm install > /dev/null 2>&1
  cd "${PROJECT_ROOT}"
fi

echo -e "${GREEN}✓ Dependencies installed${NC}\n"

# Step 5: Run tests
echo -e "${YELLOW}[5/6] Running E2E tests...${NC}"

# Build Jest command
JEST_CMD="jest tests/e2e.playwright.js --config jest.config.e2e.js"

# Add options
if [ "$DEBUG" = true ]; then
  JEST_CMD="${JEST_CMD} --verbose"
  export DEBUG="*"
fi

if [ "$COVERAGE" = true ]; then
  JEST_CMD="${JEST_CMD} --coverage"
fi

if [ "$WATCH" = true ]; then
  JEST_CMD="${JEST_CMD} --watch"
fi

if [ "$UI" = true ]; then
  JEST_CMD="${JEST_CMD} --testNamePattern='' --collectCoverage=false"
fi

# Set environment variables
export HEADLESS="${HEADLESS}"
export TEST_TIMEOUT="${TEST_TIMEOUT}"

echo "Running: ${JEST_CMD}"
echo ""

# Run tests
cd "${PROJECT_ROOT}"
${JEST_CMD}

TEST_EXIT_CODE=$?

# Step 6: Display results
echo ""
echo -e "${YELLOW}[6/6] Test execution complete${NC}\n"

if [ ${TEST_EXIT_CODE} -eq 0 ]; then
  echo -e "${GREEN}✓ All tests passed!${NC}"
else
  echo -e "${RED}✗ Some tests failed${NC}"
fi

echo ""
echo -e "${BLUE}Test Artifacts:${NC}"
echo "  HTML Report: ${PROJECT_ROOT}/test-results/e2e-report.html"
echo "  JUnit XML: ${PROJECT_ROOT}/test-results/e2e-junit.xml"
echo "  Screenshots: ${PROJECT_ROOT}/test-screenshots/"
echo "  JSON Report: ${PROJECT_ROOT}/test-screenshots/e2e-report.json"

if [ "$COVERAGE" = true ]; then
  echo "  Coverage: ${PROJECT_ROOT}/coverage/e2e/index.html"
fi

echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  • View HTML report: open ${PROJECT_ROOT}/test-results/e2e-report.html"
echo "  • Check screenshots: open ${PROJECT_ROOT}/test-screenshots/"
echo "  • Review JSON report: cat ${PROJECT_ROOT}/test-screenshots/e2e-report.json"

exit ${TEST_EXIT_CODE}
