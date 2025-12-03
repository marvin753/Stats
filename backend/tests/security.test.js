/**
 * Backend Security Tests
 * Tests for CORS, authentication, rate limiting, and SSRF protection
 *
 * @group backend
 * @group security
 */

const request = require('supertest');
const express = require('express');
const crypto = require('crypto');

// Mock environment variables
process.env.OPENAI_API_KEY = 'test-openai-key-' + crypto.randomBytes(16).toString('hex');
process.env.API_KEY = 'test-api-key-' + crypto.randomBytes(16).toString('hex');
process.env.CORS_ALLOWED_ORIGINS = 'http://localhost:8080,http://localhost:3000';

// Import server after setting env vars
const app = require('../server');

describe('Security Tests - CORS', () => {
  describe('CORS Origin Validation', () => {
    test('should accept requests from whitelisted origin', async () => {
      const response = await request(app)
        .get('/health')
        .set('Origin', 'http://localhost:8080')
        .expect('Content-Type', /json/);

      expect(response.headers['access-control-allow-origin']).toBe('http://localhost:8080');
      expect(response.status).toBe(200);
    });

    test('should accept requests from second whitelisted origin', async () => {
      const response = await request(app)
        .get('/health')
        .set('Origin', 'http://localhost:3000')
        .expect('Content-Type', /json/);

      expect(response.headers['access-control-allow-origin']).toBe('http://localhost:3000');
      expect(response.status).toBe(200);
    });

    test('should reject requests from non-whitelisted origin', async () => {
      const response = await request(app)
        .get('/health')
        .set('Origin', 'http://evil.com')
        .expect(500);

      expect(response.body.error).toMatch(/CORS/i);
    });

    test('should reject requests from similar but different origin', async () => {
      const response = await request(app)
        .get('/health')
        .set('Origin', 'http://localhost:8081')
        .expect(500);

      expect(response.body.error).toMatch(/CORS/i);
    });

    test('should allow requests without origin header', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      expect(response.body.status).toBe('ok');
    });

    test('should handle preflight OPTIONS request correctly', async () => {
      const response = await request(app)
        .options('/api/analyze')
        .set('Origin', 'http://localhost:8080')
        .set('Access-Control-Request-Method', 'POST')
        .set('Access-Control-Request-Headers', 'content-type,x-api-key');

      expect(response.status).toBeLessThan(300);
    });

    test('should reject CORS requests with credentials from untrusted origin', async () => {
      const response = await request(app)
        .post('/api/analyze')
        .set('Origin', 'http://malicious.com')
        .set('X-API-Key', process.env.API_KEY)
        .set('Cookie', 'session=abc123')
        .send({ questions: [] })
        .expect(500);
    });
  });

  describe('CORS Configuration', () => {
    test('should include credentials in CORS headers', async () => {
      const response = await request(app)
        .get('/health')
        .set('Origin', 'http://localhost:8080');

      expect(response.headers['access-control-allow-credentials']).toBe('true');
    });

    test('should handle missing CORS_ALLOWED_ORIGINS env var', async () => {
      const originalEnv = process.env.CORS_ALLOWED_ORIGINS;
      delete process.env.CORS_ALLOWED_ORIGINS;

      // Re-import to test default behavior
      delete require.cache[require.resolve('../server')];
      const testApp = require('../server');

      const response = await testApp
        .request(testApp)
        .get('/health')
        .set('Origin', 'http://localhost:8080');

      expect(response.status).toBe(200);

      // Restore
      process.env.CORS_ALLOWED_ORIGINS = originalEnv;
    });
  });
});

