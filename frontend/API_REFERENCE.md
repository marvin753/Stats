# Frontend API Reference

**Version**: 2.0.0
**Last Updated**: November 4, 2025

---

## Table of Contents

1. [config.js](#configjs)
2. [api-client.js](#api-clientjs)
3. [error-handler.js](#error-handlerjs)
4. [url-validator.js](#url-validatorjs)

---

## config.js

### Default Export

`config` - Main configuration object

### Properties

#### ENV

Environment detection object.

```javascript
config.ENV = {
  isDevelopment: boolean,
  isStaging: boolean,
  isProduction: boolean
}
```

#### API_CONFIG

API endpoint configuration.

```javascript
config.API_CONFIG = {
  BACKEND_URL: string,
  ENDPOINTS: {
    ANALYZE: '/api/analyze',
    HEALTH: '/health',
    ROOT: '/'
  },
  TIMEOUTS: {
    DEFAULT: 30000,
    ANALYZE: 60000,
    HEALTH_CHECK: 5000
  }
}
```

#### SECURITY_CONFIG

Security and authentication configuration.

```javascript
config.SECURITY_CONFIG = {
  API_KEY: string | null,
  API_KEY_HEADER: 'X-API-Key',
  CORS: {
    ALLOWED_ORIGINS: string[],
    WITH_CREDENTIALS: boolean
  }
}
```

#### URL_VALIDATION_CONFIG

URL validation rules.

```javascript
config.URL_VALIDATION_CONFIG = {
  ALLOWED_DOMAINS: string[],
  ALLOWED_PROTOCOLS: string[],
  PRIVATE_IP_PATTERNS: RegExp[],
  BLOCKED_METADATA_ENDPOINTS: string[]
}
```

#### RATE_LIMIT_CONFIG

Rate limiting configuration.

```javascript
config.RATE_LIMIT_CONFIG = {
  GENERAL: {
    MAX_REQUESTS: 100,
    WINDOW_MS: 900000  // 15 minutes
  },
  OPENAI: {
    MAX_REQUESTS: 10,
    WINDOW_MS: 60000  // 1 minute
  },
  RETRY: {
    MAX_ATTEMPTS: 3,
    INITIAL_DELAY: 1000,
    MAX_DELAY: 30000,
    BACKOFF_MULTIPLIER: 2
  },
  TRACKING: {
    ENABLED: boolean,
    STORAGE_KEY: 'quiz_rate_limit_tracker'
  }
}
```

#### ERROR_MESSAGES

User-friendly error messages.

```javascript
config.ERROR_MESSAGES = {
  CORS_BLOCKED: string,
  AUTH_NO_KEY: string,
  AUTH_INVALID: string,
  RATE_LIMIT_GENERAL: string,
  RATE_LIMIT_ANALYSIS: string,
  URL_INVALID_FORMAT: string,
  URL_PRIVATE_IP: string,
  URL_NOT_WHITELISTED: string,
  NETWORK_ERROR: string,
  // ... more messages
}
```

### Methods

#### getApiUrl(endpoint)

Get full API URL for an endpoint.

**Parameters:**
- `endpoint` (string) - API endpoint path

**Returns:** string - Full URL

**Example:**
```javascript
const url = config.getApiUrl('/api/analyze');
// 'http://localhost:3000/api/analyze'
```

#### hasApiKey()

Check if API key is configured.

**Returns:** boolean

**Example:**
```javascript
if (config.hasApiKey()) {
  // Proceed with API calls
}
```

#### setApiKey(key)

Set and validate API key.

**Parameters:**
- `key` (string) - API key to set

**Returns:** boolean - true if valid and saved

**Example:**
```javascript
const success = config.setApiKey('your-api-key');
if (!success) {
  alert('Invalid API key format');
}
```

#### clearApiKey()

Remove API key from storage.

**Example:**
```javascript
config.clearApiKey();
```

#### getSummary()

Get configuration summary for debugging.

**Returns:** Object with configuration details

**Example:**
```javascript
console.log(config.getSummary());
// {
//   environment: 'development',
//   backendUrl: 'http://localhost:3000',
//   hasApiKey: true,
//   allowedDomains: ['example.com'],
//   features: {...},
//   version: '2.0.0'
// }
```

---

## api-client.js

### Default Export

`apiClient` - Singleton API client instance

### Methods

#### healthCheck()

Check backend health status.

**Returns:** Promise<Object>

**Example:**
```javascript
const health = await apiClient.healthCheck();
console.log(health.status);  // 'ok'
```

**Response Format:**
```javascript
{
  status: 'ok',
  timestamp: string,
  openai_configured: boolean,
  api_key_configured: boolean,
  security: {
    cors_enabled: boolean,
    authentication_enabled: boolean
  }
}
```

#### analyzeQuestions(questions)

Analyze quiz questions with AI.

**Parameters:**
- `questions` (Array) - Array of question objects

**Returns:** Promise<Object>

**Throws:**
- Error if API key not configured
- Error if rate limited
- Error if validation fails

**Example:**
```javascript
const questions = [
  {
    question: "What is 2+2?",
    answers: ["3", "4", "5"]
  }
];

try {
  const result = await apiClient.analyzeQuestions(questions);
  console.log(result.answers);  // [2]
} catch (error) {
  console.error(ErrorHandler.getUserMessage(error));
}
```

**Response Format:**
```javascript
{
  status: 'success',
  answers: number[],
  questionCount: number,
  message: string
}
```

#### getRateLimitStatus()

Get current rate limit status.

**Returns:** Object with rate limit information

**Example:**
```javascript
const status = apiClient.getRateLimitStatus();

console.log(status.openai.remaining);  // 8
console.log(status.openai.limit);      // 10
console.log(status.openai.resetIn);    // 45000 (ms)
console.log(status.openai.isNearLimit); // false
```

**Response Format:**
```javascript
{
  openai: {
    used: number,
    limit: number,
    remaining: number,
    resetIn: number,  // milliseconds
    isNearLimit: boolean
  },
  general: {
    used: number,
    limit: number,
    remaining: number,
    resetIn: number
  }
}
```

#### resetRateLimitTracker()

Reset rate limit tracking (for testing).

**Example:**
```javascript
apiClient.resetRateLimitTracker();
```

### Internal Methods

#### get(endpoint, options)

Make GET request.

**Parameters:**
- `endpoint` (string) - API endpoint
- `options` (Object) - Request options

**Returns:** Promise<Object>

#### post(endpoint, data, options)

Make POST request.

**Parameters:**
- `endpoint` (string) - API endpoint
- `data` (Object) - Request body
- `options` (Object) - Request options

**Returns:** Promise<Object>

---

## error-handler.js

### Default Export

`ErrorHandler` - Static error handler class

### Methods

#### parseError(error)

Parse any error into standardized format.

**Parameters:**
- `error` (Error | string | Object) - Error to parse

**Returns:** ParsedError object

**Example:**
```javascript
try {
  // ... code
} catch (error) {
  const parsed = ErrorHandler.parseError(error);
  console.log(parsed.type);         // 'RATE_LIMIT'
  console.log(parsed.userMessage);  // User-friendly message
  console.log(parsed.retryable);    // true
}
```

#### handleApiError(error)

Handle API error with logging.

**Parameters:**
- `error` (Error) - Error from API call

**Returns:** ParsedError object

**Example:**
```javascript
try {
  await apiClient.analyzeQuestions(questions);
} catch (error) {
  const parsed = ErrorHandler.handleApiError(error);
  // Error is logged automatically
  showErrorMessage(parsed.userMessage);
}
```

#### displayError(error, containerElement)

Display error in UI container.

**Parameters:**
- `error` (Error) - Error to display
- `containerElement` (HTMLElement | null) - Container element

**Returns:** ParsedError object

**Example:**
```javascript
const container = document.getElementById('errors');
ErrorHandler.displayError(error, container);
// Error is rendered as HTML in container
```

#### getUserMessage(error)

Get user-friendly error message.

**Parameters:**
- `error` (Error) - Error object

**Returns:** string - User message

**Example:**
```javascript
const message = ErrorHandler.getUserMessage(error);
alert(message);
```

#### isRetryable(error)

Check if error is retryable.

**Parameters:**
- `error` (Error) - Error object

**Returns:** boolean

**Example:**
```javascript
if (ErrorHandler.isRetryable(error)) {
  setTimeout(() => retry(), 1000);
}
```

#### getRetryDelay(error)

Get retry delay in seconds.

**Parameters:**
- `error` (Error) - Error object

**Returns:** number | null - Seconds to wait

**Example:**
```javascript
const delay = ErrorHandler.getRetryDelay(error);
if (delay) {
  console.log(`Retry in ${delay} seconds`);
}
```

#### clearErrors(containerElement)

Clear errors from container.

**Parameters:**
- `containerElement` (HTMLElement) - Container to clear

**Example:**
```javascript
const container = document.getElementById('errors');
ErrorHandler.clearErrors(container);
```

### ParsedError Object

Result of error parsing.

```javascript
{
  type: string,           // Error type (CORS, AUTH, etc.)
  severity: string,       // info | warning | error | critical
  message: string,        // Technical message
  userMessage: string,    // User-friendly message
  technicalDetails: string,  // Detailed error info
  retryable: boolean,     // Can retry?
  retryAfter: number | null,  // Seconds until retry
  actionable: boolean,    // Can user fix?
  actionMessage: string | null,  // What to do
  code: string,          // Error code
  timestamp: string      // ISO timestamp
}
```

### Error Types

```javascript
ErrorType = {
  CORS: 'CORS',
  AUTH: 'AUTH',
  RATE_LIMIT: 'RATE_LIMIT',
  URL_VALIDATION: 'URL_VALIDATION',
  NETWORK: 'NETWORK',
  SERVER: 'SERVER',
  UNKNOWN: 'UNKNOWN'
}
```

### Error Severity

```javascript
ErrorSeverity = {
  INFO: 'info',
  WARNING: 'warning',
  ERROR: 'error',
  CRITICAL: 'critical'
}
```

---

## url-validator.js

### Default Export

`UrlValidator` - Static URL validator class

### Methods

#### validate(urlString)

Comprehensive URL validation.

**Parameters:**
- `urlString` (string) - URL to validate

**Returns:** ValidationResult object

**Example:**
```javascript
const result = UrlValidator.validate('https://example.com/quiz');

if (result.isValid) {
  console.log('Valid URL');
} else {
  result.errors.forEach(error => {
    console.error(error.message);
  });
}
```

#### isValid(urlString)

Quick boolean validation.

**Parameters:**
- `urlString` (string) - URL to validate

**Returns:** boolean

**Example:**
```javascript
if (UrlValidator.isValid(url)) {
  proceedWithScraping(url);
}
```

#### getErrors(urlString)

Get validation errors as string array.

**Parameters:**
- `urlString` (string) - URL to validate

**Returns:** string[] - Error messages

**Example:**
```javascript
const errors = UrlValidator.getErrors(url);
errors.forEach(msg => console.error(msg));
```

#### getSummary(urlString)

Get validation summary.

**Parameters:**
- `urlString` (string) - URL to validate

**Returns:** Object - Validation summary

**Example:**
```javascript
const summary = UrlValidator.getSummary(url);
console.log(`Valid: ${summary.isValid}`);
console.log(`Errors: ${summary.errorCount}`);
console.log(`Warnings: ${summary.warningCount}`);
```

#### validateOrThrow(urlString)

Validate and throw on failure.

**Parameters:**
- `urlString` (string) - URL to validate

**Returns:** ValidationResult (if valid)

**Throws:** Error with validation message

**Example:**
```javascript
try {
  UrlValidator.validateOrThrow(url);
  // Valid - proceed
} catch (error) {
  console.error(error.message);
}
```

#### validateLive(urlString, options)

Live validation for input fields.

**Parameters:**
- `urlString` (string) - URL to validate
- `options` (Object) - Validation options
  - `showWarnings` (boolean) - Include warnings
  - `showInfo` (boolean) - Include info messages

**Returns:** ValidationResult

**Example:**
```javascript
input.addEventListener('input', (e) => {
  const result = UrlValidator.validateLive(e.target.value, {
    showWarnings: true,
    showInfo: false
  });
  updateUI(result);
});
```

#### sanitize(urlString)

Remove potentially dangerous URL parts.

**Parameters:**
- `urlString` (string) - URL to sanitize

**Returns:** string - Sanitized URL

**Example:**
```javascript
const clean = UrlValidator.sanitize('http://user:pass@example.com#hash');
// 'http://example.com'
```

#### getDomain(urlString)

Extract domain from URL.

**Parameters:**
- `urlString` (string) - URL

**Returns:** string | null - Domain

**Example:**
```javascript
const domain = UrlValidator.getDomain('https://sub.example.com/path');
// 'sub.example.com'
```

#### isDomainWhitelisted(domain)

Check if domain is whitelisted.

**Parameters:**
- `domain` (string) - Domain to check

**Returns:** boolean

**Example:**
```javascript
if (UrlValidator.isDomainWhitelisted('example.com')) {
  console.log('Domain allowed');
}
```

#### getAllowedDomains()

Get list of allowed domains.

**Returns:** string[] - Allowed domains

**Example:**
```javascript
const allowed = UrlValidator.getAllowedDomains();
console.log('Allowed:', allowed.join(', '));
```

#### createValidationMessageHtml(result)

Create HTML for validation messages.

**Parameters:**
- `result` (ValidationResult) - Validation result

**Returns:** string - HTML

**Example:**
```javascript
const result = UrlValidator.validate(url);
const html = UrlValidator.createValidationMessageHtml(result);
container.innerHTML = html;
```

#### validateBatch(urls)

Validate multiple URLs.

**Parameters:**
- `urls` (string[]) - Array of URLs

**Returns:** Array of objects with url and result

**Example:**
```javascript
const results = UrlValidator.validateBatch([
  'https://example.com',
  'http://192.168.1.1'
]);

results.forEach(({ url, result }) => {
  console.log(`${url}: ${result.isValid ? 'Valid' : 'Invalid'}`);
});
```

#### getValidationStats(urls)

Get validation statistics.

**Parameters:**
- `urls` (string[]) - Array of URLs

**Returns:** Object with statistics

**Example:**
```javascript
const stats = UrlValidator.getValidationStats(urls);
console.log(`${stats.valid}/${stats.total} URLs valid`);
```

**Response Format:**
```javascript
{
  total: number,
  valid: number,
  invalid: number,
  withWarnings: number,
  results: Array
}
```

### ValidationResult Object

```javascript
{
  isValid: boolean,
  errors: Array<{message: string, code: string}>,
  warnings: Array<{message: string, code: string}>,
  info: Object  // Additional validation info
}
```

**Methods:**
- `addError(message, code)` - Add error
- `addWarning(message, code)` - Add warning
- `getAllMessages()` - Get all messages
- `getPrimaryError()` - Get main error

---

## Usage Examples

### Complete Integration Example

```javascript
import config from './config.js';
import apiClient from './api-client.js';
import ErrorHandler from './error-handler.js';
import UrlValidator from './url-validator.js';

// 1. Configure API key
config.setApiKey('your-api-key-here');

// 2. Validate URL
const url = 'https://example.com/quiz';
try {
  UrlValidator.validateOrThrow(url);
} catch (error) {
  console.error(ErrorHandler.getUserMessage(error));
  return;
}

// 3. Check rate limit
const rateLimitStatus = apiClient.getRateLimitStatus();
if (rateLimitStatus.openai.remaining === 0) {
  alert('Rate limit exceeded');
  return;
}

// 4. Analyze questions
try {
  const questions = [/* questions array */];
  const result = await apiClient.analyzeQuestions(questions);
  console.log('Answers:', result.answers);
} catch (error) {
  const parsed = ErrorHandler.handleApiError(error);

  if (parsed.retryable && parsed.retryAfter) {
    setTimeout(() => {
      // Retry
    }, parsed.retryAfter * 1000);
  }
}
```

---

## Type Definitions

### Question Object

```typescript
interface Question {
  question: string;
  answers: string[];
}
```

### Analysis Result

```typescript
interface AnalysisResult {
  status: 'success' | 'error';
  answers: number[];
  questionCount: number;
  message: string;
}
```

### Rate Limit Status

```typescript
interface RateLimitStatus {
  openai: {
    used: number;
    limit: number;
    remaining: number;
    resetIn: number;
    isNearLimit: boolean;
  };
  general: {
    used: number;
    limit: number;
    remaining: number;
    resetIn: number;
  };
}
```

---

**Document Version**: 1.0
**Last Updated**: November 4, 2025
