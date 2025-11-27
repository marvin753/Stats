# Question Number Extraction & Deduplication - Test Examples

## Test Scenario 1: Simple Deduplication

### Input (7 Screenshots with Overlapping Questions)

```json
[
  {"questionNumber": 1, "question": "Was ist die Hauptstadt von Deutschland?", "answers": ["Berlin", "München", "Hamburg", "Frankfurt"]},
  {"questionNumber": 2, "question": "Wie viele Bundesländer hat Deutschland?", "answers": []},
  {"questionNumber": 2, "question": "Wie viele Bundesländer hat Deutschland?", "answers": ["14", "15", "16", "17"]},
  {"questionNumber": 3, "question": "Welches Jahr war die Deutsche Wiedervereinigung?", "answers": ["1989", "1990", "1991", "1992"]},
  {"questionNumber": 3, "question": "Welches Jahr war die Deutsche Wiedervereinigung?", "answers": ["1989", "1990", "1991", "1992"]},
  {"questionNumber": 4, "question": "Wer war der erste Bundeskanzler?", "answers": []},
  {"questionNumber": 4, "question": "Wer war der erste Bundeskanzler?", "answers": ["Konrad Adenauer", "Willy Brandt", "Helmut Schmidt", "Helmut Kohl"]}
]
```

### Expected Console Output

```
🔍 Deduplicating questions...
   Total questions before deduplication: 7
   Q2: Replacing partial with complete version
   Q3: Keeping existing version
   Q4: Replacing partial with complete version
   Total questions after deduplication: 4
   Question numbers: [1, 2, 3, 4]
⚠️  Found 0 questions without answers (will not be sent to OpenAI)
✅ Final question count: 4 complete questions
```

### Output (Deduplicated & Filtered)

```json
[
  {"questionNumber": 1, "question": "Was ist die Hauptstadt von Deutschland?", "answers": ["Berlin", "München", "Hamburg", "Frankfurt"]},
  {"questionNumber": 2, "question": "Wie viele Bundesländer hat Deutschland?", "answers": ["14", "15", "16", "17"]},
  {"questionNumber": 3, "question": "Welches Jahr war die Deutsche Wiedervereinigung?", "answers": ["1989", "1990", "1991", "1992"]},
  {"questionNumber": 4, "question": "Wer war der erste Bundeskanzler?", "answers": ["Konrad Adenauer", "Willy Brandt", "Helmut Schmidt", "Helmut Kohl"]}
]
```

## Test Scenario 2: Question Number Extraction Formats

### Input (OpenAI Vision Extraction)

The AI should recognize these question number formats:

```
Screenshot 1:
"1. Was ist die Hauptstadt von Deutschland?"
→ questionNumber: 1

Screenshot 2:
"2) Wie viele Bundesländer hat Deutschland?"
→ questionNumber: 2

Screenshot 3:
"Frage 3: Welches Jahr war die Deutsche Wiedervereinigung?"
→ questionNumber: 3

Screenshot 4:
"Aufgabe 4 - Wer war der erste Bundeskanzler?"
→ questionNumber: 4

Screenshot 5:
"Question 5: What is the capital of Germany?"
→ questionNumber: 5
```

### Expected Extraction

```json
[
  {"questionNumber": 1, "question": "Was ist die Hauptstadt von Deutschland?", "answers": ["Berlin", "München", "Hamburg", "Frankfurt"]},
  {"questionNumber": 2, "question": "Wie viele Bundesländer hat Deutschland?", "answers": ["14", "15", "16", "17"]},
  {"questionNumber": 3, "question": "Welches Jahr war die Deutsche Wiedervereinigung?", "answers": ["1989", "1990", "1991", "1992"]},
  {"questionNumber": 4, "question": "Wer war der erste Bundeskanzler?", "answers": ["Konrad Adenauer", "Willy Brandt", "Helmut Schmidt", "Helmut Kohl"]},
  {"questionNumber": 5, "question": "What is the capital of Germany?", "answers": ["London", "Paris", "Berlin", "Madrid"]}
]
```

## Test Scenario 3: Invalid Question Numbers

### Input (Questions with Invalid/Missing Numbers)

```json
[
  {"questionNumber": 1, "question": "Valid Q1", "answers": ["A", "B", "C", "D"]},
  {"question": "Missing number", "answers": ["A", "B"]},
  {"questionNumber": 0, "question": "Invalid number (0)", "answers": ["A", "B"]},
  {"questionNumber": 25, "question": "Invalid number (>20)", "answers": ["A", "B"]},
  {"questionNumber": 2, "question": "Valid Q2", "answers": ["X", "Y", "Z"]}
]
```