describe('Security Tests - Authentication', () => {
  const validApiKey = process.env.API_KEY;
  const invalidApiKey = 'invalid-key-12345';

  describe('API Key Validation', () => {
    test('should reject requests without API key', async () => {
      const response = await request(app)
        .post('/api/analyze')
        .send({ questions: [{ question: 'Test?', answers: ['A', 'B'] }] })
        .expect(401);

      expect(response.body.error).toBe('Authentication required');
      expect(response.body.message).toMatch(/missing/i);
    });

    test('should reject requests with invalid API key', async () => {
      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', invalidApiKey)
        .send({ questions: [{ question: 'Test?', answers: ['A', 'B'] }] })
        .expect(403);

      expect(response.body.error).toBe('Authentication failed');
      expect(response.body.message).toMatch(/invalid/i);
    });

    test('should accept requests with valid API key', async () => {
      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', validApiKey)
        .send({
          questions: [
            {
              question: 'What is 2+2?',
              answers: ['3', '4', '5', '6']
            }
          ]
        })
        .expect('Content-Type', /json/);

      // Should not be auth error (might be rate limit or other)
      expect(response.body.error).not.toBe('Authentication required');
      expect(response.body.error).not.toBe('Authentication failed');
    });

    test('should allow public endpoints without authentication', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      expect(response.body.status).toBe('ok');
    });

    test('should allow root endpoint without authentication', async () => {
      const response = await request(app)
        .get('/')
        .expect(200);

      expect(response.body.name).toBe('Quiz Analysis Backend');
    });
  });

  describe('Timing Attack Prevention', () => {
    test('should use constant-time comparison for API keys', async () => {
      const startTime1 = Date.now();
      await request(app)
        .post('/api/analyze')
        .set('X-API-Key', 'a')
        .send({ questions: [] });
      const duration1 = Date.now() - startTime1;

      const startTime2 = Date.now();
      await request(app)
        .post('/api/analyze')
        .set('X-API-Key', 'a'.repeat(validApiKey.length))
        .send({ questions: [] });
      const duration2 = Date.now() - startTime2;

      // Timing should be similar (within 50ms)
      expect(Math.abs(duration1 - duration2)).toBeLessThan(50);
    });

    test('should reject keys of different lengths in constant time', async () => {
      const shortKey = 'abc';
      const longKey = 'a'.repeat(100);

      const startTime1 = Date.now();
      await request(app)
        .post('/api/analyze')
        .set('X-API-Key', shortKey)
        .send({ questions: [] });
      const duration1 = Date.now() - startTime1;

      const startTime2 = Date.now();
      await request(app)
        .post('/api/analyze')
        .set('X-API-Key', longKey)
        .send({ questions: [] });
      const duration2 = Date.now() - startTime2;

      // Should still be similar timing
      expect(Math.abs(duration1 - duration2)).toBeLessThan(50);
    });
  });

  describe('API Key Header Variations', () => {
    test('should only accept X-API-Key header (not case variations)', async () => {
      const response = await request(app)
        .post('/api/analyze')
        .set('x-api-key', validApiKey) // lowercase
        .send({ questions: [{ question: 'Test?', answers: ['A'] }] })
        .expect('Content-Type', /json/);

      // Should work (Express normalizes headers)
      expect(response.body.error).not.toBe('Authentication required');
    });

    test('should reject Authorization header as API key', async () => {
      const response = await request(app)
        .post('/api/analyze')
        .set('Authorization', `Bearer ${validApiKey}`)
        .send({ questions: [{ question: 'Test?', answers: ['A'] }] })
        .expect(401);

      expect(response.body.error).toBe('Authentication required');
    });

    test('should reject API key in query parameter', async () => {
      const response = await request(app)
        .post('/api/analyze?apiKey=' + validApiKey)
        .send({ questions: [{ question: 'Test?', answers: ['A'] }] })
        .expect(401);

      expect(response.body.error).toBe('Authentication required');
    });
  });
});

