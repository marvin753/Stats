/**
 * Error Handler Module
 * Centralized error handling for all security and API errors:
 * - CORS errors
 * - Authentication errors (401, 403)
 * - Rate limiting errors (429)
 * - URL validation errors
 * - Network errors
 *
 * @module error-handler
 * @version 2.0.0
 */

import config from './config.js';

/**
 * Error Types Enumeration
 */
const ErrorType = {
  CORS: 'CORS',
  AUTH: 'AUTH',
  RATE_LIMIT: 'RATE_LIMIT',
  URL_VALIDATION: 'URL_VALIDATION',
  NETWORK: 'NETWORK',
  SERVER: 'SERVER',
  UNKNOWN: 'UNKNOWN'
};

/**
 * Error Severity Levels
 */
const ErrorSeverity = {
  INFO: 'info',
  WARNING: 'warning',
  ERROR: 'error',
  CRITICAL: 'critical'
};

/**
 * Parsed Error Object
 */
class ParsedError {
  constructor({
    type,
    severity,
    message,
    userMessage,
    technicalDetails,
    retryable,
    retryAfter,
    actionable,
    actionMessage,
    code
  }) {
    this.type = type;
    this.severity = severity;
    this.message = message;
    this.userMessage = userMessage;
    this.technicalDetails = technicalDetails;
    this.retryable = retryable;
    this.retryAfter = retryAfter;
    this.actionable = actionable;
    this.actionMessage = actionMessage;
    this.code = code;
    this.timestamp = new Date().toISOString();
  }
}

/**
 * Error Handler Class
 */
class ErrorHandler {
  /**
   * Parse error object and return standardized error
   */
  static parseError(error) {
    // Handle string errors
    if (typeof error === 'string') {
      return this.parseErrorString(error);
    }

    // Handle Error objects
    if (error instanceof Error) {
      return this.parseErrorObject(error);
    }

    // Handle unknown error types
    return new ParsedError({
      type: ErrorType.UNKNOWN,
      severity: ErrorSeverity.ERROR,
      message: 'Unknown error occurred',
      userMessage: config.ERROR_MESSAGES.UNKNOWN_ERROR,
      technicalDetails: JSON.stringify(error),
      retryable: true,
      retryAfter: null,
      actionable: false,
      actionMessage: null,
      code: 'UNKNOWN'
    });
  }

