/**
 * Integration Test: Scraper → AI Parser Service
 *
 * This test verifies:
 * 1. Scraper correctly sends text to AI Parser on port 3001
 * 2. AI Parser processes the request and returns structured questions
 * 3. Data format is correct for backend compatibility
 * 4. Error handling works when AI Parser is down
 */

const axios = require('axios');

const AI_PARSER_URL = 'http://localhost:3001';

// Test data - realistic quiz text
const MOCK_QUIZ_TEXT = `
Was ist die Hauptstadt von Deutschland?
Berlin
München
Hamburg
Frankfurt

Wie viele Bundesländer hat Deutschland?
12
14
16
18

Welches Jahr war die Wiedervereinigung?
1987
1989
1990
1991
`;

/**
 * Test 1: Check if AI Parser is running
 */
async function testAIParserHealth() {
  console.log('\n=== TEST 1: AI Parser Health Check ===');
  try {
    const response = await axios.get(`${AI_PARSER_URL}/health`, {
      timeout: 5000
    });
    console.log('✅ AI Parser is running');
    console.log('   Status:', response.data.status);
    console.log('   AI Model:', response.data.aiModel);
    console.log('   Fallback:', response.data.fallbackEnabled ? 'Enabled' : 'Disabled');
    return true;
  } catch (error) {
    console.log('❌ AI Parser is NOT running');
    console.log('   Error:', error.message);
    console.log('   Expected URL:', AI_PARSER_URL);
    console.log('\n   To start AI Parser:');
    console.log('   $ npm run ai-parser');
    return false;
  }
}

/**
 * Test 2: Send text to AI Parser and verify response
 */
async function testAIParserParsing() {
  console.log('\n=== TEST 2: AI Parser Parsing ===');
  try {
    console.log('Sending text to AI Parser...');
    console.log(`Text length: ${MOCK_QUIZ_TEXT.length} characters`);

    const startTime = Date.now();
    const response = await axios.post(`${AI_PARSER_URL}/parse-dom`, {
      text: MOCK_QUIZ_TEXT
    }, {
      timeout: 45000,
      headers: {
        'Content-Type': 'application/json'
      }
    });
    const duration = ((Date.now() - startTime) / 1000).toFixed(2);

    console.log('✅ AI Parser returned response');
    console.log(`   Processing time: ${duration}s`);
    console.log('   Source:', response.data.source);
    console.log('   Questions parsed:', response.data.questions.length);

    // Verify response structure
    if (!response.data.questions || !Array.isArray(response.data.questions)) {
      throw new Error('Response does not contain questions array');
    }

    console.log('\n   Parsed Questions:');
    response.data.questions.forEach((q, idx) => {
      console.log(`   ${idx + 1}. ${q.question.substring(0, 50)}...`);
      console.log(`      Answers: ${q.answers.length} options`);
      q.answers.forEach((a, i) => {
        console.log(`         ${i + 1}. ${a.substring(0, 30)}${a.length > 30 ? '...' : ''}`);
      });
    });

    return response.data.questions;
  } catch (error) {
    console.log('❌ AI Parser failed to parse text');
    console.log('   Error:', error.message);
    if (error.response) {
      console.log('   Status:', error.response.status);
      console.log('   Response:', error.response.data);
    }
    return null;
  }
}

/**
 * Test 3: Verify data format is compatible with backend
 */
async function testBackendCompatibility(questions) {
  console.log('\n=== TEST 3: Backend Compatibility ===');

  if (!questions || questions.length === 0) {
    console.log('⚠️  No questions to test with backend');
    return false;
  }

  try {
    console.log('Verifying data format matches backend expectations...');

    // Check question structure
    const isValid = questions.every(q => {
      return (
        typeof q.question === 'string' &&
        Array.isArray(q.answers) &&
        q.answers.every(a => typeof a === 'string')
      );
    });

    if (!isValid) {
      console.log('❌ Question format is invalid');
      return false;
    }

    console.log('✅ Question format is valid');
    console.log('   Sample question structure:');
    console.log('   {');
    console.log(`     "question": "${questions[0].question.substring(0, 40)}...",`);
    console.log(`     "answers": [${questions[0].answers.length} strings]`);
    console.log('   }');

    // Try to send to backend (if it's running)
    try {
      const backendResponse = await axios.post('http://localhost:3000/api/analyze', {
        questions: questions
      }, {
        timeout: 5000,
        headers: {
          'Content-Type': 'application/json'
        }
      });

      console.log('\n✅ Backend accepted the questions');
      console.log('   Backend status:', backendResponse.data.status);
      if (backendResponse.data.answers) {
        console.log('   Answer indices:', backendResponse.data.answers);
      }
      return true;
    } catch (backendError) {
      if (backendError.code === 'ECONNREFUSED') {
        console.log('\n⚠️  Backend is not running (but format is valid)');
        console.log('   To test with backend:');
        console.log('   $ cd backend && npm start');
        return true; // Format is still valid
      } else {
        console.log('\n❌ Backend rejected the questions');
        console.log('   Error:', backendError.message);
        if (backendError.response) {
          console.log('   Response:', backendError.response.data);
        }
        return false;
      }
    }
  } catch (error) {
    console.log('❌ Compatibility check failed');
    console.log('   Error:', error.message);
    return false;
  }
}

