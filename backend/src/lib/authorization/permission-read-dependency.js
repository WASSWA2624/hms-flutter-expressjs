/**
 * Guard: non-read actions require the matching domain `:read` atom when it
 * exists in the canonical catalog (e.g. billing:write ⇒ billing:read).
 *
 * Domains without a catalog `:read` (platform:admin, break_glass:*, …) are
 * exempt — there is nothing to attach.
 */

const { PERMISSIONS } = require('@config/permissions');
const { HttpError } = require('@lib/errors');

const text = (value) => String(value || '').trim();

const CANONICAL_PERMISSION_NAMES = Object.freeze(
  new Set(Object.values(PERMISSIONS).map(text).filter(Boolean))
);

const splitPermissionName = (permissionName) => {
  const name = text(permissionName);
  const separator = name.indexOf(':');
  if (separator <= 0 || separator >= name.length - 1) {
    return { domain: '', action: '', name };
  }
  return {
    domain: name.slice(0, separator),
    action: name.slice(separator + 1),
    name,
  };
};

/**
 * @param {string} permissionName
 * @param {Set<string>|Iterable<string>} [catalogNames=CANONICAL_PERMISSION_NAMES]
 * @returns {string|null} Required `{domain}:read` or null when none applies
 */
const requiredReadPermissionFor = (
  permissionName,
  catalogNames = CANONICAL_PERMISSION_NAMES
) => {
  const { domain, action } = splitPermissionName(permissionName);
  if (!domain || !action || action === 'read') {
    return null;
  }
  const catalog =
    catalogNames instanceof Set ? catalogNames : new Set(catalogNames || []);
  const required = `${domain}:read`;
  // Domains without a catalog `:read` atom (admin, break_glass, …) are exempt.
  if (catalog.size > 0 && !catalog.has(required)) {
    return null;
  }
  return required;
};

/**
 * @param {string[]} permissionNames Names being assigned (or the full sync set)
 * @param {Object} [options]
 * @param {string[]} [options.existingPermissionNames] Already attached grants
 * @param {Set<string>|string[]} [options.catalogNames]
 * @returns {{ permission: string, required_read: string }[]}
 */
const findMissingRequiredReads = (
  permissionNames = [],
  {
    existingPermissionNames = [],
    catalogNames = CANONICAL_PERMISSION_NAMES,
  } = {}
) => {
  const catalog =
    catalogNames instanceof Set ? catalogNames : new Set(catalogNames || []);
  const assigned = [
    ...new Set(
      (Array.isArray(permissionNames) ? permissionNames : [])
        .map(text)
        .filter(Boolean)
    ),
  ];
  const granted = new Set([
    ...assigned,
    ...(Array.isArray(existingPermissionNames) ? existingPermissionNames : [])
      .map(text)
      .filter(Boolean),
  ]);

  const missing = [];
  const seen = new Set();
  for (const name of assigned) {
    const required = requiredReadPermissionFor(name, catalog);
    if (!required || granted.has(required)) {
      continue;
    }
    const key = `${name}|${required}`;
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    missing.push({ permission: name, required_read: required });
  }
  return missing;
};

/**
 * Reject assignment when any non-read action lacks its domain `:read`.
 *
 * @param {string[]} permissionNames
 * @param {Object} [options]
 * @param {string[]} [options.existingPermissionNames]
 * @param {Set<string>|string[]} [options.catalogNames]
 */
const assertPermissionNamesIncludeRequiredReads = (
  permissionNames = [],
  options = {}
) => {
  const missing = findMissingRequiredReads(permissionNames, options);
  if (missing.length === 0) {
    return;
  }
  throw new HttpError('errors.permission.read_required', 400, [
    {
      field: 'permission_ids',
      reason: 'read_permission_required',
      missing,
    },
  ]);
};

/**
 * Expand a permission name list so required `:read` companions are present.
 * Useful for UX auto-attach; authoritative APIs should still assert.
 *
 * @param {string[]} permissionNames
 * @param {Object} [options]
 * @param {Set<string>|string[]} [options.catalogNames]
 * @returns {string[]}
 */
const expandPermissionNamesWithRequiredReads = (
  permissionNames = [],
  { catalogNames = CANONICAL_PERMISSION_NAMES } = {}
) => {
  const catalog =
    catalogNames instanceof Set ? catalogNames : new Set(catalogNames || []);
  const expanded = new Set(
    (Array.isArray(permissionNames) ? permissionNames : [])
      .map(text)
      .filter(Boolean)
  );
  for (const name of [...expanded]) {
    const required = requiredReadPermissionFor(name, catalog);
    if (required) {
      expanded.add(required);
    }
  }
  return [...expanded];
};

module.exports = {
  CANONICAL_PERMISSION_NAMES,
  assertPermissionNamesIncludeRequiredReads,
  expandPermissionNamesWithRequiredReads,
  findMissingRequiredReads,
  requiredReadPermissionFor,
  splitPermissionName,
};
