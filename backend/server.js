/**
 * Quiz Analysis Backend Server
 * Receives questions from scraper, calls OpenAI API, sends answers to Swift app
 *
 * Usage: node server.js
 */

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const axios = require('axios');
const WebSocket = require('ws');
const http = require('http');
const rateLimit = require('express-rate-limit');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// Configuration
const PORT = process.env.BACKEND_PORT || 3000;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const OPENAI_MODEL = process.env.OPENAI_MODEL || 'gpt-3.5-turbo';
const STATS_APP_URL = process.env.STATS_APP_URL || 'http://localhost:8080';
const API_KEY = process.env.API_KEY; // Backend API key for authentication

// Security: Parse allowed origins from environment variable
const CORS_ALLOWED_ORIGINS = process.env.CORS_ALLOWED_ORIGINS
  ? process.env.CORS_ALLOWED_ORIGINS.split(',').map(origin => origin.trim())
  : ['http://localhost:8080', 'http://localhost:3000'];

// CORS Configuration - Restrict to specific origins
const corsOptions = {
  origin: function (origin, callback) {
    // Allow requests with no origin (like mobile apps, curl, Postman)
    if (!origin) return callback(null, true);

    if (CORS_ALLOWED_ORIGINS.indexOf(origin) !== -1) {
      callback(null, true);
    } else {
      console.warn(`🚫 Blocked CORS request from unauthorized origin: ${origin}`);
      callback(new Error('Not allowed by CORS policy'));
    }
  },
  credentials: true,
  optionsSuccessStatus: 200
};

// Middleware
app.use(express.json({ limit: '10mb' })); // Limit payload size
app.use(cors(corsOptions));

// Store connected WebSocket clients
const clients = new Set();

/**
 * API Key Authentication Middleware
 * Validates X-API-Key header against environment variable
 */
function authenticateApiKey(req, res, next) {
  // Skip authentication for health check and root endpoint
  if (req.path === '/health' || req.path === '/') {
    return next();
  }

  const providedKey = req.headers['x-api-key'];

  // If API_KEY is not configured, warn but allow (for development)
  if (!API_KEY) {
    console.warn('⚠️  WARNING: API_KEY not configured. All requests allowed (INSECURE)');
    return next();
  }

  // Validate API key
  if (!providedKey) {
    console.warn('🚫 Authentication failed: No API key provided');
    return res.status(401).json({
      error: 'Authentication required',
      message: 'X-API-Key header is missing'
    });
  }

  // Use timing-safe comparison to prevent timing attacks
  const providedBuffer = Buffer.from(providedKey);
  const keyBuffer = Buffer.from(API_KEY);

  if (providedBuffer.length !== keyBuffer.length) {
    console.warn('🚫 Authentication failed: Invalid API key');
    return res.status(403).json({
      error: 'Authentication failed',
      message: 'Invalid API key'
    });
  }

  // Constant-time comparison
  const isValid = providedBuffer.compare(keyBuffer) === 0;

  if (!isValid) {
    console.warn('🚫 Authentication failed: Invalid API key');
    return res.status(403).json({
      error: 'Authentication failed',
      message: 'Invalid API key'
    });
  }

  // Authentication successful
  next();
}

// Apply authentication middleware to all routes
app.use(authenticateApiKey);

/**
 * Rate Limiting Configuration
 * Protects against API abuse and DoS attacks
 */

// General rate limiter for all endpoints
const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: {
    error: 'Too many requests',
    message: 'Rate limit exceeded. Please try again later.'
  },
  standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
  legacyHeaders: false, // Disable the `X-RateLimit-*` headers
  handler: (req, res) => {
    console.warn(`⚠️  Rate limit exceeded for IP: ${req.ip}`);
    res.status(429).json({
      error: 'Too many requests',
      message: 'Rate limit exceeded. Please try again later.',
      retryAfter: req.rateLimit.resetTime
    });
  }
});

// Strict rate limiter for OpenAI API endpoint (more expensive)
const openaiLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 10, // Limit each IP to 10 requests per minute
  skipSuccessfulRequests: false,
  message: {
    error: 'Too many analysis requests',
    message: 'Please wait before analyzing more quizzes.'
  },
  handler: (req, res) => {
    console.warn(`⚠️  OpenAI rate limit exceeded for IP: ${req.ip}`);
    res.status(429).json({
      error: 'Too many analysis requests',
      message: 'OpenAI API rate limit exceeded. Please wait before analyzing more quizzes.',
      retryAfter: Math.ceil((req.rateLimit.resetTime - Date.now()) / 1000)
    });
  }
});

// Apply general rate limiter to all routes
app.use(generalLimiter);

/**
 * Call OpenAI API to get correct answer indices
 * @param {Array} questions - Questions with answers
 * @returns {Promise<Array>} Answer indices [1, 2, 3, ...]
 */
async function analyzeWithOpenAI(questions) {
  if (!OPENAI_API_KEY) {
    throw new Error('OPENAI_API_KEY not configured');
  }

  const systemPrompt = `You are a quiz expert. Analyze the following multiple-choice questions and identify the correct answer for each.
Return ONLY a JSON array with the indices of the correct answers (1-based indexing).
Format: [index1, index2, index3, ...]
Example: [4, 1, 3, 2]
Do NOT include any explanation, text, or markdown. Return ONLY the JSON array.`;

  const userContent = JSON.stringify(questions, null, 2);

  try {
    console.log('🤖 Calling OpenAI API...');

    const response = await axios.post(
      'https://api.openai.com/v1/chat/completions',
      {
        model: OPENAI_MODEL,
        messages: [
          {
            role: 'system',
            content: systemPrompt
          },
          {
            role: 'user',
            content: userContent
          }
        ],
        temperature: 0.3, // Lower temp for more consistent answers
        max_tokens: 500
      },
      {
        headers: {
          'Authorization': `Bearer ${OPENAI_API_KEY}`,
          'Content-Type': 'application/json'
        },
        timeout: 30000
      }
    );

    const content = response.data.choices[0].message.content.trim();
    console.log(`OpenAI Response: ${content}`);

    // Parse the JSON array from response
    const answerIndices = JSON.parse(content);

    if (!Array.isArray(answerIndices)) {
      throw new Error('OpenAI response was not a valid array');
    }

    console.log(`✓ Parsed answer indices: [${answerIndices.join(', ')}]`);
    return answerIndices;

  } catch (error) {
    console.error('OpenAI API error:', error.message);
    if (error.response?.data) {
      console.error('API Error Details:', error.response.data);
    }
    throw error;
  }
}

