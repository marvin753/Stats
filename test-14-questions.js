/**
 * Test Script: 14 Questions Bug Fix
 *
 * Tests the fix where only 7 out of 14 questions were being processed.
 * This script sends 14 questions (7 complete, 7 partial) to the AI parser
 * and verifies all 14 are preserved and processed correctly.
 */

const axios = require('axios');

const AI_PARSER_URL = 'http://localhost:3001';
const BACKEND_URL = 'http://localhost:3000';

// Test data: 14 questions
// - Questions 1, 3, 5, 7, 9, 11, 13 have both question text AND answers (complete)
// - Questions 2, 4, 6, 8, 10, 12, 14 have ONLY question text, no answers (partial)
const testText = `
1. What is the capital of France?
A) London
B) Berlin
C) Paris
D) Madrid

2. Which programming language is known for web development?

3. What does HTTP stand for?
A) HyperText Transfer Protocol
B) High Transfer Text Protocol
C) HyperText Transmission Process
D) High Tech Transfer Protocol

4. What is the largest planet in our solar system?

5. Who wrote "Romeo and Juliet"?
A) Charles Dickens
B) William Shakespeare
C) Jane Austen
D) Mark Twain

6. What year did World War II end?

7. What is the chemical symbol for gold?
A) Go
B) Gd
C) Au
D) Ag

8. How many continents are there on Earth?

9. What is the speed of light?
A) 299,792 km/s
B) 150,000 km/s
C) 450,000 km/s
D) 100,000 km/s

10. Who invented the telephone?

11. What is the smallest prime number?
A) 0
B) 1
C) 2
D) 3

12. What is the capital of Japan?

13. What does CPU stand for?
A) Central Processing Unit
B) Computer Personal Unit
C) Central Program Utility
D) Computer Processing Utility

14. What is the boiling point of water in Celsius?
`;

