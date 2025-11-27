/**
 * Integration Tests: Chrome CDP Service
 * Tests full-page screenshot capture and CDP functionality
 */

const axios = require('axios');
const { chromium } = require('playwright');

describe('Chrome CDP Service Integration Tests', () => {
  let browser, page;
  const CDP_URL = 'http://localhost:9223';

  beforeAll(async () => {
    console.log('🚀 Starting Chrome CDP Service tests...');

    // Launch Chrome browser for testing
    browser = await chromium.launch({
      headless: false,
      args: [
        '--remote-debugging-port=9222',
        '--disable-blink-features=AutomationControlled'
      ]
    });

    const context = await browser.newContext({
      viewport: { width: 1920, height: 1080 }
    });

    page = await context.newPage();
    console.log('✅ Chrome browser launched');
  });

  afterAll(async () => {
    if (browser) {
      await browser.close();
      console.log('🛑 Chrome browser closed');
    }
  });

  describe('Health Check', () => {
    test('Should respond with status OK', async () => {
      const response = await axios.get(`${CDP_URL}/health`);

      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('status');
      expect(response.data.status).toBe('ok');
      expect(response.data).toHaveProperty('chrome');

      console.log('✅ Health check passed:', response.data);
    });

    test('Should report Chrome connection status', async () => {
      const response = await axios.get(`${CDP_URL}/health`);

      expect(response.data.chrome).toBeDefined();
      expect(['connected', 'available', 'ready']).toContain(
        response.data.chrome.toLowerCase()
      );
    });
  });

  describe('Full-Page Screenshot Capture', () => {
    test('Should capture screenshot of simple page', async () => {
      // Navigate to a simple test page
      await page.goto('data:text/html,<h1>Test Page</h1><p>Simple content</p>');
      await page.waitForTimeout(1000);

      const response = await axios.post(`${CDP_URL}/capture-active-tab`);

      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('success');
      expect(response.data.success).toBe(true);
      expect(response.data).toHaveProperty('base64Image');
      expect(response.data.base64Image).toBeTruthy();
      expect(response.data.base64Image.length).toBeGreaterThan(1000);

      console.log('✅ Simple page screenshot captured');
    });

    test('Should capture full-page screenshot with scroll', async () => {
      // Create a long page that requires scrolling
      const longHtml = `
        <!DOCTYPE html>
        <html>
        <head><title>Long Page Test</title></head>
        <body>
          <h1>Long Page Test</h1>
          <div style="height: 3000px; background: linear-gradient(to bottom, #fff 0%, #000 100%);">
            <p style="padding: 50px;">This page is very long and requires scrolling</p>
          </div>
        </body>
        </html>
      `;

      await page.goto(`data:text/html,${encodeURIComponent(longHtml)}`);
      await page.waitForTimeout(1000);

      const response = await axios.post(`${CDP_URL}/capture-active-tab`);

      expect(response.status).toBe(200);
      expect(response.data.success).toBe(true);
      expect(response.data).toHaveProperty('dimensions');

      // Full-page screenshot should be taller than viewport
      if (response.data.dimensions) {
        expect(response.data.dimensions.height).toBeGreaterThan(1080);
        console.log('✅ Full-page screenshot dimensions:', response.data.dimensions);
      }
    });

    test('Should include page URL in response', async () => {
      await page.goto('https://example.com');
      await page.waitForTimeout(2000);

      const response = await axios.post(`${CDP_URL}/capture-active-tab`);

      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('url');
      expect(response.data.url).toContain('example.com');

      console.log('✅ Screenshot includes URL:', response.data.url);
    });
  });

  describe('Screenshot Quality Validation', () => {
    test('Should return valid PNG image data', async () => {
      await page.goto('data:text/html,<h1>PNG Test</h1>');
      await page.waitForTimeout(500);

      const response = await axios.post(`${CDP_URL}/capture-active-tab`);
      const base64 = response.data.base64Image;

      // Decode base64 to buffer
      const buffer = Buffer.from(base64, 'base64');

      // Check PNG magic number (89 50 4E 47)
      expect(buffer[0]).toBe(0x89);
      expect(buffer[1]).toBe(0x50); // 'P'
      expect(buffer[2]).toBe(0x4E); // 'N'
      expect(buffer[3]).toBe(0x47); // 'G'

      console.log('✅ Valid PNG format confirmed');
      console.log(`   Image size: ${(buffer.length / 1024).toFixed(2)} KB`);
    });

    test('Should capture high-quality screenshots', async () => {
      await page.goto('https://example.com');
      await page.waitForTimeout(2000);

      const response = await axios.post(`${CDP_URL}/capture-active-tab`);
      const buffer = Buffer.from(response.data.base64Image, 'base64');

      // High-quality screenshots should be reasonably large
      const sizeKB = buffer.length / 1024;
      expect(sizeKB).toBeGreaterThan(10);

      console.log(`✅ Screenshot quality check passed: ${sizeKB.toFixed(2)} KB`);
    });
  });

  describe('Error Handling', () => {
    test('Should handle invalid endpoint gracefully', async () => {
      try {
        await axios.get(`${CDP_URL}/invalid-endpoint`);
        fail('Should have thrown 404 error');
      } catch (error) {
        expect(error.response.status).toBe(404);
        console.log('✅ Invalid endpoint handled correctly');
      }
    });

    test('Should handle capture with no active tab', async () => {
      // Close all pages
      const pages = await browser.contexts()[0].pages();
      for (const p of pages) {
        await p.close();
      }

      try {
        await axios.post(`${CDP_URL}/capture-active-tab`);
        // If it succeeds, it should still return valid response
        console.log('✅ Capture attempted with no tabs');
      } catch (error) {
        // Or it should return appropriate error
        expect([404, 500]).toContain(error.response.status);
        console.log('✅ No active tab error handled correctly');
      }

      // Recreate page for next tests
      page = await browser.contexts()[0].newPage();
    });
  });

  describe('Performance Tests', () => {
    test('Should capture screenshot within 5 seconds', async () => {
      await page.goto('https://example.com');
      await page.waitForTimeout(2000);

      const startTime = Date.now();
      const response = await axios.post(`${CDP_URL}/capture-active-tab`);
      const duration = Date.now() - startTime;

      expect(response.status).toBe(200);
      expect(duration).toBeLessThan(5000);

      console.log(`✅ Screenshot captured in ${duration}ms`);
    });

    test('Should handle concurrent requests', async () => {
      await page.goto('data:text/html,<h1>Concurrent Test</h1>');
      await page.waitForTimeout(500);

      const promises = [
        axios.post(`${CDP_URL}/capture-active-tab`),
        axios.post(`${CDP_URL}/capture-active-tab`),
        axios.post(`${CDP_URL}/capture-active-tab`)
      ];

      const results = await Promise.all(promises);

      results.forEach((response, index) => {
        expect(response.status).toBe(200);
        expect(response.data.success).toBe(true);
      });

      console.log('✅ Concurrent requests handled successfully');
    });
  });
});
