/**
 * API Client Module
 * Handles all API communications with security features:
 * - Authentication (X-API-Key header)
 * - Rate limiting tracking and retry logic
 * - CORS error handling
 * - Request logging and monitoring
 *
 * @module api-client
 * @version 2.0.0
 */

import config from './config.js';
import ErrorHandler from './error-handler.js';

/**
 * Rate Limit Tracker
 * Tracks client-side rate limit usage
 */
class RateLimitTracker {
  constructor() {
    this.requests = [];
    this.loadFromStorage();
  }

  /**
   * Load request history from sessionStorage
   */
  loadFromStorage() {
    if (!config.RATE_LIMIT_CONFIG.TRACKING.ENABLED) return;

    try {
      const stored = sessionStorage.getItem(config.RATE_LIMIT_CONFIG.TRACKING.STORAGE_KEY);
      if (stored) {
        this.requests = JSON.parse(stored).filter(req =>
          Date.now() - req.timestamp < config.RATE_LIMIT_CONFIG.GENERAL.WINDOW_MS
        );
      }
    } catch (error) {
      console.warn('Failed to load rate limit tracker:', error);
      this.requests = [];
    }
  }

  /**
   * Save request history to sessionStorage
   */
  saveToStorage() {
    if (!config.RATE_LIMIT_CONFIG.TRACKING.ENABLED) return;

    try {
      sessionStorage.setItem(
        config.RATE_LIMIT_CONFIG.TRACKING.STORAGE_KEY,
        JSON.stringify(this.requests)
      );
    } catch (error) {
      console.warn('Failed to save rate limit tracker:', error);
    }
  }

  /**
   * Record a new request
   */
  recordRequest(endpoint, timestamp = Date.now()) {
    this.requests.push({ endpoint, timestamp });
    this.cleanupOldRequests();
    this.saveToStorage();
  }

  /**
   * Remove old requests outside the time window
   */
  cleanupOldRequests() {
    const now = Date.now();
    this.requests = this.requests.filter(req =>
      now - req.timestamp < config.RATE_LIMIT_CONFIG.GENERAL.WINDOW_MS
    );
  }

  /**
   * Get request count for endpoint within time window
   */
  getRequestCount(endpoint, windowMs) {
    const now = Date.now();
    return this.requests.filter(req =>
      req.endpoint === endpoint && now - req.timestamp < windowMs
    ).length;
  }

  /**
   * Check if endpoint is near rate limit
   */
  isNearLimit(endpoint, maxRequests, windowMs) {
    const count = this.getRequestCount(endpoint, windowMs);
    const threshold = maxRequests * config.UI_CONFIG.RATE_LIMIT_WARNING_THRESHOLD;
    return count >= threshold;
  }

  /**
   * Check if endpoint is rate limited
   */
  isRateLimited(endpoint, maxRequests, windowMs) {
    const count = this.getRequestCount(endpoint, windowMs);
    return count >= maxRequests;
  }

  /**
   * Get remaining requests
   */
  getRemainingRequests(endpoint, maxRequests, windowMs) {
    const count = this.getRequestCount(endpoint, windowMs);
    return Math.max(0, maxRequests - count);
  }

  /**
   * Get time until rate limit reset
   */
  getTimeUntilReset(endpoint, windowMs) {
    const relevantRequests = this.requests
      .filter(req => req.endpoint === endpoint)
      .sort((a, b) => a.timestamp - b.timestamp);

    if (relevantRequests.length === 0) return 0;

    const oldestRequest = relevantRequests[0];
    const resetTime = oldestRequest.timestamp + windowMs;
    return Math.max(0, resetTime - Date.now());
  }
}

/**
 * API Client Class
 */
class ApiClient {
  constructor() {
    this.rateLimitTracker = new RateLimitTracker();
    this.retryAttempts = new Map();
  }

  /**
   * Build request headers with authentication
   */
  buildHeaders(additionalHeaders = {}) {
    const headers = {
      'Content-Type': 'application/json',
      ...additionalHeaders
    };

    // Add API key if configured
    if (config.SECURITY_CONFIG.API_KEY) {
      headers[config.SECURITY_CONFIG.API_KEY_HEADER] = config.SECURITY_CONFIG.API_KEY;
    }

    return headers;
  }

  /**
   * Log request for debugging
   */
  logRequest(method, url, options = {}) {
    if (!config.FEATURES.ENABLE_REQUEST_LOGGING) return;

    console.group(`[API] ${method} ${url}`);
    console.log('Timestamp:', new Date().toISOString());
    console.log('Has API Key:', !!config.SECURITY_CONFIG.API_KEY);
    if (options.body) {
      console.log('Body:', JSON.parse(options.body));
    }
    console.groupEnd();
  }

