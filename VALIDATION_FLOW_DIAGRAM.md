# Quiz Validation System - Flow Diagram

**Visual representation of validation logic and GPU error animation**

---

## Complete System Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    USER ACTIONS                              │
└─────────────────────────────────────────────────────────────┘
                            │
                            ├── Cmd+Option+4 (Set Expected: 14)
                            │
                            ├── Cmd+Option+O (Capture Screenshot) × 7
                            │
                            └── Cmd+Option+P (Process Screenshots)
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────┐
│            SCREENSHOT EXTRACTION (Vision API)                │
│                                                              │
│  1. Send 7 screenshots to OpenAI Vision API                 │
│  2. Extract questions using GPT-4 Vision                    │
│  3. Parse response into structured format                   │
│                                                              │
│  Result: Array of 14 questions                              │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  VALIDATION LOGIC                            │
│                                                              │
│  validateQuestionCount(extractedQuestions)                  │
│                                                              │
│  Step 1: Check if expectedCount is set                      │
│          ├─ NO → Skip validation, proceed                   │
│          └─ YES → Continue to Step 2                        │
│                                                              │
│  Step 2: Compare counts                                     │
│          extractedCount vs expectedCount                    │
│          ├─ MATCH → Success ✓                               │
│          └─ MISMATCH → Retry Logic                          │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
                    ┌───────┴───────┐
                    │               │
                 MATCH           MISMATCH
                    │               │
                    ▼               ▼
            ┌───────────┐   ┌──────────────┐
            │  SUCCESS  │   │ RETRY LOGIC  │
            │  PATH     │   │              │
            └───────────┘   └──────────────┘
                    │               │
                    │               ├─ retryCount < 2?
                    │               │   ├─ YES → Retry Extraction
                    │               │   └─ NO → Show Error "6"
                    │               │
                    ▼               ▼
        ┌──────────────────┐  ┌─────────────────┐
        │ OpenAI Analysis  │  │ GPU Error "6"   │
        │ Get Answer Idx   │  │ Animation       │
        └──────────────────┘  └─────────────────┘
```

---

## Detailed Validation Decision Tree

```
START: User presses Cmd+Option+P
    │
    ▼
Extract questions from screenshots
    │
    ▼
┌───────────────────────────────────┐
│ Is expectedCount set?             │
│ (User pressed Cmd+Option+0-5?)    │
└───────────────────────────────────┘
         │              │
      NO │              │ YES
         │              │
         ▼              ▼
    ┌────────┐   ┌──────────────────────┐
    │ SKIP   │   │ Compare Counts       │
    │ VALID  │   │ extracted == expected?│
    └────────┘   └──────────────────────┘
         │              │           │
         │         MATCH│           │MISMATCH
         │              │           │
         ▼              ▼           ▼
    Proceed to    ┌─────────┐  ┌──────────┐
    OpenAI        │ SUCCESS │  │ retryCount?│
    Analysis      │ ✓       │  └──────────┘
                  └─────────┘      │      │
                       │        =0  │      │ =1
                       │            │      │
                       ▼            ▼      ▼
                  Reset retry   Increment  Show Error "6"
                  counter       retry      Set failure state
                       │        counter    Abort processing
                       │            │           │
                       ▼            ▼           ▼
                  Proceed to    Retry       Wait for user
                  OpenAI        extraction  to capture new
                  Analysis      (recursive) screenshots
```

---

## Retry Attempt Flow

```
Attempt 1 (Initial)
    │
    ├─ Extract questions
    ├─ Validate count
    │   └─ FAIL (10 != 14)
    │       └─ retryCount = 1
    │           └─ Trigger Retry
    │
    ▼
Attempt 2 (Automatic Retry)
    │
    ├─ Extract questions again
    ├─ Validate count
    │   ├─ SUCCESS (14 == 14)
    │   │   └─ retryCount = 0
    │   │       └─ Proceed to OpenAI
    │   │
    │   └─ FAIL (10 != 14)
    │       └─ retryCount = 2
    │           └─ Show GPU Error "6"
    │               └─ ABORT
