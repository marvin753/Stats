/**
 * Quiz DOM Scraper
 * Extracts questions and answers from the current webpage
 * Sends them to the backend for AI analysis
 *
 * Usage: node scraper.js [--url <url>]
 */

const playwright = require('playwright');
const axios = require('axios');

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';

/**
 * Scrape questions and answers from webpage
 * @param {string} url - Optional URL to scrape (uses active browser tab if not provided)
 * @returns {Promise<Array>} Array of questions with answers
 */
async function scrapeQuestions(url) {
  let browser;

  try {
    // Launch browser and connect to page
    browser = await playwright.chromium.launch();
    const context = await browser.createContext();
    const page = await context.newPage();

    if (url) {
      await page.goto(url, { waitUntil: 'networkidle' });
    } else {
      console.log('No URL provided. Scraper will try to analyze current page content.');
      // In real usage, would connect to active browser tab
      console.warn('Note: Connect scraper to active browser tab for production use');
    }

    // Extract questions and answers from DOM
    const questions = await page.evaluate(() => {
      const extractedQuestions = [];

      /**
       * Strategy 1: Look for common quiz structures
       * Targets: .question, [role="question"], etc.
       */
      const questionElements = document.querySelectorAll(
        '[class*="question"], [role="question"], .quiz-question, .q-item, .question-block'
      );

      if (questionElements.length > 0) {
        questionElements.forEach((qElement) => {
          // Extract question text
          const questionText =
            qElement.querySelector('[class*="text"], .question-text, h3, h4, p')?.textContent?.trim() ||
            qElement.textContent?.split('\n')[0]?.trim();

          if (!questionText) return;

          // Extract answer options
          const answerElements = qElement.querySelectorAll(
            '[class*="answer"], [class*="option"], [role="option"], label, .answer-item, .option-item'
          );

          const answers = Array.from(answerElements)
            .map(el => el.textContent?.trim())
            .filter(text => text && text.length > 0);

          if (answers.length > 0) {
            extractedQuestions.push({
              question: questionText,
              answers: answers
            });
          }
        });
      }

      /**
       * Strategy 2: Look for form inputs (radio buttons, checkboxes)
       */
      if (extractedQuestions.length === 0) {
        const formGroups = document.querySelectorAll(
          '[class*="form-group"], .question-container, .quiz-item'
        );

        formGroups.forEach((group) => {
          const questionText =
            group.querySelector('label, legend, .question-text')?.textContent?.trim();

          const inputs = group.querySelectorAll('input[type="radio"], input[type="checkbox"]');
          const answers = Array.from(inputs)
            .map(input => {
              const label = document.querySelector(`label[for="${input.id}"]`);
              return label?.textContent?.trim() || input.value;
            })
            .filter(text => text && text.length > 0);

          if (questionText && answers.length > 0) {
            extractedQuestions.push({
              question: questionText,
              answers: answers
            });
          }
        });
      }

      /**
       * Strategy 3: Fallback - look for any structure with <li> items
       */
      if (extractedQuestions.length === 0) {
        const listGroups = document.querySelectorAll('ul, ol');
        let currentQuestion = null;

        listGroups.forEach((list) => {
          const items = list.querySelectorAll('li');
          if (items.length >= 2) {
            const parent = list.parentElement?.textContent;
            if (parent) {
              const answers = Array.from(items).map(li => li.textContent?.trim());
              extractedQuestions.push({
                question: parent.split('\n')[0],
                answers: answers
              });
            }
          }
        });
      }

      return extractedQuestions;
    });

    console.log(`✓ Extracted ${questions.length} questions`);

    await browser.close();
    return questions;

  } catch (error) {
    console.error('Scraping error:', error.message);
    if (browser) await browser.close();
    throw error;
  }
}

/**
 * Send questions to backend for AI analysis
 * @param {Array} questions - Questions to analyze
 * @returns {Promise<Array>} Answer indices from AI
 */
async function sendToBackend(questions) {
  try {
    console.log(`\n📤 Sending ${questions.length} questions to backend...`);

    const response = await axios.post(`${BACKEND_URL}/api/analyze`, {
      questions: questions,
      timestamp: new Date().toISOString()
    }, {
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json'
      }
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
 * Main execution
 */
async function main() {
  try {
    console.log('🔍 Starting Quiz Scraper...\n');

    // Check if URL provided as argument
    const urlArg = process.argv.find(arg => arg.startsWith('--url'));
    const url = urlArg ? urlArg.split('=')[1] : null;

    if (url) {
      console.log(`📍 Target URL: ${url}`);
    }

    // Step 1: Scrape questions
    const questions = await scrapeQuestions(url);

    if (questions.length === 0) {
      console.error('❌ No questions found on page');
      process.exit(1);
    }

    console.log('\nExtracted Questions:');
    questions.forEach((q, idx) => {
      console.log(`\n${idx + 1}. ${q.question}`);
      q.answers.forEach((a, i) => {
        console.log(`   ${i + 1}. ${a}`);
      });
    });

    // Step 2: Send to backend for AI analysis
    const answers = await sendToBackend(questions);

    console.log('\n✅ Script completed successfully!');
    console.log(`Answer indices: [${answers.join(', ')}]`);

    process.exit(0);

  } catch (error) {
    console.error('\n❌ Fatal error:', error.message);
    process.exit(1);
  }
}

// Run if executed directly
if (require.main === module) {
  main();
}

module.exports = { scrapeQuestions, sendToBackend };
