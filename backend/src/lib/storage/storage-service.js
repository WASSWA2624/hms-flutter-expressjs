/**
 * Storage Service Base
 *
 * Abstract interface for storage providers per storage.mdc.
 * All storage operations must go through StorageService.
 */

/**
 * Sanitize filename to prevent path traversal.
 *
 * @param {string} filename - Original filename
 * @returns {string} Sanitized filename
 */
const sanitizeFilename = (filename) => {
  if (!filename || typeof filename !== 'string') {
    throw new Error('Filename must be a non-empty string');
  }

  let sanitized = filename
    .replace(/\.\./g, '')
    .replace(/[\/\\]/g, '_')
    .replace(/[^a-zA-Z0-9._-]/g, '_')
    .trim();

  if (!sanitized) {
    sanitized = `file_${Date.now()}`;
  }

  if (sanitized.length > 255) {
    const ext = sanitized.substring(sanitized.lastIndexOf('.'));
    sanitized = sanitized.substring(0, 255 - ext.length) + ext;
  }

  return sanitized;
};

class StorageService {
  /**
   * Upload file to configured storage provider.
   *
   * @returns {Promise<Object>} Upload result metadata
   * @throws {Error} Always; must be implemented by provider
   */
  async upload() {
    throw new Error('upload() method must be implemented by storage provider');
  }

  /**
   * Delete file from storage provider.
   *
   * @returns {Promise<boolean>} True if deleted
   * @throws {Error} Always; must be implemented by provider
   */
  async delete() {
    throw new Error('delete() method must be implemented by storage provider');
  }

  /**
   * Resolve addressable URL/path for stored file.
   *
   * @returns {Promise<string>} URL or relative path
   * @throws {Error} Always; must be implemented by provider
   */
  async getUrl() {
    throw new Error('getUrl() method must be implemented by storage provider');
  }

  /**
   * Check whether a stored file exists.
   *
   * @returns {Promise<boolean>} Existence flag
   * @throws {Error} Always; must be implemented by provider
   */
  async exists() {
    throw new Error('exists() method must be implemented by storage provider');
  }

  /**
   * Get file metadata from storage provider.
   *
   * @returns {Promise<Object>} Metadata
   * @throws {Error} Always; must be implemented by provider
   */
  async getMetadata() {
    throw new Error('getMetadata() method must be implemented by storage provider');
  }

  /**
   * Download file bytes from storage provider.
   *
   * @returns {Promise<Buffer>} File payload
   * @throws {Error} Always; must be implemented by provider
   */
  async download() {
    throw new Error('download() method must be implemented by storage provider');
  }

  /**
   * Utility wrapper exposed on provider instances for path sanitization.
   *
   * @param {string} filename - Original filename
   * @returns {string} Sanitized filename
   */
  sanitizeFilename(filename) {
    return sanitizeFilename(filename);
  }
}

// Backward-compatible factory for existing call sites/tests.
const createStorageServiceBase = () => new StorageService();

module.exports = {
  StorageService,
  createStorageServiceBase,
  sanitizeFilename
};
