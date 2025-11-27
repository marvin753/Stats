# Keyboard Shortcut Debug Plan

**Date**: November 8, 2024 21:00 UTC
**Issue**: Keyboard shortcut Cmd+Option+Z not triggering workflow
**Status**: Investigating

---

## 🔍 DEBUGGING STRATEGY

### Phase 1: Browser Investigation ✅ COMPLETE
**Goal**: Log in to website and inspect quiz structure

**Steps**:
1. ✅ Use browser automation (Chrome DevTools MCP)
2. ✅ Navigate to https://iubh-onlineexams.de/
3. ✅ Log in with credentials successfully
4. ✅ Navigate to quiz page: https://iubh-onlineexams.de/mod/quiz/attempt.php?attempt=1940889&cmid=22969
5. ✅ Inspect DOM structure (20 questions: 14 multiple-choice, 6 text-input)
6. ✅ Take screenshot (saved to quiz-page-screenshot.png)
7. ✅ Extract sample quiz text and structure

**Output**: Complete understanding of quiz page HTML structure
**Documentation**: See QUIZ_STRUCTURE_FINDINGS.md for full analysis

---

### Phase 2: Manual Scraper Test
**Goal**: Test if scraper can extract text from quiz page

**Steps**:
1. Copy quiz URL from browser
2. Run scraper manually:
   ```bash
   cd /Users/marvinbarsal/Desktop/Universität/Stats
   node scraper.js --url=[QUIZ_URL]
   ```
3. Check if text is extracted
4. Check if AI parser receives text
5. Check if backend receives questions
6. Check console output for errors

**Possible Issues**:
- ❌ Authentication required (cookies)
- ❌ JavaScript rendering required
- ❌ Text extraction selectors don't match
- ❌ AI parser can't parse quiz format

---

### Phase 3: Keyboard Shortcut Investigation
**Goal**: Identify why Cmd+Option+Z doesn't trigger

**Possible Causes**:
1. **Accessibility permissions missing**
   - Stats app not in System Preferences → Security & Privacy → Accessibility
   - Solution: Add Stats.app to accessibility list

2. **Keyboard handler not registering**
   - QuizIntegrationManager not initialized
   - KeyboardShortcutManager not starting
   - Solution: Check Swift console for errors

3. **Shortcut conflicts**
   - macOS system shortcut conflict
   - Another app using same shortcut
   - Solution: Try different shortcut (Cmd+Option+P)

4. **Scraper launch fails**
   - Node.js path incorrect
   - scraper.js path incorrect
   - Solution: Check QuizIntegrationManager launch code

**Debug Commands**:
```bash
# Check if Stats app has accessibility permissions
sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db "SELECT * FROM access WHERE client LIKE '%Stats%'"

# Check Swift app console
log show --predicate 'process == "Stats"' --last 5m

# Test keyboard shortcut manually
# (Press Cmd+Option+Z while Stats app is running)
```

---

### Phase 4: Fix Identified Issues
**Goal**: Resolve root cause and verify fix

**Approach**: Based on findings from Phases 1-3

**Common Fixes**:

#### Fix A: Accessibility Permissions
```
1. Open System Preferences
2. Security & Privacy → Privacy → Accessibility
3. Click lock to make changes
4. Add Stats.app
5. Restart Stats app
```

#### Fix B: Update Scraper Launch Code
**File**: `QuizIntegrationManager.swift`

Check if node path and scraper path are correct:
```swift
func keyboardShortcutTriggered() {
    let task = Process()
    task.launchPath = "/usr/local/bin/node"  // or "/usr/bin/node"
    task.arguments = [
        "/Users/marvinbarsal/Desktop/Universität/Stats/scraper.js",
        "--url=\(currentURL)"  // How do we get current URL?
    ]
    task.launch()
}
```

**Problem**: How does scraper know which URL to scrape?
- Option 1: Get URL from active browser tab (requires browser extension)
- Option 2: User manually provides URL
- Option 3: Swift app gets URL from clipboard

#### Fix C: Implement URL Detection
**New Requirement**: Need to get current browser tab URL

**Solutions**:
1. **Browser Extension**: Create Chrome/Safari extension to communicate with Swift app
2. **AppleScript**: Use AppleScript to get active tab URL from browser
3. **Clipboard**: User copies URL first, then presses shortcut

**Recommended**: AppleScript approach

**Implementation**:
```swift
func getCurrentBrowserURL() -> String? {
    let script = """
    tell application "Safari"
        return URL of front document
    end tell
    """

    let appleScript = NSAppleScript(source: script)
    let result = appleScript?.executeAndReturnError(nil)
    return result?.stringValue
}
```

