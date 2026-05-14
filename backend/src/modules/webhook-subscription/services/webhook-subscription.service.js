/**
 * Webhook subscription service
 *
 * @module modules/webhook-subscription/services
 * @description Business logic layer for webhook subscription operations.
 * Per module-creation.mdc: Services implement business logic and call repositories.
 * Per module-creation.mdc: All mutations must call createAuditLog.
 */

const webhookSubscriptionRepository = require('@repositories/webhook-subscription/webhook-subscription.repository');
const integrationLogRepository = require('@repositories/integration-log/integration-log.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { withRetry, isTransientError } = require('@lib/resilience/retry');
const {
  sanitizeIdentifier,
  resolveEntityId,
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
} = require('@lib/billing/identifiers');
const {
  serializeWebhookSubscription,
} = require('@lib/integrations/serializers');
const crypto = require('crypto');

const SORT_FIELDS = new Set(['created_at', 'updated_at', 'event', 'is_active']);
const WEBHOOK_REQUEST_TIMEOUT_MS = 10000;
const WEBHOOK_SIGNING_SECRET_KEYS = new Set([
  'webhooksecret',
  'signingsecret',
  'webhooksigningsecret',
  'signingsecret',
  'secret',
]);

const WEBHOOK_SUBSCRIPTION_INCLUDE = {
  tenant: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
    },
  },
  integration: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
      integration_type: true,
      status: true,
      config_json: true,
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

  if (filters.integration_id !== undefined) {
    const integrationId = await resolveIdentifierForFilter({
      value: filters.integration_id,
      model: 'integration',
      where: where.tenant_id ? { tenant_id: where.tenant_id } : {},
    });
    if (integrationId === null) return buildEmptyListResult(page, limit);
    if (integrationId !== undefined) where.integration_id = integrationId;
  }

  const event = sanitizeIdentifier(filters.event);
  if (event) {
    where.event = {
      contains: event,
    };
  }

  if (typeof filters.is_active === 'boolean') {
    where.is_active = filters.is_active;
  }

  const search = sanitizeIdentifier(filters.search);
  if (search) {
    where.OR = [
      { event: { contains: search } },
      { target_url: { contains: search } },
      { human_friendly_id: { contains: search.toUpperCase() } },
      { integration: { name: { contains: search } } },
    ];
  }

  return where;
};

const resolveCreatePayload = async (data = {}) => {
  const payload = { ...data };
  const tenantId = await resolveIdentifierForPayload({
    value: payload.tenant_id,
    field: 'tenant_id',
    model: 'tenant',
  });
  const integrationId = await resolveIdentifierForPayload({
    value: payload.integration_id,
    field: 'integration_id',
    model: 'integration',
    where: tenantId ? { tenant_id: tenantId } : {},
    nullable: true,
  });

  payload.tenant_id = tenantId;
  payload.integration_id = integrationId;
  return payload;
};

const resolveUpdatePayload = async (data = {}, existingWebhookSubscription = null) => {
  const payload = { ...data };

  if (Object.prototype.hasOwnProperty.call(payload, 'integration_id')) {
    payload.integration_id = await resolveIdentifierForPayload({
      value: payload.integration_id,
      field: 'integration_id',
      model: 'integration',
      where: existingWebhookSubscription?.tenant_id
        ? { tenant_id: existingWebhookSubscription.tenant_id }
        : {},
      nullable: true,
    });
  }

  return payload;
};

const normalizeString = (value) => String(value || '').trim();

const truncateText = (value, max = 2000) => {
  const normalized = normalizeString(value);
  if (!normalized) return null;
  return normalized.length > max ? `${normalized.slice(0, max - 3)}...` : normalized;
};

