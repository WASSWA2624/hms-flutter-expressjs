/**
 * Maps permission domain prefixes to subscription module slugs.
 *
 * Authority order: Plan (module) → Role (scope) → Rights (permission).
 * Permissions without a module mapping are core/platform and are not plan-gated
 * at the permission-assignment layer.
 */
const {
  resolveSubscriptionPermissionCap,
} = require('@lib/subscriptions/subscription-permission-caps');

const DOMAIN_TO_MODULE = Object.freeze({
  patient: 'patient-registry',
  patients: 'patient-registry',
  reception: 'scheduling-queue',
  opd: 'scheduling-queue',
  emergency: 'scheduling-queue',
  ipd: 'inpatient-bed-management',
  rooms_beds: 'inpatient-bed-management',
  nursing: 'inpatient-bed-management',
  discharge: 'inpatient-bed-management',
  icu: 'icu-critical-care',
  clinical: 'encounters-vitals',
  physiotherapy: 'physiotherapy',
  theater: 'theatre-anesthesia',
  lab: 'lab-workflows',
  radiology: 'radiology-workflows',
  pharmacy: 'pharmacy-dispensing',
  billing: 'billing-payments',
  financial: 'billing-payments',
  claims: 'insurance-claims',
  operations: 'facilities-maintenance',
  housekeeping: 'facilities-maintenance',
  hr: 'hr-rosters',
  unit: 'hr-rosters',
  roster: 'hr-rosters',
  biomed: 'biomedical-engineering-suite',
  mortuary: 'mortuary',
  communications: 'notifications-communications',
  integration: 'integrations-core',
  reports: 'reporting-analytics',
  subscriptions: 'subscription-controls',
});

const text = (value) => String(value || '').trim();

const normalizeModuleCode = (value) =>
  text(value)
    .toLowerCase()
    .replace(/[\s_]+/g, '-');

/**
 * @param {string} permissionName
 * @returns {string|null}
 */
const moduleForPermissionName = (permissionName) => {
  const normalized = text(permissionName).toLowerCase();
  if (!normalized) {
    return null;
  }
  const separator = normalized.indexOf(':');
  const domain = separator > 0 ? normalized.slice(0, separator) : normalized;
  return DOMAIN_TO_MODULE[domain] || null;
};

/**
 * @param {string} permissionName
 * @returns {boolean}
 */
const isModuleScopedPermission = (permissionName) =>
  moduleForPermissionName(permissionName) != null;

/**
 * @param {Iterable<string|Object>} entitlements
 * @returns {Set<string>} Normalized module slugs that are available
 */
const normalizeEnabledModuleSet = (entitlements = []) => {
  const enabled = new Set();
  const entries = Array.isArray(entitlements)
    ? entitlements
    : entitlements instanceof Set
      ? [...entitlements]
      : [];

  for (const entry of entries) {
    if (entry == null) {
      continue;
    }
    if (typeof entry === 'string') {
      const code = normalizeModuleCode(entry);
      if (code) {
        enabled.add(code);
      }
      continue;
    }

    const denied =
      entry.entitlement_denied === true || entry.entitlementDenied === true;
    const inactive =
      entry.is_active === false ||
      entry.isActive === false ||
      entry.enabled === false;
    if (denied || inactive) {
      continue;
    }

    const raw =
      entry.module_slug ||
      entry.moduleSlug ||
      entry.code ||
      entry.module_code ||
      entry.moduleCode ||
      entry.slug ||
      entry.module?.slug ||
      entry.module?.code;
    const code = normalizeModuleCode(raw);
    if (code) {
      enabled.add(code);
    }
  }

  return enabled;
};

/**
 * Keep permissions that are either core/platform or mapped to an enabled module.
 * When [enabledModules] is null/undefined, no plan filter is applied.
 *
 * @param {Array<Object>} permissions
 * @param {Set<string>|null|undefined} enabledModules
 * @returns {Array<Object>}
 */
const filterPermissionRecordsByPlanModules = (
  permissions = [],
  enabledModules = null
) => {
  if (enabledModules == null) {
    return permissions;
  }

  return permissions.filter((entry) => {
    const name = entry?.name || entry?.label || '';
    const moduleSlug = moduleForPermissionName(name);
    if (!moduleSlug) {
      return true;
    }
    return (
      enabledModules.has(moduleSlug) ||
      enabledModules.has(normalizeModuleCode(moduleSlug))
    );
  });
};

/**
 * Keep permission name strings that are either core/platform or mapped to an
 * enabled plan module. When [enabledModules] is null/undefined, no plan filter
 * is applied.
 *
 * @param {Array<string>} permissionNames
 * @param {Set<string>|null|undefined} enabledModules
 * @returns {Array<string>}
 */
const filterPermissionNamesByPlanModules = (
  permissionNames = [],
  enabledModules = null
) => {
  if (enabledModules == null) {
    return permissionNames;
  }

  return permissionNames.filter((name) =>
    isPermissionAllowedByPlan(name, enabledModules)
  );
};

const filterPermissionNamesBySubscriptionPermissions = (
  permissionNames = [],
  entitlements = []
) => {
  const entries = Array.isArray(entitlements) ? entitlements : [];
  const planTierCode = entries
    .map((entry) => entry?.plan_tier_code || entry?.planTierCode)
    .find(Boolean);
  const allowedPermissions = entries.flatMap((entry) =>
    Array.isArray(entry?.allowed_permissions)
      ? entry.allowed_permissions
      : Array.isArray(entry?.allowedPermissions)
        ? entry.allowedPermissions
        : []
  );
  const cap = resolveSubscriptionPermissionCap({
    plan_tier_code: planTierCode,
    allowed_permissions: allowedPermissions,
  });
  if (cap == null) {
    return permissionNames;
  }

  return permissionNames.filter(
    (name) => !isModuleScopedPermission(name) || cap.has(String(name || '').trim())
  );
};

/**
 * @param {string} permissionName
 * @param {Set<string>|null|undefined} enabledModules
 * @returns {boolean}
 */
const isPermissionAllowedByPlan = (permissionName, enabledModules = null) => {
  if (enabledModules == null) {
    return true;
  }
  const moduleSlug = moduleForPermissionName(permissionName);
  if (!moduleSlug) {
    return true;
  }
  return (
    enabledModules.has(moduleSlug) ||
    enabledModules.has(normalizeModuleCode(moduleSlug))
  );
};

module.exports = {
  DOMAIN_TO_MODULE,
  filterPermissionNamesByPlanModules,
  filterPermissionNamesBySubscriptionPermissions,
  filterPermissionRecordsByPlanModules,
  isModuleScopedPermission,
  isPermissionAllowedByPlan,
  moduleForPermissionName,
  normalizeEnabledModuleSet,
  normalizeModuleCode,
};
