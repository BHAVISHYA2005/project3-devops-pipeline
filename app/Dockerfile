FROM node:20-alpine3.21

# Apply base-image OS security patches.
RUN apk upgrade --no-cache

WORKDIR /app

ENV NODE_ENV=production \
    PORT=3000

COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY --chown=node:node src ./src

# The runtime only executes `node`. Dropping npm and corepack removes the
# packages bundled inside npm that dominate vulnerability scans.
RUN rm -rf /usr/local/lib/node_modules/npm \
           /usr/local/lib/node_modules/corepack \
           /usr/local/bin/npm /usr/local/bin/npx \
           /usr/local/bin/corepack /usr/local/bin/yarn /usr/local/bin/pnpm

USER node

EXPOSE 3000

# wget ships with BusyBox; curl does not exist on alpine.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

# Exec form so node receives SIGTERM directly (graceful shutdown).
CMD ["node", "src/server.js"]
