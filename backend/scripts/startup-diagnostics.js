const fs = require('fs');
const path = require('path');

const log = (...args) => {
  console.log('[startup-diagnostics]', ...args);
};

const fail = (label, error) => {
  console.error(`[startup-diagnostics] ${label} failed`);
  if (error?.message) {
    console.error(`[startup-diagnostics] message: ${error.message}`);
  }
  if (error?.code) {
    console.error(`[startup-diagnostics] code: ${error.code}`);
  }
  if (error?.stack) {
    console.error(error.stack);
  }
  process.exit(1);
};

log('cwd:', process.cwd());
log('node:', process.version);

try {
  require('module-alias/register');
  const moduleAlias = require('module-alias');
  const srcDir = path.join(process.cwd(), 'src');
  const prismaRuntimePath = path.join(process.cwd(), 'node_modules', '@prisma', 'client', 'runtime');

  moduleAlias.addAliases({
    '@app': path.join(srcDir, 'app'),
    '@lib': path.join(srcDir, 'lib'),
    '@config': path.join(srcDir, 'config'),
    '@middlewares': path.join(srcDir, 'middlewares'),
    '@logs': path.join(process.cwd(), 'logs'),
    '@websockets': path.join(srcDir, 'websockets'),
    '@modules': path.join(srcDir, 'modules'),
    '@prisma/client': path.join(srcDir, 'prisma', 'client.js'),
  });

  moduleAlias.addAlias('@prisma/client/runtime', prismaRuntimePath);

  log('module aliases registered');
} catch (error) {
  fail('module alias registration', error);
}

const checkFile = (label, targetPath) => {
  const exists = fs.existsSync(targetPath);
  log(`${label}:`, exists ? targetPath : `missing -> ${targetPath}`);
  if (!exists) {
    process.exitCode = 1;
  }
};

checkFile('server', path.join(process.cwd(), 'src', 'server.js'));
checkFile('prisma wrapper', path.join(process.cwd(), 'src', 'prisma', 'client.js'));
checkFile('generated prisma index', path.join(process.cwd(), 'node_modules', '.prisma', 'client', 'index.js'));
checkFile(
  'prisma runtime',
  path.join(process.cwd(), 'node_modules', '@prisma', 'client', 'runtime', 'client.js')
);

const steps = [
  ['env config', () => require('@config/env')],
  ['logger', () => require('@lib/logging')],
  ['prisma wrapper', () => require('@prisma/client')],
  ['startup db check', () => require('@lib/health/startupDatabaseCheck')],
  [
    'module aliases',
    () => {
      const { registerAllModuleAliases } = require('@lib/aliases');
      registerAllModuleAliases();
      return true;
    },
  ],
  ['express app factory', () => require('@app/index')],
  ['reports runtime', () => require('@lib/reports/runtime')],
];

for (const [label, loader] of steps) {
  try {
    const loaded = loader();
    log(`${label}: ok`);

    if (label === 'env config') {
      log('NODE_ENV:', loaded.NODE_ENV);
      log('HOST:', loaded.HOST);
      log('PORT:', loaded.PORT);
      log('DATABASE_URL present:', Boolean(loaded.DATABASE_URL));
    }
  } catch (error) {
    fail(label, error);
  }
}

const runDatabaseProbe = async () => {
  let prisma = null;

  try {
    prisma = require('@prisma/client');
    const { assertDatabaseConnection } = require('@lib/health/startupDatabaseCheck');
    await assertDatabaseConnection();
    log('database probe: ok');
  } catch (error) {
    fail('database probe', error);
  } finally {
    try {
      if (prisma && typeof prisma.$disconnect === 'function') {
        await prisma.$disconnect();
        log('prisma disconnect: ok');
      }
    } catch (error) {
      fail('prisma disconnect', error);
    }
  }

  process.exit(0);
};

void runDatabaseProbe();
