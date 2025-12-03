/**
 * End-to-End Tests
 * Full system integration tests from UI → Backend → OpenAI
 *
 * @group e2e
 */

const request = require('supertest');
const crypto = require('crypto');
const nock = require('nock');

// Setup environment
process.env.OPENAI_API_KEY = 'sk-test' + crypto.randomBytes(32).toString('hex');
process.env.API_KEY = 'e2e-test-key-' + crypto.randomBytes(16).toString('hex');
process.env.BACKEND_API_KEY = process.env.API_KEY;
process.env.CORS_ALLOWED_ORIGINS = 'http://localhost:8080,http://localhost:3000';
process.env.ALLOWED_DOMAINS = 'example.com,quizplatform.com';
process.env.BACKEND_URL = 'http://localhost:3000';

const app = require('../backend/server');
const { scrapeQuestions, sendToBackend, validateUrl } = require('../scraper');

describe('E2E Tests - Complete Quiz Analysis Workflow', () => {
  beforeEach(() => {
    nock.cleanAll();
  });

  afterEach(() => {
    nock.cleanAll();
  });

  test('should complete full quiz analysis from start to finish', async () => {
    // Mock OpenAI
    nock('https://api.openai.com')
      .post('/v1/chat/completions')
      .reply(200, {
        choices: [{
          message: { content: '[2, 1, 3, 4]' }
        }]
      });

    // Simulate scraped questions
    const questions = [
      { question: 'What is 2+2?', answers: ['3', '4', '5', '6'] },
      { question: 'Capital of France?', answers: ['Paris', 'London', 'Berlin'] },
      { question: 'Largest planet?', answers: ['Mars', 'Jupiter', 'Saturn'] },
      { question: 'Speed of light?', answers: ['300,000 km/s', '150,000 km/s', '500,000 km/s'] }
    ];

    // Send to backend
    const response = await request(app)
      .post('/api/analyze')
      .set('X-API-Key', process.env.API_KEY)
      .send({ questions, timestamp: new Date().toISOString() })
      .expect(200);

    expect(response.body.status).toBe('success');
    expect(response.body.answers).toEqual([2, 1, 3, 4]);
    expect(response.body.questionCount).toBe(4);
  });

  test('should handle scraper URL validation', () => {
    // Valid URL
    expect(() => validateUrl('http://example.com/quiz')).not.toThrow();

    // Invalid URLs
    expect(() => validateUrl('http://192.168.1.1')).toThrow(/private/);
    expect(() => validateUrl('http://evil.com')).toThrow(/not whitelisted/);
    expect(() => validateUrl('ftp://example.com')).toThrow(/protocol/);
  });

  test('should handle backend communication from scraper', async () => {
    nock('https://api.openai.com')
      .post('/v1/chat/completions')
      .reply(200, {
        choices: [{ message: { content: '[1, 2]' } }]
      });

    const server = app.listen(0);
    const port = server.address().port;
    const originalUrl = process.env.BACKEND_URL;
    process.env.BACKEND_URL = `http://localhost:${port}`;

    try {
      const questions = [
        { question: 'Test 1?', answers: ['A', 'B'] },
        { question: 'Test 2?', answers: ['C', 'D'] }
      ];

      const answers = await sendToBackend(questions);
      expect(answers).toEqual([1, 2]);
    } finally {
      server.close();
      process.env.BACKEND_URL = originalUrl;
    }
  });

  test('should enforce rate limiting across the system', async () => {
    nock('https://api.openai.com')
      .post('/v1/chat/completions')
      .times(15)
      .reply(200, {
        choices: [{ message: { content: '[1]' } }]
      });

    const questions = [{ question: 'Test?', answers: ['A', 'B'] }];
    const requests = [];

    // Make 12 requests (limit is 10 per minute)
    for (let i = 0; i < 12; i++) {
      requests.push(
        request(app)
          .post('/api/analyze')
          .set('X-API-Key', process.env.API_KEY)
          .send({ questions })
      );
    }

    const responses = await Promise.all(requests);
    const rateLimited = responses.filter(r => r.status === 429);

    expect(rateLimited.length).toBeGreaterThan(0);
  }, 30000);

  test('should maintain security through entire workflow', async () => {
    // Test 1: CORS validation
    const corsResponse = await request(app)
      .post('/api/analyze')
      .set('Origin', 'http://evil.com')
      .set('X-API-Key', process.env.API_KEY)
      .send({ questions: [{ question: 'Test?', answers: ['A'] }] })
      .expect(500);

    // Test 2: Authentication
    const authResponse = await request(app)
      .post('/api/analyze')
      .send({ questions: [{ question: 'Test?', answers: ['A'] }] })
      .expect(401);

    // Test 3: Input validation
    const validationResponse = await request(app)
      .post('/api/analyze')
      .set('X-API-Key', process.env.API_KEY)
      .send({ questions: 'invalid' })
      .expect(400);
  });

  test('should handle errors gracefully across components', async () => {
    // Simulate OpenAI error
    nock('https://api.openai.com')
      .post('/v1/chat/completions')
      .reply(500, { error: 'Service unavailable' });

    const questions = [{ question: 'Test?', answers: ['A', 'B'] }];

    const response = await request(app)
      .post('/api/analyze')
      .set('X-API-Key', process.env.API_KEY)
      .send({ questions })
      .expect(500);

    expect(response.body.status).toBe('error');
    expect(response.body.error).toBeDefined();
  });

  test('should recover from transient failures', async () => {
    // First request fails
    nock('https://api.openai.com')
      .post('/v1/chat/completions')
      .reply(500, { error: 'Temporary error' });

    const questions = [{ question: 'Test?', answers: ['A', 'B'] }];

    await request(app)
      .post('/api/analyze')
      .set('X-API-Key', process.env.API_KEY)
      .send({ questions })
      .expect(500);

    // Second request succeeds
    nock('https://api.openai.com')
      .post('/v1/chat/completions')
      .reply(200, {
        choices: [{ message: { content: '[1]' } }]
      });

    const response = await request(app)
      .post('/api/analyze')
      .set('X-API-Key', process.env.API_KEY)
      .send({ questions })
      .expect(200);

    expect(response.body.status).toBe('success');
  });

  test('should handle large payloads', async () => {
    nock('https://api.openai.com')
      .post('/v1/chat/completions')
      .reply(200, {
        choices: [{ message: { content: JSON.stringify(Array(50).fill(1)) } }]
      });

    const questions = Array(50).fill({
      question: 'What is the answer?',
      answers: ['A', 'B', 'C', 'D']
    });

    const response = await request(app)
      .post('/api/analyze')
      .set('X-API-Key', process.env.API_KEY)
      .send({ questions })
      .expect(200);

    expect(response.body.status).toBe('success');
    expect(response.body.questionCount).toBe(50);
  });

  test('should provide health status for monitoring', async () => {
    const response = await request(app)
      .get('/health')
      .expect(200);

    expect(response.body.status).toBe('ok');
    expect(response.body.openai_configured).toBe(true);
    expect(response.body.api_key_configured).toBe(true);
    expect(response.body.security).toBeDefined();
  });

  test('should handle concurrent users', async () => {
    nock('https://api.openai.com')
      .post('/v1/chat/completions')
      .times(5)
      .reply(200, {
        choices: [{ message: { content: '[1]' } }]
      });

    const questions = [{ question: 'Test?', answers: ['A', 'B'] }];

    const user1 = request(app)
      .post('/api/analyze')
      .set('X-API-Key', process.env.API_KEY)
      .send({ questions });

    const user2 = request(app)
      .post('/api/analyze')
      .set('X-API-Key', process.env.API_KEY)
      .send({ questions });

    const user3 = request(app)
      .post('/api/analyze')
      .set('X-API-Key', process.env.API_KEY)
      .send({ questions });

    const [r1, r2, r3] = await Promise.all([user1, user2, user3]);

    expect([r1.status, r2.status, r3.status]).toContain(200);
  });

  test('should maintain rate limit state correctly', async () => {
    nock('https://api.openai.com')
      .post('/v1/chat/completions')
      .times(5)
      .reply(200, {
        choices: [{ message: { content: '[1]' } }]
      });

    const questions = [{ question: 'Test?', answers: ['A', 'B'] }];

    // Make 3 requests
    for (let i = 0; i < 3; i++) {
      await request(app)
        .post('/api/analyze')
        .set('X-API-Key', process.env.API_KEY)
        .send({ questions })
        .expect(200);
    }

    // Check rate limit headers on next request
    const response = await request(app)
      .post('/api/analyze')
      .set('X-API-Key', process.env.API_KEY)
      .send({ questions });

    expect(response.headers['ratelimit-remaining']).toBeDefined();
    const remaining = parseInt(response.headers['ratelimit-remaining']);
    expect(remaining).toBeLessThan(10);
  });

  test('should validate data consistency end-to-end', async () => {
    const mockAnswers = [2, 1, 4];

    nock('https://api.openai.com')
      .post('/v1/chat/completions')
      .reply(200, {
        choices: [{
          message: { content: JSON.stringify(mockAnswers) }
        }]
      });

    const questions = [
      { question: 'Q1', answers: ['A', 'B', 'C'] },
      { question: 'Q2', answers: ['D', 'E'] },
      { question: 'Q3', answers: ['F', 'G', 'H', 'I'] }
    ];

    const response = await request(app)
      .post('/api/analyze')
      .set('X-API-Key', process.env.API_KEY)
      .send({ questions })
      .expect(200);

    // Verify data consistency
    expect(response.body.answers).toEqual(mockAnswers);
    expect(response.body.questionCount).toBe(questions.length);
  });

  test('should handle timeouts appropriately', async () => {
    nock('https://api.openai.com')
      .post('/v1/chat/completions')
      .delayConnection(35000)
      .reply(200, {});

    const questions = [{ question: 'Test?', answers: ['A', 'B'] }];

    const response = await request(app)
      .post('/api/analyze')
      .set('X-API-Key', process.env.API_KEY)
      .send({ questions })
      .expect(500);

    expect(response.body.status).toBe('error');
  }, 40000);

  test('should provide complete error information', async () => {
    nock('https://api.openai.com')
      .post('/v1/chat/completions')
      .reply(400, {
        error: {
          message: 'Invalid request',
          type: 'invalid_request_error'
        }
      });

    const questions = [{ question: 'Test?', answers: ['A', 'B'] }];

    const response = await request(app)
      .post('/api/analyze')
      .set('X-API-Key', process.env.API_KEY)
      .send({ questions })
      .expect(500);

    expect(response.body.error).toBeDefined();
    expect(response.body.status).toBe('error');
  });
});