### Expected Console Output

```
⚠️  Missing or invalid questionNumber
⚠️  Missing or invalid questionNumber
⚠️  Missing or invalid questionNumber
  ✓ Q1: "Valid Q1" (4 answers)
  ✓ Q2: "Valid Q2" (3 answers)
```

### Output (Only Valid Questions)

```json
[
  {"questionNumber": 1, "question": "Valid Q1", "answers": ["A", "B", "C", "D"]},
  {"questionNumber": 2, "question": "Valid Q2", "answers": ["X", "Y", "Z"]}
]
```

## Test Scenario 4: Partial Questions (No Answers)

### Input (Some Questions Without Answers)

```json
[
  {"questionNumber": 1, "question": "Q1 with answers", "answers": ["A", "B", "C", "D"]},
  {"questionNumber": 2, "question": "Q2 partial only", "answers": []},
  {"questionNumber": 3, "question": "Q3 with answers", "answers": ["X", "Y", "Z"]},
  {"questionNumber": 4, "question": "Q4 partial only", "answers": []}
]
```

### Expected Console Output

```
🔍 Deduplicating questions...
   Total questions before deduplication: 4
   Total questions after deduplication: 4
   Question numbers: [1, 2, 3, 4]
⚠️  Found 2 questions without answers (will not be sent to OpenAI)
✅ Final question count: 2 complete questions
```

### Output (Only Complete Questions)

```json
[
  {"questionNumber": 1, "question": "Q1 with answers", "answers": ["A", "B", "C", "D"]},
  {"questionNumber": 3, "question": "Q3 with answers", "answers": ["X", "Y", "Z"]}
]
```

## Test Scenario 5: Real-World Quiz (14 Questions, Some Duplicates)

### Input (Realistic Quiz Extraction)

```json
[
  {"questionNumber": 1, "question": "Statistische Grundlagen?", "answers": ["A", "B", "C", "D"]},
  {"questionNumber": 2, "question": "Normalverteilung?", "answers": []},
  {"questionNumber": 2, "question": "Normalverteilung?", "answers": ["μ=0, σ=1", "μ=1, σ=0", "μ=0, σ=2", "μ=2, σ=1"]},
  {"questionNumber": 3, "question": "T-Test?", "answers": ["Paired", "Independent", "One-sample", "All"]},
  {"questionNumber": 4, "question": "P-Wert?", "answers": []},
  {"questionNumber": 4, "question": "P-Wert?", "answers": ["<0.05", "<0.01", "<0.1", "Alle"]},
  {"questionNumber": 5, "question": "ANOVA?", "answers": ["2+ groups", "1 group", "Paired only", "None"]},
  {"questionNumber": 6, "question": "Korrelation?", "answers": ["Pearson", "Spearman", "Kendall", "Alle"]},
  {"questionNumber": 7, "question": "Regression?", "answers": []},
  {"questionNumber": 7, "question": "Regression?", "answers": ["Linear", "Logistic", "Polynomial", "Alle"]},
  {"questionNumber": 8, "question": "Chi-Quadrat?", "answers": ["Categorical", "Continuous", "Both", "None"]},
  {"questionNumber": 9, "question": "Konfidenzintervall?", "answers": ["95%", "99%", "90%", "Alle"]},
  {"questionNumber": 10, "question": "Hypothesentest?", "answers": ["H0 vs H1", "H1 vs H2", "H0 only", "None"]},
  {"questionNumber": 11, "question": "Stichprobengröße?", "answers": []},
  {"questionNumber": 11, "question": "Stichprobengröße?", "answers": ["n>30", "n>50", "n>100", "Alle"]},
  {"questionNumber": 12, "question": "Varianz?", "answers": ["σ²", "σ", "μ", "x̄"]},
  {"questionNumber": 13, "question": "Standardabweichung?", "answers": ["σ", "σ²", "μ", "x̄"]},
  {"questionNumber": 14, "question": "Median?", "answers": ["50th percentile", "Mean", "Mode", "Range"]}
]
```

### Expected Console Output

```
🔍 Deduplicating questions...
   Total questions before deduplication: 18
   Q2: Replacing partial with complete version
   Q4: Replacing partial with complete version
   Q7: Replacing partial with complete version
   Q11: Replacing partial with complete version
   Total questions after deduplication: 14
   Question numbers: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]
⚠️  Found 0 questions without answers (will not be sent to OpenAI)
✅ Final question count: 14 complete questions
```

