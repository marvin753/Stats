# 🔑 OpenAI API Key - Complete Guide

**CRITICAL**: Your old API key was exposed. You MUST create a new one.

---

## ⚠️ What Happened?

You shared your OpenAI API key in plain text in your original request.

This key can be used by anyone to:
- Access your OpenAI account
- Use your API credits
- Run up charges on your billing
- Potentially access other data

**ACTION REQUIRED**: Delete this key immediately!

---

## Step 1: Delete Old Key

### 1.1 Go to OpenAI Website

Open browser and visit:
```
https://platform.openai.com/account/api-keys
```

You need to be logged in with your OpenAI account.

### 1.2 Find the Old Key

Look for a key that starts with:
```
sk-proj-B8Elsnwgwamnb8V6...
```

(This is your exposed key)

### 1.3 Delete It

1. Click the **trash/delete icon** next to the key
2. Confirm deletion when prompted
3. The key should disappear from the list

✅ **Old key is now deleted**

---

## Step 2: Create New Key

### 2.1 Click "Create new secret key"

On the same page (https://platform.openai.com/account/api-keys):

1. Click the **"+ Create new secret key"** button
2. A dialog appears
3. Click **"Create secret key"**

### 2.2 Copy Your New Key

The new key will look like:
```
sk-proj-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

**IMPORTANT**: Copy this key immediately!
- It will ONLY show once
- You can't retrieve it again
- If you lose it, you must delete and create a new one

**Copy it like this**:
1. Click the "copy" button next to the key
2. Or manually select the entire key and Cmd+C

### 2.3 Save It Somewhere Safe

Temporarily save it to:
- Notes app
- Password manager
- Sticky note (just for setup)

**Don't keep it anywhere permanently visible!**

---

## Step 3: Put Key in .env File

Now you need to place this key in your backend configuration.

### 3.1 Locate the .env File

Path:
```
~/Desktop/Universität/Stats/backend/.env
```

### 3.2 Edit the .env File

**Option A: Using Terminal (Recommended)**

```bash
nano ~/Desktop/Universität/Stats/backend/.env
```

This opens a text editor.

Type or paste:
```
OPENAI_API_KEY=sk-proj-PASTE_YOUR_NEW_KEY_HERE
OPENAI_MODEL=gpt-3.5-turbo
BACKEND_PORT=3000
STATS_APP_URL=http://localhost:8080
```

Replace `PASTE_YOUR_NEW_KEY_HERE` with your actual key from Step 2.2

Then:
- Press `Control + X`
- Press `Y` (for yes to save)
- Press `Enter`

**Option B: Using Finder & TextEdit**

1. Open Finder
2. Press `Cmd+Shift+.` (shows hidden files)
3. Navigate to: `~/Desktop/Universität/Stats/backend/`
4. Look for file named `.env`
5. Right-click → "Open With" → "TextEdit"
6. Replace the content with:
   ```
   OPENAI_API_KEY=sk-proj-YOUR_NEW_KEY
   OPENAI_MODEL=gpt-3.5-turbo
   BACKEND_PORT=3000
   STATS_APP_URL=http://localhost:8080
   ```
7. Save (Cmd+S)

### 3.3 Verify It Worked

```bash
cat ~/Desktop/Universität/Stats/backend/.env
```

You should see:
```
OPENAI_API_KEY=sk-proj-XXXXXXXXX...
OPENAI_MODEL=gpt-3.5-turbo
BACKEND_PORT=3000
STATS_APP_URL=http://localhost:8080
```

✅ If you see your key → Correctly placed!

---

## Step 4: Test the Key

### 4.1 Start Backend Server

```bash
cd ~/Desktop/Universität/Stats/backend
npm start
```

You should see:
```
✅ Backend server running on http://localhost:3000
   OpenAI Model: gpt-3.5-turbo
```

### 4.2 Test Health Check

In another Terminal:

```bash
curl http://localhost:3000/health
```

Response should show:
```json
{
  "status": "ok",
  "openai_configured": true
}
```

✅ If `openai_configured: true` → Your key works!

### 4.3 Test Full API Call

```bash
curl -X POST http://localhost:3000/api/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "questions": [
      {"question": "What is 2+2?", "answers": ["1","2","3","4"]}
    ]
  }'
