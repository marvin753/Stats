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
