/**
 * Frontend Error Handler Tests
 * Tests for error parsing, classification, and display
 *
 * @group frontend
 * @group error-handler
 */

// Mock window object
global.window = { location: { hostname: 'localhost' }, Notification: undefined };

const config = require('../config.js').default;
const ErrorHandler = require('../error-handler.js').default;
const { ErrorType, ErrorSeverity, ParsedError } = require('../error-handler.js');

describe('Error Handler Tests - Error Parsing', () => {
  describe('String Error Parsing', () => {
    test('should parse CORS error', () => {
      const error = ErrorHandler.parseError('Not allowed by CORS policy');
      expect(error.type).toBe(ErrorType.CORS);
      expect(error.code).toBe('CORS_BLOCKED');
      expect(error.retryable).toBe(false);
    });

    test('should parse AUTH_NO_KEY error', () => {
      const error = ErrorHandler.parseError('AUTH_NO_KEY');
      expect(error.type).toBe(ErrorType.AUTH);
      expect(error.code).toBe('AUTH_NO_KEY');
      expect(error.actionable).toBe(true);
    });

    test('should parse AUTH_INVALID error', () => {
      const error = ErrorHandler.parseError('AUTH_INVALID');
      expect(error.type).toBe(ErrorType.AUTH);
      expect(error.code).toBe('AUTH_INVALID');
      expect(error.retryable).toBe(false);
    });

    test('should parse rate limit error with retry time', () => {
      const error = ErrorHandler.parseError('RATE_LIMIT_EXCEEDED:60');
      expect(error.type).toBe(ErrorType.RATE_LIMIT);
      expect(error.code).toBe('RATE_LIMIT_EXCEEDED');
      expect(error.retryAfter).toBe(60);
      expect(error.retryable).toBe(true);
    });

    test('should parse client rate limit error', () => {
      const error = ErrorHandler.parseError('CLIENT_RATE_LIMIT:30');
      expect(error.type).toBe(ErrorType.RATE_LIMIT);
      expect(error.retryAfter).toBe(30);
    });

    test('should parse network error', () => {
      const error = ErrorHandler.parseError('NETWORK_ERROR');
      expect(error.type).toBe(ErrorType.NETWORK);
      expect(error.code).toBe('NETWORK_ERROR');
      expect(error.retryable).toBe(true);
    });

    test('should parse timeout error', () => {
      const error = ErrorHandler.parseError('TIMEOUT_ERROR');
      expect(error.type).toBe(ErrorType.NETWORK);
      expect(error.code).toBe('TIMEOUT_ERROR');
      expect(error.severity).toBe(ErrorSeverity.WARNING);
    });

    test('should parse HTTP error', () => {
      const error = ErrorHandler.parseError('HTTP_ERROR:500:Internal Server Error');
      expect(error.type).toBe(ErrorType.SERVER);
      expect(error.code).toBe('HTTP_500');
      expect(error.retryable).toBe(true);
    });

    test('should parse HTTP 400 error as non-retryable', () => {
      const error = ErrorHandler.parseError('HTTP_ERROR:400:Bad Request');
      expect(error.type).toBe(ErrorType.SERVER);
      expect(error.code).toBe('HTTP_400');
      expect(error.retryable).toBe(false);
    });
  });

  describe('URL Validation Error Parsing', () => {
    test('should parse invalid protocol error', () => {
      const error = ErrorHandler.parseError('Unsupported protocol: ftp:');
      expect(error.type).toBe(ErrorType.URL_VALIDATION);
      expect(error.code).toBe('URL_INVALID_PROTOCOL');
    });

    test('should parse private IP error', () => {
      const error = ErrorHandler.parseError('Access to private/internal IP addresses');
      expect(error.type).toBe(ErrorType.URL_VALIDATION);
      expect(error.code).toBe('URL_PRIVATE_IP');
    });

    test('should parse domain not whitelisted error', () => {
      const error = ErrorHandler.parseError('Domain not whitelisted: evil.com');
      expect(error.type).toBe(ErrorType.URL_VALIDATION);
      expect(error.code).toBe('URL_NOT_WHITELISTED');
    });

    test('should parse metadata endpoint error', () => {
      const error = ErrorHandler.parseError('Access to cloud metadata services blocked');
      expect(error.type).toBe(ErrorType.URL_VALIDATION);
      expect(error.code).toBe('URL_METADATA_BLOCKED');
    });
  });

  describe('Error Object Parsing', () => {
    test('should parse Error objects', () => {
      const jsError = new Error('AUTH_NO_KEY');
      const parsed = ErrorHandler.parseError(jsError);
      expect(parsed.type).toBe(ErrorType.AUTH);
    });

    test('should handle Error objects with no message', () => {
      const jsError = new Error();
      const parsed = ErrorHandler.parseError(jsError);
      expect(parsed.type).toBe(ErrorType.UNKNOWN);
    });
  });

  describe('Unknown Error Handling', () => {
    test('should handle unknown error types', () => {
      const error = ErrorHandler.parseError('Something completely unknown');
      expect(error.type).toBe(ErrorType.UNKNOWN);
      expect(error.code).toBe('UNKNOWN');
      expect(error.retryable).toBe(true);
    });

    test('should handle null/undefined errors', () => {
      const error = ErrorHandler.parseError(null);
      expect(error.type).toBe(ErrorType.UNKNOWN);
    });

    test('should handle object errors', () => {
      const error = ErrorHandler.parseError({ custom: 'error' });
      expect(error.type).toBe(ErrorType.UNKNOWN);
    });
  });
});

