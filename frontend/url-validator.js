/**
 * URL Validator Module
 * Client-side URL validation matching backend SSRF protection rules:
 * - Protocol validation (http/https only)
 * - Private IP blocking
 * - Domain whitelist enforcement
 * - Cloud metadata endpoint blocking
 *
 * @module url-validator
 * @version 2.0.0
 */

import config from './config.js';

/**
 * Validation Result Object
 */
class ValidationResult {
  constructor(isValid, errors = [], warnings = [], info = {}) {
    this.isValid = isValid;
    this.errors = errors;
    this.warnings = warnings;
    this.info = info;
  }

  /**
   * Add error
   */
  addError(message, code = null) {
    this.errors.push({ message, code });
    this.isValid = false;
  }

  /**
   * Add warning
   */
  addWarning(message, code = null) {
    this.warnings.push({ message, code });
  }

  /**
   * Get all messages
   */
  getAllMessages() {
    return [
      ...this.errors.map(e => ({ type: 'error', ...e })),
      ...this.warnings.map(w => ({ type: 'warning', ...w }))
    ];
  }

  /**
   * Get primary error message
   */
  getPrimaryError() {
    return this.errors.length > 0 ? this.errors[0].message : null;
  }
}

/**
 * URL Validator Class
 */
class UrlValidator {
  /**
   * Validate URL comprehensively
   */
  static validate(urlString) {
    const result = new ValidationResult(true);

    // Step 1: Basic validation
    if (!this.validateBasicFormat(urlString, result)) {
      return result;
    }

    // Step 2: Parse URL
    let parsedUrl;
    try {
      parsedUrl = new URL(urlString);
      result.info.parsedUrl = {
        protocol: parsedUrl.protocol,
        hostname: parsedUrl.hostname,
        port: parsedUrl.port,
        pathname: parsedUrl.pathname
      };
    } catch (error) {
      result.addError(
        config.ERROR_MESSAGES.URL_INVALID_FORMAT,
        'URL_PARSE_ERROR'
      );
      return result;
    }

    // Step 3: Protocol validation
    if (!this.validateProtocol(parsedUrl, result)) {
      return result;
    }

    // Step 4: Private IP validation
    if (!this.validatePrivateIp(parsedUrl.hostname, result)) {
      return result;
    }

    // Step 5: Cloud metadata endpoint validation
    if (!this.validateMetadataEndpoint(parsedUrl.hostname, result)) {
      return result;
    }

    // Step 6: Domain whitelist validation
    if (!this.validateWhitelist(parsedUrl.hostname, result)) {
      return result;
    }

    // Add success info
    result.info.validatedAt = new Date().toISOString();
    result.info.allowedDomain = true;

    return result;
  }

  /**
   * Validate basic format
   */
  static validateBasicFormat(urlString, result) {
    if (!urlString) {
      result.addError('URL is required', 'URL_EMPTY');
      return false;
    }

    if (typeof urlString !== 'string') {
      result.addError('URL must be a string', 'URL_INVALID_TYPE');
      return false;
    }

    if (urlString.trim().length === 0) {
      result.addError('URL cannot be empty', 'URL_EMPTY');
      return false;
    }

    // Check for obvious malformed URLs
    if (!urlString.includes('://')) {
      result.addError(
        'URL must include protocol (http:// or https://)',
        'URL_MISSING_PROTOCOL'
      );
      return false;
    }

    return true;
  }

  /**
   * Validate protocol
   */
  static validateProtocol(parsedUrl, result) {
    const allowedProtocols = config.URL_VALIDATION_CONFIG.ALLOWED_PROTOCOLS;

    if (!allowedProtocols.includes(parsedUrl.protocol)) {
      result.addError(
        config.ERROR_MESSAGES.URL_INVALID_PROTOCOL,
        'URL_INVALID_PROTOCOL'
      );
      result.info.providedProtocol = parsedUrl.protocol;
      result.info.allowedProtocols = allowedProtocols;
      return false;
    }

    // Warn if using http instead of https
    if (parsedUrl.protocol === 'http:' && !config.ENV.isDevelopment) {
      result.addWarning(
        'Using HTTP instead of HTTPS may be insecure',
        'URL_INSECURE_PROTOCOL'
      );
    }

    return true;
  }

  /**
   * Validate against private IP ranges
   */
  static validatePrivateIp(hostname, result) {
    const patterns = config.URL_VALIDATION_CONFIG.PRIVATE_IP_PATTERNS;

    for (const pattern of patterns) {
      if (pattern.test(hostname)) {
        result.addError(
          config.ERROR_MESSAGES.URL_PRIVATE_IP,
          'URL_PRIVATE_IP'
        );
        result.info.detectedPattern = pattern.toString();
        return false;
      }
    }

    return true;
  }

  /**
   * Validate against cloud metadata endpoints
   */
  static validateMetadataEndpoint(hostname, result) {
    const blockedEndpoints = config.URL_VALIDATION_CONFIG.BLOCKED_METADATA_ENDPOINTS;

    for (const endpoint of blockedEndpoints) {
      if (hostname === endpoint || hostname.includes(endpoint)) {
        result.addError(
          config.ERROR_MESSAGES.URL_BLOCKED_METADATA,
          'URL_METADATA_BLOCKED'
        );
        result.info.blockedEndpoint = endpoint;
        return false;
      }
    }

    return true;
  }

