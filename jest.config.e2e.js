/**
 * Jest Configuration for E2E Playwright Tests
 *
 * This configuration is specifically optimized for end-to-end browser testing
 * with Playwright and includes proper timeouts, reporters, and coverage settings.
 */

module.exports = {
  // Display name for this configuration
  displayName: 'E2E Browser Tests',

  // Test environment - use default Node.js environment
  testEnvironment: 'node',

  // Root directory for tests
  rootDir: '<rootDir>',

  // Test match patterns
  testMatch: [
    '**/tests/e2e.playwright.js',
    '**/tests/e2e.test.js'
  ],

  // Ignore patterns
  testPathIgnorePatterns: [
    '/node_modules/',
    '/backend/node_modules/',
    '/.git/'
  ],

  // Module paths
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/$1'
  },

  // Setup files
  setupFilesAfterEnv: [
    '<rootDir>/tests/setup-e2e.js'
  ],

  // Transformer configuration
  transform: {
    '^.+\\.jsx?$': 'babel-jest'
  },

  // Coverage configuration
  collectCoverageFrom: [
    'scraper.js',
    'backend/server.js',
    'tests/**/*.js',
    '!tests/e2e.playwright.js',
    '!tests/setup-e2e.js',
    '!**/node_modules/**'
  ],

  // Coverage thresholds
  coverageThresholds: {
    global: {
      branches: 50,
      functions: 50,
      lines: 50,
      statements: 50
    }
  },

  // Test timeout - E2E tests need longer timeout
  testTimeout: 60000,

  // Verbose output
  verbose: true,

  // Maximum workers for parallel execution
  maxWorkers: '50%',

  // Bail on first test failure (optional)
  bail: 0,

  // Error on deprecated APIs
  errorOnDeprecated: true,

  // Reporter configuration
  reporters: [
    'default',
    [
      'jest-html-reporter',
      {
        pageTitle: 'E2E Playwright Test Report',
        outputPath: 'test-results/e2e-report.html',
        includeFailureMsg: true,
        includeConsoleLog: true,
        dateFormat: 'yyyy-mm-dd HH:MM:ss'
      }
    ],
    [
      'jest-junit',
      {
        outputDirectory: 'test-results',
        outputName: 'e2e-junit.xml',
        classNameTemplate: '{classname}',
        titleTemplate: '{title}',
        ancestorSeparator: ' › ',
        usePathAsClassName: true
      }
    ]
  ],

  // Globals configuration
  globals: {
    'ts-jest': {
      isolatedModules: true
    }
  },

  // Watch plugins
  watchPlugins: [
    'jest-watch-typeahead/filename',
    'jest-watch-typeahead/testname'
  ],

  // Clear mocks between tests
  clearMocks: true,

  // Restore mocks between tests
  restoreMocks: true,

  // Reset modules between tests
  resetModules: true,

  // Collect coverage
  collectCoverage: false,

  // Coverage directory
  coverageDirectory: 'coverage/e2e',

  // Coverage reporters
  coverageReporters: [
    'text',
    'text-summary',
    'html',
    'lcov',
    'json'
  ],

  // Coverage path ignore patterns
  coveragePathIgnorePatterns: [
    '/node_modules/',
    '/backend/node_modules/',
    'test-screenshots',
    'test-results'
  ]
};