```

---

## GPU Error Animation Timeline

```
Time: 0s ────────────────────────────────────────────────────> 13s

Phase 1: Animate Up (1.5s)
├──────────────────────┤
0                    1.5s
│                      │
│  Value: 0 → 6       │
│  FPS: 60            │
│  Interpolation:     │
│  Ease-in-out        │
│                      │
▼                      ▼
0 ─────────────────> 6


Phase 2: Display Error (10s)
                      ├──────────────────────────────────────────┤
                    1.5s                                      11.5s
                      │                                          │
                      │  Value: 6 (constant)                    │
                      │  User sees error indicator              │
                      │                                          │
                      ▼                                          ▼
                      6 ════════════════════════════════════> 6


Phase 3: Animate Down (1.5s)
                                                                ├──────────────────────┤
                                                            11.5s                    13s
                                                                │                      │
                                                                │  Value: 6 → 0       │
                                                                │  FPS: 60            │
                                                                │  Interpolation:     │
                                                                │  Ease-in-out        │
                                                                │                      │
                                                                ▼                      ▼
                                                                6 ─────────────────> 0
```

---

## Animation Interpolation (Ease-in-out)

```
Value Over Time (0 to 6 animation)

6 │                    ╭───────
  │                  ╱
  │                ╱
5 │              ╱
  │            ╱
  │          ╱
4 │        ╱
  │      ╱
  │    ╱
3 │   ╱
  │  ╱
  │ ╱
2 │╱
  │
  │
1 │
  │
  │
0 │────────────────────────────
  0s    0.5s    1.0s    1.5s

Formula: (1 - cos(progress × π)) / 2
- Starts slow (ease-in)
- Accelerates in middle
- Ends slow (ease-out)
```

---

## State Machine Diagram

```
┌─────────────────┐
│ IDLE            │
│ retryCount = 0  │
│ isInFailure = F │
└─────────────────┘
         │
         │ User captures screenshots
         │ and presses Cmd+Option+P
         ▼
┌─────────────────┐
│ PROCESSING      │
│ Extracting Q&A  │
└─────────────────┘
         │
         │ Extraction complete
         ▼
┌─────────────────┐
│ VALIDATING      │
│ Compare counts  │
└─────────────────┘
         │
    ┌────┴────┐
    │         │
 MATCH     MISMATCH
    │         │
    ▼         ▼
┌─────────────────┐     ┌─────────────────┐
│ SUCCESS         │     │ RETRY_PENDING   │
│ retryCount = 0  │     │ retryCount += 1 │
│ isInFailure = F │     │                 │
│                 │     │ retryCount < 2? │
│ Proceed to      │     ├─ YES → IDLE     │
│ OpenAI          │     └─ NO → FAILURE   │
└─────────────────┘           │
                              ▼
                    ┌─────────────────┐
                    │ FAILURE         │
                    │ retryCount = 2  │
                    │ isInFailure = T │
                    │                 │
                    │ GPU shows "6"   │
                    └─────────────────┘
                              │
                              │ User captures
                              │ new screenshot
                              ▼
                    ┌─────────────────┐
                    │ RESET           │
                    │ Auto-clear old  │
                    │ retryCount = 0  │
                    │ isInFailure = F │
                    │                 │
                    │ Back to IDLE    │
                    └─────────────────┘
```

---

## Screenshot Lifecycle

```
┌──────────────────────────────────────────────────────────┐
│              NORMAL FLOW (Success)                        │
└──────────────────────────────────────────────────────────┘

User Captures → Store in Memory → Process All → Extract Q&A
     (×7)            (Array)          ↓             ↓
                                  Validate      OpenAI
                                     ✓          Analysis
                                     ↓             ↓
                              Clear Memory    Animate
                                              Answers


┌──────────────────────────────────────────────────────────┐
│            FAILURE FLOW (Validation Error)                │
└──────────────────────────────────────────────────────────┘

