# Manual Testing Checklist - Screenshot Quiz Extraction

**Purpose**: Step-by-step checklist for manual testing session
**Date**: 2025-11-10
**Duration**: 15-30 minutes
**Prerequisites**: Backend running, Stats app compiled

---

## Pre-Test Setup

### Step 1: Check System Permissions

- [ ] Open System Preferences
- [ ] Go to: Privacy & Security > Screen Recording
- [ ] Verify "Stats.app" is in the list
- [ ] Enable checkbox for Stats.app
- [ ] Note: If not present, will be added on first capture attempt

### Step 2: Start Backend Server

```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/backend
npm start
```

**Expected Output**:
```
✅ Backend server running on http://localhost:3000
✅ OpenAI configured
```

- [ ] Backend started successfully
- [ ] No errors in console
- [ ] Port 3000 listening

**Quick Test**:
```bash
curl http://localhost:3000/health
```
- [ ] Returns `{"status":"ok","openai_configured":true}`

---

### Step 3: Start Stats App

```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats
./run-swift.sh
```

**Expected Output**:
```
Starting Stats app...
[Timestamp] HTTP server started on port 8080
[Timestamp] Keyboard shortcuts registered
[Timestamp] GPU module initialized
```

- [ ] Stats app launched
- [ ] No crash or error messages
- [ ] Menu bar icon visible (Stats app)
- [ ] GPU widget visible in menu bar

**Quick Test**:
```bash
curl http://localhost:8080
```
- [ ] Returns response (any 200 OK or similar)
- [ ] **NOTE**: If fails, this is the known issue - proceed with caution

---

### Step 4: Open Quiz Page

**Option A**: Use IUBH quiz platform
```
URL: https://iubh-onlineexams.de/mod/quiz/attempt.php?attempt=1941403&cmid=22969
```

**Option B**: Use test page with quiz-like content
```
URL: https://www.w3schools.com/quiztest/
```

**Option C**: Create test HTML file with quiz questions

- [ ] Browser opened
- [ ] Quiz page loaded
- [ ] Questions visible on screen
- [ ] Answers clearly displayed

---

## Test Sequence 1: Single Screenshot Capture

### Test 1.1: First Screenshot

**Action**: Press **Cmd+Shift+K**

**Expected Behavior**:
- [ ] No visible feedback (silent capture)
- [ ] No camera shutter sound
- [ ] No flash or screen dimming
- [ ] Console output: `"📸 Screenshot captured (1/20)"`

**If Permission Prompt Appears**:
- [ ] Click "Open System Preferences"
- [ ] Enable Screen Recording for Stats.app
- [ ] Return to test, press Cmd+Shift+K again

**Troubleshooting**:
- If nothing happens: Check console for errors
- If "Permission Denied": Enable Screen Recording permission
- If app crashes: Check build logs for compilation issues

---

### Test 1.2: Verify Screenshot Count

**Check Console Output**:
```
Expected: 📸 Screenshot captured (1/20)
```

- [ ] Count shows "1/20"
- [ ] No error messages
- [ ] App remains responsive

---

## Test Sequence 2: Multiple Screenshot Capture

### Test 2.1: Scroll and Capture

**Actions**:
1. Scroll down on quiz page to see more questions
2. Press **Cmd+Shift+K** again

**Expected Behavior**:
- [ ] Console output: `"📸 Screenshot captured (2/20)"`
- [ ] Count incremented to 2
- [ ] No lag or freeze

---

### Test 2.2: Rapid Capture Test

**Actions**: Press Cmd+Shift+K three more times (quickly)

**Expected Console Output**:
```
📸 Screenshot captured (3/20)
📸 Screenshot captured (4/20)
📸 Screenshot captured (5/20)
```

- [ ] All captures registered
- [ ] Count increments correctly
- [ ] No skipped captures
- [ ] No duplicate counts

---

### Test 2.3: Capacity Warning Test (Optional)

**Action**: Press Cmd+Shift+K 15 more times to approach limit

**Expected Behavior**:
- [ ] At 15/20: Warning message about approaching limit
- [ ] At 20/20: Cannot capture more
- [ ] Console shows capacity message

---

## Test Sequence 3: Batch Processing

### Test 3.1: Process Screenshots

**Current State**: Should have 5+ screenshots captured

**Action**: Press **Cmd+Shift+P**

**Expected Console Output** (in order):
```
🚀 Processing 5 screenshots...
📤 Sending to OpenAI Vision API...
[Wait 10-30 seconds]
✅ Extracted X questions from screenshots
📊 Backend analysis starting...
✅ Received answer indices: [3, 2, 4, ...]
🎬 Animation started
```

**Checklist**:
- [ ] "Processing" message appears immediately
- [ ] "Sending to OpenAI" message shows
- [ ] Wait period (10-30 seconds) - no freeze
- [ ] "Extracted X questions" message appears
- [ ] Backend analysis message shows
- [ ] "Animation started" message appears

