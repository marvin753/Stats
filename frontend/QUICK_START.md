# Frontend Quick Start Guide

**Get up and running in 5 minutes!**

---

## Step 1: Include the Modules (30 seconds)

Copy this into your HTML file:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Quiz Scraper</title>
</head>
<body>
  <div id="app">
    <input type="text" id="url" placeholder="Enter quiz URL">
    <button id="analyze">Analyze</button>
    <div id="errors"></div>
    <div id="results"></div>
  </div>

  <script type="module">
    import config from './config.js';
    import apiClient from './api-client.js';
    import ErrorHandler from './error-handler.js';
    import UrlValidator from './url-validator.js';

    // Continue to Step 2...
  </script>
</body>
</html>
```

---

## Step 2: Set API Key (30 seconds)

```javascript
// Set your API key (get from your backend admin)
config.setApiKey('your-api-key-here');

// Verify it's set
if (config.hasApiKey()) {
  console.log('✓ API key configured');
} else {
  alert('Please set your API key!');
}
```

---

## Step 3: Add URL Validation (1 minute)

```javascript
const urlInput = document.getElementById('url');
const analyzeBtn = document.getElementById('analyze');

// Validate URL as user types
urlInput.addEventListener('input', (e) => {
  const result = UrlValidator.validateLive(e.target.value);

  if (result.isValid) {
    urlInput.style.borderColor = 'green';
    analyzeBtn.disabled = false;
  } else {
    urlInput.style.borderColor = 'red';
    analyzeBtn.disabled = true;
  }
});
```

---

## Step 4: Make API Calls (2 minutes)

```javascript
analyzeBtn.addEventListener('click', async () => {
  const url = urlInput.value;
  const errorsDiv = document.getElementById('errors');
  const resultsDiv = document.getElementById('results');

  // Clear previous errors
  ErrorHandler.clearErrors(errorsDiv);

  // Validate URL
  try {
    UrlValidator.validateOrThrow(url);
  } catch (error) {
    ErrorHandler.displayError(error, errorsDiv);
    return;
  }

  // Scrape questions (implement your scraping logic)
  const questions = [
    {
      question: "What is 2+2?",
      answers: ["3", "4", "5", "6"]
    }
  ];

  // Analyze with AI
  try {
    analyzeBtn.disabled = true;
    analyzeBtn.textContent = 'Analyzing...';

    const result = await apiClient.analyzeQuestions(questions);

    // Display results
    resultsDiv.innerHTML = `
      <h3>Results</h3>
      <p>Correct answer: ${result.answers[0]}</p>
    `;

  } catch (error) {
    ErrorHandler.displayError(error, errorsDiv);
  } finally {
    analyzeBtn.disabled = false;
    analyzeBtn.textContent = 'Analyze';
  }
});
```

---

## Step 5: Monitor Rate Limits (1 minute)

```javascript
// Add this to your HTML
// <div id="rate-limit">Remaining: <span id="remaining">10</span></div>

