/**
 * Frontend API Client Tests
 * Tests for API client module including authentication, rate limiting, and retry logic
 *
 * @group frontend
 * @group api-client
 */

// Mock config before importing
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
const { ApiClient, RateLimitTracker } = require('../api-client.js');

describe('API Client Tests - Configuration', () => {
  let client;

  beforeEach(() => {
    client = new ApiClient();
    global.fetch.mockClear();
    window.sessionStorage.clear();
  });

  describe('Header Building', () => {
    test('should build headers with Content-Type', () => {
      const headers = client.buildHeaders();
      expect(headers['Content-Type']).toBe('application/json');
    });

    test('should include API key if configured', () => {
      config.SECURITY_CONFIG.API_KEY = 'test-api-key-123';
      const headers = client.buildHeaders();
      expect(headers['X-API-Key']).toBe('test-api-key-123');
    });

    test('should not include API key if not configured', () => {
      config.SECURITY_CONFIG.API_KEY = null;
      const headers = client.buildHeaders();
      expect(headers['X-API-Key']).toBeUndefined();
    });

    test('should merge additional headers', () => {
      const headers = client.buildHeaders({ 'Custom-Header': 'value' });
      expect(headers['Custom-Header']).toBe('value');
      expect(headers['Content-Type']).toBe('application/json');
    });
  });

  describe('Request Logging', () => {
    test('should log requests when enabled', () => {
      const originalLog = console.log;
      const logs = [];
      console.log = jest.fn((...args) => logs.push(args));
      console.group = jest.fn();
      console.groupEnd = jest.fn();

      config.FEATURES.ENABLE_REQUEST_LOGGING = true;
      client.logRequest('POST', '/api/test', { body: '{"test": true}' });

      expect(console.group).toHaveBeenCalled();
      console.log = originalLog;
    });

    test('should not log requests when disabled', () => {
      console.log = jest.fn();
      config.FEATURES.ENABLE_REQUEST_LOGGING = false;
      client.logRequest('POST', '/api/test');
      expect(console.log).not.toHaveBeenCalled();
    });
  });
});

