'use strict';

const fs = require('node:fs');
const { Client } = require('pg');
const { getSecret, invalidateSecret } = require('./secrets');

const INVALID_PASSWORD = '28P01';

// RDS enforces TLS; verify the server certificate with the AWS RDS CA bundle.
function sslConfig() {
  if (process.env.DB_SSL === 'false') return false;
  const caPath = process.env.DB_CA_PATH || '/etc/ssl/rds/global-bundle.pem';
  return { ca: fs.readFileSync(caPath, 'utf8'), rejectUnauthorized: true };
}

async function query() {
  const secretId = process.env.DB_SECRET_ARN;
  const { username, password } = await getSecret(secretId);

  const client = new Client({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT || 5432),
    database: process.env.DB_NAME,
    user: username,
    password,
    ssl: sslConfig(),
    connectionTimeoutMillis: 5000,
  });

  await client.connect();
  try {
    const { rows } = await client.query('SHOW server_version');
    return { postgres: rows[0].server_version };
  } finally {
    await client.end();
  }
}

// RDS rotates the master password automatically. If the cached password has
// just been rotated, refresh it from Secrets Manager once and retry.
async function checkDatabase() {
  try {
    return await query();
  } catch (err) {
    if (err.code !== INVALID_PASSWORD) throw err;
    invalidateSecret(process.env.DB_SECRET_ARN);
    return query();
  }
}

module.exports = { checkDatabase };
