/**
 * OpenAI Assistant API Service
 * Handles large PDF processing (140+ pages) for quiz analysis
 *
 * Features:
 * - Upload PDFs up to 2GB to OpenAI
 * - Create persistent threads with PDF context
 * - Use retrieval tool to search entire document
 * - Generate answers for quiz questions (Q1-14: multiple-choice, Q15-20: written)
 *
 * Usage:
 *   POST /api/upload-pdf - Upload PDF and create thread
 *   POST /api/analyze-quiz - Analyze quiz with PDF context
 */

// Load environment variables if not already loaded
if (!process.env.OPENAI_API_KEY) {
  require('dotenv').config();
}

const OpenAI = require('openai');
const fs = require('fs');
const path = require('path');

// Initialize OpenAI client
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

// Active threads cache (for cleanup)
const activeThreads = new Map();

/**
 * Get or create OpenAI Assistant
 * Caches assistant ID in environment variable for reuse
 */
async function getOrCreateAssistant() {
  const ASSISTANT_ID = process.env.ASSISTANT_ID;

  // Try to retrieve cached assistant
  if (ASSISTANT_ID) {
    try {
      const assistant = await openai.beta.assistants.retrieve(ASSISTANT_ID);
      console.log(`✅ Using cached assistant: ${assistant.id}`);
      return assistant;
    } catch (err) {
      console.log('⚠️  Cached assistant not found, creating new one');
    }
  }

  // Create new assistant
  const assistant = await openai.beta.assistants.create({
    name: 'Quiz Answer Assistant',
    instructions: `You are an expert quiz analyzer. Your task:

CRITICAL - IGNORE UI ELEMENTS WHEN READING SCREENSHOTS:
- IGNORE all text formatting toolbars (Bold, Italic, Underline, Font size, Font family buttons)
- IGNORE any text editor controls, rich text menus, or formatting options
- IGNORE browser toolbars, address bars, navigation menus, tabs, and browser chrome
- IGNORE any toolbar icons, dropdown buttons, or UI control elements
- IGNORE status bars, headers, footers, sidebars, and navigation panels
- IGNORE any elements that look like "B" (bold), "I" (italic), "U" (underline) formatting buttons
- The text formatting toolbar typically appears above text input areas - COMPLETELY SKIP IT
- Do NOT confuse toolbar button labels or icons with actual quiz content
- FOCUS ONLY on the main content area containing quiz questions and answer options

1. Extract ALL questions (1-20) from the quiz screenshot in chronological order
2. For Q1-14 (multiple-choice):
   - List all answer options exactly as shown
   - Use the reference PDF script to determine the correct answer
   - Return the correct answer index (1-4)
3. For Q15-20 (written questions):
   - Generate detailed, comprehensive answers based on the PDF script
   - Reference specific sections or pages when applicable
   - Provide complete, well-structured responses

Return ONLY a JSON array with this structure:
[
  {
    "questionNumber": 1,
    "type": "multiple-choice",
    "question": "Question text...",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctAnswer": 2
  },
  {
    "questionNumber": 15,
    "type": "written",
    "question": "Question text...",
    "answerText": "Detailed answer based on the script..."
  }
]

IMPORTANT:
- Return questions in order (1, 2, 3, ... 20)
- Use the retrieval tool to search the PDF for relevant information
- For multiple-choice, correctAnswer is 1-based index (1 = first option)
- For written answers, provide comprehensive, well-structured responses
- Extract ONLY quiz content, NEVER UI elements or toolbars`,
    model: 'gpt-4-turbo-preview',
    tools: [{ type: 'file_search' }] // Updated from 'retrieval' (deprecated)
  });

  console.log(`✅ Assistant created: ${assistant.id}`);
  console.log(`   💡 Save this ID to .env as ASSISTANT_ID=${assistant.id}`);

  return assistant;
}

/**
 * Upload PDF and create thread with file attached
 * POST /api/upload-pdf
 * Body: { pdfPath: "/path/to/pdf" } or { pdfBase64: "base64data", filename: "script.pdf" }
 */
