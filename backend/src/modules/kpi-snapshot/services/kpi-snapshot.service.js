const kpiSnapshotRepository = require('@repositories/kpi-snapshot/kpi-snapshot.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  buildDateWindowFilter,
  buildPagination,
  buildSearchWhere,
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
const { serializeKpiSnapshot } = require('@lib/reports/serializers');

const SORT_FIELDS = ['recorded_at', 'created_at', 'updated_at', 'name', 'metric_key', 'threshold_state'];

const assertScopedRecord = async (id, user = {}) => {
  const scoped = await resolveScopedContext({}, user);
  const record = await kpiSnapshotRepository.findById(id);
  if (!record || record.tenant_id !== scoped.tenant_id) {
    throw new HttpError('errors.kpi_snapshot.not_found', 404);
  }
  return record;
};

const listKpiSnapshots = async (filters = {}, page = 1, limit = 20, sortBy, order, user = {}) => {
  const scoped = await resolveScopeIdsForList({ filters, user });
  const where = {
    tenant_id: scoped.tenant_id,
    ...buildSinceFilter(filters.since),
    ...buildDateWindowFilter({ from: filters.from, to: filters.to, field: 'recorded_at' }),
    ...buildSearchWhere(filters.search, ['name', 'metric_key', 'metric_group']),
  };

  if (scoped.facility_id) where.facility_id = scoped.facility_id;
  if (normalizeString(filters.facility_id) && !scoped.facility_id) where.facility_id = '__none__';
  if (scoped.branch_id) where.branch_id = scoped.branch_id;
  if (normalizeString(filters.branch_id) && !scoped.branch_id) where.branch_id = '__none__';
  if (normalizeString(filters.metric_key)) where.metric_key = normalizeString(filters.metric_key);
  if (normalizeString(filters.metric_group)) where.metric_group = normalizeString(filters.metric_group);
  if (normalizeString(filters.threshold_state)) where.threshold_state = safeUpper(filters.threshold_state);

  const skip = (page - 1) * limit;
  const orderBy = buildSort(sortBy, order, 'recorded_at', SORT_FIELDS);
  const [records, total] = await Promise.all([
    kpiSnapshotRepository.findMany({ where, skip, take: limit, orderBy }),
    kpiSnapshotRepository.count(where),
  ]);

  return {
    kpiSnapshots: records.map(serializeKpiSnapshot),
    pagination: buildPagination(page, limit, total),
  };
};

const getKpiSnapshotById = async (id, user = {}) => serializeKpiSnapshot(await assertScopedRecord(id, user));

const createKpiSnapshot = async (data, context = {}) => {
  const scoped = await resolveScopedContext(data, context.user || {});
  const payload = {
    tenant_id: scoped.tenant_id,
    facility_id: await resolvePayloadIdentifier({
      value: data.facility_id ?? scoped.facility_id,
      model: 'facility',
      field: 'facility_id',
      tenant_id: scoped.tenant_id,
      nullable: true,
    }),
    branch_id: await resolvePayloadIdentifier({
      value: data.branch_id ?? scoped.branch_id,
      model: 'branch',
      field: 'branch_id',
      tenant_id: scoped.tenant_id,
      nullable: true,
    }),
    name: normalizeString(data.name),
    metric_key: normalizeString(data.metric_key),
    metric_group: normalizeString(data.metric_group),
    value: String(data.value),
    threshold_state: safeUpper(data.threshold_state),
    recorded_at: data.recorded_at ? new Date(data.recorded_at) : new Date(),
  };

  const record = await kpiSnapshotRepository.create(payload);
  await createAuditLog({
    tenant_id: payload.tenant_id,
    facility_id: payload.facility_id,
    user_id: context.user_id,
    action: 'CREATE',
    entity: 'kpi_snapshot',
    entity_id: record.id,
    diff: { after: serializeKpiSnapshot(record) },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  return serializeKpiSnapshot(record);
};

const updateKpiSnapshot = async (id, data, context = {}) => {
  const current = await assertScopedRecord(id, context.user || {});
  ensureVersionMatch({
    current,
    expectedVersion: data.version,
    serializer: serializeKpiSnapshot,
  });

  const updateData = {
    version: Number(current.version || 1) + 1,
  };
  if (data.facility_id !== undefined) {
    updateData.facility_id = await resolvePayloadIdentifier({
      value: data.facility_id,
      model: 'facility',
      field: 'facility_id',
      tenant_id: current.tenant_id,
      nullable: true,
    });
  }
  if (data.branch_id !== undefined) {
    updateData.branch_id = await resolvePayloadIdentifier({
      value: data.branch_id,
      model: 'branch',
      field: 'branch_id',
      tenant_id: current.tenant_id,
      nullable: true,
    });
  }
  if (data.name !== undefined) updateData.name = normalizeString(data.name);
  if (data.metric_key !== undefined) updateData.metric_key = normalizeString(data.metric_key);
  if (data.metric_group !== undefined) updateData.metric_group = normalizeString(data.metric_group);
  if (data.value !== undefined) updateData.value = String(data.value);
  if (data.threshold_state !== undefined) updateData.threshold_state = safeUpper(data.threshold_state);
  if (data.recorded_at !== undefined) updateData.recorded_at = data.recorded_at ? new Date(data.recorded_at) : null;

  const record = await kpiSnapshotRepository.update(id, updateData);
  await createAuditLog({
    tenant_id: current.tenant_id,
    facility_id: record.facility_id,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'kpi_snapshot',
    entity_id: current.id,
    diff: createAuditDiff(current, record, [
      'facility_id',
      'branch_id',
      'name',
      'metric_key',
      'metric_group',
      'value',
      'threshold_state',
      'recorded_at',
      'version',
    ]),
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  return serializeKpiSnapshot(record);
};

const deleteKpiSnapshot = async (id, context = {}) => {
  const current = await assertScopedRecord(id, context.user || {});
  await kpiSnapshotRepository.softDelete(id);
  await createAuditLog({
    tenant_id: current.tenant_id,
    facility_id: current.facility_id,
    user_id: context.user_id,
    action: 'DELETE',
    entity: 'kpi_snapshot',
    entity_id: current.id,
    diff: { before: serializeKpiSnapshot(current) },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });
};

module.exports = {
  createKpiSnapshot,
  deleteKpiSnapshot,
  getKpiSnapshotById,
  listKpiSnapshots,
  updateKpiSnapshot,
};
