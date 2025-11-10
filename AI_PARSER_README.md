# AI Parser Service

A robust AI-powered quiz parser service that uses CodeLlama 13B (via Ollama) with OpenAI GPT-3.5-turbo fallback to intelligently parse quiz questions from structured text.

## Overview

**Port**: 3001
**Framework**: Express.js
**Primary AI**: CodeLlama 13B via Ollama (`http://localhost:11434`)
**Fallback AI**: OpenAI GPT-3.5-turbo

## Features

- Intelligent quiz parsing using local CodeLlama 13B model
- Automatic fallback to OpenAI GPT-3.5-turbo if CodeLlama fails or times out
- Low temperature (0.1) for consistent parsing results
- Robust error handling and timeout management
- CORS enabled for local development
- Comprehensive health check endpoint
- Request validation and sanitization
- Detailed logging for monitoring

## Architecture

```
┌─────────────────────────────────────────────┐
│          Client Application                  │
│  (Scraper, Frontend, etc.)                  │
└─────────────────────────────────────────────┘
                    ↓
           POST /parse-dom
           {"text": "..."}
                    ↓
┌─────────────────────────────────────────────┐
│       AI Parser Service (Port 3001)         │
│  ┌───────────────────────────────────────┐  │
│  │  1. Try CodeLlama 13B                 │  │
│  │     (Ollama http://localhost:11434)   │  │
│  │     Timeout: 30s                      │  │
│  └───────────────────────────────────────┘  │
│                    ↓                         │
│            Success? ──────→ Return Result    │
│                    ↓ No                      │
│  ┌───────────────────────────────────────┐  │
│  │  2. Fallback to OpenAI GPT-3.5-turbo  │  │
│  │     (api.openai.com)                  │  │
│  │     Timeout: 30s                      │  │
│  └───────────────────────────────────────┘  │
│                    ↓                         │
│            Success? ──────→ Return Result    │
│                    ↓ No                      │
│              Return Error                    │
└─────────────────────────────────────────────┘
```

## Installation

### Prerequisites

1. **Node.js** (v18 or higher)
2. **Ollama** (for CodeLlama 13B)
   - Install: https://ollama.ai/
   - Pull model: `ollama pull codellama:13b`
3. **OpenAI API Key** (for fallback)

### Setup Steps

1. **Clone/Navigate to Project**
   ```bash
   cd /Users/marvinbarsal/Desktop/Universität/Stats
   ```

2. **Install Dependencies** (if not already installed)
   ```bash
   npm install
   ```

3. **Configure Environment**

   The `.env.ai-parser` file should already exist with:
   ```env
   PORT=3001
   OLLAMA_URL=http://localhost:11434
   OPENAI_API_KEY=sk-proj-[YOUR_KEY]
   AI_TIMEOUT=30000
   USE_OPENAI_FALLBACK=true
   ```

4. **Start Ollama** (in separate terminal)
   ```bash
   ollama serve
   ```

5. **Pull CodeLlama Model** (first time only)
   ```bash
   ollama pull codellama:13b
   ```

6. **Start the Service**
   ```bash
   npm run ai-parser
   # or
   node ai-parser-service.js
   ```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | 3001 | Service port |
| `OLLAMA_URL` | http://localhost:11434 | Ollama API endpoint |
| `OPENAI_API_KEY` | (required) | OpenAI API key for fallback |
| `AI_TIMEOUT` | 30000 | Timeout in milliseconds (30s) |
| `USE_OPENAI_FALLBACK` | true | Enable OpenAI fallback |

### Customization

Edit `.env.ai-parser` to customize:

```env
# Increase timeout for slower systems
AI_TIMEOUT=60000

# Disable fallback (CodeLlama only)
USE_OPENAI_FALLBACK=false

# Use different Ollama URL (remote server)
OLLAMA_URL=http://192.168.1.100:11434
```

## API Reference

### POST /parse-dom

Parse quiz questions from structured text.

**Request:**
```json
{
  "text": "Frage 1\nFragetext\nWenn das Wetter gut ist...\n\nWählen Sie eine Antwort:\n- einen draufmachen.\n- die Nacht durchzechen.\n..."
}
```

