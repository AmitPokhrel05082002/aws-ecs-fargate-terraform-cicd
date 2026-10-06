'use strict';

const http = require('node:http');
const { checkDatabase } = require('./db');

function json(res, status, body) {
  res.writeHead(status, { 'content-type': 'application/json' });
  res.end(JSON.stringify(body));
}

/**
 * Small HTTP service used to prove the platform works end to end.
 *   GET /health -> load balancer health check (no dependencies)
 *   GET /       -> which environment and git commit is running
 *   GET /db     -> connects to RDS using credentials from Secrets Manager
 */
function createServer({ dbCheck = checkDatabase } = {}) {
  return http.createServer(async (req, res) => {
    const { pathname } = new URL(req.url, 'http://localhost');

    if (req.method !== 'GET') {
      return json(res, 405, { error: 'method not allowed' });
    }

    try {
      switch (pathname) {
        case '/health':
          return json(res, 200, { status: 'ok' });
        case '/':
          return json(res, 200, {
            service: 'sample-saas',
            environment: process.env.APP_ENV || 'local',
            version: process.env.GIT_SHA || 'dev',
          });
        case '/db':
          return json(res, 200, { database: 'ok', ...(await dbCheck()) });
        default:
          return json(res, 404, { error: 'not found' });
      }
    } catch (err) {
      console.error(JSON.stringify({ level: 'error', path: pathname, message: err.message }));
      return json(res, 503, { error: 'dependency unavailable' });
    }
  });
}

module.exports = { createServer };
