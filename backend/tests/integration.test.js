/**
 * Backend Integration Tests
 * End-to-end flow tests from scraper → backend → OpenAI
 *
 * @group backend
 * @group integration
 */

const request = require('supertest');
const crypto = require('crypto');
const nock = require('nock');
const { scrapeQuestions, sendToBackend, validateUrl } = require('../../scraper');

// Mock environment
process.env.OPENAI_API_KEY = 'sk-test' + crypto.randomBytes(32).toString('hex');
process.env.API_KEY = 'test-key-' + crypto.randomBytes(16).toString('hex');
process.env.BACKEND_API_KEY = process.env.API_KEY;
process.env.CORS_ALLOWED_ORIGINS = 'http://localhost:8080';
process.env.BACKEND_URL = 'http://localhost:3000';
process.env.ALLOWED_DOMAINS = 'example.com,localhost';

const app = require('../server');

describe('Integration Tests - Full Workflow', () => {
  beforeEach(() => {
    nock.cleanAll();
  });

  afterEach(() => {
    nock.cleanAll();
  });

  describe('Scraper → Backend → OpenAI Flow', () => {
    test('should complete full analysis workflow', async () => {
      // Mock OpenAI
      const openaiMock = nock('https://api.openai.com')
        .post('/v1/chat/completions')
        .reply(200, {
          choices: [{
            message: { content: '[2, 1, 3]' }
          }]
        });

      // Simulate scraped questions
      const questions = [
        { question: 'What is 2+2?', answers: ['3', '4', '5', '6'] },
        { question: 'Capital of France?', answers: ['Paris', 'London', 'Berlin'] },
        { question: 'Color of sky?', answers: ['Red', 'Green', 'Blue'] }
      ];

      // Send to backend
      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', process.env.API_KEY)
        .send({ questions, timestamp: new Date().toISOString() })
        .expect(200);

      expect(response.body.status).toBe('success');
      expect(response.body.answers).toEqual([2, 1, 3]);
      expect(response.body.questionCount).toBe(3);
      expect(openaiMock.isDone()).toBe(true);
    });

    test('should handle multiple concurrent requests', async () => {
      nock('https://api.openai.com')
        .post('/v1/chat/completions')
        .times(3)
        .reply(200, {
          choices: [{ message: { content: '[1]' } }]
        });

      const questions = [{ question: 'Test?', answers: ['A', 'B'] }];

      const requests = [
        request(app)
          .post('/api/analyze')
          .set('X-API-Key', process.env.API_KEY)
          .send({ questions }),
        request(app)
          .post('/api/analyze')
          .set('X-API-Key', process.env.API_KEY)
          .send({ questions }),
        request(app)
          .post('/api/analyze')
          .set('X-API-Key', process.env.API_KEY)
          .send({ questions })
      ];

      const responses = await Promise.all(requests);

      responses.forEach(response => {
        expect(response.body.status).toBe('success');
        expect(response.body.answers).toEqual([1]);
      });
    });
  });

  describe('Error Propagation', () => {
    test('should propagate OpenAI errors to client', async () => {
      nock('https://api.openai.com')
        .post('/v1/chat/completions')
        .reply(500, { error: 'OpenAI service error' });

      const questions = [{ question: 'Test?', answers: ['A', 'B'] }];

      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', process.env.API_KEY)
        .send({ questions })
        .expect(500);

      expect(response.body.status).toBe('error');
      expect(response.body.error).toBeDefined();
    });

    test('should handle authentication failures in workflow', async () => {
      const response = await request(app)
        .post('/api/analyze')
        .send({ questions: [{ question: 'Test?', answers: ['A'] }] })
        .expect(401);

      expect(response.body.error).toBe('Authentication required');
    });

    test('should handle validation errors early in workflow', async () => {
      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', process.env.API_KEY)
        .send({ questions: [] })
        .expect(400);

      expect(response.body.error).toMatch(/invalid/i);
    });
  });

  describe('Rate Limiting Across Workflow', () => {
    test('should enforce rate limits across multiple requests', async () => {
      nock('https://api.openai.com')
        .post('/v1/chat/completions')
        .times(15)
        .reply(200, {
          choices: [{ message: { content: '[1]' } }]
        });

      const questions = [{ question: 'Test?', answers: ['A', 'B'] }];
      const requests = [];

      for (let i = 0; i < 15; i++) {
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
  });

  describe('Data Transformation', () => {
    test('should correctly transform questions through pipeline', async () => {
      nock('https://api.openai.com')
        .post('/v1/chat/completions', body => {
          // Verify questions are properly formatted
          const messages = body.messages;
          expect(messages).toHaveLength(2);
          expect(messages[0].role).toBe('system');
          expect(messages[1].role).toBe('user');
          return true;
        })
        .reply(200, {
          choices: [{ message: { content: '[1, 2]' } }]
        });

      const questions = [
        { question: 'Q1?', answers: ['A', 'B'] },
        { question: 'Q2?', answers: ['A', 'B'] }
      ];

      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', process.env.API_KEY)
        .send({ questions })
        .expect(200);

      expect(response.body.answers).toEqual([1, 2]);
    });
  });
});

describe('Integration Tests - Scraper Module', () => {
  describe('URL Validation Integration', () => {
    test('should validate whitelisted domain', () => {
      expect(() => validateUrl('http://example.com/quiz')).not.toThrow();
    });

    test('should reject non-whitelisted domain', () => {
      expect(() => validateUrl('http://evil.com/quiz')).toThrow(/not whitelisted/);
    });

    test('should reject private IP addresses', () => {
      expect(() => validateUrl('http://192.168.1.1/quiz')).toThrow(/private/);
      expect(() => validateUrl('http://10.0.0.1/quiz')).toThrow(/private/);
      expect(() => validateUrl('http://127.0.0.1/quiz')).toThrow(/private/);
    });

    test('should reject unsupported protocols', () => {
      expect(() => validateUrl('ftp://example.com')).toThrow(/protocol/);
      expect(() => validateUrl('file:///etc/passwd')).toThrow(/protocol/);
    });

    test('should accept subdomains of whitelisted domains', () => {
      expect(() => validateUrl('http://sub.example.com/quiz')).not.toThrow();
    });
  });

  describe('Backend Communication Integration', () => {
    test('should successfully send questions to backend', async () => {
      nock('https://api.openai.com')
        .post('/v1/chat/completions')
        .reply(200, {
          choices: [{ message: { content: '[1, 2]' } }]
        });

      // Start test server
      const server = app.listen(0);
      const port = server.address().port;
      const originalBackendUrl = process.env.BACKEND_URL;
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
        process.env.BACKEND_URL = originalBackendUrl;
      }
    });

    test('should handle backend connection errors', async () => {
      const originalBackendUrl = process.env.BACKEND_URL;
      process.env.BACKEND_URL = 'http://localhost:99999'; // Invalid port

      try {
        const questions = [{ question: 'Test?', answers: ['A', 'B'] }];
        await expect(sendToBackend(questions)).rejects.toThrow();
      } finally {
        process.env.BACKEND_URL = originalBackendUrl;
      }
    });

    test('should include API key in backend requests', async () => {
      nock('https://api.openai.com')
        .post('/v1/chat/completions')
        .reply(200, {
          choices: [{ message: { content: '[1]' } }]
        });

      const server = app.listen(0);
      const port = server.address().port;
      const originalBackendUrl = process.env.BACKEND_URL;
      process.env.BACKEND_URL = `http://localhost:${port}`;

      try {
        const questions = [{ question: 'Test?', answers: ['A', 'B'] }];
        const answers = await sendToBackend(questions);
        expect(answers).toBeDefined();
      } finally {
        server.close();
        process.env.BACKEND_URL = originalBackendUrl;
      }
    });
  });
});

describe('Integration Tests - Authentication Flow', () => {
  describe('API Key Lifecycle', () => {
    test('should persist authentication across multiple requests', async () => {
      nock('https://api.openai.com')
        .post('/v1/chat/completions')
        .times(3)
        .reply(200, {
          choices: [{ message: { content: '[1]' } }]
        });

      const questions = [{ question: 'Test?', answers: ['A', 'B'] }];

      for (let i = 0; i < 3; i++) {
        const response = await request(app)
          .post('/api/analyze')
          .set('X-API-Key', process.env.API_KEY)
          .send({ questions })
          .expect(200);

        expect(response.body.status).toBe('success');
      }
    });

    test('should reject requests after API key is invalidated', async () => {
      const invalidKey = 'invalid-key';

      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', invalidKey)
        .send({ questions: [{ question: 'Test?', answers: ['A'] }] })
        .expect(403);

      expect(response.body.error).toBe('Authentication failed');
    });
  });
});

describe('Integration Tests - Performance', () => {
  describe('Response Time Under Load', () => {
    test('should handle multiple sequential requests efficiently', async () => {
      nock('https://api.openai.com')
        .post('/v1/chat/completions')
        .times(5)
        .reply(200, {
          choices: [{ message: { content: '[1]' } }]
        });

      const questions = [{ question: 'Test?', answers: ['A', 'B'] }];
      const times = [];

      for (let i = 0; i < 5; i++) {
        const start = Date.now();
        await request(app)
          .post('/api/analyze')
          .set('X-API-Key', process.env.API_KEY)
          .send({ questions });
        times.push(Date.now() - start);
      }

      const avgTime = times.reduce((a, b) => a + b, 0) / times.length;
      expect(avgTime).toBeLessThan(1000); // Average should be under 1s
    }, 30000);
  });

  describe('Memory Management', () => {
    test('should not leak memory with repeated requests', async () => {
      nock('https://api.openai.com')
        .post('/v1/chat/completions')
        .times(20)
        .reply(200, {
          choices: [{ message: { content: '[1]' } }]
        });

      const initialMemory = process.memoryUsage().heapUsed;
      const questions = [{ question: 'Test?', answers: ['A', 'B'] }];

      for (let i = 0; i < 20; i++) {
        await request(app)
          .post('/api/analyze')
          .set('X-API-Key', process.env.API_KEY)
          .send({ questions });
      }

      // Force garbage collection if available
      if (global.gc) global.gc();

      const finalMemory = process.memoryUsage().heapUsed;
      const memoryIncrease = finalMemory - initialMemory;

      // Memory shouldn't increase by more than 50MB
      expect(memoryIncrease).toBeLessThan(50 * 1024 * 1024);
    }, 60000);
  });
});

describe('Integration Tests - Error Recovery', () => {
  describe('Graceful Degradation', () => {
    test('should continue serving after OpenAI error', async () => {
      // First request fails
      nock('https://api.openai.com')
        .post('/v1/chat/completions')
        .reply(500, { error: 'Server error' });

      const questions = [{ question: 'Test?', answers: ['A', 'B'] }];

      await request(app)
        .post('/api/analyze')
        .set('X-API-Key', process.env.API_KEY)
        .send({ questions })
        .expect(500);

      // Second request should still work
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
  });
});
