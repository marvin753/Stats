/**
 * Global Setup
 * Runs once before all tests
 */

module.exports = async () => {
  console.log('\n🚀 Starting test suite...\n');

  // Set test environment
  process.env.NODE_ENV = 'test';

  // Clean up any previous test artifacts
  const fs = require('fs');
  const path = require('path');

  const coverageDir = path.join(__dirname, '..', 'coverage');
  if (fs.existsSync(coverageDir)) {
    fs.rmSync(coverageDir, { recursive: true, force: true });
  }
};