async function uploadPDF(req, res) {
  try {
    const { pdfPath, pdfBase64, filename } = req.body;

    if (!pdfPath && !pdfBase64) {
      return res.status(400).json({
        error: 'Missing PDF data',
        message: 'Provide either pdfPath or pdfBase64 + filename'
      });
    }

    let fileToUpload;
    let cleanupFile = false;

    // Handle base64 PDF (from Swift app)
    if (pdfBase64) {
      const tempPath = path.join('/tmp', filename || 'uploaded.pdf');
      const buffer = Buffer.from(pdfBase64, 'base64');
      fs.writeFileSync(tempPath, buffer);
      fileToUpload = tempPath;
      cleanupFile = true;
      console.log(`📄 Received base64 PDF: ${(buffer.length / 1024 / 1024).toFixed(2)} MB`);
    } else {
      fileToUpload = pdfPath;
      console.log(`📄 Using PDF path: ${pdfPath}`);
    }

    // Verify file exists
    if (!fs.existsSync(fileToUpload)) {
      return res.status(400).json({
        error: 'File not found',
        message: `PDF file does not exist: ${fileToUpload}`
      });
    }

    const fileStats = fs.statSync(fileToUpload);
    const fileSizeMB = (fileStats.size / 1024 / 1024).toFixed(2);
    console.log(`📊 PDF size: ${fileSizeMB} MB`);

    // Upload file to OpenAI
    console.log('⏳ Uploading PDF to OpenAI...');
    const file = await openai.files.create({
      file: fs.createReadStream(fileToUpload),
      purpose: 'assistants'
    });

    console.log(`✅ PDF uploaded: ${file.id} (${fileSizeMB} MB)`);

    // Create or retrieve assistant
    const assistant = await getOrCreateAssistant();

    // Create vector store for file search
    console.log('⏳ Creating vector store...');
    const vectorStore = await openai.beta.vectorStores.create({
      name: `Quiz PDF - ${new Date().toISOString()}`,
      file_ids: [file.id]
    });

    console.log(`✅ Vector store created: ${vectorStore.id}`);

    // Create thread with vector store attached
    console.log('⏳ Creating thread...');
    const thread = await openai.beta.threads.create({
      tool_resources: {
        file_search: {
          vector_store_ids: [vectorStore.id]
        }
      }
    });

    console.log(`✅ Thread created: ${thread.id}`);

    // Add initial context message
    await openai.beta.threads.messages.create(thread.id, {
      role: 'user',
      content: 'This is the reference script for the quiz. It contains 140+ pages covering the course material. Use this document to answer quiz questions.'
    });

    // Cache thread info for cleanup
    activeThreads.set(thread.id, {
      fileId: file.id,
      vectorStoreId: vectorStore.id,
      createdAt: new Date(),
      pdfPath: pdfPath || filename
    });

    // Cleanup temp file if needed
    if (cleanupFile) {
      fs.unlinkSync(fileToUpload);
    }

    res.json({
      threadId: thread.id,
      assistantId: assistant.id,
      fileId: file.id,
      vectorStoreId: vectorStore.id,
      fileSizeMB: fileSizeMB,
      createdAt: new Date().toISOString()
    });

  } catch (error) {
    console.error('❌ PDF upload failed:', error);
    res.status(500).json({
      error: 'PDF upload failed',
      message: error.message
    });
  }
}

/**
 * Analyze quiz with PDF context
 * POST /api/analyze-quiz
 * Body: { threadId: "thread_xxx", screenshotBase64: "base64data" }
 */