describe('E2E Tests - Performance Under Load', () => {
  test('should maintain performance with multiple requests', async () => {
    nock('https://api.openai.com')
      .post('/v1/chat/completions')
      .times(10)
      .reply(200, {
        choices: [{ message: { content: '[1]' } }]
      });

    const questions = [{ question: 'Test?', answers: ['A', 'B'] }];
    const times = [];

    for (let i = 0; i < 10; i++) {
      const start = Date.now();
      await request(app)
        .post('/api/analyze')
        .set('X-API-Key', process.env.API_KEY)
        .send({ questions });
      times.push(Date.now() - start);
    }

    const avgTime = times.reduce((a, b) => a + b) / times.length;
    const maxTime = Math.max(...times);

    expect(avgTime).toBeLessThan(1000);
    expect(maxTime).toBeLessThan(2000);
  }, 30000);
});

describe('E2E Tests - Security Integration', () => {
  test('should block all attack vectors', async () => {
    const attacks = [
      // SSRF attempts
      { url: 'http://192.168.1.1', shouldBlock: true },
      { url: 'http://169.254.169.254', shouldBlock: true },
      { url: 'http://metadata.google.internal', shouldBlock: true },

      // Protocol attacks
      { url: 'file:///etc/passwd', shouldBlock: true },
      { url: 'javascript:alert(1)', shouldBlock: true },

      // Domain attacks
      { url: 'http://evil.com', shouldBlock: true },

      // Valid URLs
      { url: 'http://example.com', shouldBlock: false },
      { url: 'https://quizplatform.com', shouldBlock: false }
    ];

    attacks.forEach(({ url, shouldBlock }) => {
      if (shouldBlock) {
        expect(() => validateUrl(url)).toThrow();
      } else {
        expect(() => validateUrl(url)).not.toThrow();
      }
    });
  });
});
