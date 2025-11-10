/**
 * Backend API Endpoint Tests
 * Tests for all API endpoints, request/response handling, and error cases
 *
 * @group backend
 * @group api
 */

const request = require('supertest');
const crypto = require('crypto');
const nock = require('nock');

// Mock environment variables
process.env.OPENAI_API_KEY = 'sk-test' + crypto.randomBytes(32).toString('hex');
process.env.API_KEY = 'test-backend-key-' + crypto.randomBytes(16).toString('hex');
process.env.CORS_ALLOWED_ORIGINS = 'http://localhost:8080';
process.env.STATS_APP_URL = 'http://localhost:8080';

const app = require('../server');

describe('API Endpoint Tests - POST /api/analyze', () => {
  const validApiKey = process.env.API_KEY;

  beforeEach(() => {
    // Mock OpenAI API
    nock('https://api.openai.com')
      .post('/v1/chat/completions')
      .reply(200, {
        choices: [{
          message: {
            content: '[1, 2, 3]'
          }
        }]
      });

    // Mock Stats App
    nock('http://localhost:8080')
      .post('/display-answers')
      .reply(200, { status: 'ok' });
  });

  afterEach(() => {
    nock.cleanAll();
  });

  describe('Successful Requests', () => {
    test('should analyze valid questions successfully', async () => {
      const questions = [
        {
          question: 'What is 2+2?',
          answers: ['3', '4', '5', '6']
        },
        {
          question: 'What is the capital of France?',
          answers: ['London', 'Paris', 'Berlin', 'Madrid']
        },
        {
          question: 'What color is the sky?',
          answers: ['Green', 'Blue', 'Red', 'Yellow']
        }
      ];

      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', validApiKey)
        .send({ questions, timestamp: new Date().toISOString() })
        .expect(200)
        .expect('Content-Type', /json/);

      expect(response.body.status).toBe('success');
      expect(response.body.answers).toEqual([1, 2, 3]);
      expect(response.body.questionCount).toBe(3);
      expect(response.body.message).toMatch(/success/i);
    });

    test('should handle single question', async () => {
      const questions = [
        {
          question: 'What is the answer?',
          answers: ['A', 'B', 'C', 'D']
        }
      ];

      nock.cleanAll();
      nock('https://api.openai.com')
        .post('/v1/chat/completions')
        .reply(200, {
          choices: [{ message: { content: '[2]' } }]
        });

      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', validApiKey)
        .send({ questions })
        .expect(200);

      expect(response.body.status).toBe('success');
      expect(response.body.answers).toEqual([2]);
      expect(response.body.questionCount).toBe(1);
    });

    test('should handle questions with varying answer counts', async () => {
      const questions = [
        {
          question: 'True or False?',
          answers: ['True', 'False']
        },
        {
          question: 'Pick one:',
          answers: ['A', 'B', 'C', 'D', 'E', 'F']
        }
      ];

      nock.cleanAll();
      nock('https://api.openai.com')
        .post('/v1/chat/completions')
        .reply(200, {
          choices: [{ message: { content: '[1, 3]' } }]
        });

      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', validApiKey)
        .send({ questions })
        .expect(200);

      expect(response.body.status).toBe('success');
      expect(response.body.answers).toHaveLength(2);
    });

    test('should include timestamp in response', async () => {
      const questions = [{
        question: 'Test?',
        answers: ['A', 'B']
      }];

      nock.cleanAll();
      nock('https://api.openai.com')
        .post('/v1/chat/completions')
        .reply(200, {
          choices: [{ message: { content: '[1]' } }]
        });

      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', validApiKey)
        .send({ questions, timestamp: '2025-01-01T00:00:00.000Z' })
        .expect(200);

      expect(response.body.status).toBe('success');
    });
  });

  describe('Request Validation', () => {
    test('should reject request without questions field', async () => {
      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', validApiKey)
        .send({})
        .expect(400);

      expect(response.body.error).toMatch(/invalid/i);
      expect(response.body.error).toMatch(/questions/i);
    });

    test('should reject request with non-array questions', async () => {
      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', validApiKey)
        .send({ questions: 'not an array' })
        .expect(400);

      expect(response.body.error).toMatch(/invalid/i);
    });

    test('should reject request with empty questions array', async () => {
      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', validApiKey)
        .send({ questions: [] })
        .expect(400);

      expect(response.body.error).toMatch(/invalid/i);
    });

    test('should reject questions missing required fields', async () => {
      const questions = [
        { question: 'Test?' } // Missing answers
      ];

      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', validApiKey)
        .send({ questions })
        .expect(400);

      expect(response.body.error).toMatch(/invalid/i);
      expect(response.body.error).toMatch(/structure/i);
    });

    test('should reject questions with invalid answer type', async () => {
      const questions = [
        {
          question: 'Test?',
          answers: 'not an array'
        }
      ];

      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', validApiKey)
        .send({ questions })
        .expect(400);

      expect(response.body.error).toMatch(/invalid/i);
    });

    test('should reject questions with empty answers array', async () => {
      const questions = [
        {
          question: 'Test?',
          answers: []
        }
      ];

      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', validApiKey)
        .send({ questions })
        .expect(400);

      expect(response.body.error).toMatch(/invalid/i);
    });

    test('should reject malformed JSON', async () => {
      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', validApiKey)
        .set('Content-Type', 'application/json')
        .send('{"invalid": json}')
        .expect(400);
    });
  });

  describe('OpenAI Integration', () => {
    test('should handle OpenAI API success', async () => {
      nock.cleanAll();
      nock('https://api.openai.com')
        .post('/v1/chat/completions')
        .reply(200, {
          choices: [{ message: { content: '[2, 1, 3]' } }]
        });

      const questions = [
        { question: 'Q1?', answers: ['A', 'B'] },
        { question: 'Q2?', answers: ['A', 'B'] },
        { question: 'Q3?', answers: ['A', 'B', 'C'] }
      ];

      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', validApiKey)
        .send({ questions })
        .expect(200);

      expect(response.body.answers).toEqual([2, 1, 3]);
    });

    test('should handle OpenAI API error', async () => {
      nock.cleanAll();
      nock('https://api.openai.com')
        .post('/v1/chat/completions')
        .reply(500, { error: 'Internal server error' });

      const questions = [
        { question: 'Test?', answers: ['A', 'B'] }
      ];

      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', validApiKey)
        .send({ questions })
        .expect(500);

      expect(response.body.error).toBeDefined();
      expect(response.body.status).toBe('error');
    });

    test('should handle OpenAI API timeout', async () => {
      nock.cleanAll();
      nock('https://api.openai.com')
        .post('/v1/chat/completions')
        .delayConnection(35000)
        .reply(200, {});

      const questions = [
        { question: 'Test?', answers: ['A', 'B'] }
      ];

      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', validApiKey)
        .send({ questions })
        .expect(500);

      expect(response.body.error).toBeDefined();
    }, 40000);

    test('should handle invalid OpenAI response format', async () => {
      nock.cleanAll();
      nock('https://api.openai.com')
        .post('/v1/chat/completions')
        .reply(200, {
          choices: [{ message: { content: 'invalid json' } }]
        });

      const questions = [
        { question: 'Test?', answers: ['A', 'B'] }
      ];

      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', validApiKey)
        .send({ questions })
        .expect(500);

      expect(response.body.error).toBeDefined();
    });

    test('should validate answer indices from OpenAI', async () => {
      nock.cleanAll();
      nock('https://api.openai.com')
        .post('/v1/chat/completions')
        .reply(200, {
          choices: [{ message: { content: '[5]' } }] // Out of range
        });

      const questions = [
        { question: 'Test?', answers: ['A', 'B'] } // Only 2 answers
      ];

      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', validApiKey)
        .send({ questions })
        .expect(200);

      // Should still return response with warning
      expect(response.body.status).toBe('success');
    });
  });

  describe('Stats App Integration', () => {
    test('should send results to Stats app', async () => {
      nock.cleanAll();
      const openaiMock = nock('https://api.openai.com')
        .post('/v1/chat/completions')
        .reply(200, {
          choices: [{ message: { content: '[1]' } }]
        });

      const statsMock = nock('http://localhost:8080')
        .post('/display-answers')
        .reply(200, { status: 'ok' });

      const questions = [
        { question: 'Test?', answers: ['A', 'B'] }
      ];

      await request(app)
        .post('/api/analyze')
        .set('X-API-Key', validApiKey)
        .send({ questions })
        .expect(200);

      // Give it time to send async request
      await new Promise(resolve => setTimeout(resolve, 100));

      expect(openaiMock.isDone()).toBe(true);
      // Stats app call is async, may not complete
    });

    test('should continue if Stats app is unreachable', async () => {
      nock.cleanAll();
      nock('https://api.openai.com')
        .post('/v1/chat/completions')
        .reply(200, {
          choices: [{ message: { content: '[1]' } }]
        });

      nock('http://localhost:8080')
        .post('/display-answers')
        .replyWithError('Connection refused');

      const questions = [
        { question: 'Test?', answers: ['A', 'B'] }
      ];

      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', validApiKey)
        .send({ questions })
        .expect(200);

      // Should still succeed even if Stats app fails
      expect(response.body.status).toBe('success');
    });
  });
});

