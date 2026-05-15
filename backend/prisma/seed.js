/**
 * Prisma seed entrypoint
 *
 * Runs schema-aware demo seeding with deterministic faker randomness.
 */

require('module-alias/register');

const path = require('path');
const { faker } = require('@faker-js/faker');
const BACKEND_ROOT = path.join(__dirname, '..');

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
} catch (error) {
  console.error('Failed to register seed aliases:', error);
  process.exit(1);
}

const { seedDemoData } = require('../scripts/seed-demo-data');
const env = require('@config/env');
const prisma = require('@prisma/client');
const { DEFAULT_SEED_RECORD_COUNT } = require('@config/constants');

const resolveSeedTargetCount = () => {
  const value = Number.parseInt(String(env.SEED_RECORD_COUNT), 10);
  if (Number.isFinite(value) && value >= 0) return value;
  return DEFAULT_SEED_RECORD_COUNT;
};

const run = async () => {
  if (env.NODE_ENV === 'production') {
    console.warn('Skipping seed: NODE_ENV=production');
    return;
  }

  const randomSeed = Number.parseInt(String(env.SEED_RANDOM_SEED), 10) || 20260217;
  faker.seed(randomSeed);

  await seedDemoData({
    targetCount: resolveSeedTargetCount(),
    randomSeed
  });
};

run()
  .catch((error) => {
    console.error('Seed failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