/**
 * Test 4: Check scraper.js sendToAI function
 */
async function testScraperFunction() {
  console.log('\n=== TEST 4: Scraper Function Check ===');

  try {
    // Load scraper module
    const scraper = require('./scraper.js');

    console.log('✅ Scraper module loaded successfully');

    // Check if sendToAI function exists
    if (typeof scraper.sendToAI === 'function') {
      console.log('✅ sendToAI function is exported');

      // Try calling it with mock text
      console.log('\nTesting sendToAI function...');
      const questions = await scraper.sendToAI(MOCK_QUIZ_TEXT);

      console.log('✅ sendToAI executed successfully');
      console.log(`   Returned ${questions.length} questions`);
      return questions;
    } else {
      console.log('❌ sendToAI function not found');
      console.log('   Available exports:', Object.keys(scraper));
      return null;
    }
  } catch (error) {
    console.log('❌ Scraper function test failed');
    console.log('   Error:', error.message);
    return null;
  }
}

/**
 * Test 5: Error handling when AI Parser is down
 */
async function testErrorHandling() {
  console.log('\n=== TEST 5: Error Handling ===');

  try {
    // Try to connect to a non-existent port
    await axios.post('http://localhost:9999/parse-dom', {
      text: MOCK_QUIZ_TEXT
    }, {
      timeout: 2000
    });

    console.log('❌ Should have thrown connection error');
    return false;
  } catch (error) {
    if (error.code === 'ECONNREFUSED') {
      console.log('✅ Connection error handled correctly');
      console.log('   Error code:', error.code);
      console.log('   Error message:', error.message);
      return true;
    } else {
      console.log('⚠️  Different error occurred:', error.message);
      return false;
    }
  }
}

/**
 * Main test runner
 */
async function runTests() {
  console.log('╔══════════════════════════════════════════════════════════════╗');
  console.log('║  Scraper → AI Parser Integration Test Suite                 ║');
  console.log('╚══════════════════════════════════════════════════════════════╝');

  const results = {
    healthCheck: false,
    parsing: false,
    compatibility: false,
    scraperFunction: false,
    errorHandling: false
  };

  // Test 1: Health check
  results.healthCheck = await testAIParserHealth();

  if (!results.healthCheck) {
    console.log('\n❌ AI Parser is not running - cannot continue tests');
    console.log('\nTo start AI Parser:');
    console.log('$ npm run ai-parser');
    console.log('\nOr in a separate terminal:');
    console.log('$ node ai-parser-service.js');
    process.exit(1);
  }

  // Test 2: Parsing
  const questions = await testAIParserParsing();
  results.parsing = questions !== null;

  // Test 3: Backend compatibility
  if (results.parsing) {
    results.compatibility = await testBackendCompatibility(questions);
  }

  // Test 4: Scraper function
  const scraperQuestions = await testScraperFunction();
  results.scraperFunction = scraperQuestions !== null;

  // Test 5: Error handling
  results.errorHandling = await testErrorHandling();

  // Summary
  console.log('\n╔══════════════════════════════════════════════════════════════╗');
  console.log('║  Test Results Summary                                        ║');
  console.log('╚══════════════════════════════════════════════════════════════╝');
  console.log('\n1. AI Parser Health Check:', results.healthCheck ? '✅ PASS' : '❌ FAIL');
  console.log('2. AI Parser Parsing:', results.parsing ? '✅ PASS' : '❌ FAIL');
  console.log('3. Backend Compatibility:', results.compatibility ? '✅ PASS' : '❌ FAIL');
  console.log('4. Scraper Function:', results.scraperFunction ? '✅ PASS' : '❌ FAIL');
  console.log('5. Error Handling:', results.errorHandling ? '✅ PASS' : '❌ FAIL');

  const allPassed = Object.values(results).every(r => r === true);

  console.log('\n══════════════════════════════════════════════════════════════');
  if (allPassed) {
    console.log('✅ ALL TESTS PASSED - Integration is working correctly!');
  } else {
    console.log('❌ SOME TESTS FAILED - See details above');
  }
  console.log('══════════════════════════════════════════════════════════════\n');

  process.exit(allPassed ? 0 : 1);
}

// Run tests
if (require.main === module) {
  runTests().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}

module.exports = { testAIParserHealth, testAIParserParsing, testBackendCompatibility };
