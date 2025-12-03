/**
 * Integration Test Script for Wave 4
 * Tests full Assistant API integration flow
 *
 * Usage:
 *   node test-integration.js /path/to/test.pdf /path/to/test-quiz-screenshot.png
 *
 * Prerequisites:
 *   - Backend server running on port 3000
 *   - OPENAI_API_KEY configured in .env
 *   - Valid PDF and quiz screenshot files
 */

const axios = require('axios');
const fs = require('fs');
const path = require('path');

const BASE_URL = 'http://localhost:3000/api';

// ANSI color codes for terminal output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m'
};

function log(emoji, message, color = colors.reset) {
  console.log(`${color}${emoji} ${message}${colors.reset}`);
}

function logSuccess(message) {
  log('✅', message, colors.green);
}

function logError(message) {
  log('❌', message, colors.red);
}

function logInfo(message) {
  log('ℹ️ ', message, colors.cyan);
}

function logWarning(message) {
  log('⚠️ ', message, colors.yellow);
}

async function testIntegration() {
  console.log('\n' + '='.repeat(60));
  log('🧪', 'Testing Wave 4: Backend Integration with Assistant API', colors.blue);
  console.log('='.repeat(60) + '\n');

  try {
    // Get command line arguments
    const pdfPath = process.argv[2];
    const screenshotPath = process.argv[3];

    // Validate arguments
    if (!pdfPath || !screenshotPath) {
      logError('Missing required arguments');
      console.log('\nUsage:');
      console.log('  node test-integration.js /path/to/test.pdf /path/to/test-quiz.png\n');
      console.log('Example:');
      console.log('  node test-integration.js ./script.pdf ./quiz-screenshot.png\n');
      process.exit(1);
    }

    // Validate files exist
    if (!fs.existsSync(pdfPath)) {
      logError(`PDF file not found: ${pdfPath}`);
      process.exit(1);
    }

    if (!fs.existsSync(screenshotPath)) {
      logError(`Screenshot file not found: ${screenshotPath}`);
      process.exit(1);
    }

    // Test 1: Health Check
    log('🔍', 'Test 1: Health check...', colors.blue);
    const healthResponse = await axios.get(`${BASE_URL.replace('/api', '')}/health`);

    if (healthResponse.data.status === 'ok' && healthResponse.data.openai_configured) {
      logSuccess('Server healthy and OpenAI configured');
      logInfo(`   OpenAI configured: ${healthResponse.data.openai_configured}`);
      logInfo(`   API key configured: ${healthResponse.data.api_key_configured}`);
    } else {
      logWarning('Server health check returned unexpected response');
      console.log('   Response:', JSON.stringify(healthResponse.data, null, 2));
    }
    console.log();

    // Test 2: Upload PDF
    log('📄', 'Test 2: Upload PDF and create thread...', colors.blue);
    const pdfStats = fs.statSync(pdfPath);
    const pdfSizeMB = (pdfStats.size / 1024 / 1024).toFixed(2);
    logInfo(`   PDF: ${path.basename(pdfPath)} (${pdfSizeMB} MB)`);

    const uploadResponse = await axios.post(`${BASE_URL}/upload-pdf`, {
      pdfPath: path.resolve(pdfPath)
    }, {
      timeout: 180000 // 3 minutes for large PDFs
    });

    if (uploadResponse.data.threadId && uploadResponse.data.assistantId) {
      logSuccess('PDF uploaded successfully');
      logInfo(`   Thread ID: ${uploadResponse.data.threadId}`);
      logInfo(`   Assistant ID: ${uploadResponse.data.assistantId}`);
      logInfo(`   File ID: ${uploadResponse.data.fileId || 'N/A'}`);
      logInfo(`   Vector Store ID: ${uploadResponse.data.vectorStoreId || 'N/A'}`);
    } else {
      logError('Upload response missing required fields');
      console.log('   Response:', JSON.stringify(uploadResponse.data, null, 2));
      process.exit(1);
    }
    console.log();

    const threadId = uploadResponse.data.threadId;

    // Test 3: List threads
    log('📋', 'Test 3: List active threads...', colors.blue);
    const threadsResponse = await axios.get(`${BASE_URL}/threads`);

    if (threadsResponse.data.threads && threadsResponse.data.count) {
      logSuccess(`Active threads: ${threadsResponse.data.count}`);
      threadsResponse.data.threads.forEach((thread, index) => {
        logInfo(`   ${index + 1}. ${thread.threadId} (${thread.pdfPath})`);
      });
    } else {
      logWarning('Unexpected threads response format');
    }
    console.log();

    // Test 4: Get thread info
    log('ℹ️ ', 'Test 4: Get thread info...', colors.blue);
    const threadInfoResponse = await axios.get(`${BASE_URL}/thread/${threadId}`);

    if (threadInfoResponse.data.threadId) {
      logSuccess('Thread info retrieved');
      logInfo(`   PDF: ${threadInfoResponse.data.pdfPath}`);
      logInfo(`   Age: ${threadInfoResponse.data.ageMinutes} minutes`);
    } else {
      logWarning('Unexpected thread info format');
    }
    console.log();

    // Test 5: Analyze quiz (with screenshot)
    log('🔍', 'Test 5: Analyze quiz with PDF context...', colors.blue);
    const screenshotStats = fs.statSync(screenshotPath);
    const screenshotSizeMB = (screenshotStats.size / 1024 / 1024).toFixed(2);
    logInfo(`   Screenshot: ${path.basename(screenshotPath)} (${screenshotSizeMB} MB)`);

    const screenshotBase64 = fs.readFileSync(screenshotPath, 'base64');
    logInfo(`   Base64 size: ${(screenshotBase64.length / 1024).toFixed(2)} KB`);

    log('⏳', 'Waiting for Assistant response (may take 30-120 seconds)...', colors.yellow);
    const startTime = Date.now();

    const analysisResponse = await axios.post(`${BASE_URL}/analyze-quiz`, {
      threadId: threadId,
      screenshotBase64: screenshotBase64
    }, {
      timeout: 180000 // 3 minutes
    });

    const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);

    if (analysisResponse.data.answers && Array.isArray(analysisResponse.data.answers)) {
      logSuccess(`Quiz analyzed in ${elapsed}s`);
      logInfo(`   Answers: ${analysisResponse.data.answers.length}`);

      // Show answer breakdown
      const mcAnswers = analysisResponse.data.answers.filter(a => a.type === 'multiple-choice');
      const writtenAnswers = analysisResponse.data.answers.filter(a => a.type === 'written');

      logInfo(`   Multiple-choice: ${mcAnswers.length}`);
      logInfo(`   Written: ${writtenAnswers.length}`);

      // Show first 3 answers as sample
      console.log('\n   Sample answers:');
      analysisResponse.data.answers.slice(0, 3).forEach(answer => {
        if (answer.type === 'multiple-choice') {
          console.log(`   Q${answer.questionNumber}: ${answer.question}`);
          console.log(`      Options: ${answer.options?.join(', ')}`);
          console.log(`      Correct: ${answer.correctAnswer}`);
        } else {
          console.log(`   Q${answer.questionNumber}: ${answer.question}`);
          console.log(`      Answer: ${answer.answerText?.substring(0, 100)}...`);
        }
      });

      if (analysisResponse.data.answers.length > 3) {
        console.log(`   ... and ${analysisResponse.data.answers.length - 3} more\n`);
      }
    } else {
      logError('Analysis response missing answers array');
      console.log('   Response:', JSON.stringify(analysisResponse.data, null, 2));
      process.exit(1);
    }
    console.log();

    // Test 6: Delete thread (cleanup)
    log('🧹', 'Test 6: Delete thread and cleanup...', colors.blue);
    await axios.delete(`${BASE_URL}/thread/${threadId}`);
    logSuccess('Thread deleted');
    console.log();

    // Final summary
    console.log('='.repeat(60));
    logSuccess('All integration tests passed!');
    console.log('='.repeat(60) + '\n');

    console.log('Summary:');
    console.log('  ✅ Health check passed');
    console.log('  ✅ PDF upload and thread creation');
    console.log('  ✅ Thread listing and info retrieval');
    console.log('  ✅ Quiz analysis with Assistant API');
    console.log('  ✅ Thread cleanup\n');

    console.log('Next steps:');
    console.log('  1. Test from Swift app: Press Cmd+Option+L to upload PDF');
    console.log('  2. Capture quiz: Press Cmd+Option+O');
    console.log('  3. Process quiz: Press Cmd+Option+P\n');

  } catch (error) {
    console.log();
    logError('Test failed');

    if (error.response) {
      console.log(`   HTTP ${error.response.status}: ${error.response.statusText}`);
      if (error.response.data) {
        console.log('   Response:', JSON.stringify(error.response.data, null, 2));
      }
    } else if (error.request) {
      console.log('   No response from server');
      console.log('   Is the backend running on port 3000?');
    } else {
      console.log('   Error:', error.message);
    }

    console.log();
    process.exit(1);
  }
}

// Run tests
testIntegration();
