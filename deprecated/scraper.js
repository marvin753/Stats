/**
 * Quiz DOM Scraper
 * Extracts questions and answers from the current webpage
 * Sends them to the backend for AI analysis
 *
 * Usage: node scraper.js [--url <url>]
 */

const playwright = require('playwright');
const axios = require('axios');
const { URL } = require('url');

const AI_PARSER_URL = process.env.AI_PARSER_URL || 'http://localhost:3001';
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';
const BACKEND_API_KEY = process.env.BACKEND_API_KEY; // API key for backend authentication

/**
 * Extract structured text from page with DOM hierarchy preserved
 * Focuses on headings and their following content
 * @param {Page} page - Playwright page object
 * @returns {Promise<string>} Extracted text with structure
 */
async function extractStructuredText(page) {
  return await page.evaluate(() => {
    // Find main content area (Moodle typically uses main, .content, or #region-main)
    const mainContent =
      document.querySelector('main') ||
      document.querySelector('[role="main"]') ||
      document.querySelector('.content') ||
      document.querySelector('#content') ||
      document.querySelector('#region-main') ||
      document.body;

    // Extract text with structure preserved
    const textBlocks = [];

    // Look for question headings (Moodle uses h3, h4 for questions)
    const headings = mainContent.querySelectorAll('h3, h4, .qtext, .question-text');

    if (headings.length > 0) {
      // Extract each question block
      headings.forEach((heading) => {
        let blockText = heading.textContent.trim() + '\n\n';

        // Get all following siblings until next heading
        let next = heading.nextElementSibling;
        while (next && !next.matches('h3, h4, .qtext, .question-text')) {
          const text = next.textContent.trim();
          if (text) {
            blockText += text + '\n';
          }
          next = next.nextElementSibling;
        }

        if (blockText.trim()) {
          textBlocks.push(blockText.trim());
        }
      });
    } else {
      // Fallback: get all text from main content
      textBlocks.push(mainContent.textContent.trim());
    }

    // Join blocks with separator
    return textBlocks.join('\n\n---\n\n');
  });
}

/**
 * Extract text from webpage (no complex parsing, just text)
 * @param {string} url - URL to scrape
 * @returns {Promise<string>} Extracted text with structure preserved
 */
async function extractText(url) {
  let browser;

  try {
    if (url) {
      console.log(`📍 Target URL: ${url}`);
    }

    // Launch browser and connect to page
    browser = await playwright.chromium.launch({ headless: true });
    const context = await browser.createContext();
    const page = await context.newPage();

    if (url) {
      console.log('🌐 Loading page...');
      await page.goto(url, {
        waitUntil: 'networkidle',
        timeout: 30000 // 30 second timeout
      });
      console.log('✓ Page loaded');
    } else {
      console.log('No URL provided.');
      await browser.close();
      throw new Error('URL is required');
    }

    // Extract structured text from DOM
    console.log('📄 Extracting text from page...');
    const extractedText = await extractStructuredText(page);
    console.log(`✓ Extracted ${extractedText.length} characters of text`);

    await browser.close();
    return extractedText;

  } catch (error) {
    console.error('Text extraction error:', error.message);
    if (browser) await browser.close();
    throw error;
  }
}

/**
 * Send text to AI parser service for structured Q&A extraction
 * @param {string} text - Raw text from webpage
 * @returns {Promise<Array>} Array of structured questions with answers
 */
async function sendToAI(text) {
  try {
    console.log('\n🤖 Sending text to AI parser service...');
    console.log(`   Text length: ${text.length} characters`);

    const response = await axios.post(`${AI_PARSER_URL}/parse-dom`, {
      text: text
    }, {
      timeout: 45000, // 45 seconds for AI processing
      headers: {
        'Content-Type': 'application/json'
      }
    });

    console.log('✓ AI parser response received');
    console.log(`   Source: ${response.data.source}`);
    console.log(`   Processing time: ${response.data.processingTime}s`);
    console.log(`   Questions parsed: ${response.data.questions.length}`);

    return response.data.questions;

  } catch (error) {
    console.error('AI parser error:', error.message);
    throw error;
  }
}

/**
 * Send questions to backend for OpenAI answer analysis
 * @param {Array} questions - Questions to analyze
 * @returns {Promise<Array>} Answer indices from AI
 */
async function sendToBackend(questions) {
  try {
    console.log(`\n📤 Sending ${questions.length} questions to backend for answer analysis...`);

    // Prepare headers with API key if configured
    const headers = {
      'Content-Type': 'application/json'
    };

    if (BACKEND_API_KEY) {
      headers['X-API-Key'] = BACKEND_API_KEY;
      console.log('🔑 Using API key for authentication');
    }

    const response = await axios.post(`${BACKEND_URL}/api/analyze`, {
      questions: questions,
      timestamp: new Date().toISOString()
    }, {
      timeout: 30000,
      headers: headers
    });

    console.log('✓ Backend response received');
    console.log(`✓ Answer indices: [${response.data.answers.join(', ')}]`);

    return response.data.answers;

  } catch (error) {
    console.error('Backend communication error:', error.message);
    throw error;
  }
}

/**
 * Main execution - New AI-powered workflow
 */
async function main() {
  try {
    console.log('🔍 Starting Quiz Scraper (AI-powered)...\n');

    // Check if URL provided as argument
    const urlArg = process.argv.find(arg => arg.startsWith('--url'));
    const url = urlArg ? urlArg.split('=')[1] : null;

    if (!url) {
      console.error('❌ No URL provided. Usage: node scraper.js --url=<url>');
      process.exit(1);
    }

    // Step 1: Extract simple text from webpage
    console.log('Step 1: Extracting text from page...');
    const extractedText = await extractText(url);

    if (!extractedText || extractedText.trim().length === 0) {
      console.error('❌ No text extracted from page');
      process.exit(1);
    }

    console.log('\n--- Extracted Text Preview (first 500 chars) ---');
    console.log(extractedText.substring(0, 500) + '...\n');

    // Step 2: Send text to AI parser for structured Q&A extraction
    console.log('Step 2: Parsing questions with AI...');
    const questions = await sendToAI(extractedText);

    if (questions.length === 0) {
      console.error('❌ AI could not parse any questions from the text');
      process.exit(1);
    }

    console.log('\n--- AI Parsed Questions ---');
    questions.forEach((q, idx) => {
      console.log(`\n${idx + 1}. ${q.question}`);
      q.answers.forEach((a, i) => {
        console.log(`   ${i + 1}. ${a}`);
      });
    });

    // Step 3: Send structured questions to backend for answer analysis
    console.log('\nStep 3: Analyzing answers with OpenAI...');
    const answers = await sendToBackend(questions);

    console.log('\n✅ Script completed successfully!');
    console.log(`\n🎯 Final Results:`);
    console.log(`   Questions parsed: ${questions.length}`);
    console.log(`   Answer indices: [${answers.join(', ')}]`);
    console.log(`\nNote: Backend should forward answers to Swift app on port 8080`);

    process.exit(0);

  } catch (error) {
    console.error('\n❌ Fatal error:', error.message);
    if (error.stack) {
      console.error('Stack trace:', error.stack);
    }
    process.exit(1);
  }
}

// Run if executed directly
if (require.main === module) {
  main();
}

module.exports = { extractText, sendToAI, sendToBackend, extractStructuredText };