**Response (Success):**
```json
{
  "status": "success",
  "questions": [
    {
      "question": "Wenn das Wetter gut ist, wird der Bauer bestimmt den Eber, das Ferkel und …",
      "answers": [
        "einen draufmachen.",
        "die Nacht durchzechen.",
        "auf die Kacke hauen.",
        "die Sau rauslassen."
      ]
    }
  ],
  "source": "codellama",
  "processingTime": 12.5,
  "usedFallback": false
}
```

**Response (Error):**
```json
{
  "status": "error",
  "error": "Both CodeLlama and OpenAI failed",
  "details": {
    "codellama": "Ollama not available",
    "openai": "OpenAI timeout"
  }
}
```

**Status Codes:**
- `200` - Success
- `400` - Bad request (invalid JSON, missing text field)
- `500` - Internal error (both AI services failed)

**Constraints:**
- Maximum text size: 50,000 characters
- Request timeout: 30 seconds (configurable)
- JSON payload limit: 10MB

### GET /health

Health check endpoint.

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2025-11-08T12:34:56.789Z",
  "service": "ai-parser-service",
  "port": 3001,
  "configuration": {
    "ollama_url": "http://localhost:11434",
    "openai_configured": true,
    "fallback_enabled": true,
    "timeout": 30000
  },
  "ollama_status": "available"
}
```

### GET /

Service information.

**Response:**
```json
{
  "service": "AI Parser Service",
  "version": "1.0.0",
  "endpoints": {
    "POST /parse-dom": "Parse quiz questions from text",
    "GET /health": "Health check",
    "GET /": "This message"
  },
  "documentation": "Send POST request to /parse-dom with {\"text\": \"...\"}"
}
```

## Usage Examples

### Basic Usage (cURL)

```bash
# Parse quiz text
curl -X POST http://localhost:3001/parse-dom \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Frage 1: Was ist 2+2?\na) 1\nb) 2\nc) 3\nd) 4"
  }'
```

### Using with Node.js/Axios

```javascript
const axios = require('axios');

async function parseQuiz(text) {
  try {
    const response = await axios.post('http://localhost:3001/parse-dom', {
      text: text
    });

    console.log('Parsed questions:', response.data.questions);
    console.log('Source:', response.data.source);
    console.log('Processing time:', response.data.processingTime);

    return response.data.questions;
  } catch (error) {
    console.error('Parsing failed:', error.response?.data || error.message);
  }
}

// Example usage
const quizText = `
Frage 1: Was ist die Hauptstadt von Deutschland?
a) Berlin
b) München
c) Hamburg
d) Frankfurt

Frage 2: Wie viele Bundesländer hat Deutschland?
a) 12
b) 14
c) 16
d) 18
`;

parseQuiz(quizText);
```

### Integration with Existing Scraper

Modify your existing scraper to use the AI parser:

```javascript
// In scraper.js
const axios = require('axios');

async function parseWithAI(rawText) {
  try {
    const response = await axios.post('http://localhost:3001/parse-dom', {
      text: rawText
    }, {
      timeout: 35000 // Slightly longer than AI timeout
    });

    if (response.data.status === 'success') {
      console.log(`AI parsed ${response.data.questions.length} questions using ${response.data.source}`);
      return response.data.questions;
    }
  } catch (error) {
    console.error('AI parsing failed:', error.message);
    // Fall back to manual parsing
    return manualParse(rawText);
  }
}
```

## AI Prompts

### CodeLlama Prompt

```
You are a quiz parser AI. Extract questions and answers from the following text.
The text is from a webpage quiz and may have German text.

IMPORTANT RULES:
1. Match each question with its closest answer options in the DOM structure
2. Even if answer options don't seem related, include them if they are structurally close
3. Return ONLY valid JSON array, no explanations
4. Format: [{"question": "text", "answers": ["A", "B", "C", "D"]}]

Text:
{text}

