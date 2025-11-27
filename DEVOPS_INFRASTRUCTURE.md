# Quiz Stats Animation System - DevOps & Infrastructure Documentation

## Table of Contents
1. [Overview](#overview)
2. [Infrastructure Architecture](#infrastructure-architecture)
3. [Docker Setup](#docker-setup)
4. [CI/CD Pipeline](#cicd-pipeline)
5. [Security Hardening](#security-hardening)
6. [Monitoring & Logging](#monitoring--logging)
7. [Deployment Procedures](#deployment-procedures)
8. [Troubleshooting](#troubleshooting)
9. [SLA/SLO Definitions](#slaslo-definitions)

---

## Overview

This document describes the complete production-ready infrastructure and DevOps setup for the Quiz Stats Animation System, a Node.js-based application that scrapes quiz questions, analyzes them using OpenAI, and displays animated results.

### System Components
- **Backend API**: Express.js server (Node.js)
- **Scraper Service**: Playwright-based web scraper
- **Redis Cache**: Session and response caching
- **Nginx**: Reverse proxy and load balancer
- **Monitoring Stack**: Prometheus, Grafana, Loki

---

## Infrastructure Architecture

### Architecture Diagram (Text-based)

```
                                    Internet
                                       |
                                   [Nginx Proxy]
                                   Port 80/443
                                       |
                         +-------------+-------------+
                         |                           |
                  [Load Balancer]              [Rate Limiter]
                         |                           |
            +------------+------------+              |
            |            |            |              |
      [Backend 1]  [Backend 2]  [Backend 3]    [WebSocket]
       Port 3000    Port 3000    Port 3000         |
            |            |            |              |
            +------------+------------+--------------+
                         |
                    [Redis Cache]
                     Port 6379
                         |
                +--------+--------+
                |                 |
           [OpenAI API]      [Stats App]
        (External Service)   (Swift/macOS)
                                  |
                            [Animation Display]


         Monitoring & Logging Layer (Separate Network)
         +-----------------------------------------+
         |                                         |
      [Prometheus]  [Grafana]  [Loki]  [Alertmanager]
       Port 9090    Port 3001  Port 3100  Port 9093
```

### Network Architecture

**Development Environment:**
- Single Docker network: `quiz-network` (172.20.0.0/16)
- All services communicate via Docker DNS
- Ports exposed to host for debugging

**Production Environment:**
- Multiple networks for security isolation:
  - `frontend-network`: Nginx only
  - `backend-network`: Backend services + Redis
  - `monitoring-network`: Metrics collection
- Minimal port exposure
- Firewall rules for inter-service communication

### Data Flow

1. **Request Flow:**
   ```
   Client → Nginx (Rate Limit) → Backend API → OpenAI API
                                → Redis Cache
                                → Stats App (WebSocket/HTTP)
   ```

2. **Metrics Flow:**
   ```
   Services → Prometheus → Grafana → Alert Manager → Slack/Email
   ```

3. **Log Flow:**
   ```
   Services → Loki → Grafana → Query/Analysis
   ```

---

## Docker Setup

### Container Strategy

**Backend Container:**
- Base: Node.js 20 Alpine (minimal footprint)
- Multi-stage build for optimization
- Non-root user execution
- Health checks included
- Resource limits enforced

**Scraper Container:**
- Base: Playwright official image
- Chromium browser included
- Headless operation
- Screenshot capability for debugging

### Building Images

```bash
# Build backend
cd backend
docker build -t quiz-backend:latest .

# Build scraper
docker build -f scraper.Dockerfile -t quiz-scraper:latest .

# Build with Docker Compose
docker-compose build
```

### Development Environment

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f backend

# Check service health
docker-compose ps

# Stop services
docker-compose down

# Clean up volumes
docker-compose down -v
```

### Production Environment

```bash
# Deploy to production
docker-compose -f docker-compose.prod.yml up -d

# Rolling update (zero-downtime)
docker-compose -f docker-compose.prod.yml up -d --no-deps --build backend

# Scale backend services
docker-compose -f docker-compose.prod.yml up -d --scale backend=3
```

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
nano .env
```

**Critical Variables:**
- `OPENAI_API_KEY`: Your OpenAI API key
- `REDIS_PASSWORD`: Strong password for Redis
- `JWT_SECRET`: Secret for JWT authentication
- `NODE_ENV`: production/development/staging

### Volume Management

**Persistent Volumes:**
- `redis-data`: Redis persistence
- `backend-logs`: Application logs
- `prometheus-data`: Metrics data
- `grafana-data`: Dashboard configs
- `loki-data`: Log storage
- `nginx-logs`: Access/error logs

**Backup Strategy:**
```bash
# Backup volumes
docker run --rm -v quiz-stats_redis-data:/data \
  -v $(pwd)/backups:/backup alpine \
  tar czf /backup/redis-backup-$(date +%Y%m%d).tar.gz /data

# Restore volumes
docker run --rm -v quiz-stats_redis-data:/data \
  -v $(pwd)/backups:/backup alpine \
  tar xzf /backup/redis-backup-YYYYMMDD.tar.gz -C /
```

---

## CI/CD Pipeline

### GitHub Actions Workflows

**1. Continuous Integration (`ci.yml`)**
- Triggered on: Push to main/develop, Pull Requests
- Jobs:
  - Code linting (ESLint, Prettier)
  - Security scanning (Trivy, npm audit, TruffleHog)
  - Unit tests (Jest)
  - Docker image building
  - Integration tests

**2. Continuous Deployment (`cd.yml`)**
- Triggered on: Push to main, version tags
- Jobs:
  - Build and push Docker images to GHCR
  - Deploy to staging (automatic)
  - Deploy to production (manual approval required)
  - Health checks and smoke tests
  - Rollback on failure

**3. Security Scanning (`security-scan.yml`)**
- Triggered on: Daily schedule, Pull Requests
- Jobs:
  - Dependency vulnerability scanning (Snyk, OWASP)
  - Container image scanning (Trivy, Grype)
  - SAST (CodeQL, Semgrep)
  - Secret scanning (Gitleaks, TruffleHog)
  - License compliance checking

### Required GitHub Secrets

Configure these in: Repository Settings → Secrets and Variables → Actions

```
OPENAI_API_KEY              # OpenAI API key
REDIS_PASSWORD              # Redis authentication
JWT_SECRET                  # JWT signing secret

# Deployment
STAGING_HOST                # Staging server IP
STAGING_USER                # SSH user
STAGING_SSH_KEY             # SSH private key

PRODUCTION_HOST             # Production server IP
PRODUCTION_USER             # SSH user
PRODUCTION_SSH_KEY          # SSH private key

# Monitoring
SLACK_WEBHOOK               # Slack notifications
SENTRY_DSN                  # Error tracking

# Security Scanning
SNYK_TOKEN                  # Snyk vulnerability scanning
```

### Branch Strategy

```
main (production)
  ↑
develop (staging)
  ↑
feature/* (CI only)
```

**Workflow:**
1. Create feature branch from `develop`
2. CI runs on every push
3. Merge to `develop` → Auto-deploy to staging
4. Merge to `main` → Manual approval → Deploy to production
5. Tag release (v1.0.0) → GitHub release + production deploy

### Rollback Procedure

**Manual Rollback:**
```bash
# SSH to production server
ssh deploy@production-server

# View running containers
docker-compose -f docker-compose.prod.yml ps

# Rollback to previous image
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml pull <previous-tag>
docker-compose -f docker-compose.prod.yml up -d
```

**Automated Rollback:**
- CI/CD pipeline automatically rolls back if health checks fail
- Backup containers kept running during deployment
- Database migrations are versioned and reversible

---

## Security Hardening

### API Security

**1. Authentication**
```javascript
// API Key authentication
const apiKey = req.headers['x-api-key'];
if (apiKey !== process.env.API_KEY) {
  return res.status(401).json({ error: 'Unauthorized' });
}

// JWT authentication (for user sessions)
const token = req.headers.authorization?.split(' ')[1];
const decoded = jwt.verify(token, process.env.JWT_SECRET);
```

**2. Rate Limiting**
- Nginx level: 5 req/s per IP for API endpoints
- Application level: Express rate limiter
- OpenAI endpoint: 1 req/s (stricter)

**3. CORS Configuration**

Development:
```javascript
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'OPTIONS']
}));
```

Production:
```javascript
app.use(cors({
  origin: ['https://quiz-stats.example.com'],
  credentials: true,
  methods: ['GET', 'POST']
}));
```

**4. Input Validation**
```javascript
const { body, validationResult } = require('express-validator');

app.post('/api/analyze', [
  body('questions').isArray({ min: 1, max: 100 }),
  body('questions.*.question').isString().trim().notEmpty(),
  body('questions.*.answers').isArray({ min: 2, max: 10 })
], (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }
  // Process request
});
```

### Secrets Management

**Development:**
- `.env` files (gitignored)
- Local environment variables

**Production:**
- GitHub Secrets for CI/CD
- Docker secrets for sensitive data
- HashiCorp Vault (recommended for large deployments)

**Vault Setup (Optional):**
```bash
# Install Vault
docker run -d --name=vault --cap-add=IPC_LOCK \
  -e 'VAULT_DEV_ROOT_TOKEN_ID=myroot' \
  -p 8200:8200 vault

# Store secrets
vault kv put secret/quiz-stats \
  openai_api_key="sk-..." \
  redis_password="..." \
  jwt_secret="..."

# Retrieve in app
const vault = require('node-vault')();
const secrets = await vault.read('secret/data/quiz-stats');
```

### CSRF Protection

```javascript
const csrf = require('csurf');
const csrfProtection = csrf({ cookie: true });

app.use(csrfProtection);

app.get('/form', (req, res) => {
  res.json({ csrfToken: req.csrfToken() });
});
```

### Security Headers

Configured in Nginx:
- `X-Frame-Options: DENY`
- `X-Content-Type-Options: nosniff`
- `X-XSS-Protection: 1; mode=block`
- `Strict-Transport-Security: max-age=31536000`
- `Content-Security-Policy: default-src 'self'`

### DDoS Protection

**Nginx Level:**
```nginx
# Connection limits
limit_conn_zone $binary_remote_addr zone=conn_limit:10m;
limit_conn conn_limit 10;

# Request rate limits
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=5r/s;
limit_req zone=api_limit burst=10 nodelay;

# IP blacklisting
geo $limit {
    default 1;
    # Whitelist trusted IPs
    10.0.0.0/8 0;
}
```

**Application Level:**
```javascript
const rateLimit = require('express-rate-limit');

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP'
});

app.use('/api/', limiter);
```

### SSL/TLS Configuration

**Generate Self-Signed Certificate (Development):**
```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/key.pem \
  -out nginx/ssl/cert.pem
```

**Production (Let's Encrypt):**
```bash
certbot certonly --webroot -w /var/www/html \
  -d quiz-stats.example.com \
  --email admin@example.com --agree-tos
```

---

## Monitoring & Logging

### Metrics Collection (Prometheus)

**Backend Metrics:**
```javascript
const promClient = require('prom-client');

// Create metrics
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status']
});

const openaiRequestsTotal = new promClient.Counter({
  name: 'openai_requests_total',
  help: 'Total OpenAI API requests',
  labelNames: ['status']
});

// Middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestDuration.labels(req.method, req.route?.path, res.statusCode).observe(duration);
  });
  next();
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', promClient.register.contentType);
  res.end(await promClient.register.metrics());
});
```

### Structured Logging

**Winston Logger Setup:**
```javascript
const winston = require('winston');

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'quiz-backend' },
  transports: [
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' }),
    new winston.transports.Console({
      format: winston.format.simple()
    })
  ]
});

// Usage
logger.info('Processing quiz questions', {
  questionCount: questions.length,
  requestId: req.id
});

logger.error('OpenAI API error', {
  error: err.message,
  stack: err.stack,
  requestId: req.id
});
```

### Grafana Dashboards

**Access Grafana:**
- URL: http://localhost:3001
- Username: admin
- Password: admin (change on first login)

**Pre-configured Dashboards:**

1. **Backend Performance:**
   - Request rate (req/s)
   - Response time (p50, p95, p99)
   - Error rate (4xx, 5xx)
   - OpenAI API latency

2. **Resource Usage:**
   - CPU usage per container
   - Memory usage per container
   - Network I/O
   - Disk I/O

3. **Business Metrics:**
   - Quiz questions processed
   - OpenAI token usage
   - WebSocket connections
   - Cache hit rate

4. **Redis Metrics:**
   - Memory usage
   - Connected clients
   - Commands per second
   - Cache hit/miss ratio

### Alert Configuration

**Slack Integration:**
```bash
# Add to Grafana notification channels
Name: Slack Alerts
Type: Slack
Webhook URL: https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

**Email Alerts (SMTP):**
```yaml
# prometheus/alertmanager.yml
receivers:
  - name: 'email-alerts'
    email_configs:
      - to: 'ops@example.com'
        from: 'alertmanager@example.com'
        smarthost: 'smtp.gmail.com:587'
        auth_username: 'alerts@example.com'
        auth_password: 'password'
```

### Log Aggregation (Loki)

**Query Examples:**
```
# All backend errors
{service="backend"} |= "error"

# OpenAI API failures
{service="backend"} |= "OpenAI" |= "error"

# Slow requests (>1s)
{service="backend"} | json | duration > 1s

# Rate limit exceeded
{service="nginx"} |= "limiting requests"
```

### Health Checks

**Backend Health Endpoint:**
```javascript
app.get('/health', (req, res) => {
  const health = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    checks: {
      redis: redisClient.ping() ? 'ok' : 'down',
      openai: !!process.env.OPENAI_API_KEY ? 'configured' : 'not configured'
    }
  };

  const status = Object.values(health.checks).every(v => v === 'ok' || v === 'configured') ? 200 : 503;
  res.status(status).json(health);
});
```

**Docker Health Checks:**
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1
```

---

## Deployment Procedures

### Initial Server Setup

**1. Provision Server:**
- Ubuntu 22.04 LTS (recommended)
- Minimum: 2 CPU, 4GB RAM, 20GB disk
- Recommended: 4 CPU, 8GB RAM, 50GB disk

**2. Install Docker:**
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Add user to docker group
sudo usermod -aG docker $USER
```

**3. Setup Firewall:**
```bash
sudo ufw allow 22/tcp     # SSH
sudo ufw allow 80/tcp     # HTTP
sudo ufw allow 443/tcp    # HTTPS
sudo ufw enable
```

**4. Clone Repository:**
```bash
cd /opt
sudo mkdir quiz-stats
sudo chown $USER:$USER quiz-stats
cd quiz-stats
git clone https://github.com/yourusername/quiz-stats.git .
```

**5. Configure Environment:**
```bash
cp .env.example .env
nano .env
# Set all production values
```

### First Deployment

```bash
# Build images
docker-compose -f docker-compose.prod.yml build

# Start services
docker-compose -f docker-compose.prod.yml up -d

# Check logs
docker-compose -f docker-compose.prod.yml logs -f

# Verify health
curl http://localhost/health
```

### Update Deployment

```bash
# Pull latest changes
git pull origin main

# Rebuild and restart
docker-compose -f docker-compose.prod.yml up -d --build

# Or use CI/CD (recommended)
```

### Zero-Downtime Deployment

**Blue-Green Deployment:**
```bash
# Start new version (green)
docker-compose -f docker-compose.prod.yml up -d --scale backend=6

# Wait for health checks
sleep 30

# Stop old version (blue)
docker-compose -f docker-compose.prod.yml up -d --scale backend=3

# Cleanup old containers
docker system prune -f
```

**Rolling Update:**
```bash
# Update one replica at a time
for i in {1..3}; do
  docker-compose -f docker-compose.prod.yml up -d --no-deps --build backend
  sleep 30
done
```

### Database Migrations

If you add a database later:
```bash
# Create migration
npm run migrate:create add_users_table

# Run migrations
docker-compose -f docker-compose.prod.yml exec backend npm run migrate

# Rollback if needed
docker-compose -f docker-compose.prod.yml exec backend npm run migrate:rollback
```

### Backup Procedures

**Automated Daily Backup:**
```bash
# /opt/quiz-stats/backup.sh
#!/bin/bash
BACKUP_DIR="/opt/backups/quiz-stats"
DATE=$(date +%Y%m%d-%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup Redis data
docker-compose -f /opt/quiz-stats/docker-compose.prod.yml exec -T redis redis-cli BGSAVE

# Backup volumes
docker run --rm \
  -v quiz-stats_redis-data:/data \
  -v $BACKUP_DIR:/backup \
  alpine tar czf /backup/redis-$DATE.tar.gz /data

# Backup configuration
tar czf $BACKUP_DIR/config-$DATE.tar.gz \
  /opt/quiz-stats/.env \
  /opt/quiz-stats/docker-compose.prod.yml \
  /opt/quiz-stats/nginx/

# Delete backups older than 30 days
find $BACKUP_DIR -type f -mtime +30 -delete

echo "Backup completed: $DATE"
```

**Schedule with Cron:**
```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /opt/quiz-stats/backup.sh >> /var/log/quiz-backup.log 2>&1
```

### Disaster Recovery

**Restore from Backup:**
```bash
# Stop services
docker-compose -f docker-compose.prod.yml down

# Restore Redis data
docker run --rm \
  -v quiz-stats_redis-data:/data \
  -v /opt/backups/quiz-stats:/backup \
  alpine tar xzf /backup/redis-YYYYMMDD-HHMMSS.tar.gz -C /

# Restore configuration
tar xzf /opt/backups/quiz-stats/config-YYYYMMDD-HHMMSS.tar.gz -C /

# Restart services
docker-compose -f docker-compose.prod.yml up -d
```

---

## Troubleshooting

### Common Issues

**1. Backend Service Not Starting**

Check logs:
```bash
docker-compose logs backend
```

Common causes:
- Missing environment variables → Check `.env` file
- Port already in use → `sudo lsof -i :3000`
- OpenAI API key invalid → Verify key in `.env`

**2. High Memory Usage**

Check container stats:
```bash
docker stats
```

Solutions:
- Increase memory limit in docker-compose.yml
- Enable Redis cache to reduce OpenAI calls
- Scale backend services horizontally

**3. OpenAI API Timeout**

Check logs:
```bash
docker-compose logs backend | grep OpenAI
```

Solutions:
- Increase timeout in `.env`: `OPENAI_TIMEOUT=60000`
- Retry failed requests automatically
- Check OpenAI API status: https://status.openai.com

**4. Rate Limiting Issues**

Check Nginx logs:
```bash
docker-compose logs nginx | grep limiting
```

Solutions:
- Adjust rate limits in `nginx/nginx.conf`
- Implement request queuing
- Use API keys to whitelist trusted clients

**5. Redis Connection Failed**

Check Redis health:
```bash
docker-compose exec redis redis-cli ping
```

Solutions:
- Verify Redis password in `.env`
- Check Redis is running: `docker-compose ps redis`
- Restart Redis: `docker-compose restart redis`

### Debug Mode

Enable debug logging:
```bash
# .env
LOG_LEVEL=debug
DEBUG=true

# Restart services
docker-compose restart backend
```

### Performance Profiling

**Node.js Profiling:**
```bash
# Start with profiler
docker-compose exec backend node --prof server.js

# Generate report
docker-compose exec backend node --prof-process isolate-*.log > profile.txt
```

**Check Database Queries:**
```bash
# Redis slow log
docker-compose exec redis redis-cli slowlog get 10
```

### Network Debugging

**Test connectivity:**
```bash
# Backend to Redis
docker-compose exec backend nc -zv redis 6379

# Backend to OpenAI
docker-compose exec backend curl -I https://api.openai.com

# Nginx to Backend
docker-compose exec nginx curl -I http://backend:3000/health
```

---

## SLA/SLO Definitions

### Service Level Objectives (SLOs)

**1. Availability:**
- Target: 99.9% uptime (43.2 minutes downtime per month)
- Measurement: Uptime monitoring via Prometheus
- Alert: If availability drops below 99.5% in any hour

**2. Response Time:**
- Target: 95% of requests < 500ms
- P99 target: < 2 seconds
- Measurement: Nginx and application metrics
- Alert: If P95 > 1s for 5 minutes

**3. Error Rate:**
- Target: < 1% of requests result in 5xx errors
- Measurement: HTTP status codes
- Alert: If error rate > 5% for 5 minutes

**4. OpenAI API Success Rate:**
- Target: > 99% successful responses
- Measurement: OpenAI request metrics
- Alert: If success rate < 95% for 10 minutes

### Service Level Agreements (SLAs)

**Customer-Facing:**
- **Uptime Guarantee**: 99.5% monthly uptime
- **Response Time**: 95% of requests under 1 second
- **Support Response**: Critical issues within 1 hour
- **Planned Maintenance**: < 4 hours per month, scheduled in advance

**Internal:**
- **Mean Time to Detect (MTTD)**: < 5 minutes
- **Mean Time to Resolve (MTTR)**: < 30 minutes for critical issues
- **Backup Frequency**: Daily automated backups
- **Recovery Time Objective (RTO)**: < 1 hour
- **Recovery Point Objective (RPO)**: < 24 hours

### Monitoring Metrics

**Golden Signals:**
1. **Latency**: Request duration
2. **Traffic**: Requests per second
3. **Errors**: Error rate
4. **Saturation**: Resource usage (CPU, memory)

**Application-Specific Metrics:**
- Quiz questions processed per hour
- OpenAI token usage per day
- WebSocket connection count
- Cache hit rate
- Rate limit exceeded count

### Incident Response

**Severity Levels:**

| Level | Description | Response Time | Example |
|-------|-------------|---------------|---------|
| P0 - Critical | Complete service outage | 15 minutes | Backend down, no requests |
| P1 - High | Major functionality impaired | 1 hour | OpenAI API failing |
| P2 - Medium | Degraded performance | 4 hours | Slow response times |
| P3 - Low | Minor issues | 1 business day | Non-critical bug |

**On-Call Rotation:**
- Primary: 24/7 coverage
- Secondary: Backup support
- Escalation: Team lead if unresolved in 30 minutes

---

## Additional Resources

### Useful Commands

```bash
# View all containers
docker-compose ps

# Restart specific service
docker-compose restart backend

# View logs with timestamps
docker-compose logs -f --tail=100 backend

# Execute command in container
docker-compose exec backend npm run migrate

# Check disk usage
docker system df

# Cleanup unused resources
docker system prune -a --volumes

# Export metrics
curl http://localhost:9090/api/v1/query?query=up

# Check Grafana dashboards
open http://localhost:3001
```

### Maintenance Schedule

**Daily:**
- Automated backups (2 AM UTC)
- Log rotation
- Security scanning

**Weekly:**
- Dependency updates review
- Performance analysis
- Capacity planning review

**Monthly:**
- Disaster recovery drill
- Security audit
- SLA/SLO review

### Support Contacts

- **DevOps Team**: devops@example.com
- **On-Call**: +1-XXX-XXX-XXXX
- **Security Issues**: security@example.com
- **Emergency Escalation**: CTO/VP Engineering

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-11-04 | Initial production infrastructure setup |

---

**Document Maintained By**: DevOps Team
**Last Updated**: 2025-11-04
**Next Review**: 2025-12-04
