/**
 * CDP Client - Chrome DevTools Protocol client for screenshot capture
 */

import CDP from 'chrome-remote-interface';
import { CaptureResult, ChromeTarget, DEFAULT_CONFIG } from './types';

export class CDPClient {
  private readonly debugPort: number;
  private readonly maxRetries: number;
  private readonly retryDelay: number;

  constructor(
    debugPort: number = DEFAULT_CONFIG.chromeDebugPort,
    maxRetries: number = DEFAULT_CONFIG.maxRetries,
    retryDelay: number = DEFAULT_CONFIG.retryDelay
  ) {
    this.debugPort = debugPort;
    this.maxRetries = maxRetries;
    this.retryDelay = retryDelay;
  }

  /**
   * List all available Chrome targets (tabs)
   */
  async listTargets(): Promise<ChromeTarget[]> {
    try {
      const targets = await CDP.List({ port: this.debugPort });
      return targets as ChromeTarget[];
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      throw new Error(`Failed to list Chrome targets: ${errorMessage}`);
    }
  }

  /**
   * Find the active tab (most recently focused non-Chrome page)
   */
  async findActiveTab(): Promise<ChromeTarget | null> {
    const targets = await this.listTargets();

    // Filter out Chrome internal pages and DevTools
    const validTargets = targets.filter(
      (t) =>
        t.type === 'page' &&
        !t.url.startsWith('chrome://') &&
        !t.url.startsWith('chrome-extension://') &&
        !t.url.startsWith('devtools://') &&
        t.url !== 'about:blank'
    );

    if (validTargets.length === 0) {
      return null;
    }

    // Return the first valid target (Chrome's API already sorts by recency)
    return validTargets[0];
  }

  /**
   * Capture full-page screenshot of the active tab with retry logic
   */
  async captureActiveTab(): Promise<CaptureResult> {
    let lastError: Error | null = null;

    for (let attempt = 1; attempt <= this.maxRetries; attempt++) {
      try {
        console.log(`Screenshot capture attempt ${attempt}/${this.maxRetries}...`);
        return await this.performCapture();
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));
        console.error(`Attempt ${attempt} failed:`, lastError.message);

        if (attempt < this.maxRetries) {
          console.log(`Retrying in ${this.retryDelay}ms...`);
          await this.sleep(this.retryDelay);
        }
      }
    }

    throw new Error(
      `Failed to capture screenshot after ${this.maxRetries} attempts: ${lastError?.message}`
    );
  }

  /**
   * Perform the actual screenshot capture using CDP
   */
  private async performCapture(): Promise<CaptureResult> {
    // Step 1: Find active tab
    const activeTab = await this.findActiveTab();

    if (!activeTab) {
      throw new Error('No active tab found. Please open a web page in Chrome.');
    }

    console.log(`Found active tab: ${activeTab.title} (${activeTab.url})`);

    // Step 2: Connect to the tab via CDP
    let client: CDP.Client | null = null;

    try {
      client = await CDP({
        target: activeTab.id,
        port: this.debugPort
      });

      const { Page, Emulation } = client;

      // Step 3: Enable Page domain
      await Page.enable();

      // Step 4: Get full page layout metrics
      const layoutMetrics = await Page.getLayoutMetrics();
      const contentSize = layoutMetrics.cssContentSize || layoutMetrics.contentSize;

      const width = Math.ceil(contentSize.width);
      const height = Math.ceil(contentSize.height);

      console.log(`Page dimensions: ${width}x${height}px`);

      // Step 5: Set device metrics override for full page capture
      // This is critical for captureBeyondViewport to work correctly
      await Emulation.setDeviceMetricsOverride({
        width,
        height,
        deviceScaleFactor: 1,
        mobile: false,
      });

      // Step 6: Capture the full-page screenshot
      // captureBeyondViewport allows capturing content outside the visible viewport
      const screenshot = await Page.captureScreenshot({
        format: 'png',
        captureBeyondViewport: true,
        clip: {
          x: 0,
          y: 0,
          width,
          height,
          scale: 1,
        },
      });

      console.log('✓ Screenshot captured successfully');

      return {
        success: true,
        base64Image: screenshot.data,
        url: activeTab.url,
        title: activeTab.title,
        timestamp: new Date().toISOString(),
        dimensions: {
          width,
          height,
        },
      };

    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      throw new Error(`CDP operation failed: ${errorMessage}`);
    } finally {
      // Always clean up the connection
      if (client) {
        try {
          await client.close();
        } catch (error) {
          console.error('Error closing CDP client:', error);
        }
      }
    }
  }

  /**
   * Test CDP connection without capturing
   */
  async testConnection(): Promise<boolean> {
    try {
      const targets = await this.listTargets();
      return targets.length > 0;
    } catch (error) {
      return false;
    }
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}