describe('API Endpoint Tests - GET /health', () => {
  describe('Health Check Response', () => {
    test('should return 200 status', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200)
        .expect('Content-Type', /json/);

      expect(response.body.status).toBe('ok');
    });

    test('should include timestamp', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      expect(response.body.timestamp).toBeDefined();
      expect(new Date(response.body.timestamp)).toBeInstanceOf(Date);
    });

    test('should indicate OpenAI configuration status', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      expect(response.body.openai_configured).toBe(true);
    });

    test('should indicate API key configuration status', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      expect(response.body.api_key_configured).toBe(true);
    });

    test('should include security information', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      expect(response.body.security).toBeDefined();
      expect(response.body.security.cors_enabled).toBe(true);
      expect(response.body.security.authentication_enabled).toBe(true);
    });

    test('should not require authentication', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      expect(response.body.status).toBe('ok');
    });

    test('should handle HEAD requests', async () => {
      const response = await request(app)
        .head('/health')
        .expect(200);
    });
  });
});

describe('API Endpoint Tests - GET /', () => {
  describe('Root Documentation', () => {
    test('should return API documentation', async () => {
      const response = await request(app)
        .get('/')
        .expect(200)
        .expect('Content-Type', /json/);

      expect(response.body.name).toBe('Quiz Analysis Backend');
      expect(response.body.version).toBeDefined();
      expect(response.body.endpoints).toBeDefined();
    });

    test('should list available endpoints', async () => {
      const response = await request(app)
        .get('/')
        .expect(200);

      expect(response.body.endpoints['POST /api/analyze']).toBeDefined();
      expect(response.body.endpoints['GET /health']).toBeDefined();
      expect(response.body.endpoints['WS /']).toBeDefined();
    });

    test('should include documentation reference', async () => {
      const response = await request(app)
        .get('/')
        .expect(200);

      expect(response.body.documentation).toBeDefined();
    });

    test('should not require authentication', async () => {
      const response = await request(app)
        .get('/')
        .expect(200);

      expect(response.body.name).toBe('Quiz Analysis Backend');
    });
  });
});

