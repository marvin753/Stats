# Validation System Testing Guide

**Date**: November 12, 2025
**Purpose**: Step-by-step testing procedures for quiz validation system

---

## Prerequisites

1. **Build the app**:
   ```bash
   cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats
   ./build-swift.sh
   ```

2. **Run the app**:
   ```bash
   ./run-swift.sh
   ```

3. **Verify GPU widget is visible** in menu bar

---

## Test 1: Validation Success (Expected Behavior)

### Setup
1. Open a quiz webpage with exactly 14 questions
2. Press `Cmd+Option+4` to set expected count to 14
3. Capture 7 screenshots (2 questions per screenshot)

### Steps
1. **Set Expected Count**:
   ```
   Press: Cmd+Option+4
   Expected Console Output:
   🔢 Question count set to 14 via Cmd+Option+4
   ```

2. **Capture Screenshots** (repeat 7 times):
   ```
   Press: Cmd+Option+O
   Expected Console Output:
   📸 [QuizIntegration] CAPTURE SCREENSHOT (Cmd+Option+O)
   ✅ Screenshot 1 captured successfully
   ```

3. **Process Screenshots**:
   ```
   Press: Cmd+Option+P
   Expected Console Output:
   📤 Processing 7 screenshots...
   📸 Sending 7 screenshots to OpenAI Vision API...
   ✅ Extracted 14 questions from screenshots
   🔍 Validating question count...
      Expected: 14 questions
      Extracted: 14 questions
   ✅ Validation passed!
   📤 Sending questions to backend for analysis...
   ```

### Expected Result
- ✅ Validation passes immediately
- ✅ No retry triggered
- ✅ Proceeds to OpenAI analysis
- ✅ GPU widget shows answer animation (not error "6")

---

## Test 2: Validation Failure → Automatic Retry → Success

### Setup
1. Open a quiz webpage with exactly 14 questions
2. Press `Cmd+Option+4` to set expected count to 14
3. **Intentionally** capture only 5 screenshots (incomplete)

### Steps
1. **Set Expected Count**:
   ```
   Press: Cmd+Option+4
   ```

2. **Capture Only 5 Screenshots**:
   ```
   Press: Cmd+Option+O (5 times)
   Expected: 5 screenshots captured
   ```

3. **Process Screenshots**:
   ```
   Press: Cmd+Option+P
   Expected Console Output:
   📤 Processing 5 screenshots...
   ✅ Extracted 10 questions from screenshots
   🔍 Validating question count...
      Expected: 14 questions
      Extracted: 10 questions
   ❌ Validation failed!
   🔄 Retry attempt 1/2...

   [Automatic Retry]
   📤 Processing 5 screenshots...
   ✅ Extracted 14 questions from screenshots (better extraction)
   🔍 Validating question count...
      Expected: 14 questions
      Extracted: 14 questions
   ✅ Validation passed!
   ```

### Expected Result
- ✅ First attempt fails (10 != 14)
- ✅ Automatic retry triggered
- ✅ Second attempt succeeds (improved extraction)
- ✅ Proceeds to OpenAI analysis
- ✅ No error "6" shown

**Note**: This test depends on Vision API improving extraction on retry. If retry also fails, proceed to Test 3.

---

## Test 3: Validation Failure → 2 Retries → Error Display

### Setup
1. Open a quiz webpage with exactly 14 questions
2. Press `Cmd+Option+4` to set expected count to 14
3. **Intentionally** capture only 3 screenshots (definitely insufficient)

### Steps
1. **Set Expected Count**:
   ```
   Press: Cmd+Option+4
   ```

2. **Capture Only 3 Screenshots**:
   ```
   Press: Cmd+Option+O (3 times)
   Expected: 3 screenshots captured
   ```

3. **Process Screenshots**:
   ```
   Press: Cmd+Option+P
   Expected Console Output:
   📤 Processing 3 screenshots...
   ✅ Extracted 6 questions from screenshots
   🔍 Validating question count...
      Expected: 14 questions
      Extracted: 6 questions
   ❌ Validation failed!
   🔄 Retry attempt 1/2...

   [Automatic Retry 1]
   📤 Processing 3 screenshots...
   ✅ Extracted 6 questions from screenshots
   🔍 Validating question count...
      Expected: 14 questions
      Extracted: 6 questions
   ❌ Validation failed!
   ⚠️  Maximum retries (2) reached. Showing error indicator.
   🚨 [GPU] Showing validation error (number 6)
   🚨 Please capture new screenshots and try again
      Old screenshots will be cleared automatically when you capture new ones
   ❌ Processing aborted after 2 attempts
   ```

