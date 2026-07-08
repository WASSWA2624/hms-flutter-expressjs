/**
 * Audit-driven realtime emission
 *
 * Publishes websocket domain events for CRUD audit entries so every module
 * with createAuditLog mutations participates in realtime sync automatically.
 */

const { logger } = require('@lib/logging');
const { publishCrudRealtimeEvent } = require('@lib/websocket/crud-realtime');
const {
  DEFAULT_RECIPIENT_ROLES,
  REALTIME_SKIP_ENTITIES,
  REALTIME_EVENT_OVERRIDES,
  ENTITY_RECIPIENT_ROLES,
  REALTIME_MUTATION_ACTIONS
} = require('@lib/realtime/config');

const INVALID_ID_LITERALS = new Set(['unknown', 'undefined', 'null', 'n/a', 'na']);

const pickId = (value) => {
  if (typeof value !== 'string' || !value.trim()) return null;
  const normalized = value.trim();
  if (INVALID_ID_LITERALS.has(normalized.toLowerCase())) return null;
  return normalized;
};

const normalizeEntity = (value) => String(value || '').trim().toLowerCase();

const resolveRealtimeOperation = (resolvedAction, rawAction) => {
  const raw = String(rawAction || '').trim().toUpperCase();
  if (raw === 'CANCEL' || raw.startsWith('CANCEL_') || raw.endsWith('_CANCELED')) {
    return 'canceled';
  }
  if (raw === 'RESCHEDULE' || raw.startsWith('RESCHEDULE_')) {
    return 'rescheduled';
  }
  if (raw === 'REACTIVATE' || raw.startsWith('REACTIVATE_')) {
    return 'activated';
  }
  if (raw === 'DEACTIVATE' || raw.startsWith('DEACTIVATE_')) {
    return 'deactivated';
  }
  if (resolvedAction === 'CREATE') return 'created';
  if (resolvedAction === 'UPDATE') return 'updated';
  if (resolvedAction === 'DELETE') return 'deleted';
  return null;
};

const extractResourceFromAudit = (auditData = {}, tenantId) => {
  const diff = auditData.diff || auditData.details || {};
  const after = diff.after && typeof diff.after === 'object' ? diff.after : {};
  const before = diff.before && typeof diff.before === 'object' ? diff.before : {};
  const snapshot = Object.keys(after).length > 0 ? after : before;

  return {
    id: pickId(auditData.entity_id),
    tenant_id: pickId(snapshot.tenant_id) || pickId(auditData.tenant_id) || pickId(tenantId),
    facility_id: pickId(snapshot.facility_id) || pickId(auditData.facility_id),
    branch_id: pickId(snapshot.branch_id),
    patient_id: pickId(snapshot.patient_id),
    provider_user_id: pickId(snapshot.provider_user_id),
    status: snapshot.status || null
  };
};

const resolveRealtimeEvent = (entity, operation, auditData = {}) => {
  if (auditData.realtime_event) {
    return String(auditData.realtime_event).trim();
  }

  const overrideKey = `${entity}_${operation}`;
  if (REALTIME_EVENT_OVERRIDES[overrideKey]) {
    return REALTIME_EVENT_OVERRIDES[overrideKey];
  }

  return `${entity}.${operation}`;
};

/**
 * Publish a websocket domain event derived from an audit log entry.
 *
 * @param {Object} auditData
 * @param {string} resolvedTenantId
 * @param {string} resolvedAction
 * @returns {Promise<number>}
 */
const publishAuditRealtime = async (auditData = {}, resolvedTenantId, resolvedAction) => {
  try {
    if (auditData.realtime === false) {
      return 0;
    }

    if (!REALTIME_MUTATION_ACTIONS.has(resolvedAction)) {
      return 0;
    }

    const entity = normalizeEntity(auditData.entity);
    if (!entity || REALTIME_SKIP_ENTITIES.has(entity)) {
      return 0;
    }

    const operation = resolveRealtimeOperation(resolvedAction, auditData.action);
    if (!operation) {
      return 0;
    }

    const resource = extractResourceFromAudit(auditData, resolvedTenantId);
    if (!resource.id || !resource.tenant_id) {
      return 0;
    }

    const event = resolveRealtimeEvent(entity, operation, auditData);
    const recipientRoles = ENTITY_RECIPIENT_ROLES[entity] || DEFAULT_RECIPIENT_ROLES;
    const affected = {};

    if (resource.patient_id) affected.patient_id = resource.patient_id;
    if (resource.provider_user_id) affected.provider_user_id = resource.provider_user_id;

    const diff = auditData.diff || auditData.details || {};
    const after = diff.after && typeof diff.after === 'object' ? diff.after : {};
    const before = diff.before && typeof diff.before === 'object' ? diff.before : {};
    const snapshot = Object.keys(after).length > 0 ? after : before;
    const entitySnapshot =
      snapshot && typeof snapshot === 'object' && Object.keys(snapshot).length > 1
        ? snapshot
        : null;

    return await publishCrudRealtimeEvent({
      event,
      resource,
      resource_type: entity,
      actor_user_id: auditData.user_id || null,
      recipient_roles: recipientRoles,
      affected,
      payload: {
        operation,
        branch_id: resource.branch_id || null,
        patient_id: resource.patient_id || null,
        provider_user_id: resource.provider_user_id || null,
        status: resource.status,
        ...(entitySnapshot ? { entity: entitySnapshot, action: operation === 'deleted' ? 'remove' : 'upsert' } : {}),
        ...(auditData.realtime_payload || {})
      }
    });
  } catch (error) {
    logger.error('Failed to publish audit realtime event', {
      entity: auditData.entity,
      entity_id: auditData.entity_id,
      action: auditData.action,
      error: error.message
    });
    return 0;
  }
};

module.exports = {
  publishAuditRealtime,
  resolveRealtimeOperation,
  extractResourceFromAudit
};
