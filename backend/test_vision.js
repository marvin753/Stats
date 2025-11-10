const axios = require('axios');
const fs = require('fs');
require('dotenv').config();

async function testVisionAPI() {
  try {
    // Read test screenshot
    const screenshotPath = '/Users/marvinbarsal/.playwright-mcp/test_page.png';
    const base64Image = fs.readFileSync(screenshotPath, { encoding: 'base64' });
    
    console.log('Testing OpenAI Vision API...');
    console.log('Image size:', base64Image.length, 'chars');
    
    const response = await axios.post(
      'https://api.openai.com/v1/chat/completions',
      {
        model: 'gpt-4o',
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'text',
                text: 'What text do you see in this image? Extract all visible text.'
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
        max_tokens: 300
      },
      {
        headers: {
          'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
          'Content-Type': 'application/json'
        }
      }
    );
    
    console.log('\nSuccess! OpenAI Vision API Response:');
    console.log('Model:', response.data.model);
    console.log('Extracted text:', response.data.choices[0].message.content);
    console.log('\nTokens used:', response.data.usage.total_tokens);
    
    return true;
  } catch (error) {
    console.error('\nError testing Vision API:');
    if (error.response) {
      console.error('Status:', error.response.status);
      console.error('Error:', error.response.data);
    } else {
      console.error(error.message);
    }
    return false;
  }
}

testVisionAPI();
