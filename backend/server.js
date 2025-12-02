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
const multer = require('multer');
const fs = require('fs');
const path = require('path');

const app = express();
const server = http.createServer(app);

// Only create WebSocket server if not in test mode
let wss;
if (process.env.NODE_ENV !== 'test') {
  wss = new WebSocket.Server({ server });
}

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

// Apply general rate limiter to all routes (disabled in test mode)
if (process.env.NODE_ENV !== 'test') {
  app.use(generalLimiter);
}

// ============== PDF HANDLING SETUP ==============

// Multer configuration for multipart upload (Safeguard 3 & 10)
const upload = multer({
    limits: { fileSize: 50 * 1024 * 1024 }, // 50MB max
    storage: multer.memoryStorage(),
    fileFilter: (req, file, cb) => {
        if (file.mimetype === 'application/pdf') {
            cb(null, true);
        } else {
            cb(new Error('Only PDF files are allowed'), false);
        }
    }
});

// Reference file cache (Safeguard 3: Persistent storage)
const CACHE_FILE = path.join(__dirname, 'reference-cache.json');
let referenceFileCache = {
    fileId: null,
    filename: null,
    uploadedAt: null,
    fileSizeBytes: null
};

// Load cache on startup
function loadReferenceCache() {
    try {
        if (fs.existsSync(CACHE_FILE)) {
            const data = fs.readFileSync(CACHE_FILE, 'utf8');
            referenceFileCache = JSON.parse(data);
            console.log(`✅ Loaded reference cache: ${referenceFileCache.filename || 'none'}`);
        }
    } catch (error) {
        console.log('⚠️ No existing reference cache found');
    }
}

// Save cache to disk
function saveReferenceCache() {
    try {
        fs.writeFileSync(CACHE_FILE, JSON.stringify(referenceFileCache, null, 2));
        console.log('✅ Reference cache saved');
    } catch (error) {
        console.error('❌ Failed to save reference cache:', error.message);
    }
}

// Load cache on startup
loadReferenceCache();

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
    console.log(`🤖 Calling OpenAI API (model: ${OPENAI_MODEL})...`);

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

    // Parse the JSON array from response
    const answerIndices = JSON.parse(content);

    if (!Array.isArray(answerIndices)) {
      throw new Error('OpenAI response was not a valid array');
    }

    console.log(`✅ OpenAI Response: [${answerIndices.join(', ')}]`);
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
    console.log(`📤 Sending answers to Stats app (${STATS_APP_URL})...`);

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

    console.log('✓ Successfully sent to Stats app\n');

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

    console.log(`\n📥 Received ${questions.length} questions for analysis`);

    // Show question preview (first 2)
    if (questions.length > 0) {
      console.log(`\n   Question preview:`);
      questions.slice(0, Math.min(2, questions.length)).forEach((q, i) => {
        const preview = q.question.length > 60 ? q.question.substring(0, 60) + '...' : q.question;
        console.log(`   ${i + 1}. ${preview}`);
      });
      if (questions.length > 2) {
        console.log(`   ... and ${questions.length - 2} more questions\n`);
      }
    }

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

// ============== NEW PDF ENDPOINTS ==============

/**
 * POST /api/upload-reference
 * Upload PDF reference file
 */
app.post('/api/upload-reference', upload.single('pdf'), async (req, res) => {
    console.log('\n📄 [upload-reference] Processing PDF upload...');

    try {
        if (!req.file) {
            return res.status(400).json({ error: 'No PDF file provided', status: 'error' });
        }

        console.log(`   File: ${req.file.originalname} (${(req.file.size / 1024 / 1024).toFixed(2)} MB)`);

        // Delete old file from OpenAI if exists
        if (referenceFileCache.fileId) {
            console.log(`   Deleting old file: ${referenceFileCache.fileId}`);
            try {
                await axios.delete(`https://api.openai.com/v1/files/${referenceFileCache.fileId}`, {
                    headers: { 'Authorization': `Bearer ${OPENAI_API_KEY}` }
                });
                console.log('   ✅ Old file deleted');
            } catch (deleteError) {
                console.log('   ⚠️ Could not delete old file (may already be deleted)');
            }
        }

        // Upload new file to OpenAI Files API
        const FormData = require('form-data');
        const formData = new FormData();
        formData.append('purpose', 'assistants');
        formData.append('file', req.file.buffer, {
            filename: req.file.originalname,
            contentType: 'application/pdf'
        });

        const uploadResponse = await axios.post('https://api.openai.com/v1/files', formData, {
            headers: {
                'Authorization': `Bearer ${OPENAI_API_KEY}`,
                ...formData.getHeaders()
            },
            maxContentLength: 100 * 1024 * 1024,
            maxBodyLength: 100 * 1024 * 1024
        });

        const fileId = uploadResponse.data.id;
        console.log(`   ✅ File uploaded to OpenAI: ${fileId}`);

        // Update cache
        referenceFileCache = {
            fileId: fileId,
            filename: req.file.originalname,
            uploadedAt: new Date().toISOString(),
            fileSizeBytes: req.file.size
        };
        saveReferenceCache();

        res.json({
            fileId: fileId,
            filename: req.file.originalname,
            uploadedAt: referenceFileCache.uploadedAt,
            fileSizeMB: (req.file.size / 1024 / 1024).toFixed(2),
            status: 'success'
        });

    } catch (error) {
        console.error('❌ [upload-reference] Error:', error.message);
        res.status(500).json({
            error: 'Failed to upload reference file',
            message: error.message,
            status: 'error'
        });
    }
});

/**
 * DELETE /api/delete-reference
 * Delete current reference file
 */
