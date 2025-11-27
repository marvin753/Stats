# ========================================
# Scraper Dockerfile - Production Ready
# Quiz Stats Animation System
# ========================================

FROM mcr.microsoft.com/playwright:v1.40.0-jammy

# Install Node.js LTS
RUN apt-get update && \
    apt-get install -y curl && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r scraper && \
    useradd -r -g scraper -G audio,video scraper && \
    mkdir -p /home/scraper/Downloads && \
    chown -R scraper:scraper /home/scraper

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && \
    npx playwright install chromium && \
    npm cache clean --force

# Copy application code
COPY scraper.js ./

# Health check for scraper service
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Switch to non-root user
USER scraper

# Run scraper in watch mode (if needed) or as a service
CMD ["node", "scraper.js"]
