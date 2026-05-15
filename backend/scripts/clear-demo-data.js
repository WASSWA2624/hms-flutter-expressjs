/**
 * Clear Demo Data Script
 *
 * Deletes all application data from the current database while keeping
 * Prisma migration metadata intact.
 *
 * Usage:
 *   node scripts/clear-demo-data.js --yes
 *   node scripts/clear-demo-data.js --dry-run
 *
 * @module scripts/clear-demo-data
 */

// Must be absolute first - register module aliases before any other requires
require('module-alias/register');
const path = require('path');
const BACKEND_ROOT = path.join(__dirname, '..');

// Register global aliases for runtime resolution
try {
  const moduleAlias = require('module-alias');
  const prismaRuntimePath = path.join(BACKEND_ROOT, 'node_modules', '@prisma', 'client', 'runtime');

  moduleAlias.addAliases({
    '@app': path.join(BACKEND_ROOT, 'src', 'app'),
    '@lib': path.join(BACKEND_ROOT, 'src', 'lib'),
    '@config': path.join(BACKEND_ROOT, 'src', 'config'),
    '@middlewares': path.join(BACKEND_ROOT, 'src', 'middlewares'),
    '@logs': path.join(BACKEND_ROOT, 'logs'),
    '@websockets': path.join(BACKEND_ROOT, 'src', 'websockets'),
    '@modules': path.join(BACKEND_ROOT, 'src', 'modules'),
    '@prisma/client': path.join(BACKEND_ROOT, 'src', 'prisma', 'client.js')
  });

  moduleAlias.addAlias('@prisma/client/runtime', prismaRuntimePath);
} catch (err) {
  console.error('Failed to register module aliases:', err);
  process.exit(1);
}

// Register module-scoped aliases
try {
  const { registerAllModuleAliases } = require('@lib/aliases');
  registerAllModuleAliases();
} catch (err) {
  console.warn('Failed to register module aliases (may not be critical):', err.message);
}

const prisma = require('@prisma/client');
const { assertDemoTaskAllowed } = require('./demo-safety');

const PROTECTED_TABLES = new Set(['_prisma_migrations']);

const normalizeTableName = (row) =>
  row?.TABLE_NAME || row?.table_name || row?.tableName || row?.Table_name || null;

const clearDemoData = async ({ dryRun = false, confirm = false } = {}) => {
  const safety = assertDemoTaskAllowed('demo data clear');
  if (!safety.allowed) {
    console.warn('Skipping demo data clear: NODE_ENV=production');
    return { skipped: true, reason: safety.reason };
  }

  if (!dryRun && confirm !== true) {
    throw new Error('Refusing to clear demo data without explicit confirmation. Use --yes or pass { confirm: true }.');
  }

  const rows = await prisma.$queryRaw`
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = DATABASE()
      AND table_type = 'BASE TABLE'
  `;

  const allTables = rows
    .map(normalizeTableName)
    .filter(Boolean);

  const targetTables = allTables
    .filter((tableName) => !PROTECTED_TABLES.has(tableName))
    .sort((a, b) => a.localeCompare(b));

  if (targetTables.length === 0) {
    console.log('No application tables found to clear.');
    return { skipped: false, dryRun, tables: [] };
  }

  if (dryRun) {
    console.log('Dry run mode: the following tables would be cleared:');
    targetTables.forEach((tableName) => {
      console.log(`  - ${tableName}`);
    });
    return { skipped: false, dryRun: true, tables: targetTables };
  }

  console.log(`Clearing ${targetTables.length} table(s)...`);

  await prisma.$transaction(async (tx) => {
    await tx.$executeRawUnsafe('SET FOREIGN_KEY_CHECKS = 0');
    try {
      for (const tableName of targetTables) {
        const safeTableName = tableName.replace(/`/g, '');
        await tx.$executeRawUnsafe(`DELETE FROM \`${safeTableName}\``);
        console.log(`  - cleared ${safeTableName}`);
      }
    } finally {
      await tx.$executeRawUnsafe('SET FOREIGN_KEY_CHECKS = 1');
    }
  });

  console.log('Database data cleared successfully.');
  return { skipped: false, dryRun: false, tables: targetTables };
};

const main = async () => {
  const dryRun = process.argv.includes('--dry-run');
  const confirm = process.argv.includes('--yes') || process.argv.includes('--force');

  try {
    await clearDemoData({ dryRun, confirm });
  } catch (error) {
    console.error('Failed to clear database data:', error);
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect();
  }
};

if (require.main === module) {
  main();
}

module.exports = { clearDemoData };
