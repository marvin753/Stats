# Troubleshooting Guide

**Version**: 2.0.0
**Last Updated**: November 13, 2025

---

## Quick Diagnostics

Run this command first to check all services:

```bash
echo "=== CDP Service ==="
curl -s http://localhost:9223/health | jq .
echo "=== Backend ==="
curl -s http://localhost:3000/health | jq .
echo "=== Stats App ==="
curl -s http://localhost:8080/health
echo "=== Ports ==="
lsof -i :9223 | grep LISTEN
lsof -i :3000 | grep LISTEN
lsof -i :8080 | grep LISTEN
```

---

## Keyboard Shortcuts Not Working

**Problem**: Cmd+Option+O/P/L does nothing

**Solutions**:

1. **Grant Accessibility Permission**:
   - System Preferences → Security & Privacy → Privacy → Accessibility
   - Click lock icon, add Stats.app
   - Restart Stats app

2. **Verify Stats App Running**:
   ```bash
   ps aux | grep Stats | grep -v grep
   ```

3. **Check Console for Errors**:
   - Open Console.app
   - Search for "Stats"
   - Look for error messages

4. **Restart Stats App**:
   ```bash
   pkill Stats
   open cloned-stats/build/Build/Products/Release/Stats.app
   ```

---

## Screenshot Capture Fails

**Problem**: "Screenshot capture failed" error

**Solutions**:

1. **Check CDP Service**:
   ```bash
   curl http://localhost:9223/health
   # Expected: {"status":"ok","chrome":"connected"}
   ```

2. **Check Chrome Running**:
   ```bash
   curl http://localhost:9223/targets
   # Should list at least one tab
   ```

3. **Restart CDP Service**:
   ```bash
   cd chrome-cdp-service
   pkill -f "ts-node"
   npm start
   ```

4. **Verify Chrome Debug Port**:
   ```bash
   lsof -i :9222
   # Should show Chrome process
   ```

---

## Quiz Processing Fails

**Problem**: "Failed to analyze quiz" or timeout

**Solutions**:

1. **Check Backend Running**:
   ```bash
   curl http://localhost:3000/health
   # Expected: {"status":"ok","openai_configured":true}
   ```

2. **Verify OpenAI API Key**:
   ```bash
   cat backend/.env | grep OPENAI_API_KEY
   # Should show: OPENAI_API_KEY=sk-proj-...
   ```

3. **Check PDF Uploaded**:
   - Press Cmd+Option+L
   - Select PDF file
   - Wait for confirmation
   - Retry processing

4. **Test OpenAI API**:
   ```bash
   curl https://api.openai.com/v1/models \
     -H "Authorization: Bearer YOUR_API_KEY"
   # Should list available models
   ```

5. **Check OpenAI Rate Limits**:
   - Visit https://platform.openai.com/usage
   - Verify not hitting rate limits
   - Wait 1 minute if rate limited

---

## Animation Doesn't Display

**Problem**: No numbers appear in GPU widget

**Solutions**:

1. **Check GPU Widget Visible**:
   - Look for GPU indicator in menu bar
   - If hidden, enable in Stats app preferences

2. **Test Stats App HTTP Server**:
   ```bash
   curl http://localhost:8080/health
   # Expected: 200 OK
   ```

3. **Manual Animation Test**:
   ```bash
   curl -X POST http://localhost:8080/display-answers \
     -H "Content-Type: application/json" \
     -d '{"answers":[3,2,4]}'
   # Widget should animate
   ```

4. **Restart Stats App**:
   ```bash
   pkill Stats
   cd cloned-stats
   ./run-swift.sh
   ```

---

## Port Already In Use

**Problem**: "EADDRINUSE" or port conflict

**Solutions**:

**Port 9223 (CDP Service)**:
```bash
lsof -ti:9223 | xargs kill -9
cd chrome-cdp-service && npm start
```

**Port 3000 (Backend)**:
```bash
lsof -ti:3000 | xargs kill -9
cd backend && npm start
```

**Port 8080 (Stats App)**:
```bash
lsof -ti:8080 | xargs kill -9
./run-swift.sh
```

**Port 9222 (Chrome Debug)**:
```bash
pkill -f "Google Chrome.*remote-debugging-port"
# Restart CDP service (will launch Chrome)
```

---

## OpenAI API Errors

### Invalid API Key

**Error**: "Incorrect API key provided"

**Solutions**:
1. Verify key at https://platform.openai.com/api-keys
2. Delete old key if exposed
3. Create new key
4. Update backend/.env
5. Restart backend

### Rate Limit Exceeded

**Error**: "Rate limit reached"

**Solutions**:
1. Wait 60 seconds
2. Upgrade OpenAI plan if needed
3. Check usage: https://platform.openai.com/usage

### Insufficient Quota

**Error**: "You exceeded your current quota"

**Solutions**:
1. Add payment method at https://platform.openai.com/account/billing
2. Purchase credits
3. Check usage limits

---

## PDF Upload Fails

