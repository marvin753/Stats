/**
 * Jest Configuration
 * Comprehensive test configuration for Quiz Stats Animation System
 *
 * @version 1.0.0
 */

module.exports = {
  // Test environment
  testEnvironment: 'node',

  // Root directories
  roots: [
    '<rootDir>/backend/tests',
    '<rootDir>/frontend/tests',
    '<rootDir>/tests'
  ],

  // Module paths
  modulePaths: [
    '<rootDir>',
    '<rootDir>/backend',
    '<rootDir>/frontend'
  ],

  // Test match patterns
  testMatch: [
    '**/__tests__/**/*.js',
    '**/?(*.)+(spec|test).js'
  ],

  // Coverage configuration
  collectCoverage: true,
  coverageDirectory: '<rootDir>/coverage',
  coverageReporters: [
    'text',
    'text-summary',
    'lcov',
    'html',
    'json',
    'clover'
  ],

  // Coverage paths
  collectCoverageFrom: [
    'backend/server.js',
    'scraper.js',
    'frontend/api-client.js',
    'frontend/error-handler.js',
    'frontend/url-validator.js',
    'frontend/config.js',
    '!**/node_modules/**',
    '!**/tests/**',
    '!**/coverage/**',
    '!**/*.test.js',
    '!**/*.spec.js'
  ],

  // Coverage thresholds (80%+ target)
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    },
    './backend/server.js': {
      branches: 85,
      functions: 85,
      lines: 85,
      statements: 85
    },
    './frontend/api-client.js': {
      branches: 85,
      functions: 85,
      lines: 85,
      statements: 85
    },
    './frontend/error-handler.js': {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    },
    './frontend/url-validator.js': {
      branches: 90,
      functions: 90,
      lines: 90,
      statements: 90
    }
  },

  // Setup files
  setupFiles: [
    '<rootDir>/tests/setup.js'
  ],

  // Setup after environment
  setupFilesAfterEnv: [
    '<rootDir>/tests/setupAfterEnv.js'
  ],

  // Disable global setup/teardown for now due to hanging issues
  // globalSetup: undefined,
  // globalTeardown: undefined,

  // Transform configuration
  transform: {
    '^.+\\.jsx?$': 'babel-jest'
  },

  // Transform ignore patterns
  transformIgnorePatterns: [
    'node_modules/(?!(axios)/)'
  ],

  // Module name mapper for ES modules
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/$1',
    '^@backend/(.*)$': '<rootDir>/backend/$1',
    '^@frontend/(.*)$': '<rootDir>/frontend/$1',
    '^@tests/(.*)$': '<rootDir>/tests/$1'
  },

  // Test timeout
  testTimeout: 30000,

  // Verbose output
  verbose: true,

  // Detect open handles - disabled for faster execution
  detectOpenHandles: false,

  // Force exit after tests
  forceExit: true,

  // Clear mocks between tests
  clearMocks: true,

  // Reset mocks between tests
  resetMocks: true,

  // Restore mocks between tests
  restoreMocks: true,

  // Maximum workers
  maxWorkers: '50%',

  // Global setup - temporarily disabled
  // globalSetup: '<rootDir>/tests/globalSetup.js',

  // Global teardown - temporarily disabled
  // globalTeardown: '<rootDir>/tests/globalTeardown.js',

  // Reporters
  reporters: [
    'default',
    [
      'jest-html-reporter',
      {
        pageTitle: 'Quiz Stats Test Report',
        outputPath: '<rootDir>/coverage/test-report.html',
        includeFailureMsg: true,
        includeConsoleLog: true,
        theme: 'darkTheme',
        dateFormat: 'yyyy-mm-dd HH:MM:ss'
      }
    ]
    // jest-junit removed - was causing ETIMEDOUT errors
  ],

  // Watch plugins
  watchPlugins: [
    'jest-watch-typeahead/filename',
    'jest-watch-typeahead/testname'
  ],

  // Module file extensions
  moduleFileExtensions: [
    'js',
    'json',
    'jsx',
    'node'
  ],

  // Test environment options
  testEnvironmentOptions: {
    url: 'http://localhost:3000'
  },

  // Notify
  notify: false,

  // Bail after first failure (for CI)
  bail: false,

  // Error on deprecated APIs
  errorOnDeprecated: true,

  // Projects for different test types
  projects: [
    {
      displayName: 'backend',
      testMatch: ['<rootDir>/backend/tests/**/*.test.js'],
      testEnvironment: 'node'
    },
    {
      displayName: 'frontend',
      testMatch: ['<rootDir>/frontend/tests/**/*.test.js'],
      testEnvironment: 'jsdom'
    },
    {
      displayName: 'integration',
      testMatch: ['<rootDir>/tests/**/*.test.js'],
      testEnvironment: 'node'
    }
  ]
};