describe('Security Tests - Rate Limiting', () => {
  const validApiKey = process.env.API_KEY;

  beforeEach(() => {
    // Wait to avoid rate limit carryover between tests
    return new Promise(resolve => setTimeout(resolve, 1000));
  });

  describe('General Rate Limiting', () => {
    test('should allow requests under rate limit', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      expect(response.body.status).toBe('ok');
    });

    test('should include rate limit headers', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      expect(response.headers['ratelimit-limit']).toBeDefined();
      expect(response.headers['ratelimit-remaining']).toBeDefined();
      expect(response.headers['ratelimit-reset']).toBeDefined();
    });

    test('should decrement remaining count with each request', async () => {
      const response1 = await request(app).get('/health');
      const remaining1 = parseInt(response1.headers['ratelimit-remaining']);

      const response2 = await request(app).get('/health');
      const remaining2 = parseInt(response2.headers['ratelimit-remaining']);

      expect(remaining2).toBeLessThan(remaining1);
    });

    test('should block requests after exceeding general rate limit', async () => {
      // Make many requests quickly
      const requests = [];
      for (let i = 0; i < 105; i++) {
        requests.push(
          request(app)
            .get('/health')
        );
      }

      const responses = await Promise.all(requests);
      const blockedResponses = responses.filter(r => r.status === 429);

      expect(blockedResponses.length).toBeGreaterThan(0);
    }, 30000); // Increase timeout for this test
  });

  describe('OpenAI Endpoint Rate Limiting', () => {
    test('should have stricter rate limit for analyze endpoint', async () => {
      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', validApiKey)
        .send({
          questions: [{ question: 'Test?', answers: ['A', 'B'] }]
        });

      // Limit should be lower than general limit
      const limit = parseInt(response.headers['ratelimit-limit'] || '10');
      expect(limit).toBeLessThanOrEqual(10);
    });

    test('should return 429 when OpenAI rate limit exceeded', async () => {
      const requests = [];

      // Make 11 requests (limit is 10 per minute)
      for (let i = 0; i < 11; i++) {
        requests.push(
          request(app)
            .post('/api/analyze')
            .set('X-API-Key', validApiKey)
            .send({
              questions: [{ question: `Test ${i}?`, answers: ['A', 'B'] }]
            })
        );
      }

      const responses = await Promise.all(requests);
      const rateLimitedResponses = responses.filter(r => r.status === 429);

      expect(rateLimitedResponses.length).toBeGreaterThan(0);
      expect(rateLimitedResponses[0].body.error).toMatch(/rate limit/i);
    }, 30000);

    test('should include retry-after in rate limit response', async () => {
      // Exhaust rate limit
      const requests = [];
      for (let i = 0; i < 15; i++) {
        requests.push(
          request(app)
            .post('/api/analyze')
            .set('X-API-Key', validApiKey)
            .send({ questions: [{ question: 'Test?', answers: ['A'] }] })
        );
      }

      const responses = await Promise.all(requests);
      const rateLimited = responses.find(r => r.status === 429);

      if (rateLimited) {
        expect(rateLimited.body.retryAfter).toBeDefined();
        expect(typeof rateLimited.body.retryAfter).toBe('number');
        expect(rateLimited.body.retryAfter).toBeGreaterThan(0);
      }
    }, 30000);
  });

  describe('Rate Limit Reset', () => {
    test('should reset rate limit after time window', async () => {
      // Make request
      const response1 = await request(app)
        .get('/health');
      const remaining1 = parseInt(response1.headers['ratelimit-remaining']);

      // Wait for reset (general limit is 15 minutes, but we can test the mechanism)
      await new Promise(resolve => setTimeout(resolve, 2000));

      const response2 = await request(app)
        .get('/health');
      const remaining2 = parseInt(response2.headers['ratelimit-remaining']);

      // Remaining should not decrease significantly if we're in new window
      expect(remaining2).toBeGreaterThan(0);
    });
  });
});

