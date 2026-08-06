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
  // emergency:* and communications:* withheld — version-disabled-screens.
  'pharmacy:read',
  'pharmacy:write',
  'billing:read',
  'billing:write',
  'pricing:pharmacy_read',
  'pricing:pharmacy_write',
  'pricing:facility_read',
  'pricing:facility_write',
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
  // rooms_beds:* and physiotherapy:* withheld — version-disabled-screens.
  'nursing:read',
  'icu:read',
  'discharge:read',
  'theater:read',
]);

const PRO = Object.freeze([
  ...ADVANCED,
  // operations:*, housekeeping:*, biomed:*, mortuary:*, integration:*
  // withheld — version-disabled-screens.
  'hr:read',
  'hr:write',
  'unit:read',
  'unit:manage',
  'roster:read',
  'roster:write',
  'roster:publish',
  'roster:approve',
]);

const PLAN_PERMISSION_CAPS = Object.freeze({
  FREE,
  BASIC,
  ADVANCED,
  PRO,
  CUSTOM: PRO,
  DEVELOPER: PRO,
});

const {
  expandPermissionNamesWithRequiredReads,
} = require('@lib/authorization/permission-read-dependency');
const {
  filterVersionDisabledPermissionNames,
} = require('@config/version-disabled-permissions');

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
  const explicit = filterVersionDisabledPermissionNames(
    normalizePermissions(allowed_permissions)
  );
  if (explicit.length > 0) {
    return new Set(expandPermissionNamesWithRequiredReads(explicit));
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
