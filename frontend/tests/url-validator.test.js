/**
 * Frontend URL Validator Tests
 * Tests for URL validation including SSRF protection, whitelist, and protocol validation
 *
 * @group frontend
 * @group url-validator
 */

// Mock window object
global.window = { location: { hostname: 'localhost' } };

const config = require('../config.js').default;
const UrlValidator = require('../url-validator.js').default;
const { ValidationResult } = require('../url-validator.js');

describe('URL Validator Tests - Basic Validation', () => {
  describe('Empty/Invalid Input', () => {
    test('should reject empty string', () => {
      const result = UrlValidator.validate('');
      expect(result.isValid).toBe(false);
      expect(result.errors[0].code).toBe('URL_EMPTY');
    });

    test('should reject null', () => {
      const result = UrlValidator.validate(null);
      expect(result.isValid).toBe(false);
    });

    test('should reject undefined', () => {
      const result = UrlValidator.validate(undefined);
      expect(result.isValid).toBe(false);
    });

    test('should reject non-string types', () => {
      const result = UrlValidator.validate(12345);
      expect(result.isValid).toBe(false);
      expect(result.errors[0].code).toBe('URL_INVALID_TYPE');
    });

    test('should reject whitespace only', () => {
      const result = UrlValidator.validate('   ');
      expect(result.isValid).toBe(false);
      expect(result.errors[0].code).toBe('URL_EMPTY');
    });

    test('should reject URLs without protocol', () => {
      const result = UrlValidator.validate('example.com/path');
      expect(result.isValid).toBe(false);
      expect(result.errors[0].code).toBe('URL_MISSING_PROTOCOL');
    });
  });

  describe('URL Format Validation', () => {
    test('should accept valid HTTP URL', () => {
      config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['example.com'];
      const result = UrlValidator.validate('http://example.com/path');
      expect(result.isValid).toBe(true);
    });

    test('should accept valid HTTPS URL', () => {
      config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['example.com'];
      const result = UrlValidator.validate('https://example.com/path');
      expect(result.isValid).toBe(true);
    });

    test('should parse URL and extract info', () => {
      config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['example.com'];
      const result = UrlValidator.validate('https://example.com:8080/path?q=test');
      expect(result.info.parsedUrl).toBeDefined();
      expect(result.info.parsedUrl.protocol).toBe('https:');
      expect(result.info.parsedUrl.hostname).toBe('example.com');
      expect(result.info.parsedUrl.port).toBe('8080');
      expect(result.info.parsedUrl.pathname).toBe('/path');
    });

    test('should handle malformed URLs', () => {
      const result = UrlValidator.validate('http://[invalid');
      expect(result.isValid).toBe(false);
      expect(result.errors[0].code).toBe('URL_PARSE_ERROR');
    });
  });
});

describe('URL Validator Tests - Protocol Validation', () => {
  beforeEach(() => {
    config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['example.com'];
    config.URL_VALIDATION_CONFIG.ALLOWED_PROTOCOLS = ['http:', 'https:'];
  });

  describe('Allowed Protocols', () => {
    test('should accept http protocol', () => {
      const result = UrlValidator.validate('http://example.com');
      expect(result.isValid).toBe(true);
    });

    test('should accept https protocol', () => {
      const result = UrlValidator.validate('https://example.com');
      expect(result.isValid).toBe(true);
    });

    test('should warn about http in production', () => {
      config.ENV.isDevelopment = false;
      const result = UrlValidator.validate('http://example.com');
      expect(result.warnings.length).toBeGreaterThan(0);
      expect(result.warnings[0].code).toBe('URL_INSECURE_PROTOCOL');
    });

    test('should not warn about http in development', () => {
      config.ENV.isDevelopment = true;
      const result = UrlValidator.validate('http://example.com');
      expect(result.warnings.length).toBe(0);
    });
  });

  describe('Blocked Protocols', () => {
    test('should reject ftp protocol', () => {
      const result = UrlValidator.validate('ftp://example.com');
      expect(result.isValid).toBe(false);
      expect(result.errors[0].code).toBe('URL_INVALID_PROTOCOL');
    });

    test('should reject file protocol', () => {
      const result = UrlValidator.validate('file:///etc/passwd');
      expect(result.isValid).toBe(false);
      expect(result.errors[0].code).toBe('URL_INVALID_PROTOCOL');
    });

    test('should reject javascript protocol', () => {
      const result = UrlValidator.validate('javascript:alert(1)');
      expect(result.isValid).toBe(false);
      expect(result.errors[0].code).toBe('URL_INVALID_PROTOCOL');
    });

    test('should reject data protocol', () => {
      const result = UrlValidator.validate('data:text/html,<script>alert(1)</script>');
      expect(result.isValid).toBe(false);
      expect(result.errors[0].code).toBe('URL_INVALID_PROTOCOL');
    });

    test('should reject gopher protocol', () => {
      const result = UrlValidator.validate('gopher://example.com');
      expect(result.isValid).toBe(false);
      expect(result.errors[0].code).toBe('URL_INVALID_PROTOCOL');
    });
  });
});

