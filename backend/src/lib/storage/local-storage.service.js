/**
 * Local Storage Service
 *
 * Local file system storage implementation.
 */

const fs = require('fs').promises;
const path = require('path');
const { createWriteStream } = require('fs');
const { StorageService, sanitizeFilename } = require('@lib/storage/storage-service');
const { encryptBuffer, decryptBuffer } = require('@lib/crypto');
const { STORAGE_ENCRYPTION_MAGIC } = require('@config/constants');

/**
 * Local filesystem storage provider.
 */
class LocalStorageService extends StorageService {
  /**
   * @param {string} [basePath='uploads'] - Base directory for file storage
   */
  constructor(basePath = 'uploads') {
    super();
    this.resolvedBasePath = path.resolve(process.cwd(), basePath);
  }

  async ensureDirectory() {
    try {
      await fs.mkdir(this.resolvedBasePath, { recursive: true });
    } catch (err) {
      throw new Error(`Failed to create storage directory: ${err.message}`);
    }
  }

  async upload(file, filename, options = {}) {
    const sanitizedFilename = sanitizeFilename(filename);
    const filePath = path.join(this.resolvedBasePath, sanitizedFilename);

    await this.ensureDirectory();

    try {
      if (Buffer.isBuffer(file)) {
        const toWrite = options.encrypt ? encryptBuffer(file) : file;
        await fs.writeFile(filePath, toWrite);
      } else if (file && typeof file.pipe === 'function') {
        if (options.encrypt) {
          throw new Error('Encryption requires Buffer input');
        }
        const writeStream = createWriteStream(filePath);
        await new Promise((resolve, reject) => {
          file.pipe(writeStream);
          file.on('error', reject);
          writeStream.on('error', reject);
          writeStream.on('finish', resolve);
        });
      } else {
        throw new Error('File must be a Buffer or Stream');
      }

      const stats = await fs.stat(filePath);

      return {
        path: sanitizedFilename,
        fullPath: filePath,
        size: stats.size,
        mimeType: options.mimeType || 'application/octet-stream',
        encrypted: Boolean(options.encrypt),
        uploadedAt: new Date().toISOString()
      };
    } catch (err) {
      throw new Error(`Failed to upload file: ${err.message}`);
    }
  }

  async delete(filePath) {
    const sanitizedPath = sanitizeFilename(filePath);
    const fullPath = path.join(this.resolvedBasePath, sanitizedPath);

    try {
      await fs.unlink(fullPath);
      return true;
    } catch (err) {
      if (err.code === 'ENOENT') {
        return false;
      }
      throw new Error(`Failed to delete file: ${err.message}`);
    }
  }

  async getUrl(filePath) {
    const sanitizedPath = sanitizeFilename(filePath);

    const fileExists = await this.exists(filePath);
    if (!fileExists) {
      throw new Error(`File not found: ${filePath}`);
    }

    return sanitizedPath;
  }

  async exists(filePath) {
    const sanitizedPath = sanitizeFilename(filePath);
    const fullPath = path.join(this.resolvedBasePath, sanitizedPath);

    try {
      await fs.access(fullPath);
      return true;
    } catch {
      return false;
    }
  }

  async getMetadata(filePath) {
    const sanitizedPath = sanitizeFilename(filePath);
    const fullPath = path.join(this.resolvedBasePath, sanitizedPath);

    try {
      const stats = await fs.stat(fullPath);
      return {
        size: stats.size,
        lastModified: stats.mtime.toISOString(),
        created: stats.birthtime.toISOString(),
        isFile: stats.isFile(),
        isDirectory: stats.isDirectory()
      };
    } catch (err) {
      if (err.code === 'ENOENT') {
        throw new Error(`File not found: ${filePath}`);
      }
      throw new Error(`Failed to get file metadata: ${err.message}`);
    }
  }

  async download(filePath) {
    const sanitizedPath = sanitizeFilename(filePath);
    const fullPath = path.join(this.resolvedBasePath, sanitizedPath);

    try {
      const data = await fs.readFile(fullPath);
      const magic = data.length >= 4 ? data.subarray(0, 4).toString('utf8') : null;
      if (magic === String(STORAGE_ENCRYPTION_MAGIC)) {
        return decryptBuffer(data);
      }
      return data;
    } catch (err) {
      if (err.code === 'ENOENT') {
        throw new Error(`File not found: ${filePath}`);
      }
      throw new Error(`Failed to download file: ${err.message}`);
    }
  }
}

/**
 * Backward-compatible local storage factory.
 *
 * @param {string} [basePath='uploads'] - Base directory for file storage
 * @returns {LocalStorageService} Local storage provider instance
 */
const createLocalStorageService = (basePath = 'uploads') => new LocalStorageService(basePath);

module.exports = { LocalStorageService, createLocalStorageService };
