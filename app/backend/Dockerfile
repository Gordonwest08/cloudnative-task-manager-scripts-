# app/backend/Dockerfile
# Multi-stage build:
# Stage 1 — install ALL dependencies including devDependencies
# Stage 2 — copy only production dependencies, no devDependencies

# ── Stage 1: Install ────────────────────────────────────────────────
FROM node:20.19-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json ./
# Make npm more tolerant of slow registry responses
RUN npm config set fetch-retries 5 && \
    npm config set fetch-retry-factor 10 && \
    npm config set fetch-retry-mintimeout 20000 && \
    npm config set fetch-retry-maxtimeout 3000000 && \
    npm config set fetch-timeout 600000 && \
    npm ci
# ── Stage 2: Production ─────────────────────────────────────────────
FROM node:20.19-alpine AS production

WORKDIR /app

# Create non-root user — never run containers as root in production
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy package files and install ONLY production dependencies
COPY package.json package-lock.json ./
RUN npm config set fetch-retries 5 && \
    npm config set fetch-retry-factor 10 && \
    npm config set fetch-retry-mintimeout 20000 && \
    npm config set fetch-retry-maxtimeout 3000000 && \
    npm config set fetch-timeout 600000 && \
    npm ci --omit=dev

# Copy application source code
COPY src/ ./src/

# Switch to non-root user
USER appuser

EXPOSE 5000

# Use node directly — not npm start — so signals (SIGTERM) are
# received by the node process, not npm, enabling graceful shutdown
CMD ["node", "src/index.js"]
