/**
 * Environment Configuration
 *
 * This is the ONLY file allowed to read process.env directly (per constants-env.mdc)
 * All other files must import environment variables from this module via @config/env
 *
 * Validates required environment variables on application boot
 * Throws errors if required variables are missing or invalid
 */

// Load .env once here (no other file should read process.env)
const path = require('path');
require('dotenv').config({
  path: path.resolve(__dirname, '../../.env'),
  // Dotenv's runtime tips are useful for local manual runs, but they add heavy
  // noise/overhead during automated test runs.
  quiet: process.env.NODE_ENV === 'test' || process.env.DOTENV_QUIET === 'true'
});

/**
 * Required environment variables
 * These must be present for the application to start
 */
const REQUIRED_VARS = [
  'DATABASE_URL',
  'JWT_SECRET',
  'CORS_ORIGINS',
  'NODE_ENV'
];

/**
 * Validate that a required environment variable exists
 */
const validateRequired = (varName) => {
  const value = process.env[varName];
  if (!value || value.trim() === '') {
    throw new Error(
      `Missing required environment variable: ${varName}. ` +
      `Please check your .env file or environment configuration.`
    );
  }
  return value;
};

/**
 * Validate JWT_SECRET meets minimum length requirement (≥ 32 characters)
 */
const validateJwtSecret = (secret) => {
  if (secret.length < 32) {
    throw new Error(
      `JWT_SECRET must be at least 32 characters long for security. ` +
      `Current length: ${secret.length}. Please update your .env file.`
    );
  }
};

/**
 * Validate NODE_ENV is a valid value
 */
const validateNodeEnv = (env) => {
  const validEnvs = ['development', 'staging', 'production', 'test'];
  if (!validEnvs.includes(env)) {
    throw new Error(
      `Invalid NODE_ENV: ${env}. Must be one of: ${validEnvs.join(', ')}`
    );
  }
};

/**
 * Validate STORAGE_PROVIDER is valid
 */
const validateStorageProvider = (provider) => {
  if (provider && !['local', 's3'].includes(provider)) {
    throw new Error(
      `Invalid STORAGE_PROVIDER: ${provider}. Must be 'local' or 's3'`
    );
  }
};

const validatePacsAuthMode = (mode) => {
  if (!mode) return;
  if (!['none', 'basic', 'bearer'].includes(mode)) {
    throw new Error(
      `Invalid PACS_AUTH_MODE: ${mode}. Must be "none", "basic", or "bearer".`
    );
  }
};

/**
 * Parse comma-separated CORS_ORIGINS into array
 */
const parseCorsOrigins = (origins) => {
  if (!origins) return [];
  return origins.split(',').map((origin) => origin.trim()).filter(Boolean);
};

/**
 * Parse optional boolean env values
 */
const parseOptionalBoolean = (value, defaultValue) => {
  if (value === undefined || value === null || value === '') {
    return defaultValue;
  }

  const normalized = String(value).trim().toLowerCase();
  if (normalized === 'true') return true;
  if (normalized === 'false') return false;

  throw new Error(`Invalid boolean value: ${value}. Use "true" or "false".`);
};

/**
 * Parse Express trust proxy configuration from env.
 *
 * Supports:
 * - "true" / "false"
 * - non-negative integer hop counts like "1"
 */
const parseTrustProxy = (value, defaultValue) => {
  if (value === undefined || value === null || value === '') {
    return defaultValue;
  }

  const normalized = String(value).trim().toLowerCase();
  if (normalized === 'true') return true;
  if (normalized === 'false') return false;

  if (/^\d+$/.test(normalized)) {
    return parseInt(normalized, 10);
  }

  throw new Error(
    `Invalid TRUST_PROXY value: ${value}. Use "true", "false", or a non-negative integer.`
  );
};

const parseBoundedInteger = (value, defaultValue, varName, { min = 1, max = Number.MAX_SAFE_INTEGER } = {}) => {
  if (value === undefined || value === null || value === '') {
    return defaultValue;
  }

  const parsed = parseInt(String(value).trim(), 10);
  if (Number.isNaN(parsed) || parsed < min || parsed > max) {
    throw new Error(`${varName} must be an integer between ${min} and ${max}.`);
  }

  return parsed;
};

/**
 * Build validated environment config
 */