describe('API Client Tests - Rate Limit Tracker', () => {
  let tracker;

  beforeEach(() => {
    window.sessionStorage.clear();
    tracker = new RateLimitTracker();
  });

  describe('Request Recording', () => {
    test('should record requests', () => {
      tracker.recordRequest('/api/analyze');
      expect(tracker.requests).toHaveLength(1);
      expect(tracker.requests[0].endpoint).toBe('/api/analyze');
    });

    test('should record timestamp', () => {
      const before = Date.now();
      tracker.recordRequest('/api/analyze');
      const after = Date.now();

      expect(tracker.requests[0].timestamp).toBeGreaterThanOrEqual(before);
      expect(tracker.requests[0].timestamp).toBeLessThanOrEqual(after);
    });

    test('should record multiple requests', () => {
      tracker.recordRequest('/api/analyze');
      tracker.recordRequest('/api/analyze');
      tracker.recordRequest('/health');

      expect(tracker.requests).toHaveLength(3);
    });
  });

  describe('Old Request Cleanup', () => {
    test('should cleanup old requests', () => {
      const oldTimestamp = Date.now() - (20 * 60 * 1000); // 20 minutes ago
      tracker.recordRequest('/api/analyze', oldTimestamp);
      tracker.recordRequest('/api/analyze'); // Now

      tracker.cleanupOldRequests();

      expect(tracker.requests).toHaveLength(1);
      expect(tracker.requests[0].timestamp).toBeGreaterThan(oldTimestamp);
    });

    test('should keep recent requests', () => {
      tracker.recordRequest('/api/analyze', Date.now() - 1000);
      tracker.recordRequest('/api/analyze', Date.now() - 2000);

      tracker.cleanupOldRequests();

      expect(tracker.requests).toHaveLength(2);
    });
  });

  describe('Request Counting', () => {
    test('should count requests for endpoint', () => {
      tracker.recordRequest('/api/analyze');
      tracker.recordRequest('/api/analyze');
      tracker.recordRequest('/health');

      const count = tracker.getRequestCount('/api/analyze', 60000);
      expect(count).toBe(2);
    });

    test('should only count requests within window', () => {
      const oldTime = Date.now() - 70000; // 70 seconds ago
      tracker.recordRequest('/api/analyze', oldTime);
      tracker.recordRequest('/api/analyze'); // Now

      const count = tracker.getRequestCount('/api/analyze', 60000); // 1 minute window
      expect(count).toBe(1);
    });
  });

  describe('Rate Limit Checking', () => {
    test('should detect when near limit', () => {
      for (let i = 0; i < 8; i++) {
        tracker.recordRequest('/api/analyze');
      }

      const isNear = tracker.isNearLimit('/api/analyze', 10, 60000);
      expect(isNear).toBe(true);
    });

    test('should detect when at limit', () => {
      for (let i = 0; i < 10; i++) {
        tracker.recordRequest('/api/analyze');
      }

      const isLimited = tracker.isRateLimited('/api/analyze', 10, 60000);
      expect(isLimited).toBe(true);
    });

    test('should return false when under limit', () => {
      tracker.recordRequest('/api/analyze');

      const isLimited = tracker.isRateLimited('/api/analyze', 10, 60000);
      expect(isLimited).toBe(false);
    });
  });

  describe('Remaining Requests', () => {
    test('should calculate remaining requests', () => {
      for (let i = 0; i < 3; i++) {
        tracker.recordRequest('/api/analyze');
      }

      const remaining = tracker.getRemainingRequests('/api/analyze', 10, 60000);
      expect(remaining).toBe(7);
    });

    test('should return 0 when over limit', () => {
      for (let i = 0; i < 12; i++) {
        tracker.recordRequest('/api/analyze');
      }

      const remaining = tracker.getRemainingRequests('/api/analyze', 10, 60000);
      expect(remaining).toBe(0);
    });
  });

  describe('Time Until Reset', () => {
    test('should calculate time until reset', () => {
      const timestamp = Date.now() - 30000; // 30 seconds ago
      tracker.recordRequest('/api/analyze', timestamp);

      const timeUntilReset = tracker.getTimeUntilReset('/api/analyze', 60000);
      expect(timeUntilReset).toBeGreaterThan(25000);
      expect(timeUntilReset).toBeLessThan(35000);
    });

    test('should return 0 when no requests', () => {
      const timeUntilReset = tracker.getTimeUntilReset('/api/analyze', 60000);
      expect(timeUntilReset).toBe(0);
    });
  });

  describe('Storage Persistence', () => {
    test('should save to sessionStorage', () => {
      tracker.recordRequest('/api/analyze');
      expect(window.sessionStorage.getItem('quiz_rate_limit_tracker')).toBeTruthy();
    });

    test('should load from sessionStorage', () => {
      tracker.recordRequest('/api/analyze');
      const newTracker = new RateLimitTracker();

      expect(newTracker.requests).toHaveLength(1);
    });

    test('should handle corrupted storage data', () => {
      window.sessionStorage.setItem('quiz_rate_limit_tracker', 'invalid json');
      const newTracker = new RateLimitTracker();

      expect(newTracker.requests).toHaveLength(0);
    });
  });
});

describe('API Client Tests - HTTP Methods', () => {
  let client;

  beforeEach(() => {
    client = new ApiClient();
    global.fetch.mockClear();
    config.SECURITY_CONFIG.API_KEY = 'test-key';
  });

  describe('GET Requests', () => {
    test('should make GET request', async () => {
      fetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        json: async () => ({ data: 'test' }),
        headers: new Map()
      });

      const result = await client.get('/health');

      expect(fetch).toHaveBeenCalledWith(
        expect.stringContaining('/health'),
        expect.objectContaining({ method: 'GET' })
      );
      expect(result.success).toBe(true);
      expect(result.data).toEqual({ data: 'test' });
    });

    test('should include headers in GET request', async () => {
      fetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        json: async () => ({}),
        headers: new Map()
      });

      await client.get('/health');

      expect(fetch).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({
          headers: expect.objectContaining({
            'X-API-Key': 'test-key'
          })
        })
      );
    });
  });

  describe('POST Requests', () => {
    test('should make POST request', async () => {
      fetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        json: async () => ({ status: 'success' }),
        headers: new Map()
      });

      const data = { questions: [] };
      const result = await client.post('/api/analyze', data);

      expect(fetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/analyze'),
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify(data)
        })
      );
      expect(result.success).toBe(true);
    });

    test('should record request for rate limiting', async () => {
      fetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        json: async () => ({}),
        headers: new Map()
      });

      client.rateLimitTracker.recordRequest = jest.fn();

      await client.post('/api/analyze', {});

      expect(client.rateLimitTracker.recordRequest).toHaveBeenCalledWith('/api/analyze');
    });
  });
});