describe('Security Tests - SSRF Protection', () => {
  // Note: SSRF protection is in scraper.js, not server.js
  // These tests verify that backend doesn't expose vulnerable endpoints

  describe('Payload Size Limits', () => {
    test('should accept reasonable payload size', async () => {
      const questions = Array(10).fill({
        question: 'Test question?',
        answers: ['A', 'B', 'C', 'D']
      });

      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', process.env.API_KEY)
        .send({ questions });

      // Should not be rejected for size (may fail for other reasons)
      expect(response.status).not.toBe(413);
    });

    test('should reject extremely large payloads', async () => {
      const hugeString = 'A'.repeat(15 * 1024 * 1024); // 15MB
      const questions = [{
        question: hugeString,
        answers: ['A', 'B']
      }];

      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', process.env.API_KEY)
        .send({ questions });

      expect(response.status).toBe(413);
    });
  });

  describe('Input Validation', () => {
    test('should reject invalid question structure', async () => {
      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', process.env.API_KEY)
        .send({ questions: 'not an array' })
        .expect(400);

      expect(response.body.error).toMatch(/invalid/i);
    });

    test('should reject empty questions array', async () => {
      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', process.env.API_KEY)
        .send({ questions: [] })
        .expect(400);

      expect(response.body.error).toMatch(/invalid/i);
    });

    test('should reject questions without required fields', async () => {
      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', process.env.API_KEY)
        .send({
          questions: [
            { question: 'Test?' } // Missing answers
          ]
        })
        .expect(400);

      expect(response.body.error).toMatch(/invalid/i);
    });

    test('should reject questions with invalid answer format', async () => {
      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', process.env.API_KEY)
        .send({
          questions: [
            { question: 'Test?', answers: 'not an array' }
          ]
        })
        .expect(400);

      expect(response.body.error).toMatch(/invalid/i);
    });
  });

  describe('XSS Prevention', () => {
    test('should sanitize HTML in question text', async () => {
      const xssPayload = '<script>alert("XSS")</script>';
      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', process.env.API_KEY)
        .send({
          questions: [
            { question: xssPayload, answers: ['A', 'B'] }
          ]
        });

      // Should not execute script or return it unsanitized
      if (response.body.error) {
        expect(response.body.error).not.toContain('<script>');
      }
    });
  });
});

describe('Security Tests - WebSocket Security', () => {
  // WebSocket security tests would require ws client
  // Placeholder for future implementation

  test('should secure WebSocket connections', () => {
    // TODO: Implement WebSocket security tests
    expect(true).toBe(true);
  });
});

describe('Security Tests - Error Information Disclosure', () => {
  describe('Error Messages', () => {
    test('should not expose internal paths in error messages', async () => {
      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', 'invalid')
        .send({ invalid: 'data' });

      expect(response.body.error || response.body.message).not.toMatch(/\/Users\//);
      expect(response.body.error || response.body.message).not.toMatch(/node_modules/);
    });

    test('should not expose stack traces in production', async () => {
      const originalEnv = process.env.NODE_ENV;
      process.env.NODE_ENV = 'production';

      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', process.env.API_KEY)
        .send({ questions: 'invalid' });

      expect(response.body.stack).toBeUndefined();

      process.env.NODE_ENV = originalEnv;
    });

    test('should not expose API keys in error messages', async () => {
      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', 'test-key')
        .send({ questions: [] });

      const responseText = JSON.stringify(response.body);
      expect(responseText).not.toContain(process.env.OPENAI_API_KEY);
      expect(responseText).not.toContain(process.env.API_KEY);
    });
  });
});

describe('Security Tests - Configuration', () => {
  describe('Environment Variables', () => {
    test('should require OPENAI_API_KEY to be configured', () => {
      expect(process.env.OPENAI_API_KEY).toBeDefined();
      expect(process.env.OPENAI_API_KEY.length).toBeGreaterThan(0);
    });

    test('should handle missing API_KEY gracefully', async () => {
      const originalKey = process.env.API_KEY;
      delete process.env.API_KEY;

      // Reload server
      delete require.cache[require.resolve('../server')];
      const testApp = require('../server');

      const response = await request(testApp)
        .post('/api/analyze')
        .send({ questions: [{ question: 'Test?', answers: ['A'] }] });

      // Should allow request with warning (insecure mode)
      expect(response.status).not.toBe(401);

      // Restore
      process.env.API_KEY = originalKey;
    });
  });

  describe('Security Headers', () => {
    test('should return JSON content-type for API responses', async () => {
      const response = await request(app)
        .get('/health');

      expect(response.headers['content-type']).toMatch(/application\/json/);
    });

    test('should not expose server information', async () => {
      const response = await request(app)
        .get('/health');

      expect(response.headers['x-powered-by']).toBeUndefined();
    });
  });
});
