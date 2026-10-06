'use strict';

const { createServer } = require('./app');

const port = Number(process.env.PORT || 8080);
const server = createServer();

server.listen(port, () => {
  console.log(JSON.stringify({ level: 'info', message: `listening on ${port}`, version: process.env.GIT_SHA || 'dev' }));
});

// ECS sends SIGTERM before stopping a task; finish in-flight requests first.
for (const signal of ['SIGTERM', 'SIGINT']) {
  process.on(signal, () => {
    console.log(JSON.stringify({ level: 'info', message: `${signal} received, shutting down` }));
    server.close(() => process.exit(0));
  });
}
