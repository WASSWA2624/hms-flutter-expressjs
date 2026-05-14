const reportDefinitionRepository = require('@repositories/report-definition/report-definition.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { enqueueReportRun } = require('@lib/reports/runtime');
const {
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
const {
  REPORT_DATASET_MAP,
  REPORT_DEFINITION_STATUSES,
  REPORT_FORMATS,
} = require('@lib/reports/constants');
const { serializeReportDefinition, serializeReportRun } = require('@lib/reports/serializers');

const SORT_FIELDS = ['created_at', 'updated_at', 'name', 'status', 'dataset_key'];

const ensureDatasetDefinition = (datasetKey, definitionJson = {}) => {
  const dataset = REPORT_DATASET_MAP[datasetKey];
  if (!dataset) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'dataset_key' }]);
  }

  return {
    dataset_key: dataset.key,
    columns: Array.isArray(definitionJson.columns) ? definitionJson.columns : dataset.default_columns,
    default_filters: definitionJson.default_filters || [],
    group_by: Array.isArray(definitionJson.group_by) ? definitionJson.group_by : [],
    sort: Array.isArray(definitionJson.sort) ? definitionJson.sort : [],
    visualization: definitionJson.visualization || dataset.visualization,
  };
};

const buildListWhere = async (filters = {}, user = {}) => {
  const scoped = await resolveScopeIdsForList({ filters, user });
  const where = {
    tenant_id: scoped.tenant_id,
    ...buildSinceFilter(filters.since),
    ...buildSearchWhere(filters.search, ['name', 'description', 'dataset_key', 'category']),
  };

  if (scoped.facility_id) where.facility_id = scoped.facility_id;
  if (normalizeString(filters.facility_id) && !scoped.facility_id) where.facility_id = '__none__';

  const ownerId = scoped.owner_id || (filters.created_by ? scoped.owner_id : null);
  if (ownerId) where.created_by = ownerId;
  if ((filters.owner_id || filters.created_by) && !ownerId) where.created_by = '__none__';

  if (normalizeString(filters.dataset_key)) where.dataset_key = normalizeString(filters.dataset_key);
  if (normalizeString(filters.category)) where.category = normalizeString(filters.category);
  if (normalizeString(filters.status)) where.status = safeUpper(filters.status);

  return where;
};

const listReportDefinitions = async (filters = {}, page = 1, limit = 20, sortBy, order, user = {}) => {
  const where = await buildListWhere(filters, user);
  const skip = (page - 1) * limit;
  const orderBy = buildSort(sortBy, order, 'updated_at', SORT_FIELDS);

  const [records, total] = await Promise.all([
    reportDefinitionRepository.findMany({ where, skip, take: limit, orderBy }),
    reportDefinitionRepository.count(where),
  ]);

  return {
    reportDefinitions: records.map(serializeReportDefinition),
    pagination: buildPagination(page, limit, total),
  };
};

const getReportDefinitionById = async (id, user = {}) => {
  const scoped = await resolveScopedContext({}, user);
  const record = await reportDefinitionRepository.findById(id);
  if (!record || record.tenant_id !== scoped.tenant_id) {
    throw new HttpError('errors.report_definition.not_found', 404);
  }
  if (scoped.facility_id && record.facility_id && scoped.facility_id !== record.facility_id) {
    throw new HttpError('errors.report_definition.not_found', 404);
  }
  return serializeReportDefinition(record);
};

