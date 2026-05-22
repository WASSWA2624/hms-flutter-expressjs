#!/usr/bin/env node
/**
 * Close duplicate active OPD/emergency encounters and backfill active locks.
 *
 * Usage:
 *   node scripts/clean-duplicate-encounters.js --dry-run
 *   node scripts/clean-duplicate-encounters.js --yes
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

try {
  const { registerAllModuleAliases } = require('@lib/aliases');
  registerAllModuleAliases();
} catch (error) {
  console.warn('Failed to register module-scoped aliases:', error.message);
}

const prisma = require('@prisma/client');
const { assertDemoTaskAllowed } = require('./demo-safety');

const ACTIVE_OPD_TYPES = ['OPD', 'EMERGENCY'];
const FACILITY_FALLBACK = 'GLOBAL';

const args = new Set(process.argv.slice(2));
const dryRun = args.has('--dry-run') || !args.has('--yes');

const lockKeyFor = (encounter) => {
  if (!encounter?.tenant_id || !encounter?.patient_id) {
    return null;
  }
  return [
    'opd',
    encounter.tenant_id,
    encounter.facility_id || FACILITY_FALLBACK,
    encounter.patient_id
  ].join(':');
};

const groupKeyFor = (encounter) =>
  [
    encounter.tenant_id,
    encounter.facility_id || FACILITY_FALLBACK,
    encounter.patient_id
  ].join('|');

const getFlow = (encounter) => encounter?.extension_json?.opd_flow || null;

const cleanupDuplicateEncounters = async () => {
  const safety = assertDemoTaskAllowed('duplicate encounter cleanup');
  if (!safety.allowed) {
    return {
      skipped: true,
      reason: safety.reason,
      duplicateEncountersClosed: 0,
      lockKeysBackfilled: 0,
      visitQueuesCompleted: 0
    };
  }

  const encounters = await prisma.encounter.findMany({
    where: {
      deleted_at: null,
      status: 'OPEN',
      encounter_type: { in: ACTIVE_OPD_TYPES }
    },
    orderBy: [
      { tenant_id: 'asc' },
      { facility_id: 'asc' },
      { patient_id: 'asc' },
      { started_at: 'asc' },
      { created_at: 'asc' },
      { id: 'asc' }
    ],
    select: {
      id: true,
      human_friendly_id: true,
      tenant_id: true,
      facility_id: true,
      patient_id: true,
      encounter_type: true,
      started_at: true,
      created_at: true,
      active_opd_lock_key: true,
      extension_json: true
    }
  });

  const groups = new Map();
  for (const encounter of encounters) {
    const groupKey = groupKeyFor(encounter);
    const group = groups.get(groupKey) || [];
    group.push(encounter);
    groups.set(groupKey, group);
  }

  const duplicateEncounters = [];
  const lockUpdates = [];
  for (const group of groups.values()) {
    const [keeper, ...duplicates] = group;
    duplicateEncounters.push(...duplicates);

    const expectedLockKey = lockKeyFor(keeper);
    if (keeper.active_opd_lock_key !== expectedLockKey) {
      lockUpdates.push({ id: keeper.id, active_opd_lock_key: expectedLockKey });
    }
  }

  const visitQueueIds = [
    ...new Set(
      duplicateEncounters
        .map((encounter) => getFlow(encounter)?.visit_queue_id)
        .filter(Boolean)
    )
  ];

  if (!dryRun) {
    const closedAt = new Date();
    await prisma.$transaction(async (tx) => {
      for (const encounter of duplicateEncounters) {
        await tx.encounter.update({
          where: { id: encounter.id },
          data: {
            status: 'CLOSED',
            ended_at: closedAt,
            active_opd_lock_key: null
          }
        });
      }

      if (visitQueueIds.length > 0) {
        await tx.visit_queue.updateMany({
          where: {
            id: { in: visitQueueIds },
            deleted_at: null
          },
          data: { status: 'COMPLETED' }
        });
      }

      for (const update of lockUpdates) {
        await tx.encounter.update({
          where: { id: update.id },
          data: { active_opd_lock_key: update.active_opd_lock_key }
        });
      }
    });
  }

  return {
    dryRun,
    duplicateEncountersClosed: duplicateEncounters.length,
    lockKeysBackfilled: lockUpdates.length,
    visitQueuesCompleted: visitQueueIds.length,
    duplicateEncounterIds: duplicateEncounters.map(
      (encounter) => encounter.human_friendly_id || encounter.id
    )
  };
};

cleanupDuplicateEncounters()
  .then((result) => {
    console.log(JSON.stringify(result, null, 2));
  })
  .catch((error) => {
    console.error(`Duplicate encounter cleanup failed: ${error.message}`);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect().catch(() => {});
  });
