/**
 * Create Audit Log Entry
 * 
 * Creates audit log entry for mutations per compliance.mdc and prisma.mdc
 * Audit logs must include: user_id, action, entity, entity_id, diff (before/after), ip, created_at
 * Audit log creation must not prevent primary operation from completing (non-blocking)
 * 
 * Per prisma.mdc: Audit trail creation should be handled in service layer, not repositories
 * Audit trail failures must not prevent the primary operation (log errors, don't throw)
 */

const { logger } = require('@lib/logging');
const VALID_AUDIT_ACTIONS = new Set(['CREATE', 'UPDATE', 'DELETE', 'ACCESS', 'EXPORT', 'LOGIN', 'LOGOUT']);
const INVALID_ID_LITERALS = new Set(['unknown', 'undefined', 'null', 'n/a', 'na']);
const UPDATE_ACTION_ALIASES = new Set([
  'ACTIVATE',
  'APPROVE',
  'ASSIGN',
  'CANCEL',
  'COMPLETE',
  'DEACTIVATE',
  'DISCHARGE',
  'FINALIZE',
  'REASSIGN',
  'RELEASE',
  'RESOLVE',
  'RESTORE',
  'START',
  'STOP',
  'SUSPEND',
  'TRANSFER',
  'UNASSIGN',
]);
const CREATE_ACTION_PREFIXES = ['ADD_', 'CREATE_'];
const DELETE_ACTION_PREFIXES = ['DELETE_', 'REMOVE_', 'VOID_'];
const UPDATE_ACTION_PREFIXES = [
  'ACTIVATE_',
  'APPROVE_',
  'ASSIGN_',
  'CANCEL_',
  'COMPLETE_',
  'DISCHARGE_',
  'FINALIZE_',
  'PLAN_',
  'RELEASE_',
  'REQUEST_',
  'RESOLVE_',
  'RESTORE_',
  'START_',
  'TRANSFER_',
  'UPDATE_',
];

// Prisma may not be available during initial setup
let prisma = null;
try {
  prisma = require('@prisma/client'); // This resolves to src/prisma/client.js
} catch (err) {
  // Prisma not available yet, will be handled gracefully
}

const pickTenantId = (value) => {
  if (typeof value === 'string' && value.trim()) {
    const normalized = value.trim();
    if (INVALID_ID_LITERALS.has(normalized.toLowerCase())) {
      return null;
    }
    return normalized;
  }
  return null;
};

const resolveTenantIdFromAuditData = (auditData = {}) => {
  const directTenantId = pickTenantId(auditData.tenant_id);
  if (directTenantId) return directTenantId;

  const nestedTenantId = pickTenantId(auditData.tenant?.id || auditData.tenant?.tenant_id);
  if (nestedTenantId) return nestedTenantId;

  const diff = auditData.diff || {};
  const beforeTenantId = pickTenantId(diff.before?.tenant_id || diff.before?.tenant?.id);
  if (beforeTenantId) return beforeTenantId;

  const afterTenantId = pickTenantId(diff.after?.tenant_id || diff.after?.tenant?.id);
  if (afterTenantId) return afterTenantId;

  const detailsTenantId = pickTenantId(auditData.details?.tenant_id || auditData.details?.tenant?.id);
  if (detailsTenantId) return detailsTenantId;

  return null;
};

const resolveTenantIdFromUser = async (userId) => {
  if (!prisma?.user?.findUnique) return null;
  const normalizedUserId = pickTenantId(userId);
  if (!normalizedUserId) return null;

  try {
    const user = await prisma.user.findUnique({
      where: { id: normalizedUserId },
      select: { tenant_id: true }
    });
    return pickTenantId(user?.tenant_id);
  } catch {
    return null;
  }
};

