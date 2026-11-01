FROM node:20-alpine3.21

WORKDIR /app

ENV NODE_ENV=production \
    PORT=3000

COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY --chown=node:node src ./src

USER node

EXPOSE 3000

# wget ships with BusyBox; curl does not exist on alpine.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

# Exec form so node receives SIGTERM directly (graceful shutdown).
CMD ["node", "src/server.js"]
