#!/usr/bin/env node

/**
 * Simple standalone test runner
 * No Jest, no hanging issues
 */

const http = require('http');
const assert = require('assert');

// Set environment
process.env.NODE_ENV = 'test';
process.env.OPENAI_API_KEY = 'sk-test-12345';
process.env.API_KEY = 'test-api-key-12345';
process.env.CORS_ALLOWED_ORIGINS = 'http://localhost:8080';
process.env.STATS_APP_URL = 'http://localhost:8080';

console.log('Loading server...');
const app = require('./backend/server');

console.log('Starting simple test...');

// Create HTTP server from the app
const server = app.listen(0, () => {
  const addr = server.address();
  const port = addr.port;
  console.log(`Server listening on port ${port}`);

  // Test 1: Health check endpoint
  const req = http.get(`http://localhost:${port}/health`, (res) => {
    let data = '';
    res.on('data', (chunk) => { data += chunk; });
    res.on('end', () => {
      try {
        assert.strictEqual(res.statusCode, 200, 'Health check should return 200');
        const body = JSON.parse(data);
        assert.strictEqual(body.status, 'ok', 'Health status should be ok');
        console.log('✓ Health check test passed');

        // Test 2: Root endpoint
        const req2 = http.get(`http://localhost:${port}/`, (res2) => {
          let data2 = '';
          res2.on('data', (chunk) => { data2 += chunk; });
          res2.on('end', () => {
            try {
              assert.strictEqual(res2.statusCode, 200, 'Root endpoint should return 200');
              const body2 = JSON.parse(data2);
              assert.strictEqual(body2.name, 'Quiz Analysis Backend', 'API name should match');
              console.log('✓ Root endpoint test passed');

              console.log('\n✅ All tests passed!');
              server.close(() => {
                process.exit(0);
              });
            } catch (err) {
              console.error('✗ Root endpoint test failed:', err.message);
              server.close(() => {
                process.exit(1);
              });
            }
          });
        });

        req2.on('error', (err) => {
          console.error('Request error:', err.message);
          server.close(() => {
            process.exit(1);
          });
        });
      } catch (err) {
        console.error('✗ Health check test failed:', err.message);
        server.close(() => {
          process.exit(1);
        });
      }
    });
  });

  req.on('error', (err) => {
    console.error('Request error:', err.message);
    server.close(() => {
      process.exit(1);
    });
  });

  // Timeout after 10 seconds
  setTimeout(() => {
    console.error('Test timeout!');
    server.close(() => {
      process.exit(1);
    });
  }, 10000);
});

server.on('error', (err) => {
  console.error('Server error:', err.message);
  process.exit(1);
});
