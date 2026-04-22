# app/frontend/Dockerfile
# Multi-stage build:
# Stage 1 — build the React app with Node.js
# Stage 2 — serve the built files with nginx
# Final image has NO Node.js, no source code, no dev dependencies
# Result: ~25MB image instead of ~1GB

# ── Stage 1: Build ──────────────────────────────────────────────────
FROM node:20.19-alpine AS builder

WORKDIR /app

# Copy package files first — Docker cache layer
# If package.json hasn't changed, npm install is skipped on rebuild
COPY package.json package-lock.json ./
# Make npm more tolerant of slow registry responses
RUN npm config set fetch-retries 5 && \
    npm config set fetch-retry-factor 10 && \
    npm config set fetch-retry-mintimeout 20000 && \
    npm config set fetch-retry-maxtimeout 3000000 && \
    npm config set fetch-timeout 600000 && \
    npm ci

# Copy source and build
COPY . .
RUN npm run build
# Output: /app/dist/

# ── Stage 2: Serve ──────────────────────────────────────────────────
FROM nginx:alpine AS production

# Copy built files from Stage 1 into nginx's serve directory
COPY --from=builder /app/dist /usr/share/nginx/html

# Replace default nginx config with our SPA config
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
