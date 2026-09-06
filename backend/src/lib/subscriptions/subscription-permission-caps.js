/**
 * Shipped subscription permission ceilings.
 *
 * Runtime grants are intersected with these action caps after module
 * entitlement filtering. Custom plans may provide extension_json
 * `allowed_permissions`; Developer is unrestricted only outside production.
 *
 * Two invariants keep this file consistent with the rest of access control:
 *
 * 1. Caps only bite on module-scoped permissions (see permission-module-map).
 *    Listing a core/platform key here is inert — do not add one.
 * 2. A key's tier must be >= its module's `minimum_plan_tier_code` in
 *    plan-module-matrix.js, otherwise the cap admits a permission whose module
 *    the plan does not entitle and the workspace stays unreachable anyway.
 *
 * Both are asserted in src/tests/lib/subscriptions/subscription-permission-caps.test.js.
 */
const FREE = Object.freeze([
  'patient:read',
  'patient:write',
  // patient:delete is deliberately withheld here: FREE (and production
  // DEVELOPER, which resolves to FREE) must not admit destructive patient
  // actions. It enters at BASIC, the first tier with tenant/facility admins.
  'patients:read',
  'reports:read',
]);

const BASIC = Object.freeze([
  ...FREE,
  'patient:delete',
  'reception:read',
  'opd:read',
  'clinical:read',
  'clinical:write',
  // emergency:* and communications:* withheld — version-disabled-screens.
  'pharmacy:read',
  'pharmacy:write',
  'billing:read',
  'billing:write',
  'accounts:read',
  'accounts:write',
  // pricing:* is intentionally absent — it is a cross-module rights-layer
  // permission with no module mapping, so a cap entry for it would be inert.
  'subscriptions:read',
  'subscriptions:write',
  'subscriptions:delete',
]);

const ADVANCED = Object.freeze([
  ...BASIC,
  'lab:read',
  'lab:write',
  'radiology:read',
  'radiology:write',
  'reports:write',
  'reports:delete',
  'financial:approve',
  'claims:read',
  // inpatient-bed-management is entitled from BASIC, but the IPD / nursing /
  // discharge workspaces open at ADVANCED — the cap is the binding gate.
  'ipd:read',
  // rooms_beds:* and physiotherapy:* withheld — version-disabled-screens.
  'nursing:read',
  'discharge:read',
]);

const PRO = Object.freeze([
  ...ADVANCED,
  // operations:*, housekeeping:*, biomed:*, mortuary:*, integration:*
  // withheld — version-disabled-screens.
  // icu-critical-care and theatre-anesthesia are PRO modules in
  // plan-module-matrix.js; their entry keys must not sit in a lower cap.
  'icu:read',
  'theater:read',
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
