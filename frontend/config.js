/**
 * Frontend Configuration Module
 * Centralized configuration for API endpoints, security settings, and environment variables
 *
 * @module config
 * @version 2.0.0
 */

/**
 * Environment Detection
 * Automatically detects if running in development, staging, or production
 */
const ENV = {
  isDevelopment: window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1',
  isStaging: window.location.hostname.includes('staging'),
  isProduction: !window.location.hostname.includes('localhost') && !window.location.hostname.includes('staging')
};

/**
 * API Configuration
 * Endpoint URLs and timeouts
 */
const API_CONFIG = {
  // Backend base URL - defaults to localhost in development
  BACKEND_URL: (() => {
    if (ENV.isDevelopment) {
      return window.BACKEND_URL || 'http://localhost:3000';
    } else if (ENV.isStaging) {
      return window.BACKEND_URL || 'https://api-staging.example.com';
    } else {
      return window.BACKEND_URL || 'https://api.example.com';
    }
  })(),

  // API Endpoints
  ENDPOINTS: {
    ANALYZE: '/api/analyze',
    HEALTH: '/health',
    ROOT: '/'
  },

  // Request Timeouts (milliseconds)
  TIMEOUTS: {
    DEFAULT: 30000,        // 30 seconds
    ANALYZE: 60000,        // 60 seconds (AI analysis can take time)
    HEALTH_CHECK: 5000     // 5 seconds
  }
};

/**
 * Security Configuration
 * API key management and CORS settings
 */
const SECURITY_CONFIG = {
  // API Key - NEVER hardcode in production!
  // In production, retrieve from secure environment or prompt user
  API_KEY: (() => {
    if (ENV.isDevelopment) {
      // Development: Allow fallback to window variable or sessionStorage
      return window.API_KEY || sessionStorage.getItem('quiz_api_key') || null;
    } else {
      // Production: Only use sessionStorage (never localStorage for security)
      return sessionStorage.getItem('quiz_api_key') || null;
    }
  })(),

  // API Key Header Name
  API_KEY_HEADER: 'X-API-Key',

  // CORS Settings
  CORS: {
    // Allowed origins (frontend domains that can access the API)
    ALLOWED_ORIGINS: ENV.isDevelopment
      ? ['http://localhost:8080', 'http://localhost:3000']
      : ['https://app.example.com', 'https://quiz.example.com'],

    // Include credentials in requests
    WITH_CREDENTIALS: true
  }
};

/**
 * URL Validation Configuration
 * Whitelist for scraper and SSRF protection
 */
const URL_VALIDATION_CONFIG = {
  // Allowed domains for scraping (must match backend whitelist)
  ALLOWED_DOMAINS: (() => {
    if (ENV.isDevelopment) {
      return window.ALLOWED_DOMAINS || ['example.com', 'quizplatform.com', 'localhost'];
    } else {
      return window.ALLOWED_DOMAINS || ['quizplatform.com', 'yourquizsite.com'];
    }
  })(),

  // Allowed protocols
  ALLOWED_PROTOCOLS: ['http:', 'https:'],

  // Private IP ranges to block (RFC 1918, RFC 4193, RFC 3927)
  PRIVATE_IP_PATTERNS: [
    /^10\./,                          // 10.0.0.0/8
    /^172\.(1[6-9]|2[0-9]|3[0-1])\./,// 172.16.0.0/12
    /^192\.168\./,                    // 192.168.0.0/16
    /^127\./,                         // 127.0.0.0/8 (localhost)
    /^169\.254\./,                    // 169.254.0.0/16 (link-local)
    /^fc00:/,                         // fc00::/7 (IPv6 ULA)
    /^fe80:/,                         // fe80::/10 (IPv6 link-local)
    /^::1$/,                          // ::1 (IPv6 localhost)
    /^localhost$/i                    // localhost (any case)
  ],

  // Cloud metadata endpoints to block
  BLOCKED_METADATA_ENDPOINTS: [
    '169.254.169.254',              // AWS, Azure, GCP
    'metadata.google.internal',      // GCP
    '100.100.100.200'                // Alibaba Cloud
  ]
};

/**
 * Rate Limiting Configuration
 * Client-side tracking and retry logic
 */
const RATE_LIMIT_CONFIG = {
  // General rate limits (should match backend)
  GENERAL: {
    MAX_REQUESTS: 100,
    WINDOW_MS: 15 * 60 * 1000  // 15 minutes
  },

  // OpenAI analysis rate limits (should match backend)
  OPENAI: {
    MAX_REQUESTS: 10,
    WINDOW_MS: 60 * 1000  // 1 minute
  },

  // Retry configuration
  RETRY: {
    MAX_ATTEMPTS: 3,
    INITIAL_DELAY: 1000,        // 1 second
    MAX_DELAY: 30000,            // 30 seconds
    BACKOFF_MULTIPLIER: 2        // Exponential backoff
  },

  // Client-side tracking
  TRACKING: {
    ENABLED: true,
    STORAGE_KEY: 'quiz_rate_limit_tracker'
  }
};

/**
 * Error Messages
 * User-friendly error messages for different scenarios
 */
