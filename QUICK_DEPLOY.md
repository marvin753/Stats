# Quick Deployment Guide
## Quiz Stats Animation System

Get the system running in minutes!

---

## Prerequisites

- Docker & Docker Compose installed
- Git installed
- OpenAI API key

---

## 1. Clone & Setup (2 minutes)

```bash
# Clone repository
git clone https://github.com/yourusername/quiz-stats.git
cd quiz-stats

# Copy environment template
cp .env.example .env
```

---

## 2. Configure Environment (1 minute)

Edit `.env` and set your OpenAI API key:

```bash
# Open in your editor
nano .env

# Required: Add your OpenAI API key
OPENAI_API_KEY=sk-proj-your-api-key-here

# Optional: Change other settings
OPENAI_MODEL=gpt-3.5-turbo
BACKEND_PORT=3000
```

---

## 3. Start Services (1 minute)

### Development Mode

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f backend
```

### Production Mode

```bash
# Start production stack
docker-compose -f docker-compose.prod.yml up -d

# View status
docker-compose -f docker-compose.prod.yml ps
```

---

## 4. Verify Installation (30 seconds)

```bash
# Check health
curl http://localhost:3000/health

# Expected output:
# {"status":"ok","timestamp":"2025-11-04T...","openai_configured":true}

# Check services
docker-compose ps

# All services should show "Up"
```

---

## 5. Test the API (30 seconds)

```bash
# Send test request
curl -X POST http://localhost:3000/api/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "questions": [
      {
        "question": "What is 2+2?",
        "answers": ["1", "2", "3", "4"]
      }
    ]
  }'

# Expected output:
# {"status":"success","answers":[4],"questionCount":1}
```

---

## 6. Access Monitoring (Optional)

- **Grafana Dashboard**: http://localhost:3001
  - Username: `admin`
  - Password: `admin`

- **Prometheus**: http://localhost:9090

- **API Docs**: http://localhost:3000

---

## Common Commands

```bash
# Stop services
docker-compose down

# Restart services
docker-compose restart

# View logs
docker-compose logs -f

# Update services
git pull
docker-compose up -d --build

# Clean up
docker-compose down -v
docker system prune -af
```

---

## Troubleshooting

### Service won't start

```bash
# Check logs
docker-compose logs backend

# Common fixes:
# 1. Check .env file exists and has OPENAI_API_KEY
# 2. Ensure port 3000 is not in use: lsof -i :3000
# 3. Restart Docker: sudo systemctl restart docker
```

### OpenAI API errors

```bash
# Verify API key
docker-compose exec backend printenv OPENAI_API_KEY

# Should show your API key (not empty)

# Test OpenAI connection
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY"
```

### Redis connection failed

```bash
# Check Redis is running
docker-compose ps redis

# Restart Redis
docker-compose restart redis

# Check connection
docker-compose exec backend nc -zv redis 6379
```

---

## Next Steps

1. **Production Deployment**: See [DEVOPS_INFRASTRUCTURE.md](DEVOPS_INFRASTRUCTURE.md)
2. **Kubernetes**: See [KUBERNETES_DEPLOYMENT.md](KUBERNETES_DEPLOYMENT.md)
3. **Monitoring Setup**: See monitoring section in DEVOPS_INFRASTRUCTURE.md
4. **CI/CD Setup**: Configure GitHub Actions workflows

---

## Support

- **Documentation**: [DEVOPS_INFRASTRUCTURE.md](DEVOPS_INFRASTRUCTURE.md)
- **Architecture**: [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md)
- **Issues**: Create an issue on GitHub

---

**Total Setup Time**: ~5 minutes

That's it! Your Quiz Stats Animation System is now running.
