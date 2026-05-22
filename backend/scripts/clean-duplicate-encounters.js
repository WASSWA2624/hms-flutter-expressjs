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
const TERMINAL_OPD_STAGES = new Set(['ADMITTED', 'DISCHARGED']);
const CLOSED_WORK_STATUSES = ['COMPLETED', 'CANCELLED', 'NO_SHOW'];
const NON_REOPENABLE_WORK_STATUSES = ['CANCELLED', 'NO_SHOW'];

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

const normalizeUpper = (value) =>
  String(value || '')
    .trim()
    .toUpperCase();

const isTerminalFlow = (encounter) => {
  const flow = getFlow(encounter);
  return (
    encounter.status !== 'OPEN' ||
    TERMINAL_OPD_STAGES.has(normalizeUpper(flow?.stage))
  );
};

const sortedIds = (ids) => [...ids].filter(Boolean).sort();

const rowsNeedingStatus = async ({
  model,
  ids,
  status,
  excludedStatuses = []
}) => {
  const idList = sortedIds(ids);
  if (idList.length === 0) {
    return [];
  }

  return prisma[model].findMany({
    where: {
      id: { in: idList },
      deleted_at: null,
      status:
        excludedStatuses.length > 0
          ? { notIn: [...new Set([status, ...excludedStatuses])] }
          : { not: status }
    },
    select: {
      id: true,
      human_friendly_id: true,
      status: true
    }
  });
};

const cleanupDuplicateEncounters = async () => {
  const safety = assertDemoTaskAllowed('duplicate encounter cleanup');
  if (!safety.allowed) {
    return {
      skipped: true,
      reason: safety.reason,
      duplicateEncountersClosed: 0,
      lockKeysBackfilled: 0,
      visitQueuesCompleted: 0,
      visitQueuesMarkedInProgress: 0,
      appointmentsCompleted: 0,
      appointmentsMarkedInProgress: 0
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

  const flowEncounters = await prisma.encounter.findMany({
    where: {
      deleted_at: null,
      encounter_type: { in: ACTIVE_OPD_TYPES }
    },
    select: {
      id: true,
      status: true,
      extension_json: true
    }
  });

  const duplicateEncounterIds = new Set(
    duplicateEncounters.map((encounter) => encounter.id)
  );
  const visitQueueIdsToComplete = new Set();
  const visitQueueIdsToMarkInProgress = new Set();
  const appointmentIdsToComplete = new Set();
  const appointmentIdsToMarkInProgress = new Set();

  for (const encounter of flowEncounters) {
    const flow = getFlow(encounter);
    if (!flow) {
      continue;
    }

    const shouldCompleteWork =
      duplicateEncounterIds.has(encounter.id) || isTerminalFlow(encounter);

    if (flow.visit_queue_id) {
      if (shouldCompleteWork) {
        visitQueueIdsToComplete.add(flow.visit_queue_id);
      } else {
        visitQueueIdsToMarkInProgress.add(flow.visit_queue_id);
      }
    }

    if (flow.appointment_id) {
      if (shouldCompleteWork) {
        appointmentIdsToComplete.add(flow.appointment_id);
      } else {
        appointmentIdsToMarkInProgress.add(flow.appointment_id);
      }
    }
  }

  for (const id of visitQueueIdsToMarkInProgress) {
    visitQueueIdsToComplete.delete(id);
  }
  for (const id of appointmentIdsToMarkInProgress) {
    appointmentIdsToComplete.delete(id);
  }

  const [
    visitQueuesToComplete,
    visitQueuesToMarkInProgress,
    appointmentsToComplete,
    appointmentsToMarkInProgress
  ] = await Promise.all([
    rowsNeedingStatus({
      model: 'visit_queue',
      ids: visitQueueIdsToComplete,
      status: 'COMPLETED',
      excludedStatuses: CLOSED_WORK_STATUSES
    }),
    rowsNeedingStatus({
      model: 'visit_queue',
      ids: visitQueueIdsToMarkInProgress,
      status: 'IN_PROGRESS',
      excludedStatuses: NON_REOPENABLE_WORK_STATUSES
    }),
    rowsNeedingStatus({
      model: 'appointment',
      ids: appointmentIdsToComplete,
      status: 'COMPLETED',
      excludedStatuses: CLOSED_WORK_STATUSES
    }),
    rowsNeedingStatus({
      model: 'appointment',
      ids: appointmentIdsToMarkInProgress,
      status: 'IN_PROGRESS',
      excludedStatuses: NON_REOPENABLE_WORK_STATUSES
    })
  ]);

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

      if (visitQueuesToComplete.length > 0) {
        await tx.visit_queue.updateMany({
          where: {
            id: {
              in: visitQueuesToComplete.map((entry) => entry.id)
            },
            deleted_at: null
          },
          data: { status: 'COMPLETED' }
        });
      }

      if (visitQueuesToMarkInProgress.length > 0) {
        await tx.visit_queue.updateMany({
          where: {
            id: {
              in: visitQueuesToMarkInProgress.map((entry) => entry.id)
            },
            deleted_at: null
          },
          data: { status: 'IN_PROGRESS' }
        });
      }

      if (appointmentsToComplete.length > 0) {
        await tx.appointment.updateMany({
          where: {
            id: {
              in: appointmentsToComplete.map((entry) => entry.id)
            },
            deleted_at: null
          },
          data: { status: 'COMPLETED' }
        });
      }

      if (appointmentsToMarkInProgress.length > 0) {
        await tx.appointment.updateMany({
          where: {
            id: {
              in: appointmentsToMarkInProgress.map((entry) => entry.id)
            },
            deleted_at: null
          },
          data: { status: 'IN_PROGRESS' }
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
    visitQueuesCompleted: visitQueuesToComplete.length,
    visitQueuesMarkedInProgress: visitQueuesToMarkInProgress.length,
    appointmentsCompleted: appointmentsToComplete.length,
    appointmentsMarkedInProgress: appointmentsToMarkInProgress.length,
    duplicateEncounterIds: duplicateEncounters.map(
      (encounter) => encounter.human_friendly_id || encounter.id
    ),
    completedVisitQueueIds: visitQueuesToComplete.map(
      (entry) => entry.human_friendly_id || entry.id
    ),
    inProgressVisitQueueIds: visitQueuesToMarkInProgress.map(
      (entry) => entry.human_friendly_id || entry.id
    ),
    completedAppointmentIds: appointmentsToComplete.map(
      (entry) => entry.human_friendly_id || entry.id
    ),
    inProgressAppointmentIds: appointmentsToMarkInProgress.map(
      (entry) => entry.human_friendly_id || entry.id
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