  /**
   * Log response for debugging
   */
  logResponse(url, response, duration) {
    if (!config.FEATURES.ENABLE_REQUEST_LOGGING) return;

    console.group(`[API] Response from ${url}`);
    console.log('Status:', response.status, response.statusText);
    console.log('Duration:', `${duration}ms`);
    console.log('Rate Limit Headers:', {
      limit: response.headers.get('RateLimit-Limit'),
      remaining: response.headers.get('RateLimit-Remaining'),
      reset: response.headers.get('RateLimit-Reset')
    });
    console.groupEnd();
  }

  /**
   * Check client-side rate limit before making request
   */
  checkClientRateLimit(endpoint) {
    // Check OpenAI endpoint specifically
    if (endpoint === config.API_CONFIG.ENDPOINTS.ANALYZE) {
      const { MAX_REQUESTS, WINDOW_MS } = config.RATE_LIMIT_CONFIG.OPENAI;

      if (this.rateLimitTracker.isRateLimited(endpoint, MAX_REQUESTS, WINDOW_MS)) {
        const timeUntilReset = this.rateLimitTracker.getTimeUntilReset(endpoint, WINDOW_MS);
        throw new Error(`CLIENT_RATE_LIMIT:${Math.ceil(timeUntilReset / 1000)}`);
      }

      // Show warning if near limit
      if (this.rateLimitTracker.isNearLimit(endpoint, MAX_REQUESTS, WINDOW_MS)) {
        const remaining = this.rateLimitTracker.getRemainingRequests(endpoint, MAX_REQUESTS, WINDOW_MS);
        console.warn(`Rate limit warning: ${remaining} requests remaining`);
      }
    }

    // Check general rate limit
    const { MAX_REQUESTS, WINDOW_MS } = config.RATE_LIMIT_CONFIG.GENERAL;
    if (this.rateLimitTracker.isRateLimited(endpoint, MAX_REQUESTS, WINDOW_MS)) {
      const timeUntilReset = this.rateLimitTracker.getTimeUntilReset(endpoint, WINDOW_MS);
      throw new Error(`CLIENT_RATE_LIMIT:${Math.ceil(timeUntilReset / 1000)}`);
    }
  }

  /**
   * Parse rate limit headers from response
   */
  parseRateLimitHeaders(response) {
    return {
      limit: parseInt(response.headers.get('RateLimit-Limit') || '0'),
      remaining: parseInt(response.headers.get('RateLimit-Remaining') || '0'),
      reset: parseInt(response.headers.get('RateLimit-Reset') || '0')
    };
  }

  /**
   * Calculate retry delay with exponential backoff
   */
  calculateRetryDelay(attemptNumber, retryAfter = null) {
    if (retryAfter) {
      // Server provided retry-after header
      return retryAfter * 1000;
    }

    // Exponential backoff: delay = initial * (multiplier ^ attempt)
    const { INITIAL_DELAY, MAX_DELAY, BACKOFF_MULTIPLIER } = config.RATE_LIMIT_CONFIG.RETRY;
    const delay = INITIAL_DELAY * Math.pow(BACKOFF_MULTIPLIER, attemptNumber - 1);
    return Math.min(delay, MAX_DELAY);
  }

  /**
   * Make HTTP request with retry logic
   */
  async makeRequest(method, url, options = {}, attemptNumber = 1) {
    const startTime = Date.now();
    const requestId = `${method}:${url}:${startTime}`;

    try {
      // Log request
      this.logRequest(method, url, options);

      // Make request
      const response = await fetch(url, {
        method,
        ...options,
        credentials: config.SECURITY_CONFIG.CORS.WITH_CREDENTIALS ? 'include' : 'same-origin'
      });

      // Log response
      const duration = Date.now() - startTime;
      this.logResponse(url, response, duration);

      // Parse rate limit info
      const rateLimitInfo = this.parseRateLimitHeaders(response);

      // Handle different status codes
      if (response.status === 429) {
        // Rate limited
        const data = await response.json().catch(() => ({}));
        const retryAfter = data.retryAfter || rateLimitInfo.reset || null;

        // Check if we should retry
        if (config.FEATURES.ENABLE_RETRY_LOGIC && attemptNumber < config.RATE_LIMIT_CONFIG.RETRY.MAX_ATTEMPTS) {
          const delay = this.calculateRetryDelay(attemptNumber, retryAfter);
          console.warn(`Rate limited. Retrying after ${delay}ms (attempt ${attemptNumber + 1})`);

          // Wait and retry
          await new Promise(resolve => setTimeout(resolve, delay));
          return this.makeRequest(method, url, options, attemptNumber + 1);
        }

        // Max retries exceeded
        throw new Error(`RATE_LIMIT_EXCEEDED:${retryAfter || 0}`);
      }

      if (response.status === 401) {
        throw new Error('AUTH_NO_KEY');
      }

      if (response.status === 403) {
        throw new Error('AUTH_INVALID');
      }

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({ error: response.statusText }));
        throw new Error(`HTTP_ERROR:${response.status}:${errorData.error || errorData.message || response.statusText}`);
      }

