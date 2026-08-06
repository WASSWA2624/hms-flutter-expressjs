/**
 * Temporary ship gate: permission domains withheld from every user and every
 * subscription package until a later release re-enables them.
 *
 * Catalog keys and role packs may still list these domains; effective access
 * and plan caps must strip them. See `.cursor/access/version-disabled-screens.mdc`.
 */
const VERSION_DISABLED_PERMISSION_DOMAINS = Object.freeze([
  'emergency',
  'rooms_beds',
  'physiotherapy',
  'operations',
  'housekeeping',
  'biomed',
  'mortuary',
  'communications',
  'integration',
]);

const DOMAIN_SET = new Set(VERSION_DISABLED_PERMISSION_DOMAINS);

const permissionDomain = (permissionName) => {
  const normalized = String(permissionName || '')
    .trim()
    .toLowerCase();
  if (!normalized) {
    return '';
  }
  const separator = normalized.indexOf(':');
  return separator > 0 ? normalized.slice(0, separator) : normalized;
};

const isVersionDisabledPermission = (permissionName) =>
  DOMAIN_SET.has(permissionDomain(permissionName));

const filterVersionDisabledPermissionNames = (permissionNames = []) =>
  (Array.isArray(permissionNames) ? permissionNames : []).filter(
    (name) => !isVersionDisabledPermission(name)
  );

module.exports = {
  VERSION_DISABLED_PERMISSION_DOMAINS,
  filterVersionDisabledPermissionNames,
  isVersionDisabledPermission,
  permissionDomain,
};
