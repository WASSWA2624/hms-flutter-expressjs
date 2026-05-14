/**
 * Lib Barrel Export
 * 
 * Centralized export for all lib utilities
 * Allows importing lib utilities via @lib/* aliases
 * Per import-aliases.mdc: @lib/* resolves to src/lib/*
 */

// Async utilities
const { asyncHandler } = require('@lib/async');

// Alias utilities
const { registerModuleAliases, registerAllModuleAliases } = require('@lib/aliases');

// Audit utilities
const { createAuditLog } = require('@lib/audit');

// Crypto utilities
const { encrypt, decrypt, hashPassword, comparePassword, hashApiKey, verifyApiKey } = require('@lib/crypto');

// Date utilities
const { formatDate, getCurrentTimestamp, getCurrentTimestampMs, getCurrentISO, getCurrentDate, getCurrentDateString } = require('@lib/dates');

// Error utilities
const { AppError, HttpError, handleApiError } = require('@lib/errors');

// Adaptability guard utilities
const {
  buildGuardResult,
  checkPolicyGuard,
  checkWorkflowStateGuard,
  runDynamicFormValidationHooks,
  checkFeatureFlagGuard,
  isFeatureFlagEnabled
} = require('@lib/guards');

// JWT utilities
const { generateToken, generateRefreshToken, verifyToken } = require('@lib/jwt');

// Logging utilities
const { sanitize, logger } = require('@lib/logging');

// Performance utilities
const { logQueryPerformance, logEndpointPerformance, getDbStats, resetMetrics } = require('@lib/performance');

// Resilience utilities
const { withRetry, withTimeout, isTransientError } = require('@lib/resilience');

// Response utilities
const { sendSuccess, sendPaginated, sendError } = require('@lib/response');

// Storage utilities
const { StorageService, LocalStorageService, S3StorageService, createStorageService } = require('@lib/storage');

// i18n utilities
const { getLocale, translate, resolveLocale, getDirection, formatDate: formatLocaleDate, formatNumber } = require('@lib/i18n');

// Validation utilities
const validationSchemas = require('@lib/validation');

// WebSocket utilities
const { WS_EVENTS, CONNECTION_EVENTS, AUTH_EVENTS, emitToUser, emitBroadcast, emitToUsers } = require('@lib/websocket');

module.exports = {
  // Aliases
  registerModuleAliases,
  registerAllModuleAliases,
  
  // Async
  asyncHandler,
  
  // Audit
  createAuditLog,
  
  // Crypto
  encrypt,
  decrypt,
  hashPassword,
  comparePassword,
  hashApiKey,
  verifyApiKey,
  
  // Dates
  formatDate,
  getCurrentTimestamp,
  getCurrentTimestampMs,
  getCurrentISO,
  getCurrentDate,
  getCurrentDateString,
  
  // Errors
  AppError,
  HttpError,
  handleApiError,

  // Guards
  buildGuardResult,
  checkPolicyGuard,
  checkWorkflowStateGuard,
  runDynamicFormValidationHooks,
  checkFeatureFlagGuard,
  isFeatureFlagEnabled,
  
  // JWT
  generateToken,
  generateRefreshToken,
  verifyToken,
  
  // Logging
  sanitize,
  logger,
  
  // Performance
  logQueryPerformance,
  logEndpointPerformance,
  getDbStats,
  resetMetrics,
  
  // Resilience
  withRetry,
  withTimeout,
  isTransientError,

  // Response
  sendSuccess,
  sendPaginated,
  sendError,
  
  // Storage
  StorageService,
  LocalStorageService,
  S3StorageService,
  createStorageService,

  // i18n
  getLocale,
  translate,
  resolveLocale,
  getDirection,
  formatLocaleDate,
  formatNumber,
  
  // Validation
  validationSchemas,
  
  // WebSocket
  WS_EVENTS,
  CONNECTION_EVENTS,
  AUTH_EVENTS,
  emitToUser,
  emitBroadcast,
  emitToUsers
};