describe('API Client Tests - Error Handling', () => {
  let client;

  beforeEach(() => {
    client = new ApiClient();
    config.SECURITY_CONFIG.API_KEY = 'test-key';
  });

  describe('HTTP Status Errors', () => {
    test('should handle 401 Unauthorized', async () => {
      fetch.mockResolvedValueOnce({
        ok: false,
        status: 401,
        json: async () => ({ error: 'Unauthorized' }),
        headers: new Map()
      });

      await expect(client.get('/api/analyze')).rejects.toThrow('AUTH_NO_KEY');
    });

    test('should handle 403 Forbidden', async () => {
      fetch.mockResolvedValueOnce({
        ok: false,
        status: 403,
        json: async () => ({ error: 'Forbidden' }),
        headers: new Map()
      });

      await expect(client.get('/api/analyze')).rejects.toThrow('AUTH_INVALID');
    });

    test('should handle 429 Rate Limit', async () => {
      fetch.mockResolvedValueOnce({
        ok: false,
        status: 429,
        json: async () => ({ error: 'Too many requests', retryAfter: 60 }),
        headers: new Map()
      });

      config.FEATURES.ENABLE_RETRY_LOGIC = false;

      await expect(client.get('/api/analyze')).rejects.toThrow(/RATE_LIMIT_EXCEEDED/);
    });

    test('should handle generic HTTP errors', async () => {
      fetch.mockResolvedValueOnce({
        ok: false,
        status: 500,
        statusText: 'Internal Server Error',
        json: async () => ({ error: 'Server error' }),
        headers: new Map()
      });

      await expect(client.get('/api/analyze')).rejects.toThrow(/HTTP_ERROR/);
    });
  });

  describe('Network Errors', () => {
    test('should handle network errors', async () => {
      fetch.mockRejectedValueOnce(new TypeError('Failed to fetch'));

      await expect(client.get('/api/analyze')).rejects.toThrow('NETWORK_ERROR');
    });

    test('should handle timeout errors', async () => {
      const abortError = new Error('Aborted');
      abortError.name = 'AbortError';
      fetch.mockRejectedValueOnce(abortError);

      await expect(client.get('/api/analyze')).rejects.toThrow('TIMEOUT_ERROR');
    });
  });
});

describe('API Client Tests - Retry Logic', () => {
  let client;

  beforeEach(() => {
    client = new ApiClient();
    config.FEATURES.ENABLE_RETRY_LOGIC = true;
    config.SECURITY_CONFIG.API_KEY = 'test-key';
  });

  describe('Retry on Rate Limit', () => {
    test('should retry on 429 with backoff', async () => {
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
          json: async () => ({ status: 'success' }),
          headers: new Map()
        });

      const result = await client.get('/api/analyze');

      expect(fetch).toHaveBeenCalledTimes(2);
      expect(result.success).toBe(true);
    }, 10000);

    test('should respect max retry attempts', async () => {
      fetch.mockResolvedValue({
        ok: false,
        status: 429,
        json: async () => ({ retryAfter: 1 }),
        headers: new Map()
      });

      await expect(client.get('/api/analyze')).rejects.toThrow(/RATE_LIMIT_EXCEEDED/);

      expect(fetch.mock.calls.length).toBeLessThanOrEqual(config.RATE_LIMIT_CONFIG.RETRY.MAX_ATTEMPTS);
    }, 15000);
  });

  describe('Backoff Calculation', () => {
    test('should calculate exponential backoff', () => {
      const delay1 = client.calculateRetryDelay(1);
      const delay2 = client.calculateRetryDelay(2);
      const delay3 = client.calculateRetryDelay(3);

      expect(delay2).toBeGreaterThan(delay1);
      expect(delay3).toBeGreaterThan(delay2);
    });

    test('should respect max delay', () => {
      const delay = client.calculateRetryDelay(10);
      expect(delay).toBeLessThanOrEqual(config.RATE_LIMIT_CONFIG.RETRY.MAX_DELAY);
    });

    test('should use server retry-after if provided', () => {
      const delay = client.calculateRetryDelay(1, 5);
      expect(delay).toBe(5000);
    });
  });
});

