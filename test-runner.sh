#!/bin/bash

###############################################################################
# Test Runner Script
# Comprehensive test execution with multiple modes and reporting
#
# Usage:
#   ./test-runner.sh [options]
#
# Options:
#   --all           Run all tests (default)
#   --backend       Run backend tests only
#   --frontend      Run frontend tests only
#   --e2e           Run end-to-end tests only
#   --security      Run security tests only
#   --integration   Run integration tests only
#   --unit          Run unit tests only
#   --watch         Run tests in watch mode
#   --coverage      Generate coverage report
#   --ci            Run in CI mode (no watch, strict)
#   --verbose       Verbose output
#   --help          Show help
#
# Examples:
#   ./test-runner.sh --backend --coverage
#   ./test-runner.sh --e2e --verbose
#   ./test-runner.sh --ci
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Default options
MODE="all"
WATCH=false
COVERAGE=false
CI=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --all)
      MODE="all"
      shift
      ;;
    --backend)
      MODE="backend"
      shift
      ;;
    --frontend)
      MODE="frontend"
      shift
      ;;
    --e2e)
      MODE="e2e"
      shift
      ;;
    --security)
      MODE="security"
      shift
      ;;
    --integration)
      MODE="integration"
      shift
      ;;
    --unit)
      MODE="unit"
      shift
      ;;
    --watch)
      WATCH=true
      shift
      ;;
    --coverage)
      COVERAGE=true
      shift
      ;;
    --ci)
      CI=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      grep "^#" "$0" | grep -v "^#!/" | sed 's/^# //'
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Functions
print_header() {
  echo -e "\n${BLUE}========================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
  echo -e "${RED}✗ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
  echo -e "${BLUE}ℹ $1${NC}"
}

# Check dependencies
check_dependencies() {
  print_header "Checking Dependencies"

  if ! command -v node &> /dev/null; then
    print_error "Node.js is not installed"
    exit 1
  fi
  print_success "Node.js $(node --version)"

  if ! command -v npm &> /dev/null; then
    print_error "npm is not installed"
    exit 1
  fi
  print_success "npm $(npm --version)"

  if [ ! -d "node_modules" ]; then
    print_warning "node_modules not found, installing dependencies..."
    npm install
  fi

  if [ ! -d "backend/node_modules" ]; then
    print_warning "Backend dependencies not found, installing..."
    cd backend && npm install && cd ..
  fi

  print_success "All dependencies installed"
}

# Setup environment
setup_environment() {
  print_header "Setting Up Test Environment"

  # Create test environment file
  if [ ! -f ".env.test" ]; then
    print_info "Creating .env.test file..."
    cat > .env.test << EOF
NODE_ENV=test
BACKEND_PORT=3001
OPENAI_API_KEY=sk-test-key-for-testing
API_KEY=test-api-key
BACKEND_API_KEY=test-api-key
CORS_ALLOWED_ORIGINS=http://localhost:8080,http://localhost:3000
ALLOWED_DOMAINS=example.com,quizplatform.com,localhost
BACKEND_URL=http://localhost:3000
STATS_APP_URL=http://localhost:8080
EOF
    print_success "Test environment file created"
  fi

  # Load test environment
  export $(cat .env.test | xargs)

  print_success "Test environment configured"
}

# Build Jest command
build_jest_command() {
  local cmd="npx jest"

  # Add test path based on mode
  case $MODE in
    all)
      cmd="$cmd"
      ;;
    backend)
      cmd="$cmd backend/tests"
      ;;
    frontend)
      cmd="$cmd frontend/tests"
      ;;
    e2e)
      cmd="$cmd tests/e2e.test.js"
      ;;
    security)
      cmd="$cmd backend/tests/security.test.js"
      ;;
    integration)
      cmd="$cmd backend/tests/integration.test.js tests/e2e.test.js"
      ;;
    unit)
      cmd="$cmd --testPathIgnorePatterns=integration.test.js --testPathIgnorePatterns=e2e.test.js"
      ;;
  esac

  # Add options
  if [ "$WATCH" = true ]; then
    cmd="$cmd --watch"
  fi

  if [ "$COVERAGE" = true ] || [ "$CI" = true ]; then
    cmd="$cmd --coverage"
  fi

  if [ "$VERBOSE" = true ]; then
    cmd="$cmd --verbose"
  fi

  if [ "$CI" = true ]; then
    cmd="$cmd --ci --bail --maxWorkers=2"
  fi

  # Add config file
  cmd="$cmd --config=jest.config.js"

  echo "$cmd"
}

# Run tests
run_tests() {
  print_header "Running Tests: $MODE"

  local jest_cmd=$(build_jest_command)

  print_info "Command: $jest_cmd"
  echo

  if eval "$jest_cmd"; then
    print_success "All tests passed!"
    return 0
  else
    print_error "Some tests failed"
    return 1
  fi
}

# Generate report
generate_report() {
  if [ "$COVERAGE" = true ] || [ "$CI" = true ]; then
    print_header "Generating Test Report"

    if [ -d "coverage" ]; then
      print_success "Coverage report generated at coverage/index.html"
      print_success "Test report generated at coverage/test-report.html"

      # Display coverage summary
      if [ -f "coverage/coverage-summary.json" ]; then
        echo
        print_info "Coverage Summary:"
        node -e "
          const coverage = require('./coverage/coverage-summary.json');
          const total = coverage.total;
          console.log('  Lines:      ' + total.lines.pct + '%');
          console.log('  Statements: ' + total.statements.pct + '%');
          console.log('  Functions:  ' + total.functions.pct + '%');
          console.log('  Branches:   ' + total.branches.pct + '%');
        "
      fi
    else
      print_warning "No coverage directory found"
    fi
  fi
}

# Cleanup
cleanup() {
  print_header "Cleaning Up"

  # Remove test artifacts
  rm -f .env.test

  print_success "Cleanup complete"
}

# Main execution
main() {
  print_header "Quiz Stats Animation System - Test Runner"

  print_info "Mode: $MODE"
  print_info "Watch: $WATCH"
  print_info "Coverage: $COVERAGE"
  print_info "CI: $CI"
  print_info "Verbose: $VERBOSE"

  # Run steps
  check_dependencies
  setup_environment

  # Run tests
  if run_tests; then
    TEST_RESULT=0
  else
    TEST_RESULT=1
  fi

  # Generate report
  generate_report

  # Cleanup (skip in watch mode)
  if [ "$WATCH" = false ]; then
    cleanup
  fi

  # Exit with test result
  if [ $TEST_RESULT -eq 0 ]; then
    print_success "Test suite completed successfully!"
    exit 0
  else
    print_error "Test suite failed"
    exit 1
  fi
}

# Trap errors
trap 'print_error "An error occurred. Exiting."; exit 1' ERR

# Run main
main
