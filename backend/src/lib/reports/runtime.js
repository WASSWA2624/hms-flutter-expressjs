const os = require('os');
const prisma = require('@prisma/client');
const { createStorageService } = require('@lib/storage');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { logger } = require('@lib/logging');
const { createNotification } = require('@services/notification/notification.service');
const {
  REPORT_DEFAULT_RETENTION_DAYS,
  REPORT_RUNNER_MAX_CONCURRENCY,
  REPORT_RUNNER_POLL_INTERVAL_MS,
  REPORT_SCHEDULE_FREQUENCIES,
  REPORT_SCHEDULE_LEASE_MS,
  REPORT_SCHEDULE_STATUSES,
} = require('@lib/reports/constants');
const { executeReportDataset } = require('@lib/reports/datasets');
const { generateReportFile } = require('@lib/reports/files');
const { markSpanError, recordBackgroundJob, recordWorkflowEvent } = require('@lib/telemetry/metrics');

const runnerState = {
  interval: null,
  draining: false,
  activeRuns: new Set(),
  instanceId: `${os.hostname()}:${process.pid}`,
  startPromise: null,
  disabledReason: null,
  disabledLogged: false,
};

const REPORT_RUNTIME_REQUIRED_TABLES = ['report_definition', 'report_run', 'report_schedule'];
const MISSING_SCHEMA_ARTIFACT_ERROR_CODES = new Set(['P2021', 'P2022']);

const normalizeString = (value) => String(value || '').trim();
const addMinutes = (value, minutes) => new Date(new Date(value).getTime() + minutes * 60_000);
const addDays = (value, days) => new Date(new Date(value).getTime() + days * 24 * 60 * 60_000);
const [DAILY_FREQUENCY, WEEKLY_FREQUENCY, MONTHLY_FREQUENCY] = REPORT_SCHEDULE_FREQUENCIES;
const [ACTIVE_SCHEDULE_STATUS] = REPORT_SCHEDULE_STATUSES;

const isMissingSchemaArtifactError = (error) => {
  const code = error?.code ? String(error.code).toUpperCase() : null;
  if (code && MISSING_SCHEMA_ARTIFACT_ERROR_CODES.has(code)) {
    return true;
  }

  return /does not exist in the current database|does not exist/i.test(
    String(error?.message || '')
  );
};

const resolveSchemaArtifactName = (row) => {
  if (!row || typeof row !== 'object') return null;
  if (typeof row.table_name === 'string') return row.table_name;
  if (typeof row.TABLE_NAME === 'string') return row.TABLE_NAME;

  const firstValue = Object.values(row)[0];
  return typeof firstValue === 'string' ? firstValue : null;
};

const clearRuntimeInterval = () => {
  if (!runnerState.interval) return;
  clearInterval(runnerState.interval);
  runnerState.interval = null;
};

const disableReportRuntime = (reason, details = {}) => {
  clearRuntimeInterval();
  runnerState.disabledReason = reason;
  recordBackgroundJob('report_runtime.disabled', {
    'hms.runtime.reason': reason,
  });

  if (runnerState.disabledLogged) return;
  runnerState.disabledLogged = true;

  logger.warn('Reports runtime disabled', {
    reason,
    ...details,
  });
};

const ensureReportRuntimeTablesAvailable = async () => {
  try {
    const rows = await prisma.$queryRawUnsafe(`
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = DATABASE()
        AND table_name IN ('report_definition', 'report_run', 'report_schedule')
    `);

    const availableTables = new Set(
      (Array.isArray(rows) ? rows : [])
        .map(resolveSchemaArtifactName)
        .filter(Boolean)
        .map((name) => String(name).toLowerCase())
    );

    const missingTables = REPORT_RUNTIME_REQUIRED_TABLES.filter(
      (tableName) => !availableTables.has(tableName)
    );

    if (missingTables.length > 0) {
      disableReportRuntime('missing_report_runtime_tables', {
        missing_tables: missingTables,
      });
      return false;
    }

    return true;
  } catch {
    // If the preflight check itself cannot run, preserve existing behavior and let
    // the runtime attempt its normal work path on the next tick.
    return true;
  }
};

const handleRuntimeTickError = (error, context) => {
  if (!isMissingSchemaArtifactError(error)) return;

  disableReportRuntime('missing_report_schema_artifact', {
    context,
    code: error?.code || null,
    error: String(error?.message || 'Unknown Prisma schema artifact error'),
  });
};