  /**
   * Parse error string (custom error codes)
   */
  static parseErrorString(errorString) {
    // CORS Errors
    if (errorString.includes('CORS') || errorString.includes('Not allowed by CORS')) {
      return new ParsedError({
        type: ErrorType.CORS,
        severity: ErrorSeverity.ERROR,
        message: 'CORS policy violation',
        userMessage: config.ERROR_MESSAGES.CORS_BLOCKED,
        technicalDetails: errorString,
        retryable: false,
        retryAfter: null,
        actionable: true,
        actionMessage: config.ERROR_MESSAGES.CORS_HELP,
        code: 'CORS_BLOCKED'
      });
    }

    // Authentication Errors
    if (errorString.includes('AUTH_NO_KEY')) {
      return new ParsedError({
        type: ErrorType.AUTH,
        severity: ErrorSeverity.ERROR,
        message: 'API key missing',
        userMessage: config.ERROR_MESSAGES.AUTH_NO_KEY,
        technicalDetails: errorString,
        retryable: false,
        retryAfter: null,
        actionable: true,
        actionMessage: 'Please configure your API key in the settings.',
        code: 'AUTH_NO_KEY'
      });
    }

    if (errorString.includes('AUTH_INVALID')) {
      return new ParsedError({
        type: ErrorType.AUTH,
        severity: ErrorSeverity.ERROR,
        message: 'Invalid API key',
        userMessage: config.ERROR_MESSAGES.AUTH_INVALID,
        technicalDetails: errorString,
        retryable: false,
        retryAfter: null,
        actionable: true,
        actionMessage: 'Please check your API key and try again.',
        code: 'AUTH_INVALID'
      });
    }

    // Rate Limit Errors
    if (errorString.includes('RATE_LIMIT_EXCEEDED') || errorString.includes('CLIENT_RATE_LIMIT')) {
      const retryMatch = errorString.match(/:(\d+)$/);
      const retryAfter = retryMatch ? parseInt(retryMatch[1]) : null;

      return new ParsedError({
        type: ErrorType.RATE_LIMIT,
        severity: ErrorSeverity.WARNING,
        message: 'Rate limit exceeded',
        userMessage: errorString.includes('CLIENT_RATE_LIMIT')
          ? config.ERROR_MESSAGES.RATE_LIMIT_ANALYSIS
          : config.ERROR_MESSAGES.RATE_LIMIT_GENERAL,
        technicalDetails: errorString,
        retryable: true,
        retryAfter,
        actionable: true,
        actionMessage: retryAfter
          ? `Please wait ${retryAfter} seconds before trying again.`
          : config.ERROR_MESSAGES.RATE_LIMIT_HELP,
        code: 'RATE_LIMIT_EXCEEDED'
      });
    }

    // URL Validation Errors
    if (errorString.includes('URL') || errorString.includes('Domain') || errorString.includes('protocol')) {
      return this.parseUrlValidationError(errorString);
    }

    // Network Errors
    if (errorString.includes('NETWORK_ERROR') || errorString.includes('fetch')) {
      return new ParsedError({
        type: ErrorType.NETWORK,
        severity: ErrorSeverity.ERROR,
        message: 'Network error',
        userMessage: config.ERROR_MESSAGES.NETWORK_ERROR,
        technicalDetails: errorString,
        retryable: true,
        retryAfter: null,
        actionable: true,
        actionMessage: 'Please check your internet connection and try again.',
        code: 'NETWORK_ERROR'
      });
    }

    // Timeout Errors
    if (errorString.includes('TIMEOUT_ERROR') || errorString.includes('timeout')) {
      return new ParsedError({
        type: ErrorType.NETWORK,
        severity: ErrorSeverity.WARNING,
        message: 'Request timeout',
        userMessage: config.ERROR_MESSAGES.TIMEOUT_ERROR,
        technicalDetails: errorString,
        retryable: true,
        retryAfter: null,
        actionable: true,
        actionMessage: 'The server is taking longer than expected. Please try again.',
        code: 'TIMEOUT_ERROR'
      });
    }

    // HTTP Errors
    if (errorString.includes('HTTP_ERROR')) {
      const parts = errorString.split(':');
      const statusCode = parts[1];
      const message = parts.slice(2).join(':');

      return new ParsedError({
        type: ErrorType.SERVER,
        severity: ErrorSeverity.ERROR,
        message: `HTTP ${statusCode} Error`,
        userMessage: config.ERROR_MESSAGES.SERVER_ERROR,
        technicalDetails: message,
        retryable: parseInt(statusCode) >= 500,
        retryAfter: null,
        actionable: true,
        actionMessage: parseInt(statusCode) >= 500
          ? 'The server is experiencing issues. Please try again later.'
          : 'Please check your request and try again.',
        code: `HTTP_${statusCode}`
      });
    }

    // Default
    return new ParsedError({
      type: ErrorType.UNKNOWN,
      severity: ErrorSeverity.ERROR,
      message: errorString,
      userMessage: config.ERROR_MESSAGES.UNKNOWN_ERROR,
      technicalDetails: errorString,
      retryable: true,
      retryAfter: null,
      actionable: false,
      actionMessage: null,
      code: 'UNKNOWN'
    });
  }

  /**
   * Parse Error object
   */
  static parseErrorObject(error) {
    return this.parseErrorString(error.message || error.toString());
  }

  /**
   * Parse URL validation errors
   */
  static parseUrlValidationError(errorString) {
    let userMessage = config.ERROR_MESSAGES.URL_INVALID_FORMAT;
    let actionMessage = 'Please enter a valid URL starting with http:// or https://';
    let code = 'URL_INVALID';

    if (errorString.includes('protocol') || errorString.includes('Unsupported protocol')) {
      userMessage = config.ERROR_MESSAGES.URL_INVALID_PROTOCOL;
      actionMessage = 'Only HTTP and HTTPS URLs are supported.';
      code = 'URL_INVALID_PROTOCOL';
    } else if (errorString.includes('private') || errorString.includes('internal')) {
      userMessage = config.ERROR_MESSAGES.URL_PRIVATE_IP;
      actionMessage = 'Access to private IP addresses and internal networks is blocked for security.';
      code = 'URL_PRIVATE_IP';
    } else if (errorString.includes('not whitelisted') || errorString.includes('Domain not whitelisted')) {
      userMessage = config.ERROR_MESSAGES.URL_NOT_WHITELISTED;
      actionMessage = `Allowed domains: ${config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS.join(', ')}`;
      code = 'URL_NOT_WHITELISTED';
    } else if (errorString.includes('metadata')) {
      userMessage = config.ERROR_MESSAGES.URL_BLOCKED_METADATA;
      actionMessage = 'Access to cloud metadata services is blocked for security reasons.';
      code = 'URL_METADATA_BLOCKED';
    }

    return new ParsedError({
      type: ErrorType.URL_VALIDATION,
      severity: ErrorSeverity.ERROR,
      message: 'URL validation failed',
      userMessage,
      technicalDetails: errorString,
      retryable: false,
      retryAfter: null,
      actionable: true,
      actionMessage,
      code
    });
  }

