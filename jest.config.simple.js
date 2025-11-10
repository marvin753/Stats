/**
 * Simplified Jest Configuration for Quick Testing
 */

module.exports = {
  testEnvironment: 'node',

  roots: [
    '<rootDir>/backend/tests',
    '<rootDir>/frontend/tests',
    '<rootDir>/tests'
  ],

  testMatch: [
    '**/?(*.)+(spec|test).js'
  ],

  // Coverage configuration - disabled for faster execution
  collectCoverage: false,

  // Setup files
  setupFiles: [
    '<rootDir>/tests/setup.js'
  ],

  setupFilesAfterEnv: [
    '<rootDir>/tests/setupAfterEnv.js'
  ],

  // Transform configuration
  transform: {
    '^.+\\.jsx?$': 'babel-jest'
  },

  transformIgnorePatterns: [
    'node_modules/(?!(axios)/)'
  ],

  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/$1',
    '^@backend/(.*)$': '<rootDir>/backend/$1',
    '^@frontend/(.*)$': '<rootDir>/frontend/$1',
    '^@tests/(.*)$': '<rootDir>/tests/$1'
  },

  testTimeout: 5000,
  verbose: true,
  detectOpenHandles: false,
  forceExit: true,
  workerIdleMemoryLimit: 512,
  clearMocks: true,
  resetMocks: true,
  restoreMocks: true,
  maxWorkers: 1,

  reporters: [
    'default'
  ],

  moduleFileExtensions: [
    'js',
    'json',
    'jsx',
    'node'
  ],

  bail: 0,
  errorOnDeprecated: false
};