describe('Error Handler Tests - ParsedError Class', () => {
  test('should create ParsedError with all fields', () => {
    const error = new ParsedError({
      type: ErrorType.AUTH,
      severity: ErrorSeverity.ERROR,
      message: 'Test error',
      userMessage: 'User friendly message',
      technicalDetails: 'Technical info',
      retryable: true,
      retryAfter: 60,
      actionable: true,
      actionMessage: 'Try this',
      code: 'TEST_ERROR'
    });

    expect(error.type).toBe(ErrorType.AUTH);
    expect(error.severity).toBe(ErrorSeverity.ERROR);
    expect(error.message).toBe('Test error');
    expect(error.userMessage).toBe('User friendly message');
    expect(error.retryable).toBe(true);
    expect(error.retryAfter).toBe(60);
    expect(error.actionable).toBe(true);
    expect(error.actionMessage).toBe('Try this');
    expect(error.code).toBe('TEST_ERROR');
    expect(error.timestamp).toBeDefined();
  });
});

describe('Error Handler Tests - Error Display', () => {
  let mockContainer;

  beforeEach(() => {
    mockContainer = {
      innerHTML: '',
      style: { display: '' }
    };
  });

  describe('Display Error', () => {
    test('should display error in container', () => {
      ErrorHandler.displayError('AUTH_NO_KEY', mockContainer);
      expect(mockContainer.innerHTML).toContain('API key is missing');
      expect(mockContainer.style.display).toBe('block');
    });

    test('should include action message', () => {
      ErrorHandler.displayError('AUTH_INVALID', mockContainer);
      expect(mockContainer.innerHTML).toContain('Please check your API key');
    });

    test('should show retry button for retryable errors', () => {
      ErrorHandler.displayError('RATE_LIMIT_EXCEEDED:60', mockContainer);
      expect(mockContainer.innerHTML).toContain('Retry');
    });

    test('should not show retry button for non-retryable errors', () => {
      ErrorHandler.displayError('AUTH_NO_KEY', mockContainer);
      expect(mockContainer.innerHTML).not.toContain('retry-button');
    });

    test('should fallback to console when no container', () => {
      console.error = jest.fn();
      console.info = jest.fn();

      ErrorHandler.displayError('AUTH_NO_KEY', null);

      expect(console.error).toHaveBeenCalled();
    });
  });

  describe('Error HTML Creation', () => {
    test('should create error HTML with correct color', () => {
      const error = new ParsedError({
        type: ErrorType.AUTH,
        severity: ErrorSeverity.ERROR,
        message: 'Test',
        userMessage: 'Test error',
        technicalDetails: 'Details',
        retryable: false,
        retryAfter: null,
        actionable: false,
        actionMessage: null,
        code: 'TEST'
      });

      const html = ErrorHandler.createErrorHtml(error);
      expect(html).toContain('#cc0000'); // Error color
      expect(html).toContain('Test error');
    });

    test('should include technical details when enabled', () => {
      config.FEATURES.ENABLE_DETAILED_ERRORS = true;

      const error = new ParsedError({
        type: ErrorType.AUTH,
        severity: ErrorSeverity.ERROR,
        message: 'Test',
        userMessage: 'Test error',
        technicalDetails: 'SECRET_DETAILS',
        retryable: false,
        retryAfter: null,
        actionable: false,
        actionMessage: null,
        code: 'TEST'
      });

      const html = ErrorHandler.createErrorHtml(error);
      expect(html).toContain('SECRET_DETAILS');
      expect(html).toContain('Technical Details');
    });

    test('should not include technical details when disabled', () => {
      config.FEATURES.ENABLE_DETAILED_ERRORS = false;

      const error = new ParsedError({
        type: ErrorType.AUTH,
        severity: ErrorSeverity.ERROR,
        message: 'Test',
        userMessage: 'Test error',
        technicalDetails: 'SECRET_DETAILS',
        retryable: false,
        retryAfter: null,
        actionable: false,
        actionMessage: null,
        code: 'TEST'
      });

      const html = ErrorHandler.createErrorHtml(error);
      expect(html).not.toContain('SECRET_DETAILS');
    });

    test('should show different colors for different severities', () => {
      const severities = [
        { severity: ErrorSeverity.INFO, color: '#0066cc' },
        { severity: ErrorSeverity.WARNING, color: '#ff9900' },
        { severity: ErrorSeverity.ERROR, color: '#cc0000' },
        { severity: ErrorSeverity.CRITICAL, color: '#990000' }
      ];

      severities.forEach(({ severity, color }) => {
        const error = new ParsedError({
          type: ErrorType.UNKNOWN,
          severity,
          message: 'Test',
          userMessage: 'Test',
          technicalDetails: '',
          retryable: false,
          retryAfter: null,
          actionable: false,
          actionMessage: null,
          code: 'TEST'
        });

        const html = ErrorHandler.createErrorHtml(error);
        expect(html).toContain(color);
      });
    });
  });

  describe('Error Icons', () => {
    test('should return correct icons for error types', () => {
      expect(ErrorHandler.getErrorIcon(ErrorType.CORS)).toBe('🚫');
      expect(ErrorHandler.getErrorIcon(ErrorType.AUTH)).toBe('🔐');
      expect(ErrorHandler.getErrorIcon(ErrorType.RATE_LIMIT)).toBe('⏱️');
      expect(ErrorHandler.getErrorIcon(ErrorType.URL_VALIDATION)).toBe('🔗');
      expect(ErrorHandler.getErrorIcon(ErrorType.NETWORK)).toBe('🌐');
      expect(ErrorHandler.getErrorIcon(ErrorType.SERVER)).toBe('⚠️');
      expect(ErrorHandler.getErrorIcon(ErrorType.UNKNOWN)).toBe('❓');
    });

    test('should return default icon for unknown types', () => {
      expect(ErrorHandler.getErrorIcon('INVALID_TYPE')).toBe('❓');
    });
  });
});