const getZonedParts = (date, timeZone) => {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: timeZone || 'UTC',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  });

  return formatter.formatToParts(date).reduce((acc, entry) => {
    if (entry.type !== 'literal') acc[entry.type] = Number(entry.value);
    return acc;
  }, {});
};

const getTimeZoneOffsetMs = (date, timeZone) => {
  const parts = getZonedParts(date, timeZone);
  const utcEquivalent = Date.UTC(parts.year, parts.month - 1, parts.day, parts.hour, parts.minute, parts.second);
  return utcEquivalent - date.getTime();
};

const zonedDateTimeToUtc = ({ year, month, day, hour, minute }, timeZone) => {
  const guess = new Date(Date.UTC(year, month - 1, day, hour, minute, 0));
  const offsetMs = getTimeZoneOffsetMs(guess, timeZone);
  return new Date(guess.getTime() - offsetMs);
};

const parseTimeOfDay = (value) => {
  const [hour, minute] = String(value || '08:00').split(':');
  return {
    hour: Number(hour) || 8,
    minute: Number(minute) || 0,
  };
};

const computeDailyOccurrence = (schedule, reference) => {
  const timeZone = normalizeString(schedule.timezone) || 'UTC';
  const parts = getZonedParts(reference, timeZone);
  const time = parseTimeOfDay(schedule.time_of_day);
  let candidate = zonedDateTimeToUtc(
    { year: parts.year, month: parts.month, day: parts.day, hour: time.hour, minute: time.minute },
    timeZone
  );
  if (candidate <= reference) candidate = addDays(candidate, 1);
  return candidate;
};

const computeWeeklyOccurrence = (schedule, reference) => {
  const desiredDay = Number(schedule.day_of_week ?? 1);
  let candidate = computeDailyOccurrence(schedule, reference);
  while (candidate.getUTCDay() !== desiredDay) {
    candidate = addDays(candidate, 1);
  }
  return candidate;
};

const computeMonthlyOccurrence = (schedule, reference) => {
  const timeZone = normalizeString(schedule.timezone) || 'UTC';
  const parts = getZonedParts(reference, timeZone);
  const time = parseTimeOfDay(schedule.time_of_day);
  const desiredDay = Math.max(1, Number(schedule.day_of_month || 1));

  const build = (year, month) => {
    const lastDay = new Date(Date.UTC(year, month, 0)).getUTCDate();
    const day = Math.min(desiredDay, lastDay);
    return zonedDateTimeToUtc({ year, month, day, hour: time.hour, minute: time.minute }, timeZone);
  };

  let candidate = build(parts.year, parts.month);
  if (candidate <= reference) {
    let month = parts.month + 1;
    let year = parts.year;
    if (month > 12) {
      month = 1;
      year += 1;
    }
    candidate = build(year, month);
  }
  return candidate;
};

const getNextScheduledTime = (schedule, reference = new Date()) => {
  const frequency = normalizeString(schedule.frequency).toUpperCase();
  if (frequency === WEEKLY_FREQUENCY) {
    return computeWeeklyOccurrence(schedule, reference);
  }
  if (frequency === MONTHLY_FREQUENCY) {
    return computeMonthlyOccurrence(schedule, reference);
  }
  return computeDailyOccurrence(schedule, reference);
};

const getCurrentWindow = (schedule, reference = new Date()) => {
  const start = schedule.next_run_at ? new Date(schedule.next_run_at) : getNextScheduledTime(schedule, reference);
  const end =
    normalizeString(schedule.frequency).toUpperCase() === MONTHLY_FREQUENCY
      ? getNextScheduledTime(schedule, addDays(start, 28))
      : normalizeString(schedule.frequency).toUpperCase() === WEEKLY_FREQUENCY
        ? addDays(start, 7)
        : addDays(start, 1);
  return { start, end };
};

const buildStoragePath = (tenantId, fileName, createdAt = new Date()) => {
  const year = String(createdAt.getUTCFullYear());
  const month = String(createdAt.getUTCMonth() + 1).padStart(2, '0');
  return `reports/${tenantId}/${year}/${month}/${fileName}`;
};

const resolveRunScope = (definition, run) => ({
  tenant_id: definition.tenant_id,
  facility_id: run.facility_id || definition.facility_id || null,
  facility_label: run?.facility?.name || definition?.facility?.name || null,
});

