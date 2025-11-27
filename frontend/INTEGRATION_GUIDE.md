# Frontend Security Integration Guide

**Version**: 2.0.0
**Last Updated**: November 4, 2025
**Status**: Production Ready

---

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Module Documentation](#module-documentation)
4. [API Integration](#api-integration)
5. [Security Features](#security-features)
6. [Error Handling](#error-handling)
7. [Rate Limiting](#rate-limiting)
8. [URL Validation](#url-validation)
9. [Configuration](#configuration)
10. [Best Practices](#best-practices)
11. [Troubleshooting](#troubleshooting)

---

## Overview

The Quiz Stats Animation System frontend has been enhanced with enterprise-grade security features to match the backend security improvements. This guide covers the integration of all security features into your frontend application.

### Key Features

- **API Authentication**: Secure API key management with X-API-Key header
- **CORS Protection**: Client-side CORS error handling
- **Rate Limiting**: Client-side tracking and retry logic with exponential backoff
- **SSRF Protection**: URL validation matching backend whitelist rules
- **Error Handling**: User-friendly error messages for all security scenarios
- **Real-time Validation**: Live URL and input validation with visual feedback

### Architecture

```
frontend/
├── config.js              # Configuration and environment settings
├── api-client.js          # API communication with security features
├── error-handler.js       # Centralized error handling
├── url-validator.js       # URL validation and SSRF protection
├── scraper-ui.html        # Enhanced UI with security features
├── INTEGRATION_GUIDE.md   # This file
├── API_REFERENCE.md       # API documentation
└── TESTING_GUIDE.md       # Testing procedures
```

---

## Quick Start

### 1. Include Modules in Your HTML

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Quiz Scraper</title>
</head>
<body>
  <!-- Your UI -->

  <!-- Import modules (ES6 modules) -->
  <script type="module">
    import config from './config.js';
    import apiClient from './api-client.js';
    import ErrorHandler from './error-handler.js';
    import UrlValidator from './url-validator.js';

    // Your code here
  </script>
</body>
</html>
```

### 2. Configure API Key

```javascript
// Set API key (stored in sessionStorage)
config.setApiKey('YOUR_API_KEY_HERE');

// Verify configuration
console.log(config.getSummary());
```

### 3. Validate URLs

```javascript
// Validate a URL
const result = UrlValidator.validate('https://example.com/quiz');

if (result.isValid) {
  console.log('URL is valid');
} else {
  console.error('Validation errors:', result.errors);
}
```

### 4. Make API Calls

```javascript
// Analyze questions
try {
  const questions = [
    {
      question: "What is 2+2?",
      answers: ["3", "4", "5", "6"]
    }
  ];

  const result = await apiClient.analyzeQuestions(questions);
  console.log('Answers:', result.answers);
} catch (error) {
  const parsedError = ErrorHandler.handleApiError(error);
  console.error(parsedError.userMessage);
}
```

---

## Module Documentation

### config.js

Central configuration for the entire frontend application.

#### Key Exports

```javascript
// Get API endpoint URL
const url = config.getApiUrl('/api/analyze');

// Check if API key is configured
if (!config.hasApiKey()) {
  // Prompt user for API key
}

// Set API key
config.setApiKey('your-key-here');

// Get configuration summary
const summary = config.getSummary();
```

#### Environment Variables

The config module automatically detects the environment:

- **Development**: `localhost` or `127.0.0.1`
- **Staging**: URLs containing `staging`
- **Production**: Everything else

Configuration values change automatically based on environment.

#### Feature Flags

```javascript
config.FEATURES = {
  ENABLE_RATE_LIMIT_TRACKING: true,
  ENABLE_RETRY_LOGIC: true,
  ENABLE_DETAILED_ERRORS: true,  // Development only
  ENABLE_REQUEST_LOGGING: true,  // Development only
  ENABLE_PERFORMANCE_MONITORING: true
}
```

---

### api-client.js

Handles all API communication with built-in security features.

#### Basic Usage

```javascript
import apiClient from './api-client.js';

// Health check
const health = await apiClient.healthCheck();

// Analyze questions
const result = await apiClient.analyzeQuestions(questions);

// Get rate limit status
const status = apiClient.getRateLimitStatus();
console.log(`${status.openai.remaining} requests remaining`);
```

#### Advanced Features

**Automatic Retry Logic**

```javascript
// Automatically retries on rate limit (429) errors
// with exponential backoff
try {
  const result = await apiClient.analyzeQuestions(questions);
} catch (error) {
  // Only throws if max retries exceeded
}
```

**Rate Limit Tracking**

```javascript
// Check if near rate limit
const status = apiClient.getRateLimitStatus();

if (status.openai.isNearLimit) {
  alert('Warning: Approaching rate limit');
}

if (status.openai.remaining === 0) {
  alert(`Rate limit exceeded. Reset in ${status.openai.resetIn}ms`);
}
```

**Request Logging** (Development Only)

All requests are automatically logged in development:

```
[API] POST http://localhost:3000/api/analyze
Timestamp: 2025-11-04T10:30:00.000Z
Has API Key: true
Body: { questions: [...] }

[API] Response from http://localhost:3000/api/analyze
Status: 200 OK
Duration: 1234ms
Rate Limit Headers: {...}
```

---

### error-handler.js

Centralized error handling for all error types.

#### Basic Usage

```javascript
import ErrorHandler from './error-handler.js';

try {
  // Your code
} catch (error) {
  // Parse error
  const parsedError = ErrorHandler.parseError(error);

  // Display to user
  ErrorHandler.displayError(error, errorContainer);

  // Get user message
  const message = ErrorHandler.getUserMessage(error);

  // Check if retryable
  if (ErrorHandler.isRetryable(error)) {
    const delay = ErrorHandler.getRetryDelay(error);
    console.log(`Can retry in ${delay} seconds`);
  }
}
```

#### Error Types

- **CORS**: CORS policy violations
- **AUTH**: Authentication errors (401, 403)
- **RATE_LIMIT**: Rate limiting (429)
- **URL_VALIDATION**: URL validation failures
- **NETWORK**: Network connectivity issues
- **SERVER**: Server errors (5xx)
- **UNKNOWN**: Unexpected errors

#### Error Display

```javascript
// Display error in container
const errorContainer = document.getElementById('errors');
ErrorHandler.displayError(error, errorContainer);

// Create custom notification
const parsedError = ErrorHandler.parseError(error);
showNotification({
  title: 'Error',
  message: parsedError.userMessage,
  type: parsedError.severity
});
```

#### Error Properties

```javascript
const parsedError = ErrorHandler.parseError(error);

console.log(parsedError.type);              // Error type
console.log(parsedError.severity);          // info|warning|error|critical
console.log(parsedError.message);           // Technical message
console.log(parsedError.userMessage);       // User-friendly message
console.log(parsedError.retryable);         // Can retry?
console.log(parsedError.retryAfter);        // Seconds until retry
console.log(parsedError.actionable);        // Can user fix?
console.log(parsedError.actionMessage);     // What user should do
console.log(parsedError.code);              // Error code
```

---

### url-validator.js

Client-side URL validation matching backend SSRF protection.

#### Basic Usage

```javascript
import UrlValidator from './url-validator.js';

// Validate URL
const result = UrlValidator.validate(urlString);

if (result.isValid) {
  // URL is safe to use
  proceedWithScraping(urlString);
} else {
  // Show errors
  result.errors.forEach(error => {
    console.error(error.message);
  });
}
```

#### Quick Validation

```javascript
// Boolean check
if (UrlValidator.isValid(url)) {
  // Valid
}

// Get errors as array
const errors = UrlValidator.getErrors(url);

// Validate or throw
try {
  UrlValidator.validateOrThrow(url);
  // Valid
} catch (error) {
  console.error(error.message);
}
```

#### Live Validation

```javascript
// Real-time validation for input fields
urlInput.addEventListener('input', (e) => {
  const result = UrlValidator.validateLive(e.target.value, {
    showWarnings: true,
    showInfo: false
  });

  updateValidationUI(result);
});
```

#### Validation Rules

The validator checks for:

1. **Protocol**: Only `http://` and `https://` allowed
2. **Private IPs**: Blocks RFC 1918, RFC 4193, RFC 3927 ranges
3. **Cloud Metadata**: Blocks 169.254.169.254 and similar
4. **Whitelist**: Only allowed domains accepted

#### Batch Validation

```javascript
// Validate multiple URLs
const urls = [
  'https://example.com/quiz1',
  'https://example.com/quiz2',
  'http://192.168.1.1/admin'  // Invalid
];

const stats = UrlValidator.getValidationStats(urls);
console.log(`${stats.valid}/${stats.total} URLs valid`);
```

---

## API Integration

### Complete Example

```javascript
import config from './config.js';
import apiClient from './api-client.js';
import ErrorHandler from './error-handler.js';
import UrlValidator from './url-validator.js';

async function analyzeQuiz() {
  const url = document.getElementById('urlInput').value;
  const errorContainer = document.getElementById('errors');
  const resultsContainer = document.getElementById('results');

  // Clear previous errors
  ErrorHandler.clearErrors(errorContainer);

  // Step 1: Validate URL
  try {
    UrlValidator.validateOrThrow(url);
  } catch (error) {
    ErrorHandler.displayError(error, errorContainer);
    return;
  }

  // Step 2: Check API key
  if (!config.hasApiKey()) {
    alert('Please configure your API key');
    return;
  }

  // Step 3: Check rate limit
  const rateLimitStatus = apiClient.getRateLimitStatus();
  if (rateLimitStatus.openai.remaining === 0) {
    const resetIn = Math.ceil(rateLimitStatus.openai.resetIn / 1000);
    alert(`Rate limit exceeded. Please wait ${resetIn} seconds.`);
    return;
  }

  // Step 4: Show loading
  showLoading();

  try {
    // Step 5: Scrape questions (implement your scraping logic)
    const questions = await scrapeQuestionsFromUrl(url);

    // Step 6: Analyze with AI
    const result = await apiClient.analyzeQuestions(questions);

    // Step 7: Display results
    displayResults(questions, result.answers);

  } catch (error) {
    // Step 8: Handle errors
    const parsedError = ErrorHandler.displayError(error, errorContainer);

    // Optional: Retry logic
    if (parsedError.retryable && parsedError.retryAfter) {
      setTimeout(() => {
        // Retry after delay
        analyzeQuiz();
      }, parsedError.retryAfter * 1000);
    }
  } finally {
    hideLoading();
  }
}
```

---

## Security Features

### 1. API Key Management

**Secure Storage**

API keys are stored in `sessionStorage` (NOT `localStorage`) for security:

```javascript
// Set API key (automatically stored in sessionStorage)
config.setApiKey('your-api-key');

// Clear API key
config.clearApiKey();

// Check if configured
if (config.hasApiKey()) {
  // Proceed with API calls
}
```

**Never hardcode API keys in production!**

```javascript
// ❌ BAD - Hardcoded
const API_KEY = 'sk-1234567890abcdef';

// ✅ GOOD - Environment based
const API_KEY = window.API_KEY || sessionStorage.getItem('quiz_api_key');

// ✅ BEST - Prompt user
if (!config.hasApiKey()) {
  const key = prompt('Enter your API key:');
  config.setApiKey(key);
}
```

### 2. CORS Error Handling

CORS errors are automatically detected and handled:

```javascript
try {
  await apiClient.analyzeQuestions(questions);
} catch (error) {
  const parsed = ErrorHandler.parseError(error);

  if (parsed.type === 'CORS') {
    // CORS error - show helpful message
    console.error(parsed.userMessage);
    console.info(parsed.actionMessage);
  }
}
```

### 3. Rate Limiting

**Client-Side Tracking**

```javascript
// Get current rate limit status
const status = apiClient.getRateLimitStatus();

console.log('OpenAI endpoint:');
console.log(`  Used: ${status.openai.used}`);
console.log(`  Limit: ${status.openai.limit}`);
console.log(`  Remaining: ${status.openai.remaining}`);
console.log(`  Reset in: ${status.openai.resetIn}ms`);
console.log(`  Near limit: ${status.openai.isNearLimit}`);
```

**Automatic Retry**

The API client automatically retries rate-limited requests:

```javascript
// Automatically retries up to 3 times with exponential backoff
const result = await apiClient.analyzeQuestions(questions);
```

**Manual Rate Limit Check**

```javascript
// Check before making request
const status = apiClient.getRateLimitStatus();

if (status.openai.remaining === 0) {
  const seconds = Math.ceil(status.openai.resetIn / 1000);
  showMessage(`Rate limit exceeded. Please wait ${seconds} seconds.`);
  return;
}

// Show warning if near limit
if (status.openai.isNearLimit) {
  showWarning(`Only ${status.openai.remaining} requests remaining`);
}
```

### 4. URL Validation (SSRF Protection)

All URLs are validated before use:

```javascript
// Comprehensive validation
const result = UrlValidator.validate(url);

if (!result.isValid) {
  result.errors.forEach(error => {
    console.error(`${error.code}: ${error.message}`);
  });
}

// What's checked:
// ✓ Protocol (http/https only)
// ✓ Private IPs (10.x, 192.168.x, 127.x, etc.)
// ✓ Cloud metadata (169.254.169.254)
// ✓ Domain whitelist
```

---

## Error Handling

### Error Flow

```
User Action → API Call → Error Occurs
                              ↓
                    ErrorHandler.parseError()
                              ↓
                    Determine Error Type
                              ↓
        ┌───────────────────┴───────────────────┐
        ↓                   ↓                    ↓
    RETRYABLE          ACTIONABLE           CRITICAL
        ↓                   ↓                    ↓
   Retry Logic      Show Help Message    Alert User
```

### Handling Different Error Types

#### Authentication Errors

```javascript
try {
  await apiClient.analyzeQuestions(questions);
} catch (error) {
  const parsed = ErrorHandler.parseError(error);

  if (parsed.code === 'AUTH_NO_KEY') {
    // Prompt for API key
    const key = prompt('Please enter your API key:');
    config.setApiKey(key);
    // Retry
    await apiClient.analyzeQuestions(questions);
  }

  if (parsed.code === 'AUTH_INVALID') {
    // Clear invalid key and prompt again
    config.clearApiKey();
    alert('Invalid API key. Please try again.');
  }
}
```

#### Rate Limit Errors

```javascript
try {
  await apiClient.analyzeQuestions(questions);
} catch (error) {
  const parsed = ErrorHandler.parseError(error);

  if (parsed.type === 'RATE_LIMIT') {
    // Show countdown
    if (parsed.retryAfter) {
      showCountdown(parsed.retryAfter, () => {
        // Retry after countdown
        analyzeQuiz();
      });
    }
  }
}
```

#### Network Errors

```javascript
try {
  await apiClient.analyzeQuestions(questions);
} catch (error) {
  const parsed = ErrorHandler.parseError(error);

  if (parsed.type === 'NETWORK') {
    // Check connectivity
    if (!navigator.onLine) {
      alert('No internet connection');
    } else {
      alert('Network error. Please try again.');
    }
  }
}
```

---

## Rate Limiting

### Understanding Rate Limits

The backend implements two-tier rate limiting:

1. **General**: 100 requests per 15 minutes per IP
2. **OpenAI**: 10 requests per minute per IP

### Client-Side Tracking

The frontend tracks rate limit usage in `sessionStorage`:

```javascript
// Rate limit tracker stores:
{
  requests: [
    { endpoint: '/api/analyze', timestamp: 1699123456789 },
    { endpoint: '/api/analyze', timestamp: 1699123457890 },
    ...
  ]
}
```

### Display Rate Limit Info to Users

```javascript
function updateRateLimitDisplay() {
  const status = apiClient.getRateLimitStatus();

  document.getElementById('remaining').textContent =
    `${status.openai.remaining}/${status.openai.limit}`;

  document.getElementById('resetTime').textContent =
    `Resets in ${Math.ceil(status.openai.resetIn / 1000)}s`;

  // Change color based on usage
  if (status.openai.remaining === 0) {
    // Red - rate limited
    element.style.color = 'red';
  } else if (status.openai.isNearLimit) {
    // Orange - warning
    element.style.color = 'orange';
  } else {
    // Green - OK
    element.style.color = 'green';
  }
}

// Update every second
setInterval(updateRateLimitDisplay, 1000);
```

### Handling Rate Limit Errors

```javascript
async function makeRequestWithRetry() {
  try {
    return await apiClient.analyzeQuestions(questions);
  } catch (error) {
    const parsed = ErrorHandler.parseError(error);

    if (parsed.code === 'RATE_LIMIT_EXCEEDED') {
      // Show error with retry time
      showError(`Rate limit exceeded. Please wait ${parsed.retryAfter}s`);

      // Disable button and show countdown
      disableButton();
      startCountdown(parsed.retryAfter, () => {
        enableButton();
      });
    }
  }
}
```

---

## URL Validation

### Validation Process

```
User Input → validateLive() → Real-time Feedback
                                     ↓
User Submits → validate() → Comprehensive Check
                                     ↓
                            Pass/Fail + Messages
```

### Real-Time Validation

```html
<input type="text" id="urlInput" />
<div id="validation"></div>

<script type="module">
import UrlValidator from './url-validator.js';

const input = document.getElementById('urlInput');
const validation = document.getElementById('validation');

input.addEventListener('input', () => {
  const result = UrlValidator.validateLive(input.value);

  // Update UI
  if (result.isValid) {
    input.classList.add('valid');
    input.classList.remove('invalid');
  } else {
    input.classList.add('invalid');
    input.classList.remove('valid');
  }

  // Show messages
  validation.innerHTML = UrlValidator.createValidationMessageHtml(result);
});
</script>
```

### Custom Validation Messages

```javascript
const result = UrlValidator.validate(url);

// Get all messages
result.getAllMessages().forEach(msg => {
  if (msg.type === 'error') {
    console.error(`❌ ${msg.message}`);
  } else if (msg.type === 'warning') {
    console.warn(`⚠️ ${msg.message}`);
  }
});

// Get specific error info
if (result.info.allowedDomains) {
  console.log('Allowed domains:', result.info.allowedDomains.join(', '));
}
```

---

## Configuration

### Environment-Based Configuration

```javascript
// Development
if (config.ENV.isDevelopment) {
  config.API_CONFIG.BACKEND_URL = 'http://localhost:3000';
  config.FEATURES.ENABLE_REQUEST_LOGGING = true;
  config.FEATURES.ENABLE_DETAILED_ERRORS = true;
}

// Production
if (config.ENV.isProduction) {
  config.API_CONFIG.BACKEND_URL = 'https://api.example.com';
  config.FEATURES.ENABLE_REQUEST_LOGGING = false;
  config.FEATURES.ENABLE_DETAILED_ERRORS = false;
}
```

### Custom Configuration

```javascript
// Override via window object (set before importing modules)
window.BACKEND_URL = 'https://custom-api.example.com';
window.API_KEY = 'your-api-key';
window.ALLOWED_DOMAINS = ['custom1.com', 'custom2.com'];

// Or modify after import
import config from './config.js';
config.API_CONFIG.BACKEND_URL = 'https://custom-api.example.com';
```

---

## Best Practices

### 1. Always Validate User Input

```javascript
// ✅ GOOD
const result = UrlValidator.validate(userInput);
if (result.isValid) {
  await scrapeUrl(userInput);
}

// ❌ BAD
await scrapeUrl(userInput);  // No validation
```

### 2. Handle All Error Cases

```javascript
// ✅ GOOD
try {
  await apiClient.analyzeQuestions(questions);
} catch (error) {
  const parsed = ErrorHandler.parseError(error);

  switch (parsed.type) {
    case 'AUTH':
      handleAuthError(parsed);
      break;
    case 'RATE_LIMIT':
      handleRateLimitError(parsed);
      break;
    case 'NETWORK':
      handleNetworkError(parsed);
      break;
    default:
      handleGenericError(parsed);
  }
}

// ❌ BAD
try {
  await apiClient.analyzeQuestions(questions);
} catch (error) {
  console.error(error);  // Just log it
}
```

### 3. Provide User Feedback

```javascript
// ✅ GOOD - Show what's happening
showLoading('Analyzing quiz...');
try {
  const result = await apiClient.analyzeQuestions(questions);
  showSuccess('Analysis complete!');
  displayResults(result);
} catch (error) {
  showError(ErrorHandler.getUserMessage(error));
} finally {
  hideLoading();
}

// ❌ BAD - No feedback
await apiClient.analyzeQuestions(questions);
```

### 4. Monitor Rate Limits

```javascript
// ✅ GOOD - Warn users
const status = apiClient.getRateLimitStatus();
if (status.openai.isNearLimit) {
  showWarning(`Only ${status.openai.remaining} requests remaining this minute`);
}

// ❌ BAD - Let user hit the limit
await apiClient.analyzeQuestions(questions);
```

### 5. Secure API Key Storage

```javascript
// ✅ GOOD - Use sessionStorage
config.setApiKey(userProvidedKey);

// ❌ BAD - Use localStorage (persists across sessions)
localStorage.setItem('api_key', key);

// ❌ WORSE - Hardcode
const API_KEY = 'sk-1234567890';
```

---

## Troubleshooting

### Common Issues

#### Issue: "Authentication required"

**Cause**: API key not configured or invalid

**Solution**:
```javascript
// Check if API key is set
if (!config.hasApiKey()) {
  config.setApiKey(prompt('Enter API key:'));
}

// Verify API key format
if (!config.VALIDATION.isValidApiKeyFormat(key)) {
  alert('Invalid API key format');
}
```

#### Issue: "CORS policy violation"

**Cause**: Frontend domain not whitelisted in backend

**Solution**:
1. Add your domain to backend `CORS_ALLOWED_ORIGINS`
2. Restart backend server
3. Clear browser cache

```bash
# Backend .env
CORS_ALLOWED_ORIGINS=http://localhost:8080,https://yourdomain.com
```

#### Issue: "Rate limit exceeded"

**Cause**: Too many requests in short time

**Solution**:
```javascript
// Check rate limit status
const status = apiClient.getRateLimitStatus();
console.log(`Wait ${status.openai.resetIn}ms before next request`);

// Reset tracker (for testing only)
apiClient.resetRateLimitTracker();
```

#### Issue: "Domain not whitelisted"

**Cause**: URL domain not in allowed list

**Solution**:
```javascript
// Check allowed domains
console.log(UrlValidator.getAllowedDomains());

// Add domain to backend whitelist
// In backend .env: ALLOWED_DOMAINS=example.com,yoursite.com
```

#### Issue: Validation not working

**Cause**: Modules not imported correctly

**Solution**:
```html
<!-- Use type="module" -->
<script type="module">
  import UrlValidator from './url-validator.js';
  // Now it works
</script>
```

### Debug Mode

Enable detailed logging:

```javascript
import config from './config.js';

// Enable all logging
config.FEATURES.ENABLE_REQUEST_LOGGING = true;
config.FEATURES.ENABLE_DETAILED_ERRORS = true;

// Check configuration
console.log(config.getSummary());

// Monitor all API calls
// (automatically logged when logging enabled)
```

### Health Check

```javascript
// Test backend connectivity
async function testConnection() {
  try {
    const health = await apiClient.healthCheck();
    console.log('Backend Status:', health);
    console.log('OpenAI Configured:', health.openai_configured);
    console.log('API Key Configured:', health.api_key_configured);
    console.log('Authentication Enabled:', health.security.authentication_enabled);
  } catch (error) {
    console.error('Backend unreachable:', error);
  }
}

testConnection();
```

---

## Support

### Getting Help

1. Check this guide first
2. Review [API_REFERENCE.md](./API_REFERENCE.md)
3. Check [TESTING_GUIDE.md](./TESTING_GUIDE.md)
4. Review browser console for errors
5. Check backend logs

### Reporting Issues

When reporting issues, include:

1. Error message
2. Configuration summary: `config.getSummary()`
3. Rate limit status: `apiClient.getRateLimitStatus()`
4. Browser console output
5. Steps to reproduce

---

**Document Version**: 1.0
**Last Updated**: November 4, 2025
**Author**: Frontend Security Team
