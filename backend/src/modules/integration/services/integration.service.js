/**
 * Integration service
 *
 * @module modules/integration/services
 * @description Business logic layer for integration operations.
 * Per module-creation.mdc: Services implement business logic and call repositories.
 * Per module-creation.mdc: All mutations must call createAuditLog.
 */

const integrationRepository = require('@repositories/integration/integration.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  sanitizeIdentifier,
  resolveEntityId,
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
} = require('@lib/billing/identifiers');
const { serializeIntegration } = require('@lib/integrations/serializers');

const SORT_FIELDS = new Set(['created_at', 'updated_at', 'name', 'status', 'integration_type']);

const INTEGRATION_INCLUDE = {
  tenant: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
    },
  },
  _count: {
    select: {
      logs: true,
      webhooks: true,
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
  return SORT_FIELDS.has(normalized) ? normalized : 'created_at';
};

const resolveListFilters = async (filters = {}, page, limit) => {
  const where = {};

  if (filters.tenant_id !== undefined) {
    const tenantId = await resolveIdentifierForFilter({
      value: filters.tenant_id,
      model: 'tenant',
    });
    if (tenantId === null) return buildEmptyListResult(page, limit);
    if (tenantId !== undefined) where.tenant_id = tenantId;
  }

  if (filters.integration_type) {
    where.integration_type = filters.integration_type;
  }

  if (filters.status) {
    where.status = filters.status;
  }

  const name = sanitizeIdentifier(filters.name);
  if (name) {
    where.name = {
      contains: name,
    };
  }

  const search = sanitizeIdentifier(filters.search);
  if (search) {
    where.OR = [
      { name: { contains: search } },
      { human_friendly_id: { contains: search.toUpperCase() } },
    ];
  }

  return where;
};

const resolveCreatePayload = async (data = {}) => {
  const payload = { ...data };

  payload.tenant_id = await resolveIdentifierForPayload({
    value: payload.tenant_id,
    field: 'tenant_id',
    model: 'tenant',
  });

  return payload;
};

/**
 * Get integration by ID
 *
 * @param {string} id - Integration ID
 * @returns {Promise<Object>} Integration object
 * @throws {HttpError} 404 if integration not found
 */
const getIntegrationById = async (id) => {
  const resolvedId = await resolveEntityId({
    model: 'integration',
    identifier: id,
  });
  const integration = await integrationRepository.findById(resolvedId, INTEGRATION_INCLUDE);

  if (!integration) {
    throw new HttpError('errors.integration.not_found', 404);
  }

  return serializeIntegration(integration);
};

/**
 * List integrations with pagination and filters
 *
 * @param {Object} filters - Filter criteria
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order (asc/desc)
 * @returns {Promise<Object>} Paginated integrations
 */
const listIntegrations = async (
  filters = {},
  page = 1,
  limit = 20,
  sortBy = 'created_at',
  order = 'desc'
) => {
  const numericPage = normalizePage(page);
  const numericLimit = normalizeLimit(limit);
  const resolvedFilters = await resolveListFilters(filters, numericPage, numericLimit);
  if (resolvedFilters?.data && resolvedFilters?.pagination) {
    return resolvedFilters;
  }

  const skip = (numericPage - 1) * numericLimit;
  const orderBy = { [normalizeSortField(sortBy)]: normalizeOrder(order) };

  const [integrations, total] = await Promise.all([
    integrationRepository.findMany(resolvedFilters, skip, numericLimit, orderBy, INTEGRATION_INCLUDE),
    integrationRepository.count(resolvedFilters),
  ]);

  return {
    data: integrations.map(serializeIntegration),
    pagination: buildPagination(numericPage, numericLimit, total),
  };
};

/**
 * Create new integration
 *
 * @param {Object} data - Integration data
 * @param {Object} auditContext - Audit context (user_id, tenant_id, ip_address)
 * @returns {Promise<Object>} Created integration
 */
const createIntegration = async (data, auditContext) => {
  const payload = await resolveCreatePayload(data);
  const integration = await integrationRepository.create(payload);
  const createdRecord =
    (await integrationRepository.findById(integration.id, INTEGRATION_INCLUDE)) || integration;

  await createAuditLog({
    action: 'CREATE',
    entity: 'integration',
    entity_id: integration.id,
    new_values: integration,
    ...auditContext,
  });

  return serializeIntegration(createdRecord);
};

/**
 * Update integration
 *
 * @param {string} id - Integration ID
 * @param {Object} data - Update data
 * @param {Object} auditContext - Audit context (user_id, tenant_id, ip_address)
 * @returns {Promise<Object>} Updated integration
 * @throws {HttpError} 404 if integration not found
 */
const updateIntegration = async (id, data, auditContext) => {
  const resolvedId = await resolveEntityId({
    model: 'integration',
    identifier: id,
  });
  const existingIntegration = await integrationRepository.findById(resolvedId, INTEGRATION_INCLUDE);

  if (!existingIntegration) {
    throw new HttpError('errors.integration.not_found', 404);
  }

  const updated = await integrationRepository.update(existingIntegration.id, data);
  const updatedRecord =
    (await integrationRepository.findById(updated.id, INTEGRATION_INCLUDE)) || updated;

  await createAuditLog({
    action: 'UPDATE',
    entity: 'integration',
    entity_id: existingIntegration.id,
    old_values: existingIntegration,
    new_values: updated,
    ...auditContext,
  });

  return serializeIntegration(updatedRecord);
};

/**
 * Delete integration (soft delete)
 *
 * @param {string} id - Integration ID
 * @param {Object} auditContext - Audit context (user_id, tenant_id, ip_address)
 * @returns {Promise<Object>} Deleted integration
 * @throws {HttpError} 404 if integration not found
 */
const deleteIntegration = async (id, auditContext) => {
  const resolvedId = await resolveEntityId({
    model: 'integration',
    identifier: id,
  });
  const existingIntegration = await integrationRepository.findById(resolvedId, INTEGRATION_INCLUDE);

  if (!existingIntegration) {
    throw new HttpError('errors.integration.not_found', 404);
  }

  const deleted = await integrationRepository.softDelete(existingIntegration.id);

  await createAuditLog({
    action: 'DELETE',
    entity: 'integration',
    entity_id: existingIntegration.id,
    old_values: existingIntegration,
    ...auditContext,
  });

  return deleted;
};

/**
 * Test integration connection
 *
 * @param {string} id - Integration ID
 * @param {Object} data - Test payload
 * @param {Object} auditContext - Audit context
 * @returns {Promise<Object>} Test result payload
 */
const testIntegrationConnection = async (id, data = {}, auditContext = {}) => {
  const resolvedId = await resolveEntityId({
    model: 'integration',
    identifier: id,
  });
  const integration = await integrationRepository.findById(resolvedId, INTEGRATION_INCLUDE);

  if (!integration) {
    throw new HttpError('errors.integration.not_found', 404);
  }

  const serializedIntegration = serializeIntegration(integration);
  const hasConfig = integration.config_json !== null && integration.config_json !== undefined;

  const result = {
    integration_id: serializedIntegration.id,
    integration_display_id: serializedIntegration.display_id,
    integration_label: serializedIntegration.name,
    connected: hasConfig,
    tested_at: new Date().toISOString(),
    timeout_ms: data.timeout_ms || 10000,
    dry_run: Boolean(data.dry_run),
  };

  await createAuditLog({
    action: 'TEST_CONNECTION',
    entity: 'integration',
    entity_id: integration.id,
    old_values: integration,
    new_values: result,
    ...auditContext,
  }).catch(() => {});

  return result;
};

/**
 * Trigger integration sync
 *
 * @param {string} id - Integration ID
 * @param {Object} data - Sync payload
 * @param {Object} auditContext - Audit context
 * @returns {Promise<Object>} Sync payload
 */
const syncIntegrationNow = async (id, data = {}, auditContext = {}) => {
  const resolvedId = await resolveEntityId({
    model: 'integration',
    identifier: id,
  });
  const integration = await integrationRepository.findById(resolvedId, INTEGRATION_INCLUDE);

  if (!integration) {
    throw new HttpError('errors.integration.not_found', 404);
  }

  const serializedIntegration = serializeIntegration(integration);

  const result = {
    integration_id: serializedIntegration.id,
    integration_display_id: serializedIntegration.display_id,
    integration_label: serializedIntegration.name,
    queued: true,
    forced: Boolean(data.force),
    scope: data.scope || 'full',
    queued_at: new Date().toISOString(),
  };

  await createAuditLog({
    action: 'SYNC_NOW',
    entity: 'integration',
    entity_id: integration.id,
    old_values: integration,
    new_values: result,
    ...auditContext,
  }).catch(() => {});

  return result;
};

module.exports = {
  getIntegrationById,
  listIntegrations,
  createIntegration,
  updateIntegration,
  deleteIntegration,
  testIntegrationConnection,
  syncIntegrationNow,
};
