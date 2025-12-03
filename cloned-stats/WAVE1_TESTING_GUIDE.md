# Wave 1 Testing Guide: OS-Level Hotkeys

## Quick Test Procedure

### 1. Build the App

```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats
xcodebuild -project Stats.xcodeproj \
  -scheme Stats \
  -configuration Debug \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath build \
  build
```

### 2. Run the App

```bash
open build/Build/Products/Debug/Stats.app
```

### 3. Grant Input Monitoring Permission (First Time Only)

**Expected Behavior**: On first launch, an alert will appear:

```
Input Monitoring Permission Required

Stats needs Input Monitoring permission to register
system-wide keyboard shortcuts.

To enable:
1. Open System Settings (or System Preferences)
2. Go to Privacy & Security → Input Monitoring
3. Enable 'Stats' in the list
4. Restart the Stats app
```

**Steps**:
1. Click "Open System Settings"
2. System Settings will open to Input Monitoring
3. Find "Stats" in the list
4. Toggle it ON (enable it)
5. Close System Settings
6. Quit Stats (Cmd+Q)
7. Relaunch Stats

### 4. Test OS-Level Hotkeys

#### Test Case 1: Screenshot Capture (Browser Focused)

**Objective**: Verify hotkey works when browser is focused

**Steps**:
1. Open Google Chrome or Safari
2. Navigate to any webpage
3. Click inside the browser window to focus it
4. Press **Cmd+Option+O**

**Expected Result**:
- Console shows: `⌨️  [KeyboardManager] Cmd+Option+O detected: Capture screenshot`
- Screenshot is captured
- Stats app does NOT need to be focused

**Pass/Fail**:
- [ ] PASS: Screenshot captured while browser was focused
- [ ] FAIL: Nothing happened (check permissions)

---

#### Test Case 2: Process Screenshots (Browser Focused)

**Objective**: Verify processing hotkey works when browser is focused

**Prerequisites**: At least 1 screenshot captured (Test Case 1)

