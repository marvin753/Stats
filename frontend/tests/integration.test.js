/**
 * Frontend Integration Tests
 * Tests for integrated frontend workflows
 *
 * @group frontend
 * @group integration
 */

// Setup mocks
global.window = {
  location: { hostname: 'localhost' },
  sessionStorage: {
    data: {},
    getItem(key) { return this.data[key] || null; },
    setItem(key, value) { this.data[key] = value; },
    removeItem(key) { delete this.data[key]; },
    clear() { this.data = {}; }
  }
};
global.fetch = jest.fn();

const config = require('../config.js').default;
const { ApiClient } = require('../api-client.js');
const ErrorHandler = require('../error-handler.js').default;
const UrlValidator = require('../url-validator.js').default;

describe('Frontend Integration Tests - Full Workflow', () => {
  let client;

  beforeEach(() => {
    client = new ApiClient();
    fetch.mockClear();
    window.sessionStorage.clear();
    config.SECURITY_CONFIG.API_KEY = 'test-key';
    config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['example.com'];
  });

  test('should complete URL validation → API request → success flow', async () => {
    // 1. Validate URL
    const urlResult = UrlValidator.validate('http://example.com/quiz');
    expect(urlResult.isValid).toBe(true);

    // 2. Mock API response
    fetch.mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: async () => ({ status: 'success', answers: [1, 2, 3] }),
      headers: new Map()
    });

    // 3. Make API request
    const questions = [
      { question: 'Q1?', answers: ['A', 'B'] },
      { question: 'Q2?', answers: ['A', 'B'] },
      { question: 'Q3?', answers: ['A', 'B'] }
    ];

    const apiResult = await client.analyzeQuestions(questions);

    expect(apiResult.status).toBe('success');
    expect(apiResult.answers).toEqual([1, 2, 3]);
  });

  test('should handle URL validation → error flow', () => {
    const urlResult = UrlValidator.validate('http://evil.com/quiz');
    expect(urlResult.isValid).toBe(false);

    const error = ErrorHandler.parseError(urlResult.getPrimaryError());
    expect(error.type).toBe('URL_VALIDATION');
  });

  test('should handle API auth error flow', async () => {
    fetch.mockResolvedValueOnce({
      ok: false,
      status: 401,
      json: async () => ({ error: 'Unauthorized' }),
      headers: new Map()
    });

    try {
      await client.analyzeQuestions([{ question: 'Test?', answers: ['A'] }]);
    } catch (error) {
      const parsed = ErrorHandler.parseError(error);
      expect(parsed.type).toBe('AUTH');
      expect(parsed.code).toBe('AUTH_NO_KEY');
    }
  });

  test('should handle rate limit with retry', async () => {
    fetch
      .mockResolvedValueOnce({
        ok: false,
        status: 429,
        json: async () => ({ retryAfter: 1 }),
        headers: new Map()
      })
      .mockResolvedValueOnce({
        ok: true,
        status: 200,
        json: async () => ({ status: 'success', answers: [1] }),
        headers: new Map()
      });

    config.FEATURES.ENABLE_RETRY_LOGIC = true;

    const result = await client.analyzeQuestions([
      { question: 'Test?', answers: ['A', 'B'] }
    ]);

    expect(result.status).toBe('success');
    expect(fetch).toHaveBeenCalledTimes(2);
  }, 10000);

  test('should track rate limit across requests', async () => {
    fetch.mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ status: 'success', answers: [1] }),
      headers: new Map()
    });

    const questions = [{ question: 'Test?', answers: ['A', 'B'] }];

    // Make multiple requests
    await client.analyzeQuestions(questions);
    await client.analyzeQuestions(questions);
    await client.analyzeQuestions(questions);

    const status = client.getRateLimitStatus();
    expect(status.openai.used).toBe(3);
    expect(status.openai.remaining).toBe(7);
  });

  test('should persist rate limit data in session', async () => {
    fetch.mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: async () => ({ status: 'success', answers: [1] }),
      headers: new Map()
    });

    await client.analyzeQuestions([{ question: 'Test?', answers: ['A'] }]);

    // Create new client to test persistence
    const newClient = new ApiClient();
    const status = newClient.getRateLimitStatus();

    expect(status.openai.used).toBe(1);
  });
});

describe('Frontend Integration Tests - Error Handling Workflow', () => {
  let client, mockContainer;

  beforeEach(() => {
    client = new ApiClient();
    mockContainer = { innerHTML: '', style: { display: '' } };
    fetch.mockClear();
    config.SECURITY_CONFIG.API_KEY = 'test-key';
  });

  test('should display network error to user', async () => {
    fetch.mockRejectedValueOnce(new TypeError('Failed to fetch'));

    try {
      await client.analyzeQuestions([{ question: 'Test?', answers: ['A'] }]);
    } catch (error) {
      ErrorHandler.displayError(error, mockContainer);
      expect(mockContainer.innerHTML).toContain('Network error');
      expect(mockContainer.style.display).toBe('block');
    }
  });

  test('should display auth error with action message', async () => {
    config.SECURITY_CONFIG.API_KEY = null;

    try {
      await client.analyzeQuestions([{ question: 'Test?', answers: ['A'] }]);
    } catch (error) {
      ErrorHandler.displayError(error, mockContainer);
      expect(mockContainer.innerHTML).toContain('API key is missing');
      expect(mockContainer.innerHTML).toContain('configure');
    }
  });

  test('should display rate limit with countdown', async () => {
    fetch.mockResolvedValueOnce({
      ok: false,
      status: 429,
      json: async () => ({ retryAfter: 60 }),
      headers: new Map()
    });

    config.FEATURES.ENABLE_RETRY_LOGIC = false;

    try {
      await client.analyzeQuestions([{ question: 'Test?', answers: ['A'] }]);
    } catch (error) {
      ErrorHandler.displayError(error, mockContainer);
      expect(mockContainer.innerHTML).toContain('60');
      expect(mockContainer.innerHTML).toContain('Retry');
    }
  });
});

