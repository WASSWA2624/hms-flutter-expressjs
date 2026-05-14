const { resolvePublicIdentifier } = require('@lib/billing/identifiers');

const safePublicId = (...values) => resolvePublicIdentifier(...values) || null;

const safeString = (value) => {
  const normalized = String(value ?? '').trim();
  return normalized || null;
};

const safeNumber = (value, fallback = 0) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const SENSITIVE_CONFIG_KEY_PATTERN =
  /(secret|token|password|api[_-]?key|private[_-]?key|client[_-]?secret|authorization|signing)/i;

const summarizeConfigValue = (value, parentKey = '') => {
  if (SENSITIVE_CONFIG_KEY_PATTERN.test(String(parentKey || ''))) {
    return '[REDACTED]';
  }

  if (Array.isArray(value)) {
    return value.map((entry) => summarizeConfigValue(entry, parentKey));
  }

  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([key, entry]) => [key, summarizeConfigValue(entry, key)])
    );
  }

  if (typeof value === 'string' && value.length > 120) {
    return `${value.slice(0, 117)}...`;
  }

  return value;
};

const safeUrlHost = (value) => {
  const target = safeString(value);
  if (!target) return null;

  try {
    return new URL(target).host || null;
  } catch (error) {
    return null;
  }
};

const serializeIntegration = (record) => {
  if (!record || typeof record !== 'object') return null;

  return {
    id: safePublicId(record.human_friendly_id, record.id),
    human_friendly_id: safePublicId(record.human_friendly_id, record.id),
    display_id: safePublicId(record.human_friendly_id, record.id),
    tenant_id: safePublicId(record?.tenant?.human_friendly_id, record.tenant_id),
    tenant_label: safeString(record?.tenant?.name),
    integration_type: safeString(record.integration_type),
    status: safeString(record.status),
    name: safeString(record.name),
    config_json: summarizeConfigValue(record.config_json),
    has_config: record.config_json !== null && record.config_json !== undefined,
    log_count: safeNumber(record?._count?.logs, 0),
    webhook_subscription_count: safeNumber(record?._count?.webhooks, 0),
    requires_attention: safeString(record.status) === 'ERROR',
    created_at: record.created_at || null,
    updated_at: record.updated_at || null,
    version: safeNumber(record.version, 1),
  };
};

const serializeIntegrationLog = (record) => {
  if (!record || typeof record !== 'object') return null;

  return {
    id: safePublicId(record.human_friendly_id, record.id),
    human_friendly_id: safePublicId(record.human_friendly_id, record.id),
    display_id: safePublicId(record.human_friendly_id, record.id),
    integration_id: safePublicId(record?.integration?.human_friendly_id, record.integration_id),
    integration_display_id: safePublicId(
      record?.integration?.human_friendly_id,
      record.integration_id
    ),
    integration_label: safeString(record?.integration?.name),
    integration_type: safeString(record?.integration?.integration_type),
    integration_status: safeString(record?.integration?.status),
    tenant_id: safePublicId(
      record?.integration?.tenant?.human_friendly_id,
      record?.integration?.tenant_id
    ),
    tenant_label: safeString(record?.integration?.tenant?.name),
    status: safeString(record.status),
    message: safeString(record.message),
    logged_at: record.logged_at || null,
    timeline_at: record.logged_at || record.created_at || null,
    requires_attention: safeString(record.status) === 'ERROR',
    created_at: record.created_at || null,
    updated_at: record.updated_at || null,
    version: safeNumber(record.version, 1),
  };
};

const serializeWebhookSubscription = (record) => {
  if (!record || typeof record !== 'object') return null;

  return {
    id: safePublicId(record.human_friendly_id, record.id),
    human_friendly_id: safePublicId(record.human_friendly_id, record.id),
    display_id: safePublicId(record.human_friendly_id, record.id),
    tenant_id: safePublicId(record?.tenant?.human_friendly_id, record.tenant_id),
    tenant_label: safeString(record?.tenant?.name),
    integration_id: safePublicId(record?.integration?.human_friendly_id, record.integration_id),
    integration_display_id: safePublicId(
      record?.integration?.human_friendly_id,
      record.integration_id
    ),
    integration_label: safeString(record?.integration?.name),
    integration_type: safeString(record?.integration?.integration_type),
    integration_status: safeString(record?.integration?.status),
    event: safeString(record.event),
    target_url: safeString(record.target_url),
    target_host: safeUrlHost(record.target_url),
    is_active: Boolean(record.is_active),
    created_at: record.created_at || null,
    updated_at: record.updated_at || null,
    version: safeNumber(record.version, 1),
  };
};

module.exports = {
  safePublicId,
  serializeIntegration,
  serializeIntegrationLog,
  serializeWebhookSubscription,
};