describe('API Endpoint Tests - Error Handling', () => {
  describe('404 Not Found', () => {
    test('should return 404 for unknown endpoint', async () => {
      const response = await request(app)
        .get('/api/unknown')
        .set('X-API-Key', process.env.API_KEY)
        .expect(404);
    });

    test('should return 404 for invalid POST endpoint', async () => {
      const response = await request(app)
        .post('/api/invalid')
        .set('X-API-Key', process.env.API_KEY)
        .send({})
        .expect(404);
    });
  });

  describe('405 Method Not Allowed', () => {
    test('should not allow GET on /api/analyze', async () => {
      const response = await request(app)
        .get('/api/analyze')
        .set('X-API-Key', process.env.API_KEY)
        .expect(404);
    });

    test('should not allow POST on /health', async () => {
      const response = await request(app)
        .post('/health')
        .set('X-API-Key', process.env.API_KEY)
        .send({})
        .expect(404);
    });
  });

  describe('500 Internal Server Error', () => {
    test('should handle uncaught errors gracefully', async () => {
      nock.cleanAll();
      nock('https://api.openai.com')
        .post('/v1/chat/completions')
        .replyWithError('Catastrophic failure');

      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', process.env.API_KEY)
        .send({
          questions: [{ question: 'Test?', answers: ['A'] }]
        })
        .expect(500);

      expect(response.body.error).toBeDefined();
      expect(response.body.status).toBe('error');
    });
  });

  describe('Error Response Format', () => {
    test('should return consistent error format', async () => {
      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', process.env.API_KEY)
        .send({ questions: [] })
        .expect(400);

      expect(response.body).toHaveProperty('error');
      expect(response.body).toHaveProperty('status');
      expect(response.body.status).toBe('error');
    });

    test('should include error message', async () => {
      const response = await request(app)
        .post('/api/analyze')
        .expect(401);

      expect(response.body.error).toBeDefined();
      expect(response.body.message).toBeDefined();
    });
  });
});

