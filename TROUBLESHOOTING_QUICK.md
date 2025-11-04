# Quick Troubleshooting Guide

## Error: "Cannot find module 'dotenv'"

### What Happened?
The backend dependencies weren't installed.

### Solution (STEP BY STEP):

**Step 1: Navigate to backend folder**
```bash
cd ~/Desktop/Universität/Stats/backend
```

**Step 2: Install dependencies**
```bash
npm install
```

You should see:
```
added 112 packages, and audited 113 packages in 4s
found 0 vulnerabilities
```

**Step 3: Verify dependencies are installed**
```bash
ls node_modules | head -10
```

You should see a list of packages like:
```
express
axios
cors
dotenv
ws
...
```

**Step 4: Now try npm start**
```bash
npm start
```

You should see:
```
✅ Backend server running on http://localhost:3000
   OpenAI Model: gpt-3.5-turbo
   Stats App URL: http://localhost:8080
   WebSocket: ws://localhost:3000
```

---

## If it still doesn't work:

### Check 1: Are you in the correct folder?
```bash
pwd
```

Should show:
```
/Users/marvinbarsal/Desktop/Universität/Stats/backend
```

If not, run:
```bash
cd ~/Desktop/Universität/Stats/backend
```

### Check 2: Does package.json exist?
```bash
ls package.json
```

Should show:
```
package.json
```

### Check 3: Delete and reinstall
```bash
rm -rf node_modules package-lock.json
npm install
npm start
```

### Check 4: Is .env file created?
```bash
cat .env
```

Should show your API key configuration.

---

## Common Issues

### Issue: "Port 3000 already in use"
**Solution**:
```bash
lsof -ti:3000 | xargs kill -9
npm start
```

### Issue: "OPENAI_API_KEY not found"
**Solution**:
Make sure `.env` file exists and has your API key:
```bash
cat ~/.env
```

Should show:
```
OPENAI_API_KEY=sk-proj-YOUR_KEY
OPENAI_MODEL=gpt-3.5-turbo
BACKEND_PORT=3000
STATS_APP_URL=http://localhost:8080
```

### Issue: "Module not found" errors
**Solution**:
```bash
cd ~/Desktop/Universität/Stats/backend
rm -rf node_modules package-lock.json
npm install
npm start
```

---

## Complete Fresh Start

If you want to start completely fresh:

```bash
# Go to backend folder
cd ~/Desktop/Universität/Stats/backend

# Remove old files
rm -rf node_modules package-lock.json

# Install fresh
npm install

# Verify installation
ls node_modules | wc -l
# Should show around 112

# Start server
npm start
```

---

## Verify Everything Works

Once backend starts successfully:

**In another Terminal:**
```bash
curl http://localhost:3000/health
```

Should return:
```json
{"status":"ok","timestamp":"...","openai_configured":true}
```

If you see `openai_configured: true` → **Everything is working!** ✅

---

## Need More Help?

1. Make sure you're in `/Users/marvinbarsal/Desktop/Universität/Stats/backend`
2. Run `npm install` first
3. Then run `npm start`
4. If errors persist, run the "Complete Fresh Start" section above

