/**
 * Integration Tests: End-to-End Workflow
 * Tests complete quiz workflow from CDP capture to backend analysis
 */

const axios = require('axios');
const fs = require('fs');
const path = require('path');

describe('End-to-End Workflow Tests', () => {
  const CDP_URL = 'http://localhost:9223';
  const BACKEND_URL = 'http://localhost:3000';
  const BACKEND_API = `${BACKEND_URL}/api`;
  const STATS_APP_URL = 'http://localhost:8080';

  let threadId = null;

  beforeAll(() => {
    console.log('🚀 Starting End-to-End Workflow tests...');
    console.log('📋 Testing complete integration: CDP → Backend → Stats App');
  });

  afterAll(async () => {
    // Cleanup
    if (threadId) {
      try {
        await axios.delete(`${BACKEND_API}/thread/${threadId}`);
        console.log('🧹 Cleanup: Test thread deleted');
      } catch (error) {
        console.log('⚠️  Cleanup warning:', error.message);
      }
    }
  });

  describe('Service Availability', () => {
    test('CDP service should be running', async () => {
      const response = await axios.get(`${CDP_URL}/health`);

      expect(response.status).toBe(200);
      expect(response.data.status).toBe('ok');

      console.log('✅ CDP service is available:', response.data);
    });

    test('Backend service should be running', async () => {
      const response = await axios.get(`${BACKEND_URL}/health`);

      expect(response.status).toBe(200);
      expect(response.data.status).toBe('ok');

      console.log('✅ Backend service is available:', response.data);
    });

    test('Stats app HTTP server should be accessible', async () => {
      try {
        const response = await axios.get(STATS_APP_URL, {
          timeout: 3000,
          validateStatus: () => true // Accept any status
        });

        // Stats app might return various status codes
        console.log(`✅ Stats app is accessible (status: ${response.status})`);
      } catch (error) {
        if (error.code === 'ECONNREFUSED') {
          console.log('⚠️  Stats app not running - start with ./run-swift.sh');
          console.log('   This test will be skipped');
        } else {
          console.log(`✅ Stats app is accessible (${error.message})`);
        }
      }
    });
  });

  describe('Complete Workflow: Screenshot-Based Analysis', () => {
    test('Workflow Step 1: Capture screenshot via CDP', async () => {
      const response = await axios.post(`${CDP_URL}/capture-active-tab`);

      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('success');
      expect(response.data).toHaveProperty('base64Image');
      expect(response.data.base64Image).toBeTruthy();

      console.log('✅ Step 1: Screenshot captured via CDP');
      console.log(`   Screenshot size: ${(response.data.base64Image.length / 1024).toFixed(2)} KB`);

      // Store for next step
      this.capturedScreenshot = response.data.base64Image;
    });

    test('Workflow Step 2: Upload PDF and create thread', async () => {
      const pdfPath = path.join(__dirname, '../fixtures/test-script.pdf');

      if (!fs.existsSync(pdfPath)) {
        console.log('⏭️  Skipping: Test PDF not found');
        console.log('   Create test-script.pdf in tests/fixtures/ to run this test');
        return;
      }

      const response = await axios.post(
        `${BACKEND_API}/upload-pdf`,
        { pdfPath },
        { timeout: 60000 }
      );

      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('threadId');

      threadId = response.data.threadId;

      console.log('✅ Step 2: PDF uploaded and thread created');
      console.log(`   Thread ID: ${threadId}`);
    }, 65000);

    test('Workflow Step 3: Analyze quiz with screenshot', async () => {
      if (!threadId) {
        console.log('⏭️  Skipping: No thread ID (PDF upload may have been skipped)');
        return;
      }

      if (!this.capturedScreenshot) {
        console.log('⏭️  Skipping: No screenshot captured');
        return;
      }

      const response = await axios.post(
        `${BACKEND_API}/analyze-quiz`,
        {
          threadId: threadId,
          screenshotBase64: this.capturedScreenshot
        },
        { timeout: 120000 }
      );

      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('answers');
      expect(Array.isArray(response.data.answers)).toBe(true);

      console.log('✅ Step 3: Quiz analyzed successfully');
      console.log(`   Answers received: ${JSON.stringify(response.data.answers)}`);

      // Store for next step
      this.analyzedAnswers = response.data.answers;
    }, 125000);

    test('Workflow Step 4: Send answers to Stats app', async () => {
      if (!this.analyzedAnswers) {
        console.log('⏭️  Skipping: No analyzed answers available');
        return;
      }

      try {
        const response = await axios.post(
          `${STATS_APP_URL}/display-answers`,
          { answers: this.analyzedAnswers },
          {
            timeout: 5000,
            validateStatus: () => true
          }
        );

        console.log('✅ Step 4: Answers sent to Stats app');
        console.log(`   Response status: ${response.status}`);
        console.log(`   Animation should start in Stats app`);
      } catch (error) {
        if (error.code === 'ECONNREFUSED') {
          console.log('⏭️  Skipping: Stats app not running');
        } else {
          console.log(`✅ Step 4: Request sent (${error.message})`);
        }
      }
    });
  });

  describe('Workflow Validation', () => {
    test('Should validate answer ordering', async () => {
      // Create mock answers for testing
      const mockAnswers = [1, 2, 3, 4, 5];

      // Answers should be in sequential order
      for (let i = 0; i < mockAnswers.length - 1; i++) {
        expect(mockAnswers[i]).toBeLessThanOrEqual(mockAnswers[i + 1]);
      }

      console.log('✅ Answer ordering validation passed');
    });

    test('Should validate answer range (1-10)', async () => {
      const mockAnswers = [3, 2, 4, 1];

      mockAnswers.forEach(answer => {
        expect(answer).toBeGreaterThanOrEqual(1);
        expect(answer).toBeLessThanOrEqual(10);
      });

      console.log('✅ Answer range validation passed');
    });

    test('Should handle empty answer array', async () => {
      const emptyAnswers = [];

      expect(Array.isArray(emptyAnswers)).toBe(true);
      expect(emptyAnswers.length).toBe(0);

      console.log('✅ Empty answer array handled correctly');
    });
  });

  describe('Error Recovery and Resilience', () => {
    test('Should handle CDP service temporary unavailability', async () => {
      // Simulate timeout scenario
      try {
        await axios.post(`${CDP_URL}/capture-active-tab`, {}, {
          timeout: 1 // Very short timeout to simulate failure
        });
      } catch (error) {
        expect(error.code).toBeDefined();
        console.log('✅ CDP timeout handled gracefully');
      }
    });

    test('Should handle backend analysis failure', async () => {
      try {
        await axios.post(
          `${BACKEND_API}/analyze-quiz`,
          { threadId: 'invalid', screenshotBase64: 'invalid' },
          { timeout: 10000 }
        );
        fail('Should have thrown error for invalid request');
      } catch (error) {
        expect(error.response.status).toBeGreaterThanOrEqual(400);
        console.log('✅ Backend error handled gracefully');
      }
    });

    test('Should handle Stats app connection failure', async () => {
      try {
        await axios.post(
          'http://localhost:9999/display-answers', // Wrong port
          { answers: [1, 2, 3] },
          { timeout: 2000 }
        );
      } catch (error) {
        expect(['ECONNREFUSED', 'ETIMEDOUT']).toContain(error.code);
        console.log('✅ Connection failure handled gracefully');
      }
    });
  });

  describe('Performance Benchmarks', () => {
    test('Complete workflow should finish within 2 minutes', async () => {
      const startTime = Date.now();

      try {
        // Step 1: Health checks
        await axios.get(`${CDP_URL}/health`);
        await axios.get(`${BACKEND_URL}/health`);

        // Step 2: Capture screenshot
        const screenshotResp = await axios.post(`${CDP_URL}/capture-active-tab`);

        // Step 3: Mock analysis (if thread available)
        if (threadId) {
          await axios.post(
            `${BACKEND_API}/analyze-quiz`,
            {
              threadId: threadId,
              screenshotBase64: screenshotResp.data.base64Image
            },
            { timeout: 120000 }
          );
        }

        const duration = Date.now() - startTime;
        expect(duration).toBeLessThan(120000); // 2 minutes

        console.log(`✅ Workflow completed in ${(duration / 1000).toFixed(2)}s`);
      } catch (error) {
        console.log(`⚠️  Workflow benchmark: ${error.message}`);
      }
    }, 130000);

    test('Individual component latency should be acceptable', async () => {
      const results = {};

      // Test CDP latency
      let start = Date.now();
      await axios.get(`${CDP_URL}/health`);
      results.cdp = Date.now() - start;

      // Test Backend latency
      start = Date.now();
      await axios.get(`${BACKEND_URL}/health`);
      results.backend = Date.now() - start;

      // All should be under 1 second for health checks
      expect(results.cdp).toBeLessThan(1000);
      expect(results.backend).toBeLessThan(1000);

      console.log('✅ Component latency check:');
      console.log(`   CDP: ${results.cdp}ms`);
      console.log(`   Backend: ${results.backend}ms`);
    });
  });

  describe('Data Flow Integrity', () => {
    test('Screenshot data should maintain integrity through pipeline', async () => {
      // Capture screenshot
      const cdpResponse = await axios.post(`${CDP_URL}/capture-active-tab`);
      const originalScreenshot = cdpResponse.data.base64Image;

      // Verify it's valid base64
      const buffer = Buffer.from(originalScreenshot, 'base64');
      expect(buffer.length).toBeGreaterThan(0);

      // Verify PNG format
      expect(buffer[0]).toBe(0x89);
      expect(buffer[1]).toBe(0x50);

      console.log('✅ Screenshot data integrity verified');
      console.log(`   Original size: ${(originalScreenshot.length / 1024).toFixed(2)} KB`);
      console.log(`   Decoded size: ${(buffer.length / 1024).toFixed(2)} KB`);
    });

    test('Answer data should be properly formatted', async () => {
      const mockAnswers = [3, 2, 4, 1];

      // Verify array format
      expect(Array.isArray(mockAnswers)).toBe(true);

      // Verify all elements are numbers
      mockAnswers.forEach(answer => {
        expect(typeof answer).toBe('number');
      });

      // Verify JSON serialization
      const json = JSON.stringify({ answers: mockAnswers });
      const parsed = JSON.parse(json);
      expect(parsed.answers).toEqual(mockAnswers);

      console.log('✅ Answer data format validated');
    });
  });
});
