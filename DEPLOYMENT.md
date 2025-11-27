# Production Deployment Guide

**Version**: 2.0.0
**Target**: macOS 10.15+ (Production Single-User)
**Last Updated**: November 13, 2025

---

## Table of Contents

1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [Production Build](#production-build)
3. [Environment Configuration](#environment-configuration)
4. [Service Installation](#service-installation)
5. [Auto-Start Configuration](#auto-start-configuration)
6. [Validation](#validation)
7. [Monitoring](#monitoring)
8. [Backup & Recovery](#backup--recovery)
9. [Rollback Procedure](#rollback-procedure)
10. [Security Hardening](#security-hardening)

---

## Pre-Deployment Checklist

### System Requirements

- [ ] macOS 10.15+ (Catalina or later) installed
- [ ] Node.js 18+ installed and verified (`node --version`)
- [ ] npm 9+ installed and verified (`npm --version`)
- [ ] Xcode command-line tools installed (`xcode-select --install`)
- [ ] Google Chrome installed (latest stable)
- [ ] 8 GB RAM minimum (16 GB recommended)
- [ ] 2 GB free disk space
- [ ] Administrator access to machine

### Testing Requirements

- [ ] All tests passing (Wave 5A: 95.5% pass rate minimum)
- [ ] Security audit complete (Wave 3B: 92/100 score minimum)
- [ ] Manual QA testing complete (Wave 5B)
- [ ] Performance benchmarks met:
  - Screenshot capture < 3 seconds
  - Quiz analysis < 60 seconds
  - Memory usage < 500 MB total

### Configuration Requirements

- [ ] OpenAI API key obtained (GPT-4 access enabled)
- [ ] API key tested and verified working
- [ ] OpenAI account has sufficient credits
- [ ] Rate limits understood and acceptable
- [ ] Data usage policy reviewed

### Permissions & Security

- [ ] macOS Accessibility permission plan prepared
- [ ] Firewall configuration reviewed
- [ ] Network security requirements understood
- [ ] API key storage location secured
- [ ] Backup strategy defined

---

## Production Build

### Step 1: Clean Build Environment

```bash
cd ~/Desktop/Universität/Stats

# Clean all build artifacts
cd cloned-stats
rm -rf build/
xcodebuild clean

# Clean node_modules
cd ../chrome-cdp-service
rm -rf node_modules/ dist/

cd ../backend
rm -rf node_modules/

# Clean tests
cd ../tests
rm -rf node_modules/ coverage/
```

### Step 2: Install Production Dependencies

```bash
# CDP Service
cd ~/Desktop/Universität/Stats/chrome-cdp-service
npm ci --production

# Backend
cd ../backend
npm ci --production

# Note: Don't install test dependencies in production
```

### Step 3: Build CDP Service

```bash
cd ~/Desktop/Universität/Stats/chrome-cdp-service
npm run build
```

**Expected output**: Compiled TypeScript files in `dist/` directory

**Verification**:
```bash
ls -la dist/
# Should show: index.js, chrome-manager.js, cdp-client.js, types.js
```

### Step 4: Build Stats App (Code-Signed)

**For Testing (No Code Sign)**:
```bash
cd ~/Desktop/Universität/Stats/cloned-stats
xcodebuild -project Stats.xcodeproj -scheme Stats \
  -configuration Release \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
```

**For Production (Code-Signed)**:

*Note: Requires Apple Developer ID certificate*

```bash
cd ~/Desktop/Universität/Stats/cloned-stats
xcodebuild -project Stats.xcodeproj -scheme Stats \
  -configuration Release \
  CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)" \
  build
```

**Expected output**: "BUILD SUCCEEDED" in 1-2 minutes

**Verification**:
```bash
ls -la build/Build/Products/Release/Stats.app
# Should show Stats.app bundle

# Verify code signature (production only)
codesign -dv --verbose=4 build/Build/Products/Release/Stats.app
```

### Step 5: Create Distribution Package

```bash
cd ~/Desktop/Universität/Stats

# Create distribution directory
mkdir -p dist/StatsQuizSystem

# Copy built artifacts
cp -R cloned-stats/build/Build/Products/Release/Stats.app dist/StatsQuizSystem/
cp -R chrome-cdp-service dist/StatsQuizSystem/
cp -R backend dist/StatsQuizSystem/

# Copy documentation
cp FINAL_SYSTEM_DOCUMENTATION.md dist/StatsQuizSystem/
cp QUICKSTART.md dist/StatsQuizSystem/
cp TROUBLESHOOTING.md dist/StatsQuizSystem/

# Create archive
cd dist
tar -czf StatsQuizSystem-v2.0.0.tar.gz StatsQuizSystem/
```

**Verification**:
```bash
ls -lh StatsQuizSystem-v2.0.0.tar.gz
# Should show ~50-100 MB archive
```

---

## Environment Configuration

### Step 1: Create Production Environment File

```bash
cd ~/Desktop/Universität/Stats/backend

# Create production .env
cat > .env << 'EOF'
# Production Configuration
NODE_ENV=production
LOG_LEVEL=error

# OpenAI Configuration
OPENAI_API_KEY=sk-proj-YOUR_PRODUCTION_KEY_HERE
OPENAI_MODEL=gpt-4-turbo-preview

# Server Configuration
BACKEND_PORT=3000
STATS_APP_URL=http://localhost:8080

# Security Configuration
CORS_ALLOWED_ORIGINS=http://localhost:8080
RATE_LIMIT_ENABLED=true
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

# Monitoring
ENABLE_METRICS=true
METRICS_PORT=9090
EOF
```

### Step 2: Secure Environment File

```bash
# Restrict permissions
chmod 600 backend/.env

# Verify ownership
ls -la backend/.env
# Should show: -rw------- (owner read/write only)
```

### Step 3: Configure CDP Service

```bash
cd ~/Desktop/Universität/Stats/chrome-cdp-service

# Create production config
cat > .env << 'EOF'
# CDP Service Production Configuration
NODE_ENV=production
LOG_LEVEL=error

# Chrome Configuration
CHROME_PORT=9222
SERVICE_PORT=9223

# Stealth Mode
CHROME_HEADLESS=false
CHROME_DISABLE_AUTOMATION=true
EOF

chmod 600 .env
```

---

## Service Installation

### Option 1: Manual Start (Development/Testing)

**Terminal 1: CDP Service**
```bash
cd ~/Desktop/Universität/Stats/chrome-cdp-service
npm run serve
```

**Terminal 2: Backend**
```bash
cd ~/Desktop/Universität/Stats/backend
NODE_ENV=production npm start
```

**Terminal 3: Stats App**
```bash
cd ~/Desktop/Universität/Stats/cloned-stats
open build/Build/Products/Release/Stats.app
```

### Option 2: launchd Daemons (Production)

#### CDP Service Daemon

**Create plist**:
```bash
mkdir -p ~/Library/LaunchAgents

cat > ~/Library/LaunchAgents/com.stats.cdp-service.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.stats.cdp-service</string>

    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/node</string>
        <string>dist/index.js</string>
    </array>

    <key>WorkingDirectory</key>
    <string>/Users/YOUR_USERNAME/Desktop/Universität/Stats/chrome-cdp-service</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>NODE_ENV</key>
        <string>production</string>
    </dict>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>

    <key>StandardOutPath</key>
    <string>/Users/YOUR_USERNAME/Library/Logs/stats-cdp.log</string>

    <key>StandardErrorPath</key>
    <string>/Users/YOUR_USERNAME/Library/Logs/stats-cdp.error.log</string>
</dict>
</plist>
EOF
```

**Replace `YOUR_USERNAME`** with actual username:
```bash
whoami
# Use this value to replace YOUR_USERNAME in the plist
```

**Load daemon**:
```bash
launchctl load ~/Library/LaunchAgents/com.stats.cdp-service.plist
```

#### Backend Service Daemon

**Create plist**:
```bash
cat > ~/Library/LaunchAgents/com.stats.backend.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.stats.backend</string>

    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/node</string>
        <string>server.js</string>
    </array>

    <key>WorkingDirectory</key>
    <string>/Users/YOUR_USERNAME/Desktop/Universität/Stats/backend</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>NODE_ENV</key>
        <string>production</string>
    </dict>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>

    <key>StandardOutPath</key>
    <string>/Users/YOUR_USERNAME/Library/Logs/stats-backend.log</string>

    <key>StandardErrorPath</key>
    <string>/Users/YOUR_USERNAME/Library/Logs/stats-backend.error.log</string>
</dict>
</plist>
EOF
```

**Load daemon**:
```bash
launchctl load ~/Library/LaunchAgents/com.stats.backend.plist
```

#### Stats App Login Item

**Add to Login Items**:
1. Open System Preferences → Users & Groups
2. Select your user account
3. Click "Login Items" tab
4. Click '+' button
5. Navigate to `Stats.app`
6. Add and ensure "Hide" is NOT checked

---

## Auto-Start Configuration

### Verify Services Start on Login

```bash
# Check CDP service
launchctl list | grep com.stats.cdp-service
# Should show running status

# Check backend
launchctl list | grep com.stats.backend
# Should show running status
```

### Test Auto-Start

1. **Logout** of macOS
2. **Login** again
3. **Verify** all services running:

```bash
# Check processes
ps aux | grep -E "node|Stats"

# Check ports
lsof -i :9223  # CDP Service
lsof -i :3000  # Backend
lsof -i :8080  # Stats App
```

### Manage Services

**Stop service**:
```bash
launchctl unload ~/Library/LaunchAgents/com.stats.cdp-service.plist
launchctl unload ~/Library/LaunchAgents/com.stats.backend.plist
```

**Start service**:
```bash
launchctl load ~/Library/LaunchAgents/com.stats.cdp-service.plist
launchctl load ~/Library/LaunchAgents/com.stats.backend.plist
```

**Restart service**:
```bash
launchctl unload ~/Library/LaunchAgents/com.stats.backend.plist
launchctl load ~/Library/LaunchAgents/com.stats.backend.plist
```

**View logs**:
```bash
tail -f ~/Library/Logs/stats-backend.log
tail -f ~/Library/Logs/stats-cdp.log
```

---

## Validation

### Post-Deployment Validation Checklist

#### 1. Service Health Checks

```bash
# CDP Service
curl -s http://localhost:9223/health | jq .
# Expected: {"status":"ok","chrome":"connected"}

# Backend
curl -s http://localhost:3000/health | jq .
# Expected: {"status":"ok","openai_configured":true}

# Stats App
curl -s http://localhost:8080/health
# Expected: 200 OK
```

#### 2. Functional Testing

**Test Screenshot Capture**:
```bash
curl -X POST http://localhost:9223/capture-active-tab > /tmp/test.json
cat /tmp/test.json | jq '.success'
# Expected: true
```

**Test Backend API**:
```bash
curl -X POST http://localhost:3000/api/upload-pdf \
  -H "Content-Type: application/json" \
  -d '{"pdfPath":"/path/to/test.pdf"}'
# Expected: {"success":true,...}
```

**Test Stats App Animation**:
```bash
curl -X POST http://localhost:8080/display-answers \
  -H "Content-Type: application/json" \
  -d '{"answers":[3,2,4]}'
# Expected: 200 OK, widget animates
```

#### 3. End-to-End Test

1. Press **Cmd+Option+L** → Upload test PDF
2. Open test quiz in Chrome
3. Press **Cmd+Option+O** → Capture screenshot
4. Press **Cmd+Option+P** → Process quiz
5. Verify animation displays correctly

#### 4. Performance Validation

```bash
# Screenshot performance
time curl -X POST http://localhost:9223/capture-active-tab > /dev/null
# Expected: < 3 seconds

# Memory usage
ps aux | grep -E "node|Stats" | awk '{sum+=$6} END {print sum/1024 " MB"}'
# Expected: < 500 MB total

# CPU usage (should be low at idle)
ps aux | grep -E "node|Stats"
# Expected: < 10% CPU each
```

---

## Monitoring

### Log Files

**Location**:
```
~/Library/Logs/stats-cdp.log        # CDP Service stdout
~/Library/Logs/stats-cdp.error.log  # CDP Service stderr
~/Library/Logs/stats-backend.log    # Backend stdout
~/Library/Logs/stats-backend.error.log  # Backend stderr
```

**Monitor logs**:
```bash
# Real-time monitoring
tail -f ~/Library/Logs/stats-backend.log

# Check for errors
grep ERROR ~/Library/Logs/*.log

# Log rotation (manual)
for f in ~/Library/Logs/stats-*.log; do
  mv "$f" "$f.1"
  touch "$f"
done
```

### System Metrics

**CPU Usage**:
```bash
ps aux | grep -E "node.*server.js|Stats" | awk '{print $3}'
```

**Memory Usage**:
```bash
ps aux | grep -E "node.*server.js|Stats" | awk '{print $6/1024 " MB"}'
```

**Network Connections**:
```bash
lsof -i -n | grep -E "node|Stats"
```

### Health Check Script

```bash
cat > ~/check-stats-health.sh << 'EOF'
#!/bin/bash
echo "=== Stats Quiz System Health Check ==="
echo ""

# Check CDP Service
echo -n "CDP Service: "
curl -s http://localhost:9223/health > /dev/null && echo "OK" || echo "FAIL"

# Check Backend
echo -n "Backend: "
curl -s http://localhost:3000/health > /dev/null && echo "OK" || echo "FAIL"

# Check Stats App
echo -n "Stats App: "
curl -s http://localhost:8080/health > /dev/null && echo "OK" || echo "FAIL"

# Check processes
echo ""
echo "Running Processes:"
ps aux | grep -E "node.*server.js|Stats" | grep -v grep

# Check memory
echo ""
echo -n "Total Memory: "
ps aux | grep -E "node|Stats" | awk '{sum+=$6} END {print sum/1024 " MB"}'
EOF

chmod +x ~/check-stats-health.sh
```

**Usage**:
```bash
~/check-stats-health.sh
```

### Automated Alerts (Optional)

**Create alert script**:
```bash
cat > ~/stats-alert.sh << 'EOF'
#!/bin/bash
if ! curl -s http://localhost:3000/health > /dev/null; then
  osascript -e 'display notification "Backend service is down" with title "Stats Alert"'
fi
EOF

chmod +x ~/stats-alert.sh
```

**Schedule with cron**:
```bash
crontab -e
# Add: */5 * * * * ~/stats-alert.sh
```

---

## Backup & Recovery

### What to Backup

**Configuration Files**:
```bash
# Create backup directory
mkdir -p ~/stats-backups/$(date +%Y%m%d)

# Backup configuration
cp backend/.env ~/stats-backups/$(date +%Y%m%d)/
cp chrome-cdp-service/.env ~/stats-backups/$(date +%Y%m%d)/
cp ~/Library/LaunchAgents/com.stats.*.plist ~/stats-backups/$(date +%Y%m%d)/
```

**Application Bundle**:
```bash
cp -R cloned-stats/build/Build/Products/Release/Stats.app \
  ~/stats-backups/$(date +%Y%m%d)/
```

### Backup Script

```bash
cat > ~/backup-stats.sh << 'EOF'
#!/bin/bash
BACKUP_DIR=~/stats-backups/$(date +%Y%m%d-%H%M%S)
mkdir -p "$BACKUP_DIR"

echo "Backing up Stats Quiz System to $BACKUP_DIR"

# Backup configs
cp ~/Desktop/Universität/Stats/backend/.env "$BACKUP_DIR/"
cp ~/Desktop/Universität/Stats/chrome-cdp-service/.env "$BACKUP_DIR/"
cp ~/Library/LaunchAgents/com.stats.*.plist "$BACKUP_DIR/"

# Backup app
cp -R ~/Desktop/Universität/Stats/cloned-stats/build/Build/Products/Release/Stats.app \
  "$BACKUP_DIR/"

# Create archive
cd ~/stats-backups
tar -czf $(date +%Y%m%d-%H%M%S).tar.gz $(date +%Y%m%d-%H%M%S)

echo "Backup complete: $BACKUP_DIR.tar.gz"
EOF

chmod +x ~/backup-stats.sh
```

### Recovery Procedure

```bash
# 1. Stop all services
launchctl unload ~/Library/LaunchAgents/com.stats.*.plist
pkill Stats

# 2. Restore from backup
BACKUP_DATE=YYYYMMDD  # Replace with backup date
cd ~/stats-backups
tar -xzf $BACKUP_DATE.tar.gz

# 3. Restore configs
cp $BACKUP_DATE/.env ~/Desktop/Universität/Stats/backend/
cp $BACKUP_DATE/.env ~/Desktop/Universität/Stats/chrome-cdp-service/
cp $BACKUP_DATE/com.stats.*.plist ~/Library/LaunchAgents/

# 4. Restore app
cp -R $BACKUP_DATE/Stats.app \
  ~/Desktop/Universität/Stats/cloned-stats/build/Build/Products/Release/

# 5. Restart services
launchctl load ~/Library/LaunchAgents/com.stats.*.plist
open ~/Desktop/Universität/Stats/cloned-stats/build/Build/Products/Release/Stats.app

# 6. Verify
~/check-stats-health.sh
```

---

## Rollback Procedure

### Quick Rollback

```bash
# 1. Stop current version
launchctl unload ~/Library/LaunchAgents/com.stats.*.plist
pkill Stats

# 2. Restore previous version
cd ~/stats-backups
PREV_BACKUP=$(ls -t *.tar.gz | head -2 | tail -1)
tar -xzf "$PREV_BACKUP"

# 3. Copy files
PREV_DIR=${PREV_BACKUP%.tar.gz}
cp $PREV_DIR/.env ~/Desktop/Universität/Stats/backend/
cp -R $PREV_DIR/Stats.app \
  ~/Desktop/Universität/Stats/cloned-stats/build/Build/Products/Release/

# 4. Restart
launchctl load ~/Library/LaunchAgents/com.stats.*.plist
open ~/Desktop/Universität/Stats/cloned-stats/build/Build/Products/Release/Stats.app
```

### Verify Rollback

```bash
~/check-stats-health.sh
# All services should be OK
```

---

## Security Hardening

### Network Security

**Enable macOS Firewall**:
1. System Preferences → Security & Privacy → Firewall
2. Turn On Firewall
3. Firewall Options:
   - Block all incoming connections
   - Allow Node.js (for localhost only)
   - Allow Stats.app

**Verify localhost binding**:
```bash
# Services should only listen on 127.0.0.1
netstat -an | grep LISTEN | grep -E "9223|3000|8080"
# Should show 127.0.0.1:*, not 0.0.0.0:*
```

### API Key Security

**Encrypt .env file** (optional):
```bash
# Encrypt
openssl enc -aes-256-cbc -salt -in backend/.env -out backend/.env.enc

# Decrypt (for use)
openssl enc -d -aes-256-cbc -in backend/.env.enc -out backend/.env
```

**Secure permissions**:
```bash
chmod 600 backend/.env
chmod 600 chrome-cdp-service/.env
```

**Rotate API key regularly**:
1. Generate new key at https://platform.openai.com/api-keys
2. Update backend/.env
3. Restart backend service
4. Delete old key

### Application Security

**Code signing verification**:
```bash
codesign -dv --verbose=4 Stats.app
# Should show valid Developer ID signature
```

**Notarization** (for distribution):
```bash
# Submit for notarization
xcrun altool --notarize-app \
  --primary-bundle-id "com.stats.app" \
  --username "your@email.com" \
  --password "@keychain:AC_PASSWORD" \
  --file Stats.zip
```

---

## Troubleshooting Deployment

### Service Won't Start

**Check logs**:
```bash
tail -100 ~/Library/Logs/stats-backend.error.log
```

**Check permissions**:
```bash
ls -la ~/Library/LaunchAgents/com.stats.*.plist
# Should show readable permissions
```

**Manually test**:
```bash
cd ~/Desktop/Universität/Stats/backend
NODE_ENV=production node server.js
# Watch for errors
```

### Port Conflicts

```bash
# Find what's using port
lsof -i :3000

# Kill process
lsof -ti:3000 | xargs kill -9
```

### OpenAI API Errors

```bash
# Test API key
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY"

# Check rate limits
curl https://api.openai.com/v1/usage \
  -H "Authorization: Bearer $OPENAI_API_KEY"
```

---

## Support

**For issues**, check:
1. [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. Service logs in `~/Library/Logs/`
3. [FINAL_SYSTEM_DOCUMENTATION.md](FINAL_SYSTEM_DOCUMENTATION.md)

---

**Deployment Guide Version**: 2.0.0
**Last Updated**: November 13, 2025
**Status**: Production Documentation

---

**END OF DEPLOYMENT GUIDE**
