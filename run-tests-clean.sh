#!/bin/bash

# Clean Test Runner for Stats Project
# Kills hanging processes and runs tests cleanly

echo "═══════════════════════════════════════════════"
echo "  Stats Project - Clean Test Runner"
echo "═══════════════════════════════════════════════"

# Step 1: Kill any hanging node/jest processes
echo ""
echo "1. Killing any hanging test processes..."
killall -9 node jest 2>/dev/null
sleep 2
echo "   ✓ Processes cleaned"

# Step 2: Navigate to project directory
cd "$(dirname "$0")"
echo ""
echo "2. Project directory: $(pwd)"

# Step 3: Check if node_modules exists
if [ ! -d "node_modules" ]; then
  echo ""
  echo "3. Installing dependencies..."
  npm install
else
  echo ""
  echo "3. Dependencies already installed ✓"
fi

# Step 4: Run tests with proper configuration
echo ""
echo "4. Running tests..."
echo "───────────────────────────────────────────────"

# Run tests with simplified Jest config
npx jest \
  --config jest.config.js \
  --no-coverage \
  --forceExit \
  --maxWorkers=1 \
  --testTimeout=10000 \
  --verbose

EXIT_CODE=$?

echo "───────────────────────────────────────────────"
echo ""

if [ $EXIT_CODE -eq 0 ]; then
  echo "✅ All tests passed!"
else
  echo "❌ Some tests failed (exit code: $EXIT_CODE)"
  echo ""
  echo "Common issues:"
  echo "  - Check that backend/.env has OPENAI_API_KEY set"
  echo "  - Check that all dependencies are installed"
  echo "  - Review test output above for specific failures"
fi

echo ""
echo "═══════════════════════════════════════════════"

exit $EXIT_CODE
