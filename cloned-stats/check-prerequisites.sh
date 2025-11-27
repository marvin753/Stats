#!/bin/bash
# check-prerequisites.sh
# Environment validation script for Quiz Stats Animation System

# Colors for output (if terminal supports them)
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  NC='\033[0m' # No Color
else
  RED=''
  GREEN=''
  YELLOW=''
  NC=''
fi

# Track if any critical checks fail
CRITICAL_FAILURE=0

echo ""
echo "🔍 Checking Quiz Stats System Prerequisites..."
echo ""

# 1. Check Node.js installation
if command -v node &> /dev/null; then
  NODE_VERSION=$(node --version)
  MAJOR_VERSION=$(echo $NODE_VERSION | cut -d'.' -f1 | sed 's/v//')

  if [ "$MAJOR_VERSION" -ge 18 ]; then
    echo -e "${GREEN}✅${NC} Node.js $NODE_VERSION installed"
  else
    echo -e "${RED}❌${NC} Node.js version too old ($NODE_VERSION). Requires v18.0.0 or higher"
    echo "   Install from https://nodejs.org/"
    CRITICAL_FAILURE=1
  fi
else
  echo -e "${RED}❌${NC} Node.js not found. Install from nodejs.org (requires v18+)"
  CRITICAL_FAILURE=1
fi

# 2. Check npm installation
if command -v npm &> /dev/null; then
  NPM_VERSION=$(npm --version)
  NPM_MAJOR=$(echo $NPM_VERSION | cut -d'.' -f1)

  if [ "$NPM_MAJOR" -ge 9 ]; then
    echo -e "${GREEN}✅${NC} npm v$NPM_VERSION installed"
  else
    echo -e "${YELLOW}⚠️${NC}  npm version $NPM_VERSION (recommend v9.0.0 or higher)"
  fi
else
  echo -e "${RED}❌${NC} npm not found. Install Node.js (includes npm)"
  CRITICAL_FAILURE=1
fi

# 3. Check Xcode command line tools
if xcode-select -p &> /dev/null; then
  XCODE_PATH=$(xcode-select -p)
  echo -e "${GREEN}✅${NC} Xcode command line tools found at: $XCODE_PATH"
else
  echo -e "${RED}❌${NC} Xcode command line tools not found. Run: xcode-select --install"
  CRITICAL_FAILURE=1
fi

# 4. Check xcodebuild availability
if command -v xcodebuild &> /dev/null; then
  XCODEBUILD_VERSION=$(xcodebuild -version | head -n 1)
  echo -e "${GREEN}✅${NC} $XCODEBUILD_VERSION available"
else
  echo -e "${RED}❌${NC} xcodebuild not found. Verify Xcode installation"
  CRITICAL_FAILURE=1
fi

# 5. Check OpenAI API key configuration
BACKEND_ENV_PATH="$(dirname "$0")/../backend/.env"

if [ -f "$BACKEND_ENV_PATH" ]; then
  if grep -q "^OPENAI_API_KEY=sk-" "$BACKEND_ENV_PATH" 2>/dev/null; then
    echo -e "${GREEN}✅${NC} OpenAI API key configured"
  else
    echo -e "${RED}❌${NC} OpenAI API key not configured properly in backend/.env"
    echo "   Expected format: OPENAI_API_KEY=sk-..."
    echo "   Copy backend/.env.example to backend/.env and add your key"
    CRITICAL_FAILURE=1
  fi
else
  echo -e "${RED}❌${NC} OpenAI API key not configured. Copy backend/.env.example to backend/.env and add your key"
  echo "   File not found: $BACKEND_ENV_PATH"
  CRITICAL_FAILURE=1
fi

# 6. Check backend dependencies installed
BACKEND_NODE_MODULES="$(dirname "$0")/../backend/node_modules"

if [ -d "$BACKEND_NODE_MODULES" ]; then
  echo -e "${GREEN}✅${NC} Backend dependencies installed"
else
  echo -e "${YELLOW}⚠️${NC}  Backend dependencies not installed. Run: cd backend && npm install"
fi

# 7. Check build scripts are executable
BUILD_SCRIPT="$(dirname "$0")/build-swift.sh"
RUN_SCRIPT="$(dirname "$0")/run-swift.sh"

if [ -x "$BUILD_SCRIPT" ]; then
  echo -e "${GREEN}✅${NC} build-swift.sh is executable"
else
  echo -e "${YELLOW}⚠️${NC}  build-swift.sh not executable. Run: chmod +x build-swift.sh"
fi

if [ -x "$RUN_SCRIPT" ]; then
  echo -e "${GREEN}✅${NC} run-swift.sh is executable"
else
  echo -e "${YELLOW}⚠️${NC}  run-swift.sh not executable. Run: chmod +x run-swift.sh"
fi

echo ""

# Final summary
if [ $CRITICAL_FAILURE -eq 0 ]; then
  echo -e "${GREEN}✅ All prerequisites met! Ready to develop.${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Press Cmd+Shift+B in VS Code to build the Swift app"
  echo "  2. Run 'Terminal > Run Task > Full System Launch' to start everything"
  echo "  3. Press Cmd+Option+Q to trigger quiz automation"
  echo ""
  exit 0
else
  echo -e "${RED}❌ Some prerequisites are missing. Fix the errors above and run this script again.${NC}"
  echo ""
  exit 1
fi