const createReportDefinition = async (data, context = {}) => {
  const scoped = await resolveScopedContext(data, context.user || {});
  const datasetKey = normalizeString(data.dataset_key);
  const definitionJson = ensureDatasetDefinition(datasetKey, {
    ...(data.definition_json || {}),
    dataset_key: datasetKey,
  });
  const dataset = REPORT_DATASET_MAP[datasetKey];

  const payload = {
    tenant_id: scoped.tenant_id,
    facility_id: await resolvePayloadIdentifier({
      value: data.facility_id ?? scoped.facility_id,
      model: 'facility',
      field: 'facility_id',
      tenant_id: scoped.tenant_id,
      nullable: true,
    }),
    created_by: context.user_id || null,
    name: normalizeString(data.name),
    description: normalizeString(data.description) || null,
    dataset_key: datasetKey,
    category: normalizeString(data.category) || dataset.category,
    status: safeUpper(data.status) || REPORT_DEFINITION_STATUSES[0],
    default_format: safeUpper(data.default_format) || REPORT_FORMATS[0],
    definition_json: definitionJson,
    parameter_schema_json: data.parameter_schema_json || null,
  };

  const record = await reportDefinitionRepository.create(payload);
  await createAuditLog({
    tenant_id: payload.tenant_id,
    facility_id: payload.facility_id,
    user_id: context.user_id,
    action: 'CREATE',
    entity: 'report_definition',
    entity_id: record.id,
    diff: { after: serializeReportDefinition(record) },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  return serializeReportDefinition(record);
};

const updateReportDefinition = async (id, data, context = {}) => {
  const scoped = await resolveScopedContext(data, context.user || {});
  const current = await reportDefinitionRepository.findById(id);
  if (!current || current.tenant_id !== scoped.tenant_id) {
    throw new HttpError('errors.report_definition.not_found', 404);
  }

  ensureVersionMatch({
    current,
    expectedVersion: data.version,
    serializer: serializeReportDefinition,
  });

  const nextDatasetKey = normalizeString(data.dataset_key) || current.dataset_key;
  const dataset = REPORT_DATASET_MAP[nextDatasetKey];
  const updateData = {};

  if (data.facility_id !== undefined) {
    updateData.facility_id = await resolvePayloadIdentifier({
      value: data.facility_id,
      model: 'facility',
      field: 'facility_id',
      tenant_id: scoped.tenant_id,
      nullable: true,
    });
  }
  if (data.name !== undefined) updateData.name = normalizeString(data.name);
  if (data.description !== undefined) updateData.description = normalizeString(data.description) || null;
  if (data.dataset_key !== undefined) updateData.dataset_key = nextDatasetKey;
  if (data.category !== undefined) updateData.category = normalizeString(data.category) || dataset?.category || current.category;
  if (data.status !== undefined) updateData.status = safeUpper(data.status);
  if (data.default_format !== undefined) updateData.default_format = safeUpper(data.default_format);
  if (data.parameter_schema_json !== undefined) updateData.parameter_schema_json = data.parameter_schema_json || null;
  if (data.definition_json !== undefined || data.dataset_key !== undefined) {
    updateData.definition_json = ensureDatasetDefinition(nextDatasetKey, {
      ...(current.definition_json || {}),
      ...(data.definition_json || {}),
      dataset_key: nextDatasetKey,
    });
  }
  updateData.version = Number(current.version || 1) + 1;

  const record = await reportDefinitionRepository.update(id, updateData);
  await createAuditLog({
    tenant_id: current.tenant_id,
    facility_id: record.facility_id,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'report_definition',
    entity_id: current.id,
    diff: createAuditDiff(current, record, [
      'name',
      'description',
      'dataset_key',
      'category',
      'status',
      'default_format',
      'facility_id',
      'version',
    ]),
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  return serializeReportDefinition(record);
};

const deleteReportDefinition = async (id, context = {}) => {
  const scoped = await resolveScopedContext({}, context.user || {});
  const current = await reportDefinitionRepository.findById(id);
  if (!current || current.tenant_id !== scoped.tenant_id) {
    throw new HttpError('errors.report_definition.not_found', 404);
  }

  await reportDefinitionRepository.softDelete(id);
  await createAuditLog({
    tenant_id: current.tenant_id,
    facility_id: current.facility_id,
    user_id: context.user_id,
    action: 'DELETE',
    entity: 'report_definition',
    entity_id: current.id,
    diff: { before: serializeReportDefinition(current) },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });
};

const runReportDefinitionNow = async (id, payload = {}, context = {}) => {
  const scoped = await resolveScopedContext(payload, context.user || {});
  const definition = await reportDefinitionRepository.findById(id);
  if (!definition || definition.tenant_id !== scoped.tenant_id) {
    throw new HttpError('errors.report_definition.not_found', 404);
  }

  const run = await enqueueReportRun({
    report_definition_id: definition.id,
    facility_id: await resolvePayloadIdentifier({
      value: payload.facility_id ?? definition.facility_id ?? scoped.facility_id,
      model: 'facility',
      field: 'facility_id',
      tenant_id: scoped.tenant_id,
      nullable: true,
    }),
    requested_by_user_id: context.user_id || null,
    trigger_type: 'MANUAL',
    format: safeUpper(payload.format) || definition.default_format || REPORT_FORMATS[0],
    parameters_json: payload.parameters_json || {},
    retention_days: payload.retention_days,
  });

  await createAuditLog({
    tenant_id: definition.tenant_id,
    facility_id: definition.facility_id,
    user_id: context.user_id,
    action: 'CREATE',
    entity: 'report_run',
    entity_id: run.id,
    diff: { after: serializeReportRun(run) },
    ip_address: context.ip_address,
    user_agent: context.user_agent,
  });

  return serializeReportRun(run);
};

module.exports = {
  createReportDefinition,
  deleteReportDefinition,
  getReportDefinitionById,
  listReportDefinitions,
  runReportDefinitionNow,
  updateReportDefinition,
};