const scheduleNotification = async ({ run, title, message, priority = 'MEDIUM' }) => {
  if (!run?.tenant_id || !run?.requested_by_user_id) return;
  await createNotification(
    {
      tenant_id: run.tenant_id,
      user_id: run.requested_by_user_id,
      notification_type: 'OTHER',
      priority,
      title,
      message,
    },
    null,
    null
  ).catch(() => {});
};

const failRun = async (run, error) => {
  await prisma.report_run.update({
    where: { id: run.id },
    data: {
      status: 'FAILED',
      completed_at: new Date(),
      error_message: String(error?.message || 'Unexpected report execution error').slice(0, 10000),
    },
  }).catch(() => {});

  await createAuditLog({
    tenant_id: run.tenant_id,
    user_id: run.requested_by_user_id,
    action: 'UPDATE',
    entity: 'report_run',
    entity_id: run.id,
    diff: { after: { status: 'FAILED', error_message: String(error?.message || '') } },
  });

  await scheduleNotification({
    run,
    title: `Report run failed: ${run.report_definition?.name || run.human_friendly_id || 'report'}`,
    message: String(error?.message || 'The report run failed before completion.'),
    priority: 'HIGH',
  });

  recordBackgroundJob('report_run.failed', {
    'hms.report_run.id': run.human_friendly_id || run.id,
    'hms.report_definition.id': run.report_definition?.human_friendly_id || run.report_definition_id,
  });
  markSpanError(error, {
    'hms.background.event': 'report_run.failed',
  });
};

const processRunById = async (runId) => {
  if (!runId || runnerState.activeRuns.has(runId) || runnerState.activeRuns.size >= REPORT_RUNNER_MAX_CONCURRENCY) {
    return;
  }

  runnerState.activeRuns.add(runId);

  try {
    const claimed = await prisma.report_run.updateMany({
      where: { id: runId, status: 'QUEUED', deleted_at: null },
      data: { status: 'PROCESSING', started_at: new Date() },
    });
    if (!claimed.count) return;

    const run = await prisma.report_run.findFirst({
      where: { id: runId, deleted_at: null },
      include: {
        facility: { select: { id: true, name: true } },
        report_definition: {
          include: {
            facility: { select: { id: true, name: true } },
          },
        },
        requested_by: {
          select: {
            id: true,
            email: true,
            human_friendly_id: true,
            profile: { select: { first_name: true } },
          },
        },
        schedule: true,
      },
    });

    if (!run?.report_definition) {
      throw new HttpError('errors.report_run.not_found', 404);
    }

    recordBackgroundJob('report_run.processing', {
      'hms.report_run.id': run.human_friendly_id || run.id,
      'hms.report_definition.id': run.report_definition?.human_friendly_id || run.report_definition_id,
      'hms.report_run.trigger_type': run.trigger_type,
    });

    const result = await executeReportDataset({
      dataset_key: run.report_definition.dataset_key || run.report_definition?.definition_json?.dataset_key,
      scope: resolveRunScope(run.report_definition, run),
      definition_json: run.report_definition.definition_json || {},
      parameters: run.parameters_json || {},
    });
    const rendered = await generateReportFile({
      title: run.report_definition.name,
      subtitle: result.subtitle,
      columns: result.columns,
      rows: result.rows,
      format: run.format || run.report_definition.default_format,
    });

    const storage = createStorageService();
    const storagePath = buildStoragePath(run.tenant_id, rendered.file_name, new Date());
    const uploaded = await storage.upload(rendered.buffer, storagePath, {
      mimeType: rendered.mime_type,
      encrypt: true,
      metadata: {
        report_run_id: run.id,
        report_definition_id: run.report_definition.id,
      },
    });

    const latestRunState = await prisma.report_run.findFirst({
      where: { id: run.id },
      select: { status: true },
    });
    if (String(latestRunState?.status || '').toUpperCase() === 'CANCELLED') {
      await storage.delete(uploaded?.path || storagePath).catch(() => {});
      return;
    }

    await prisma.report_run.update({
      where: { id: run.id },
      data: {
        status: 'COMPLETED',
        completed_at: new Date(),
        output_storage_path: uploaded?.path || storagePath,
        output_file_name: rendered.file_name,
        output_mime_type: rendered.mime_type,
        output_size_bytes: rendered.size_bytes,
        error_message: null,
        expires_at: addDays(new Date(), Number(run?.schedule?.retention_days || REPORT_DEFAULT_RETENTION_DAYS)),
      },
    });

    if (run.schedule_id) {
      await prisma.report_schedule.update({
        where: { id: run.schedule_id },
        data: {
          last_run_at: new Date(),
          next_run_at: getNextScheduledTime(run.schedule || {}, addMinutes(new Date(), 1)),
        },
      }).catch(() => {});
    }

    await createAuditLog({
      tenant_id: run.tenant_id,
      user_id: run.requested_by_user_id,
      action: 'EXPORT',
      entity: 'report_run',
      entity_id: run.id,
      diff: { after: { status: 'COMPLETED', output_file_name: rendered.file_name } },
    });

    await scheduleNotification({
      run,
      title: `Report ready: ${run.report_definition.name}`,
      message: `${run.report_definition.name} completed successfully and is available for download.`,
    });

    recordBackgroundJob('report_run.completed', {
      'hms.report_run.id': run.human_friendly_id || run.id,
      'hms.report_definition.id': run.report_definition?.human_friendly_id || run.report_definition_id,
      'hms.report_run.format': run.format,
    });
    recordWorkflowEvent('report_run.completed', {
      'hms.report_run.id': run.human_friendly_id || run.id,
    });
  } catch (error) {
    const run = await prisma.report_run.findFirst({
      where: { id: runId },
      include: { report_definition: true },
    });
    if (run) {
      await failRun(run, error);
    }
  } finally {
    runnerState.activeRuns.delete(runId);
  }
};