describe('Error Handler Tests - API Error Handling', () => {
  beforeEach(() => {
    console.group = jest.fn();
    console.groupEnd = jest.fn();
    console.error = jest.fn();
  });

  test('should handle API errors', () => {
    const error = ErrorHandler.handleApiError('AUTH_NO_KEY');
    expect(error.type).toBe(ErrorType.AUTH);
  });

  test('should log errors when logging enabled', () => {
    config.FEATURES.ENABLE_REQUEST_LOGGING = true;
    ErrorHandler.handleApiError('AUTH_NO_KEY');
    expect(console.error).toHaveBeenCalled();
  });

  test('should not log when logging disabled', () => {
    config.FEATURES.ENABLE_REQUEST_LOGGING = false;
    console.error = jest.fn();
    ErrorHandler.handleApiError('AUTH_NO_KEY');
    expect(console.error).not.toHaveBeenCalled();
  });
});

describe('Error Handler Tests - Utility Functions', () => {
  describe('Get User Message', () => {
    test('should return user-friendly message', () => {
      const message = ErrorHandler.getUserMessage('AUTH_NO_KEY');
      expect(message).toBe(config.ERROR_MESSAGES.AUTH_NO_KEY);
    });

    test('should handle Error objects', () => {
      const message = ErrorHandler.getUserMessage(new Error('AUTH_INVALID'));
      expect(message).toBe(config.ERROR_MESSAGES.AUTH_INVALID);
    });
  });

  describe('Is Retryable', () => {
    test('should return true for retryable errors', () => {
      expect(ErrorHandler.isRetryable('RATE_LIMIT_EXCEEDED:60')).toBe(true);
      expect(ErrorHandler.isRetryable('NETWORK_ERROR')).toBe(true);
      expect(ErrorHandler.isRetryable('HTTP_ERROR:500:Error')).toBe(true);
    });

    test('should return false for non-retryable errors', () => {
      expect(ErrorHandler.isRetryable('AUTH_NO_KEY')).toBe(false);
      expect(ErrorHandler.isRetryable('AUTH_INVALID')).toBe(false);
      expect(ErrorHandler.isRetryable('HTTP_ERROR:400:Bad Request')).toBe(false);
    });
  });

  describe('Get Retry Delay', () => {
    test('should return retry delay from error', () => {
      const delay = ErrorHandler.getRetryDelay('RATE_LIMIT_EXCEEDED:120');
      expect(delay).toBe(120);
    });

    test('should return null for errors without retry delay', () => {
      const delay = ErrorHandler.getRetryDelay('AUTH_NO_KEY');
      expect(delay).toBeNull();
    });
  });

  describe('Clear Errors', () => {
    test('should clear container', () => {
      const container = {
        innerHTML: 'Some error',
        style: { display: 'block' }
      };

      ErrorHandler.clearErrors(container);

      expect(container.innerHTML).toBe('');
      expect(container.style.display).toBe('none');
    });

    test('should handle null container', () => {
      expect(() => ErrorHandler.clearErrors(null)).not.toThrow();
    });
  });
});

