/**
 * Storage Service Factory
 * 
 * Factory function to select storage provider based on environment configuration
 * Per storage.mdc: Switching providers must be possible by changing environment configuration only
 * Reads STORAGE_PROVIDER from @config/env
 */

const { STORAGE_PROVIDER, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, AWS_S3_BUCKET } = require('@config/env');
const { LOCAL_STORAGE_DIR } = require('@config/constants');

const getStorageProviders = () => {
  return require('@lib/storage');
};

/**
 * Create and return appropriate storage service instance
 * 
 * @returns {StorageService} Storage service instance
 */
const createStorageService = () => {
  const { createLocalStorageService, createS3StorageService } = getStorageProviders();

  switch (STORAGE_PROVIDER) {
    case 'local':
      return createLocalStorageService(LOCAL_STORAGE_DIR);
    
    case 's3':
      if (!AWS_ACCESS_KEY_ID || !AWS_SECRET_ACCESS_KEY || !AWS_REGION || !AWS_S3_BUCKET) {
        throw new Error(
          'AWS credentials are required when STORAGE_PROVIDER is "s3". ' +
          'Please set AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, and AWS_S3_BUCKET in your .env file.'
        );
      }
      
      return createS3StorageService({
        accessKeyId: AWS_ACCESS_KEY_ID,
        secretAccessKey: AWS_SECRET_ACCESS_KEY,
        region: AWS_REGION,
        bucket: AWS_S3_BUCKET
      });
    
    default:
      throw new Error(
        `Unsupported storage provider: ${STORAGE_PROVIDER}. ` +
        `Supported providers: 'local', 's3'`
      );
  }
};

module.exports = { createStorageService };

