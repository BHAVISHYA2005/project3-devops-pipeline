/**
 * Unit Tests — Express API Endpoints
 * -----------------------------------
 * Uses supertest to make HTTP requests against the Express app
 * WITHOUT starting a real server (no port binding needed).
 *
 * Run:  npm test
 */

const request = require('supertest');
const app = require('../src/app');

// ---------------------------------------------------------------------------
// Health endpoint
// ---------------------------------------------------------------------------
describe('GET /health', () => {
  test('returns 200 with status OK and uptime', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('OK');
    expect(typeof res.body.uptime).toBe('number');
    expect(res.body.timestamp).toBeDefined();
  });
});

// ---------------------------------------------------------------------------
// Info endpoint
// ---------------------------------------------------------------------------
describe('GET /api/info', () => {
  test('returns app metadata with all expected fields', async () => {
    const res = await request(app).get('/api/info');
    expect(res.statusCode).toBe(200);
    expect(res.body.app).toBe('devops-pipeline-app');
    expect(typeof res.body.environment).toBe('string');
    expect(typeof res.body.version).toBe('string');
    expect(res.body.nodeVersion).toBeDefined();
  });
});

// ---------------------------------------------------------------------------
// Greet endpoint
// ---------------------------------------------------------------------------
describe('GET /api/greet', () => {
  test('returns greeting with provided name', async () => {
    const res = await request(app).get('/api/greet?name=DevOps');
    expect(res.statusCode).toBe(200);
    expect(res.body.message).toBe('Hello, DevOps!');
  });

  test('defaults to "World" when no name query param', async () => {
    const res = await request(app).get('/api/greet');
    expect(res.statusCode).toBe(200);
    expect(res.body.message).toBe('Hello, World!');
  });
});
