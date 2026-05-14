const breakGlassReviewRepository = require('@repositories/break-glass-review/break-glass-review.repository');
const breakGlassAccessRepository = require('@repositories/break-glass-access/break-glass-access.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { resolveEntityId, resolveIdentifierForFilter } = require('@lib/billing/identifiers');
const { buildPagination } = require('@lib/last-office/shared');
const {
  serializeBreakGlassAccess,
  serializeBreakGlassReview,
} = require('@lib/authorization/serializers');
const { emitAccessControlEvent, ACCESS_CONTROL_EVENTS } = require('@lib/last-office/events');
const { recordWorkflowEvent } = require('@lib/telemetry/metrics');

const listBreakGlassReviews = async (filters = {}, page = 1, limit = 20, context = {}) => {
  const skip = (page - 1) * limit;
  const tenantId = context.tenant_id || filters.tenant_id;
  if (!tenantId) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'tenant_id' }]);
  }

  const where = { tenant_id: tenantId };
  if (filters.break_glass_access_id) {
    where.break_glass_access_id = await resolveIdentifierForFilter({
      value: filters.break_glass_access_id,
      model: 'break_glass_access',
      where: { tenant_id: tenantId },
    });
  }
  if (filters.reviewer_user_id) {
    where.reviewer_user_id = await resolveIdentifierForFilter({
      value: filters.reviewer_user_id,
      model: 'user',
      where: { tenant_id: tenantId },
    });
  }
  if (filters.status) where.status = String(filters.status).trim().toUpperCase();

  const [rows, total] = await Promise.all([
    breakGlassReviewRepository.findMany(where, skip, limit),
    breakGlassReviewRepository.count(where),
  ]);

  return {
    reviews: rows.map(serializeBreakGlassReview),
    pagination: buildPagination(page, limit, total),
  };
};

const getBreakGlassReviewById = async (id) => {
  const resolvedId = await resolveEntityId({ model: 'break_glass_review', identifier: id });
  const review = await breakGlassReviewRepository.findById(resolvedId);
  if (!review) {
    throw new HttpError('errors.break_glass_review.not_found', 404);
  }
  return serializeBreakGlassReview(review);
};

const createBreakGlassReview = async (payload = {}, context = {}) => {
  if (!context.tenant_id || !context.user_id) {
    throw new HttpError('errors.auth.unauthorized', 401);
  }

  const accessId = await resolveEntityId({
    model: 'break_glass_access',
    identifier: payload.break_glass_access_id,
  });
  const access = await breakGlassAccessRepository.findById(accessId);
  if (!access) {
    throw new HttpError('errors.break_glass_access.not_found', 404);
  }
  if (access.status !== 'REQUESTED') {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'break_glass_access_id' }]);
  }

  if (payload.status === 'APPROVED' && !payload.expires_at && !access.expires_at) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'expires_at' }]);
  }

  const review = await breakGlassReviewRepository.create({
    break_glass_access_id: access.id,
    tenant_id: context.tenant_id,
    reviewer_user_id: context.user_id,
    status: payload.status,
    notes: payload.notes || null,
    decided_at: new Date(),
  });

  const updateData = {
    review_status: payload.status,
    reviewed_at: new Date(),
    version: Number(access.version || 1) + 1,
  };

  if (payload.status === 'APPROVED') {
    const expiresAt = payload.expires_at ? new Date(payload.expires_at) : access.expires_at;
    updateData.status = 'ACTIVE';
    updateData.approved_by_user_id = context.user_id;
    updateData.approved_at = new Date();
    updateData.starts_at = access.starts_at || new Date();
    updateData.expires_at = expiresAt;
  } else if (payload.status === 'REJECTED') {
    updateData.status = 'REJECTED';
  }

  const nextAccess = await breakGlassAccessRepository.update(access.id, updateData);

  createAuditLog({
    tenant_id: access.tenant_id,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'break_glass_access',
    entity_id: access.id,
    diff: {
      before: serializeBreakGlassAccess(access),
      after: serializeBreakGlassAccess(nextAccess),
      review: serializeBreakGlassReview(review),
    },
    ip_address: context.ip_address,
  }).catch(() => {});

  recordWorkflowEvent('break_glass.reviewed', {
    'hms.review.status': payload.status,
    'hms.resource.type': access.target_resource_type,
  });
  await emitAccessControlEvent({
    tenant_id: access.tenant_id,
    facility_id: access.facility_id,
    event: ACCESS_CONTROL_EVENTS.BREAK_GLASS_REVIEWED,
    payload: {
      break_glass_access_id: serializeBreakGlassAccess(nextAccess).id,
      break_glass_review_id: serializeBreakGlassReview(review).id,
      status: nextAccess.status,
      review_status: nextAccess.review_status,
    },
  });

  return {
    review: serializeBreakGlassReview(review),
    access: serializeBreakGlassAccess(nextAccess),
  };
};

module.exports = {
  createBreakGlassReview,
  getBreakGlassReviewById,
  listBreakGlassReviews,
};