**If Errors Occur**:
- Network Error: Check internet connection
- API Error: Check OpenAI API key and quota
- Timeout: Wait longer (API can be slow)
- Backend Error: Check backend console logs

---

### Test 3.2: Backend Verification

**Check Backend Console** (in backend terminal):

**Expected Logs**:
```
POST /api/analyze - Status: 200
OpenAI API request: 5 questions
OpenAI API response: [3, 2, 4, ...]
Sending to Stats app: http://localhost:8080/display-answers
```

- [ ] Backend received request
- [ ] OpenAI API called successfully
- [ ] Answer indices extracted
- [ ] Posted to Stats app

**If HTTP Server Issue Exists**:
- May see: "Connection refused to localhost:8080"
- This is the known issue from automated tests
- Animation will NOT start

---

## Test Sequence 4: Animation Verification

### Test 4.1: GPU Widget Animation

**What to Watch**: Menu bar GPU widget

**Expected Animation Sequence** (for answers [3, 2, 4]):

**Answer 1 (3)**:
- [ ] Widget shows: 0
- [ ] Animates: 0 → 1 → 2 → 3 (smooth, 1.5 seconds)
- [ ] Displays: 3 (steady for 10 seconds)
- [ ] Animates: 3 → 2 → 1 → 0 (smooth, 1.5 seconds)
- [ ] Rests: 0 (steady for 15 seconds)

**Answer 2 (2)**:
- [ ] Animates: 0 → 1 → 2 (smooth, 1.5 seconds)
- [ ] Displays: 2 (steady for 10 seconds)
- [ ] Animates: 2 → 1 → 0 (smooth, 1.5 seconds)
- [ ] Rests: 0 (steady for 15 seconds)

**Answer 3 (4)**:
- [ ] Animates: 0 → 1 → 2 → 3 → 4 (smooth, 1.5 seconds)
- [ ] Displays: 4 (steady for 10 seconds)
- [ ] Animates: 4 → 3 → 2 → 1 → 0 (smooth, 1.5 seconds)
- [ ] Rests: 0 (steady for 15 seconds)

**Final Sequence**:
- [ ] Animates: 0 → 10 (smooth, 1.5 seconds)
- [ ] Displays: 10 (steady for 15 seconds)
- [ ] Returns to: 0 (permanent)

---

### Test 4.2: Animation Timing Verification

**Use Stopwatch**:

**Timing Checkpoints**:
- [ ] Animation up: 1.5 seconds (±0.2s)
- [ ] Display duration: 10 seconds (±0.5s)
- [ ] Animation down: 1.5 seconds (±0.2s)
- [ ] Rest duration: 15 seconds (±0.5s)
- [ ] Final display: 15 seconds (±0.5s)

**Total Time** (for 3 answers):
- Expected: ~90 seconds
- [ ] Actual: _______ seconds

---

### Test 4.3: Visual Quality

**Animation Smoothness**:
- [ ] No stuttering or lag
- [ ] Smooth transitions (60 FPS)
- [ ] Numbers clearly visible
- [ ] No visual glitches

**Widget Behavior**:
- [ ] Stays in menu bar
- [ ] Doesn't flicker
- [ ] Readable at all values (0-10)
- [ ] Returns to normal after completion

---

## Test Sequence 5: Edge Cases

### Test 5.1: Cancel During Capture

**Actions**:
1. Capture 2 screenshots (Cmd+Shift+K twice)
2. Wait 5 seconds
3. Quit Stats app (Cmd+Q)
4. Restart app

**Expected Behavior**:
- [ ] App restarts cleanly
- [ ] Screenshot count resets to 0
- [ ] No crash or data corruption

---

### Test 5.2: Cancel During Processing

**Actions**:
1. Capture screenshots
2. Press Cmd+Shift+P to process
3. **Immediately** quit app (Cmd+Q) before API returns

**Expected Behavior**:
- [ ] App quits gracefully
- [ ] No hanging processes
- [ ] Backend doesn't crash
- [ ] Can restart cleanly

---

### Test 5.3: Network Failure Simulation

**Actions**:
1. Disconnect from internet
2. Capture screenshots (Cmd+Shift+K)
3. Press Cmd+Shift+P to process

**Expected Behavior**:
- [ ] Captures still work (offline)
- [ ] Processing shows error: "Network error"
- [ ] App remains responsive
- [ ] Can retry after reconnecting

---

### Test 5.4: Invalid Quiz Page

**Actions**:
1. Navigate to non-quiz page (e.g., Google homepage)
2. Capture screenshot
3. Process

**Expected Behavior**:
- [ ] Capture works
- [ ] OpenAI Vision returns "No questions found"
- [ ] App handles gracefully (no crash)
- [ ] Clear error message to user

---

## Test Sequence 6: Performance & Stress Testing

### Test 6.1: Maximum Capacity Test

**Actions**: Capture exactly 20 screenshots

