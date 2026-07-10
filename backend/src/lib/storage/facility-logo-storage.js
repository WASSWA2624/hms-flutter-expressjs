/**
 * Facility logo storage key helpers.
 *
 * Local/S3 storage sanitizes path separators to underscores, so keys look like:
 * `facilities_{tenantId}_{facilityId}_branding_{slug}-logo.png`
 */

const { sanitizeFilename } = require('@lib/storage/storage-service');

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

  // Prefer the final path segment when a nested URL path is provided.
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
 * Resolve the storage key for a facility logo upload.
 * Reuses the existing key when replacing so the filename stays stable.
 *
 * @param {Object} params
 * @param {string} params.facilityId
 * @param {string|null|undefined} params.existingLogoUrl
 * @param {string} params.fallbackKey - Canonical key/path before sanitization
 * @returns {string}
 */
const resolveFacilityLogoUploadKey = ({
  facilityId,
  existingLogoUrl,
  fallbackKey,
}) => {
  const existingKey = extractStorageKeyFromLogoUrl(existingLogoUrl);
  const facilityToken = sanitizeFilename(String(facilityId || ''));
  if (
    existingKey &&
    facilityToken &&
    existingKey.includes(facilityToken)
  ) {
    return existingKey;
  }

  return sanitizeFilename(fallbackKey);
};

/**
 * Best-effort delete of a facility logo from storage.
 *
 * @param {import('@lib/storage/storage-service').StorageService} storage
 * @param {string|null|undefined} logoUrl
 * @returns {Promise<boolean>}
 */
const deleteFacilityLogoFromStorage = async (storage, logoUrl) => {
  const key = extractStorageKeyFromLogoUrl(logoUrl);
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
  extractStorageKeyFromLogoUrl,
  resolveFacilityLogoUploadKey,
  deleteFacilityLogoFromStorage,
};
