# Security Test Guide - Chrome CDP Service

**Quick Reference for Wave 3B Security Validation**

---

## 1. Quick Validation (5 minutes)

### Start Service
```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/chrome-cdp-service
npm start
```

Expected output:
```
✓ Chrome already running with remote debugging on port 9222
✅ Express server running on http://localhost:9223
```

### Open Test Page
```bash
open anti-bot-test.html
```

**Expected Result:**
- Pass rate: > 90%
- Green "STEALTH MODE FULLY ACTIVE" banner
- Security assessment: "EXCELLENT" or "GOOD"

---

## 2. Core Stealth Checks (Browser Console)

Open Chrome DevTools (Cmd+Option+I) and run:

```javascript
// Test 1: navigator.webdriver (CRITICAL)
console.log('navigator.webdriver:', navigator.webdriver);
// Expected: undefined ✅

// Test 2: chrome.runtime
console.log('chrome.runtime:', window.chrome?.runtime);
// Expected: undefined ✅

// Test 3: User agent
console.log('User agent:', navigator.userAgent);
// Expected: No "HeadlessChrome" ✅

// Test 4: Webdriver attribute
console.log('webdriver attribute:', document.documentElement.getAttribute('webdriver'));
// Expected: null ✅

// Test 5: Plugins
console.log('Plugins:', navigator.plugins.length);
// Expected: > 0 ✅
```

---

## 3. Screenshot Metadata Test

### Capture Screenshot
```bash
# Capture active tab
curl -X POST http://localhost:9223/capture-active-tab > screenshot-response.json

# Extract image
cat screenshot-response.json | jq -r '.base64Image' | base64 -D > test-screenshot.png
```

### Check Metadata
```bash
# Install exiftool if needed
# brew install exiftool

# Check metadata
exiftool test-screenshot.png
```

**Expected Output:**
```
File Name                       : test-screenshot.png
File Type                       : PNG
Image Width                     : 1920
Image Height                    : 1080
Bit Depth                       : 8
Color Type                      : RGB
Compression                     : Deflate/Inflate
```

**MUST NOT contain:**
- Software name
- Chrome version
- CDP markers
- Timestamp
- Tool signatures

---

## 4. Network Traffic Test

### Monitor Localhost Traffic
```bash
# Start monitoring (requires sudo)
sudo tcpdump -i lo0 -n -s 0 -w cdp-traffic.pcap port 9222 or port 9223

# In another terminal, capture screenshot
curl -X POST http://localhost:9223/capture-active-tab

# Stop monitoring (Ctrl+C)

# Analyze
tcpdump -r cdp-traffic.pcap -A | head -50
```

**Expected:**
- ✅ Only localhost (127.0.0.1) traffic
- ✅ No external DNS queries
- ✅ No HTTP requests to websites
- ✅ Only CDP WebSocket communication

---

## 5. Real-World Test Scenario

### Test on Actual Website

1. **Open target website in Chrome:**
   ```bash
   open -a "Google Chrome" "https://iubh-onlineexams.de"
   ```

2. **Capture screenshot:**
   ```bash
   curl -X POST http://localhost:9223/capture-active-tab -o quiz-screenshot.json
   ```

3. **Verify success:**
   ```bash
   cat quiz-screenshot.json | jq '.success, .url, .dimensions'
   ```

4. **Check for detection:**
   - Website should function normally
   - No anti-bot warnings
   - No CAPTCHA challenges
   - No access denied errors

---

## 6. Continuous Detection Testing

### Automated Test Script

Create `test-stealth.sh`:
```bash
#!/bin/bash

echo "=== Chrome CDP Stealth Test ==="

# 1. Check service is running
if ! curl -s http://localhost:9223/health > /dev/null; then
  echo "❌ Service not running"
  exit 1
fi
echo "✅ Service running"

# 2. Open test page and wait
open anti-bot-test.html
sleep 3

# 3. Capture screenshot
curl -s -X POST http://localhost:9223/capture-active-tab > /tmp/test.json

# 4. Check success
if jq -e '.success == true' /tmp/test.json > /dev/null; then
  echo "✅ Screenshot captured successfully"
else
  echo "❌ Screenshot failed"
  exit 1
fi

# 5. Extract and check metadata
jq -r '.base64Image' /tmp/test.json | base64 -D > /tmp/test.png
METADATA=$(exiftool /tmp/test.png | grep -i "chrome\|cdp\|automation\|puppeteer\|playwright")

if [ -z "$METADATA" ]; then
  echo "✅ Metadata clean (no tool signatures)"
else
  echo "❌ Metadata contains tool signatures:"
  echo "$METADATA"
  exit 1
fi

echo ""
echo "🎉 All stealth tests passed!"
```

