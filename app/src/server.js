const app = require('./app');

const PORT = process.env.PORT || 3000;

const server = app.listen(PORT, () => {
  console.log(`[server] listening on port ${PORT} (NODE_ENV=${process.env.NODE_ENV || 'development'})`);
});

// Docker sends SIGTERM on `docker stop`; close the listener first so in-flight
// requests finish. The 10s watchdog guards against connections that never close.
function shutdown(signal) {
  console.log(`[server] received ${signal}, shutting down gracefully`);

  server.close(() => {
    console.log('[server] all connections closed, exiting.');
    process.exit(0);
  });

  setTimeout(() => {
    console.error('[server] forcing shutdown after timeout');
    process.exit(1);
  }, 10_000);
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