const resolveWebhookSigningSecret = (config) => {
  if (!config || typeof config !== 'object') return null;

  if (Array.isArray(config)) {
    for (const entry of config) {
      const resolved = resolveWebhookSigningSecret(entry);
      if (resolved) return resolved;
    }
    return null;
  }

  for (const [key, value] of Object.entries(config)) {
    const normalizedKey = normalizeString(key).replace(/[_-]/g, '').toLowerCase();
    if (WEBHOOK_SIGNING_SECRET_KEYS.has(normalizedKey) && typeof value === 'string') {
      return normalizeString(value) || null;
    }

    if (value && typeof value === 'object') {
      const nested = resolveWebhookSigningSecret(value);
      if (nested) return nested;
    }
  }

  return null;
};

const createWebhookSignature = (secret, timestamp, body) =>
  `sha256=${crypto
    .createHmac('sha256', secret)
    .update(`${timestamp}.${body}`)
    .digest('hex')}`;

const deliverWebhookReplay = async (webhookSubscription, replayPayload) => {
  const signingSecret = resolveWebhookSigningSecret(webhookSubscription?.integration?.config_json);
  const requestBody = JSON.stringify(replayPayload);
  const timestamp = Math.floor(Date.now() / 1000).toString();
  const headers = {
    'content-type': 'application/json',
    'user-agent': 'hms-backend/webhooks',
    'x-hms-webhook-event': replayPayload.event,
    'x-hms-webhook-delivery-id': replayPayload.delivery_id,
    'x-hms-webhook-timestamp': timestamp,
  };

  if (signingSecret) {
    headers['x-hms-webhook-signature'] = createWebhookSignature(
      signingSecret,
      timestamp,
      requestBody
    );
  }

  let attemptCount = 0;
  const response = await withRetry(
    async () => {
      attemptCount += 1;
      const httpResponse = await globalThis.fetch(webhookSubscription.target_url, {
        method: 'POST',
        headers,
        body: requestBody,
        signal: globalThis.AbortSignal?.timeout
          ? globalThis.AbortSignal.timeout(WEBHOOK_REQUEST_TIMEOUT_MS)
          : undefined,
      });
      const responseBody = truncateText(await httpResponse.text(), 4000);

      if (!httpResponse.ok) {
        const error = new Error(`Webhook delivery failed with status ${httpResponse.status}`);
        error.statusCode = httpResponse.status;
        error.responseBody = responseBody;
        throw error;
      }

      return {
        status: httpResponse.status,
        body: responseBody,
        signed: Boolean(signingSecret),
        attempt_count: attemptCount,
      };
    },
    {
      maxAttempts: 3,
      initialDelayMs: 500,
      maxDelayMs: 5000,
      shouldRetry: (error) =>
        isTransientError(error) || Number(error?.statusCode || 0) === 429,
    }
  );

  return response;
};

const logWebhookReplayDelivery = async ({
  webhookSubscription,
  replayPayload,
  deliveryResult,
  deliveryError,
}) => {
  if (!webhookSubscription?.integration_id) {
    return;
  }

  const message = deliveryError
    ? truncateText(
        `Webhook replay ${replayPayload.delivery_id} failed for ${webhookSubscription.target_url}: ${deliveryError.responseBody || deliveryError.message}`
      )
    : truncateText(
        `Webhook replay ${replayPayload.delivery_id} delivered to ${webhookSubscription.target_url} with HTTP ${deliveryResult.status}.`
      );

  await integrationLogRepository.create({
    integration_id: webhookSubscription.integration_id,
    status: deliveryError ? 'ERROR' : 'ACTIVE',
    message,
  }).catch(() => {});
};

/**
 * Get webhook subscription by ID
 *
 * @param {string} id - Webhook subscription ID
 * @returns {Promise<Object>} Webhook subscription object
 * @throws {HttpError} 404 if webhook subscription not found
 */
const getWebhookSubscriptionById = async (id) => {
  const resolvedId = await resolveEntityId({
    model: 'webhook_subscription',
    identifier: id,
  });
  const webhookSubscription = await webhookSubscriptionRepository.findById(
    resolvedId,
    WEBHOOK_SUBSCRIPTION_INCLUDE
  );

  if (!webhookSubscription) {
    throw new HttpError('errors.webhook_subscription.not_found', 404);
  }

  return serializeWebhookSubscription(webhookSubscription);
};

