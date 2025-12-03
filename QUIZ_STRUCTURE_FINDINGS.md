# Quiz Page Structure Analysis

**Date**: November 8, 2024 21:30 UTC
**Quiz URL**: https://iubh-onlineexams.de/mod/quiz/attempt.php?attempt=1940889&cmid=22969

---

## Quiz Page Structure

### Overview
- **Total Questions**: 20
- **Question Types**:
  - Questions 1-14: Multiple choice (4 options each)
  - Questions 15-20: Text input / Essay questions
- **Platform**: Moodle-based quiz system (iubh-onlineexams.de)

### HTML Structure Pattern

#### Multiple Choice Questions (1-14)
```html
<h3>Frage 1</h3>
<p>Bisher nicht beantwortet</p>
<p>Erreichbare Punkte: 3,00</p>
<h4>Fragetext</h4>
<p>Question text here...</p>
<p>Wählen Sie eine Antwort:</p>
<input type="radio" ...> Answer 1
<input type="radio" ...> Answer 2
<input type="radio" ...> Answer 3
<input type="radio" ...> Answer 4
```

#### Text Input Questions (15-20)
```html
<h3>Frage 15</h3>
<p>Bisher nicht beantwortet</p>
<p>Erreichbare Punkte: 6,00</p>
<h4>Fragetext</h4>
<p>Question text here...</p>
<textarea>...</textarea>
```

### Sample Questions Extracted

**Question 1** (Points: 3.00):
- Text: "Wenn das Wetter gut ist, wird der Bauer bestimmt den Eber, das Ferkel und …"
- Answers:
  1. die Nacht durchzechen.
  2. einen draufmachen.
  3. die Sau rauslassen.
  4. auf die Kacke hauen.

**Question 2** (Points: 3.00):
- Text: "Was ist meist ziemlich viel?"
- Answers:
  1. Selbstbewusste Differenz
  2. Stolze Summe
  3. Arroganter Quotient
  4. Hochmütiges Produkt

**Question 3** (Points: 3.00):
- Text: "Wessen Genesung schnell voranschreitet, der erholt sich …"
- Answers:
  1. anschauends.
  2. glotzends.
  3. hinguckends.
  4. zusehends.

**Question 7** (Points: 3.00):
- Text: "Wie viele kleine Geißlein wurden vom Wolf verschlungen?"
- Answers:
  1. 5
  2. 6
  3. 7
  4. 1

---

## Scraper Compatibility Analysis

### ✅ Good News
1. **Clear structure**: Questions use `<h3>Frage X</h3>` pattern
2. **Consistent format**: All multiple-choice questions follow same HTML structure
3. **Answer labels**: Radio button text is clearly labeled
4. **No dynamic loading**: All questions visible on page load

### ⚠️ Challenges
1. **Mixed question types**: Need to handle both multiple-choice and essay questions
2. **Text-only answers**: Some questions have text input (not parseable for correct answer)
3. **Authentication required**: Cannot scrape without valid session cookies
4. **German language**: Questions in German, but AI should handle

---

## Critical Issue Identified: URL Detection

### The Problem
**QuizIntegrationManager has NO code to get the current browser tab URL.**

When the keyboard shortcut (Cmd+Option+Z) is pressed:
1. ✅ KeyboardShortcutManager fires correctly
2. ✅ QuizIntegrationManager receives trigger
3. ❌ **No code exists to get the current browser URL**
4. ❌ Scraper cannot be launched without URL parameter

### Current Code (QuizIntegrationManager.swift)
```swift
func keyboardShortcutTriggered() {
    print("🎯 Keyboard shortcut triggered!")
    // TODO: How to get current browser tab URL?
    // let url = ???
    // launchScraper(url: url)
}
```

### Why This Is The Root Cause
- User presses Cmd+Option+Z on quiz page
- Swift app receives keyboard event
- But has no way to know which URL to scrape
- Scraper needs: `node scraper.js --url=https://iubh-onlineexams.de/mod/quiz/attempt.php?attempt=1940889&cmid=22969`

---

## Solution Options

### Option 1: AppleScript (Recommended)
Get URL from active browser tab using AppleScript:

```swift
func getCurrentBrowserURL() -> String? {
    let script = """
    tell application "Google Chrome"
        return URL of active tab of front window
    end tell
    """

    let appleScript = NSAppleScript(source: script)
    let result = appleScript?.executeAndReturnError(nil)
    return result?.stringValue
}
```

**Pros**:
- Works with Chrome, Safari, Brave
- No browser extension needed
- Simple implementation

**Cons**:
- Requires user permission for AppleScript
- Browser-specific (need separate scripts for Chrome/Safari)

### Option 2: Clipboard-Based
User copies URL first, then presses keyboard shortcut:

```swift
func getCurrentBrowserURL() -> String? {
    let pasteboard = NSPasteboard.general
    return pasteboard.string(forType: .string)
}
```

**Pros**:
- Simple, no permissions needed
- Works with any browser

**Cons**:
- Extra step for user (copy URL first)
- Less seamless UX

### Option 3: Browser Extension
Create Chrome/Safari extension to communicate with Swift app:

**Pros**:
- Most reliable
- Can inject directly into quiz page
- No AppleScript needed

**Cons**:
- Complex implementation
- Requires browser extension installation
- Separate extensions for each browser

---

## Recommended Implementation Plan

### Step 1: Implement AppleScript URL Detection
- Add `getCurrentBrowserURL()` function to QuizIntegrationManager
- Support both Chrome and Safari
- Fall back to clipboard if AppleScript fails

### Step 2: Launch Scraper with URL
```swift
func keyboardShortcutTriggered() {
    guard let url = getCurrentBrowserURL() else {
        print("❌ Could not get browser URL")
        return
    }

    print("🌐 Detected URL: \(url)")
    launchScraper(url: url)
}

func launchScraper(url: String) {
    let task = Process()
    task.launchPath = "/usr/local/bin/node"
    task.arguments = [
        "/Users/marvinbarsal/Desktop/Universität/Stats/scraper.js",
        "--url=\(url)"
    ]
    task.launch()
}
```

### Step 3: Handle Authentication
- Scraper needs to maintain session cookies
- Use Playwright's persistent context:
  ```javascript
  const context = await browser.newContext({
      storageState: 'auth-state.json'
  });
  ```
- Save cookies after manual login
- Reuse cookies on subsequent scrapes

---

## Testing Plan

### Manual Scraper Test
```bash
cd /Users/marvinbarsal/Desktop/Universität/Stats
node scraper.js --url="https://iubh-onlineexams.de/mod/quiz/attempt.php?attempt=1940889&cmid=22969"
```

**Expected Behavior**:
1. Scraper extracts 14 multiple-choice questions
2. Ignores 6 text-input questions (not parseable)
3. Sends questions to AI parser on port 3001
4. AI parser structures Q&A
5. Backend analyzes with OpenAI
6. Returns answer indices [3, 2, 4, ...]

**Challenge**: Authentication required - scraper won't have session cookies

---

## Next Steps

1. ✅ Document quiz structure (this file)
2. 🔄 Test scraper manually (may fail due to auth)
3. ⏳ Implement URL detection in QuizIntegrationManager
4. ⏳ Handle authentication (persistent cookies)
5. ⏳ Test complete workflow end-to-end

---

**Status**: Issue identified - URL detection missing in QuizIntegrationManager
**Priority**: CRITICAL - This is the root cause of keyboard shortcut failure