User Captures → Store in Memory → Process All → Extract Q&A
     (×3)            (Array)          ↓             ↓
                                  Validate      [Retry]
                                     ✗             ↓
                                     ↓         Extract Q&A
                              Show Error "6"      ↓
                                     ↓         Validate
                                     ↓             ✗
                              [Keep in Memory]    ↓
                                     ↓         Show Error "6"
                              User captures       ↓
                              new screenshot  [Keep in Memory]
                                     ↓             ↓
                              AUTO-CLEAR     [Wait for user]
                                     ↓             ↓
                              Fresh Start    Capture New
                                              Screenshots
```

---

## Error Recovery Flow

```
┌─────────────────────────────────────────────────────────┐
│          ERROR RECOVERY SEQUENCE                         │
└─────────────────────────────────────────────────────────┘

Step 1: Error Detected
    │
    ├─ retryCount = 2
    ├─ isInFailureState = true
    └─ GPU shows "6" for 10 seconds
         │
         ▼

Step 2: User Response
    │
    ├─ Option A: Wait (do nothing)
    │   └─ GPU returns to "0" after 13s
    │       └─ System stays in failure state
    │           └─ Old screenshots still in memory
    │
    ├─ Option B: Capture new screenshot (Cmd+Option+O)
    │   │
    │   ├─ Check isInFailureState == true?
    │   │   └─ YES → Auto-clear old screenshots
    │   │       ├─ Clear memory
    │   │       ├─ Reset retryCount = 0
    │   │       ├─ Set isInFailureState = false
    │   │       └─ Capture new screenshot
    │   │           └─ Ready for fresh attempt
    │   │
    │   └─ NO → Normal screenshot capture
    │
    └─ Option C: Quit app
        └─ All state lost
            └─ Fresh start on restart


Step 3: Fresh Attempt
    │
    └─ Capture correct number of screenshots
        └─ Process with Cmd+Option+P
            └─ Validation passes
                └─ Success!
```

---

## Memory State Tracking

```
┌─────────────────────────────────────────────────────────┐
│               MEMORY STATE OVER TIME                     │
└─────────────────────────────────────────────────────────┘

Event                    Screenshots  retryCount  isInFailure
────────────────────────────────────────────────────────────
App Start                []           0           false

Capture #1               [S1]         0           false
Capture #2               [S1,S2]      0           false
Capture #3               [S1,S2,S3]   0           false

Process (Fail)           [S1,S2,S3]   1           false
Retry (Fail)             [S1,S2,S3]   2           true

GPU shows "6"            [S1,S2,S3]   2           true
(10 seconds pass)        [S1,S2,S3]   2           true

Capture NEW              [NEW1]       0           false
(Auto-clear triggered)

Capture NEW #2           [NEW1,NEW2]  0           false

Process (Success)        []           0           false
(Cleared after success)
```

---

## Code Execution Path

```
User Action: Cmd+Option+P
    │
    ▼
QuizIntegrationManager.onProcessScreenshots()
    │
    ├─ Get all screenshots from manager
    │
    ├─ Call VisionAIService.extractQuizQuestions()
    │   └─ OpenAI Vision API call
    │       └─ Returns: [[String: Any]] (questions array)
    │
    ├─ Call validateQuestionCount(extractedQuestions)
    │   │
    │   ├─ Get expectedCount from screenshotManager
    │   │   ├─ nil → return true (skip validation)
    │   │   └─ value → compare counts
    │   │
    │   ├─ extracted == expected?
    │   │   ├─ YES → return true
    │   │   └─ NO → increment retryCount
    │   │       ├─ retryCount < 2 → return false
    │   │       └─ retryCount >= 2 → call showValidationError()
    │   │           └─ return false
    │   │
    │   └─ return Bool
    │
    ├─ Validation result?
    │   ├─ true → Proceed to sendToBackend()
    │   └─ false →
    │       ├─ retryCount < 2 → call onProcessScreenshots() recursively
    │       └─ retryCount >= 2 → abort
    │
    └─ SUCCESS PATH:
        ├─ Send to backend for OpenAI analysis
        ├─ Start animation with answers
        ├─ Clear screenshots
        ├─ Reset state
        └─ Done
```

---

## GPU Animation Code Path

```
showValidationError() called
    │
    ▼
