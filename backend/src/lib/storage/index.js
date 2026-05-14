/**
 * Storage Module Barrel Export
 * 
 * Centralized exports for storage module
 * Per storage.mdc: Exports StorageService, factory, providers
 */

const { StorageService, createStorageServiceBase, sanitizeFilename } = require('@lib/storage/storage-service');
const { LocalStorageService, createLocalStorageService } = require('@lib/storage/local-storage.service');
const { S3StorageService, createS3StorageService } = require('@lib/storage/s3-storage.service');
const { createStorageService } = require('@lib/storage/factory');

module.exports = {
  StorageService,
  LocalStorageService,
  S3StorageService,
  createStorageService,
  createStorageServiceBase,
  createLocalStorageService,
  createS3StorageService,
  sanitizeFilename
};

