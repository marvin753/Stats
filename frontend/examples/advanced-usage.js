/**
 * Advanced Usage Examples
 * Demonstrates complex integration scenarios
 */

import config from '../config.js';
import apiClient from '../api-client.js';
import ErrorHandler from '../error-handler.js';
import UrlValidator from '../url-validator.js';

/**
 * Example 1: Complete Quiz Analysis Flow
 */
async function completeQuizAnalysis(url) {
  console.log('=== Complete Quiz Analysis ===\n');

  // Step 1: Validate URL
  console.log('Step 1: Validating URL...');
  try {
    const validation = UrlValidator.validateOrThrow(url);
    console.log('✓ URL is valid');
    console.log('  Domain:', validation.info.parsedUrl.hostname);
  } catch (error) {
    console.error('✗ URL validation failed:', ErrorHandler.getUserMessage(error));
    return;
  }

  // Step 2: Check API key
  console.log('\nStep 2: Checking API key...');
  if (!config.hasApiKey()) {
    console.error('✗ API key not configured');
    return;
  }
  console.log('✓ API key is configured');

  // Step 3: Check rate limit
  console.log('\nStep 3: Checking rate limits...');
  const rateLimitStatus = apiClient.getRateLimitStatus();
  console.log(`  Remaining requests: ${rateLimitStatus.openai.remaining}/${rateLimitStatus.openai.limit}`);

  if (rateLimitStatus.openai.remaining === 0) {
    const resetIn = Math.ceil(rateLimitStatus.openai.resetIn / 1000);
    console.error(`✗ Rate limit exceeded. Reset in ${resetIn}s`);
    return;
  }

  // Step 4: Scrape questions (mock data for example)
  console.log('\nStep 4: Scraping questions...');
  const questions = [
    {
      question: "What is the capital of France?",
      answers: ["London", "Berlin", "Paris", "Madrid"]
    },
    {
      question: "What is 2 + 2?",
      answers: ["3", "4", "5", "6"]
    }
  ];
  console.log(`✓ Scraped ${questions.length} questions`);

  // Step 5: Analyze with AI
  console.log('\nStep 5: Analyzing with AI...');
  try {
    const result = await apiClient.analyzeQuestions(questions);
    console.log('✓ Analysis complete');
    console.log('  Answers:', result.answers);
    console.log('  Status:', result.status);

    // Update rate limit display
    const newStatus = apiClient.getRateLimitStatus();
    console.log(`  Remaining: ${newStatus.openai.remaining}/${newStatus.openai.limit}`);

    return result;
  } catch (error) {
    console.error('✗ Analysis failed');
    const parsed = ErrorHandler.handleApiError(error);

    console.error(`  Error: ${parsed.userMessage}`);
    console.error(`  Type: ${parsed.type}`);
    console.error(`  Retryable: ${parsed.retryable}`);

    if (parsed.retryable && parsed.retryAfter) {
      console.log(`  Will retry in ${parsed.retryAfter}s`);
    }
  }
}

/**
 * Example 2: Retry Logic with Exponential Backoff
 */
