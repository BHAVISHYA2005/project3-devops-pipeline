# ===========================================================================
#  Multi-stage Dockerfile — Node.js production image
# ===========================================================================
#  Stage 1 (build):  Install ALL dependencies (including devDeps).
#  Stage 2 (prod) :  Copy only production deps + source → lean final image.
#
#  Why multi-stage?
#    - The build stage may contain compilers, dev tools, test frameworks.
#    - The production stage strips all of that → smaller image, smaller
#      attack surface, fewer CVEs flagged by Trivy.
# ===========================================================================

# ---- Stage 1: Build / dependency install ----
FROM node:20-alpine AS build
#  ↑ Using `alpine` instead of `slim` — smaller base (~50 MB vs ~200 MB),
#    fewer pre-installed packages = fewer potential vulnerabilities.

WORKDIR /app

# Copy package manifests FIRST → Docker layer caching means dependencies
# are only reinstalled when package.json or lock file actually changes.
COPY package*.json ./

# `npm ci` is preferred over `npm install` in CI/Docker:
#   - Deterministic: uses lock file exactly as-is
#   - Faster: skips the dependency resolution step
#   - Fails if lock file is out of sync with package.json (catches drift)
RUN npm ci && npm cache clean --force

# ---- Stage 2: Production runtime ----
FROM node:20-alpine

# The official Node alpine image ships with a pre-built `node` user (uid 1000).
# Using it instead of creating a custom user keeps the Dockerfile simpler and
# is the recommended practice from the Node.js Docker team.
# Reference: https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md

WORKDIR /app

# Copy production dependencies from the build stage
COPY --from=build /app/node_modules ./node_modules

# Copy application source and manifests
COPY src ./src
COPY package*.json ./

# Set ownership to the built-in `node` user BEFORE switching user
RUN chown -R node:node /app

# Switch to non-root user — mitigates container-escape vulnerabilities
USER node

EXPOSE 3000

# Docker-level health check — the daemon will mark the container "unhealthy"
# and orchestrators (Compose, Swarm, ECS) can act on it automatically.
# Using `wget` because curl is not installed in alpine by default.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

ENV NODE_ENV=production
ENV PORT=3000

# Use the array form of CMD (exec form) so that node receives signals
# (SIGTERM etc.) directly — required for graceful shutdown to work.
CMD ["node", "src/server.js"]
