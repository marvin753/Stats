/**
 * AI Parser Service
 *
 * Uses CodeLlama 13B (via Ollama) to intelligently parse quiz questions
 * from structured text with OpenAI GPT-3.5-turbo as fallback.
 *
 * Port: 3001
 * Framework: Express.js
 * Primary AI: CodeLlama 13B via Ollama (http://localhost:11434)
 * Fallback AI: OpenAI GPT-3.5-turbo
 */

require('dotenv').config({ path: '.env.ai-parser' });
const express = require('express');
const axios = require('axios');
const cors = require('cors');

// Configuration
const PORT = process.env.PORT || 3001;
const OLLAMA_URL = process.env.OLLAMA_URL || 'http://localhost:11434';
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const AI_TIMEOUT = parseInt(process.env.AI_TIMEOUT) || 30000;
const USE_OPENAI_FALLBACK = process.env.USE_OPENAI_FALLBACK === 'true';

// Initialize Express app
const app = express();

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Logging middleware
app.use((req, res, next) => {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${req.method} ${req.path}`);
  next();
});

/**
 * CodeLlama prompt template
 */
const CODELLAMA_PROMPT = (text) => `You are a quiz parser AI. Extract questions and answers from the following text.
The text is from a webpage quiz and may have German text.

IMPORTANT RULES:
1. Match each question with its closest answer options in the DOM structure
2. Even if answer options don't seem related, include them if they are structurally close
3. Return ONLY valid JSON array, no explanations
4. Format: [{"question": "text", "answers": ["A", "B", "C", "D"]}]

Text:
${text}

Return JSON array:`;

/**
 * OpenAI prompt template (same as CodeLlama)
 */
const OPENAI_PROMPT = (text) => `You are a quiz parser AI. Extract questions and answers from the following text.
The text is from a webpage quiz and may have German text.

IMPORTANT RULES:
1. Match each question with its closest answer options in the DOM structure
2. Even if answer options don't seem related, include them if they are structurally close
3. Return ONLY valid JSON array, no explanations
4. Format: [{"question": "text", "answers": ["A", "B", "C", "D"]}]

Text:
${text}

Return JSON array:`;

/**
 * Call CodeLlama via Ollama
 * @param {string} text - Text to parse
 * @returns {Promise<Array>} - Parsed questions
 */
async function parseWithCodeLlama(text) {
  const startTime = Date.now();

  try {
    console.log('Attempting to parse with CodeLlama 13B...');

    const response = await axios.post(
      `${OLLAMA_URL}/api/generate`,
      {
        model: 'codellama:13b-instruct',
        prompt: CODELLAMA_PROMPT(text),
        stream: false,
        options: {
          temperature: 0.1,
          num_predict: 2000
        }
      },
      {
        timeout: AI_TIMEOUT,
        headers: {
          'Content-Type': 'application/json'
        }
      }
    );

    const processingTime = ((Date.now() - startTime) / 1000).toFixed(2);
    console.log(`CodeLlama response received in ${processingTime}s`);

    // Extract the generated text
    const generatedText = response.data.response || '';

    // Try to parse JSON from response
    const questions = parseJSONResponse(generatedText);

    if (!questions || questions.length === 0) {
      throw new Error('CodeLlama returned empty or invalid JSON');
    }

    console.log(`CodeLlama successfully parsed ${questions.length} questions`);

    return {
      questions,
      source: 'codellama',
      processingTime: parseFloat(processingTime)
    };

  } catch (error) {
    const processingTime = ((Date.now() - startTime) / 1000).toFixed(2);

    if (error.code === 'ECONNREFUSED') {
      console.error('CodeLlama connection refused - is Ollama running?');
      throw new Error('Ollama not available');
    }

    if (error.code === 'ETIMEDOUT' || error.message.includes('timeout')) {
      console.error(`CodeLlama timeout after ${processingTime}s`);
      throw new Error('CodeLlama timeout');
    }

    console.error('CodeLlama error:', error.message);
    throw error;
  }
}

/**
 * Call OpenAI GPT-3.5-turbo as fallback
 * @param {string} text - Text to parse
 * @returns {Promise<Array>} - Parsed questions
 */
async function parseWithOpenAI(text) {
  const startTime = Date.now();

  if (!OPENAI_API_KEY) {
    throw new Error('OpenAI API key not configured');
  }

  try {
    console.log('Attempting to parse with OpenAI GPT-3.5-turbo...');

    const response = await axios.post(
      'https://api.openai.com/v1/chat/completions',
      {
        model: 'gpt-3.5-turbo',
        messages: [
          {
            role: 'system',
            content: 'You are a quiz parser. Return ONLY valid JSON array, no explanations.'
          },
          {
            role: 'user',
            content: OPENAI_PROMPT(text)
          }
        ],
        temperature: 0.1,
        max_tokens: 2000
      },
      {
        timeout: AI_TIMEOUT,
        headers: {
          'Authorization': `Bearer ${OPENAI_API_KEY}`,
          'Content-Type': 'application/json'
        }
      }
    );

    const processingTime = ((Date.now() - startTime) / 1000).toFixed(2);
    console.log(`OpenAI response received in ${processingTime}s`);

    // Extract the generated text
    const generatedText = response.data.choices[0].message.content || '';

    // Try to parse JSON from response
    const questions = parseJSONResponse(generatedText);

    if (!questions || questions.length === 0) {
      throw new Error('OpenAI returned empty or invalid JSON');
    }

    console.log(`OpenAI successfully parsed ${questions.length} questions`);

    return {
      questions,
      source: 'openai',
      processingTime: parseFloat(processingTime)
    };

  } catch (error) {
    const processingTime = ((Date.now() - startTime) / 1000).toFixed(2);

    if (error.response?.status === 401) {
      console.error('OpenAI authentication failed - invalid API key');
      throw new Error('Invalid OpenAI API key');
    }

    if (error.response?.status === 429) {
      console.error('OpenAI rate limit exceeded');
      throw new Error('OpenAI rate limit exceeded');
    }

    if (error.code === 'ETIMEDOUT' || error.message.includes('timeout')) {
      console.error(`OpenAI timeout after ${processingTime}s`);
      throw new Error('OpenAI timeout');
    }

    console.error('OpenAI error:', error.message);
    throw error;
  }
}

/**
 * Parse JSON from AI response
 * Handles various response formats and extracts JSON array
 * @param {string} text - AI response text
 * @returns {Array|null} - Parsed questions or null
 */
function parseJSONResponse(text) {
  try {
    // Remove markdown code blocks if present
    let cleanedText = text.trim();

    // Remove ```json and ``` markers
    cleanedText = cleanedText.replace(/```json\s*/g, '');
    cleanedText = cleanedText.replace(/```\s*/g, '');

    // Find JSON array in the text
    const arrayMatch = cleanedText.match(/\[[\s\S]*\]/);
    if (arrayMatch) {
      cleanedText = arrayMatch[0];
    }

    // Parse JSON
    const parsed = JSON.parse(cleanedText);

    // Validate structure
    if (!Array.isArray(parsed)) {
      console.error('Response is not an array');
      return null;
    }

    // Validate each question object
    const validQuestions = parsed.filter(q => {
      return q.question &&
             Array.isArray(q.answers) &&
             q.answers.length > 0;
    });

    return validQuestions;

  } catch (error) {
    console.error('JSON parsing failed:', error.message);
    console.error('Raw text:', text.substring(0, 200));
    return null;
  }
}

/**
 * Validate request body
 * @param {Object} body - Request body
 * @returns {Object|null} - Validation result
 */
function validateRequest(body) {
  if (!body || typeof body !== 'object') {
    return { valid: false, error: 'Request body must be JSON object' };
  }

  if (!body.text || typeof body.text !== 'string') {
    return { valid: false, error: 'Missing or invalid "text" field' };
  }

  if (body.text.length === 0) {
    return { valid: false, error: 'Text field cannot be empty' };
  }

  if (body.text.length > 50000) {
    return { valid: false, error: 'Text field too large (max 50000 characters)' };
  }

  return { valid: true };
}

/**
 * Main parsing endpoint
 * POST /parse-dom
 */
app.post('/parse-dom', async (req, res) => {
  const startTime = Date.now();

  try {
    // Validate request
    const validation = validateRequest(req.body);
    if (!validation.valid) {
      return res.status(400).json({
        status: 'error',
        error: validation.error
      });
    }

    const { text } = req.body;

    console.log(`Processing ${text.length} characters of text...`);

    let result;
    let usedFallback = false;

    // Try CodeLlama first
    try {
      result = await parseWithCodeLlama(text);
    } catch (codeLlamaError) {
      console.error('CodeLlama failed:', codeLlamaError.message);

      // Try OpenAI fallback if enabled
      if (USE_OPENAI_FALLBACK && OPENAI_API_KEY) {
        console.log('Falling back to OpenAI...');
        usedFallback = true;

        try {
          result = await parseWithOpenAI(text);
        } catch (openAIError) {
          console.error('OpenAI fallback also failed:', openAIError.message);

          return res.status(500).json({
            status: 'error',
            error: 'Both CodeLlama and OpenAI failed',
            details: {
              codellama: codeLlamaError.message,
              openai: openAIError.message
            }
          });
        }
      } else {
        return res.status(500).json({
          status: 'error',
          error: 'CodeLlama failed and no fallback available',
          details: codeLlamaError.message
        });
      }
    }

    const totalTime = ((Date.now() - startTime) / 1000).toFixed(2);

    console.log(`Success! Parsed ${result.questions.length} questions using ${result.source} in ${totalTime}s`);

    res.json({
      status: 'success',
      questions: result.questions,
      source: result.source,
      processingTime: parseFloat(totalTime),
      usedFallback
    });

  } catch (error) {
    const totalTime = ((Date.now() - startTime) / 1000).toFixed(2);

    console.error('Unexpected error:', error);

    res.status(500).json({
      status: 'error',
      error: 'Internal server error',
      message: error.message,
      processingTime: parseFloat(totalTime)
    });
  }
});

/**
 * Health check endpoint
 * GET /health
 */
app.get('/health', async (req, res) => {
  const health = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    service: 'ai-parser-service',
    port: PORT,
    configuration: {
      ollama_url: OLLAMA_URL,
      openai_configured: !!OPENAI_API_KEY,
      fallback_enabled: USE_OPENAI_FALLBACK,
      timeout: AI_TIMEOUT
    }
  };

  // Check Ollama availability
  try {
    await axios.get(`${OLLAMA_URL}/api/tags`, { timeout: 5000 });
    health.ollama_status = 'available';
  } catch (error) {
    health.ollama_status = 'unavailable';
    health.ollama_error = error.message;
  }

  res.json(health);
});

/**
 * Root endpoint
 * GET /
 */
app.get('/', (req, res) => {
  res.json({
    service: 'AI Parser Service',
    version: '1.0.0',
    endpoints: {
      'POST /parse-dom': 'Parse quiz questions from text',
      'GET /health': 'Health check',
      'GET /': 'This message'
    },
    documentation: 'Send POST request to /parse-dom with {"text": "..."}'
  });
});

/**
 * 404 handler
 */
app.use((req, res) => {
  res.status(404).json({
    status: 'error',
    error: 'Endpoint not found',
    available_endpoints: ['POST /parse-dom', 'GET /health', 'GET /']
  });
});

/**
 * Global error handler
 */
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);

  res.status(500).json({
    status: 'error',
    error: 'Internal server error',
    message: err.message
  });
});

/**
 * Start server
 */
app.listen(PORT, () => {
  console.log('='.repeat(60));
  console.log('AI Parser Service');
  console.log('='.repeat(60));
  console.log(`Server running on: http://localhost:${PORT}`);
  console.log(`Ollama URL: ${OLLAMA_URL}`);
  console.log(`OpenAI configured: ${!!OPENAI_API_KEY ? 'Yes' : 'No'}`);
  console.log(`Fallback enabled: ${USE_OPENAI_FALLBACK ? 'Yes' : 'No'}`);
  console.log(`AI timeout: ${AI_TIMEOUT}ms`);
  console.log('='.repeat(60));
  console.log('Endpoints:');
  console.log(`  POST http://localhost:${PORT}/parse-dom`);
  console.log(`  GET  http://localhost:${PORT}/health`);
  console.log('='.repeat(60));
  console.log('Ready to parse quiz questions!');
  console.log('='.repeat(60));
});

// Handle graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully...');
  process.exit(0);
});
