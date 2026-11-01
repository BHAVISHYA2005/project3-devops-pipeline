const express = require('express');

// Exported separately from server.js so tests can import it without a listener.
const app = express();

app.get('/health', (_req, res) => {
  res.status(200).json({
    status: 'OK',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
  });
});

app.get('/api/info', (_req, res) => {
  res.status(200).json({
    app: 'devops-pipeline-app',
    version: process.env.APP_VERSION || '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    nodeVersion: process.version,
  });
});

app.get('/api/greet', (req, res) => {
  const name = req.query.name || 'World';
  res.status(200).json({ message: `Hello, ${name}!` });
});

// JSON 404 so API clients never get Express's HTML default page.
const notFound = (_req, res) => {
  res.status(404).json({ error: 'Not found' });
};

// The four-argument signature is what marks this as an error handler.
const errorHandler = (err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
};

app.use(notFound);
app.use(errorHandler);

// Exported so the tests can exercise the handlers directly.
module.exports = app;
module.exports.notFound = notFound;
module.exports.errorHandler = errorHandler;