setInterval(() => {
  const status = apiClient.getRateLimitStatus();
  document.getElementById('remaining').textContent = status.openai.remaining;

  if (status.openai.isNearLimit) {
    document.getElementById('rate-limit').style.color = 'orange';
  }
}, 1000);
```

---

## Complete Example

Here's everything together:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Quiz Scraper</title>
  <style>
    body { font-family: Arial; max-width: 600px; margin: 50px auto; }
    input { width: 100%; padding: 10px; margin: 10px 0; }
    button { width: 100%; padding: 10px; background: #667eea; color: white; border: none; cursor: pointer; }
    button:disabled { opacity: 0.5; }
    .error { color: red; padding: 10px; background: #fee; margin: 10px 0; }
    .results { padding: 10px; background: #efe; margin: 10px 0; }
  </style>
</head>
<body>
  <h1>Quiz Scraper</h1>

  <div id="rate-limit">Remaining: <span id="remaining">10</span></div>

  <input type="text" id="url" placeholder="https://example.com/quiz">
  <button id="analyze">Analyze</button>

  <div id="errors"></div>
  <div id="results"></div>

  <script type="module">
    import config from './config.js';
    import apiClient from './api-client.js';
    import ErrorHandler from './error-handler.js';
    import UrlValidator from './url-validator.js';

    // Configure API key
    const apiKey = prompt('Enter your API key:');
    if (!config.setApiKey(apiKey)) {
      alert('Invalid API key format');
    }

    // Elements
    const urlInput = document.getElementById('url');
    const analyzeBtn = document.getElementById('analyze');
    const errorsDiv = document.getElementById('errors');
    const resultsDiv = document.getElementById('results');

    // URL validation
    urlInput.addEventListener('input', (e) => {
      const result = UrlValidator.validateLive(e.target.value);
      urlInput.style.borderColor = result.isValid ? 'green' : 'red';
      analyzeBtn.disabled = !result.isValid;
    });

    // Analyze button
    analyzeBtn.addEventListener('click', async () => {
      const url = urlInput.value;

      ErrorHandler.clearErrors(errorsDiv);

      try {
        UrlValidator.validateOrThrow(url);
      } catch (error) {
        ErrorHandler.displayError(error, errorsDiv);
        return;
      }

      const questions = [
        { question: "What is 2+2?", answers: ["3", "4", "5", "6"] }
      ];

      try {
        analyzeBtn.disabled = true;
        analyzeBtn.textContent = 'Analyzing...';

        const result = await apiClient.analyzeQuestions(questions);

        resultsDiv.className = 'results';
        resultsDiv.innerHTML = `
          <h3>Results</h3>
          <p>Question: ${questions[0].question}</p>
          <p>Correct answer: ${questions[0].answers[result.answers[0] - 1]}</p>
        `;

      } catch (error) {
        ErrorHandler.displayError(error, errorsDiv);
      } finally {
        analyzeBtn.disabled = false;
        analyzeBtn.textContent = 'Analyze';
      }
    });

    // Rate limit monitor
    setInterval(() => {
      const status = apiClient.getRateLimitStatus();
      document.getElementById('remaining').textContent = status.openai.remaining;
    }, 1000);
  </script>
</body>
</html>
```

---

## Testing Your Setup

### 1. Test URL Validation

Try these URLs:

```
✓ https://example.com/quiz          (should work)
✗ http://192.168.1.1                 (private IP - should fail)
✗ ftp://example.com                  (invalid protocol - should fail)
✗ https://evil.com                   (not whitelisted - should fail)
```

### 2. Test API Key

```javascript
// Invalid format
config.setApiKey('short');  // Returns false

// Valid format
config.setApiKey('a'.repeat(32));  // Returns true
```

### 3. Test Rate Limiting

```javascript
// Check status
const status = apiClient.getRateLimitStatus();
console.log(status.openai.remaining);  // Should show remaining requests
```

### 4. Test Error Handling

```javascript
// Force an error
try {
  await apiClient.analyzeQuestions([]);  // Empty array
} catch (error) {
  const parsed = ErrorHandler.parseError(error);
  console.log(parsed.userMessage);  // User-friendly message
}
```

---

## Common Issues

### "Module not found"

Make sure you're using `type="module"` in your script tag:

```html
<script type="module">
  // Your code
</script>
```

### "CORS error"

Add your domain to backend `.env`:

```bash
CORS_ALLOWED_ORIGINS=http://localhost:8080,https://yourdomain.com
```

### "Authentication required"

Make sure API key is set:

```javascript
if (!config.hasApiKey()) {
  config.setApiKey('your-api-key');
}
```

### "Rate limit exceeded"

Wait for reset or check status:

```javascript
const status = apiClient.getRateLimitStatus();
console.log(`Wait ${Math.ceil(status.openai.resetIn / 1000)} seconds`);
```

---

## Next Steps

1. **Read the full documentation**:
   - [README.md](./README.md) - Overview
   - [INTEGRATION_GUIDE.md](./INTEGRATION_GUIDE.md) - Detailed guide
   - [API_REFERENCE.md](./API_REFERENCE.md) - API docs

2. **Check out examples**:
   - [examples/basic-integration.html](./examples/basic-integration.html)
   - [examples/advanced-usage.js](./examples/advanced-usage.js)

3. **Run tests**:
   - [TESTING_GUIDE.md](./TESTING_GUIDE.md)

4. **Customize the UI**:
   - [scraper-ui.html](./scraper-ui.html) - Full implementation

---

## Support

- Check browser console for errors
- Verify configuration: `config.getSummary()`
- Test backend: `apiClient.healthCheck()`

---

**That's it! You're ready to go!** 🎉
