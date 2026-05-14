const { resolvePublicIdentifier } = require('@lib/billing/identifiers');

const serializeAbacPolicy = (record) => ({
  id: resolvePublicIdentifier(record?.human_friendly_id, record?.id),
  human_friendly_id: resolvePublicIdentifier(record?.human_friendly_id, record?.id),
  tenant_id: resolvePublicIdentifier(record?.tenant?.human_friendly_id, record?.tenant_id),
  facility_id: resolvePublicIdentifier(record?.facility?.human_friendly_id, record?.facility_id),
  branch_id: resolvePublicIdentifier(record?.branch?.human_friendly_id, record?.branch_id),
  department_id: resolvePublicIdentifier(record?.department?.human_friendly_id, record?.department_id),
  name: record?.name || null,
  description: record?.description || null,
  resource_type: record?.resource_type || null,
  action: record?.action || null,
  effect: record?.effect || null,
  priority: record?.priority || 0,
  is_active: Boolean(record?.is_active),
  subject_conditions_json: record?.subject_conditions_json || null,
  object_conditions_json: record?.object_conditions_json || null,
  environment_conditions_json: record?.environment_conditions_json || null,
  reason_template: record?.reason_template || null,
  created_by_user_id: resolvePublicIdentifier(record?.created_by?.human_friendly_id, record?.created_by_user_id),
  updated_by_user_id: resolvePublicIdentifier(record?.updated_by?.human_friendly_id, record?.updated_by_user_id),
  version: Number(record?.version || 1),
  created_at: record?.created_at || null,
  updated_at: record?.updated_at || null,
});

const serializeBreakGlassAccess = (record) => ({
  id: resolvePublicIdentifier(record?.human_friendly_id, record?.id),
  human_friendly_id: resolvePublicIdentifier(record?.human_friendly_id, record?.id),
  tenant_id: resolvePublicIdentifier(record?.tenant?.human_friendly_id, record?.tenant_id),
  facility_id: resolvePublicIdentifier(record?.facility?.human_friendly_id, record?.facility_id),
  branch_id: resolvePublicIdentifier(record?.branch?.human_friendly_id, record?.branch_id),
  patient_id: resolvePublicIdentifier(record?.patient?.human_friendly_id, record?.patient_id),
  target_resource_type: record?.target_resource_type || null,
  target_resource_id: record?.target_resource_id || null,
  requested_by_user_id: resolvePublicIdentifier(record?.requested_by?.human_friendly_id, record?.requested_by_user_id),
  approved_by_user_id: resolvePublicIdentifier(record?.approved_by?.human_friendly_id, record?.approved_by_user_id),
  revoked_by_user_id: resolvePublicIdentifier(record?.revoked_by?.human_friendly_id, record?.revoked_by_user_id),
  reason: record?.reason || null,
  justification_json: record?.justification_json || null,
  requested_scope_json: record?.requested_scope_json || null,
  status: record?.status || null,
  review_status: record?.review_status || null,
  requested_at: record?.requested_at || null,
  approved_at: record?.approved_at || null,
  starts_at: record?.starts_at || null,
  expires_at: record?.expires_at || null,
  revoked_at: record?.revoked_at || null,
  revoke_reason: record?.revoke_reason || null,
  reviewed_at: record?.reviewed_at || null,
  etag: record?.etag || null,
  version: Number(record?.version || 1),
  reviews: Array.isArray(record?.reviews)
    ? record.reviews.map((review) => ({
        id: resolvePublicIdentifier(review?.human_friendly_id, review?.id),
        reviewer_user_id: resolvePublicIdentifier(review?.reviewer?.human_friendly_id, review?.reviewer_user_id),
        status: review?.status || null,
        notes: review?.notes || null,
        decided_at: review?.decided_at || null,
      }))
    : [],
});

const serializeBreakGlassReview = (record) => ({
  id: resolvePublicIdentifier(record?.human_friendly_id, record?.id),
  human_friendly_id: resolvePublicIdentifier(record?.human_friendly_id, record?.id),
  break_glass_access_id: resolvePublicIdentifier(
    record?.break_glass_access?.human_friendly_id,
    record?.break_glass_access_id
  ),
  tenant_id: resolvePublicIdentifier(record?.tenant?.human_friendly_id, record?.tenant_id),
  reviewer_user_id: resolvePublicIdentifier(record?.reviewer?.human_friendly_id, record?.reviewer_user_id),
  status: record?.status || null,
  notes: record?.notes || null,
  decided_at: record?.decided_at || null,
  version: Number(record?.version || 1),
});

module.exports = {
  serializeAbacPolicy,
  serializeBreakGlassAccess,
  serializeBreakGlassReview,
};