**Steps**:
1. Keep browser focused (don't switch to Stats)
2. Press **Cmd+Option+P**

**Expected Result**:
- Console shows: `⌨️  [KeyboardManager] Cmd+Option+P detected: Process screenshots`
- Processing begins
- Stats app does NOT need to be focused

**Pass/Fail**:
- [ ] PASS: Processing started while browser was focused
- [ ] FAIL: Nothing happened (check permissions)

---

#### Test Case 3: Set Question Count (Browser Focused)

**Objective**: Verify question count hotkeys work when browser is focused

**Steps**:
1. Keep browser focused
2. Press **Cmd+Option+2**

**Expected Result**:
- Console shows: `⌨️  [KeyboardManager] Cmd+Option+2 detected: Set question count to 12`
- Question count is set to 12

**Pass/Fail**:
- [ ] PASS: Question count set while browser was focused
- [ ] FAIL: Nothing happened (check permissions)

---

#### Test Case 4: PDF Picker Placeholder (Browser Focused)

**Objective**: Verify PDF picker hotkey is registered

**Steps**:
1. Keep browser focused
2. Press **Cmd+Option+L**

**Expected Result**:
- Console shows:
  ```
  ⌨️  [KeyboardManager] Cmd+Option+L detected: Open PDF file picker
     (PDF picker not yet implemented)
  ```

**Pass/Fail**:
- [ ] PASS: Hotkey detected (even though not implemented)
- [ ] FAIL: Nothing happened (check permissions)

---

#### Test Case 5: Event Tap Auto-Recovery

**Objective**: Verify event tap re-enables if disabled by macOS

**Steps**:
1. Leave app running for 10 minutes
2. Press hotkeys periodically (every 2-3 minutes)
3. Watch console for auto-recovery messages

**Expected Result** (if event tap becomes inactive):
- Console shows:
  ```
  ⚠️  [KeyboardManager] Event tap became inactive - re-enabling...
  ```
- Hotkeys continue working after recovery

**Pass/Fail**:
- [ ] PASS: Event tap auto-recovered
- [ ] N/A: Event tap never became inactive (also acceptable)
- [ ] FAIL: Event tap became inactive and didn't recover

---

## Console Output Reference

### Successful Startup

```
🔧 [KeyboardManager] Initialized for OS-level keyboard shortcuts
   Supported: Cmd+Option+O (capture), Cmd+Option+P (process), Cmd+Option+L (PDF picker)
   Question counts: Cmd+Option+0-5 (10-15 questions)
✅ [KeyboardManager] Delegate set: QuizIntegrationManager
🔧 [KeyboardManager] Starting OS-level keyboard shortcut registration...
🔧 [KeyboardManager] Monitoring for:
   - Cmd+Option+O: Capture screenshot
   - Cmd+Option+P: Process all screenshots
   - Cmd+Option+L: Open PDF file picker
   - Cmd+Option+0-5: Set expected question count (10-15)
🔐 [KeyboardManager] Input Monitoring permission check:
   Status: ✅ GRANTED
✅ [KeyboardManager] OS-level keyboard shortcuts registered successfully
   Event tap: <CFMachPort 0x600000e44100>
   Run loop source: <CFRunLoopSource 0x600001524900>
   ✓ Hotkeys will work even when browser is focused
```

### Permission Denied

```
🔐 [KeyboardManager] Input Monitoring permission check:
   Status: ❌ DENIED or NOT CHECKED

⚠️  Input Monitoring permission NOT granted!
   To enable:
   1. Open System Settings (System Preferences on older macOS)
   2. Go to: Privacy & Security → Input Monitoring
   3. Find 'Stats' in the list and enable it
   4. Restart the Stats app

⚠️  [KeyboardManager] Registration will fail due to missing Input Monitoring permissions
[Alert dialog appears]
```

### Hotkey Detected

```
⌨️  [KeyboardManager] Cmd+Option+O detected: Capture screenshot
================================================================
📸 [QuizIntegration] CAPTURE SCREENSHOT (Cmd+Option+O)
================================================================
✅ Screenshot 1 captured successfully
```

---

## Troubleshooting

### Issue: Hotkeys not working at all

**Diagnosis Steps**:

1. Check console for error messages
2. Verify Input Monitoring permission:
   - Open System Settings
   - Go to Privacy & Security → Input Monitoring
   - Confirm Stats is in the list and enabled
3. Restart the app after granting permission

**Resolution**:
```bash
# Restart the app
pkill Stats
open build/Build/Products/Debug/Stats.app
```

---

### Issue: "Event tap creation failed" error

**Console Output**:
```
❌ [KeyboardManager] ERROR: Failed to create event tap!
   This usually means Input Monitoring permissions are denied.
   Check: System Settings → Privacy & Security → Input Monitoring
```

**Resolution**:
1. Open System Settings
2. Go to Privacy & Security → Input Monitoring
3. Remove Stats from the list (click the minus button)
4. Close System Settings
5. Relaunch Stats
6. Alert will appear asking to grant permission
7. Click "Open System Settings"
8. Enable Stats in the list

---

### Issue: Hotkeys work in Stats but not in browser

**This means**: Event tap is not working correctly

**Diagnosis**:
1. Check if Input Monitoring permission is granted
2. Look for event tap creation success in console
3. Verify console shows: `✓ Hotkeys will work even when browser is focused`

**Resolution**:
1. Verify permissions
2. Rebuild app with latest code
3. Restart app

---

### Issue: App crashes when pressing hotkey

**Possible Causes**:
- Delegate not set
- Delegate methods not implemented
- Memory issue

**Diagnosis**:
1. Check console for crash log
2. Look for delegate set message: `✅ [KeyboardManager] Delegate set`
3. Verify QuizIntegrationManager implements delegate methods

---

## Performance Testing

### CPU Usage

**Test**: Monitor CPU usage while app is running

**Steps**:
1. Open Activity Monitor
2. Find "Stats" process
3. Monitor CPU usage for 5 minutes

**Expected Result**:
- CPU usage: < 1% when idle
- CPU usage: < 5% when hotkey pressed

**Pass/Fail**:
- [ ] PASS: CPU usage within expected range
- [ ] FAIL: CPU usage abnormally high

---

### Memory Usage

**Test**: Monitor memory usage while app is running

**Steps**:
1. Open Activity Monitor
2. Find "Stats" process
3. Monitor memory usage for 10 minutes

**Expected Result**:
- Memory usage: ~150-200 MB
- No memory leaks (usage stays stable)

**Pass/Fail**:
- [ ] PASS: Memory usage stable
- [ ] FAIL: Memory usage increasing over time (leak)

---

## Edge Cases

### Test: Multiple rapid hotkey presses

**Steps**:
1. Press Cmd+Option+O 10 times rapidly
2. Check console for all events detected

**Expected Result**:
- All 10 presses detected
- No crashes or hangs
- Screenshots captured for each press

---

### Test: Hotkey press while Stats is quitting

**Steps**:
1. Start quitting Stats (Cmd+Q)
2. Immediately press Cmd+Option+O

**Expected Result**:
- Either: Event processed normally
- Or: Event ignored (app shutting down)
- No crash

---

### Test: Permission revoked while app running

**Steps**:
1. Run app with permission granted
2. Open System Settings
3. Disable Stats in Input Monitoring
4. Press Cmd+Option+O

**Expected Result**:
- Console shows: `⚠️  [KeyboardManager] Event tap was disabled`
- Event tap attempts to re-enable
- May require app restart

---

## Success Criteria

All test cases must pass for Wave 1 to be considered complete:

- [x] Build succeeds without compilation errors
- [ ] App launches successfully
- [ ] Input Monitoring permission requested on first launch
- [ ] Cmd+Option+O works when browser is focused
- [ ] Cmd+Option+P works when browser is focused
- [ ] Cmd+Option+0-5 works when browser is focused
- [ ] Cmd+Option+L is registered (placeholder)
- [ ] Event tap auto-recovery works (or N/A)
- [ ] No memory leaks during extended use
- [ ] CPU usage within acceptable range
- [ ] No crashes during normal operation

---

## Post-Testing Cleanup

After testing, you can remove the test build:

```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats
rm -rf build
```

---

## Reporting Issues

If any test fails, document:

1. **Test case number** (e.g., Test Case 1)
2. **Expected behavior** (from test case)
3. **Actual behavior** (what happened)
4. **Console output** (copy/paste relevant lines)
5. **macOS version** (System Settings → General → About)
6. **Steps to reproduce** (detailed)

Example issue report:

```
Test Case: 1 (Screenshot Capture)
Expected: Screenshot captured while browser focused
Actual: Nothing happened, no console output
Console: [Empty - no KeyboardManager messages]
macOS: 14.5
Steps:
1. Launched app
2. Opened Chrome
3. Pressed Cmd+Option+O
4. Nothing happened
```

---

## Next Steps After Testing

Once all tests pass:

1. Commit changes to git
2. Document any issues found
3. Proceed to Wave 2 (PDF File Picker)
4. Update CLAUDE.md with Wave 1 completion status