**Problem**: "Failed to upload PDF"

**Solutions**:

1. **Check File Size** (max 512 MB):
   ```bash
   ls -lh /path/to/file.pdf
   ```

2. **Check File Permissions**:
   ```bash
   ls -l /path/to/file.pdf
   # Should have read permissions
   ```

3. **Verify PDF Valid**:
   ```bash
   file /path/to/file.pdf
   # Should show: PDF document
   ```

4. **Check Backend Logs**:
   ```bash
   tail -100 ~/Library/Logs/stats-backend.error.log
   ```

---

## Build Errors

### Swift Build Fails

**Problem**: xcodebuild errors

**Solutions**:

1. **Clean Build**:
   ```bash
   cd cloned-stats
   rm -rf build/
   xcodebuild clean
   ./build-swift.sh
   ```

2. **Update Xcode**:
   ```bash
   xcode-select --install
   ```

3. **Check Dependencies**:
   - Ensure all Swift files compile
   - Check for syntax errors in Xcode

### npm Install Fails

**Problem**: npm errors during installation

**Solutions**:

1. **Clear npm Cache**:
   ```bash
   npm cache clean --force
   npm install
   ```

2. **Delete node_modules**:
   ```bash
   rm -rf node_modules/ package-lock.json
   npm install
   ```

3. **Update Node.js**:
   ```bash
   node --version  # Should be 18+
   # Update if needed from nodejs.org
   ```

---

## Performance Issues

### Slow Screenshot Capture

**Problem**: Screenshots take >5 seconds

**Solutions**:
1. Close unused Chrome tabs
2. Restart Chrome
3. Reduce page content before capture
4. Check CPU usage (should be <80%)

### High Memory Usage

**Problem**: System using >1 GB RAM

**Solutions**:
1. **Check memory**:
   ```bash
   ps aux | grep -E "node|Stats|Chrome"
   ```
2. Restart services periodically
3. Close unused applications
4. Restart Chrome

### Backend Timeout

**Problem**: Quiz analysis takes >60 seconds

**Solutions**:
1. Check OpenAI API status
2. Use gpt-3.5-turbo instead of gpt-4 (faster)
3. Reduce PDF size
4. Check internet connection

---

## Common Error Messages

### "No active tab found"

**Cause**: Chrome has no open tabs

**Solution**: Open a webpage in Chrome

### "No PDF script has been uploaded"

**Cause**: No PDF uploaded yet

**Solution**: Press Cmd+Option+L and select PDF

### "Chrome not connected"

**Cause**: Chrome debug port not accessible

**Solution**: Restart CDP service

### "Thread not found"

**Cause**: OpenAI thread expired or deleted

**Solution**: Re-upload PDF (Cmd+Option+L)

---

## Diagnostic Scripts

### Full System Check

```bash
#!/bin/bash
echo "=== Stats Quiz System Diagnostics ==="

# Services
echo -n "CDP Service: "
curl -s http://localhost:9223/health > /dev/null && echo "OK" || echo "FAIL"

echo -n "Backend: "
curl -s http://localhost:3000/health > /dev/null && echo "OK" || echo "FAIL"

echo -n "Stats App: "
curl -s http://localhost:8080/health > /dev/null && echo "OK" || echo "FAIL"

# Processes
echo -e "\nProcesses:"
ps aux | grep -E "node.*server.js|Stats" | grep -v grep

# Ports
echo -e "\nPorts:"
lsof -i :9223 -i :3000 -i :8080 -i :9222 | grep LISTEN

# Memory
echo -e "\nMemory Usage:"
ps aux | grep -E "node|Stats" | awk '{sum+=$6} END {print sum/1024 " MB"}'
```

Save as `diagnose.sh` and run: `bash diagnose.sh`

---

## When to Restart

**Restart CDP Service** if:
- Screenshot capture fails
- Chrome connection lost
- Port 9223 not responding

**Restart Backend** if:
- Quiz processing fails
- OpenAI API errors persist
- Port 3000 not responding

**Restart Stats App** if:
- Keyboard shortcuts don't work
- Animation doesn't display
- Port 8080 not responding

**Restart Everything** if:
- Multiple services failing
- System behaving erratically
- After configuration changes

---

## Getting Help

1. **Check Documentation**:
   - [FINAL_SYSTEM_DOCUMENTATION.md](FINAL_SYSTEM_DOCUMENTATION.md)
   - [QUICKSTART.md](QUICKSTART.md)
   - [DEPLOYMENT.md](DEPLOYMENT.md)

2. **Check Logs**:
   - CDP Service: Terminal output or ~/Library/Logs/stats-cdp.log
   - Backend: Terminal output or ~/Library/Logs/stats-backend.log
   - Stats App: Console.app

3. **Review Wave Documentation**:
   - Wave 1-5 completion reports
   - Implementation guides
   - Test reports

---

**Troubleshooting Guide Version**: 2.0.0
**Last Updated**: November 13, 2025

---

**END OF TROUBLESHOOTING GUIDE**