/**
 * List webhook subscriptions with pagination and filters
 *
 * @param {Object} filters - Filter criteria
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order (asc/desc)
 * @returns {Promise<Object>} Paginated webhook subscriptions
 */
const listWebhookSubscriptions = async (
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

  const [webhookSubscriptions, total] = await Promise.all([
    webhookSubscriptionRepository.findMany(
      resolvedFilters,
      skip,
      numericLimit,
      orderBy,
      WEBHOOK_SUBSCRIPTION_INCLUDE
    ),
    webhookSubscriptionRepository.count(resolvedFilters),
  ]);

  return {
    data: webhookSubscriptions.map(serializeWebhookSubscription),
    pagination: buildPagination(numericPage, numericLimit, total),
  };
};

/**
 * Create new webhook subscription
 *
 * @param {Object} data - Webhook subscription data
 * @param {Object} auditContext - Audit context (user_id, tenant_id, ip_address)
 * @returns {Promise<Object>} Created webhook subscription
 */
const createWebhookSubscription = async (data, auditContext) => {
  const payload = await resolveCreatePayload(data);
  const webhookSubscription = await webhookSubscriptionRepository.create(payload);
  const createdRecord =
    (await webhookSubscriptionRepository.findById(
      webhookSubscription.id,
      WEBHOOK_SUBSCRIPTION_INCLUDE
    )) || webhookSubscription;

  await createAuditLog({
    action: 'CREATE',
    entity: 'webhook_subscription',
    entity_id: webhookSubscription.id,
    new_values: webhookSubscription,
    ...auditContext,
  });

  return serializeWebhookSubscription(createdRecord);
};

/**
 * Update webhook subscription
 *
 * @param {string} id - Webhook subscription ID
 * @param {Object} data - Update data
 * @param {Object} auditContext - Audit context (user_id, tenant_id, ip_address)
 * @returns {Promise<Object>} Updated webhook subscription
 * @throws {HttpError} 404 if webhook subscription not found
 */
const updateWebhookSubscription = async (id, data, auditContext) => {
  const resolvedId = await resolveEntityId({
    model: 'webhook_subscription',
    identifier: id,
  });
  const existingWebhookSubscription = await webhookSubscriptionRepository.findById(
    resolvedId,
    WEBHOOK_SUBSCRIPTION_INCLUDE
  );

  if (!existingWebhookSubscription) {
    throw new HttpError('errors.webhook_subscription.not_found', 404);
  }

  const payload = await resolveUpdatePayload(data, existingWebhookSubscription);
  const updated = await webhookSubscriptionRepository.update(existingWebhookSubscription.id, payload);
  const updatedRecord =
    (await webhookSubscriptionRepository.findById(updated.id, WEBHOOK_SUBSCRIPTION_INCLUDE)) ||
    updated;

  await createAuditLog({
    action: 'UPDATE',
    entity: 'webhook_subscription',
    entity_id: existingWebhookSubscription.id,
    old_values: existingWebhookSubscription,
    new_values: updated,
    ...auditContext,
  });

  return serializeWebhookSubscription(updatedRecord);
};

/**
 * Delete webhook subscription (soft delete)
 *
 * @param {string} id - Webhook subscription ID
 * @param {Object} auditContext - Audit context (user_id, tenant_id, ip_address)
 * @returns {Promise<Object>} Deleted webhook subscription
 * @throws {HttpError} 404 if webhook subscription not found
 */
