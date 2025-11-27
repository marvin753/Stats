/**
 * Chrome Manager - Handles Chrome browser lifecycle with stealth flags
 */

import * as chromeLauncher from 'chrome-launcher';
import { DEFAULT_CONFIG } from './types';

export class ChromeManager {
  private chrome: chromeLauncher.LaunchedChrome | null = null;
  private readonly debugPort: number;

  constructor(debugPort: number = DEFAULT_CONFIG.chromeDebugPort) {
    this.debugPort = debugPort;
  }

  /**
   * Stealth Chrome launch flags - designed to avoid detection
   * Critical: --disable-blink-features=AutomationControlled removes navigator.webdriver
   */
  private getStealthFlags(): string[] {
    return [
      `--remote-debugging-port=${this.debugPort}`,
      '--disable-blink-features=AutomationControlled', // Critical: removes navigator.webdriver
      '--disable-dev-shm-usage',
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-background-networking',
      '--disable-background-timer-throttling',
      '--disable-backgrounding-occluded-windows',
      '--disable-breakpad',
      '--disable-component-extensions-with-background-pages',
      '--disable-extensions',
      '--disable-features=TranslateUI',
      '--disable-ipc-flooding-protection',
      '--disable-renderer-backgrounding',
      '--force-color-profile=srgb',
      '--metrics-recording-only',
      '--no-sandbox',
      '--disable-setuid-sandbox',
      // Use standard Chrome user agent for macOS
      `--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36`,
    ];
  }

  /**
   * Check if Chrome is already running with remote debugging enabled
   */
  async isChromeRunning(): Promise<boolean> {
    try {
      const response = await fetch(`http://localhost:${this.debugPort}/json/version`);
      return response.ok;
    } catch (error) {
      return false;
    }
  }

  /**
   * Launch Chrome with stealth flags if not already running
   */
  async ensureChromeRunning(): Promise<void> {
    const isRunning = await this.isChromeRunning();

    if (isRunning) {
      console.log(`✓ Chrome already running with remote debugging on port ${this.debugPort}`);
      return;
    }

    console.log('Launching Chrome with stealth flags...');

    try {
      this.chrome = await chromeLauncher.launch({
        chromeFlags: this.getStealthFlags(),
        startingUrl: 'about:blank',
        ignoreDefaultFlags: true, // Use only our custom flags
        logLevel: 'silent',
      });

      console.log(`✓ Chrome launched successfully (PID: ${this.chrome.pid})`);
      console.log(`✓ Remote debugging available on port ${this.chrome.port}`);

      // Wait a moment for Chrome to fully initialize
      await this.sleep(2000);

      // Verify connection
      const isConnected = await this.isChromeRunning();
      if (!isConnected) {
        throw new Error('Chrome launched but remote debugging is not responding');
      }

      console.log('✓ Chrome remote debugging verified');

    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      throw new Error(`Failed to launch Chrome: ${errorMessage}`);
    }
  }

  /**
   * Get Chrome version and debugging info
   */
  async getChromeVersion(): Promise<any> {
    try {
      const response = await fetch(`http://localhost:${this.debugPort}/json/version`);
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      return await response.json();
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      throw new Error(`Failed to get Chrome version: ${errorMessage}`);
    }
  }

  /**
   * Kill the Chrome instance if we launched it
   */
  async killChrome(): Promise<void> {
    if (this.chrome) {
      try {
        await this.chrome.kill();
        console.log('✓ Chrome instance terminated');
        this.chrome = null;
      } catch (error) {
        console.error('Error killing Chrome:', error);
      }
    }
  }

  /**
   * Graceful shutdown handler
   */
  async shutdown(): Promise<void> {
    console.log('Shutting down Chrome manager...');
    await this.killChrome();
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}
