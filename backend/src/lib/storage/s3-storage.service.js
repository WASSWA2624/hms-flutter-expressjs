/**
 * S3 Storage Service
 *
 * AWS S3 storage implementation.
 */

const { StorageService, sanitizeFilename } = require('@lib/storage/storage-service');
const { encryptBuffer, decryptBuffer } = require('@lib/crypto');
const { STORAGE_ENCRYPTION_MAGIC } = require('@config/constants');

/**
 * AWS S3 storage provider.
 */
class S3StorageService extends StorageService {
  /**
   * @param {Object} config - S3 configuration
   */
  constructor(config) {
    super();

    if (!config?.accessKeyId || !config?.secretAccessKey || !config?.region || !config?.bucket) {
      throw new Error('S3 configuration requires accessKeyId, secretAccessKey, region, and bucket');
    }

    this.config = config;
    this.s3Client = null;
    this.PutObjectCommand = null;
    this.DeleteObjectCommand = null;
    this.GetObjectCommand = null;
    this.HeadObjectCommand = null;

    this.initializeClient();
  }

  initializeClient() {
    try {
      const {
        S3Client,
        PutObjectCommand: Put,
        DeleteObjectCommand: Delete,
        GetObjectCommand: Get,
        HeadObjectCommand: Head
      } = require('@aws-sdk/client-s3');

      this.s3Client = new S3Client({
        region: this.config.region,
        credentials: {
          accessKeyId: this.config.accessKeyId,
          secretAccessKey: this.config.secretAccessKey
        }
      });

      this.PutObjectCommand = Put;
      this.DeleteObjectCommand = Delete;
      this.GetObjectCommand = Get;
      this.HeadObjectCommand = Head;
    } catch (err) {
      throw new Error(
        'AWS SDK not installed. Please install @aws-sdk/client-s3: npm install @aws-sdk/client-s3'
      );
    }
  }

  async upload(file, filename, options = {}) {
    if (!this.s3Client) {
      throw new Error('S3 client not initialized');
    }

    const sanitizedKey = sanitizeFilename(filename);

    try {
      let fileBuffer = file;
      if (file && typeof file.pipe === 'function') {
        const chunks = [];
        for await (const chunk of file) {
          chunks.push(chunk);
        }
        fileBuffer = Buffer.concat(chunks);
      }

      if (!Buffer.isBuffer(fileBuffer)) {
        throw new Error('File must be a Buffer or Stream');
      }

      const toUpload = options.encrypt ? encryptBuffer(fileBuffer) : fileBuffer;

      const command = new this.PutObjectCommand({
        Bucket: this.config.bucket,
        Key: sanitizedKey,
        Body: toUpload,
        ContentType: options.mimeType || 'application/octet-stream',
        Metadata: {
          ...(options.metadata || {}),
          ...(options.encrypt ? { encrypted: '1', enc: 'aes-256-gcm' } : {})
        }
      });

      await this.s3Client.send(command);
      const url = await this.getUrl(sanitizedKey);

      return {
        path: sanitizedKey,
        url,
        size: toUpload.length,
        mimeType: options.mimeType || 'application/octet-stream',
        encrypted: Boolean(options.encrypt),
        uploadedAt: new Date().toISOString()
      };
    } catch (err) {
      throw new Error(`Failed to upload file to S3: ${err.message}`);
    }
  }

  async delete(filePath) {
    if (!this.s3Client) {
      throw new Error('S3 client not initialized');
    }

    const sanitizedKey = sanitizeFilename(filePath);

    try {
      const command = new this.DeleteObjectCommand({
        Bucket: this.config.bucket,
        Key: sanitizedKey
      });

      await this.s3Client.send(command);
      return true;
    } catch (err) {
      throw new Error(`Failed to delete file from S3: ${err.message}`);
    }
  }

  async getUrl(filePath) {
    if (!this.s3Client) {
      throw new Error('S3 client not initialized');
    }

    const sanitizedKey = sanitizeFilename(filePath);

    const fileExists = await this.exists(filePath);
    if (!fileExists) {
      throw new Error(`File not found: ${filePath}`);
    }

    return `https://${this.config.bucket}.s3.${this.config.region}.amazonaws.com/${sanitizedKey}`;
  }

  async exists(filePath) {
    if (!this.s3Client) {
      throw new Error('S3 client not initialized');
    }

    const sanitizedKey = sanitizeFilename(filePath);

    try {
      const command = new this.HeadObjectCommand({
        Bucket: this.config.bucket,
        Key: sanitizedKey
      });

      await this.s3Client.send(command);
      return true;
    } catch (err) {
      if (err.name === 'NotFound' || err.$metadata?.httpStatusCode === 404) {
        return false;
      }
      throw new Error(`Failed to check file existence: ${err.message}`);
    }
  }

  async getMetadata(filePath) {
    if (!this.s3Client) {
      throw new Error('S3 client not initialized');
    }

    const sanitizedKey = sanitizeFilename(filePath);

    try {
      const command = new this.HeadObjectCommand({
        Bucket: this.config.bucket,
        Key: sanitizedKey
      });

      const response = await this.s3Client.send(command);

      return {
        size: response.ContentLength,
        mimeType: response.ContentType,
        lastModified: response.LastModified?.toISOString(),
        etag: response.ETag,
        metadata: response.Metadata || {}
      };
    } catch (err) {
      if (err.name === 'NotFound' || err.$metadata?.httpStatusCode === 404) {
        throw new Error(`File not found: ${filePath}`);
      }
      throw new Error(`Failed to get file metadata: ${err.message}`);
    }
  }

  async download(filePath) {
    if (!this.s3Client) {
      throw new Error('S3 client not initialized');
    }

    const sanitizedKey = sanitizeFilename(filePath);

    try {
      const command = new this.GetObjectCommand({
        Bucket: this.config.bucket,
        Key: sanitizedKey
      });

      const response = await this.s3Client.send(command);

      const chunks = [];
      for await (const chunk of response.Body) {
        chunks.push(chunk);
      }
      const data = Buffer.concat(chunks);
      const magic = data.length >= 4 ? data.subarray(0, 4).toString('utf8') : null;
      if (magic === String(STORAGE_ENCRYPTION_MAGIC)) {
        return decryptBuffer(data);
      }
      return data;
    } catch (err) {
      if (err.name === 'NoSuchKey' || err.$metadata?.httpStatusCode === 404) {
        throw new Error(`File not found: ${filePath}`);
      }
      throw new Error(`Failed to download file: ${err.message}`);
    }
  }
}

/**
 * Backward-compatible S3 storage factory.
 *
 * @param {Object} config - S3 configuration
 * @returns {S3StorageService} S3 storage provider instance
 */
const createS3StorageService = (config) => new S3StorageService(config);

module.exports = { S3StorageService, createS3StorageService };
