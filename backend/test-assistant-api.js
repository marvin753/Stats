#!/usr/bin/env node
/**
 * Test script for OpenAI Assistant API integration
 * Tests PDF upload, thread creation, and quiz analysis
 *
 * Usage:
 *   node test-assistant-api.js --pdf /path/to/test.pdf
 *   node test-assistant-api.js --pdf /path/to/script.pdf --screenshot /path/to/quiz.png
 */

const axios = require('axios');
const fs = require('fs');
const path = require('path');

const BASE_URL = 'http://localhost:3000/api';

// Parse command line arguments
const args = process.argv.slice(2);
const pdfPath = args[args.indexOf('--pdf') + 1];
const screenshotPath = args.indexOf('--screenshot') !== -1 ? args[args.indexOf('--screenshot') + 1] : null;

// Colors for console output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m'
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

async function testPDFUpload() {
  log('\n=== TEST 1: PDF Upload ===', 'cyan');

  if (!pdfPath) {
    log('❌ No PDF path provided. Use --pdf /path/to/file.pdf', 'red');
    return null;
  }

  if (!fs.existsSync(pdfPath)) {
    log(`❌ PDF file not found: ${pdfPath}`, 'red');
    return null;
  }

  const fileStats = fs.statSync(pdfPath);
  const fileSizeMB = (fileStats.size / 1024 / 1024).toFixed(2);
  log(`📄 PDF: ${path.basename(pdfPath)} (${fileSizeMB} MB)`, 'blue');

  try {
    // Read PDF as base64
    const pdfData = fs.readFileSync(pdfPath);
    const base64PDF = pdfData.toString('base64');

    log('⏳ Uploading PDF to Assistant API...', 'yellow');
    const startTime = Date.now();

    const response = await axios.post(`${BASE_URL}/upload-pdf`, {
      pdfBase64: base64PDF,
      filename: path.basename(pdfPath)
    }, {
      timeout: 180000 // 3 minutes
    });

    const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);

    log(`✅ Upload successful in ${elapsed}s`, 'green');
    log(`   Thread ID: ${response.data.threadId}`, 'blue');
    log(`   Assistant ID: ${response.data.assistantId}`, 'blue');
    log(`   File ID: ${response.data.fileId}`, 'blue');
    log(`   Vector Store ID: ${response.data.vectorStoreId}`, 'blue');

    return response.data;
  } catch (error) {
    log(`❌ Upload failed: ${error.message}`, 'red');
    if (error.response?.data) {
      log(`   Details: ${JSON.stringify(error.response.data, null, 2)}`, 'red');
    }
    return null;
  }
}

async function testQuizAnalysis(threadId) {
  log('\n=== TEST 2: Quiz Analysis ===', 'cyan');

  if (!threadId) {
    log('❌ No thread ID available. Upload PDF first.', 'red');
    return null;
  }

  // Create mock quiz screenshot if not provided
  let screenshotBase64;

  if (screenshotPath && fs.existsSync(screenshotPath)) {
    log(`📸 Using screenshot: ${path.basename(screenshotPath)}`, 'blue');
    const screenshotData = fs.readFileSync(screenshotPath);
    screenshotBase64 = screenshotData.toString('base64');
  } else {
    log('📸 Creating mock quiz screenshot...', 'yellow');
    // Create a simple base64 encoded test image (1x1 transparent PNG)
    screenshotBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
    log('⚠️  Using mock screenshot. Provide real screenshot with --screenshot for actual testing.', 'yellow');
  }

  try {
    log('⏳ Analyzing quiz with PDF context...', 'yellow');
    const startTime = Date.now();

    const response = await axios.post(`${BASE_URL}/analyze-quiz`, {
      threadId: threadId,
      screenshotBase64: screenshotBase64
    }, {
      timeout: 180000 // 3 minutes
    });

    const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);

    log(`✅ Analysis successful in ${elapsed}s`, 'green');
    log(`   Answers extracted: ${response.data.answers.length}`, 'blue');

    // Show answer summary
    const mcCount = response.data.answers.filter(a => a.type === 'multiple-choice').length;
    const writtenCount = response.data.answers.filter(a => a.type === 'written').length;
    log(`   Multiple-choice: ${mcCount}, Written: ${writtenCount}`, 'blue');

    // Show first few answers
    log('\n   Sample answers:', 'blue');
    response.data.answers.slice(0, 3).forEach(answer => {
      if (answer.type === 'multiple-choice') {
        log(`   Q${answer.questionNumber}: ${answer.question}`, 'cyan');
        log(`      Answer: Option ${answer.correctAnswer}`, 'green');
      } else {
        log(`   Q${answer.questionNumber}: ${answer.question}`, 'cyan');
        const preview = answer.answerText.substring(0, 80) + '...';
        log(`      Answer: ${preview}`, 'green');
      }
    });

    return response.data;
  } catch (error) {
    log(`❌ Analysis failed: ${error.message}`, 'red');
    if (error.response?.data) {
      log(`   Details: ${JSON.stringify(error.response.data, null, 2)}`, 'red');
    }
    return null;
  }
}