```

Should return:
```json
{
  "status": "success",
  "answers": [4],
  "questionCount": 1,
  "message": "Questions analyzed successfully"
}
```

✅ If you get this → API key is fully working!

---

## 🔐 Keeping Your Key Safe

### DO:
✅ Keep .env file in `.gitignore`
✅ Store key in environment variables only
✅ Use different keys for different projects
✅ Rotate keys regularly
✅ Enable API usage monitoring

### DON'T:
❌ Share key in emails or messages
❌ Commit .env file to git
❌ Post key on websites or forums
❌ Use same key for multiple projects
❌ Leave key visible on screen

### In .gitignore:

Make sure `.gitignore` contains:
```
backend/.env
node_modules/
.DS_Store
```

Check it:
```bash
cat ~/Desktop/Universität/Stats/backend/.gitignore
```

---

## What If You Lose Your Key?

If you accidentally lose your new key:

1. Go to: https://platform.openai.com/account/api-keys
2. Delete the lost key
3. Create a new one
4. Update .env file
5. Restart backend

---

## Billing & Monitoring

### 1. Set Usage Limits

Go to: https://platform.openai.com/account/billing/overview

1. Click "Usage limits"
2. Set a monthly limit to prevent surprises
3. Set a hard limit if needed

### 2. Monitor API Usage

Go to: https://platform.openai.com/account/billing/overview

- Check usage dashboard
- See costs per model
- Monitor request counts

### 3. API Keys Page

Go to: https://platform.openai.com/account/api-keys

- See all active keys
- Last used dates
- Delete unused keys

---

## Troubleshooting

### "Invalid API key"
**Solution**:
1. Double-check key in .env file
2. Make sure it starts with `sk-proj-`
3. Make sure there are no extra spaces
4. Verify key hasn't expired
5. Check key exists on OpenAI website

Example of WRONG:
```
sk-proj-XXXXX sk-proj-XXXXX  ← spaces!
sk-proj-XXXXX.bak             ← extra characters!
 sk-proj-XXXXX                ← leading space!
```

Example of CORRECT:
```
sk-proj-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

### "Rate limit exceeded"
**Solution**:
1. Your API calls are happening too fast
2. Wait a few moments
3. Try the test again

### "Authentication failed"
**Solution**:
1. Key might be wrong
2. Backend might not be reading .env correctly
3. Try restarting backend:
   ```bash
   Ctrl+C (stop)
   npm start (restart)
   ```

### "Connection refused"
**Solution**:
1. Backend server might not be running
2. Start it with:
   ```bash
   cd ~/Desktop/Universität/Stats/backend && npm start
   ```

---

## API Key Security Checklist

- [ ] Old key deleted
- [ ] New key created
- [ ] New key copied
- [ ] New key placed in .env
- [ ] .env file in .gitignore
- [ ] Health check works
- [ ] Full API test works
- [ ] Usage limits set
- [ ] Billing monitored
- [ ] Key stored safely

---

## Quick Reference

| Item | Location |
|------|----------|
| Create/Manage Keys | https://platform.openai.com/account/api-keys |
| Billing | https://platform.openai.com/account/billing/overview |
| Usage Limits | https://platform.openai.com/account/billing/overview |
| .env File | ~/Desktop/Universität/Stats/backend/.env |
| Backend | ~/Desktop/Universität/Stats/backend/server.js |

---

## Commands You'll Need

### Edit .env
```bash
nano ~/Desktop/Universität/Stats/backend/.env
```

### View .env
```bash
cat ~/Desktop/Universität/Stats/backend/.env
```

### Start Backend
```bash
cd ~/Desktop/Universität/Stats/backend && npm start
```

### Test Health
```bash
curl http://localhost:3000/health
```

### Test API
```bash
curl -X POST http://localhost:3000/api/analyze \
  -H "Content-Type: application/json" \
  -d '{"questions":[{"question":"Q?","answers":["A","B"]}]}'
```

---

## Security Summary

Your API key is now:
- ✅ New (old one deleted)
- ✅ Stored securely (in .env only)
- ✅ Not hardcoded in files
- ✅ Not committed to git
- ✅ Not exposed anywhere
- ✅ Ready to use safely

**You're all set!** 🎉

---

## Next Steps

1. ✅ Complete API key setup above
2. ➡️ Go to `START_HERE.md`
3. ➡️ Follow all startup steps
4. ➡️ Start the backend server
5. ➡️ Test everything works

---

**Questions about API keys?**
Visit: https://platform.openai.com/docs/api-reference/authentication

**Questions about costs?**
Visit: https://openai.com/pricing/

