/**
 * Express Application Setup
 * -------------------------
 * Defines all API routes for the devops-pipeline-app.
 * The app is exported separately from the server so that
 * tests (supertest) can import it without starting a listener.
 */

const express = require('express');
const app = express();

// ---------------------------------------------------------------------------
// Middleware
// ---------------------------------------------------------------------------

// Parse incoming JSON request bodies (e.g. POST /api payloads)
app.use(express.json());

// ---------------------------------------------------------------------------
// Routes
// ---------------------------------------------------------------------------

/**
 * GET /health
 * Lightweight health-check endpoint consumed by:
 *   - Docker HEALTHCHECK (container-level liveness)
 *   - CodeDeploy ValidateService hook (deployment verification)
 *   - CI/CD post-deploy smoke test (cd.yml)
 *
 * Returns 200 with uptime and a timestamp so operators can
 * quickly eyeball whether the process restarted recently.
 */
app.get('/health', (_req, res) => {
  res.status(200).json({
    status: 'OK',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
  });
});

/**
 * GET /api/info
 * Returns build-time and runtime metadata.
 * APP_VERSION is injected via Docker build args or CI environment.
 */
app.get('/api/info', (_req, res) => {
  res.status(200).json({
    app: 'devops-pipeline-app',
    version: process.env.APP_VERSION || '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    nodeVersion: process.version,
  });
});

/**
 * GET /api/greet?name=DevOps
 * Simple greeting endpoint — defaults to "World" when no name is provided.
 */
app.get('/api/greet', (req, res) => {
  const name = req.query.name || 'World';
  res.status(200).json({ message: `Hello, ${name}!` });
});

module.exports = app;