describe('Frontend Integration Tests - Configuration Management', () => {
  test('should detect development environment', () => {
    window.location.hostname = 'localhost';
    const summary = config.getSummary();
    expect(summary.environment).toBe('development');
  });

  test('should set and get API key', () => {
    const validKey = 'dGVzdC1hcGkta2V5LXRoYXQtaXMtbG9uZy1lbm91Z2gtdG8tcGFzcw==';
    const result = config.setApiKey(validKey);

    expect(result).toBe(true);
    expect(config.hasApiKey()).toBe(true);
  });

  test('should reject invalid API key format', () => {
    const result = config.setApiKey('short');
    expect(result).toBe(false);
  });

  test('should clear API key', () => {
    config.setApiKey('dGVzdC1hcGkta2V5LXRoYXQtaXMtbG9uZy1lbm91Z2gtdG8tcGFzcw==');
    config.clearApiKey();
    expect(config.hasApiKey()).toBe(false);
  });
});

describe('Frontend Integration Tests - Cross-Module Communication', () => {
  let client;

  beforeEach(() => {
    client = new ApiClient();
    config.SECURITY_CONFIG.API_KEY = 'test-key';
  });

  test('should use config values in API client', async () => {
    config.API_CONFIG.BACKEND_URL = 'http://test-backend:3000';

    fetch.mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: async () => ({ status: 'ok' }),
      headers: new Map()
    });

    await client.healthCheck();

    expect(fetch).toHaveBeenCalledWith(
      'http://test-backend:3000/health',
      expect.any(Object)
    );
  });

  test('should use config error messages in error handler', () => {
    config.ERROR_MESSAGES.AUTH_NO_KEY = 'Custom auth message';

    const error = ErrorHandler.parseError('AUTH_NO_KEY');
    expect(error.userMessage).toBe('Custom auth message');
  });

  test('should use config whitelist in URL validator', () => {
    config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['custom-domain.com'];

    expect(UrlValidator.isValid('http://custom-domain.com')).toBe(true);
    expect(UrlValidator.isValid('http://other-domain.com')).toBe(false);
  });
});

describe('Frontend Integration Tests - Performance', () => {
  let client;

  beforeEach(() => {
    client = new ApiClient();
    config.SECURITY_CONFIG.API_KEY = 'test-key';
    fetch.mockClear();
  });

  test('should handle rapid sequential validations', () => {
    const urls = Array(100).fill('http://example.com');

    const startTime = Date.now();
    urls.forEach(url => {
      config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['example.com'];
      UrlValidator.validate(url);
    });
    const duration = Date.now() - startTime;

    expect(duration).toBeLessThan(1000); // Should complete in under 1 second
  });

  test('should handle multiple error parsings efficiently', () => {
    const errors = Array(100).fill('AUTH_NO_KEY');

    const startTime = Date.now();
    errors.forEach(error => ErrorHandler.parseError(error));
    const duration = Date.now() - startTime;

    expect(duration).toBeLessThan(500);
  });
});

describe('Frontend Integration Tests - Edge Cases', () => {
  let client;

  beforeEach(() => {
    client = new ApiClient();
    config.SECURITY_CONFIG.API_KEY = 'test-key';
    config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['example.com'];
  });

  test('should handle Unicode in URLs', () => {
    const result = UrlValidator.validate('http://example.com/路径');
    expect(result.isValid).toBe(true);
  });

  test('should handle very long URLs', () => {
    const longPath = 'a'.repeat(1000);
    const result = UrlValidator.validate(`http://example.com/${longPath}`);
    expect(result.isValid).toBe(true);
  });

  test('should handle special characters in error messages', () => {
    const error = ErrorHandler.parseError('Error with <script>alert(1)</script>');
    expect(error.userMessage).toBeDefined();
  });

  test('should handle concurrent API requests', async () => {
    fetch.mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ status: 'success', answers: [1] }),
      headers: new Map()
    });

    const questions = [{ question: 'Test?', answers: ['A'] }];
    const promises = [
      client.analyzeQuestions(questions),
      client.analyzeQuestions(questions),
      client.analyzeQuestions(questions)
    ];

    const results = await Promise.all(promises);
    expect(results).toHaveLength(3);
    results.forEach(result => {
      expect(result.status).toBe('success');
    });
  });
});
