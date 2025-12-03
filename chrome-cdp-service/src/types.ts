/**
 * Type definitions for Chrome CDP Screenshot Service
 */

export interface CaptureResult {
  success: boolean;
  base64Image: string;
  url: string;
  title: string;
  timestamp: string;
  dimensions?: {
    width: number;
    height: number;
  };
}

export interface HealthCheckResponse {
  status: 'ok' | 'error';
  chrome: 'connected' | 'disconnected' | 'launching';
  port: number;
  timestamp: string;
  version?: string;
}

export interface ErrorResponse {
  success: false;
  error: string;
  details?: string;
  timestamp: string;
}

export interface ChromeTarget {
  id: string;
  type: string;
  title: string;
  url: string;
  description?: string;
  devtoolsFrontendUrl?: string;
  webSocketDebuggerUrl?: string;
}

export interface ServiceConfig {
  port: number;
  chromeDebugPort: number;
  stealthMode: boolean;
  maxRetries: number;
  retryDelay: number;
}

export const DEFAULT_CONFIG: ServiceConfig = {
  port: 9223,
  chromeDebugPort: 9222,
  stealthMode: true,
  maxRetries: 3,
  retryDelay: 1000,
};
