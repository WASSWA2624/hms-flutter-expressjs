const breakGlassAccessRepository = require('@repositories/break-glass-access/break-glass-access.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveEntityId,
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
} = require('@lib/billing/identifiers');
const { buildPagination } = require('@lib/last-office/shared');
const { serializeBreakGlassAccess } = require('@lib/authorization/serializers');
const { emitAccessControlEvent, ACCESS_CONTROL_EVENTS } = require('@lib/last-office/events');
const { recordWorkflowEvent } = require('@lib/telemetry/metrics');
const { PERMISSIONS } = require('@config/permissions');
const { getUserPermissions } = require('@middlewares/auth.middleware');

const canReview = (context = {}) => {
  const permissions = getUserPermissions(context.user || context);
  return permissions.includes(PERMISSIONS.BREAK_GLASS_REVIEW) || permissions.includes(PERMISSIONS.BREAK_GLASS_APPROVE);
};

const listBreakGlassAccesses = async (filters = {}, page = 1, limit = 20, context = {}) => {
  const skip = (page - 1) * limit;
  const tenantId = context.tenant_id || filters.tenant_id;
  if (!tenantId) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'tenant_id' }]);
  }

  const where = { tenant_id: tenantId };
  if (!canReview(context)) {
    where.requested_by_user_id = context.user_id;
  } else if (filters.requested_by_user_id) {
    where.requested_by_user_id = await resolveIdentifierForFilter({
      value: filters.requested_by_user_id,
      model: 'user',
      where: { tenant_id: tenantId },
    });
  }

  if (filters.patient_id) {
    where.patient_id = await resolveIdentifierForFilter({
      value: filters.patient_id,
      model: 'patient',
      where: { tenant_id: tenantId },
    });
  }
  if (filters.status) where.status = String(filters.status).trim().toUpperCase();
  if (filters.review_status) where.review_status = String(filters.review_status).trim().toUpperCase();
  if (filters.target_resource_type) where.target_resource_type = String(filters.target_resource_type).trim();

  const [rows, total] = await Promise.all([
    breakGlassAccessRepository.findMany(where, skip, limit),
    breakGlassAccessRepository.count(where),
  ]);

  return {
    accesses: rows.map(serializeBreakGlassAccess),
    pagination: buildPagination(page, limit, total),
  };
};

const getBreakGlassAccessById = async (id, context = {}) => {
  const resolvedId = await resolveEntityId({ model: 'break_glass_access', identifier: id });
  const record = await breakGlassAccessRepository.findById(resolvedId);
  if (!record) {
    throw new HttpError('errors.break_glass_access.not_found', 404);
  }
  if (!canReview(context) && record.requested_by_user_id !== context.user_id) {
    throw new HttpError('errors.auth.insufficient_permissions', 403);
  }
  return serializeBreakGlassAccess(record);
};

const createBreakGlassAccess = async (payload = {}, context = {}) => {
  const tenantId = context.tenant_id || payload.tenant_id;
  if (!tenantId || !context.user_id) {
    throw new HttpError('errors.auth.unauthorized', 401);
  }

  const record = await breakGlassAccessRepository.create({
    tenant_id: tenantId,
    facility_id: await resolveIdentifierForPayload({
      value: payload.facility_id ?? context.facility_id,
      field: 'facility_id',
      model: 'facility',
      nullable: true,
      where: { tenant_id: tenantId },
    }),
    branch_id: await resolveIdentifierForPayload({
      value: payload.branch_id ?? context.branch_id,
      field: 'branch_id',
      model: 'branch',
      nullable: true,
      where: { tenant_id: tenantId },
    }),
    patient_id: await resolveIdentifierForPayload({
      value: payload.patient_id,
      field: 'patient_id',
      model: 'patient',
      nullable: true,
      where: { tenant_id: tenantId },
    }),
    target_resource_type: payload.target_resource_type,
    target_resource_id: payload.target_resource_id || null,
    requested_by_user_id: context.user_id,
    reason: payload.reason,
    justification_json: payload.justification_json || null,
    requested_scope_json: payload.requested_scope_json || null,
    starts_at: payload.starts_at ? new Date(payload.starts_at) : null,
    expires_at: payload.expires_at ? new Date(payload.expires_at) : null,
    etag: payload.etag || null,
  });

  createAuditLog({
    tenant_id: tenantId,
    user_id: context.user_id,
    action: 'CREATE',
    entity: 'break_glass_access',
    entity_id: record.id,
    diff: { after: serializeBreakGlassAccess(record) },
    ip_address: context.ip_address,
  }).catch(() => {});

  recordWorkflowEvent('break_glass.requested', {
    'hms.resource.type': record.target_resource_type,
  });
  await emitAccessControlEvent({
    tenant_id: tenantId,
    facility_id: record.facility_id,
    event: ACCESS_CONTROL_EVENTS.BREAK_GLASS_REQUESTED,
    payload: {
      break_glass_access_id: serializeBreakGlassAccess(record).id,
      target_resource_type: record.target_resource_type,
      status: record.status,
    },
  });

  return serializeBreakGlassAccess(record);
};

const revokeBreakGlassAccess = async (id, payload = {}, context = {}) => {
  const resolvedId = await resolveEntityId({ model: 'break_glass_access', identifier: id });
  const existing = await breakGlassAccessRepository.findById(resolvedId);
  if (!existing) {
    throw new HttpError('errors.break_glass_access.not_found', 404);
  }
  if (!canReview(context) && existing.requested_by_user_id !== context.user_id) {
    throw new HttpError('errors.auth.insufficient_permissions', 403);
  }

  const next = await breakGlassAccessRepository.update(existing.id, {
    status: 'REVOKED',
    revoked_by_user_id: context.user_id,
    revoked_at: new Date(),
    revoke_reason: payload.revoke_reason || null,
    reviewed_at: new Date(),
    version: Number(existing.version || 1) + 1,
  });

  createAuditLog({
    tenant_id: existing.tenant_id,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'break_glass_access',
    entity_id: existing.id,
    diff: { before: serializeBreakGlassAccess(existing), after: serializeBreakGlassAccess(next) },
    ip_address: context.ip_address,
  }).catch(() => {});

  recordWorkflowEvent('break_glass.revoked', {
    'hms.resource.type': existing.target_resource_type,
  });
  await emitAccessControlEvent({
    tenant_id: existing.tenant_id,
    facility_id: existing.facility_id,
    event: ACCESS_CONTROL_EVENTS.BREAK_GLASS_REVOKED,
    payload: {
      break_glass_access_id: serializeBreakGlassAccess(next).id,
      status: next.status,
    },
  });

  return serializeBreakGlassAccess(next);
};

module.exports = {
  createBreakGlassAccess,
  getBreakGlassAccessById,
  listBreakGlassAccesses,
  revokeBreakGlassAccess,
};
