'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createServer } = require('../src/app');

async function start(t, options) {
  const server = createServer(options);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => server.close());
  return `http://127.0.0.1:${server.address().port}`;
}

async function get(base, path) {
  const res = await fetch(base + path);
  return { status: res.status, body: await res.json() };
}

test('GET /health returns ok', async (t) => {
  const base = await start(t);
  const res = await get(base, '/health');
  assert.equal(res.status, 200);
  assert.equal(res.body.status, 'ok');
});

test('GET / reports environment and version', async (t) => {
  process.env.APP_ENV = 'test';
  process.env.GIT_SHA = 'abc123';
  const base = await start(t);
  const res = await get(base, '/');
  assert.equal(res.status, 200);
  assert.deepEqual(res.body, { service: 'sample-saas', environment: 'test', version: 'abc123' });
});

test('GET /db returns database info when the check succeeds', async (t) => {
  const base = await start(t, { dbCheck: async () => ({ postgres: '16.4' }) });
  const res = await get(base, '/db');
  assert.equal(res.status, 200);
  assert.deepEqual(res.body, { database: 'ok', postgres: '16.4' });
});

test('GET /db returns 503 without leaking error details', async (t) => {
  const base = await start(t, {
    dbCheck: async () => {
      throw new Error('password authentication failed');
    },
  });
  const res = await get(base, '/db');
  assert.equal(res.status, 503);
  assert.deepEqual(res.body, { error: 'dependency unavailable' });
});

test('unknown paths return 404', async (t) => {
  const base = await start(t);
  const res = await get(base, '/nope');
  assert.equal(res.status, 404);
});