Run:
```bash
chmod +x test-stealth.sh
./test-stealth.sh
```

---

## 7. Detection Risk Checklist

Use this checklist before production deployment:

```
Core Detection Vectors:
[ ] navigator.webdriver is undefined
[ ] window.chrome.runtime is undefined
[ ] No "webdriver" attribute in DOM
[ ] User agent contains no automation markers
[ ] navigator.plugins.length > 0
[ ] navigator.languages is populated

Screenshot Security:
[ ] PNG metadata contains no tool names
[ ] No Chrome version in metadata
[ ] No timestamp in metadata
[ ] No EXIF data present

Network Security:
[ ] All traffic is localhost-only
[ ] No external DNS queries
[ ] No HTTP requests to target site
[ ] WebSocket only to localhost:9222

Operational Security:
[ ] Service runs on trusted network
[ ] Chrome launched with stealth flags
[ ] No console errors or warnings
[ ] Captures complete successfully
```

---

## 8. Troubleshooting Detection Issues

### Issue: navigator.webdriver is true

**Solution:**
```bash
# Check Chrome launch flags
ps aux | grep chrome | grep "disable-blink-features"

# Should show: --disable-blink-features=AutomationControlled

# If not, restart service:
npm start
```

### Issue: Screenshot metadata contains tool names

**Diagnosis:**
```bash
exiftool test.png | grep -i "Software"
```

**Solution:** This should NOT happen with Chrome CDP. If it does, verify you're using `Page.captureScreenshot()` and not external screenshot tools.

### Issue: External network requests detected

**Diagnosis:**
```bash
# Monitor for 10 seconds during capture
timeout 10 sudo tcpdump -i en0 -n not host 127.0.0.1
```

**Solution:** Verify Chrome launch flags include:
- `--disable-background-networking`
- `--disable-breakpad`
- `--metrics-recording-only`

### Issue: Anti-bot test page shows failures

**Action:**
1. Open browser console (Cmd+Option+I)
2. Look for red "FAIL" entries
3. Check which specific test failed
4. Refer to SECURITY_AUDIT_REPORT.md section 6.3 for details

---

## 9. Monthly Security Review

### Checklist for Ongoing Monitoring

**Every Month:**
1. Run anti-bot-test.html and verify > 90% pass rate
2. Check Chrome version: `chrome://version`
3. Update user agent if Chrome updated
4. Review Chrome security blog for CDP changes
5. Test on target websites for detection

**Every Quarter:**
1. Re-read SECURITY_AUDIT_REPORT.md
2. Check for new anti-bot techniques
3. Update detection test page if needed
4. Rotate user agent string

**Every 6 Months:**
1. Full security re-audit
2. Update documentation
3. Review sandbox flag requirement
4. Consider implementing enhancements from section 8.2

---

## 10. Quick Commands Reference

```bash
# Start service
npm start

# Health check
curl http://localhost:9223/health

# Capture screenshot
curl -X POST http://localhost:9223/capture-active-tab

# Open stealth verification
open verify-stealth.html

# Open comprehensive test
open anti-bot-test.html

# Check screenshot metadata
exiftool test.png

# Monitor network
sudo tcpdump -i lo0 port 9222 or port 9223

# Kill Chrome
pkill -f "Chrome.*remote-debugging-port"

# Restart service
npm start
```

---

## Expected Results Summary

| Test | Expected | Pass Criteria |
|------|----------|---------------|
| **anti-bot-test.html** | > 90% pass rate | Green banner |
| **navigator.webdriver** | undefined | ✅ |
| **Screenshot metadata** | Clean PNG | No tool signatures |
| **Network traffic** | Localhost only | No external requests |
| **Core detection** | 7/7 pass | All green |
| **Advanced detection** | 7/8 pass | Minimal failures |
| **Timing tests** | 3/3 pass | All green |

---

## Support

**Documentation:**
- Full audit: `SECURITY_AUDIT_REPORT.md`
- Installation: `INSTALLATION.md`
- Quick reference: `QUICK_REFERENCE.md`

**Test Files:**
- `verify-stealth.html` - Basic stealth check (4 tests)
- `anti-bot-test.html` - Comprehensive detection tests (18 tests)

**Status Check:**
```bash
# Quick validation
curl http://localhost:9223/health && \
open anti-bot-test.html && \
echo "✅ Security tests launched"
```

---

**Last Updated:** November 13, 2025
**Audit Version:** 1.0
**Detection Risk:** 🟢 LOW
**Production Status:** ✅ APPROVED
