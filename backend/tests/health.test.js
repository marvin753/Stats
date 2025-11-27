/**
 * Health Check Test
 * Simple test to verify server is working
 */

const request = require('supertest');

// Set test environment
process.env.NODE_ENV = 'test';
process.env.OPENAI_API_KEY = 'sk-test';
process.env.API_KEY = 'test-key';
process.env.CORS_ALLOWED_ORIGINS = 'http://localhost:8080';
process.env.STATS_APP_URL = 'http://localhost:8080';

const app = require('../server');

describe('Health Check', () => {
  test('health endpoint should return ok', async () => {
    const response = await request(app)
      .get('/health')
      .expect(200);

    expect(response.body.status).toBe('ok');
    expect(response.body.timestamp).toBeDefined();
  });

  test('health endpoint should return configuration status', async () => {
    const response = await request(app)
      .get('/health')
      .expect(200);

    expect(response.body.openai_configured).toBe(true);
    expect(response.body.api_key_configured).toBe(true);
  });
});
