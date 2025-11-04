# 🚀 Quick Reference - Updated Stats System

## New Keyboard Shortcut

**Press: `Cmd + Shift + Z`** to trigger quiz analysis on any webpage

(Changed from `Cmd + Option + Q`)

---

## GPU Display Update

GPU percentages now show as **ranges** instead of exact numbers:

- `47%` → `45-50%`
- `23%` → `20-25%`
- `89%` → `85-90%`

This is more accurate for fluctuating values.

---

## How to Use the Complete System

### 1. **Start the Backend** (in one terminal)
```bash
cd ~/Desktop/Universität/Stats/backend
npm start
```

Expected output:
```
✅ Backend server running on http://localhost:3000
```

### 2. **Open Stats App** (in Xcode)
```bash
open ~/Desktop/Universität/Stats/cloned-stats/Stats.xcodeproj
# Build with Cmd+B, Run with Cmd+R
```

### 3. **Test the System**
- Open any webpage with multiple-choice quiz questions
- Press **`Cmd + Shift + Z`**
- Watch the animation show correct answers!

---

## What Each Component Does

| Component | Purpose | Status |
|-----------|---------|--------|
| **Scraper** | Extracts questions from webpage | ✅ Running |
| **Backend** | Sends to OpenAI for analysis | ✅ Running |
| **Swift App** | Displays answers with animation | ✅ Ready |
| **Keyboard Shortcut** | **`Cmd + Shift + Z`** to trigger | ✅ Updated |

---

## Files Changed

- ✅ `KeyboardShortcutManager.swift` - Updated shortcut
- ✅ `portal.swift` (GPU) - Updated display to ranges

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Shortcut doesn't work | Check app is running, press `Cmd + Shift + Z` |
| GPU shows exact % | Rebuild with Cmd+B in Xcode |
| Backend won't start | Run `npm install` first in backend folder |
| Can't find quiz questions | Try different websites with quizzes |

---

**Last Updated**: 2025-11-04
**Version**: 1.0.1
**System**: Quiz Stats Animation System