app.delete('/api/delete-reference', async (req, res) => {
    console.log('\n🗑️ [delete-reference] Deleting reference file...');

    try {
        if (!referenceFileCache.fileId) {
            return res.json({ status: 'no_file', message: 'No reference file to delete' });
        }

        // Delete from OpenAI
        try {
            await axios.delete(`https://api.openai.com/v1/files/${referenceFileCache.fileId}`, {
                headers: { 'Authorization': `Bearer ${OPENAI_API_KEY}` }
            });
            console.log('   ✅ File deleted from OpenAI');
        } catch (deleteError) {
            console.log('   ⚠️ File may already be deleted from OpenAI');
        }

        // Clear cache
        referenceFileCache = {
            fileId: null,
            filename: null,
            uploadedAt: null,
            fileSizeBytes: null
        };
        saveReferenceCache();

        res.json({ status: 'deleted', message: 'Reference file deleted' });

    } catch (error) {
        console.error('❌ [delete-reference] Error:', error.message);
        res.status(500).json({ error: error.message, status: 'error' });
    }
});

/**
 * GET /api/reference-status
 * Get current reference file status
 */
app.get('/api/reference-status', (req, res) => {
    res.json({
        hasReference: !!referenceFileCache.fileId,
        filename: referenceFileCache.filename,
        fileId: referenceFileCache.fileId,
        uploadedAt: referenceFileCache.uploadedAt,
        fileSizeMB: referenceFileCache.fileSizeBytes ?
            (referenceFileCache.fileSizeBytes / 1024 / 1024).toFixed(2) : null
    });
});

/**
 * POST /api/solve
 * Get solution for a question using reference PDF
 */
app.post('/api/solve', async (req, res) => {
    console.log('\n📝 [solve] Processing solution request...');

    try {
        const { question, answers } = req.body;

        if (!question || !answers || !Array.isArray(answers)) {
            return res.status(400).json({
                error: 'Invalid request. Required: question (string), answers (array)',
                status: 'error'
            });
        }

        if (!referenceFileCache.fileId) {
            return res.status(400).json({
                error: 'No reference PDF uploaded. Please upload a reference document first.',
                status: 'error'
            });
        }

        console.log(`   Question: "${question.substring(0, 50)}..."`);
        console.log(`   Answers: ${answers.length} options`);
        console.log(`   Using reference: ${referenceFileCache.filename}`);

        // Format the question with answers
        const formattedQuestion = `Question: ${question}\n\nAnswer options:\n${
            answers.map((a, i) => `${i + 1}. ${a}`).join('\n')
        }`;

        // Call OpenAI with file context
        const response = await axios.post('https://api.openai.com/v1/chat/completions', {
            model: OPENAI_MODEL || 'gpt-4-turbo-preview',
            messages: [
                {
                    role: 'system',
                    content: `You are an expert tutor helping a student understand quiz questions.
You have access to the student's reference document (${referenceFileCache.filename}).
Provide a detailed, educational explanation of the correct answer.
Include:
1. The correct answer number (1-4)
2. Why this answer is correct
3. Why the other answers are incorrect
4. Relevant concepts from the reference material
Keep the explanation clear and comprehensive but not overly long.`
                },
                {
                    role: 'user',
                    content: formattedQuestion
                }
            ],
            max_tokens: 1500,
            temperature: 0.3
        }, {
            headers: {
                'Authorization': `Bearer ${OPENAI_API_KEY}`,
                'Content-Type': 'application/json'
            },
            timeout: 60000
        });

        const solution = response.data.choices[0].message.content.trim();
        console.log(`   ✅ Solution generated (${solution.length} chars)`);

        // Save solution to file for reference
        const solutionFile = path.join(__dirname, 'latest_solution.json');
        fs.writeFileSync(solutionFile, JSON.stringify({
            question,
            answers,
            solution,
            timestamp: new Date().toISOString(),
            referenceFile: referenceFileCache.filename
        }, null, 2));

        res.json({
            solution,
            questionLength: question.length,
            solutionLength: solution.length,
            referenceFile: referenceFileCache.filename,
            status: 'success'
        });

    } catch (error) {
        console.error('❌ [solve] Error:', error.message);
        res.status(500).json({
            error: 'Failed to generate solution',
            message: error.message,
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
    version: '2.0.0',
    endpoints: {
      'POST /api/analyze': 'Send questions for analysis',
      'POST /api/upload-reference': 'Upload PDF reference file (multipart/form-data)',
      'DELETE /api/delete-reference': 'Delete current reference file',
      'GET /api/reference-status': 'Get reference file status',
      'POST /api/solve': 'Get solution for a question using reference PDF',
      'GET /health': 'Health check',
      'WS /': 'WebSocket for real-time updates'
    },
    documentation: {
      analyze: 'POST /api/analyze with body: { questions: [...] }',
      upload: 'POST /api/upload-reference with multipart file field "pdf"',
      solve: 'POST /api/solve with body: { question: "...", answers: ["A", "B", "C", "D"] }'
    }
  });
});

/**
 * WebSocket connection handler (only if WebSocket server exists)
 */
if (wss) {
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
}

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
 * Start server (only if not in test environment)
 */
if (process.env.NODE_ENV !== 'test') {
  server.listen(PORT, () => {
    console.log(`\n✅ Backend server running on http://localhost:${PORT}`);
    console.log(`   OpenAI Model: ${OPENAI_MODEL}`);
    console.log(`   Stats App URL: ${STATS_APP_URL}`);
    console.log(`   WebSocket: ws://localhost:${PORT}\n`);
  });
}

module.exports = app;
