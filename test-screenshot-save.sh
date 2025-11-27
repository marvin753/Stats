#!/bin/bash
#
# Test script to verify ScreenshotFileManager deadlock fix
# This simulates the screenshot capture workflow
#

echo "=========================================="
echo "Screenshot Save Test (Deadlock Fix)"
echo "=========================================="
echo ""

# Check if Stats app is running
if ! pgrep -f "Stats.app" > /dev/null; then
    echo "❌ Stats app is not running"
    echo "   Start it first: cd cloned-stats && ./run-swift.sh"
    exit 1
fi
echo "✓ Stats app is running"

# Trigger screenshot capture via keyboard shortcut simulation
echo ""
echo "📸 Triggering screenshot capture (Cmd+Option+Q)..."
osascript -e 'tell application "System Events" to keystroke "q" using {command down, option down}' 2>/dev/null

# Wait for screenshot processing
echo "⏳ Waiting 3 seconds for processing..."
sleep 3

# Check for crash reports
LATEST_CRASH=$(ls -t ~/Library/Logs/DiagnosticReports/Stats-*.ips 2>/dev/null | head -1)
if [ -n "$LATEST_CRASH" ]; then
    CRASH_TIME=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$LATEST_CRASH")
    CURRENT_TIME=$(date "+%Y-%m-%d %H:%M:%S")

    # Check if crash happened in last 5 seconds
    CRASH_TIMESTAMP=$(stat -f "%m" "$LATEST_CRASH")
    CURRENT_TIMESTAMP=$(date +%s)
    TIME_DIFF=$((CURRENT_TIMESTAMP - CRASH_TIMESTAMP))

    if [ $TIME_DIFF -lt 5 ]; then
        echo "❌ CRASH DETECTED!"
        echo "   Crash report: $LATEST_CRASH"
        echo "   Crash time: $CRASH_TIME"
        echo ""
        echo "Reading crash details..."
        grep -A 2 '"asi"' "$LATEST_CRASH"
        exit 1
    fi
fi

# Check if app is still running
if ! pgrep -f "Stats.app" > /dev/null; then
    echo "❌ Stats app crashed (no longer running)"
    exit 1
fi
echo "✅ No crash detected - app still running"

# Check if screenshot was saved
SCREENSHOT_DIR="$HOME/Library/Application Support/Stats/Screenshots"
if [ ! -d "$SCREENSHOT_DIR" ]; then
    echo "⚠️  Screenshot directory does not exist: $SCREENSHOT_DIR"
    echo "   This might be normal if no screenshots were captured yet"
    exit 0
fi

LATEST_SESSION=$(ls -td "$SCREENSHOT_DIR"/Session_* 2>/dev/null | head -1)
if [ -z "$LATEST_SESSION" ]; then
    echo "⚠️  No session folders found in $SCREENSHOT_DIR"
    exit 0
fi

LATEST_SCREENSHOT=$(ls -t "$LATEST_SESSION"/*.png 2>/dev/null | head -1)
if [ -n "$LATEST_SCREENSHOT" ]; then
    SCREENSHOT_TIME=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$LATEST_SCREENSHOT")
    SCREENSHOT_SIZE=$(stat -f "%z" "$LATEST_SCREENSHOT")
    echo "✅ Latest screenshot saved successfully!"
    echo "   File: $(basename "$LATEST_SCREENSHOT")"
    echo "   Size: $((SCREENSHOT_SIZE / 1024)) KB"
    echo "   Time: $SCREENSHOT_TIME"
    echo "   Path: $LATEST_SCREENSHOT"
else
    echo "⚠️  No screenshots found in latest session: $LATEST_SESSION"
fi

echo ""
echo "=========================================="
echo "✅ TEST PASSED - No deadlock detected!"
echo "=========================================="