  /**
   * Validate against domain whitelist
   */
  static validateWhitelist(hostname, result) {
    const allowedDomains = config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS;

    // Check if hostname matches any allowed domain
    const isWhitelisted = allowedDomains.some(allowedDomain => {
      // Exact match
      if (hostname === allowedDomain) {
        return true;
      }

      // Subdomain match (e.g., sub.example.com matches example.com)
      if (hostname.endsWith(`.${allowedDomain}`)) {
        return true;
      }

      return false;
    });

    if (!isWhitelisted) {
      result.addError(
        config.ERROR_MESSAGES.URL_NOT_WHITELISTED,
        'URL_NOT_WHITELISTED'
      );
      result.info.providedDomain = hostname;
      result.info.allowedDomains = allowedDomains;
      return false;
    }

    return true;
  }

  /**
   * Quick validation (returns boolean)
   */
  static isValid(urlString) {
    const result = this.validate(urlString);
    return result.isValid;
  }

  /**
   * Get validation errors as string array
   */
  static getErrors(urlString) {
    const result = this.validate(urlString);
    return result.errors.map(e => e.message);
  }

  /**
   * Get validation summary
   */
  static getSummary(urlString) {
    const result = this.validate(urlString);

    return {
      isValid: result.isValid,
      errorCount: result.errors.length,
      warningCount: result.warnings.length,
      primaryError: result.getPrimaryError(),
      allMessages: result.getAllMessages()
    };
  }

  /**
   * Validate and throw if invalid (for use with async/await)
   */
  static validateOrThrow(urlString) {
    const result = this.validate(urlString);

    if (!result.isValid) {
      const error = new Error(result.getPrimaryError());
      error.code = result.errors[0]?.code;
      error.validationResult = result;
      throw error;
    }

    return result;
  }

  /**
   * Sanitize URL (remove dangerous parts)
   * Note: This is NOT a replacement for validation!
   */
  static sanitize(urlString) {
    try {
      const url = new URL(urlString);

      // Remove authentication credentials if present
      url.username = '';
      url.password = '';

      // Remove hash fragment
      url.hash = '';

      return url.toString();
    } catch {
      return urlString;
    }
  }

  /**
   * Get domain from URL
   */
  static getDomain(urlString) {
    try {
      const url = new URL(urlString);
      return url.hostname;
    } catch {
      return null;
    }
  }

  /**
   * Check if domain is whitelisted
   */
  static isDomainWhitelisted(domain) {
    const allowedDomains = config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS;

    return allowedDomains.some(allowedDomain =>
      domain === allowedDomain || domain.endsWith(`.${allowedDomain}`)
    );
  }

  /**
   * Get allowed domains
   */
  static getAllowedDomains() {
    return [...config.URL_VALIDATION_CONFIG.ALLOWED_DOMAINS];
  }

  /**
   * Create validation message HTML
   */
  static createValidationMessageHtml(result) {
    if (result.isValid && result.errors.length === 0 && result.warnings.length === 0) {
      return `
        <div class="validation-success" style="
          color: #008800;
          padding: 8px 12px;
          background: #00880010;
          border-left: 3px solid #008800;
          border-radius: 4px;
          font-size: 14px;
        ">
          ✓ URL is valid and whitelisted
        </div>
      `;
    }

    const messages = result.getAllMessages();
    const html = messages.map(msg => {
      const color = msg.type === 'error' ? '#cc0000' : '#ff9900';
      const icon = msg.type === 'error' ? '✗' : '⚠';

      return `
        <div class="validation-${msg.type}" style="
          color: ${color};
          padding: 8px 12px;
          background: ${color}10;
          border-left: 3px solid ${color};
          border-radius: 4px;
          margin-bottom: 8px;
          font-size: 14px;
        ">
          ${icon} ${msg.message}
        </div>
      `;
    }).join('');

    return html;
  }

  /**
   * Live validation for input fields
   * Returns validation result as user types
   */
  static validateLive(urlString, options = {}) {
    const { showWarnings = true, showInfo = false } = options;

    // Don't validate empty string (allow user to type)
    if (!urlString || urlString.trim().length === 0) {
      return new ValidationResult(true);
    }

    // Perform validation
    const result = this.validate(urlString);

    // Filter results based on options
    if (!showWarnings) {
      result.warnings = [];
    }

    return result;
  }

  /**
   * Batch validate multiple URLs
   */
  static validateBatch(urls) {
    return urls.map(url => ({
      url,
      result: this.validate(url)
    }));
  }

  /**
   * Get validation statistics
   */
  static getValidationStats(urls) {
    const results = this.validateBatch(urls);

    return {
      total: results.length,
      valid: results.filter(r => r.result.isValid).length,
      invalid: results.filter(r => !r.result.isValid).length,
      withWarnings: results.filter(r => r.result.warnings.length > 0).length,
      results
    };
  }
}

// Export
export default UrlValidator;
export { ValidationResult };