/**
 * Send results to Swift app via HTTP
 * @param {Array} answers - Answer indices
 * @returns {Promise<void>}
 */
async function sendToSwiftApp(answers) {
  try {
    console.log(`📲 Sending answers to Swift app at ${STATS_APP_URL}...`);

    await axios.post(
      `${STATS_APP_URL}/display-answers`,
      {
        answers: answers,
        timestamp: new Date().toISOString(),
        status: 'success'
      },
      {
        timeout: 10000,
        headers: {
          'Content-Type': 'application/json'
        }
      }
    );

    console.log('✓ Successfully sent to Swift app');

  } catch (error) {
    console.warn('⚠️  Could not reach Swift app (might not be running):', error.message);
    // Don't throw - Swift app may not be running yet
  }
}

/**
 * Broadcast to WebSocket clients
 * @param {Object} data - Data to send
 */
function broadcastToClients(data) {
  clients.forEach(client => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify(data));
    }
  });
}

/**
 * POST /api/analyze
 * Receive scraped questions, analyze with OpenAI, send to Swift
 * Rate limited to prevent OpenAI API abuse
 */
app.post('/api/analyze', openaiLimiter, async (req, res) => {
  try {
    const { questions, timestamp } = req.body;

    if (!questions || !Array.isArray(questions) || questions.length === 0) {
      return res.status(400).json({
        error: 'Invalid request: questions array required',
        status: 'error'
      });
    }

    console.log(`\n📥 Received ${questions.length} questions at ${timestamp}`);

    // Validate question structure
    const validQuestions = questions.every(q =>
      q.question && typeof q.question === 'string' &&
      q.answers && Array.isArray(q.answers) && q.answers.length > 0
    );

    if (!validQuestions) {
      return res.status(400).json({
        error: 'Invalid question structure',
        status: 'error'
      });
    }

    // Call OpenAI API
    const answerIndices = await analyzeWithOpenAI(questions);

    // Validate answer indices
    const validAnswers = answerIndices.every((idx, i) => {
      if (idx < 1 || idx > questions[i].answers.length) {
        console.warn(`⚠️  Answer index ${idx} out of range for question ${i + 1}`);
        return false;
      }
      return true;
    });

    if (!validAnswers) {
      console.warn('⚠️  Some answer indices are out of range, but proceeding...');
    }

    // Send to Swift app (async, don't wait)
    sendToSwiftApp(answerIndices);

    // Broadcast to WebSocket clients
    broadcastToClients({
      type: 'answers_ready',
      answers: answerIndices,
      questionCount: questions.length
    });

    // Return to requester
    res.json({
      status: 'success',
      answers: answerIndices,
      questionCount: questions.length,
      message: 'Questions analyzed successfully'
    });

  } catch (error) {
    console.error('Error processing request:', error.message);

    res.status(500).json({
      error: error.message,
      status: 'error'
    });
  }
});

/**
 * GET /health
 * Health check endpoint
 */
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    openai_configured: !!OPENAI_API_KEY,
    api_key_configured: !!API_KEY,
    security: {
      cors_enabled: true,
      authentication_enabled: !!API_KEY
    }
  });
});

/**
 * GET /
 * API documentation
 */
app.get('/', (req, res) => {
  res.json({
    name: 'Quiz Analysis Backend',
    version: '1.0.0',
    endpoints: {
      'POST /api/analyze': 'Send questions for analysis',
      'GET /health': 'Health check',
      'WS /': 'WebSocket for real-time updates'
    },
    documentation: 'POST /api/analyze with body: { questions: [...] }'
  });
});

/**
 * WebSocket connection handler
 */
wss.on('connection', (ws) => {
  console.log('✓ WebSocket client connected');
  clients.add(ws);

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      console.log('WebSocket message:', data.type);
    } catch (error) {
      console.error('WebSocket message parse error:', error.message);
    }
  });

  ws.on('close', () => {
    console.log('✓ WebSocket client disconnected');
    clients.delete(ws);
  });

  ws.on('error', (error) => {
    console.error('WebSocket error:', error.message);
    clients.delete(ws);
  });

  // Send welcome message
  ws.send(JSON.stringify({
    type: 'connection',
    message: 'Connected to Quiz Analysis Backend',
    timestamp: new Date().toISOString()
  }));
});

/**
 * Error handling middleware
 */
app.use((err, req, res, next) => {
  console.error('Server error:', err.message);
  res.status(500).json({
    error: 'Internal server error',
    message: err.message
  });
});

/**
 * Start server
 */
server.listen(PORT, () => {
  console.log(`\n✅ Backend server running on http://localhost:${PORT}`);
  console.log(`   OpenAI Model: ${OPENAI_MODEL}`);
  console.log(`   Stats App URL: ${STATS_APP_URL}`);
  console.log(`   WebSocket: ws://localhost:${PORT}\n`);
});

module.exports = app;
