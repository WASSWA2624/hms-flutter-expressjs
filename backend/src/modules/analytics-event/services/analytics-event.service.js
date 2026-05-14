const analyticsEventRepository = require('@repositories/analytics-event/analytics-event.repository');
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
const { serializeAnalyticsEvent } = require('@lib/reports/serializers');

const SORT_FIELDS = ['occurred_at', 'created_at', 'updated_at', 'event_name', 'event_category', 'severity'];

const assertScopedRecord = async (id, user = {}) => {
  const scoped = await resolveScopedContext({}, user);
  const record = await analyticsEventRepository.findById(id);
  if (!record || record.tenant_id !== scoped.tenant_id) {
    throw new HttpError('errors.analytics_event.not_found', 404);
  }
  return record;
};

const listAnalyticsEvents = async (filters = {}, page = 1, limit = 20, sortBy, order, user = {}) => {
  const scoped = await resolveScopeIdsForList({ filters, user });
  const where = {
    tenant_id: scoped.tenant_id,
    ...buildSinceFilter(filters.since),
    ...buildDateWindowFilter({ from: filters.from, to: filters.to, field: 'occurred_at' }),
    ...buildSearchWhere(filters.search, ['event_name', 'event_category', 'entity_type', 'entity_public_id']),
  };

  if (scoped.user_id) where.user_id = scoped.user_id;
  if (normalizeString(filters.user_id) && !scoped.user_id) where.user_id = '__none__';
  if (scoped.facility_id) where.facility_id = scoped.facility_id;
  if (normalizeString(filters.facility_id) && !scoped.facility_id) where.facility_id = '__none__';
  if (scoped.branch_id) where.branch_id = scoped.branch_id;
  if (normalizeString(filters.branch_id) && !scoped.branch_id) where.branch_id = '__none__';
  if (normalizeString(filters.event_category)) where.event_category = normalizeString(filters.event_category);
  if (normalizeString(filters.entity_type)) where.entity_type = normalizeString(filters.entity_type);
  if (normalizeString(filters.severity)) where.severity = safeUpper(filters.severity);

  const skip = (page - 1) * limit;
  const orderBy = buildSort(sortBy, order, 'occurred_at', SORT_FIELDS);
  const [records, total] = await Promise.all([
    analyticsEventRepository.findMany({ where, skip, take: limit, orderBy }),
    analyticsEventRepository.count(where),
  ]);

  return {
    analyticsEvents: records.map(serializeAnalyticsEvent),
    pagination: buildPagination(page, limit, total),
  };
};

const getAnalyticsEventById = async (id, user = {}) => serializeAnalyticsEvent(await assertScopedRecord(id, user));

const createAnalyticsEvent = async (data, context = {}) => {
  const scoped = await resolveScopedContext(data, context.user || {});
  const payload = {
    tenant_id: scoped.tenant_id,
    user_id: await resolvePayloadIdentifier({
      value: data.user_id ?? context.user_id,
      model: 'user',
      field: 'user_id',
      tenant_id: scoped.tenant_id,
      nullable: true,
    }),
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
    event_name: normalizeString(data.event_name),
    event_category: normalizeString(data.event_category),
    entity_type: normalizeString(data.entity_type) || null,
    entity_public_id: normalizeString(data.entity_public_id) || null,
    severity: safeUpper(data.severity),
    payload_json: data.payload_json || null,
    occurred_at: data.occurred_at ? new Date(data.occurred_at) : new Date(),
  };

  const record = await analyticsEventRepository.create(payload);
  await createAuditLog({
    tenant_id: payload.tenant_id,
    facility_id: payload.facility_id,
    user_id: context.user_id,
    action: 'CREATE',
    entity: 'analytics_event',
    entity_id: record.id,
    diff: { after: serializeAnalyticsEvent(record) },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  return serializeAnalyticsEvent(record);
};

const updateAnalyticsEvent = async (id, data, context = {}) => {
  const current = await assertScopedRecord(id, context.user || {});
  ensureVersionMatch({
    current,
    expectedVersion: data.version,
    serializer: serializeAnalyticsEvent,
  });

  const updateData = {
    version: Number(current.version || 1) + 1,
  };
  if (data.user_id !== undefined) {
    updateData.user_id = await resolvePayloadIdentifier({
      value: data.user_id,
      model: 'user',
      field: 'user_id',
      tenant_id: current.tenant_id,
      nullable: true,
    });
  }
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
  if (data.event_name !== undefined) updateData.event_name = normalizeString(data.event_name);
  if (data.event_category !== undefined) updateData.event_category = normalizeString(data.event_category);
  if (data.entity_type !== undefined) updateData.entity_type = normalizeString(data.entity_type) || null;
  if (data.entity_public_id !== undefined) updateData.entity_public_id = normalizeString(data.entity_public_id) || null;
  if (data.severity !== undefined) updateData.severity = safeUpper(data.severity);
  if (data.payload_json !== undefined) updateData.payload_json = data.payload_json || null;
  if (data.occurred_at !== undefined) updateData.occurred_at = data.occurred_at ? new Date(data.occurred_at) : null;

  const record = await analyticsEventRepository.update(id, updateData);
  await createAuditLog({
    tenant_id: current.tenant_id,
    facility_id: record.facility_id,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'analytics_event',
    entity_id: current.id,
    diff: createAuditDiff(current, record, [
      'user_id',
      'facility_id',
      'branch_id',
      'event_name',
      'event_category',
      'entity_type',
      'entity_public_id',
      'severity',
      'occurred_at',
      'version',
    ]),
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  return serializeAnalyticsEvent(record);
};

const deleteAnalyticsEvent = async (id, context = {}) => {
  const current = await assertScopedRecord(id, context.user || {});
  await analyticsEventRepository.softDelete(id);
  await createAuditLog({
    tenant_id: current.tenant_id,
    facility_id: current.facility_id,
    user_id: context.user_id,
    action: 'DELETE',
    entity: 'analytics_event',
    entity_id: current.id,
    diff: { before: serializeAnalyticsEvent(current) },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });
};

module.exports = {
  createAnalyticsEvent,
  deleteAnalyticsEvent,
  getAnalyticsEventById,
  listAnalyticsEvents,
  updateAnalyticsEvent,
};
