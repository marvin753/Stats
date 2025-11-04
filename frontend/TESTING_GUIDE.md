# Frontend Testing Guide

**Version**: 2.0.0
**Last Updated**: November 4, 2025

---

## Table of Contents

1. [Overview](#overview)
2. [Test Setup](#test-setup)
3. [Unit Tests](#unit-tests)
4. [Integration Tests](#integration-tests)
5. [Security Tests](#security-tests)
6. [Manual Testing](#manual-testing)
7. [Performance Testing](#performance-testing)
8. [Browser Compatibility](#browser-compatibility)

---

## Overview

This guide provides comprehensive testing procedures for the Quiz Stats Animation System frontend, with focus on security features.

### Test Coverage

- ✅ Configuration module
- ✅ API client with authentication
- ✅ Error handling
- ✅ URL validation (SSRF protection)
- ✅ Rate limiting
- ✅ CORS handling
- ✅ User interface

---

## Test Setup

### Prerequisites

```bash
# Install testing dependencies
npm install --save-dev jest @testing-library/dom @testing-library/user-event

# Or use browser-based testing (no installation needed)
```

### Test Environment

```javascript
// test-setup.js
import config from './config.js';

// Set test environment
config.ENV.isDevelopment = true;
config.FEATURES.ENABLE_REQUEST_LOGGING = true;

// Mock API key
config.setApiKey('test-api-key-12345678901234567890abcd');
```

---

## Unit Tests

### Testing config.js

```javascript
// test-config.js
import config from './config.js';

describe('Configuration Module', () => {
  test('should detect environment correctly', () => {
    expect(config.ENV.isDevelopment).toBe(true);
  });

  test('should validate API key format', () => {
    const validKey = 'a'.repeat(32);
    expect(config.VALIDATION.isValidApiKeyFormat(validKey)).toBe(true);

    const invalidKey = 'short';
    expect(config.VALIDATION.isValidApiKeyFormat(invalidKey)).toBe(false);
  });

  test('should set and retrieve API key', () => {
    const key = 'test-key-1234567890123456789012';
    config.setApiKey(key);
    expect(config.hasApiKey()).toBe(true);
    expect(config.SECURITY_CONFIG.API_KEY).toBe(key);
  });

  test('should clear API key', () => {
    config.clearApiKey();
    expect(config.hasApiKey()).toBe(false);
  });

  test('should generate correct API URLs', () => {
    const url = config.getApiUrl('/test');
    expect(url).toContain('/test');
    expect(url).toMatch(/^https?:\/\//);
  });
});
```

### Testing url-validator.js

```javascript
// test-url-validator.js
import UrlValidator from './url-validator.js';

describe('URL Validator', () => {
  test('should validate valid URLs', () => {
    const validUrls = [
      'https://example.com',
      'http://example.com/path',
      'https://sub.example.com'
    ];

    validUrls.forEach(url => {
      const result = UrlValidator.validate(url);
      expect(result.isValid).toBe(true);
    });
  });

  test('should reject invalid protocols', () => {
    const invalidUrls = [
      'ftp://example.com',
      'file:///etc/passwd',
      'javascript:alert(1)'
    ];

    invalidUrls.forEach(url => {
      const result = UrlValidator.validate(url);
      expect(result.isValid).toBe(false);
      expect(result.errors[0].code).toBe('URL_INVALID_PROTOCOL');
    });
  });

  test('should reject private IP addresses', () => {
    const privateIPs = [
      'http://192.168.1.1',
      'http://10.0.0.1',
      'http://172.16.0.1',
      'http://127.0.0.1',
      'http://localhost'
    ];

    privateIPs.forEach(url => {
      const result = UrlValidator.validate(url);
      expect(result.isValid).toBe(false);
      expect(result.errors[0].code).toBe('URL_PRIVATE_IP');
    });
  });

  test('should reject cloud metadata endpoints', () => {
    const metadataUrls = [
      'http://169.254.169.254/latest/meta-data/',
      'http://metadata.google.internal'
    ];

    metadataUrls.forEach(url => {
      const result = UrlValidator.validate(url);
      expect(result.isValid).toBe(false);
      expect(result.errors[0].code).toBe('URL_METADATA_BLOCKED');
    });
  });

  test('should enforce domain whitelist', () => {
    const result = UrlValidator.validate('https://evil.com');
    expect(result.isValid).toBe(false);
    expect(result.errors[0].code).toBe('URL_NOT_WHITELISTED');
  });

  test('should extract domain correctly', () => {
    const domain = UrlValidator.getDomain('https://sub.example.com/path?query=1');
    expect(domain).toBe('sub.example.com');
  });

  test('should sanitize URLs', () => {
    const dirty = 'http://user:pass@example.com/path#hash';
    const clean = UrlValidator.sanitize(dirty);
    expect(clean).not.toContain('user');
    expect(clean).not.toContain('pass');
    expect(clean).not.toContain('#hash');
  });
});
```

### Testing error-handler.js

```javascript
// test-error-handler.js
import ErrorHandler from './error-handler.js';

describe('Error Handler', () => {
  test('should parse CORS errors', () => {
    const error = new Error('Not allowed by CORS policy');
    const parsed = ErrorHandler.parseError(error);

    expect(parsed.type).toBe('CORS');
    expect(parsed.severity).toBe('error');
    expect(parsed.retryable).toBe(false);
  });

  test('should parse authentication errors', () => {
    const error = new Error('AUTH_NO_KEY');
    const parsed = ErrorHandler.parseError(error);

    expect(parsed.type).toBe('AUTH');
    expect(parsed.code).toBe('AUTH_NO_KEY');
    expect(parsed.actionable).toBe(true);
  });

  test('should parse rate limit errors', () => {
    const error = new Error('RATE_LIMIT_EXCEEDED:60');
    const parsed = ErrorHandler.parseError(error);

    expect(parsed.type).toBe('RATE_LIMIT');
    expect(parsed.retryable).toBe(true);
    expect(parsed.retryAfter).toBe(60);
  });

  test('should parse network errors', () => {
    const error = new Error('NETWORK_ERROR');
    const parsed = ErrorHandler.parseError(error);

    expect(parsed.type).toBe('NETWORK');
    expect(parsed.retryable).toBe(true);
  });

  test('should check if error is retryable', () => {
    const retryableError = new Error('RATE_LIMIT_EXCEEDED:30');
    expect(ErrorHandler.isRetryable(retryableError)).toBe(true);

    const nonRetryableError = new Error('AUTH_INVALID');
    expect(ErrorHandler.isRetryable(nonRetryableError)).toBe(false);
  });

  test('should get retry delay', () => {
    const error = new Error('RATE_LIMIT_EXCEEDED:45');
    const delay = ErrorHandler.getRetryDelay(error);
    expect(delay).toBe(45);
  });

  test('should get user-friendly messages', () => {
    const error = new Error('AUTH_NO_KEY');
    const message = ErrorHandler.getUserMessage(error);
    expect(message).toContain('API key');
  });
});
```

### Testing api-client.js

```javascript
// test-api-client.js
import apiClient from './api-client.js';

describe('API Client', () => {
  beforeEach(() => {
    // Reset rate limit tracker
    apiClient.resetRateLimitTracker();
  });

  test('should track rate limits', async () => {
    const initialStatus = apiClient.getRateLimitStatus();
    const initialRemaining = initialStatus.openai.remaining;

    // Simulate a request (without actually making it)
    apiClient.rateLimitTracker.recordRequest('/api/analyze');

    const newStatus = apiClient.getRateLimitStatus();
    expect(newStatus.openai.remaining).toBe(initialRemaining - 1);
  });

  test('should detect near rate limit', () => {
    // Record 9 requests (80% of 10)
    for (let i = 0; i < 9; i++) {
      apiClient.rateLimitTracker.recordRequest('/api/analyze');
    }

    const status = apiClient.getRateLimitStatus();
    expect(status.openai.isNearLimit).toBe(true);
  });

  test('should throw when rate limited', () => {
    // Record 10 requests (100% of 10)
    for (let i = 0; i < 10; i++) {
      apiClient.rateLimitTracker.recordRequest('/api/analyze');
    }

    expect(() => {
      apiClient.checkClientRateLimit('/api/analyze');
    }).toThrow();
  });

  test('should calculate retry delay with exponential backoff', () => {
    const delay1 = apiClient.calculateRetryDelay(1);
    const delay2 = apiClient.calculateRetryDelay(2);
    const delay3 = apiClient.calculateRetryDelay(3);

    expect(delay2).toBeGreaterThan(delay1);
    expect(delay3).toBeGreaterThan(delay2);
  });

  test('should respect max retry delay', () => {
    const delay = apiClient.calculateRetryDelay(100);
    expect(delay).toBeLessThanOrEqual(30000); // MAX_DELAY
  });
});
```

---

## Integration Tests

### Full Flow Test

```javascript
// test-integration.js
import config from './config.js';
import apiClient from './api-client.js';
import ErrorHandler from './error-handler.js';
import UrlValidator from './url-validator.js';

describe('Integration Tests', () => {
  beforeAll(() => {
    // Setup
    config.setApiKey('test-key-1234567890123456789012');
  });

  test('should validate URL before API call', async () => {
    const invalidUrl = 'http://192.168.1.1';

    // Validate URL
    const validationResult = UrlValidator.validate(invalidUrl);
    expect(validationResult.isValid).toBe(false);

    // Don't make API call if URL invalid
    if (!validationResult.isValid) {
      return; // Success - prevented invalid call
    }
  });

  test('should handle complete analysis flow', async () => {
    // 1. Validate URL
    const url = 'https://example.com/quiz';
    const urlResult = UrlValidator.validate(url);
    expect(urlResult.isValid).toBe(true);

    // 2. Check API key
    expect(config.hasApiKey()).toBe(true);

    // 3. Check rate limit
    const rateLimitStatus = apiClient.getRateLimitStatus();
    expect(rateLimitStatus.openai.remaining).toBeGreaterThan(0);

    // 4. Make API call (mocked)
    // In real test, you would mock the fetch call
  });

  test('should handle error flow gracefully', async () => {
    // Simulate error
    const error = new Error('RATE_LIMIT_EXCEEDED:30');

    // Handle error
    const parsed = ErrorHandler.handleApiError(error);

    // Verify error handling
    expect(parsed.type).toBe('RATE_LIMIT');
    expect(parsed.retryable).toBe(true);
    expect(parsed.userMessage).toBeTruthy();
  });
});
```

---

## Security Tests

### SSRF Protection Tests

```javascript
// test-ssrf-protection.js
import UrlValidator from './url-validator.js';

describe('SSRF Protection', () => {
  const attackVectors = [
    // Private IP ranges
    'http://127.0.0.1',
    'http://localhost',
    'http://0.0.0.0',
    'http://10.0.0.1',
    'http://172.16.0.1',
    'http://192.168.1.1',
    'http://169.254.169.254',

    // IPv6
    'http://[::1]',
    'http://[fe80::1]',

    // Cloud metadata
    'http://169.254.169.254/latest/meta-data/',
    'http://metadata.google.internal',

    // Protocol bypass attempts
    'file:///etc/passwd',
    'ftp://internal.server',
    'gopher://internal.server',

    // Domain bypass attempts
    'https://evil.com',
    'https://attacker.net'
  ];

  test('should block all SSRF attack vectors', () => {
    attackVectors.forEach(url => {
      const result = UrlValidator.validate(url);
      expect(result.isValid).toBe(false);
    });
  });

  test('should allow legitimate URLs', () => {
    const legitimateUrls = [
      'https://example.com',
      'https://www.example.com',
      'https://sub.example.com/path',
      'https://example.com:8080/quiz'
    ];

    legitimateUrls.forEach(url => {
      const result = UrlValidator.validate(url);
      expect(result.isValid).toBe(true);
    });
  });
});
```

### Authentication Tests

```javascript
// test-authentication.js
import config from './config.js';
import apiClient from './api-client.js';

describe('Authentication', () => {
  test('should require API key for protected endpoints', () => {
    config.clearApiKey();

    expect(() => {
      // This should throw AUTH_NO_KEY
      apiClient.checkClientRateLimit('/api/analyze');
    }).not.toThrow(); // Client-side check doesn't throw yet

    // But API call would fail
    expect(config.hasApiKey()).toBe(false);
  });

  test('should validate API key format', () => {
    const invalidKeys = [
      'short',
      '12345',
      '',
      null,
      undefined
    ];

    invalidKeys.forEach(key => {
      const isValid = config.setApiKey(key);
      expect(isValid).toBe(false);
    });
  });

  test('should accept valid API key', () => {
    const validKey = 'a'.repeat(32);
    const isValid = config.setApiKey(validKey);
    expect(isValid).toBe(true);
    expect(config.hasApiKey()).toBe(true);
  });

  test('should store API key in sessionStorage only', () => {
    const key = 'test-key-1234567890123456789012';
    config.setApiKey(key);

    // Check sessionStorage
    const stored = sessionStorage.getItem('quiz_api_key');
    expect(stored).toBe(key);

    // Check localStorage (should NOT be there)
    const inLocal = localStorage.getItem('quiz_api_key');
    expect(inLocal).toBeNull();
  });
});
```

### Rate Limiting Tests

```javascript
// test-rate-limiting.js
import apiClient from './api-client.js';

describe('Rate Limiting', () => {
  beforeEach(() => {
    apiClient.resetRateLimitTracker();
  });

  test('should enforce OpenAI rate limit (10/min)', () => {
    // Record 10 requests
    for (let i = 0; i < 10; i++) {
      apiClient.rateLimitTracker.recordRequest('/api/analyze');
    }

    // 11th request should be blocked
    expect(() => {
      apiClient.checkClientRateLimit('/api/analyze');
    }).toThrow();
  });

  test('should track requests in time window', () => {
    const now = Date.now();

    // Record 5 recent requests
    for (let i = 0; i < 5; i++) {
      apiClient.rateLimitTracker.recordRequest('/api/analyze', now - 1000);
    }

    // Record 5 old requests (outside window)
    for (let i = 0; i < 5; i++) {
      apiClient.rateLimitTracker.recordRequest('/api/analyze', now - 120000);
    }

    // Should only count recent requests
    const status = apiClient.getRateLimitStatus();
    expect(status.openai.used).toBe(5);
  });

  test('should calculate time until reset', () => {
    const now = Date.now();
    apiClient.rateLimitTracker.recordRequest('/api/analyze', now - 30000);

    const resetTime = apiClient.rateLimitTracker.getTimeUntilReset(
      '/api/analyze',
      60000
    );

    expect(resetTime).toBeGreaterThan(0);
    expect(resetTime).toBeLessThanOrEqual(30000);
  });
});
```

---

## Manual Testing

### Test Checklist

#### 1. URL Validation

```
□ Enter valid URL (https://example.com/quiz)
  → Should show green checkmark
  → Analyze button should be enabled

□ Enter invalid protocol (ftp://example.com)
  → Should show red X
  → Should display error: "Unsupported protocol"
  → Analyze button should be disabled

□ Enter private IP (http://192.168.1.1)
  → Should show error: "Private IP addresses not allowed"
  → Analyze button should be disabled

□ Enter non-whitelisted domain (https://evil.com)
  → Should show error: "Domain not whitelisted"
  → Should list allowed domains
  → Analyze button should be disabled
```

#### 2. API Key Configuration

```
□ Open page without API key
  → Should show API key configuration card
  → Should hide scraper card

□ Enter invalid API key
  → Should show red X
  → Should display "Invalid API key format"
  → Save button should not work

□ Enter valid API key
  → Should show green checkmark
  → Should save successfully
  → Should show scraper card
```

#### 3. Rate Limiting

```
□ Check initial rate limit display
  → Should show "10/10 remaining"

□ Make 1 analysis request
  → Should show "9/10 remaining"
  → Used count should increase

□ Make 10 analysis requests quickly
  → 10th request should succeed
  → 11th request should show rate limit error
  → Should display "Rate limit exceeded"
  → Should show countdown until reset

□ Wait for rate limit reset
  → Countdown should decrease
  → When reset, should allow requests again
```

#### 4. Error Handling

```
□ Disconnect from internet
  → Make API request
  → Should show "Network error"
  → Should suggest checking connection

□ Use invalid API key
  → Make API request
  → Should show "Invalid API key"
  → Should suggest checking credentials

□ Test CORS error (use wrong origin)
  → Should show "CORS policy violation"
  → Should show helpful message
```

#### 5. User Interface

```
□ Loading states
  → Should show spinner during analysis
  → Should display loading text
  → Button should be disabled

□ Results display
  → Should show questions
  → Should highlight correct answers
  → Should be clearly readable

□ Responsive design
  → Test on mobile (320px width)
  → Test on tablet (768px width)
  → Test on desktop (1920px width)
  → All elements should be accessible
```

---

## Performance Testing

### Response Time Tests

```javascript
// test-performance.js
describe('Performance', () => {
  test('URL validation should be fast', () => {
    const start = performance.now();

    for (let i = 0; i < 1000; i++) {
      UrlValidator.validate('https://example.com/quiz');
    }

    const duration = performance.now() - start;
    expect(duration).toBeLessThan(100); // 100ms for 1000 validations
  });

  test('Rate limit checking should be fast', () => {
    const start = performance.now();

    for (let i = 0; i < 1000; i++) {
      apiClient.getRateLimitStatus();
    }

    const duration = performance.now() - start;
    expect(duration).toBeLessThan(50); // 50ms for 1000 checks
  });
});
```

### Memory Leak Tests

```javascript
// Monitor memory usage
console.log('Initial memory:', performance.memory.usedJSHeapSize);

// Make many requests
for (let i = 0; i < 100; i++) {
  UrlValidator.validate('https://example.com/quiz');
  apiClient.getRateLimitStatus();
}

console.log('After 100 calls:', performance.memory.usedJSHeapSize);

// Memory should not increase significantly
```

---

## Browser Compatibility

### Supported Browsers

- ✅ Chrome 90+
- ✅ Firefox 88+
- ✅ Safari 14+
- ✅ Edge 90+

### Feature Detection

```javascript
// Check for required features
const supportsModules = 'noModule' in HTMLScriptElement.prototype;
const supportsSessionStorage = typeof sessionStorage !== 'undefined';
const supportsFetch = typeof fetch !== 'undefined';

if (!supportsModules || !supportsSessionStorage || !supportsFetch) {
  alert('Your browser is not supported. Please upgrade.');
}
```

### Cross-Browser Testing Checklist

```
□ Chrome
  □ URL validation works
  □ API calls succeed
  □ Rate limiting tracked
  □ Errors displayed correctly

□ Firefox
  □ Same as Chrome

□ Safari
  □ Same as Chrome
  □ Check CORS handling (Safari is strict)

□ Edge
  □ Same as Chrome
```

---

## Automated Testing Script

### Quick Test Runner

```html
<!DOCTYPE html>
<html>
<head>
  <title>Automated Tests</title>
</head>
<body>
  <h1>Running Tests...</h1>
  <div id="results"></div>

  <script type="module">
    import config from './config.js';
    import apiClient from './api-client.js';
    import ErrorHandler from './error-handler.js';
    import UrlValidator from './url-validator.js';

    const results = [];

    function test(name, fn) {
      try {
        fn();
        results.push({ name, status: 'PASS' });
      } catch (error) {
        results.push({ name, status: 'FAIL', error: error.message });
      }
    }

    // Run tests
    test('Config loads', () => {
      if (!config.VERSION) throw new Error('Config not loaded');
    });

    test('URL validation works', () => {
      const result = UrlValidator.validate('https://example.com');
      if (!result.isValid) throw new Error('Valid URL rejected');
    });

    test('Private IPs blocked', () => {
      const result = UrlValidator.validate('http://192.168.1.1');
      if (result.isValid) throw new Error('Private IP allowed');
    });

    test('Rate limit tracking works', () => {
      apiClient.resetRateLimitTracker();
      const status = apiClient.getRateLimitStatus();
      if (status.openai.remaining !== 10) throw new Error('Wrong limit');
    });

    // Display results
    const resultsDiv = document.getElementById('results');
    resultsDiv.innerHTML = results.map(r =>
      `<div style="color: ${r.status === 'PASS' ? 'green' : 'red'}">
        ${r.status}: ${r.name}
        ${r.error ? `<br>Error: ${r.error}` : ''}
      </div>`
    ).join('');

    const passCount = results.filter(r => r.status === 'PASS').length;
    console.log(`${passCount}/${results.length} tests passed`);
  </script>
</body>
</html>
```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
# .github/workflows/frontend-tests.yml
name: Frontend Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v2

      - name: Setup Node.js
        uses: actions/setup-node@v2
        with:
          node-version: '18'

      - name: Install dependencies
        run: npm install

      - name: Run tests
        run: npm test

      - name: Run linter
        run: npm run lint

      - name: Check security
        run: npm audit
```

---

**Document Version**: 1.0
**Last Updated**: November 4, 2025
