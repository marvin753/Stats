#!/bin/bash
# Test screenshot capture with the CDP service

echo "Testing Chrome CDP Screenshot Service"
echo "======================================"
echo ""

# Test health check
echo "1. Health Check:"
curl -s http://localhost:9223/health | python3 -m json.tool
echo ""
echo ""

# Test targets listing
echo "2. Available Chrome Targets:"
curl -s http://localhost:9223/targets | python3 -m json.tool
echo ""
echo ""

# Capture screenshot
echo "3. Capturing Screenshot:"
RESPONSE=$(curl -s -X POST http://localhost:9223/capture-active-tab)

# Check if successful
if echo "$RESPONSE" | grep -q '"success":true'; then
    echo "✅ Screenshot captured successfully!"
    echo ""

    # Extract metadata (without the huge base64 image)
    echo "Screenshot Metadata:"
    echo "$RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f'  URL: {data.get(\"url\")}')
print(f'  Title: {data.get(\"title\")}')
print(f'  Dimensions: {data.get(\"dimensions\", {}).get(\"width\")}x{data.get(\"dimensions\", {}).get(\"height\")} px')
print(f'  Timestamp: {data.get(\"timestamp\")}')
print(f'  Image Size: {len(data.get(\"base64Image\", \"\"))} characters (base64)')
"
    echo ""

    # Optionally save the image
    echo "4. Save to file? (y/n)"
    read -t 5 -n 1 SAVE
    if [ "$SAVE" == "y" ]; then
        echo "$RESPONSE" | python3 -c "
import sys, json, base64
data = json.load(sys.stdin)
with open('screenshot.png', 'wb') as f:
    f.write(base64.b64decode(data['base64Image']))
print('\\n✅ Screenshot saved to screenshot.png')
"
    fi
else
    echo "❌ Screenshot capture failed!"
    echo ""
    echo "Error Details:"
    echo "$RESPONSE" | python3 -m json.tool
fi