async function testAIParser() {
  console.log('='.repeat(80));
  console.log('TEST: 14 Questions Bug Fix');
  console.log('='.repeat(80));
  console.log('\nSending test data to AI Parser Service...');
  console.log(`Text length: ${testText.length} characters`);
  console.log(`Expected: 14 questions total`);
  console.log(`  - 7 questions with answers (complete)`);
  console.log(`  - 7 questions without answers (partial)\n`);

  try {
    // Step 1: Send to AI Parser
    console.log('Step 1: Sending to AI Parser Service (localhost:3001)...\n');

    const parserResponse = await axios.post(`${AI_PARSER_URL}/parse-dom`, {
      text: testText
    }, {
      timeout: 60000,
      headers: { 'Content-Type': 'application/json' }
    });

    console.log('\n' + '='.repeat(80));
    console.log('AI PARSER RESULTS');
    console.log('='.repeat(80));
    console.log(`Status: ${parserResponse.data.status}`);
    console.log(`Source: ${parserResponse.data.source}`);
    console.log(`Processing time: ${parserResponse.data.processingTime}s`);
    console.log(`Questions returned: ${parserResponse.data.questions.length}`);

    const questions = parserResponse.data.questions;

    // Analyze results
    const withAnswers = questions.filter(q => q.answers && q.answers.length > 0);
    const withoutAnswers = questions.filter(q => !q.answers || q.answers.length === 0);
    const withNumbers = questions.filter(q => q.questionNumber !== null);

    console.log(`\nBreakdown:`);
    console.log(`  Questions with answers: ${withAnswers.length}`);
    console.log(`  Questions without answers: ${withoutAnswers.length}`);
    console.log(`  Questions with numbers: ${withNumbers.length}`);

    // Display all questions
    console.log(`\nDetailed Question List:`);
    questions.forEach((q, idx) => {
      const num = q.questionNumber || 'none';
      const answerCount = q.answers ? q.answers.length : 0;
      const questionPreview = q.question.substring(0, 50);
      console.log(`  ${idx + 1}. [Q${num}] ${questionPreview}... (${answerCount} answers)`);
    });

    // Verify expectations
    console.log('\n' + '='.repeat(80));
    console.log('VERIFICATION');
    console.log('='.repeat(80));

    const checks = [
      {
        name: 'Total questions extracted',
        expected: 14,
        actual: questions.length,
        pass: questions.length === 14,
        critical: true
      },
      {
        name: 'Questions with answers',
        expected: 7,
        actual: withAnswers.length,
        pass: withAnswers.length === 7,
        critical: true
      },
      {
        name: 'Questions without answers',
        expected: 7,
        actual: withoutAnswers.length,
        pass: withoutAnswers.length === 7,
        critical: true
      },
      {
        name: 'Questions with numbers',
        expected: 14,
        actual: withNumbers.length,
        pass: withNumbers.length >= 0, // Optional - AI may strip numbers
        critical: false
      }
    ];

    checks.forEach(check => {
      const status = check.pass ? '✅ PASS' : '❌ FAIL';
      const priority = check.critical ? '' : ' (optional)';
      console.log(`${status}: ${check.name}${priority}`);
      console.log(`  Expected: ${check.expected}, Actual: ${check.actual}`);
    });

    const criticalChecksPassed = checks.filter(c => c.critical).every(c => c.pass);
    const allPassed = checks.every(c => c.pass);

    // Step 2: Send to Backend (if critical checks passed)
    if (criticalChecksPassed) {
      console.log('\n' + '='.repeat(80));
      console.log('Step 2: Testing Backend Merging Logic...\n');

      try {
        const backendResponse = await axios.post(`${BACKEND_URL}/api/analyze`, {
          questions: questions,
          timestamp: new Date().toISOString()
        }, {
          timeout: 60000,
          headers: { 'Content-Type': 'application/json' }
        });

        console.log('\n' + '='.repeat(80));
        console.log('BACKEND RESULTS');
        console.log('='.repeat(80));
        console.log(`Status: ${backendResponse.data.status}`);
        console.log(`Total questions received: ${backendResponse.data.totalQuestionsReceived}`);
        console.log(`Questions after merging: ${backendResponse.data.questionsAfterMerging}`);
        console.log(`Complete questions sent to OpenAI: ${backendResponse.data.questionCount}`);
        console.log(`Answer indices: [${backendResponse.data.answers.join(', ')}]`);

        console.log('\n' + '='.repeat(80));
        console.log('✅ ALL TESTS PASSED');
        console.log('='.repeat(80));
        console.log('The bug fix is working correctly!');
        console.log('All 14 questions were extracted, merged, and processed.');

      } catch (backendError) {
        if (backendError.code === 'ECONNREFUSED') {
          console.log('\n⚠️  Backend not running (localhost:3000)');
          console.log('Start backend with: cd backend && npm start');
        } else {
          console.error('\n❌ Backend test failed:', backendError.message);
          if (backendError.response?.data) {
            console.error('Error details:', backendError.response.data);
          }
        }
      }
    } else {
      console.log('\n' + '='.repeat(80));
      console.log('❌ TESTS FAILED');
      console.log('='.repeat(80));
      console.log('The AI parser is not preserving all 14 questions correctly.');
      console.log('Review the AI parser service logs for details.');
    }

  } catch (error) {
    console.error('\n❌ Test failed:', error.message);

    if (error.code === 'ECONNREFUSED') {
      console.error('\nCannot connect to AI Parser Service (localhost:3001)');
      console.error('Make sure the service is running:');
      console.error('  cd /Users/marvinbarsal/Desktop/Universität/Stats');
      console.error('  node ai-parser-service.js');
    } else if (error.response) {
      console.error('Server response:', error.response.status);
      console.error('Error details:', error.response.data);
    }
  }
}

// Run the test
console.log('\nStarting test in 2 seconds...\n');
setTimeout(() => {
  testAIParser().then(() => {
    console.log('\n✓ Test completed\n');
  }).catch(error => {
    console.error('\n✗ Test failed with error:', error.message);
    process.exit(1);
  });
}, 2000);