const buildEnv = () => {
  const DATABASE_URL = validateRequired('DATABASE_URL');
  const JWT_SECRET = validateRequired('JWT_SECRET');
  const CORS_ORIGINS_RAW = validateRequired('CORS_ORIGINS');
  const NODE_ENV = validateRequired('NODE_ENV');

  validateJwtSecret(JWT_SECRET);
  validateNodeEnv(NODE_ENV);

  const CORS_ORIGINS = parseCorsOrigins(CORS_ORIGINS_RAW);

  const rawPort = process.env.PORT;
  const PORT = rawPort ? parseInt(rawPort, 10) : 3000;
  const HOST = process.env.HOST || '0.0.0.0';
  const TRUST_PROXY = parseTrustProxy(process.env.TRUST_PROXY, false);
  const STORAGE_PROVIDER = process.env.STORAGE_PROVIDER || 'local';
  const ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || null;
  const CSRF_SECRET = process.env.CSRF_SECRET || null;
  const APP_PUBLIC_URL = process.env.APP_PUBLIC_URL || 'http://localhost:8081';
  const APP_DISPLAY_NAME =
    String(process.env.APP_DISPLAY_NAME || 'Hospital Management System').trim() ||
    'Hospital Management System';
  const APP_SHORT_NAME = String(process.env.APP_SHORT_NAME || 'HMS').trim() || 'HMS';
  const JWT_ACCESS_TOKEN_EXPIRATION =
    String(process.env.JWT_ACCESS_TOKEN_EXPIRATION || '15m').trim() || '15m';
  const JWT_REFRESH_TOKEN_EXPIRATION =
    String(process.env.JWT_REFRESH_TOKEN_EXPIRATION || '7d').trim() || '7d';
  const AUTH_SESSION_TTL_DAYS = parseBoundedInteger(
    process.env.AUTH_SESSION_TTL_DAYS,
    7,
    'AUTH_SESSION_TTL_DAYS',
    { min: 1, max: 90 }
  );
  const SMTP_HOST = process.env.SMTP_HOST || null;
  const SMTP_PORT = process.env.SMTP_PORT ? parseInt(process.env.SMTP_PORT, 10) : null;
  const SMTP_USER = process.env.SMTP_USER || null;
  const SMTP_PASS = process.env.SMTP_PASS || null;
  const SMTP_FROM = process.env.SMTP_FROM || null;
  const SMTP_FROM_NAME = process.env.SMTP_FROM_NAME || APP_DISPLAY_NAME;
  const SMTP_REPLY_TO = process.env.SMTP_REPLY_TO || null;
  const SMTP_NO_REPLY_ADDRESS = process.env.SMTP_NO_REPLY_ADDRESS || null;
  const ALLOW_PLAINTEXT_PASSWORD_EMAIL = parseOptionalBoolean(
    process.env.ALLOW_PLAINTEXT_PASSWORD_EMAIL,
    false
  );
  const HANDLE_SIGINT = parseOptionalBoolean(
    process.env.HANDLE_SIGINT,
    true
  );
  const ALLOW_PRIVATE_NETWORK_ORIGINS = parseOptionalBoolean(
    process.env.ALLOW_PRIVATE_NETWORK_ORIGINS,
    NODE_ENV === 'development'
  );
  const WS_MAX_CONNECTIONS = process.env.WS_MAX_CONNECTIONS ? parseInt(process.env.WS_MAX_CONNECTIONS, 10) : 1000;
  const WS_HEARTBEAT_INTERVAL = process.env.WS_HEARTBEAT_INTERVAL ? parseInt(process.env.WS_HEARTBEAT_INTERVAL, 10) : 30000;
  const WS_HEARTBEAT_TIMEOUT = process.env.WS_HEARTBEAT_TIMEOUT ? parseInt(process.env.WS_HEARTBEAT_TIMEOUT, 10) : 60000;
  const PRISMA_POOL_CONNECTION_LIMIT = process.env.PRISMA_POOL_CONNECTION_LIMIT
    ? parseInt(process.env.PRISMA_POOL_CONNECTION_LIMIT, 10)
    : 10;
  const PRISMA_POOL_CONNECT_TIMEOUT_MS = process.env.PRISMA_POOL_CONNECT_TIMEOUT_MS
    ? parseInt(process.env.PRISMA_POOL_CONNECT_TIMEOUT_MS, 10)
    : 5000;
  const PRISMA_POOL_ACQUIRE_TIMEOUT_MS = process.env.PRISMA_POOL_ACQUIRE_TIMEOUT_MS
    ? parseInt(process.env.PRISMA_POOL_ACQUIRE_TIMEOUT_MS, 10)
    : 5000;
  const PRISMA_MYSQL_ALLOW_PUBLIC_KEY_RETRIEVAL = parseOptionalBoolean(
    process.env.PRISMA_MYSQL_ALLOW_PUBLIC_KEY_RETRIEVAL,
    NODE_ENV === 'development'
  );
  const SEED_RECORD_COUNT = process.env.SEED_RECORD_COUNT
    ? parseInt(process.env.SEED_RECORD_COUNT, 10)
    : 50;
  const SEED_RANDOM_SEED = process.env.SEED_RANDOM_SEED
    ? parseInt(process.env.SEED_RANDOM_SEED, 10)
    : 20260217;
  const PACS_DICOMWEB_BASE_URL = process.env.PACS_DICOMWEB_BASE_URL || null;
  const PACS_AUTH_MODE = String(process.env.PACS_AUTH_MODE || 'none').trim().toLowerCase();
  const PACS_USERNAME = process.env.PACS_USERNAME || null;
  const PACS_PASSWORD = process.env.PACS_PASSWORD || null;
  const PACS_BEARER_TOKEN = process.env.PACS_BEARER_TOKEN || null;
  const PACS_TIMEOUT_MS = process.env.PACS_TIMEOUT_MS
    ? parseInt(process.env.PACS_TIMEOUT_MS, 10)
    : 10000;
  const OTEL_ENABLED = parseOptionalBoolean(
    process.env.OTEL_ENABLED,
    false
  );
  const OTEL_SERVICE_NAME =
    String(process.env.OTEL_SERVICE_NAME || 'hms-backend').trim() || 'hms-backend';
  const OTEL_EXPORTER_OTLP_ENDPOINT = process.env.OTEL_EXPORTER_OTLP_ENDPOINT || null;
  const OTEL_METRIC_EXPORT_INTERVAL_MS = process.env.OTEL_METRIC_EXPORT_INTERVAL_MS
    ? parseInt(process.env.OTEL_METRIC_EXPORT_INTERVAL_MS, 10)
    : 60000;
  const PHARMACY_WORKSPACE_V1 = parseOptionalBoolean(
    process.env.PHARMACY_WORKSPACE_V1,
    false
  );
  const RADIOLOGY_ATTESTATION_V2 = parseOptionalBoolean(
    process.env.RADIOLOGY_ATTESTATION_V2,
    false
  );

  if (process.env.STORAGE_PROVIDER) {
    validateStorageProvider(STORAGE_PROVIDER);
  }
  validatePacsAuthMode(PACS_AUTH_MODE);

  if (ENCRYPTION_KEY) {
    const hex = String(ENCRYPTION_KEY).trim();
    const isValidHex = /^[0-9a-fA-F]{64}$/.test(hex);
    if (!isValidHex) {
      throw new Error(
        'Invalid ENCRYPTION_KEY. Must be a 64-character hex string (32 bytes) for AES-256.'
      );
    }
  }

  if (isNaN(PORT) || PORT < 1 || PORT > 65535) {
    throw new Error(
      `Invalid PORT: ${rawPort}. Must be a number between 1 and 65535.`
    );
  }

  if (SMTP_PORT !== null && (isNaN(SMTP_PORT) || SMTP_PORT < 1 || SMTP_PORT > 65535)) {
    throw new Error(`Invalid SMTP_PORT: ${process.env.SMTP_PORT}. Must be a number between 1 and 65535.`);
  }

  if (CSRF_SECRET && CSRF_SECRET.length < 32) {
    throw new Error('CSRF_SECRET must be at least 32 characters long.');
  }

  if (isNaN(WS_MAX_CONNECTIONS) || WS_MAX_CONNECTIONS < 1) {
    throw new Error('WS_MAX_CONNECTIONS must be a positive integer.');
  }

  if (isNaN(WS_HEARTBEAT_INTERVAL) || WS_HEARTBEAT_INTERVAL < 1000) {
    throw new Error('WS_HEARTBEAT_INTERVAL must be at least 1000ms.');
  }

  if (isNaN(WS_HEARTBEAT_TIMEOUT) || WS_HEARTBEAT_TIMEOUT < 2000) {
    throw new Error('WS_HEARTBEAT_TIMEOUT must be at least 2000ms.');
  }

  if (
    isNaN(PRISMA_POOL_CONNECTION_LIMIT) ||
    PRISMA_POOL_CONNECTION_LIMIT < 1 ||
    PRISMA_POOL_CONNECTION_LIMIT > 1000
  ) {
    throw new Error('PRISMA_POOL_CONNECTION_LIMIT must be an integer between 1 and 1000.');
  }

  if (isNaN(PRISMA_POOL_CONNECT_TIMEOUT_MS) || PRISMA_POOL_CONNECT_TIMEOUT_MS < 1000) {
    throw new Error('PRISMA_POOL_CONNECT_TIMEOUT_MS must be at least 1000ms.');
  }

  if (isNaN(PRISMA_POOL_ACQUIRE_TIMEOUT_MS) || PRISMA_POOL_ACQUIRE_TIMEOUT_MS < 1000) {
    throw new Error('PRISMA_POOL_ACQUIRE_TIMEOUT_MS must be at least 1000ms.');
  }

  if (isNaN(SEED_RECORD_COUNT) || SEED_RECORD_COUNT < 0) {
    throw new Error('SEED_RECORD_COUNT must be a non-negative integer.');
  }

  if (isNaN(SEED_RANDOM_SEED)) {
    throw new Error('SEED_RANDOM_SEED must be an integer.');
  }

  if (isNaN(PACS_TIMEOUT_MS) || PACS_TIMEOUT_MS < 1000) {
    throw new Error('PACS_TIMEOUT_MS must be at least 1000ms.');
  }

  if (isNaN(OTEL_METRIC_EXPORT_INTERVAL_MS) || OTEL_METRIC_EXPORT_INTERVAL_MS < 1000) {
    throw new Error('OTEL_METRIC_EXPORT_INTERVAL_MS must be at least 1000ms.');
  }

  const AWS_ACCESS_KEY_ID = process.env.AWS_ACCESS_KEY_ID || null;
  const AWS_SECRET_ACCESS_KEY = process.env.AWS_SECRET_ACCESS_KEY || null;
  const AWS_REGION = process.env.AWS_REGION || null;
  const AWS_S3_BUCKET = process.env.AWS_S3_BUCKET || null;

  if (STORAGE_PROVIDER === 's3') {
    if (!AWS_ACCESS_KEY_ID || !AWS_SECRET_ACCESS_KEY || !AWS_REGION || !AWS_S3_BUCKET) {
      throw new Error(
        'AWS credentials are required when STORAGE_PROVIDER is "s3". ' +
        'Please set AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, and AWS_S3_BUCKET in your .env file.'
      );
    }
  }

  const envConfig = {
    DATABASE_URL,
    JWT_SECRET,
    CORS_ORIGINS,
    NODE_ENV,
    PORT,
    HOST,
    TRUST_PROXY,
    STORAGE_PROVIDER,
    ENCRYPTION_KEY,
    CSRF_SECRET,
    APP_PUBLIC_URL,
    APP_DISPLAY_NAME,
    APP_SHORT_NAME,
    JWT_ACCESS_TOKEN_EXPIRATION,
    JWT_REFRESH_TOKEN_EXPIRATION,
    AUTH_SESSION_TTL_DAYS,
    SMTP_HOST,
    SMTP_PORT,
    SMTP_USER,
    SMTP_PASS,
    SMTP_FROM,
    SMTP_FROM_NAME,
    SMTP_REPLY_TO,
    SMTP_NO_REPLY_ADDRESS,
    ALLOW_PLAINTEXT_PASSWORD_EMAIL,
    HANDLE_SIGINT,
    ALLOW_PRIVATE_NETWORK_ORIGINS,
    WS_MAX_CONNECTIONS,
    WS_HEARTBEAT_INTERVAL,
    WS_HEARTBEAT_TIMEOUT,
    PRISMA_POOL_CONNECTION_LIMIT,
    PRISMA_POOL_CONNECT_TIMEOUT_MS,
    PRISMA_POOL_ACQUIRE_TIMEOUT_MS,
    PRISMA_MYSQL_ALLOW_PUBLIC_KEY_RETRIEVAL,
    SEED_RECORD_COUNT,
    SEED_RANDOM_SEED,
    PACS_DICOMWEB_BASE_URL,
    PACS_AUTH_MODE,
    PACS_USERNAME,
    PACS_PASSWORD,
    PACS_BEARER_TOKEN,
    PACS_TIMEOUT_MS,
    OTEL_ENABLED,
    OTEL_SERVICE_NAME,
    OTEL_EXPORTER_OTLP_ENDPOINT,
    OTEL_METRIC_EXPORT_INTERVAL_MS,
    PHARMACY_WORKSPACE_V1,
    RADIOLOGY_ATTESTATION_V2,
    AWS_ACCESS_KEY_ID,
    AWS_SECRET_ACCESS_KEY,
    AWS_REGION,
    AWS_S3_BUCKET
  };

  return envConfig;
};