async function testThreadInfo(threadId) {
  log('\n=== TEST 3: Thread Info ===', 'cyan');

  if (!threadId) {
    log('❌ No thread ID available.', 'red');
    return;
  }

  try {
    const response = await axios.get(`${BASE_URL}/thread/${threadId}`);

    log('✅ Thread info retrieved', 'green');
    log(`   Thread ID: ${response.data.threadId}`, 'blue');
    log(`   PDF: ${response.data.pdfPath}`, 'blue');
    log(`   Age: ${response.data.ageMinutes} minutes`, 'blue');
    log(`   Created: ${response.data.createdAt}`, 'blue');
  } catch (error) {
    log(`❌ Failed to get thread info: ${error.message}`, 'red');
  }
}

async function testListThreads() {
  log('\n=== TEST 4: List Threads ===', 'cyan');

  try {
    const response = await axios.get(`${BASE_URL}/threads`);

    log(`✅ Found ${response.data.count} active thread(s)`, 'green');

    response.data.threads.forEach((thread, index) => {
      log(`\n   Thread ${index + 1}:`, 'blue');
      log(`      ID: ${thread.threadId}`, 'cyan');
      log(`      PDF: ${thread.pdfPath}`, 'cyan');
      log(`      Age: ${thread.ageMinutes} minutes`, 'cyan');
    });
  } catch (error) {
    log(`❌ Failed to list threads: ${error.message}`, 'red');
  }
}

async function testDeleteThread(threadId) {
  log('\n=== TEST 5: Delete Thread ===', 'cyan');

  if (!threadId) {
    log('⚠️  Skipping thread deletion (no thread ID)', 'yellow');
    return;
  }

  // Ask for confirmation
  log(`⚠️  About to delete thread: ${threadId}`, 'yellow');
  log('   Press Ctrl+C to cancel, or wait 3 seconds to proceed...', 'yellow');

  await new Promise(resolve => setTimeout(resolve, 3000));

  try {
    await axios.delete(`${BASE_URL}/thread/${threadId}`);
    log('✅ Thread deleted successfully', 'green');
  } catch (error) {
    log(`❌ Failed to delete thread: ${error.message}`, 'red');
  }
}

async function testHealthCheck() {
  log('\n=== TEST 0: Health Check ===', 'cyan');

  try {
    const response = await axios.get('http://localhost:3000/health');
    log('✅ Backend is healthy', 'green');
    log(`   OpenAI configured: ${response.data.openai_configured}`, 'blue');
    log(`   API key configured: ${response.data.api_key_configured}`, 'blue');
    return true;
  } catch (error) {
    log('❌ Backend health check failed', 'red');
    log('   Make sure backend is running: cd backend && npm start', 'yellow');
    return false;
  }
}

async function runTests() {
  log('\n🧪 OpenAI Assistant API Integration Tests', 'cyan');
  log('==========================================\n', 'cyan');

  // Check if backend is running
  const isHealthy = await testHealthCheck();
  if (!isHealthy) {
    log('\n❌ Tests aborted - backend not running', 'red');
    process.exit(1);
  }

  // Test 1: Upload PDF
  const uploadResult = await testPDFUpload();
  if (!uploadResult) {
    log('\n❌ Tests aborted - PDF upload failed', 'red');
    process.exit(1);
  }

  const threadId = uploadResult.threadId;

  // Test 2: Analyze quiz
  await testQuizAnalysis(threadId);

  // Test 3: Get thread info
  await testThreadInfo(threadId);

  // Test 4: List all threads
  await testListThreads();

  // Test 5: Delete thread (optional)
  if (process.env.CLEANUP === 'true') {
    await testDeleteThread(threadId);
  } else {
    log('\n💡 Thread kept alive for manual testing', 'yellow');
    log('   To cleanup, run: CLEANUP=true node test-assistant-api.js --pdf ...', 'yellow');
    log(`   Or delete manually: curl -X DELETE ${BASE_URL}/thread/${threadId}`, 'yellow');
  }

  log('\n✅ All tests completed', 'green');
  log('\n📊 Summary:', 'cyan');
  log(`   Thread ID: ${threadId}`, 'blue');
  log(`   Assistant ID: ${uploadResult.assistantId}`, 'blue');
  log(`   Save to .env: ASSISTANT_ID=${uploadResult.assistantId}`, 'yellow');
}

// Run tests
runTests().catch(error => {
  log(`\n❌ Test suite failed: ${error.message}`, 'red');
  process.exit(1);
});