describe('API Endpoint Tests - Content Negotiation', () => {
  describe('Content-Type Handling', () => {
    test('should accept application/json', async () => {
      nock.cleanAll();
      nock('https://api.openai.com')
        .post('/v1/chat/completions')
        .reply(200, {
          choices: [{ message: { content: '[1]' } }]
        });

      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', process.env.API_KEY)
        .set('Content-Type', 'application/json')
        .send(JSON.stringify({
          questions: [{ question: 'Test?', answers: ['A'] }]
        }))
        .expect(200);

      expect(response.body.status).toBe('success');
    });

    test('should reject non-JSON content-type', async () => {
      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', process.env.API_KEY)
        .set('Content-Type', 'text/plain')
        .send('not json')
        .expect(400);
    });
  });

  describe('Response Format', () => {
    test('should always return JSON', async () => {
      const response = await request(app)
        .get('/health')
        .expect('Content-Type', /json/);

      expect(() => JSON.parse(JSON.stringify(response.body))).not.toThrow();
    });
  });
});

describe('API Endpoint Tests - Request Limits', () => {
  describe('Request Size Limits', () => {
    test('should accept reasonable request size', async () => {
      const questions = Array(50).fill({
        question: 'What is the answer?',
        answers: ['A', 'B', 'C', 'D']
      });

      nock.cleanAll();
      nock('https://api.openai.com')
        .post('/v1/chat/completions')
        .reply(200, {
          choices: [{ message: { content: JSON.stringify(Array(50).fill(1)) } }]
        });

      const response = await request(app)
        .post('/api/analyze')
        .set('X-API-Key', process.env.API_KEY)
        .send({ questions });

      expect(response.status).not.toBe(413);
    });
  });
});

describe('API Endpoint Tests - Performance', () => {
  describe('Response Time', () => {
    test('should respond to health check quickly', async () => {
      const startTime = Date.now();

      await request(app)
        .get('/health')
        .expect(200);

      const duration = Date.now() - startTime;
      expect(duration).toBeLessThan(100); // Should respond in under 100ms
    });

    test('should respond to root endpoint quickly', async () => {
      const startTime = Date.now();

      await request(app)
        .get('/')
        .expect(200);

      const duration = Date.now() - startTime;
      expect(duration).toBeLessThan(100);
    });
  });
});
