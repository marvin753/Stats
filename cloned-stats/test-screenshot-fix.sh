#!/bin/bash

echo "================================================"
echo "  TESTING SCREENSHOT DEADLOCK FIX"
echo "================================================"
echo ""

# Kill any existing Stats processes
echo "1. Killing existing Stats processes..."
killall Stats 2>/dev/null
killall curl 2>/dev/null
sleep 1

# Start the app
echo "2. Starting Stats app..."
cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats
./run-swift.sh &
APP_PID=$!
echo "   App started with PID: $APP_PID"

# Wait for app to initialize
echo "3. Waiting for app to initialize..."
sleep 5

# Check if app is still running
if ps -p $APP_PID > /dev/null; then
    echo "   ✅ App is running"
else
    echo "   ❌ App crashed during startup"
    exit 1
fi

# Trigger screenshot with keyboard shortcut simulator
echo "4. Simulating Cmd+Option+O keyboard shortcut..."
osascript -e 'tell application "System Events" to keystroke "o" using {command down, option down}' 2>&1

# Wait a moment for screenshot processing
echo "5. Waiting for screenshot processing..."
sleep 3

# Check if app is still running (not crashed)
echo "6. Checking app status..."
if ps -p $APP_PID > /dev/null; then
    echo "   ✅ SUCCESS! App is still running - NO CRASH!"

    # Check if screenshot was saved
    echo "7. Checking for saved screenshots..."
    SCREENSHOT_DIR="$HOME/Library/Application Support/Stats/Screenshots"
    if [ -d "$SCREENSHOT_DIR" ]; then
        SCREENSHOT_COUNT=$(find "$SCREENSHOT_DIR" -name "*.png" 2>/dev/null | wc -l | xargs)
        echo "   Found $SCREENSHOT_COUNT screenshot(s) in: $SCREENSHOT_DIR"

        # Show latest screenshot if any
        LATEST=$(find "$SCREENSHOT_DIR" -name "*.png" -print0 2>/dev/null | xargs -0 ls -t | head -1)
        if [ ! -z "$LATEST" ]; then
            echo "   Latest screenshot: $(basename "$LATEST")"
        fi
    fi
else
    echo "   ❌ FAILED! App crashed with SIGTRAP"
    echo ""
    echo "Checking for crash report..."
    LATEST_CRASH=$(ls -t ~/Library/Logs/DiagnosticReports/Stats*.ips 2>/dev/null | head -1)
    if [ ! -z "$LATEST_CRASH" ]; then
        echo "   Crash report: $LATEST_CRASH"
        echo "   Created: $(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$LATEST_CRASH")"
    fi
fi

echo ""
echo "================================================"
echo "  TEST COMPLETE"
echo "================================================"

# Clean up - kill the test app
kill $APP_PID 2>/dev/null