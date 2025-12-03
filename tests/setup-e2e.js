/**
 * Jest Setup File for E2E Tests
 *
 * This file runs before all E2E tests and sets up:
 * - Global test configuration
 * - Environment variables
 * - Test utilities
 * - Custom matchers
 * - Timeout handling
 */

const fs = require('fs');
const path = require('path');

/**
 * Set test timeout to 60 seconds for E2E tests
 */
jest.setTimeout(60000);

/**
 * Setup environment variables for E2E tests
 */
process.env.NODE_ENV = 'test';
process.env.TEST_ENVIRONMENT = 'e2e';
process.env.DEBUG = process.env.DEBUG || '';

/**
 * Ensure required directories exist
 */
const requiredDirs = [
  path.join(__dirname, '../test-screenshots'),
  path.join(__dirname, '../test-results')
];

requiredDirs.forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
    console.log(`Created directory: ${dir}`);
  }
});

/**
 * Custom matchers for E2E tests
 */
expect.extend({
  /**
   * Match URL pattern
   */
  toMatchUrl(received, pattern) {
    const pass = new RegExp(pattern).test(received);
    return {
      pass,
      message: () =>
        pass
          ? `expected ${received} not to match ${pattern}`
          : `expected ${received} to match ${pattern}`
    };
  },

  /**
   * Match response status
   */
  toHaveStatus(response, expectedStatus) {
    const pass = response.status === expectedStatus;
    return {
      pass,
      message: () =>
        pass
          ? `expected response status ${response.status} not to be ${expectedStatus}`
          : `expected response status ${response.status} to be ${expectedStatus}`
    };
  },

  /**
   * Match response body property
   */
  toHaveProperty(obj, property, value) {
    const pass = obj[property] === value;
    return {
      pass,
      message: () =>
        pass
          ? `expected ${property} not to equal ${value}`
          : `expected ${property} to equal ${value}`
    };
  },

  /**
   * Match if element is visible
   */
  toBeVisible(element) {
    if (!element) {
      return {
        pass: false,
        message: () => 'element is null or undefined'
      };
    }

    const pass = element && element.offsetParent !== null;
    return {
      pass,
      message: () =>
        pass
          ? `expected element to be hidden`
          : `expected element to be visible`
    };
  },

  /**
   * Match response time
   */
  toRespondFastly(duration, maxDuration = 1000) {
    const pass = duration <= maxDuration;
    return {
      pass,
      message: () =>
        pass
          ? `expected response time ${duration}ms to exceed ${maxDuration}ms`
          : `expected response time ${duration}ms to be under ${maxDuration}ms`
    };
  }
});

/**
 * Global test utilities
 */
global.testUtils = {
  /**
   * Sleep for specified milliseconds
   */
  sleep: (ms) => new Promise(resolve => setTimeout(resolve, ms)),

  /**
   * Retry async function with exponential backoff
   */
  retry: async (fn, maxAttempts = 3, delayMs = 1000) => {
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await fn();
      } catch (error) {
        if (attempt === maxAttempts) throw error;
        const delay = delayMs * Math.pow(2, attempt - 1);
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
  },

  /**
   * Wait for condition to be true
   */
  waitFor: async (condition, maxWaitMs = 5000, checkIntervalMs = 100) => {
    const startTime = Date.now();
    while (Date.now() - startTime < maxWaitMs) {
      if (condition()) {
        return true;
      }
      await new Promise(resolve => setTimeout(resolve, checkIntervalMs));
    }
    return false;
  },

  /**
   * Generate unique ID for test artifacts
   */
  generateTestId: () => {
    return `test-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }
};

/**
 * Before all tests
 */
beforeAll(() => {
  console.log('\n========== E2E TEST SETUP ==========');
  console.log(`Environment: ${process.env.NODE_ENV}`);
  console.log(`Test Type: ${process.env.TEST_ENVIRONMENT}`);
  console.log(`Test Timeout: 60000ms`);
  console.log(`Screenshots Dir: ${path.join(__dirname, '../test-screenshots')}`);
  console.log('====================================\n');
});

/**
 * After all tests
 */
afterAll(() => {
  console.log('\n========== E2E TEST CLEANUP ==========');
  console.log(`Total test duration: ${Math.round(Date.now() / 1000)}s`);
  console.log('======================================\n');
});

/**
 * Error handler for unhandled rejections
 */
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

/**
 * Error handler for uncaught exceptions
 */
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
});

/**
 * Export for use in tests
 */
module.exports = {
  testUtils: global.testUtils
};
