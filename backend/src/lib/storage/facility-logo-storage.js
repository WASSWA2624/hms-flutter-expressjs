/**
 * Facility logo storage key helpers.
 *
 * Leaf filenames stay short (≤ 32 chars). Local storage flattens path
 * separators, so the stable key is the entire storage object name.
 */

const { sanitizeFilename } = require('@lib/storage/storage-service');

const MAX_FACILITY_LOGO_BASENAME = 32;

/**
 * Stable short logo key for a facility: `logo-{id8}.png` (≤ 32 chars).
 *
 * @param {string} facilityId
 * @returns {string}
 */
const buildStableFacilityLogoKey = (facilityId) => {
  const compact = String(facilityId || '')
    .replace(/[^a-zA-Z0-9]/g, '')
    .toLowerCase();
  const suffix = (compact.slice(-8) || 'facility').slice(0, 8);
  const key = `logo-${suffix}.png`;
  return sanitizeFilename(key).slice(0, MAX_FACILITY_LOGO_BASENAME);
};

/**
 * Extract a storage key from a stored logo_url (relative path or absolute URL).
 *
 * @param {string|null|undefined} logoUrl
 * @returns {string|null}
 */
const extractStorageKeyFromLogoUrl = (logoUrl) => {
  if (!logoUrl || typeof logoUrl !== 'string') {
    return null;
  }

  let value = logoUrl.trim();
  if (!value) {
    return null;
  }

  value = value.split('?')[0].split('#')[0].trim();
  if (!value) {
    return null;
  }

  try {
    if (/^https?:\/\//i.test(value)) {
      value = new URL(value).pathname || '';
    }
  } catch {
    // Keep the original value when URL parsing fails.
  }

  value = value.replace(/^\/+/, '');
  value = value.replace(/^uploads\//i, '');
  if (!value) {
    return null;
  }

  const slashIndex = Math.max(value.lastIndexOf('/'), value.lastIndexOf('\\'));
  if (slashIndex >= 0) {
    value = value.slice(slashIndex + 1);
  }

  try {
    return sanitizeFilename(value);
  } catch {
    return null;
  }
};

/**
 * Resolve upload key + optional previous key to delete after overwrite migration.
 *
 * Always targets the stable short key for the facility. If an older long key
 * exists, it is returned as `previousKey` so callers can delete it after upload.
 *
 * @param {Object} params
 * @param {string} params.facilityId
 * @param {string|null|undefined} params.existingLogoUrl
 * @returns {{ storageKey: string, previousKey: string|null }}
 */
const resolveFacilityLogoUploadKey = ({ facilityId, existingLogoUrl }) => {
  const storageKey = buildStableFacilityLogoKey(facilityId);
  const existingKey = extractStorageKeyFromLogoUrl(existingLogoUrl);
  const previousKey =
    existingKey && existingKey !== storageKey ? existingKey : null;
  return { storageKey, previousKey };
};

/**
 * Build a browser-loadable logo URL path for a storage key.
 * Relative form: `/uploads/{key}` (optionally with cache-buster query).
 *
 * @param {string} storageKey
 * @param {{ cacheBust?: boolean|number|string }} [options]
 * @returns {string}
 */
const buildFacilityLogoPublicPath = (storageKey, options = {}) => {
  const key = sanitizeFilename(storageKey);
  const base = `/uploads/${key}`;
  if (options.cacheBust === false) {
    return base;
  }
  const version =
    options.cacheBust === true || options.cacheBust == null
      ? Date.now()
      : options.cacheBust;
  return `${base}?v=${version}`;
};

/**
 * Best-effort delete of a facility logo from storage.
 *
 * @param {{ delete: (key: string) => Promise<boolean> }} storage
 * @param {string|null|undefined} logoUrlOrKey
 * @returns {Promise<boolean>}
 */
const deleteFacilityLogoFromStorage = async (storage, logoUrlOrKey) => {
  const key = extractStorageKeyFromLogoUrl(logoUrlOrKey) ||
    (typeof logoUrlOrKey === 'string' && !logoUrlOrKey.includes('/')
      ? (() => {
          try {
            return sanitizeFilename(logoUrlOrKey.trim());
          } catch {
            return null;
          }
        })()
      : null);
  if (!key || !storage || typeof storage.delete !== 'function') {
    return false;
  }

  try {
    return Boolean(await storage.delete(key));
  } catch {
    return false;
  }
};

module.exports = {
  MAX_FACILITY_LOGO_BASENAME,
  buildStableFacilityLogoKey,
  extractStorageKeyFromLogoUrl,
  resolveFacilityLogoUploadKey,
  buildFacilityLogoPublicPath,
  deleteFacilityLogoFromStorage,
};