DispatchQueue.main.async {
    │
    ├─ Get currentQuizNumber (current GPU value)
    │
    ├─ animateValue(from: current, to: 6, duration: 1.5)
    │   │
    │   ├─ Create Timer (60 FPS)
    │   │   └─ Fires every 16.67ms
    │   │
    │   ├─ Calculate elapsed time
    │   ├─ Calculate progress (0.0 to 1.0)
    │   ├─ Apply ease-in-out: (1 - cos(progress × π)) / 2
    │   ├─ Interpolate value
    │   ├─ Call updateQuizNumber(interpolated)
    │   │   └─ Updates GPU widget display
    │   │
    │   ├─ progress >= 1.0?
    │   │   ├─ YES → invalidate timer
    │   │   │       └─ call completion callback
    │   │   └─ NO → continue
    │   │
    │   └─ Completion: value is now 6
    │
    ├─ DispatchQueue.main.asyncAfter(10 seconds)
    │   │
    │   └─ animateValue(from: 6, to: 0, duration: 1.5)
    │       │
    │       └─ [Same animation logic as above]
    │           │
    │           └─ Completion: value is now 0
    │               └─ Animation complete
    │
    └─ Total elapsed: 13 seconds
}
```

---

## Console Output Timeline

```
Time    Event                               Console Output
──────────────────────────────────────────────────────────────
0.0s    User presses Cmd+Option+P           🚀 [QuizIntegration] PROCESS SCREENSHOTS
0.1s    Start processing                    📤 Processing 3 screenshots...
0.2s    Sending to Vision API               📸 Sending 3 screenshots to OpenAI Vision API...
3.5s    Extraction complete                 ✅ Extracted 6 questions from screenshots
3.5s    Start validation                    🔍 Validating question count...
3.5s    Show comparison                        Expected: 14 questions
3.5s                                            Extracted: 6 questions
3.5s    Validation fails                    ❌ Validation failed!
3.5s    First retry                         🔄 Retry attempt 1/2...
3.6s    Recursive call                      📤 Processing 3 screenshots...
3.7s    Sending to Vision API               📸 Sending 3 screenshots to OpenAI Vision API...
7.2s    Extraction complete                 ✅ Extracted 6 questions from screenshots
7.2s    Start validation                    🔍 Validating question count...
7.2s    Show comparison                        Expected: 14 questions
7.2s                                            Extracted: 6 questions
7.2s    Validation fails again              ❌ Validation failed!
7.2s    Max retries reached                 ⚠️  Maximum retries (2) reached. Showing error indicator.
7.2s    Show GPU error                      🚨 [GPU] Showing validation error (number 6)
7.2s    User instructions                   🚨 Please capture new screenshots and try again
7.2s                                           Old screenshots will be cleared automatically when you capture new ones
7.2s    Abort processing                    ❌ Processing aborted after 2 attempts
8.7s    Animation phase 2                   🚨 [GPU] Displaying error indicator (6) for 10 seconds
18.7s   Animation phase 3                   🚨 [GPU] Animating back to 0
20.2s   Animation complete                  ✅ [GPU] Error indicator cleared
```

---

## Success Metrics

### Timing Accuracy
```
Animation Phase          Target    Acceptable Range    Measured
─────────────────────────────────────────────────────────────────
Phase 1: 0 → 6          1.5s      1.4s - 1.6s         _____
Phase 2: Display        10.0s     9.8s - 10.2s        _____
Phase 3: 6 → 0          1.5s      1.4s - 1.6s         _____
Total Duration          13.0s     12.8s - 13.2s       _____
```

### Frame Rate
```
Target: 60 FPS (16.67ms per frame)
Acceptable: > 30 FPS (< 33.33ms per frame)
Measured: _____ FPS
```

### State Management
```
Scenario                 Expected         Actual
─────────────────────────────────────────────────
After success           retryCount = 0    _____
After 2 failures        retryCount = 2    _____
After auto-clear        retryCount = 0    _____
Failure state set       isInFailure = T   _____
After recovery          isInFailure = F   _____
```

---

**Status**: Implementation Complete
**Build Status**: ✅ Compiled Successfully
**Ready For**: Integration Testing