**Expected Behavior**:
- [ ] Can capture all 20
- [ ] Warning at 15/20
- [ ] 21st capture rejected with message
- [ ] Processing works with 20 images

---

### Test 6.2: Large Screenshot Test

**Actions**:
1. Set browser to full screen (F11)
2. Capture screenshot (larger file size)

**Expected Behavior**:
- [ ] Capture succeeds
- [ ] Base64 encoding works
- [ ] API accepts large image
- [ ] No timeout or memory issues

---

### Test 6.3: Rapid Workflow Test

**Actions**: Complete workflow 3 times in succession

**Expected Behavior**:
- [ ] First workflow completes successfully
- [ ] Can immediately start second workflow
- [ ] No memory leaks (check Activity Monitor)
- [ ] Performance doesn't degrade

---

## Post-Test Analysis

### Collect Logs

**Backend Logs**:
```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/backend
# Check console output for errors
```
- [ ] No critical errors
- [ ] All API calls logged
- [ ] Response times reasonable

**Stats App Logs**:
```bash
# Check terminal where app is running
./run-swift.sh 2>&1 | tee test-session.log
```
- [ ] No crash logs
- [ ] All operations logged
- [ ] Timestamps present

---

### Performance Metrics

**Measure and Record**:

| Metric | Target | Actual | Pass/Fail |
|--------|--------|--------|-----------|
| Screenshot capture time | < 1s | ___s | ☐ |
| OpenAI Vision API (5 images) | 10-30s | ___s | ☐ |
| Backend analysis | < 5s | ___s | ☐ |
| Animation smoothness | 60 FPS | Visual | ☐ |
| Total end-to-end | < 60s | ___s | ☐ |
| Memory usage | < 300MB | ___MB | ☐ |
| CPU usage (idle) | < 5% | ___% | ☐ |
| CPU usage (processing) | < 50% | ___% | ☐ |

---

### Answer Accuracy Test

**Validation**:
1. Manually read quiz questions
2. Identify correct answers
3. Compare with extracted answers

**Accuracy Tracking**:
- Total questions: ______
- Correctly identified: ______
- Accuracy: ______%
- [ ] Accuracy > 90% (acceptable)

---

## Issues Found During Testing

### Issue Log

**Issue #1**:
- Description: _________________________________
- Severity: Critical / High / Medium / Low
- Steps to reproduce: _______________________
- Expected: ________________________________
- Actual: __________________________________

**Issue #2**:
- Description: _________________________________
- Severity: Critical / High / Medium / Low
- Steps to reproduce: _______________________
- Expected: ________________________________
- Actual: __________________________________

**Issue #3**:
- Description: _________________________________
- Severity: Critical / High / Medium / Low
- Steps to reproduce: _______________________
- Expected: ________________________________
- Actual: __________________________________

---

## Final Checklist

### Core Functionality

- [ ] Cmd+Shift+K captures screenshots
- [ ] Screenshot count increments correctly
- [ ] Cmd+Shift+P triggers processing
- [ ] OpenAI Vision API extracts questions
- [ ] Backend analyzes and returns answers
- [ ] GPU widget animates answer numbers
- [ ] Animation timing matches specification
- [ ] Returns to idle state after completion

### Error Handling

- [ ] Permission denied handled gracefully
- [ ] Network errors show clear messages
- [ ] Invalid quiz pages handled
- [ ] Capacity limits enforced
- [ ] App doesn't crash on errors

### User Experience

- [ ] Keyboard shortcuts responsive
- [ ] Feedback messages clear and timely
- [ ] Animation smooth and visible
- [ ] No lag or freeze during capture
- [ ] No lag during API processing

### Performance

- [ ] Screenshot capture < 1 second
- [ ] End-to-end workflow < 60 seconds
- [ ] Memory usage acceptable
- [ ] CPU usage reasonable
- [ ] No performance degradation over time

---

## Test Session Summary

**Date**: _________________
**Duration**: _____________ minutes
**Tester**: _______________________________

**Overall Result**: ☐ PASS  ☐ FAIL  ☐ PARTIAL

**Pass Rate**: _____ / _____ tests passed (____%)

**Critical Issues Found**: _____

**Blocker Issues**: _____

**Recommendation**:
☐ Ready for production
☐ Ready with minor fixes
☐ Requires significant fixes
☐ Not ready - major issues

**Notes**:
_________________________________________________________
_________________________________________________________
_________________________________________________________
_________________________________________________________

---

## Next Actions

### Immediate Fixes Required:
1. ________________________________________________
2. ________________________________________________
3. ________________________________________________

### Documentation Updates:
1. ________________________________________________
2. ________________________________________________

### Future Enhancements:
1. ________________________________________________
2. ________________________________________________

---

**Checklist Version**: 1.0
**Last Updated**: 2025-11-10
**Related Documents**:
- Full Test Report: `TEST_REPORT_Screenshot_Workflow.md`
- Test Summary: `TEST_SUMMARY.md`