Return JSON array:
```

### OpenAI Prompt

Same as CodeLlama prompt. Both use:
- **Temperature**: 0.1 (low for consistent results)
- **Max tokens**: 2000
- **System message**: "Return ONLY valid JSON array, no explanations"

## Error Handling

The service implements comprehensive error handling:

### 1. CodeLlama Errors

- **Connection refused**: Ollama not running → Falls back to OpenAI
- **Timeout**: Response took > 30s → Falls back to OpenAI
- **Invalid JSON**: Response couldn't be parsed → Falls back to OpenAI
- **Empty response**: No questions found → Falls back to OpenAI

### 2. OpenAI Errors

- **Authentication failed**: Invalid API key → Returns 500 error
- **Rate limit exceeded**: Too many requests → Returns 500 error
- **Timeout**: Response took > 30s → Returns 500 error
- **Invalid JSON**: Response couldn't be parsed → Returns 500 error

### 3. Request Errors

- **Missing text field**: Returns 400 error
- **Text too large**: Returns 400 error (max 50KB)
- **Invalid JSON**: Returns 400 error

### 4. Graceful Degradation

```
CodeLlama fails
    ↓
Try OpenAI (if enabled)
    ↓
OpenAI fails
    ↓
Return detailed error with both failure reasons
```

## Performance

### Expected Processing Times

| Scenario | Time | Notes |
|----------|------|-------|
| **CodeLlama success** | 5-15s | Local processing, no network delay |
| **OpenAI fallback** | 2-8s | API call, depends on network |
| **Both fail** | ~30s | Timeout on both attempts |

### Optimization Tips

1. **Keep Ollama running**: Avoid startup delay
2. **Use CodeLlama when possible**: Faster and free
3. **Adjust timeout**: Increase for complex texts
4. **Cache results**: Store parsed questions to avoid re-parsing

### Resource Usage

- **Memory**: ~500MB for CodeLlama model
- **CPU**: High during CodeLlama inference
- **Network**: Only for OpenAI fallback

## Troubleshooting

### Problem: "Ollama not available"

**Solution:**
```bash
# Check if Ollama is running
curl http://localhost:11434/api/tags

# Start Ollama
ollama serve

# Verify model is installed
ollama list
# Should show: codellama:13b

# Pull model if missing
ollama pull codellama:13b
```

### Problem: "Invalid OpenAI API key"

**Solution:**
```bash
# Check .env.ai-parser file
cat .env.ai-parser | grep OPENAI_API_KEY

# Update with valid key
nano .env.ai-parser
# OPENAI_API_KEY=sk-proj-[YOUR_NEW_KEY]

# Restart service
npm run ai-parser
```

### Problem: Port 3001 already in use

**Solution:**
```bash
# Find process using port 3001
lsof -i :3001

# Kill it
lsof -ti:3001 | xargs kill -9

# Or change port in .env.ai-parser
# PORT=3002
```

### Problem: "Both CodeLlama and OpenAI failed"

**Diagnosis:**
```bash
# 1. Test CodeLlama directly
curl http://localhost:11434/api/generate \
  -d '{
    "model": "codellama:13b",
    "prompt": "Test",
    "stream": false
  }'

# 2. Test OpenAI directly
curl https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [{"role": "user", "content": "Test"}]
  }'

# 3. Check service logs
# Look for specific error messages
```

### Problem: Slow parsing performance

**Solutions:**
1. **Increase timeout**:
   ```env
   AI_TIMEOUT=60000
   ```

2. **Disable fallback** (if CodeLlama always works):
   ```env
   USE_OPENAI_FALLBACK=false
   ```

3. **Use OpenAI only** (faster for simple texts):
   - Comment out CodeLlama code
   - Or set Ollama to unavailable URL

## Testing

### Manual Testing

```bash
# 1. Start service
npm run ai-parser

# 2. Test health endpoint
curl http://localhost:3001/health

# 3. Test parsing with simple text
curl -X POST http://localhost:3001/parse-dom \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Frage 1: Was ist 2+2?\na) 1\nb) 2\nc) 3\nd) 4"
  }'

# 4. Test with complex German text
curl -X POST http://localhost:3001/parse-dom \
  -H "Content-Type: application/json" \
  -d @test-quiz.txt

# 5. Test error handling
curl -X POST http://localhost:3001/parse-dom \
  -H "Content-Type: application/json" \
  -d '{}'
# Should return 400 error
```

### Automated Testing

Create `test-ai-parser.js`:

```javascript
const axios = require('axios');

const tests = [
  {
    name: 'Simple German quiz',
    text: 'Frage 1: Was ist 2+2?\na) 1\nb) 2\nc) 3\nd) 4'
  },
  {
    name: 'Multiple questions',
    text: `
      Frage 1: Hauptstadt Deutschland?
      a) Berlin
      b) München

      Frage 2: Bundesländer Anzahl?
      a) 12
      b) 16
    `
  }
];

