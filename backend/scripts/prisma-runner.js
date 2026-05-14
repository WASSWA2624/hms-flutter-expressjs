const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const args = process.argv.slice(2);

if (args.length === 0) {
  console.error('Usage: node scripts/prisma-runner.js <prisma args...>');
  process.exit(1);
}

if (!process.env.DOTENV_QUIET) {
  process.env.DOTENV_QUIET = 'true';
}

const projectRoot = process.cwd();
const maxOutputChars = 4000;

const tail = (value) => {
  const text = String(value || '');
  if (text.length <= maxOutputChars) return text;
  return `[truncated, showing last ${maxOutputChars} chars of ${text.length}]\n${text.slice(-maxOutputChars)}`;
};

const maskDatabaseUrl = (value) => {
  if (!value) return '<missing>';

  try {
    const parsed = new URL(value);
    const username = parsed.username ? '<set>' : '<missing>';
    const password = parsed.password ? '<set>' : '<missing>';
    return `${parsed.protocol}//${username}:${password}@${parsed.host}${parsed.pathname}`;
  } catch (error) {
    return `<invalid: ${error.message}>`;
  }
};

const printCheck = (label, value) => {
  console.log(`[prisma-runner] ${label}: ${value}`);
};

printCheck('cwd', projectRoot);
printCheck('node', process.version);
printCheck('command', `prisma ${args.join(' ')}`);
printCheck('DATABASE_URL', maskDatabaseUrl(process.env.DATABASE_URL));
printCheck('NODE_ENV', process.env.NODE_ENV || '<missing>');

const schemaPath = path.join(projectRoot, 'prisma', 'schema.prisma');
const prismaConfigPath = path.join(projectRoot, 'prisma.config.js');
printCheck('schema exists', fs.existsSync(schemaPath));
printCheck('prisma.config exists', fs.existsSync(prismaConfigPath));

try {
  const prismaConfig = require(prismaConfigPath);
  printCheck('prisma.config loaded', true);
  printCheck('prisma.config schema', prismaConfig.schema || '<missing>');
  if (prismaConfig.datasource && prismaConfig.datasource.url) {
    printCheck('prisma.config datasource', maskDatabaseUrl(prismaConfig.datasource.url));
  } else {
    printCheck('prisma.config datasource', '<missing>');
  }
} catch (error) {
  console.error('[prisma-runner] prisma.config load failed');
  console.error(error && error.stack ? error.stack : String(error));
  process.exit(1);
}

let prismaCliPath;
try {
  prismaCliPath = require.resolve('prisma/build/index.js');
  printCheck('prisma cli', prismaCliPath);
} catch (error) {
  console.error('[prisma-runner] prisma CLI resolve failed');
  console.error(error && error.stack ? error.stack : String(error));
  process.exit(1);
}

const result = spawnSync(process.execPath, [prismaCliPath, ...args], {
  cwd: projectRoot,
  env: process.env,
  encoding: 'utf8',
});

if (result.stdout) {
  console.log('[prisma-runner] stdout:');
  console.log(tail(result.stdout));
}

if (result.stderr) {
  console.error('[prisma-runner] stderr:');
  console.error(tail(result.stderr));
}

if (result.error) {
  console.error('[prisma-runner] spawn error:');
  console.error(result.error && result.error.stack ? result.error.stack : String(result.error));
  process.exit(1);
}

process.exit(result.status ?? 1);
