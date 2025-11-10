/**
 * Jest Setup File
 * Runs before each test file
 */

// Suppress console warnings in tests
const originalWarn = console.warn;
const originalError = console.error;

console.warn = (...args) => {
  if (args[0]?.includes?.('deprecated')) return;
  originalWarn.apply(console, args);
};

console.error = (...args) => {
  if (args[0]?.includes?.('Warning:')) return;
  originalError.apply(console, args);
};

// Set test environment variables
process.env.NODE_ENV = 'test';
process.env.BACKEND_PORT = '3001';

// Mock timers
global.setImmediate = global.setImmediate || ((fn, ...args) => global.setTimeout(fn, 0, ...args));