4. **Observe GPU Widget**:
   ```
   Time 0.0s:  GPU shows 0
   Time 0.75s: GPU shows ~3 (animating up)
   Time 1.5s:  GPU shows 6 (reached target)
   Time 11.5s: GPU still shows 6 (holding)
   Time 12.25s: GPU shows ~3 (animating down)
   Time 13.0s: GPU shows 0 (animation complete)
   ```

### Expected Result
- ✅ First attempt fails (6 != 14)
- ✅ Automatic retry triggered
- ✅ Second attempt also fails (6 != 14)
- ✅ Error "6" displayed in GPU widget
- ✅ Animation smooth and visible
- ✅ Display duration: exactly 10 seconds at "6"
- ✅ Total animation time: 13 seconds
- ✅ Processing aborted (no OpenAI call)

---

## Test 4: Auto-Clear After Error

### Setup
1. Complete Test 3 first (trigger validation error)
2. Wait for error animation to complete (GPU shows 0 again)

### Steps
1. **Verify Failure State**:
   ```
   Internal State:
   isInFailureState = true
   retryCount = 2
   Old screenshots still in memory
   ```

2. **Capture New Screenshot**:
   ```
   Press: Cmd+Option+O
   Expected Console Output:
   📸 [QuizIntegration] CAPTURE SCREENSHOT (Cmd+Option+O)
   🧹 Auto-clearing old screenshots (previous validation failed)
   ✅ Screenshot 1 captured successfully
   ```

3. **Verify State Reset**:
   ```
   Internal State:
   isInFailureState = false
   retryCount = 0
   Old screenshots cleared
   Fresh start for new capture session
   ```

### Expected Result
- ✅ Old screenshots automatically cleared
- ✅ Retry counter reset to 0
- ✅ Failure state cleared
- ✅ New screenshot count starts at 1
- ✅ Ready for fresh capture attempt

---

## Test 5: Validation Bypass (No Expected Count)

### Setup
1. Open a quiz webpage
2. **Do NOT** set expected count (skip Cmd+Option+0-5)
3. Capture any number of screenshots

### Steps
1. **Capture Screenshots** (any number):
   ```
   Press: Cmd+Option+O (multiple times)
   ```

2. **Process Screenshots**:
   ```
   Press: Cmd+Option+P
   Expected Console Output:
   📤 Processing N screenshots...
   ✅ Extracted M questions from screenshots
   ℹ️  No expected count set - skipping validation
   📤 Sending questions to backend for analysis...
   ```

### Expected Result
- ✅ Validation completely skipped
- ✅ No retry logic executed
- ✅ Proceeds directly to OpenAI analysis
- ✅ Works with any question count

---

## Test 6: GPU Animation Smoothness

### Purpose
Verify animation is smooth at 60 FPS

### Steps
1. Trigger validation error (Test 3)
2. Carefully observe GPU widget during animation
3. Check for any stuttering or frame drops

### Visual Checks
- ✅ Animation from 0 to 6 is smooth (no jumps)
- ✅ Hold at 6 is stable (no flickering)
- ✅ Animation from 6 to 0 is smooth
- ✅ No CPU spikes during animation
- ✅ Timer cleans up properly (no memory leak)

### Timing Verification
1. Start timer when error triggers
2. Measure time from 0 to 6: should be ~1.5 seconds
3. Measure time at 6: should be ~10 seconds
4. Measure time from 6 to 0: should be ~1.5 seconds
5. Total duration: should be ~13 seconds

---

## Test 7: Concurrent Screenshot Capture During Error

### Purpose
Verify system handles edge cases

### Setup
1. Trigger validation error (Test 3)
2. While GPU widget shows "6", try capturing new screenshot

### Steps
1. **Trigger Error**:
   ```
   [Complete Test 3 to trigger error "6"]
   ```

2. **Capture During Error Display**:
   ```
   Press: Cmd+Option+O (while GPU shows "6")
   Expected: Auto-clear still works
   ```

### Expected Result
- ✅ Auto-clear triggers immediately
- ✅ Old screenshots cleared
- ✅ New screenshot captured
- ✅ GPU animation continues (may jump to 0)
- ✅ No crashes or race conditions

---

## Test 8: Multiple Validation Cycles

### Purpose
Verify state management across multiple sessions

### Steps
1. **Cycle 1**: Pass validation (Test 1)
   - Verify retryCount = 0 after success