async function analyzeWithRetry(questions, maxRetries = 3) {
  console.log('=== Analysis with Retry Logic ===\n');

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    console.log(`Attempt ${attempt}/${maxRetries}...`);

    try {
      const result = await apiClient.analyzeQuestions(questions);
      console.log('✓ Success!');
      return result;
    } catch (error) {
      const parsed = ErrorHandler.parseError(error);

      if (!parsed.retryable || attempt === maxRetries) {
        console.error('✗ Final failure');
        throw error;
      }

      const delay = parsed.retryAfter
        ? parsed.retryAfter * 1000
        : Math.min(1000 * Math.pow(2, attempt - 1), 30000);

      console.log(`⏱️  Retrying in ${delay}ms...`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
}

/**
 * Example 3: Batch URL Validation
 */
function validateMultipleUrls(urls) {
  console.log('=== Batch URL Validation ===\n');

  const stats = UrlValidator.getValidationStats(urls);

  console.log(`Total URLs: ${stats.total}`);
  console.log(`Valid: ${stats.valid}`);
  console.log(`Invalid: ${stats.invalid}`);
  console.log(`With warnings: ${stats.withWarnings}\n`);

  stats.results.forEach(({ url, result }) => {
    const status = result.isValid ? '✓' : '✗';
    console.log(`${status} ${url}`);

    if (!result.isValid) {
      result.errors.forEach(error => {
        console.log(`    Error: ${error.message}`);
      });
    }

    if (result.warnings.length > 0) {
      result.warnings.forEach(warning => {
        console.log(`    Warning: ${warning.message}`);
      });
    }
  });

  return stats;
}

/**
 * Example 4: Rate Limit Monitoring
 */
function monitorRateLimits(callback) {
  console.log('=== Rate Limit Monitor Started ===\n');

  const intervalId = setInterval(() => {
    const status = apiClient.getRateLimitStatus();

    // Check if near limit
    if (status.openai.isNearLimit) {
      console.warn('⚠️  Warning: Near rate limit!');
      console.warn(`   ${status.openai.remaining} requests remaining`);
    }

    // Check if rate limited
    if (status.openai.remaining === 0) {
      const resetIn = Math.ceil(status.openai.resetIn / 1000);
      console.error('🚫 Rate limit exceeded!');
      console.error(`   Reset in ${resetIn}s`);
    }

    // Call callback with status
    if (callback) {
      callback(status);
    }
  }, 1000);

  // Return function to stop monitoring
  return () => {
    clearInterval(intervalId);
    console.log('=== Rate Limit Monitor Stopped ===\n');
  };
}

/**
 * Example 5: Error Recovery Strategies
 */
async function analyzeWithErrorRecovery(questions) {
  console.log('=== Analysis with Error Recovery ===\n');

  try {
    return await apiClient.analyzeQuestions(questions);
  } catch (error) {
    const parsed = ErrorHandler.parseError(error);

    // Strategy 1: Handle authentication errors
    if (parsed.type === 'AUTH') {
      console.log('Strategy: Fix authentication');

      if (parsed.code === 'AUTH_NO_KEY') {
        // Prompt for API key
        const key = prompt('Please enter your API key:');
        if (config.setApiKey(key)) {
          console.log('Retrying with new API key...');
          return await apiClient.analyzeQuestions(questions);
        }
      }

      if (parsed.code === 'AUTH_INVALID') {
        // Clear invalid key
        config.clearApiKey();
        console.error('Invalid API key. Please reconfigure.');
      }
    }

    // Strategy 2: Handle rate limiting
    if (parsed.type === 'RATE_LIMIT') {
      console.log('Strategy: Wait for rate limit reset');

      if (parsed.retryAfter) {
        console.log(`Waiting ${parsed.retryAfter}s...`);
        await new Promise(resolve => setTimeout(resolve, parsed.retryAfter * 1000));

        console.log('Retrying after rate limit reset...');
        return await apiClient.analyzeQuestions(questions);
      }
    }

    // Strategy 3: Handle network errors
    if (parsed.type === 'NETWORK') {
      console.log('Strategy: Check connectivity and retry');

      // Wait a bit and retry
      await new Promise(resolve => setTimeout(resolve, 2000));

      console.log('Retrying after network error...');
      return await apiClient.analyzeQuestions(questions);
    }

    // No recovery strategy available
    console.error('No recovery strategy available');
    throw error;
  }
}

/**
 * Example 6: Performance Monitoring
 */
async function analyzeWithPerformanceMonitoring(questions) {
  console.log('=== Performance Monitoring ===\n');

  // Track performance metrics
  const metrics = {
    startTime: performance.now(),
    validationTime: 0,
    apiCallTime: 0,
    totalTime: 0
  };

  // Validation phase
  const validationStart = performance.now();
  // ... validation logic
  metrics.validationTime = performance.now() - validationStart;

  // API call phase
  const apiStart = performance.now();
  try {
    const result = await apiClient.analyzeQuestions(questions);
    metrics.apiCallTime = performance.now() - apiStart;
    metrics.totalTime = performance.now() - metrics.startTime;

    console.log('Performance Metrics:');
    console.log(`  Validation: ${metrics.validationTime.toFixed(2)}ms`);
    console.log(`  API Call: ${metrics.apiCallTime.toFixed(2)}ms`);
    console.log(`  Total: ${metrics.totalTime.toFixed(2)}ms`);

    return { result, metrics };
  } catch (error) {
    metrics.totalTime = performance.now() - metrics.startTime;
    console.error(`Failed after ${metrics.totalTime.toFixed(2)}ms`);
    throw error;
  }
}

/**
 * Example 7: Configuration Management
 */
function manageConfiguration() {
  console.log('=== Configuration Management ===\n');

  // Get current configuration
  const summary = config.getSummary();
  console.log('Current Configuration:');
  console.log(JSON.stringify(summary, null, 2));

  // Modify configuration
  console.log('\nModifying configuration...');

  // Example: Change backend URL (for testing)
  const originalUrl = config.API_CONFIG.BACKEND_URL;
  config.API_CONFIG.BACKEND_URL = 'https://test-api.example.com';
  console.log(`Backend URL changed: ${originalUrl} → ${config.API_CONFIG.BACKEND_URL}`);

  // Example: Enable/disable features
  const originalLogging = config.FEATURES.ENABLE_REQUEST_LOGGING;
  config.FEATURES.ENABLE_REQUEST_LOGGING = !originalLogging;
  console.log(`Request logging: ${originalLogging} → ${config.FEATURES.ENABLE_REQUEST_LOGGING}`);

  // Restore original configuration
  config.API_CONFIG.BACKEND_URL = originalUrl;
  config.FEATURES.ENABLE_REQUEST_LOGGING = originalLogging;
  console.log('\nConfiguration restored');
}

/**
 * Example 8: Real-time URL Validation for Form Input
 */
function setupLiveUrlValidation(inputElement, outputElement) {
  console.log('=== Live URL Validation Setup ===\n');

  inputElement.addEventListener('input', (event) => {
    const url = event.target.value;

    // Skip validation if empty
    if (!url) {
      outputElement.innerHTML = '';
      return;
    }

    // Validate
    const result = UrlValidator.validateLive(url, {
      showWarnings: true,
      showInfo: false
    });

    // Update UI
    if (result.isValid) {
      inputElement.style.borderColor = 'green';
    } else {
      inputElement.style.borderColor = 'red';
    }

    // Show messages
    outputElement.innerHTML = UrlValidator.createValidationMessageHtml(result);
  });

  console.log('Live validation enabled');
}

// Export examples
export {
  completeQuizAnalysis,
  analyzeWithRetry,
  validateMultipleUrls,
  monitorRateLimits,
  analyzeWithErrorRecovery,
  analyzeWithPerformanceMonitoring,
  manageConfiguration,
  setupLiveUrlValidation
};

// If run directly, execute demo
if (typeof window !== 'undefined' && window.location.search.includes('demo=true')) {
  console.log('Running Advanced Usage Demo...\n');

  // Demo 1: Batch URL validation
  validateMultipleUrls([
    'https://example.com/quiz1',
    'http://192.168.1.1',
    'https://example.com/quiz2',
    'ftp://example.com'
  ]);

  // Demo 2: Rate limit monitoring
  const stopMonitoring = monitorRateLimits((status) => {
    // Update UI or log status
  });

  // Stop after 10 seconds
  setTimeout(stopMonitoring, 10000);
}
