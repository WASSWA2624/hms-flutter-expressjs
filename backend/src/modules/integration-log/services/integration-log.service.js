/**
 * Integration log service
 *
 * @module modules/integration-log/services
 * @description Business logic layer for integration log operations.
 * Per module-creation.mdc: Services implement business logic and call repositories.
 * Note: This is a READ-ONLY module (no create/update/delete operations)
 */

const integrationLogRepository = require('@repositories/integration-log/integration-log.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  sanitizeIdentifier,
  resolveEntityId,
  resolveIdentifierForFilter,
} = require('@lib/billing/identifiers');
const { serializeIntegrationLog } = require('@lib/integrations/serializers');

const SORT_FIELDS = new Set(['logged_at', 'created_at', 'updated_at', 'status']);

const INTEGRATION_LOG_INCLUDE = {
  integration: {
    select: {
      id: true,
      human_friendly_id: true,
      tenant_id: true,
      name: true,
      integration_type: true,
      status: true,
      tenant: {
        select: {
          id: true,
          human_friendly_id: true,
          name: true,
        },
      },
    },
  },
};

const buildPagination = (page, limit, total) => ({
  page,
  limit,
  total,
  totalPages: limit > 0 ? Math.ceil(total / limit) : 0,
  hasNextPage: limit > 0 ? page < Math.ceil(total / limit) : false,
  hasPreviousPage: page > 1,
});

const buildEmptyListResult = (page, limit) => ({
  data: [],
  pagination: buildPagination(page, limit, 0),
});

const normalizePage = (value) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 1;
};

const normalizeLimit = (value) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 20;
};

const normalizeOrder = (value) =>
  String(value || '').trim().toLowerCase() === 'asc' ? 'asc' : 'desc';

const normalizeSortField = (value) => {
  const normalized = sanitizeIdentifier(value);
  return SORT_FIELDS.has(normalized) ? normalized : 'logged_at';
};

const resolveIntegrationLogFilters = async (filters = {}, page, limit) => {
  const where = {};

  if (filters.integration_id !== undefined) {
    const integrationId = await resolveIdentifierForFilter({
      value: filters.integration_id,
      model: 'integration',
    });
    if (integrationId === null) return buildEmptyListResult(page, limit);
    if (integrationId !== undefined) where.integration_id = integrationId;
  }

  if (filters.status) {
    where.status = filters.status;
  }

  const search = sanitizeIdentifier(filters.search);
  if (search) {
    where.OR = [
      { message: { contains: search } },
      { human_friendly_id: { contains: search.toUpperCase() } },
      { integration: { name: { contains: search } } },
    ];
  }

  return where;
};

/**
 * Get integration log by ID
 *
 * @param {string} id - Integration log ID
 * @returns {Promise<Object>} Integration log object
 * @throws {HttpError} 404 if integration log not found
 */
const getIntegrationLogById = async (id) => {
  const resolvedId = await resolveEntityId({
    model: 'integration_log',
    identifier: id,
  });
  const integrationLog = await integrationLogRepository.findById(resolvedId, INTEGRATION_LOG_INCLUDE);

  if (!integrationLog) {
    throw new HttpError('errors.integration_log.not_found', 404);
  }

  return serializeIntegrationLog(integrationLog);
};

/**
 * Get integration logs by integration ID
 *
 * @param {string} integrationId - Integration ID
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order (asc/desc)
 * @returns {Promise<Object>} Paginated integration logs
 */
const getIntegrationLogsByIntegrationId = async (
  integrationId,
  page = 1,
  limit = 20,
  sortBy = 'logged_at',
  order = 'desc'
) => {
  const numericPage = normalizePage(page);
  const numericLimit = normalizeLimit(limit);
  const resolvedIntegrationId = await resolveIdentifierForFilter({
    value: integrationId,
    model: 'integration',
  });

  if (resolvedIntegrationId === null) {
    return buildEmptyListResult(numericPage, numericLimit);
  }

  const skip = (numericPage - 1) * numericLimit;
  const orderBy = { [normalizeSortField(sortBy)]: normalizeOrder(order) };
  const where = {
    integration_id: resolvedIntegrationId || integrationId,
  };

  const [integrationLogs, total] = await Promise.all([
    integrationLogRepository.findMany(
      where,
      skip,
      numericLimit,
      orderBy,
      INTEGRATION_LOG_INCLUDE
    ),
    integrationLogRepository.count(where),
  ]);

  return {
    data: integrationLogs.map(serializeIntegrationLog),
    pagination: buildPagination(numericPage, numericLimit, total),
  };
};

/**
 * List integration logs with pagination and filters
 *
 * @param {Object} filters - Filter criteria
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order (asc/desc)
 * @returns {Promise<Object>} Paginated integration logs
 */
const listIntegrationLogs = async (
  filters = {},
  page = 1,
  limit = 20,
  sortBy = 'logged_at',
  order = 'desc'
) => {
  const numericPage = normalizePage(page);
  const numericLimit = normalizeLimit(limit);
  const resolvedFilters = await resolveIntegrationLogFilters(filters, numericPage, numericLimit);
  if (resolvedFilters?.data && resolvedFilters?.pagination) {
    return resolvedFilters;
  }

  const skip = (numericPage - 1) * numericLimit;
  const orderBy = { [normalizeSortField(sortBy)]: normalizeOrder(order) };

  const [integrationLogs, total] = await Promise.all([
    integrationLogRepository.findMany(
      resolvedFilters,
      skip,
      numericLimit,
      orderBy,
      INTEGRATION_LOG_INCLUDE
    ),
    integrationLogRepository.count(resolvedFilters),
  ]);

  return {
    data: integrationLogs.map(serializeIntegrationLog),
    pagination: buildPagination(numericPage, numericLimit, total),
  };
};

/**
 * Replay integration log
 *
 * @param {string} id - Integration log ID
 * @param {Object} data - Replay payload
 * @param {Object} context - Request context
 * @returns {Promise<Object>} Replayed integration log
 */
const replayIntegrationLog = async (id, data = {}, context = {}) => {
  const resolvedId = await resolveEntityId({
    model: 'integration_log',
    identifier: id,
  });
  const existingLog = await integrationLogRepository.findById(resolvedId, INTEGRATION_LOG_INCLUDE);

  if (!existingLog) {
    throw new HttpError('errors.integration_log.not_found', 404);
  }

  const replayedLog = await integrationLogRepository.create({
    integration_id: existingLog.integration_id,
    status: existingLog.status,
    message: `[REPLAY] ${existingLog.message || 'No message'}`,
  });
  const replayedRecord =
    (await integrationLogRepository.findById(replayedLog.id, INTEGRATION_LOG_INCLUDE)) || replayedLog;

  await createAuditLog({
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    action: 'REPLAY',
    entity: 'integration_log',
    entity_id: replayedLog.id,
    diff: {
      before: existingLog,
      after: replayedLog,
      metadata: {
        notes: data.notes || null,
      },
    },
    ip_address: context.ip_address,
  }).catch(() => {});

  return serializeIntegrationLog(replayedRecord);
};

module.exports = {
  getIntegrationLogById,
  getIntegrationLogsByIntegrationId,
  listIntegrationLogs,
  replayIntegrationLog,
};
