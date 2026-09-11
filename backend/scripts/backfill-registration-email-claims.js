#!/usr/bin/env node
/**
 * Backfill registration email claims before the unique index goes live.
 *
 * `registration_attempt.claimed_email` is unique, and from the migration onward
 * it is written inside the transaction that bootstraps a self-serve tenant. Any
 * workspace created before that has no claim row, so without this backfill an
 * old email could bootstrap a second tenant once, and support has no record of
 * which workspace owns an address.
 *
 * The script walks existing self-serve owners (recorded in
 * `registration_follow_up`), keeps the earliest registration per email as the
 * claim holder, and reports every later duplicate so an operator can merge or
 * retire it. It never deletes, merges, or rewrites an account.
 *
 * Safe to re-run: an email that already has a claim is skipped.
 *
 * Usage:
 *   node scripts/backfill-registration-email-claims.js --dry-run
 *   node scripts/backfill-registration-email-claims.js --yes
 */

require('module-alias/register');
const path = require('path');

const BACKEND_ROOT = path.join(__dirname, '..');

try {
  const moduleAlias = require('module-alias');
  const prismaRuntimePath = path.join(
    BACKEND_ROOT,
    'node_modules',
    '@prisma',
    'client',
    'runtime'
  );

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
  console.error('Failed to register module aliases:', error);
  process.exit(1);
}

const prisma = require('@prisma/client');

const args = new Set(process.argv.slice(2));
const DRY_RUN = args.has('--dry-run') || !args.has('--yes');

const BACKFILL_KEY_PREFIX = 'backfill:';
const CLAIM_TTL_MS = 365 * 24 * 60 * 60 * 1000;

const normalizeEmail = (value) => String(value || '').trim().toLowerCase();

const main = async () => {
  const followUps = await prisma.registration_follow_up.findMany({
    where: { deleted_at: null },
    orderBy: [{ first_registered_at: 'asc' }, { created_at: 'asc' }],
    select: {
      id: true,
      user_id: true,
      tenant_id: true,
      facility_id: true,
      email: true,
      account_status: true,
      first_registered_at: true,
    },
  });

  const existingClaims = await prisma.registration_attempt.findMany({
    where: { claimed_email: { not: null } },
    select: { claimed_email: true },
  });
  const claimed = new Set(existingClaims.map((row) => normalizeEmail(row.claimed_email)));

  const seen = new Set();
  const duplicates = [];
  const toCreate = [];

  for (const row of followUps) {
    const email = normalizeEmail(row.email);
    if (!email) {
      continue;
    }

    if (seen.has(email) || claimed.has(email)) {
      duplicates.push({
        email,
        user_id: row.user_id,
        tenant_id: row.tenant_id,
        first_registered_at: row.first_registered_at,
      });
      continue;
    }

    seen.add(email);

    toCreate.push({
      idempotency_key: `${BACKFILL_KEY_PREFIX}${row.user_id}`,
      email,
      claimed_email: email,
      status: 'SUCCEEDED',
      outcome_code: 'ACCOUNT_CREATED_EMAIL_SENT',
      email_status: 'SENT',
      user_id: row.user_id,
      tenant_id: row.tenant_id,
      facility_id: row.facility_id,
      started_at: row.first_registered_at || new Date(),
      completed_at: row.first_registered_at || new Date(),
      expires_at: new Date(Date.now() + CLAIM_TTL_MS),
    });
  }

  console.log(`[backfill] self-serve registrations scanned: ${followUps.length}`);
  console.log(`[backfill] emails already claimed: ${claimed.size}`);
  console.log(`[backfill] claims to create: ${toCreate.length}`);
  console.log(`[backfill] duplicate registration emails found: ${duplicates.length}`);

  duplicates.forEach((entry) => {
    console.warn(
      `[backfill] duplicate email ${entry.email} -> user ${entry.user_id} ` +
        `(tenant ${entry.tenant_id}); the earliest registration keeps the claim`
    );
  });

  if (DRY_RUN) {
    console.log('[backfill] dry run: no rows written. Re-run with --yes to apply.');
    return;
  }

  let created = 0;
  for (const data of toCreate) {
    try {
      await prisma.registration_attempt.create({ data });
      created += 1;
    } catch (error) {
      if (error?.code === 'P2002') {
        // Another run (or a live registration) already claimed this email.
        continue;
      }
      throw error;
    }
  }

  console.log(`[backfill] claims created: ${created}`);
};

main()
  .catch((error) => {
    console.error(`[backfill] failed: ${error.message}`);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect().catch(() => {});
  });