const resolveAuditAction = (value) => {
  const rawAction = String(value || '').trim().toUpperCase();
  if (!rawAction) return 'ACCESS';
  if (VALID_AUDIT_ACTIONS.has(rawAction)) return rawAction;
  if (UPDATE_ACTION_ALIASES.has(rawAction)) return 'UPDATE';
  if (CREATE_ACTION_PREFIXES.some((prefix) => rawAction.startsWith(prefix))) return 'CREATE';
  if (DELETE_ACTION_PREFIXES.some((prefix) => rawAction.startsWith(prefix))) return 'DELETE';
  if (UPDATE_ACTION_PREFIXES.some((prefix) => rawAction.startsWith(prefix))) return 'UPDATE';
  return 'ACCESS';
};

/**
 * Create audit log entry (non-blocking)
 * 
 * @param {Object} auditData - Audit log data
 * @param {string} auditData.tenant_id - Tenant ID (required)
 * @param {string} [auditData.user_id] - User ID who performed the action
 * @param {string} auditData.action - Action type (e.g., 'create', 'update', 'delete')
 * @param {string} auditData.entity - Entity type (e.g., 'user', 'product', 'order')
 * @param {string} auditData.entity_id - Entity ID
 * @param {Object} [auditData.diff] - Before/after changes (JSON object)
 * @param {string} [auditData.ip_address] - IP address of the request
 * @param {string} [auditData.ip] - IP address (alias for ip_address)
 * @returns {Promise<void>} Resolves when audit log is created (or fails silently)
 */
const createAuditLog = async (auditData) => {
  // Validate required fields
  if (!auditData || !auditData.action || !auditData.entity || !auditData.entity_id) {
    logger.warn('Invalid audit log data: missing required fields', { 
      auditData,
      passedTenantId: auditData?.tenant_id,
      passedEntity_id: auditData?.entity_id,
      passedUserId: auditData?.user_id,
      allKeys: Object.keys(auditData || {})
    });
    return;
  }

  // If Prisma is not available, log warning and return (non-blocking)
  if (!prisma) {
    logger.warn('Prisma client not available, skipping audit log creation', {
      action: auditData.action,
      entity: auditData.entity,
      entity_id: auditData.entity_id
    });
    return;
  }

  try {
    const rawAction = String(auditData.action || '').trim().toUpperCase();
    const action = resolveAuditAction(rawAction);
    const detailsPayload =
      auditData.diff ||
      auditData.details ||
      (auditData.old_values || auditData.new_values
        ? {
            before: auditData.old_values || null,
            after: auditData.new_values || null
          }
        : null);
    const diffJson =
      action === rawAction || !detailsPayload
        ? detailsPayload
        : { ...(typeof detailsPayload === 'object' ? detailsPayload : { details: detailsPayload }), original_action: rawAction };

    // Create audit log entry asynchronously (non-blocking)
    // Use setImmediate to ensure it doesn't block the main operation
    setImmediate(async () => {
      try {
        const resolvedTenantId =
          resolveTenantIdFromAuditData(auditData) ||
          (await resolveTenantIdFromUser(auditData.user_id));

        if (!resolvedTenantId) {
          logger.warn('Invalid audit log data: missing tenant_id', {
            action: auditData.action,
            entity: auditData.entity,
            entity_id: auditData.entity_id,
            passedUserId: auditData.user_id || null,
            allKeys: Object.keys(auditData || {})
          });
          return;
        }

        await prisma.audit_log.create({
          data: {
            tenant_id: resolvedTenantId,
            user_id: auditData.user_id || null,
            action,
            entity: auditData.entity,
            entity_id: auditData.entity_id,
            diff_json: diffJson,
            ip_address: auditData.ip_address || auditData.ip || null,
            created_at: new Date()
          }
        });
      } catch (err) {
        // Log error but don't throw (non-blocking)
        logger.error('Failed to create audit log entry', {
          error: err.message,
          action: auditData.action,
          entity: auditData.entity,
          entity_id: auditData.entity_id
        });
      }
    });
  } catch (err) {
    // Log error but don't throw (non-blocking)
    logger.error('Failed to schedule audit log creation', {
      error: err.message,
      action: auditData.action,
      entity: auditData.entity,
      entity_id: auditData.entity_id
    });
  }
};

module.exports = { createAuditLog };