const ERROR_MESSAGES = {
  // CORS Errors
  CORS_BLOCKED: 'Access denied. The server has rejected this request due to CORS policy.',
  CORS_HELP: 'Please ensure you are accessing the application from an authorized domain.',

  // Authentication Errors
  AUTH_NO_KEY: 'API key is missing. Please configure your API key to use this feature.',
  AUTH_INVALID: 'Invalid API key. Please check your credentials and try again.',
  AUTH_EXPIRED: 'Your session has expired. Please refresh and try again.',

  // Rate Limiting Errors
  RATE_LIMIT_GENERAL: 'Too many requests. Please wait a moment before trying again.',
  RATE_LIMIT_ANALYSIS: 'Analysis rate limit exceeded. Please wait before analyzing more quizzes.',
  RATE_LIMIT_HELP: 'Rate limits help protect the service from abuse.',

  // URL Validation Errors
  URL_INVALID_FORMAT: 'Invalid URL format. Please enter a valid URL.',
  URL_INVALID_PROTOCOL: 'Unsupported protocol. Only HTTP and HTTPS are allowed.',
  URL_PRIVATE_IP: 'Access to private/internal IP addresses is not allowed.',
  URL_NOT_WHITELISTED: 'This domain is not authorized for scraping.',
  URL_BLOCKED_METADATA: 'Access to cloud metadata services is blocked for security.',

  // Network Errors
  NETWORK_ERROR: 'Network error. Please check your internet connection.',
  TIMEOUT_ERROR: 'Request timeout. The server took too long to respond.',
  SERVER_ERROR: 'Server error. Please try again later.',

  // Generic
  UNKNOWN_ERROR: 'An unexpected error occurred. Please try again.'
};

/**
 * UI Configuration
 * Visual feedback and notification settings
 */
const UI_CONFIG = {
  // Notification durations (milliseconds)
  NOTIFICATION_DURATION: {
    SUCCESS: 5000,
    INFO: 7000,
    WARNING: 10000,
    ERROR: 0  // 0 = requires manual dismissal
  },

  // Loading states
  LOADING: {
    MIN_DISPLAY_TIME: 500,  // Minimum time to show loading indicator
    SPINNER_DELAY: 200       // Delay before showing spinner
  },

  // Rate limit UI
  RATE_LIMIT_WARNING_THRESHOLD: 0.8,  // Show warning at 80% of limit

  // Retry UI
  SHOW_RETRY_COUNTDOWN: true
};

/**
 * Feature Flags
 * Enable/disable features
 */
const FEATURES = {
  ENABLE_RATE_LIMIT_TRACKING: true,
  ENABLE_RETRY_LOGIC: true,
  ENABLE_DETAILED_ERRORS: ENV.isDevelopment,
  ENABLE_REQUEST_LOGGING: ENV.isDevelopment,
  ENABLE_PERFORMANCE_MONITORING: true
};

/**
 * Validation Helpers
 */
const VALIDATION = {
  /**
   * Validate API key format (base64, 32+ characters)
   */
  isValidApiKeyFormat(key) {
    if (!key || typeof key !== 'string') return false;

    // API key should be base64 and at least 32 characters
    const base64Regex = /^[A-Za-z0-9+/=]{32,}$/;
    return base64Regex.test(key);
  },

  /**
   * Validate URL format
   */
  isValidUrl(urlString) {
    try {
      new URL(urlString);
      return true;
    } catch {
      return false;
    }
  }
};

/**
 * Export configuration
 */
export default {
  ENV,
  API_CONFIG,
  SECURITY_CONFIG,
  URL_VALIDATION_CONFIG,
  RATE_LIMIT_CONFIG,
  ERROR_MESSAGES,
  UI_CONFIG,
  FEATURES,
  VALIDATION,

  // Version information
  VERSION: '2.0.0',
  BUILD_DATE: new Date('2025-11-04'),

  /**
   * Get full API URL
   */
  getApiUrl(endpoint) {
    return `${API_CONFIG.BACKEND_URL}${endpoint}`;
  },

  /**
   * Check if API key is configured
   */
  hasApiKey() {
    return !!SECURITY_CONFIG.API_KEY;
  },

  /**
   * Set API key (stores in sessionStorage)
   */
  setApiKey(key) {
    if (VALIDATION.isValidApiKeyFormat(key)) {
      sessionStorage.setItem('quiz_api_key', key);
      SECURITY_CONFIG.API_KEY = key;
      return true;
    }
    return false;
  },

  /**
   * Clear API key
   */
  clearApiKey() {
    sessionStorage.removeItem('quiz_api_key');
    SECURITY_CONFIG.API_KEY = null;
  },

  /**
   * Get configuration summary for debugging
   */
  getSummary() {
    return {
      environment: ENV.isDevelopment ? 'development' : ENV.isStaging ? 'staging' : 'production',
      backendUrl: API_CONFIG.BACKEND_URL,
      hasApiKey: this.hasApiKey(),
      allowedDomains: URL_VALIDATION_CONFIG.ALLOWED_DOMAINS,
      features: FEATURES,
      version: this.VERSION
    };
  }
};
