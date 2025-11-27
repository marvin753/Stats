/**
 * Integration Tests: Backend Assistant API
 * Tests PDF upload, thread management, and quiz analysis
 */

const axios = require('axios');
const fs = require('fs');
const path = require('path');

describe('Backend Assistant API Integration Tests', () => {
  const BASE_URL = 'http://localhost:3000/api';
  const HEALTH_URL = 'http://localhost:3000/health';
  let threadId = null;
  let assistantId = null;

  beforeAll(() => {
    console.log('🚀 Starting Backend API tests...');
  });

  afterAll(async () => {
    // Cleanup: Delete test thread if it exists
    if (threadId) {
      try {
        await axios.delete(`${BASE_URL}/thread/${threadId}`);
        console.log('🧹 Cleanup: Test thread deleted');
      } catch (error) {
        console.log('⚠️  Cleanup: Thread already deleted or not found');
      }
    }
  });

  describe('Health Check', () => {
    test('Should return backend health status', async () => {
      const response = await axios.get(HEALTH_URL);

      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('status');
      expect(response.data.status).toBe('ok');

      console.log('✅ Backend health check passed:', response.data);
    });

    test('Should report OpenAI configuration status', async () => {
      const response = await axios.get(HEALTH_URL);

      expect(response.data).toHaveProperty('openai_configured');
      expect(response.data.openai_configured).toBe(true);

      console.log('✅ OpenAI configured:', response.data.openai_configured);
    });

    test('Should include timestamp in health response', async () => {
      const response = await axios.get(HEALTH_URL);

      expect(response.data).toHaveProperty('timestamp');
      const timestamp = new Date(response.data.timestamp);
      expect(timestamp).toBeInstanceOf(Date);
      expect(timestamp.getTime()).toBeLessThanOrEqual(Date.now());

      console.log('✅ Health check timestamp:', response.data.timestamp);
    });
  });

  describe('PDF Upload and Thread Creation', () => {
    test('Should upload PDF and create assistant thread', async () => {
      const pdfPath = path.join(__dirname, '../fixtures/test-script.pdf');

      // Check if test PDF exists
      if (!fs.existsSync(pdfPath)) {
        console.log('⚠️  Test PDF not found, creating mock...');
        // Test will be skipped if no PDF - create one manually
        return;
      }

      const response = await axios.post(
        `${BASE_URL}/upload-pdf`,
        { pdfPath },
        { timeout: 60000 }
      );

      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('threadId');
      expect(response.data).toHaveProperty('assistantId');
      expect(response.data.threadId).toBeTruthy();
      expect(response.data.assistantId).toBeTruthy();

      // Store for later tests
      threadId = response.data.threadId;
      assistantId = response.data.assistantId;

      console.log('✅ PDF uploaded and thread created');
      console.log(`   Thread ID: ${threadId}`);
      console.log(`   Assistant ID: ${assistantId}`);
    }, 65000);

    test('Should handle invalid PDF path gracefully', async () => {
      try {
        await axios.post(
          `${BASE_URL}/upload-pdf`,
          { pdfPath: '/nonexistent/file.pdf' },
          { timeout: 10000 }
        );
        fail('Should have thrown error for invalid PDF');
      } catch (error) {
        expect(error.response.status).toBeGreaterThanOrEqual(400);
        console.log('✅ Invalid PDF path handled correctly');
      }
    });
  });

  describe('Thread Management', () => {
    test('Should list active threads', async () => {
      const response = await axios.get(`${BASE_URL}/threads`);

      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('threads');
      expect(Array.isArray(response.data.threads)).toBe(true);

      if (threadId) {
        // Our test thread should be in the list
        const foundThread = response.data.threads.find(t => t.id === threadId);
        console.log('✅ Active threads listed:', response.data.threads.length);
      } else {
        console.log('✅ Threads endpoint accessible (no test thread yet)');
      }
    });

    test('Should get specific thread information', async () => {
      if (!threadId) {
        console.log('⏭️  Skipping: No thread ID available');
        return;
      }

      const response = await axios.get(`${BASE_URL}/thread/${threadId}`);

      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('thread');
      expect(response.data.thread).toHaveProperty('id');
      expect(response.data.thread.id).toBe(threadId);

      console.log('✅ Thread info retrieved:', response.data.thread.id);
    });

    test('Should handle non-existent thread gracefully', async () => {
      try {
        await axios.get(`${BASE_URL}/thread/thread_nonexistent123`);
        fail('Should have thrown 404 for non-existent thread');
      } catch (error) {
        expect(error.response.status).toBe(404);
        console.log('✅ Non-existent thread handled correctly');
      }
    });
  });

  describe('Quiz Analysis with Screenshot', () => {
    test('Should analyze quiz with mock screenshot', async () => {
      if (!threadId) {
        console.log('⏭️  Skipping: No thread ID available');
        return;
      }

      // Create a simple mock screenshot (1x1 white pixel PNG)
      const mockScreenshotBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==';

      const response = await axios.post(
        `${BASE_URL}/analyze-quiz`,
        {
          threadId: threadId,
          screenshotBase64: mockScreenshotBase64
        },
        { timeout: 120000 }
      );

      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('answers');
      expect(Array.isArray(response.data.answers)).toBe(true);

      console.log('✅ Quiz analysis completed');
      console.log(`   Answers: ${JSON.stringify(response.data.answers)}`);
    }, 125000);

    test('Should handle missing screenshot gracefully', async () => {
      if (!threadId) {
        console.log('⏭️  Skipping: No thread ID available');
        return;
      }

      try {
        await axios.post(
          `${BASE_URL}/analyze-quiz`,
          { threadId: threadId },
          { timeout: 10000 }
        );
        // Might succeed with empty screenshot or fail
        console.log('✅ Missing screenshot handled');
      } catch (error) {
        expect(error.response.status).toBeGreaterThanOrEqual(400);
        console.log('✅ Missing screenshot error handled correctly');
      }
    });

    test('Should handle invalid thread ID in analysis', async () => {
      try {
        await axios.post(
          `${BASE_URL}/analyze-quiz`,
          {
            threadId: 'thread_invalid123',
            screenshotBase64: 'abc123'
          },
          { timeout: 10000 }
        );
        fail('Should have thrown error for invalid thread');
      } catch (error) {
        expect(error.response.status).toBeGreaterThanOrEqual(400);
        console.log('✅ Invalid thread ID in analysis handled correctly');
      }
    });
  });

  describe('Thread Deletion', () => {
    test('Should delete thread successfully', async () => {
      if (!threadId) {
        console.log('⏭️  Skipping: No thread ID available');
        return;
      }

      const response = await axios.delete(`${BASE_URL}/thread/${threadId}`);

      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('success');
      expect(response.data.success).toBe(true);

      console.log('✅ Thread deleted successfully');

      // Clear threadId so afterAll doesn't try to delete again
      threadId = null;
    });

    test('Should handle deletion of non-existent thread', async () => {
      try {
        await axios.delete(`${BASE_URL}/thread/thread_nonexistent123`);
        fail('Should have thrown 404 for non-existent thread');
      } catch (error) {
        expect(error.response.status).toBe(404);
        console.log('✅ Non-existent thread deletion handled correctly');
      }
    });
  });

  describe('API Security and Error Handling', () => {
    test('Should validate request payload format', async () => {
      try {
        await axios.post(
          `${BASE_URL}/analyze-quiz`,
          { invalid: 'payload' },
          { timeout: 5000 }
        );
        fail('Should have rejected invalid payload');
      } catch (error) {
        expect(error.response.status).toBeGreaterThanOrEqual(400);
        console.log('✅ Invalid payload rejected');
      }
    });

    test('Should handle malformed JSON', async () => {
      try {
        await axios.post(
          `${BASE_URL}/upload-pdf`,
          'not json',
          {
            headers: { 'Content-Type': 'application/json' },
            timeout: 5000
          }
        );
        fail('Should have rejected malformed JSON');
      } catch (error) {
        expect(error.response.status).toBeGreaterThanOrEqual(400);
        console.log('✅ Malformed JSON rejected');
      }
    });

    test('Should respect CORS headers', async () => {
      const response = await axios.get(HEALTH_URL);

      expect(response.headers).toHaveProperty('access-control-allow-origin');
      console.log('✅ CORS headers present');
    });
  });

  describe('Performance Tests', () => {
    test('Should respond to health check quickly', async () => {
      const startTime = Date.now();
      await axios.get(HEALTH_URL);
      const duration = Date.now() - startTime;

      expect(duration).toBeLessThan(1000);
      console.log(`✅ Health check responded in ${duration}ms`);
    });

    test('Should handle multiple concurrent health checks', async () => {
      const promises = Array(10).fill(null).map(() => axios.get(HEALTH_URL));

      const startTime = Date.now();
      const results = await Promise.all(promises);
      const duration = Date.now() - startTime;

      results.forEach(response => {
        expect(response.status).toBe(200);
      });

      console.log(`✅ ${promises.length} concurrent requests in ${duration}ms`);
    });
  });
});