2. **Cycle 2**: Fail validation (Test 3)
   - Verify error "6" shows

3. **Cycle 3**: Auto-clear and retry (Test 4)
   - Verify state resets properly

4. **Cycle 4**: Pass validation again (Test 1)
   - Verify no leftover state from previous failures

### Expected Result
- ✅ Each cycle independent
- ✅ State resets properly between cycles
- ✅ No accumulated errors
- ✅ Consistent behavior

---

## Debugging Tips

### If Validation Doesn't Trigger
1. Check if expected count is set:
   ```swift
   // Should see this in console:
   🔢 Question count set to N via Cmd+Option+X
   ```

2. Verify method is called:
   ```swift
   // Add breakpoint in QuizIntegrationManager.swift:642
   private func validateQuestionCount(...)
   ```

### If GPU Error Animation Doesn't Show
1. Check GPU module connection:
   ```swift
   // Should see in console on app start:
   🔗 Connected to GPU module for quiz display
   ✅ GPU widget integration complete - displaying default value: 0
   ```

2. Verify method is called:
   ```swift
   // Add breakpoint in GPU/main.swift:221
   public func showValidationError()
   ```

### If Auto-Clear Doesn't Work
1. Check failure state:
   ```swift
   // Add logging in onCaptureScreenshot:
   print("isInFailureState: \(isInFailureState)")
   ```

2. Verify screenshot manager clears:
   ```swift
   // Should see in console:
   🧹 Auto-clearing old screenshots (previous validation failed)
   ```

---

## Performance Metrics

### Expected Values
| Metric | Target | Acceptable |
|--------|--------|------------|
| Animation frame rate | 60 FPS | > 30 FPS |
| Animation smoothness | No stuttering | Minor glitches OK |
| Error display duration | 10.0s | 9.5s - 10.5s |
| Total animation time | 13.0s | 12.5s - 13.5s |
| Retry processing time | < 5s | < 10s |
| Memory leak | None | None |

### Monitoring Commands
```bash
# Monitor CPU usage
top -pid $(pgrep Stats)

# Monitor memory
leaks -quiet -atExit -- /path/to/Stats.app/Contents/MacOS/Stats

# View console logs
log stream --predicate 'process == "Stats"' --level debug
```

---

## Troubleshooting

### Issue: Animation Too Fast/Slow
**Solution**: Adjust duration in GPU/main.swift:
```swift
// Line 229: Change duration parameter
self.animateValue(from: currentValue, to: 6, duration: 1.5)  // Increase/decrease
```

### Issue: Retry Doesn't Improve Extraction
**Solution**: This is expected behavior. Retry mechanism assumes Vision API variability. If consistently fails, capture more screenshots.

### Issue: GPU Widget Doesn't Update
**Solution**:
1. Verify GPU module is enabled in app
2. Check menu bar settings (GPU widget visibility)
3. Restart app

### Issue: Console Doesn't Show Expected Output
**Solution**:
1. Run app via `./run-swift.sh` (not Xcode)
2. Check terminal output directly
3. Enable debug logging

---

## Success Criteria

### All Tests Must Pass
- ✅ Test 1: Validation success
- ✅ Test 2: Automatic retry
- ✅ Test 3: Error display after 2 failures
- ✅ Test 4: Auto-clear works
- ✅ Test 5: Bypass when no count set
- ✅ Test 6: Animation smooth
- ✅ Test 7: Concurrent capture handled
- ✅ Test 8: Multiple cycles work

### System Ready for Production When:
1. All 8 tests pass consistently
2. No crashes or exceptions
3. Animation smooth (60 FPS)
4. State management correct
5. Memory leaks verified absent
6. Console output matches expectations

---

## Next Steps After Testing

1. **Document Results**: Note any issues or unexpected behavior
2. **Performance Tuning**: Adjust timing if needed
3. **User Feedback**: Collect feedback on error visibility
4. **Edge Case Testing**: Test with unusual quiz formats
5. **Integration Testing**: Test with backend and OpenAI

---

## Quick Test Commands

```bash
# Build and run
cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats
./build-swift.sh && ./run-swift.sh

# Test keyboard shortcuts
# Cmd+Option+4 = Set count to 14
# Cmd+Option+O = Capture screenshot
# Cmd+Option+P = Process screenshots

# Monitor logs
tail -f /tmp/stats-app.log  # If logging enabled
```

---

**Status**: Ready for Testing
**Estimated Time**: 30-45 minutes for complete test suite
**Prerequisites**: Quiz webpage with known question count