async function runTests() {
  for (const test of tests) {
    console.log(`Testing: ${test.name}`);
    try {
      const response = await axios.post('http://localhost:3001/parse-dom', {
        text: test.text
      });
      console.log(`  ✓ Success (${response.data.questions.length} questions)`);
      console.log(`  Source: ${response.data.source}`);
      console.log(`  Time: ${response.data.processingTime}s`);
    } catch (error) {
      console.log(`  ✗ Failed: ${error.message}`);
    }
  }
}

runTests();
```

Run: `node test-ai-parser.js`

## Monitoring

### Logging

The service logs:
- All incoming requests
- AI processing attempts (CodeLlama, OpenAI)
- Success/failure for each AI
- Processing times
- Detailed errors

### Health Monitoring

Set up periodic health checks:

```bash
# Add to crontab for monitoring
*/5 * * * * curl -f http://localhost:3001/health || echo "AI Parser down" | mail admin@example.com
```

### Metrics to Track

- **Total requests**: Count of `/parse-dom` calls
- **Success rate**: Percentage of successful parses
- **Source distribution**: CodeLlama vs OpenAI usage
- **Processing times**: Average, min, max
- **Error types**: Categorize failures

## Security

### Best Practices

1. **API Key Protection**:
   - Keep `.env.ai-parser` in `.gitignore`
   - Never commit API keys
   - Rotate keys regularly

2. **Input Validation**:
   - Maximum text size enforced (50KB)
   - JSON structure validation
   - Sanitize error messages

3. **Network Security**:
   - Use HTTPS in production
   - Restrict CORS origins
   - Implement rate limiting (future)

4. **Monitoring**:
   - Log all requests
   - Alert on unusual patterns
   - Track API usage costs

## Production Deployment

### Recommended Setup

1. **Use environment-specific configs**:
   ```env
   # .env.ai-parser.production
   PORT=3001
   OLLAMA_URL=http://ollama-server:11434
   OPENAI_API_KEY=sk-proj-[PRODUCTION_KEY]
   AI_TIMEOUT=45000
   USE_OPENAI_FALLBACK=true
   NODE_ENV=production
   ```

2. **Run with PM2**:
   ```bash
   npm install -g pm2
   pm2 start ai-parser-service.js --name ai-parser
   pm2 save
   pm2 startup
   ```

3. **Set up reverse proxy** (nginx):
   ```nginx
   location /ai-parser/ {
     proxy_pass http://localhost:3001/;
     proxy_timeout 60s;
   }
   ```

4. **Monitor logs**:
   ```bash
   pm2 logs ai-parser
   pm2 monit
   ```

## Integration with Existing System

The AI Parser Service integrates with the Quiz Stats system:

```
User presses Cmd+Option+Q
    ↓
Scraper extracts raw DOM text
    ↓
POST to AI Parser Service /parse-dom
    ↓
CodeLlama/OpenAI parses questions
    ↓
Returns structured JSON
    ↓
Backend analyzes answers with OpenAI
    ↓
Swift app animates results
```

**Benefits over manual parsing**:
- Handles complex HTML structures
- Adapts to different quiz formats
- Better handling of German text
- Reduces maintenance of parsing rules

## Roadmap

Future enhancements:

- [ ] Support for multiple languages (configuration)
- [ ] Caching layer for duplicate texts
- [ ] Batch processing endpoint
- [ ] WebSocket streaming for real-time progress
- [ ] Custom model fine-tuning
- [ ] Rate limiting implementation
- [ ] Prometheus metrics export
- [ ] Docker containerization

## Support

For issues:
1. Check this README
2. Verify Ollama is running
3. Check service logs
4. Test health endpoint
5. Verify environment variables

## License

MIT

---

**File Location**: `/Users/marvinbarsal/Desktop/Universität/Stats/AI_PARSER_README.md`
**Service File**: `/Users/marvinbarsal/Desktop/Universität/Stats/ai-parser-service.js`
**Configuration**: `/Users/marvinbarsal/Desktop/Universität/Stats/.env.ai-parser`
**Port**: 3001
**Status**: Production Ready