  /**
   * Handle API error and return parsed error
   */
  static handleApiError(error) {
    const parsedError = this.parseError(error);

    // Log error if logging is enabled
    if (config.FEATURES.ENABLE_REQUEST_LOGGING) {
      console.group('[Error Handler]');
      console.error('Type:', parsedError.type);
      console.error('Severity:', parsedError.severity);
      console.error('Code:', parsedError.code);
      console.error('Message:', parsedError.message);
      console.error('User Message:', parsedError.userMessage);
      if (config.FEATURES.ENABLE_DETAILED_ERRORS) {
        console.error('Technical Details:', parsedError.technicalDetails);
      }
      console.groupEnd();
    }

    return parsedError;
  }

  /**
   * Display error to user
   * Can be customized based on UI framework
   */
  static displayError(error, containerElement = null) {
    const parsedError = this.parseError(error);

    // Create error UI
    const errorHtml = this.createErrorHtml(parsedError);

    if (containerElement) {
      containerElement.innerHTML = errorHtml;
      containerElement.style.display = 'block';
    } else {
      // Fallback: Use alert or console
      console.error(parsedError.userMessage);
      if (parsedError.actionMessage) {
        console.info(parsedError.actionMessage);
      }
    }

    return parsedError;
  }

  /**
   * Create HTML for error display
   */
  static createErrorHtml(parsedError) {
    const severityColors = {
      info: '#0066cc',
      warning: '#ff9900',
      error: '#cc0000',
      critical: '#990000'
    };

    const color = severityColors[parsedError.severity];
    const icon = this.getErrorIcon(parsedError.type);

    return `
      <div class="error-container" style="
        border: 2px solid ${color};
        background-color: ${color}10;
        border-radius: 8px;
        padding: 16px;
        margin: 16px 0;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      ">
        <div style="display: flex; align-items: flex-start; gap: 12px;">
          <div style="font-size: 24px;">${icon}</div>
          <div style="flex: 1;">
            <div style="font-weight: 600; color: ${color}; margin-bottom: 8px;">
              ${parsedError.userMessage}
            </div>
            ${parsedError.actionMessage ? `
              <div style="color: #555; font-size: 14px; margin-bottom: 12px;">
                ${parsedError.actionMessage}
              </div>
            ` : ''}
            ${parsedError.retryable ? `
              <button class="retry-button" style="
                background-color: ${color};
                color: white;
                border: none;
                border-radius: 4px;
                padding: 8px 16px;
                cursor: pointer;
                font-size: 14px;
                font-weight: 500;
              ">
                ${parsedError.retryAfter ? `Retry in ${parsedError.retryAfter}s` : 'Retry'}
              </button>
            ` : ''}
            ${config.FEATURES.ENABLE_DETAILED_ERRORS ? `
              <details style="margin-top: 12px;">
                <summary style="cursor: pointer; color: #666; font-size: 12px;">
                  Technical Details
                </summary>
                <pre style="
                  margin-top: 8px;
                  padding: 8px;
                  background: #f5f5f5;
                  border-radius: 4px;
                  font-size: 11px;
                  overflow-x: auto;
                ">${parsedError.technicalDetails}</pre>
              </details>
            ` : ''}
          </div>
        </div>
      </div>
    `;
  }

  /**
   * Get emoji icon for error type
   */
  static getErrorIcon(errorType) {
    const icons = {
      [ErrorType.CORS]: '🚫',
      [ErrorType.AUTH]: '🔐',
      [ErrorType.RATE_LIMIT]: '⏱️',
      [ErrorType.URL_VALIDATION]: '🔗',
      [ErrorType.NETWORK]: '🌐',
      [ErrorType.SERVER]: '⚠️',
      [ErrorType.UNKNOWN]: '❓'
    };
    return icons[errorType] || '❓';
  }

  /**
   * Create notification (can be integrated with notification library)
   */
  static showNotification(error, options = {}) {
    const parsedError = this.parseError(error);

    // Use browser notification API if available
    if ('Notification' in window && Notification.permission === 'granted') {
      new Notification('Quiz Analysis Error', {
        body: parsedError.userMessage,
        icon: '/icon.png',
        badge: '/badge.png'
      });
    }

    // Return parsed error for further handling
    return parsedError;
  }

  /**
   * Clear errors from container
   */
  static clearErrors(containerElement) {
    if (containerElement) {
      containerElement.innerHTML = '';
      containerElement.style.display = 'none';
    }
  }

  /**
   * Get user-friendly error message
   */
  static getUserMessage(error) {
    const parsedError = this.parseError(error);
    return parsedError.userMessage;
  }

  /**
   * Check if error is retryable
   */
  static isRetryable(error) {
    const parsedError = this.parseError(error);
    return parsedError.retryable;
  }

  /**
   * Get retry delay for error
   */
  static getRetryDelay(error) {
    const parsedError = this.parseError(error);
    return parsedError.retryAfter;
  }
}

// Export
export default ErrorHandler;
export { ErrorType, ErrorSeverity, ParsedError };
