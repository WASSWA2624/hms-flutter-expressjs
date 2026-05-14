const reportRunRepository = require('@repositories/report-run/report-run.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { createStorageService } = require('@lib/storage');
const { cancelQueuedRun, enqueueReportRun } = require('@lib/reports/runtime');
const {
  buildDateWindowFilter,
  buildPagination,
  buildSinceFilter,
  buildSort,
  createAuditDiff,
  ensureVersionMatch,
  normalizeString,
  resolvePayloadIdentifier,
  resolveScopeIdsForList,
  resolveScopedContext,
  safeUpper,
} = require('@lib/reports/api');
const {
  REPORT_DEFAULT_RETENTION_DAYS,
  REPORT_FORMATS,
  REPORT_RUN_STATUSES,
} = require('@lib/reports/constants');
const { serializeReportRun } = require('@lib/reports/serializers');

const SORT_FIELDS = ['queued_at', 'created_at', 'updated_at', 'completed_at', 'status', 'format'];

const buildListWhere = async (filters = {}, user = {}) => {
  const scoped = await resolveScopeIdsForList({ filters, user });
  const where = {
    tenant_id: scoped.tenant_id,
    ...buildSinceFilter(filters.since),
    ...buildDateWindowFilter({ from: filters.from, to: filters.to, field: 'queued_at' }),
  };

  if (scoped.facility_id) where.facility_id = scoped.facility_id;
  if (normalizeString(filters.facility_id) && !scoped.facility_id) where.facility_id = '__none__';
  if (scoped.report_definition_id) where.report_definition_id = scoped.report_definition_id;
  if (normalizeString(filters.report_definition_id) && !scoped.report_definition_id) where.report_definition_id = '__none__';
  if (scoped.schedule_id) where.schedule_id = scoped.schedule_id;
  if (normalizeString(filters.schedule_id) && !scoped.schedule_id) where.schedule_id = '__none__';
  if (scoped.owner_id) where.requested_by_user_id = scoped.owner_id;
  if (normalizeString(filters.owner_id) && !scoped.owner_id) where.requested_by_user_id = '__none__';
  if (normalizeString(filters.status)) where.status = safeUpper(filters.status);
  if (normalizeString(filters.format)) where.format = safeUpper(filters.format);
  if (normalizeString(filters.trigger_type)) where.trigger_type = safeUpper(filters.trigger_type);

  return where;
};

const assertScopedRun = async (id, user = {}) => {
  const scoped = await resolveScopedContext({}, user);
  const record = await reportRunRepository.findById(id);
  if (!record || record.tenant_id !== scoped.tenant_id) {
    throw new HttpError('errors.report_run.not_found', 404);
  }
  if (scoped.facility_id && record.facility_id && scoped.facility_id !== record.facility_id) {
    throw new HttpError('errors.report_run.not_found', 404);
  }
  return record;
};

const listReportRuns = async (filters = {}, page = 1, limit = 20, sortBy, order, user = {}) => {
  const where = await buildListWhere(filters, user);
  const skip = (page - 1) * limit;
  const orderBy = buildSort(sortBy, order, 'queued_at', SORT_FIELDS);

  const [records, total] = await Promise.all([
    reportRunRepository.findMany({ where, skip, take: limit, orderBy }),
    reportRunRepository.count(where),
  ]);

  return {
    reportRuns: records.map(serializeReportRun),
    pagination: buildPagination(page, limit, total),
  };
};

const getReportRunById = async (id, user = {}) => serializeReportRun(await assertScopedRun(id, user));

const createReportRun = async (data, context = {}) => {
  const scoped = await resolveScopedContext(data, context.user || {});
  const reportDefinitionId = await resolvePayloadIdentifier({
    value: data.report_definition_id,
    model: 'report_definition',
    field: 'report_definition_id',
    tenant_id: scoped.tenant_id,
  });

  const run = await enqueueReportRun({
    report_definition_id: reportDefinitionId,
    facility_id: await resolvePayloadIdentifier({
      value: data.facility_id ?? scoped.facility_id,
      model: 'facility',
      field: 'facility_id',
      tenant_id: scoped.tenant_id,
      nullable: true,
    }),
    requested_by_user_id: context.user_id || null,
    trigger_type: 'MANUAL',
    format: safeUpper(data.format) || REPORT_FORMATS[0],
    parameters_json: data.parameters_json || {},
    retention_days: data.retention_days || REPORT_DEFAULT_RETENTION_DAYS,
  });

  return serializeReportRun(run);
};

const updateReportRun = async (id, data, context = {}) => {
  const current = await assertScopedRun(id, context.user || {});
  ensureVersionMatch({
    current,
    expectedVersion: data.version,
    serializer: serializeReportRun,
  });

  const updateData = {
    version: Number(current.version || 1) + 1,
  };
  if (data.status !== undefined) updateData.status = safeUpper(data.status);
  if (data.error_message !== undefined) updateData.error_message = normalizeString(data.error_message) || null;
  if (data.completed_at !== undefined) updateData.completed_at = data.completed_at ? new Date(data.completed_at) : null;
  if (data.expires_at !== undefined) updateData.expires_at = data.expires_at ? new Date(data.expires_at) : null;
  if (data.output_file_name !== undefined) updateData.output_file_name = normalizeString(data.output_file_name) || null;

  const record = await reportRunRepository.update(id, updateData);
  await createAuditLog({
    tenant_id: current.tenant_id,
    facility_id: current.facility_id,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'report_run',
    entity_id: current.id,
    diff: createAuditDiff(current, record, [
      'status',
      'error_message',
      'completed_at',
      'expires_at',
      'output_file_name',
      'version',
    ]),
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  return serializeReportRun(record);
};

const deleteReportRun = async (id, context = {}) => {
  const current = await assertScopedRun(id, context.user || {});
  await reportRunRepository.softDelete(id);
  await createAuditLog({
    tenant_id: current.tenant_id,
    facility_id: current.facility_id,
    user_id: context.user_id,
    action: 'DELETE',
    entity: 'report_run',
    entity_id: current.id,
    diff: { before: serializeReportRun(current) },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });
};

const retryReportRun = async (id, payload = {}, context = {}) => {
  const current = await assertScopedRun(id, context.user || {});
  if (!['FAILED', 'CANCELLED', 'COMPLETED'].includes(String(current.status || '').toUpperCase())) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'status' }]);
  }

  const run = await enqueueReportRun({
    report_definition_id: current.report_definition_id,
    facility_id: current.facility_id,
    requested_by_user_id: context.user_id || current.requested_by_user_id || null,
    trigger_type: 'RETRY',
    format: safeUpper(payload.format) || current.format || current.report_definition?.default_format || REPORT_FORMATS[0],
    parameters_json: current.parameters_json || {},
    retention_days:
      payload.retention_days ||
      current.schedule?.retention_days ||
      REPORT_DEFAULT_RETENTION_DAYS,
  });

  await createAuditLog({
    tenant_id: current.tenant_id,
    facility_id: current.facility_id,
    user_id: context.user_id,
    action: 'CREATE',
    entity: 'report_run',
    entity_id: run.id,
    diff: {
      before: { source_report_run_id: current.id },
      after: serializeReportRun(run),
    },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  return serializeReportRun(run);
};

const cancelReportRunById = async (id, context = {}) => {
  const current = await assertScopedRun(id, context.user || {});
  const cancelled = await cancelQueuedRun(current.id);
  if (!cancelled) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'status' }]);
  }
  const next = await reportRunRepository.findById(current.id);

  await createAuditLog({
    tenant_id: current.tenant_id,
    facility_id: current.facility_id,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'report_run',
    entity_id: current.id,
    diff: createAuditDiff(current, next, ['status', 'completed_at']),
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  return serializeReportRun(next);
};

const downloadReportRun = async (id, context = {}) => {
  const run = await assertScopedRun(id, context.user || {});
  if (String(run.status || '').toUpperCase() !== REPORT_RUN_STATUSES[2] || !run.output_storage_path) {
    throw new HttpError('errors.report_run.not_found', 404);
  }

  const storage = createStorageService();
  const buffer = await storage.download(run.output_storage_path);

  await createAuditLog({
    tenant_id: run.tenant_id,
    facility_id: run.facility_id,
    user_id: context.user_id,
    action: 'EXPORT',
    entity: 'report_run',
    entity_id: run.id,
    diff: { after: { output_file_name: run.output_file_name, status: run.status } },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  return {
    buffer,
    file_name: run.output_file_name || `${serializeReportRun(run).human_friendly_id || 'report-run'}.bin`,
    mime_type: run.output_mime_type || 'application/octet-stream',
  };
};

module.exports = {
  cancelReportRunById,
  createReportRun,
  deleteReportRun,
  downloadReportRun,
  getReportRunById,
  listReportRuns,
  retryReportRun,
  updateReportRun,
};
