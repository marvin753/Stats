# ========================================
# Backend Dockerfile - Production Ready
# Quiz Stats Animation System
# ========================================

# Multi-stage build for optimized image size
FROM node:20-alpine AS base

# Install security updates and dependencies
RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
    dumb-init \
    curl \
    && rm -rf /var/cache/apk/*

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

WORKDIR /app

# ========================================
# Dependencies stage
# ========================================
FROM base AS dependencies

# Copy package files
COPY package*.json ./

# Install production dependencies only
RUN npm ci --only=production && \
    npm cache clean --force

# ========================================
# Build stage
# ========================================
FROM base AS build

COPY package*.json ./
RUN npm ci

# Copy source code
COPY . .

# Run any build steps if needed
# RUN npm run build

# ========================================
# Production stage
# ========================================
FROM base AS production

# Set environment to production
ENV NODE_ENV=production
ENV PORT=3000

# Copy production dependencies
COPY --from=dependencies --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copy application code
COPY --chown=nodejs:nodejs . .

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:${PORT}/health || exit 1

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Start application
CMD ["node", "server.js"]
