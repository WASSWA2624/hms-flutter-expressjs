/**
 * Shipped subscription permission ceilings.
 *
 * Runtime grants are intersected with these action caps after module
 * entitlement filtering. Custom plans may provide extension_json
 * `allowed_permissions`; Developer is unrestricted only outside production.
 */
const FREE = Object.freeze([
  'patient:read',
  'patient:write',
  'patients:read',
  'reports:read',
]);

const BASIC = Object.freeze([
  ...FREE,
  'reception:read',
  'opd:read',
  'clinical:read',
  'clinical:write',
  'emergency:read',
  'emergency:write',
  'pharmacy:read',
  'pharmacy:write',
  'billing:read',
  'billing:write',
  'communications:read',
  'communications:write',
  'subscriptions:read',
  'subscriptions:write',
]);

const ADVANCED = Object.freeze([
  ...BASIC,
  'lab:read',
  'lab:write',
  'radiology:read',
  'radiology:write',
  'reports:write',
  'financial:approve',
  'claims:read',
  'ipd:read',
  'rooms_beds:read',
  'nursing:read',
  'icu:read',
  'discharge:read',
  'physiotherapy:read',
  'theater:read',
]);

const PRO = Object.freeze([
  ...ADVANCED,
  'operations:read',
  'operations:write',
  'housekeeping:read',
  'hr:read',
  'hr:write',
  'unit:read',
  'unit:manage',
  'roster:read',
  'roster:write',
  'roster:publish',
  'roster:approve',
  'biomed:read',
  'biomed:write',
  'mortuary:read',
  'mortuary:write',
  'mortuary:release',
  'mortuary:manage_storage',
  'mortuary:post_mortem_request',
  'mortuary:approve',
  'mortuary:billing_event',
  'mortuary:export',
  'mortuary:audit',
  'integration:read',
  'integration:write',
  'integration:delete',
]);

const PLAN_PERMISSION_CAPS = Object.freeze({
  FREE,
  BASIC,
  ADVANCED,
  PRO,
  CUSTOM: PRO,
  DEVELOPER: PRO,
});

const normalizePermissions = (values = []) =>
  Array.from(
    new Set(
      (Array.isArray(values) ? values : [])
        .map((value) => String(value || '').trim())
        .filter(Boolean)
    )
  );

const resolveSubscriptionPermissionCap = ({
  plan_tier_code,
  allowed_permissions,
  node_env = process.env.NODE_ENV,
} = {}) => {
  const explicit = normalizePermissions(allowed_permissions);
  if (explicit.length > 0) {
    return new Set(explicit);
  }

  const tier = String(plan_tier_code || '').trim().toUpperCase();
  if (!tier) {
    return null;
  }
  if (tier === 'DEVELOPER' && node_env !== 'production') {
    return null;
  }
  if (tier === 'DEVELOPER') {
    return new Set(PLAN_PERMISSION_CAPS.FREE);
  }
  return new Set(PLAN_PERMISSION_CAPS[tier] || []);
};

module.exports = {
  PLAN_PERMISSION_CAPS,
  resolveSubscriptionPermissionCap,
};
