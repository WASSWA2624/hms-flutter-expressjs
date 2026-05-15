#!/usr/bin/env node
const { spawnSync } = require('child_process');
const { installTestEnv, redactDatabaseUrl } = require('./test-env');

const main = () => {
  const env = installTestEnv();
  const jestBin = require.resolve('jest/bin/jest');
  const args = process.argv.slice(2);

  console.log(`[test] backend NODE_ENV=${env.NODE_ENV}`);
  console.log(`[test] backend DATABASE_URL=${redactDatabaseUrl(env.DATABASE_URL)}`);

  const result = spawnSync(process.execPath, [jestBin, ...args], {
    stdio: 'inherit',
    env: {
      ...process.env,
      ...env,
    },
  });

  if (result.error) {
    throw result.error;
  }

  process.exit(result.status ?? 1);
};

main();