describe('API Client Tests - Client-Side Rate Limiting', () => {
  let client;

  beforeEach(() => {
    client = new ApiClient();
    client.rateLimitTracker = new RateLimitTracker();
  });

  describe('Pre-Request Rate Check', () => {
    test('should allow requests under limit', () => {
      expect(() => client.checkClientRateLimit('/api/analyze')).not.toThrow();
    });

    test('should block requests over limit', () => {
      for (let i = 0; i < 11; i++) {
        client.rateLimitTracker.recordRequest('/api/analyze');
      }

      expect(() => client.checkClientRateLimit('/api/analyze')).toThrow(/CLIENT_RATE_LIMIT/);
    });

    test('should warn when near limit', () => {
      console.warn = jest.fn();

      for (let i = 0; i < 9; i++) {
        client.rateLimitTracker.recordRequest('/api/analyze');
      }

      client.checkClientRateLimit('/api/analyze');

      expect(console.warn).toHaveBeenCalled();
    });
  });
});

describe('API Client Tests - Analyze Questions', () => {
  let client;

  beforeEach(() => {
    client = new ApiClient();
    config.SECURITY_CONFIG.API_KEY = 'test-key';
  });

  describe('Input Validation', () => {
    test('should reject non-array questions', async () => {
      await expect(client.analyzeQuestions('not an array')).rejects.toThrow();
    });

    test('should reject empty array', async () => {
      await expect(client.analyzeQuestions([])).rejects.toThrow();
    });

    test('should reject when API key missing', async () => {
      config.SECURITY_CONFIG.API_KEY = null;
      await expect(client.analyzeQuestions([{ q: 'Test?' }])).rejects.toThrow('AUTH_NO_KEY');
    });
  });

  describe('Successful Analysis', () => {
    test('should analyze questions successfully', async () => {
      fetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        json: async () => ({ status: 'success', answers: [1, 2, 3] }),
        headers: new Map()
      });

      const questions = [
        { question: 'Q1?', answers: ['A', 'B'] },
        { question: 'Q2?', answers: ['A', 'B'] },
        { question: 'Q3?', answers: ['A', 'B'] }
      ];

      const result = await client.analyzeQuestions(questions);

      expect(result.status).toBe('success');
      expect(result.answers).toEqual([1, 2, 3]);
    });

    test('should include timestamp in request', async () => {
      fetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        json: async () => ({ status: 'success', answers: [1] }),
        headers: new Map()
      });

      const questions = [{ question: 'Test?', answers: ['A', 'B'] }];

      await client.analyzeQuestions(questions);

      const callArgs = fetch.mock.calls[0][1];
      const body = JSON.parse(callArgs.body);
      expect(body.timestamp).toBeDefined();
    });
  });
});

describe('API Client Tests - Rate Limit Status', () => {
  let client;

  beforeEach(() => {
    client = new ApiClient();
    client.rateLimitTracker = new RateLimitTracker();
  });

  test('should return rate limit status', () => {
    client.rateLimitTracker.recordRequest('/api/analyze');
    client.rateLimitTracker.recordRequest('/api/analyze');

    const status = client.getRateLimitStatus();

    expect(status.openai).toBeDefined();
    expect(status.openai.used).toBe(2);
    expect(status.openai.limit).toBe(10);
    expect(status.openai.remaining).toBe(8);
    expect(status.general).toBeDefined();
  });

  test('should reset rate limit tracker', () => {
    client.rateLimitTracker.recordRequest('/api/analyze');
    expect(client.rateLimitTracker.requests).toHaveLength(1);

    client.resetRateLimitTracker();

    expect(client.rateLimitTracker.requests).toHaveLength(0);
  });
});

describe('API Client Tests - Health Check', () => {
  let client;

  beforeEach(() => {
    client = new ApiClient();
  });

  test('should perform health check', async () => {
    fetch.mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: async () => ({ status: 'ok' }),
      headers: new Map()
    });

    const result = await client.healthCheck();

    expect(result.status).toBe('ok');
    expect(fetch).toHaveBeenCalledWith(
      expect.stringContaining('/health'),
      expect.any(Object)
    );
  });

  test('should handle health check failure', async () => {
    fetch.mockRejectedValueOnce(new Error('Network error'));

    await expect(client.healthCheck()).rejects.toThrow();
  });
});
