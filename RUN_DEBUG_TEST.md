# Run Debug Test - Critical Instructions

**Date**: November 8, 2024 22:35 UTC
**Status**: Ready to test with correct binary

---

## 🔴 CRITICAL: Close All Stats Instances First!

You have **TWO Stats apps running**:
1. Production Stats app (in your menu bar - the normal one)
2. Our debug build (trying to start but conflicting)

### Step 1: Close Production Stats App

**You MUST close the production Stats app** that's showing CPU/GPU in your menu bar:

1. Look at your menu bar (top right of screen)
2. Find the **Stats** menu bar icon (shows CPU/GPU percentages)
3. Click it
4. Click **Quit Stats** at the bottom
5. Confirm the app closes (icon disappears from menu bar)

---

## ✅ Step 2: Run Our Debug Build

Now run our debug build with verbose logging:

```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats
./run-swift.sh 2>&1 | tee ~/Desktop/stats-debug-log.txt
```

---

## 🔍 Step 3: What You Should See

### On Startup - Look for These Messages:

```
🚀 Starting Stats app (DEBUG BUILD WITH LOGGING)...
⌨️  Keyboard shortcut: Cmd+Shift+Z (NOT Cmd+Option+Q!)
🔍 Verbose logging enabled - watch for [KeyboardManager] and [QuizIntegration] messages

[Then the Swift app logs should appear:]

🎬 [QuizIntegration] Initializing Quiz Integration Manager...
🔧 [QuizIntegration] Step 1: Requesting notification permissions...
🔧 [QuizIntegration] Step 2: Setting up delegates...
🔧 [KeyboardManager] Initialized with trigger key: 'z'
✅ [KeyboardManager] Delegate set: QuizIntegrationManager
🔧 [QuizIntegration] Step 3: Starting HTTP server...
🔧 [QuizIntegration] Step 4: Registering keyboard shortcut...
🔧 [KeyboardManager] Starting keyboard shortcut registration...
🔐 [KeyboardManager] Accessibility permissions check:
   Status: ✅ GRANTED or ❌ DENIED
✅ [KeyboardManager] Global keyboard shortcut registered successfully
```

**CRITICAL**: If you don't see messages starting with `🔧 [KeyboardManager]` or `🎬 [QuizIntegration]`, the verbose logging isn't working.

---

### When Pressing Cmd+Shift+Z:

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
```

---

## ⚠️ If You See Port 8080 Error

If the script says:
```
⚠️  WARNING: Port 8080 is already in use!
❌ Please close the other Stats app first
```

This means another Stats instance is still running. You need to:

1. **Close Stats from menu bar** (click icon → Quit)
2. **Or manually kill it**:
   ```bash
   lsof -i :8080 | grep Stats | awk '{print $2}' | xargs kill -9
   ```
3. Then run `./run-swift.sh` again

---

## 🎯 Test Procedure

Once the app is running with verbose logs visible:

### Test 1: Check Startup Logs
- [ ] Do you see `🔧 [KeyboardManager]` messages?
- [ ] Do you see `🔐 Accessibility permissions check: Status: ???`
- [ ] What's the status: ✅ GRANTED or ❌ DENIED?

### Test 2: Test Keyboard Shortcut
- [ ] Open any webpage in Chrome or Safari
- [ ] Press **Cmd+Shift+Z** (Command + Shift + Z)
- [ ] Do you see `⌨️  [KeyboardManager] Key event detected!`?
- [ ] Do you see `✅ SHORTCUT MATCHED!`?
- [ ] Do you see `🎯 KEYBOARD SHORTCUT TRIGGERED!`?

### Test 3: Check for Errors
- [ ] Any lines starting with `❌ [KeyboardManager]`?
- [ ] Any lines about accessibility permissions denied?
- [ ] Any other error messages?

---

## 📊 What to Report

After running the test, please share:

1. **Did you close the production Stats app?** (Yes/No)
2. **Did you see the verbose logging?** (Messages with `🔧 [KeyboardManager]`)
3. **Accessibility permissions status**: (✅ GRANTED or ❌ DENIED)
4. **When pressing Cmd+Shift+Z**: (What messages appeared, if any)
5. **Complete log file**: `~/Desktop/stats-debug-log.txt`

---

## 🚨 Common Problems

### Problem: "Cmd+Option+Q" still mentioned
**Cause**: Old hardcoded message in run-swift.sh (now fixed)
**Solution**: Use latest version of run-swift.sh

### Problem: No verbose logging appears
**Cause**: Wrong binary is running, or code didn't compile
**Check**: Look for messages starting with `[KeyboardManager]` or `[QuizIntegration]`

### Problem: Port 8080 in use
**Cause**: Production Stats app still running
**Solution**: Quit Stats from menu bar first

### Problem: Database lock errors
**Cause**: Two Stats instances trying to use same database
**Solution**: Only run one instance at a time

---

## 🎬 Quick Command

**All-in-one command** (after closing production Stats app):

```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats && \
./run-swift.sh 2>&1 | tee ~/Desktop/stats-debug-log.txt
```

**Then**:
1. Wait for `✅ Quiz Integration Manager initialized`
2. Press Cmd+Shift+Z
3. Watch console output
4. Ctrl+C to stop
5. Share `~/Desktop/stats-debug-log.txt`

---

**Status**: ⏳ Awaiting test results
**Priority**: 🔴 Critical - Need clean run without conflicts