      // Success - parse response
      const data = await response.json();
      return {
        success: true,
        data,
        rateLimitInfo,
        duration
      };

    } catch (error) {
      // Handle network errors
      if (error.name === 'TypeError' && error.message.includes('fetch')) {
        throw new Error('NETWORK_ERROR');
      }

      // Handle timeout errors
      if (error.name === 'AbortError') {
        throw new Error('TIMEOUT_ERROR');
      }

      // Re-throw other errors
      throw error;
    }
  }

  /**
   * GET request
   */
  async get(endpoint, options = {}) {
    const url = config.getApiUrl(endpoint);
    const headers = this.buildHeaders(options.headers);

    return this.makeRequest('GET', url, {
      ...options,
      headers
    });
  }

  /**
   * POST request
   */
  async post(endpoint, data = {}, options = {}) {
    // Check client-side rate limit before making request
    this.checkClientRateLimit(endpoint);

    const url = config.getApiUrl(endpoint);
    const headers = this.buildHeaders(options.headers);

    const result = await this.makeRequest('POST', url, {
      ...options,
      headers,
      body: JSON.stringify(data)
    });

    // Record successful request for rate limiting
    this.rateLimitTracker.recordRequest(endpoint);

    return result;
  }

  /**
   * Health check
   */
  async healthCheck() {
    try {
      const result = await this.get(config.API_CONFIG.ENDPOINTS.HEALTH, {
        timeout: config.API_CONFIG.TIMEOUTS.HEALTH_CHECK
      });
      return result.data;
    } catch (error) {
      console.error('Health check failed:', error);
      throw error;
    }
  }

  /**
   * Analyze questions (main API endpoint)
   */
  async analyzeQuestions(questions) {
    if (!Array.isArray(questions) || questions.length === 0) {
      throw new Error('Questions array is required');
    }

    // Validate API key
    if (!config.SECURITY_CONFIG.API_KEY) {
      throw new Error('AUTH_NO_KEY');
    }

    try {
      const result = await this.post(
        config.API_CONFIG.ENDPOINTS.ANALYZE,
        {
          questions,
          timestamp: new Date().toISOString()
        },
        {
          timeout: config.API_CONFIG.TIMEOUTS.ANALYZE
        }
      );

      return result.data;
    } catch (error) {
      throw ErrorHandler.handleApiError(error);
    }
  }

  /**
   * Get rate limit status
   */
  getRateLimitStatus() {
    const analyzeEndpoint = config.API_CONFIG.ENDPOINTS.ANALYZE;
    const { MAX_REQUESTS: openaiMax, WINDOW_MS: openaiWindow } = config.RATE_LIMIT_CONFIG.OPENAI;
    const { MAX_REQUESTS: generalMax, WINDOW_MS: generalWindow } = config.RATE_LIMIT_CONFIG.GENERAL;

    return {
      openai: {
        used: this.rateLimitTracker.getRequestCount(analyzeEndpoint, openaiWindow),
        limit: openaiMax,
        remaining: this.rateLimitTracker.getRemainingRequests(analyzeEndpoint, openaiMax, openaiWindow),
        resetIn: this.rateLimitTracker.getTimeUntilReset(analyzeEndpoint, openaiWindow),
        isNearLimit: this.rateLimitTracker.isNearLimit(analyzeEndpoint, openaiMax, openaiWindow)
      },
      general: {
        used: this.rateLimitTracker.getRequestCount(analyzeEndpoint, generalWindow),
        limit: generalMax,
        remaining: this.rateLimitTracker.getRemainingRequests(analyzeEndpoint, generalMax, generalWindow),
        resetIn: this.rateLimitTracker.getTimeUntilReset(analyzeEndpoint, generalWindow)
      }
    };
  }

  /**
   * Reset rate limit tracker (for testing)
   */
  resetRateLimitTracker() {
    this.rateLimitTracker = new RateLimitTracker();
    sessionStorage.removeItem(config.RATE_LIMIT_CONFIG.TRACKING.STORAGE_KEY);
  }
}

// Create singleton instance
const apiClient = new ApiClient();

// Export singleton
export default apiClient;

// Also export class for testing
export { ApiClient, RateLimitTracker };
