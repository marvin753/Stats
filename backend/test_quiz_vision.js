const axios = require('axios');
const fs = require('fs');
require('dotenv').config();

async function testQuizVision() {
  try {
    // Read the actual quiz screenshot
    const screenshotPath = '/Users/marvinbarsal/Desktop/Universität/Stats/test_quiz_screenshot.png';
    const base64Image = fs.readFileSync(screenshotPath, { encoding: 'base64' });

    console.log('🧪 Testing OpenAI Vision API on German quiz...');
    console.log('📸 Image size:', base64Image.length, 'chars');
    console.log('');

    const response = await axios.post(
      'https://api.openai.com/v1/chat/completions',
      {
        model: 'gpt-4o',
        messages: [
          {
            role: 'system',
            content: 'You are a quiz extraction expert. Extract quiz questions and multiple-choice answers from screenshots. Return ONLY valid JSON array in this format: [{"question": "text", "answers": ["A", "B", "C", "D"]}]. No explanations, no markdown, just the JSON array.'
          },
          {
            role: 'user',
            content: [
              {
                type: 'text',
                text: 'Extract all quiz questions and their answer options from this screenshot. The quiz is in German. Return a JSON array with this exact format: [{"question": "question text", "answers": ["option 1", "option 2", "option 3", "option 4"]}]'
              },
              {
                type: 'image_url',
                image_url: {
                  url: `data:image/png;base64,${base64Image}`
                }
              }
            ]
          }
        ],
        max_tokens: 2000,
        temperature: 0.1
      },
      {
        headers: {
          'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
          'Content-Type': 'application/json'
        },
        timeout: 45000
      }
    );

    console.log('✅ OpenAI Vision API Response:');
    console.log('Model:', response.data.model);
    console.log('');
    console.log('Extracted content:');
    console.log(response.data.choices[0].message.content);
    console.log('');
    console.log('📊 Tokens used:', response.data.usage.total_tokens);

    // Try to parse as JSON
    try {
      const content = response.data.choices[0].message.content;
      // Remove markdown code blocks if present
      const cleanContent = content.replace(/```json\s*/g, '').replace(/```\s*/g, '');
      const questions = JSON.parse(cleanContent);

      console.log('');
      console.log('✅ Successfully parsed JSON!');
      console.log('📝 Number of questions extracted:', questions.length);
      console.log('');
      console.log('--- Parsed Questions ---');
      questions.forEach((q, idx) => {
        console.log(`\n${idx + 1}. ${q.question}`);
        q.answers.forEach((a, i) => {
          console.log(`   ${i + 1}. ${a}`);
        });
      });

      return { success: true, questions };
    } catch (parseError) {
      console.log('');
      console.log('⚠️  Could not parse as JSON:', parseError.message);
      return { success: false, error: parseError.message };
    }

  } catch (error) {
    console.error('\n❌ Error testing Vision API:');
    if (error.response) {
      console.error('Status:', error.response.status);
      console.error('Error:', JSON.stringify(error.response.data, null, 2));
    } else {
      console.error(error.message);
    }
    return { success: false, error: error.message };
  }
}

testQuizVision();
