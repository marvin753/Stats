/**
 * Chrome CDP Screenshot Service
 * Port 9223 - HTTP API for silent full-page screenshot capture
 */

import express, { Request, Response } from 'express';
import cors from 'cors';
import { ChromeManager } from './chrome-manager';
import { CDPClient } from './cdp-client';
import { DEFAULT_CONFIG, HealthCheckResponse, ErrorResponse } from './types';

const app = express();
const PORT = DEFAULT_CONFIG.port;

// Initialize Chrome manager and CDP client
const chromeManager = new ChromeManager(DEFAULT_CONFIG.chromeDebugPort);
const cdpClient = new CDPClient(
  DEFAULT_CONFIG.chromeDebugPort,
  DEFAULT_CONFIG.maxRetries,
  DEFAULT_CONFIG.retryDelay
);

// Middleware
app.use(cors());
app.use(express.json());

// Request logging middleware
app.use((req, _res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

/**
 * Health check endpoint
 * GET /health
 */
app.get('/health', async (_req: Request, res: Response<HealthCheckResponse>) => {
  try {
    const isConnected = await cdpClient.testConnection();
    const chromeVersion = isConnected ? await chromeManager.getChromeVersion() : null;

    res.json({
      status: 'ok',
      chrome: isConnected ? 'connected' : 'disconnected',
      port: DEFAULT_CONFIG.chromeDebugPort,
      timestamp: new Date().toISOString(),
      version: chromeVersion?.Browser || undefined,
    });
  } catch (error) {
    res.status(503).json({
      status: 'error',
      chrome: 'disconnected',
      port: DEFAULT_CONFIG.chromeDebugPort,
      timestamp: new Date().toISOString(),
    });
  }
});

/**
 * Capture active tab screenshot
 * POST /capture-active-tab
 */
app.post('/capture-active-tab', async (_req: Request, res: Response) => {
  try {
    console.log('Received screenshot capture request');

    // Ensure Chrome is running with remote debugging
    await chromeManager.ensureChromeRunning();

    // Capture the screenshot
    const result = await cdpClient.captureActiveTab();

    console.log('✓ Screenshot captured and returned successfully');
    res.json(result);

  } catch (error) {
    console.error('Screenshot capture failed:', error);

    const errorMessage = error instanceof Error ? error.message : String(error);
    const errorResponse: ErrorResponse = {
      success: false,
      error: 'Failed to capture screenshot',
      details: errorMessage,
      timestamp: new Date().toISOString(),
    };

    res.status(500).json(errorResponse);
  }
});

/**
 * List all Chrome targets (debug endpoint)
 * GET /targets
 */
app.get('/targets', async (_req: Request, res: Response) => {
  try {
    const targets = await cdpClient.listTargets();
    res.json({
      success: true,
      count: targets.length,
      targets,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    res.status(500).json({
      success: false,
      error: 'Failed to list targets',
      details: errorMessage,
      timestamp: new Date().toISOString(),
    });
  }
});

/**
 * Root endpoint
 */
app.get('/', (_req: Request, res: Response) => {
  res.json({
    service: 'Chrome CDP Screenshot Service',
    version: '1.0.0',
    status: 'running',
    endpoints: {
      health: 'GET /health',
      capture: 'POST /capture-active-tab',
      targets: 'GET /targets',
    },
    timestamp: new Date().toISOString(),
  });
});

/**
 * Error handler
 */
app.use((err: Error, _req: Request, res: Response, _next: any) => {
  console.error('Unhandled error:', err);
  res.status(500).json({
    success: false,
    error: 'Internal server error',
    details: err.message,
    timestamp: new Date().toISOString(),
  });
});

/**
 * Graceful shutdown handlers
 */
const shutdown = async () => {
  console.log('\nReceived shutdown signal');

  try {
    await chromeManager.shutdown();
    process.exit(0);
  } catch (error) {
    console.error('Error during shutdown:', error);
    process.exit(1);
  }
};

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

/**
 * Start the server
 */
const startServer = async () => {
  try {
    console.log('='.repeat(60));
    console.log('Chrome CDP Screenshot Service');
    console.log('='.repeat(60));

    // Ensure Chrome is running before starting the server
    console.log('\nInitializing Chrome with stealth flags...');
    await chromeManager.ensureChromeRunning();

    // Start Express server
    app.listen(PORT, () => {
      console.log('\n' + '='.repeat(60));
      console.log(`✓ Service running on http://localhost:${PORT}`);
      console.log(`✓ Chrome debugging on port ${DEFAULT_CONFIG.chromeDebugPort}`);
      console.log('='.repeat(60));
      console.log('\nAvailable endpoints:');
      console.log(`  GET  http://localhost:${PORT}/health`);
      console.log(`  POST http://localhost:${PORT}/capture-active-tab`);
      console.log(`  GET  http://localhost:${PORT}/targets`);
      console.log('\nTest commands:');
      console.log(`  curl http://localhost:${PORT}/health`);
      console.log(`  curl -X POST http://localhost:${PORT}/capture-active-tab`);
      console.log('\nPress Ctrl+C to stop\n');
    });

  } catch (error) {
    console.error('Failed to start service:', error);
    process.exit(1);
  }
};

// Start the service
startServer();