describe('Error Handler Tests - Notification Support', () => {
  test('should attempt to show notification when available', () => {
    global.window.Notification = {
      permission: 'granted'
    };
    global.Notification = jest.fn();

    const error = ErrorHandler.showNotification('AUTH_NO_KEY');

    expect(error.type).toBe(ErrorType.AUTH);
  });

  test('should handle missing Notification API', () => {
    delete global.window.Notification;
    delete global.Notification;

    const error = ErrorHandler.showNotification('AUTH_NO_KEY');

    expect(error.type).toBe(ErrorType.AUTH);
  });
});

describe('Error Handler Tests - Error Message Consistency', () => {
  test('should provide consistent user messages', () => {
    const errors = [
      'AUTH_NO_KEY',
      'AUTH_INVALID',
      'RATE_LIMIT_EXCEEDED:60',
      'NETWORK_ERROR',
      'TIMEOUT_ERROR',
      'Not allowed by CORS policy'
    ];

    errors.forEach(errorStr => {
      const parsed = ErrorHandler.parseError(errorStr);
      expect(parsed.userMessage).toBeDefined();
      expect(parsed.userMessage.length).toBeGreaterThan(0);
      expect(typeof parsed.userMessage).toBe('string');
    });
  });

  test('should provide actionable messages where appropriate', () => {
    const actionableErrors = [
      'AUTH_NO_KEY',
      'AUTH_INVALID',
      'RATE_LIMIT_EXCEEDED:60',
      'Domain not whitelisted: evil.com'
    ];

    actionableErrors.forEach(errorStr => {
      const parsed = ErrorHandler.parseError(errorStr);
      expect(parsed.actionable).toBe(true);
      expect(parsed.actionMessage).toBeDefined();
      expect(parsed.actionMessage.length).toBeGreaterThan(0);
    });
  });
});

describe('Error Handler Tests - Error Severity Classification', () => {
  test('should classify errors with appropriate severity', () => {
    const testCases = [
      { error: 'RATE_LIMIT_EXCEEDED:60', expectedSeverity: ErrorSeverity.WARNING },
      { error: 'AUTH_NO_KEY', expectedSeverity: ErrorSeverity.ERROR },
      { error: 'NETWORK_ERROR', expectedSeverity: ErrorSeverity.ERROR },
      { error: 'TIMEOUT_ERROR', expectedSeverity: ErrorSeverity.WARNING }
    ];

    testCases.forEach(({ error, expectedSeverity }) => {
      const parsed = ErrorHandler.parseError(error);
      expect(parsed.severity).toBe(expectedSeverity);
    });
  });
});