const drainQueuedRuns = async () => {
  if (runnerState.draining) return;
  runnerState.draining = true;

  try {
    while (runnerState.activeRuns.size < REPORT_RUNNER_MAX_CONCURRENCY) {
      const queuedRun = await prisma.report_run.findFirst({
        where: { deleted_at: null, status: 'QUEUED' },
        orderBy: [{ queued_at: 'asc' }, { created_at: 'asc' }],
        select: { id: true },
      });
      if (!queuedRun?.id) break;
      await processRunById(queuedRun.id);
    }
  } finally {
    runnerState.draining = false;
  }
};

const enqueueReportRun = async ({
  report_definition_id,
  facility_id = null,
  schedule_id = null,
  requested_by_user_id = null,
  trigger_type = 'MANUAL',
  format = 'PDF',
  parameters_json = {},
  retention_days = REPORT_DEFAULT_RETENTION_DAYS,
}) => {
  const definition = await prisma.report_definition.findFirst({
    where: { id: report_definition_id, deleted_at: null },
  });
  if (!definition) {
    throw new HttpError('errors.report_definition.not_found', 404);
  }

  const run = await prisma.report_run.create({
    data: {
      tenant_id: definition.tenant_id,
      facility_id: facility_id || definition.facility_id || null,
      report_definition_id: definition.id,
      schedule_id,
      requested_by_user_id,
      trigger_type,
      format: normalizeString(format || definition.default_format || 'PDF').toUpperCase(),
      parameters_json: parameters_json || {},
      status: 'QUEUED',
      queued_at: new Date(),
      expires_at: addDays(new Date(), Number(retention_days || REPORT_DEFAULT_RETENTION_DAYS)),
    },
  });

  setImmediate(() => {
    drainQueuedRuns().catch(() => {});
  });

  await createAuditLog({
    tenant_id: definition.tenant_id,
    user_id: requested_by_user_id,
    action: 'CREATE',
    entity: 'report_run',
    entity_id: run.id,
    diff: { after: { trigger_type, format: run.format, schedule_id } },
  });

  recordBackgroundJob('report_run.queued', {
    'hms.report_run.id': run.human_friendly_id || run.id,
    'hms.report_definition.id': definition.human_friendly_id || definition.id,
    'hms.report_run.trigger_type': trigger_type,
    'hms.report_run.format': run.format,
  });

  return run;
};

const acquireScheduleLease = async (scheduleId) => {
  const expiredAt = addMinutes(new Date(), -(REPORT_SCHEDULE_LEASE_MS / 60_000));
  const result = await prisma.report_schedule.updateMany({
    where: {
      id: scheduleId,
      deleted_at: null,
      OR: [{ locked_at: null }, { locked_at: { lt: expiredAt } }],
    },
    data: {
      locked_at: new Date(),
      locked_by: runnerState.instanceId,
    },
  });
  return result.count > 0;
};