const deleteWebhookSubscription = async (id, auditContext) => {
  const resolvedId = await resolveEntityId({
    model: 'webhook_subscription',
    identifier: id,
  });
  const existingWebhookSubscription = await webhookSubscriptionRepository.findById(
    resolvedId,
    WEBHOOK_SUBSCRIPTION_INCLUDE
  );

  if (!existingWebhookSubscription) {
    throw new HttpError('errors.webhook_subscription.not_found', 404);
  }

  const deleted = await webhookSubscriptionRepository.softDelete(existingWebhookSubscription.id);

  await createAuditLog({
    action: 'DELETE',
    entity: 'webhook_subscription',
    entity_id: existingWebhookSubscription.id,
    old_values: existingWebhookSubscription,
    ...auditContext,
  });

  return deleted;
};

/**
 * Replay webhook subscription event
 *
 * @param {string} id - Webhook subscription ID
 * @param {Object} data - Replay payload
 * @param {Object} auditContext - Audit context
 * @returns {Promise<Object>} Replay result
 */
const replayWebhookSubscription = async (id, data = {}, auditContext = {}) => {
  const resolvedId = await resolveEntityId({
    model: 'webhook_subscription',
    identifier: id,
  });
  const webhookSubscription = await webhookSubscriptionRepository.findById(
    resolvedId,
    WEBHOOK_SUBSCRIPTION_INCLUDE
  );

  if (!webhookSubscription) {
    throw new HttpError('errors.webhook_subscription.not_found', 404);
  }

  const serializedWebhookSubscription = serializeWebhookSubscription(webhookSubscription);
  const deliveryId = crypto.randomUUID();
  const replayedAt = new Date().toISOString();
  const payloadJson = data.payload_json || {};
  const notes = sanitizeIdentifier(data.notes) || null;
  const replayPayload = {
    delivery_id: deliveryId,
    event: webhookSubscription.event,
    replayed_at: replayedAt,
    webhook_subscription_id: serializedWebhookSubscription.id,
    integration_id: serializedWebhookSubscription.integration_id,
    tenant_id: serializedWebhookSubscription.tenant_id,
    data: payloadJson,
    notes,
  };

  let deliveryResult = null;
  let deliveryError = null;
  try {
    deliveryResult = await deliverWebhookReplay(webhookSubscription, replayPayload);
  } catch (error) {
    deliveryError = error;
  }

  await logWebhookReplayDelivery({
    webhookSubscription,
    replayPayload,
    deliveryResult,
    deliveryError,
  });

  const replayResult = {
    webhook_subscription_id: serializedWebhookSubscription.id,
    webhook_subscription_display_id: serializedWebhookSubscription.display_id,
    integration_id: serializedWebhookSubscription.integration_id,
    integration_display_id: serializedWebhookSubscription.integration_display_id,
    integration_label: serializedWebhookSubscription.integration_label,
    event: webhookSubscription.event,
    target_url: webhookSubscription.target_url,
    replayed: !deliveryError,
    replayed_at: replayedAt,
    delivery_id: deliveryId,
    payload_json: payloadJson,
    notes,
    signed: Boolean(deliveryResult?.signed),
    attempt_count: Number(deliveryResult?.attempt_count || 0),
    http_status: deliveryResult?.status || deliveryError?.statusCode || null,
    error: deliveryError
      ? truncateText(deliveryError.responseBody || deliveryError.message)
      : null,
  };

  await createAuditLog({
    action: 'REPLAY',
    entity: 'webhook_subscription',
    entity_id: webhookSubscription.id,
    old_values: webhookSubscription,
    new_values: replayResult,
    ...auditContext,
  }).catch(() => {});

  if (deliveryError) {
    throw new HttpError('errors.service.unavailable', 503, [
      {
        field: 'webhook_delivery',
        webhook_subscription_id: serializedWebhookSubscription.id,
        delivery_id: deliveryId,
        http_status: deliveryError.statusCode || null,
      },
    ]);
  }

  return replayResult;
};

module.exports = {
  getWebhookSubscriptionById,
  listWebhookSubscriptions,
  createWebhookSubscription,
  updateWebhookSubscription,
  deleteWebhookSubscription,
  replayWebhookSubscription,
};