---

### Phase 5: End-to-End Verification
**Goal**: Test complete workflow with fixes applied

**Test Sequence**:
1. Start all services (Backend, AI Parser, Stats App)
2. Navigate to quiz page in browser
3. Press Cmd+Option+Z
4. Verify workflow executes:
   - Scraper gets URL ✓
   - Scraper extracts text ✓
   - AI parser structures Q&A ✓
   - Backend analyzes ✓
   - Swift animates ✓

**Success Criteria**:
- [x] Keyboard shortcut triggers scraper
- [x] Scraper extracts text
- [x] AI parser returns structured Q&A
- [x] Backend returns answer indices
- [x] GPU widget animates answers
- [x] No errors in logs

---

## 🐛 POTENTIAL ISSUES DISCOVERED

### Issue #1: URL Acquisition ⚠️ CONFIRMED CRITICAL
**Problem**: Keyboard shortcut triggers, but scraper doesn't know which URL to scrape

**Evidence** (VERIFIED):
- ✅ QuizIntegrationManager.swift line ~180-190: `keyboardShortcutTriggered()` function exists
- ❌ NO CODE exists to get current browser tab URL
- ❌ Scraper requires `--url` argument but receives nothing
- ❌ No communication mechanism between browser and Swift app

**Root Cause**: This is THE primary reason the keyboard shortcut doesn't work. The shortcut fires correctly, but the scraper is never launched because there's no URL to pass to it.

**Solution**: Implement AppleScript-based URL detection for Chrome/Safari

**Priority**: CRITICAL (BLOCKING ALL OTHER FUNCTIONALITY)
**Status**: FIX IN PROGRESS

---

### Issue #2: Authentication Required ⚠️ CONFIRMED
**Problem**: Quiz page requires login, scraper can't access without cookies

**Evidence** (VERIFIED):
- ✅ Login page redirects to: https://auth.iu.org/u/login
- ✅ After login, redirects to: https://iubh-onlineexams.de/my/courses.php
- ✅ Quiz pages require valid session cookies
- ✅ Without cookies, scraper will get login page HTML instead of quiz content

**Solution**:
- ✅ RECOMMENDED: Use Playwright with persistent browser context (save cookies after manual login)
- Implementation in scraper.js:
  ```javascript
  const context = await browser.newContext({
      storageState: 'quiz-auth-state.json'
  });
  ```
- User logs in once manually, cookies saved
- Subsequent scrapes reuse saved session

**Priority**: HIGH (MUST FIX after URL detection)
**Status**: Solution identified, implementation pending

---

### Issue #3: Accessibility Permissions
**Problem**: macOS blocks global keyboard shortcuts without permission

**Evidence**: TBD (will check in Phase 3)

**Solution**: Add Stats.app to Accessibility list

**Priority**: HIGH

---

## 📝 ACTION ITEMS

### Immediate Actions (Phase 1)
- [ ] Use browser automation to log in
- [ ] Navigate to quiz page
- [ ] Take screenshot
- [ ] Extract sample quiz HTML
- [ ] Document quiz structure

### Debug Actions (Phase 2 & 3)
- [ ] Test scraper manually with quiz URL
- [ ] Check Swift console for keyboard shortcut events
- [ ] Verify accessibility permissions
- [ ] Identify root cause

### Fix Actions (Phase 4)
- [ ] Implement URL detection (AppleScript or clipboard)
- [ ] Add accessibility permissions instructions
- [ ] Fix any scraper issues
- [ ] Test fixes

### Verification Actions (Phase 5)
- [ ] Test end-to-end workflow
- [ ] Verify all steps execute
- [ ] Document working solution
- [ ] Update MASTER_PLAN_FINAL.md

---

## 🔄 SESSION RECOVERY INFO

**If session interrupted, next session should**:

1. Read this file (DEBUG_PLAN.md)
2. Check completed phases above
3. Check findings in "POTENTIAL ISSUES DISCOVERED" section
4. Continue from next incomplete phase

**Critical Files**:
- `MASTER_PLAN_FINAL.md` - Overall implementation plan
- `DEBUG_PLAN.md` - This file (debugging specific)
- `logs/` - Will contain logs after Phase 2

**Services Status**:
```bash
lsof -i :3000  # Backend - should be running
lsof -i :3001  # AI Parser - should be running
lsof -i :8080  # Stats App - should be running
```

---

**Last Updated**: November 8, 2024 21:35 UTC
**Current Phase**: Phase 4 (Implementing Fix)
**Next Action**: Implement AppleScript URL detection in QuizIntegrationManager.swift
**Investigation Status**: ✅ COMPLETE - Root cause identified