const releaseScheduleLease = async (scheduleId) => {
  await prisma.report_schedule.update({
    where: { id: scheduleId },
    data: { locked_at: null, locked_by: null },
  }).catch(() => {});
};

const processDueSchedules = async () => {
  const dueSchedules = await prisma.report_schedule.findMany({
    where: {
      deleted_at: null,
      status: ACTIVE_SCHEDULE_STATUS,
      next_run_at: { lte: new Date() },
    },
    orderBy: { next_run_at: 'asc' },
  });

  for (const schedule of dueSchedules) {
    const leased = await acquireScheduleLease(schedule.id);
    if (!leased) continue;

    try {
      const window = getCurrentWindow(schedule, new Date());
      const existingRun = await prisma.report_run.findFirst({
        where: {
          deleted_at: null,
          schedule_id: schedule.id,
          trigger_type: 'SCHEDULED',
          queued_at: { gte: window.start, lt: window.end },
        },
        select: { id: true },
      });

      if (!existingRun) {
        await enqueueReportRun({
          report_definition_id: schedule.report_definition_id,
          facility_id: schedule.facility_id,
          schedule_id: schedule.id,
          requested_by_user_id: schedule.created_by,
          trigger_type: 'SCHEDULED',
          format: schedule.format,
          parameters_json: schedule.parameter_overrides_json || {},
          retention_days: schedule.retention_days,
        });
        recordWorkflowEvent('report_schedule.enqueued', {
          'hms.report_schedule.id': schedule.human_friendly_id || schedule.id,
          'hms.report_definition.id': schedule.report_definition_id,
        });
      }

      await prisma.report_schedule.update({
        where: { id: schedule.id },
        data: {
          next_run_at: getNextScheduledTime(schedule, addMinutes(new Date(), 1)),
          locked_at: null,
          locked_by: null,
        },
      });
    } catch (error) {
      await releaseScheduleLease(schedule.id);
    }
  }
};

const cleanupExpiredOutputs = async () => {
  const expiredRuns = await prisma.report_run.findMany({
    where: {
      deleted_at: null,
      output_storage_path: { not: null },
      expires_at: { lte: new Date() },
    },
    select: {
      id: true,
      output_storage_path: true,
    },
    take: 50,
  });
  if (!expiredRuns.length) return;

  const storage = createStorageService();
  for (const run of expiredRuns) {
    await storage.delete(run.output_storage_path).catch(() => {});
    await prisma.report_run.update({
      where: { id: run.id },
      data: {
        output_storage_path: null,
        output_file_name: null,
        output_mime_type: null,
        output_size_bytes: null,
      },
    }).catch(() => {});
  }
};

const tickRunner = async () => {
  await processDueSchedules();
  await cleanupExpiredOutputs();
  await drainQueuedRuns();
};

const startReportRunScheduler = () => {
  if (runnerState.interval || runnerState.startPromise) return runnerState.startPromise;
  if (runnerState.disabledReason) return Promise.resolve(false);

  runnerState.startPromise = (async () => {
    const ready = await ensureReportRuntimeTablesAvailable();
    if (!ready) {
      return false;
    }

    runnerState.interval = setInterval(() => {
      tickRunner().catch((error) => {
        handleRuntimeTickError(error, 'interval');
      });
    }, REPORT_RUNNER_POLL_INTERVAL_MS);
    if (typeof runnerState.interval.unref === 'function') {
      runnerState.interval.unref();
    }
    setImmediate(() => {
      tickRunner().catch((error) => {
        handleRuntimeTickError(error, 'startup');
      });
    });

    return true;
  })();

  return runnerState.startPromise.finally(() => {
    runnerState.startPromise = null;
  });
};

const stopReportRunScheduler = () => {
  clearRuntimeInterval();
};

const cancelQueuedRun = async (runId) => {
  const updated = await prisma.report_run.updateMany({
    where: {
      id: runId,
      deleted_at: null,
      status: { in: ['QUEUED', 'PROCESSING'] },
    },
    data: {
      status: 'CANCELLED',
      completed_at: new Date(),
    },
  });
  return updated.count > 0;
};

module.exports = {
  cancelQueuedRun,
  enqueueReportRun,
  getNextScheduledTime,
  processRunById,
  startReportRunScheduler,
  stopReportRunScheduler,
};
