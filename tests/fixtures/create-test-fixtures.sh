#!/bin/bash

echo "============================================================"
echo "Creating Test Fixtures for Integration Tests"
echo "============================================================"
echo ""

FIXTURES_DIR="/Users/marvinbarsal/Desktop/Universität/Stats/tests/fixtures"

# Create mock quiz HTML
echo "1. Creating mock quiz HTML..."
cat > "$FIXTURES_DIR/test-quiz.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Mock Quiz - Integration Test</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .quiz-container {
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            border-bottom: 3px solid #007bff;
            padding-bottom: 10px;
        }
        .question {
            margin: 30px 0;
            padding: 20px;
            background: #f9f9f9;
            border-left: 4px solid #007bff;
        }
        .question-text {
            font-weight: bold;
            font-size: 18px;
            margin-bottom: 15px;
            color: #333;
        }
        .answer {
            display: block;
            margin: 10px 0;
            padding: 10px;
            cursor: pointer;
        }
        .answer:hover {
            background: #e9ecef;
        }
        .long-content {
            height: 2000px;
            background: linear-gradient(to bottom, #fff 0%, #f0f0f0 100%);
            padding: 20px;
            margin-top: 30px;
        }
    </style>
</head>
<body>
    <div class="quiz-container">
        <h1>Statistics Quiz - Integration Test</h1>

        <div class="question">
            <div class="question-text">1. What is the mean of the dataset: 2, 4, 6, 8?</div>
            <label class="answer">
                <input type="radio" name="q1" value="1"> 4
            </label>
            <label class="answer">
                <input type="radio" name="q1" value="2"> 5
            </label>
            <label class="answer">
                <input type="radio" name="q1" value="3"> 6
            </label>
            <label class="answer">
                <input type="radio" name="q1" value="4"> 7
            </label>
        </div>

        <div class="question">
            <div class="question-text">2. Which measure of central tendency is most affected by outliers?</div>
            <label class="answer">
                <input type="radio" name="q2" value="1"> Mean
            </label>
            <label class="answer">
                <input type="radio" name="q2" value="2"> Median
            </label>
            <label class="answer">
                <input type="radio" name="q2" value="3"> Mode
            </label>
            <label class="answer">
                <input type="radio" name="q2" value="4"> Range
            </label>
        </div>

        <div class="question">
            <div class="question-text">3. What is the standard deviation used to measure?</div>
            <label class="answer">
                <input type="radio" name="q3" value="1"> Central tendency
            </label>
            <label class="answer">
                <input type="radio" name="q3" value="2"> Dispersion
            </label>
            <label class="answer">
                <input type="radio" name="q3" value="3"> Correlation
            </label>
            <label class="answer">
                <input type="radio" name="q3" value="4"> Causation
            </label>
        </div>

        <div class="question">
            <div class="question-text">4. In a normal distribution, approximately what percentage of data falls within one standard deviation of the mean?</div>
            <label class="answer">
                <input type="radio" name="q4" value="1"> 50%
            </label>
            <label class="answer">
                <input type="radio" name="q4" value="2"> 68%
            </label>
            <label class="answer">
                <input type="radio" name="q4" value="3"> 95%
            </label>
            <label class="answer">
                <input type="radio" name="q4" value="4"> 99%
            </label>
        </div>

        <div class="long-content">
            <p>This is additional content to test full-page screenshot capture.</p>
            <p>The page extends beyond the viewport to ensure CDP service captures the entire page.</p>
        </div>
    </div>
</body>
</html>
EOF

echo "✅ Mock quiz HTML created: test-quiz.html"
echo ""

# Create mock screenshot (1x1 white pixel PNG)
echo "2. Creating mock screenshot..."
cat > "$FIXTURES_DIR/test-screenshot.png.b64" << 'EOF'
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==
EOF

base64 -d "$FIXTURES_DIR/test-screenshot.png.b64" > "$FIXTURES_DIR/test-screenshot.png"
rm "$FIXTURES_DIR/test-screenshot.png.b64"

echo "✅ Mock screenshot created: test-screenshot.png"
echo ""

# Create README for fixtures
echo "3. Creating fixtures README..."
cat > "$FIXTURES_DIR/README.md" << 'EOF'
# Test Fixtures

This directory contains mock data for integration testing.

## Files

### test-quiz.html
Mock quiz page with 4 statistics questions. Used for testing:
- DOM scraping
- Full-page screenshot capture
- Quiz structure parsing

To view: `open test-quiz.html`

### test-screenshot.png
Minimal 1x1 white pixel PNG for testing screenshot handling.
Used for API payload testing without large data transfer.

### test-script.pdf
**NOT INCLUDED** - Add your own PDF file for testing PDF upload.
The PDF should contain course material or lecture notes.

To create a test PDF:
```bash
# On macOS:
echo "Test PDF Content" | textutil -stdin -output test-script.pdf -format txt -convert pdf
```

## Usage

These fixtures are automatically used by the integration test suite.

Run tests: `npm test`
EOF

echo "✅ Fixtures README created"
echo ""

echo "============================================================"
echo "Test Fixtures Created Successfully"
echo "============================================================"
echo ""
echo "📁 Fixtures location: $FIXTURES_DIR"
echo ""
echo "📋 Created files:"
echo "   ✅ test-quiz.html - Mock quiz page"
echo "   ✅ test-screenshot.png - Mock screenshot"
echo "   ✅ README.md - Fixtures documentation"
echo ""
echo "⚠️  Note: test-script.pdf must be added manually"
echo "   Some tests will be skipped without it"
echo ""
echo "Next steps:"
echo "  1. Open test-quiz.html in browser: open $FIXTURES_DIR/test-quiz.html"
echo "  2. (Optional) Add test-script.pdf for full test coverage"
echo "  3. Run tests: cd /Users/marvinbarsal/Desktop/Universität/Stats/tests && npm test"
echo ""
