/**
 * Server Entry Point
 * ------------------
 * Starts the Express HTTP listener.
 * Separated from app.js so that Jest/supertest can import the app
 * without binding to a port (avoids EADDRINUSE in parallel tests).
 */

const app = require('./app');

const PORT = process.env.PORT || 3000;

const server = app.listen(PORT, () => {
  console.log(`[server] listening on port ${PORT} (NODE_ENV=${process.env.NODE_ENV || 'development'})`);
});

// ---------------------------------------------------------------------------
// Graceful shutdown
// ---------------------------------------------------------------------------
// When Docker sends SIGTERM (during `docker stop`) or Kubernetes sends it
// during pod eviction, we close the HTTP server first so in-flight requests
// finish before the process exits.  Without this, connections are dropped.

function shutdown(signal) {
  console.log(`[server] received ${signal}, shutting down gracefully…`);
  server.close(() => {
    console.log('[server] all connections closed, exiting.');
    process.exit(0);
  });

  // Force-kill after 10 seconds if connections refuse to close
  setTimeout(() => {
    console.error('[server] forcing shutdown after timeout');
    process.exit(1);
  }, 10_000);
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
