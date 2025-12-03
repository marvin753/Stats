#!/bin/bash
# Run Stats Swift app from command line

cd "$(dirname "$0")"

APP_PATH="build/Build/Products/Debug/Stats.app/Contents/MacOS/Stats"

if [ ! -f "$APP_PATH" ]; then
  echo "❌ Stats app not built yet. Run ./build-swift.sh first"
  exit 1
fi

echo "🚀 Starting Stats app (DEBUG BUILD WITH LOGGING)..."
echo "📊 HTTP Server will run on port 8080"
echo "⌨️  Keyboard shortcuts: Cmd+Option+O (capture), Cmd+Option+P (process)"
echo "💡 GPU widget will show quiz answer numbers"
echo "🔍 Verbose logging enabled - watch for [KeyboardManager] and [QuizIntegration] messages"
echo ""

# Check if another Stats app is running
if lsof -i :8080 > /dev/null 2>&1; then
  echo "⚠️  WARNING: Port 8080 is already in use!"
  echo "   Another Stats instance may be running. Checking..."
  lsof -i :8080
  echo ""
  echo "❌ Please close the other Stats app first, then run this script again."
  exit 1
fi

# Run in foreground so logs appear in terminal
"$APP_PATH"
