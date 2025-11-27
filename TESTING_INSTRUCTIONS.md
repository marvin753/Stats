# Testing Instructions - Keyboard Shortcut Debugging

**Date**: November 8, 2024 22:25 UTC
**Status**: ✅ App rebuilt with comprehensive logging
**Next Step**: Run app and collect console logs

---

## 🎯 What We're Testing

The Swift app now has extensive logging to identify exactly where the keyboard shortcut chain breaks. We need to:

1. Run the app
2. Observe startup logs
3. Press Cmd+Shift+Z
4. Analyze what logs appear (or don't appear)

---

## 📋 Step-by-Step Instructions

### Step 1: Run the Swift App

**Option A: Using Terminal** (Recommended for log collection)
```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats
./run-swift.sh 2>&1 | tee ~/Desktop/stats-debug-log.txt
```

This will:
- Run the Stats app
- Display all logs in terminal
- Save logs to `~/Desktop/stats-debug-log.txt` for analysis

**Option B: Using Xcode** (If you prefer GUI)
```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats
open Stats.xcodeproj
```
Then in Xcode:
1. Press Cmd+R to run
2. Open Console: View → Debug Area → Activate Console (Cmd+Shift+C)

---

### Step 2: Check Startup Logs

**What you should see when the app starts:**

```
🎬 [QuizIntegration] Initializing Quiz Integration Manager...
🔧 [QuizIntegration] Step 1: Requesting notification permissions...
🔧 [QuizIntegration] Step 2: Setting up delegates...
🔧 [KeyboardManager] Initialized with trigger key: 'z'
✅ [KeyboardManager] Delegate set: QuizIntegrationManager
   ✓ HTTP server delegate set
   ✓ Keyboard manager delegate set
🔧 [QuizIntegration] Step 3: Starting HTTP server...
🔧 [QuizIntegration] Step 4: Registering keyboard shortcut...
🔧 [KeyboardManager] Starting keyboard shortcut registration...
🔧 [KeyboardManager] Target key: 'z'
🔧 [KeyboardManager] Expected combination: Cmd+Shift+Z
🔐 [KeyboardManager] Accessibility permissions check:
   Status: ✅ GRANTED or ❌ DENIED  ← IMPORTANT!
✅ [KeyboardManager] Global keyboard shortcut registered successfully
   Monitor object: <NSEvent: ...>
```

**Critical checkpoint**: Look for this line:
```
🔐 [KeyboardManager] Accessibility permissions check: Status: ✅ GRANTED
```

**If it says `❌ DENIED`**:
- The keyboard shortcut cannot work without accessibility permissions
- See "Fix Accessibility Permissions" section below

---

### Step 3: Test Keyboard Shortcut

**While the app is running:**

1. Make sure the app is running (menu bar icon should be visible)
2. Open any webpage in Chrome or Safari
3. Press **Cmd+Shift+Z** (Command + Shift + Z)
4. Watch the terminal/console for logs

---

### Step 4: Analyze Console Output

**Scenario A: Accessibility Permissions GRANTED & Events Received**

If permissions are granted, you should see this when pressing Cmd+Shift+Z:

```
⌨️  [KeyboardManager] Key event detected!
   - Key character: 'z'
   - Modifier flags: [command, shift]
   - Has Command: true
   - Has Shift: true
   - Key matches 'z': true
✅ [KeyboardManager] SHORTCUT MATCHED! Triggering delegate...
============================================================
🎯 [QuizIntegration] KEYBOARD SHORTCUT TRIGGERED!
============================================================
⌨️  Keyboard shortcut triggered!
🚀 Triggering scraper and quiz workflow...
✓ Detected URL: https://...
```

**If this happens**: ✅ Keyboard shortcut is working! Issue is downstream (URL detection, scraper, etc.)

---

**Scenario B: Accessibility Permissions DENIED**

Startup logs show:
```
🔐 [KeyboardManager] Accessibility permissions check: Status: ❌ DENIED
⚠️  [KeyboardManager] Accessibility permissions NOT granted!
```

When you press Cmd+Shift+Z: **Nothing happens** (no logs at all)

**Fix**: See "Fix Accessibility Permissions" section below

---

**Scenario C: Permissions Granted but NO Events Received**

Startup logs show:
```
🔐 [KeyboardManager] Accessibility permissions check: Status: ✅ GRANTED
✅ [KeyboardManager] Global keyboard shortcut registered successfully
```

But when you press Cmd+Shift+Z: **No "Key event detected!" message appears**

**This means**:
- Permissions are granted
- Event monitor registered successfully
- But NSEvent.addGlobalMonitorForEvents is not receiving events

**Possible causes**:
1. App is in foreground (global monitor only works when app is in background)
2. Another security setting is blocking events
3. macOS bug or conflict

**Test**: Try pressing Cmd+Shift+Z while another app is in foreground (e.g., Chrome)

---

**Scenario D: Events Received but Shortcut Not Matching**

You see:
```
⌨️  [KeyboardManager] Key event detected!
   - Key character: 'z'
   - Modifier flags: [command]  ← Missing shift?
   - Has Command: true
   - Has Shift: false  ← This should be true!
   - Key matches 'z': true
❌ [KeyboardManager] Shortcut not matched (need Cmd+Shift+z)
```

**This means**: Keys are detected but modifiers are wrong

**Check**: Are you pressing the correct keys? (Cmd+**Shift**+Z, not Cmd+Option+Z)

---

**Scenario E: Event Monitor Returns Nil**

You see:
```
❌ [KeyboardManager] ERROR: NSEvent.addGlobalMonitorForEvents returned nil!
   This usually means accessibility permissions are denied.
```

**This means**: Registration failed completely

**Fix**: Check accessibility permissions (see below)

---

## 🔧 Fix Accessibility Permissions

If logs show `❌ DENIED`:

### macOS 13 (Ventura) and Later:
1. Open **System Settings**
2. Click **Privacy & Security** in sidebar
3. Scroll down and click **Accessibility**
4. Click the **+** button (or lock icon to unlock)
5. Navigate to: `/Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats/build/Build/Products/Debug/Stats.app`
6. Click **Open** to add it
7. Enable the checkbox next to "Stats"
8. **Restart the Stats app**

### macOS 12 (Monterey) and Earlier:
1. Open **System Preferences**
2. Click **Security & Privacy**
3. Click **Privacy** tab
4. Select **Accessibility** in left sidebar
5. Click lock icon to unlock (enter password)
6. Click **+** button
7. Navigate to and select `Stats.app`
8. Enable checkbox
9. **Restart the Stats app**

---

## 📊 What to Report Back

After running the app and testing, please provide:

### 1. Startup Logs
Copy the entire startup sequence, especially:
```
🔐 [KeyboardManager] Accessibility permissions check: Status: ???
✅ or ❌ [KeyboardManager] Global keyboard shortcut registered successfully
```

### 2. Keyboard Test Results
When pressing Cmd+Shift+Z, what happens?
- [ ] Nothing (no logs at all)
- [ ] Logs show "Key event detected!" but shortcut doesn't match
- [ ] Logs show "SHORTCUT MATCHED!" but no delegate callback
- [ ] Full workflow triggers (scraper launches, notification appears)

### 3. Any Error Messages
Copy any lines starting with ❌ or ⚠️

### 4. Complete Log File
If using Option A (terminal), the log file is saved at:
```
~/Desktop/stats-debug-log.txt
```

---

## 🎬 Quick Test Command

**All-in-one test**:
```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats && \
./run-swift.sh 2>&1 | tee ~/Desktop/stats-debug-log.txt
```

Then:
1. Wait for "✅ Quiz Integration Manager initialized"
2. Press Cmd+Shift+Z
3. Watch for logs
4. Press Ctrl+C to stop app
5. Check `~/Desktop/stats-debug-log.txt` for full logs

---

## 🔍 Expected Outcomes

### ✅ Best Case
Logs show complete chain:
```
🔐 Status: ✅ GRANTED
⌨️  Key event detected!
✅ SHORTCUT MATCHED!
🎯 KEYBOARD SHORTCUT TRIGGERED!
✓ Detected URL: https://...
🌐 Launching scraper...
```
→ Keyboard shortcut works! Issue is in scraper/backend (if no animation)

### ⚠️ Permission Issue
Logs show:
```
🔐 Status: ❌ DENIED
```
→ Fix accessibility permissions, restart app, test again

### ❌ Event Monitor Issue
Logs show:
```
✅ GRANTED
✅ registered successfully
[No "Key event detected!" when pressing Cmd+Shift+Z]
```
→ Event monitor not receiving events despite registration

---

## 📝 Debugging Decision Tree

```
Start: Run app
    ↓
Q: Does it show "Status: ✅ GRANTED"?
    ├─ No → Fix permissions, restart app
    └─ Yes → Continue
         ↓
    Press Cmd+Shift+Z
         ↓
    Q: Do you see "Key event detected!"?
         ├─ No → Event monitor not receiving events
         │        → Try with app in background
         │        → Check for other security restrictions
         └─ Yes → Continue
              ↓
         Q: Do you see "SHORTCUT MATCHED!"?
              ├─ No → Check modifier flags in logs
              │        → Verify correct keys pressed
              └─ Yes → Continue
                   ↓
              Q: Do you see "KEYBOARD SHORTCUT TRIGGERED!"?
                   ├─ No → Delegate connection broken
                   │        → Check QuizIntegrationManager delegate assignment
                   └─ Yes → Keyboard shortcut working!
                        ↓
                   Q: Do you see "✓ Detected URL: ..."?
                        ├─ No → AppleScript failing
                        │        → Phase 2 debugging (URL detection)
                        └─ Yes → Continue to scraper debugging
```

---

**Status**: ⏳ Awaiting test results
**Priority**: 🔴 Critical - Need console logs to proceed
**Estimated Time**: 5 minutes to run and collect logs
