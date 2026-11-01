const request = require('supertest');
const app = require('../src/app');

describe('GET /health', () => {
  test('returns 200 with status OK and uptime', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('OK');
    expect(typeof res.body.uptime).toBe('number');
    expect(res.body.timestamp).toBeDefined();
  });
});

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

describe('unknown routes', () => {
  test('returns a JSON 404 instead of HTML', async () => {
    const res = await request(app).get('/does-not-exist');
    expect(res.statusCode).toBe(404);
    expect(res.body).toEqual({ error: 'Not found' });
  });
});

describe('error handler', () => {
  test('returns a JSON 500 and logs the error', () => {
    const spy = jest.spyOn(console, 'error').mockImplementation(() => {});
    const res = { status: jest.fn().mockReturnThis(), json: jest.fn() };

    app.errorHandler(new Error('boom'), {}, res, () => {});

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({ error: 'Internal server error' });
    expect(spy).toHaveBeenCalled();

    spy.mockRestore();
  });
});
