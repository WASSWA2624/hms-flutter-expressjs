#!/usr/bin/env node
const { spawnSync } = require('child_process');
const { installTestEnv, redactDatabaseUrl } = require('./test-env');

const run = (command, args, env) => {
  const display = [command, ...args].join(' ');
  console.log(`[test-db] ${display}`);
  const result = spawnSync(command, args, {
    stdio: 'inherit',
    env: {
      ...process.env,
      ...env,
    },
    shell: process.platform === 'win32',
  });

  if (result.error) {
    throw result.error;
  }

  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
};

const main = () => {
  const env = installTestEnv();
  const npx = process.platform === 'win32' ? 'npx.cmd' : 'npx';

  console.log(`[test-db] using ${redactDatabaseUrl(env.DATABASE_URL)}`);
  run(npx, ['prisma', 'generate'], env);
  run(npx, ['prisma', 'migrate', 'deploy'], env);
  console.log('[test-db] test database is ready.');
};

main();