async function analyzeQuiz(req, res) {
  try {
    const { threadId, screenshotBase64 } = req.body;

    if (!threadId || !screenshotBase64) {
      return res.status(400).json({
        error: 'Missing required fields',
        message: 'Provide threadId and screenshotBase64'
      });
    }

    console.log(`\n🔍 Analyzing quiz for thread: ${threadId}`);

    // Add screenshot message to thread
    await openai.beta.threads.messages.create(threadId, {
      role: 'user',
      content: [
        {
          type: 'text',
          text: `Extract all questions (1-20) from this quiz screenshot. CRITICAL: IGNORE any text formatting toolbars (Bold, Italic, Underline buttons, etc.) and other UI elements - focus ONLY on the actual quiz content. For Q1-14 (multiple-choice), select the correct answer based on the reference script. For Q15-20 (written), generate detailed answers using the script. Return JSON array in chronological order.`
        },
        {
          type: 'image_url',
          image_url: {
            url: `data:image/png;base64,${screenshotBase64}`,
            detail: 'high'
          }
        }
      ]
    });

    // Run assistant
    const assistant = await getOrCreateAssistant();
    console.log('⏳ Running Assistant...');

    const run = await openai.beta.threads.runs.create(threadId, {
      assistant_id: assistant.id
    });

    // Poll for completion
    let runStatus = await openai.beta.threads.runs.retrieve(threadId, run.id);
    const startTime = Date.now();

    while (runStatus.status !== 'completed' && runStatus.status !== 'failed') {
      await new Promise(resolve => setTimeout(resolve, 2000));
      runStatus = await openai.beta.threads.runs.retrieve(threadId, run.id);

      const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
      console.log(`⏳ Assistant status: ${runStatus.status} (${elapsed}s)`);

      // Timeout after 2 minutes
      if (Date.now() - startTime > 120000) {
        throw new Error('Assistant run timeout (2 minutes)');
      }
    }

    if (runStatus.status === 'failed') {
      throw new Error(`Assistant run failed: ${runStatus.last_error?.message || 'Unknown error'}`);
    }

    console.log(`✅ Assistant completed in ${((Date.now() - startTime) / 1000).toFixed(1)}s`);

    // Get response messages
    const messages = await openai.beta.threads.messages.list(threadId, {
      order: 'desc',
      limit: 1
    });

    const lastMessage = messages.data[0];
    if (!lastMessage || !lastMessage.content || lastMessage.content.length === 0) {
      throw new Error('No response from Assistant');
    }

    const content = lastMessage.content[0].text.value;
    console.log('📄 Assistant response preview:', content.substring(0, 200) + '...');

    // Parse JSON response
    const jsonMatch = content.match(/\[[\s\S]*\]/);
    if (!jsonMatch) {
      throw new Error('No JSON array found in response');
    }

    const answers = JSON.parse(jsonMatch[0]);

    if (!Array.isArray(answers)) {
      throw new Error('Response is not an array');
    }

    console.log(`✅ Quiz analyzed: ${answers.length} answers extracted`);

    // Log answer summary
    const mcCount = answers.filter(a => a.type === 'multiple-choice').length;
    const writtenCount = answers.filter(a => a.type === 'written').length;
    console.log(`   Multiple-choice: ${mcCount}, Written: ${writtenCount}`);

    res.json({
      answers: answers,
      threadId: threadId,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('❌ Quiz analysis failed:', error);
    res.status(500).json({
      error: 'Quiz analysis failed',
      message: error.message
    });
  }
}

/**
 * Get thread info
 * GET /api/thread/:threadId
 */
async function getThreadInfo(req, res) {
  try {
    const { threadId } = req.params;

    const threadInfo = activeThreads.get(threadId);
    if (!threadInfo) {
      return res.status(404).json({
        error: 'Thread not found',
        message: 'No cached thread with this ID'
      });
    }

    res.json({
      threadId: threadId,
      ...threadInfo,
      ageMinutes: ((Date.now() - threadInfo.createdAt.getTime()) / 60000).toFixed(1)
    });

  } catch (error) {
    res.status(500).json({
      error: 'Failed to get thread info',
      message: error.message
    });
  }
}

/**
 * Delete thread and cleanup resources
 * DELETE /api/thread/:threadId
 */
async function deleteThread(req, res) {
  try {
    const { threadId } = req.params;

    const threadInfo = activeThreads.get(threadId);
    if (!threadInfo) {
      return res.status(404).json({
        error: 'Thread not found',
        message: 'No cached thread with this ID'
      });
    }

    console.log(`🧹 Cleaning up thread: ${threadId}`);

    // Delete thread
    await openai.beta.threads.del(threadId);
    console.log(`   ✓ Thread deleted`);

    // Delete vector store
    if (threadInfo.vectorStoreId) {
      await openai.beta.vectorStores.del(threadInfo.vectorStoreId);
      console.log(`   ✓ Vector store deleted`);
    }

    // Delete file
    if (threadInfo.fileId) {
      await openai.files.del(threadInfo.fileId);
      console.log(`   ✓ File deleted`);
    }

    activeThreads.delete(threadId);

    res.json({
      message: 'Thread cleaned up successfully',
      threadId: threadId
    });

  } catch (error) {
    console.error('❌ Cleanup failed:', error);
    res.status(500).json({
      error: 'Cleanup failed',
      message: error.message
    });
  }
}

/**
 * List all active threads
 * GET /api/threads
 */
function listThreads(req, res) {
  const threads = Array.from(activeThreads.entries()).map(([id, info]) => ({
    threadId: id,
    pdfPath: info.pdfPath,
    createdAt: info.createdAt.toISOString(),
    ageMinutes: ((Date.now() - info.createdAt.getTime()) / 60000).toFixed(1)
  }));

  res.json({
    threads: threads,
    count: threads.length
  });
}

/**
 * Cleanup old threads (run periodically)
 * Deletes threads older than 24 hours
 */
async function cleanupOldThreads() {
  const now = Date.now();
  const maxAge = 24 * 60 * 60 * 1000; // 24 hours

  for (const [threadId, data] of activeThreads.entries()) {
    if (now - data.createdAt.getTime() > maxAge) {
      try {
        console.log(`🧹 Auto-cleanup: Deleting old thread ${threadId}`);
        await openai.beta.threads.del(threadId);

        if (data.vectorStoreId) {
          await openai.beta.vectorStores.del(data.vectorStoreId);
        }

        if (data.fileId) {
          await openai.files.del(data.fileId);
        }

        activeThreads.delete(threadId);
        console.log(`   ✓ Thread ${threadId} cleaned up`);
      } catch (err) {
        console.error(`   ✗ Failed to cleanup thread ${threadId}:`, err.message);
      }
    }
  }
}

// Run cleanup every hour
setInterval(cleanupOldThreads, 60 * 60 * 1000);

// Export functions
module.exports = {
  uploadPDF,
  analyzeQuiz,
  getThreadInfo,
  deleteThread,
  listThreads,
  getOrCreateAssistant
};