### Output (14 Complete, Deduplicated Questions)

```json
[
  {"questionNumber": 1, "question": "Statistische Grundlagen?", "answers": ["A", "B", "C", "D"]},
  {"questionNumber": 2, "question": "Normalverteilung?", "answers": ["μ=0, σ=1", "μ=1, σ=0", "μ=0, σ=2", "μ=2, σ=1"]},
  {"questionNumber": 3, "question": "T-Test?", "answers": ["Paired", "Independent", "One-sample", "All"]},
  {"questionNumber": 4, "question": "P-Wert?", "answers": ["<0.05", "<0.01", "<0.1", "Alle"]},
  {"questionNumber": 5, "question": "ANOVA?", "answers": ["2+ groups", "1 group", "Paired only", "None"]},
  {"questionNumber": 6, "question": "Korrelation?", "answers": ["Pearson", "Spearman", "Kendall", "Alle"]},
  {"questionNumber": 7, "question": "Regression?", "answers": ["Linear", "Logistic", "Polynomial", "Alle"]},
  {"questionNumber": 8, "question": "Chi-Quadrat?", "answers": ["Categorical", "Continuous", "Both", "None"]},
  {"questionNumber": 9, "question": "Konfidenzintervall?", "answers": ["95%", "99%", "90%", "Alle"]},
  {"questionNumber": 10, "question": "Hypothesentest?", "answers": ["H0 vs H1", "H1 vs H2", "H0 only", "None"]},
  {"questionNumber": 11, "question": "Stichprobengröße?", "answers": ["n>30", "n>50", "n>100", "Alle"]},
  {"questionNumber": 12, "question": "Varianz?", "answers": ["σ²", "σ", "μ", "x̄"]},
  {"questionNumber": 13, "question": "Standardabweichung?", "answers": ["σ", "σ²", "μ", "x̄"]},
  {"questionNumber": 14, "question": "Median?", "answers": ["50th percentile", "Mean", "Mode", "Range"]}
]
```

## Implementation Summary

### Changes Made to VisionAIService.swift

1. **Updated System Prompt** (lines 291-318)
   - Added questionNumber extraction rules
   - Added examples of different question number formats
   - Added examples showing expected JSON structure

2. **Updated parseQuizQuestions Method** (lines 384-414)
   - Added validation for questionNumber field
   - Validates questionNumber is between 1-20
   - Returns validated questions with questionNumber, question, and answers

3. **Added deduplicateQuestions Method** (lines 417-478)
   - Groups questions by questionNumber
   - Prefers complete versions (with answers) over partial
   - Keeps longer answer lists when both versions have answers
   - Sorts by question number
   - Returns deduplicated array

4. **Updated extractQuizQuestions Method** (lines 204-220)
   - Calls deduplicateQuestions after batch processing
   - Filters to only complete questions (with answers)
   - Logs count of incomplete questions
   - Returns final filtered list

### Key Features

- Question numbers extracted from various formats (1., 2), Frage 3, Aufgabe 4, etc.)
- Duplicate detection by question number
- Preference for complete versions (with answers)
- Sorting by question number for correct order
- Filtering of incomplete questions
- Detailed console logging for debugging

### Expected Behavior

1. Screenshots captured with overlapping questions
2. OpenAI extracts all questions with numbers
3. Deduplication removes duplicates, keeping complete versions
4. Filtering removes questions without answers
5. Final list sent to OpenAI for analysis
6. Quiz answers displayed in correct order

## Testing Instructions

1. Build the Swift app:
   ```bash
   cd /Users/marvinbarsal/Desktop/Universität/Stats/cloned-stats
   xcodebuild -project Stats.xcodeproj -scheme Stats -configuration Debug \
     CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build
   ```

2. Run the app and capture quiz screenshots with Cmd+Option+P

3. Monitor console output for deduplication logs:
   ```
   🔍 Deduplicating questions...
      Total questions before deduplication: X
      QN: Replacing partial with complete version
      ...
      Total questions after deduplication: Y
      Question numbers: [1, 2, 3, ...]
   ⚠️  Found N questions without answers (will not be sent to OpenAI)
   ✅ Final question count: M complete questions
   ```

4. Verify correct number of questions sent to OpenAI

5. Check animation displays correct answers in order