describe('URL Validator Tests - Private IP Protection', () => {
  beforeEach(() => {
    config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['192.168.1.1', '10.0.0.1', 'localhost'];
  });

  describe('IPv4 Private Ranges', () => {
    test('should block 10.0.0.0/8', () => {
      const result = UrlValidator.validate('http://10.0.0.1');
      expect(result.isValid).toBe(false);
      expect(result.errors[0].code).toBe('URL_PRIVATE_IP');
    });

    test('should block 172.16.0.0/12', () => {
      const result = UrlValidator.validate('http://172.16.0.1');
      expect(result.isValid).toBe(false);
      expect(result.errors[0].code).toBe('URL_PRIVATE_IP');
    });

    test('should block 192.168.0.0/16', () => {
      const result = UrlValidator.validate('http://192.168.1.1');
      expect(result.isValid).toBe(false);
      expect(result.errors[0].code).toBe('URL_PRIVATE_IP');
    });

    test('should block 127.0.0.0/8 (localhost)', () => {
      const result = UrlValidator.validate('http://127.0.0.1');
      expect(result.isValid).toBe(false);
      expect(result.errors[0].code).toBe('URL_PRIVATE_IP');
    });

    test('should block 169.254.0.0/16 (link-local)', () => {
      const result = UrlValidator.validate('http://169.254.169.254');
      expect(result.isValid).toBe(false);
      expect(result.errors[0].code).toBe('URL_PRIVATE_IP');
    });

    test('should block localhost hostname', () => {
      const result = UrlValidator.validate('http://localhost');
      expect(result.isValid).toBe(false);
      expect(result.errors[0].code).toBe('URL_PRIVATE_IP');
    });

    test('should block LOCALHOST (case insensitive)', () => {
      const result = UrlValidator.validate('http://LOCALHOST');
      expect(result.isValid).toBe(false);
      expect(result.errors[0].code).toBe('URL_PRIVATE_IP');
    });
  });

  describe('Public IPs Should Pass (if whitelisted)', () => {
    test('should allow public IP if in whitelist', () => {
      config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['8.8.8.8'];
      const result = UrlValidator.validate('http://8.8.8.8');
      expect(result.isValid).toBe(true);
    });
  });
});

describe('URL Validator Tests - Cloud Metadata Protection', () => {
  beforeEach(() => {
    config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['169.254.169.254', 'metadata.google.internal'];
  });

  describe('AWS/Azure/GCP Metadata', () => {
    test('should block 169.254.169.254', () => {
      const result = UrlValidator.validate('http://169.254.169.254/latest/meta-data');
      expect(result.isValid).toBe(false);
      expect(result.errors[0].code).toBe('URL_METADATA_BLOCKED');
    });

    test('should block GCP metadata endpoint', () => {
      const result = UrlValidator.validate('http://metadata.google.internal/computeMetadata');
      expect(result.isValid).toBe(false);
      expect(result.errors[0].code).toBe('URL_METADATA_BLOCKED');
    });

    test('should block Alibaba Cloud metadata', () => {
      config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['100.100.100.200'];
      const result = UrlValidator.validate('http://100.100.100.200/latest/meta-data');
      expect(result.isValid).toBe(false);
      expect(result.errors[0].code).toBe('URL_METADATA_BLOCKED');
    });
  });
});