let cachedEnv = null;

const getEnv = () => {
  if (!cachedEnv) {
    cachedEnv = buildEnv();
  }
  return cachedEnv;
};

const getDatabaseUrlForPrisma = () => validateRequired('DATABASE_URL');

const setEnvForTests = (overrides = {}) => {
  Object.entries(overrides).forEach(([key, value]) => {
    if (value === undefined || value === null) {
      delete process.env[key];
    } else {
      process.env[key] = String(value);
    }
  });

  cachedEnv = buildEnv();
  return cachedEnv;
};

const envKeys = [
  'DATABASE_URL',
  'JWT_SECRET',
  'CORS_ORIGINS',
  'NODE_ENV',
  'PORT',
  'HOST',
  'TRUST_PROXY',
  'STORAGE_PROVIDER',
  'ENCRYPTION_KEY',
  'CSRF_SECRET',
  'APP_PUBLIC_URL',
  'APP_DISPLAY_NAME',
  'APP_SHORT_NAME',
  'JWT_ACCESS_TOKEN_EXPIRATION',
  'JWT_REFRESH_TOKEN_EXPIRATION',
  'AUTH_SESSION_TTL_DAYS',
  'SMTP_HOST',
  'SMTP_PORT',
  'SMTP_USER',
  'SMTP_PASS',
  'SMTP_FROM',
  'SMTP_FROM_NAME',
  'SMTP_REPLY_TO',
  'SMTP_NO_REPLY_ADDRESS',
  'ALLOW_PLAINTEXT_PASSWORD_EMAIL',
  'HANDLE_SIGINT',
  'ALLOW_PRIVATE_NETWORK_ORIGINS',
  'WS_MAX_CONNECTIONS',
  'WS_HEARTBEAT_INTERVAL',
  'WS_HEARTBEAT_TIMEOUT',
  'PRISMA_POOL_CONNECTION_LIMIT',
  'PRISMA_POOL_CONNECT_TIMEOUT_MS',
  'PRISMA_POOL_ACQUIRE_TIMEOUT_MS',
  'PRISMA_MYSQL_ALLOW_PUBLIC_KEY_RETRIEVAL',
  'SEED_RECORD_COUNT',
  'SEED_RANDOM_SEED',
  'PACS_DICOMWEB_BASE_URL',
  'PACS_AUTH_MODE',
  'PACS_USERNAME',
  'PACS_PASSWORD',
  'PACS_BEARER_TOKEN',
  'PACS_TIMEOUT_MS',
  'OTEL_ENABLED',
  'OTEL_SERVICE_NAME',
  'OTEL_EXPORTER_OTLP_ENDPOINT',
  'OTEL_METRIC_EXPORT_INTERVAL_MS',
  'PHARMACY_WORKSPACE_V1',
  'RADIOLOGY_ATTESTATION_V2',
  'AWS_ACCESS_KEY_ID',
  'AWS_SECRET_ACCESS_KEY',
  'AWS_REGION',
  'AWS_S3_BUCKET'
];

const exported = {
  setEnvForTests,
  getDatabaseUrlForPrisma
};

envKeys.forEach((key) => {
  Object.defineProperty(exported, key, {
    enumerable: true,
    get: () => getEnv()[key]
  });
});

module.exports = exported;
