'use strict';

const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');

// Secrets are cached briefly so every request does not call Secrets Manager.
const TTL_MS = 5 * 60 * 1000;
const cache = new Map();
let client;

async function getSecret(secretId) {
  if (!secretId) {
    throw new Error('DB_SECRET_ARN is not set');
  }

  const hit = cache.get(secretId);
  if (hit && hit.expires > Date.now()) {
    return hit.value;
  }

  client ??= new SecretsManagerClient({});
  const out = await client.send(new GetSecretValueCommand({ SecretId: secretId }));
  const value = JSON.parse(out.SecretString);
  cache.set(secretId, { value, expires: Date.now() + TTL_MS });
  return value;
}

function invalidateSecret(secretId) {
  cache.delete(secretId);
}

module.exports = { getSecret, invalidateSecret };