describe('URL Validator Tests - Domain Whitelist', () => {
  describe('Exact Domain Match', () => {
    test('should allow exact whitelisted domain', () => {
      config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['example.com'];
      const result = UrlValidator.validate('http://example.com');
      expect(result.isValid).toBe(true);
    });

    test('should reject non-whitelisted domain', () => {
      config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['example.com'];
      const result = UrlValidator.validate('http://evil.com');
      expect(result.isValid).toBe(false);
      expect(result.errors[0].code).toBe('URL_NOT_WHITELISTED');
    });

    test('should reject similar but different domain', () => {
      config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['example.com'];
      const result = UrlValidator.validate('http://example.org');
      expect(result.isValid).toBe(false);
      expect(result.errors[0].code).toBe('URL_NOT_WHITELISTED');
    });
  });

  describe('Subdomain Matching', () => {
    test('should allow subdomain of whitelisted domain', () => {
      config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['example.com'];
      const result = UrlValidator.validate('http://sub.example.com');
      expect(result.isValid).toBe(true);
    });

    test('should allow nested subdomain', () => {
      config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['example.com'];
      const result = UrlValidator.validate('http://a.b.c.example.com');
      expect(result.isValid).toBe(true);
    });

    test('should not allow partial domain match', () => {
      config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['example.com'];
      const result = UrlValidator.validate('http://notexample.com');
      expect(result.isValid).toBe(false);
    });

    test('should not allow suffix match', () => {
      config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['example.com'];
      const result = UrlValidator.validate('http://evilexample.com');
      expect(result.isValid).toBe(false);
    });
  });

  describe('Multiple Whitelisted Domains', () => {
    test('should allow any whitelisted domain', () => {
      config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['example.com', 'test.com', 'demo.org'];

      expect(UrlValidator.validate('http://example.com').isValid).toBe(true);
      expect(UrlValidator.validate('http://test.com').isValid).toBe(true);
      expect(UrlValidator.validate('http://demo.org').isValid).toBe(true);
      expect(UrlValidator.validate('http://evil.com').isValid).toBe(false);
    });
  });
});

describe('URL Validator Tests - ValidationResult Class', () => {
  test('should create ValidationResult', () => {
    const result = new ValidationResult(true, [], [], {});
    expect(result.isValid).toBe(true);
    expect(result.errors).toEqual([]);
    expect(result.warnings).toEqual([]);
  });

  test('should add errors', () => {
    const result = new ValidationResult(true);
    result.addError('Test error', 'TEST_CODE');

    expect(result.isValid).toBe(false);
    expect(result.errors).toHaveLength(1);
    expect(result.errors[0].message).toBe('Test error');
    expect(result.errors[0].code).toBe('TEST_CODE');
  });

  test('should add warnings', () => {
    const result = new ValidationResult(true);
    result.addWarning('Test warning', 'WARN_CODE');

    expect(result.isValid).toBe(true);
    expect(result.warnings).toHaveLength(1);
    expect(result.warnings[0].message).toBe('Test warning');
  });

  test('should get all messages', () => {
    const result = new ValidationResult(true);
    result.addError('Error 1');
    result.addWarning('Warning 1');

    const messages = result.getAllMessages();
    expect(messages).toHaveLength(2);
    expect(messages[0].type).toBe('error');
    expect(messages[1].type).toBe('warning');
  });

  test('should get primary error', () => {
    const result = new ValidationResult(true);
    result.addError('First error');
    result.addError('Second error');

    expect(result.getPrimaryError()).toBe('First error');
  });

  test('should return null for primary error when no errors', () => {
    const result = new ValidationResult(true);
    expect(result.getPrimaryError()).toBeNull();
  });
});

describe('URL Validator Tests - Utility Methods', () => {
  beforeEach(() => {
    config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['example.com'];
  });

  describe('Quick Validation', () => {
    test('should return boolean for isValid', () => {
      expect(UrlValidator.isValid('http://example.com')).toBe(true);
      expect(UrlValidator.isValid('http://evil.com')).toBe(false);
    });
  });

  describe('Get Errors', () => {
    test('should return error messages as array', () => {
      const errors = UrlValidator.getErrors('http://evil.com');
      expect(Array.isArray(errors)).toBe(true);
      expect(errors.length).toBeGreaterThan(0);
      expect(typeof errors[0]).toBe('string');
    });

    test('should return empty array for valid URL', () => {
      const errors = UrlValidator.getErrors('http://example.com');
      expect(errors).toEqual([]);
    });
  });

  describe('Get Summary', () => {
    test('should return validation summary', () => {
      const summary = UrlValidator.getSummary('http://evil.com');

      expect(summary.isValid).toBe(false);
      expect(summary.errorCount).toBeGreaterThan(0);
      expect(summary.primaryError).toBeDefined();
      expect(Array.isArray(summary.allMessages)).toBe(true);
    });
  });

  describe('Validate Or Throw', () => {
    test('should not throw for valid URL', () => {
      expect(() => UrlValidator.validateOrThrow('http://example.com')).not.toThrow();
    });

    test('should throw for invalid URL', () => {
      expect(() => UrlValidator.validateOrThrow('http://evil.com')).toThrow();
    });

    test('should include error code in thrown error', () => {
      try {
        UrlValidator.validateOrThrow('http://evil.com');
      } catch (error) {
        expect(error.code).toBeDefined();
        expect(error.validationResult).toBeDefined();
      }
    });
  });

  describe('Sanitize URL', () => {
    test('should remove credentials', () => {
      const sanitized = UrlValidator.sanitize('http://user:pass@example.com/path');
      expect(sanitized).not.toContain('user');
      expect(sanitized).not.toContain('pass');
    });

    test('should remove hash fragment', () => {
      const sanitized = UrlValidator.sanitize('http://example.com/path#fragment');
      expect(sanitized).not.toContain('#fragment');
    });

    test('should handle invalid URLs gracefully', () => {
      const sanitized = UrlValidator.sanitize('not a url');
      expect(sanitized).toBe('not a url');
    });
  });

  describe('Get Domain', () => {
    test('should extract domain from URL', () => {
      const domain = UrlValidator.getDomain('http://example.com:8080/path');
      expect(domain).toBe('example.com');
    });

    test('should return null for invalid URL', () => {
      const domain = UrlValidator.getDomain('not a url');
      expect(domain).toBeNull();
    });
  });

  describe('Is Domain Whitelisted', () => {
    test('should check if domain is whitelisted', () => {
      config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['example.com', 'test.com'];

      expect(UrlValidator.isDomainWhitelisted('example.com')).toBe(true);
      expect(UrlValidator.isDomainWhitelisted('test.com')).toBe(true);
      expect(UrlValidator.isDomainWhitelisted('evil.com')).toBe(false);
    });

    test('should check subdomains', () => {
      config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['example.com'];

      expect(UrlValidator.isDomainWhitelisted('sub.example.com')).toBe(true);
      expect(UrlValidator.isDomainWhitelisted('a.b.example.com')).toBe(true);
    });
  });

  describe('Get Allowed Domains', () => {
    test('should return allowed domains list', () => {
      config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['example.com', 'test.com'];

      const domains = UrlValidator.getAllowedDomains();
      expect(domains).toEqual(['example.com', 'test.com']);
    });
  });
});

describe('URL Validator Tests - Live Validation', () => {
  beforeEach(() => {
    config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['example.com'];
  });

  test('should allow empty string during live validation', () => {
    const result = UrlValidator.validateLive('');
    expect(result.isValid).toBe(true);
    expect(result.errors).toHaveLength(0);
  });

  test('should validate non-empty string', () => {
    const result = UrlValidator.validateLive('http://evil.com');
    expect(result.isValid).toBe(false);
  });

  test('should filter warnings when disabled', () => {
    config.ENV.isDevelopment = false;
    const result = UrlValidator.validateLive('http://example.com', { showWarnings: false });
    expect(result.warnings).toHaveLength(0);
  });
});

describe('URL Validator Tests - Batch Validation', () => {
  beforeEach(() => {
    config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['example.com', 'test.com'];
  });

  test('should validate multiple URLs', () => {
    const urls = [
      'http://example.com',
      'http://test.com',
      'http://evil.com'
    ];

    const results = UrlValidator.validateBatch(urls);

    expect(results).toHaveLength(3);
    expect(results[0].result.isValid).toBe(true);
    expect(results[1].result.isValid).toBe(true);
    expect(results[2].result.isValid).toBe(false);
  });

  test('should return validation statistics', () => {
    const urls = [
      'http://example.com',
      'http://test.com',
      'http://evil.com',
      'http://bad.com'
    ];

    const stats = UrlValidator.getValidationStats(urls);

    expect(stats.total).toBe(4);
    expect(stats.valid).toBe(2);
    expect(stats.invalid).toBe(2);
    expect(stats.results).toHaveLength(4);
  });
});

describe('URL Validator Tests - HTML Generation', () => {
  test('should create success message HTML', () => {
    config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['example.com'];
    const result = UrlValidator.validate('http://example.com');
    const html = UrlValidator.createValidationMessageHtml(result);

    expect(html).toContain('valid and whitelisted');
    expect(html).toContain('#008800');
  });

  test('should create error message HTML', () => {
    config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['example.com'];
    const result = UrlValidator.validate('http://evil.com');
    const html = UrlValidator.createValidationMessageHtml(result);

    expect(html).toContain('validation-error');
    expect(html).toContain('#cc0000');
  });

  test('should create warning message HTML', () => {
    config.ENV.isDevelopment = false;
    config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS = ['example.com'];
    const result = UrlValidator.validate('http://example.com');
    const html = UrlValidator.createValidationMessageHtml(result);

    expect(html).toContain('warning');
    expect(html).toContain('#ff9900');
  });
});
