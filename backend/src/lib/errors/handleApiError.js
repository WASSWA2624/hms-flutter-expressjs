/**
 * Centralized API Error Handler
 * 
 * Handles all errors and formats them according to response-format.mdc
 * Decodes Prisma errors to readable messages
 * Never exposes stack traces or sensitive information to clients
 * 
 * @param {Error} err - The error object
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next function
 * @returns {Object} Formatted error response
 */
const AppError = require('@lib/errors/AppError');
const HttpError = require('@lib/errors/HttpError');
const { translate, isTranslationKey, applyLocaleHeader, getResponseMeta } = require('@lib/i18n');
const { sanitizeFriendlyIds } = require('@lib/identifiers/sanitize-friendly-ids');
const {
  applyProblemJsonContentType,
  createProblemDetails
} = require('@lib/response/problem-details');

// Prisma may not be available during initial setup
let Prisma = null;
try {
  Prisma = require('@prisma/client').Prisma;
} catch (err) {
  // Prisma not available yet, will be handled gracefully
}

/**
 * Decode Prisma errors to user-friendly messages
 * 
 * @param {Error} error - Prisma error
 * @returns {Object} Decoded error with message and status code
 */
const decodePrismaError = (error) => {
  if (!Prisma) return null;
  
  // Prisma Client Known Request Error
  if (error instanceof Prisma.PrismaClientKnownRequestError) {
    switch (error.code) {
      case 'P2002':
        // Unique constraint violation
        const field = error.meta?.target?.[0] || 'field';
        return {
          message: 'errors.database.unique',
          statusCode: 409,
          errors: [{
            field: field,
            message: 'errors.database.unique_field'
          }]
        };
      
      case 'P2025':
        // Record not found
        return {
          message: 'errors.not_found',
          statusCode: 404,
          errors: []
        };
      
      case 'P2003':
        // Foreign key constraint violation
        return {
          message: 'errors.database.foreign_key',
          statusCode: 400,
          errors: [{
            field: error.meta?.field_name || 'reference',
            message: 'errors.database.foreign_key_field'
          }]
        };
      
      case 'P2014':
        // Required relation violation
        return {
          message: 'errors.database.relation_required',
          statusCode: 400,
          errors: [{
            field: error.meta?.relation_name || 'relation',
            message: 'errors.database.relation_required_field'
          }]
        };
      
      default:
        return {
          message: 'errors.database.unexpected',
          statusCode: 500,
          errors: []
        };
    }
  }
  
  // Prisma Client Validation Error
  if (error instanceof Prisma.PrismaClientValidationError) {
    return {
      message: 'errors.validation.invalid',
      statusCode: 400,
      errors: [{
        field: 'validation',
        message: 'errors.validation.invalid'
      }]
    };
  }
  
  // Prisma Client Initialization Error
  if (error instanceof Prisma.PrismaClientInitializationError) {
    return {
      message: 'errors.database.unavailable',
      statusCode: 503,
      errors: []
    };
  }
  
  // Prisma Client RPC Error
  if (error instanceof Prisma.PrismaClientRustPanicError) {
    return {
      message: 'errors.database.panic',
      statusCode: 500,
      errors: []
    };
  }
  
  return null;
};

/**
 * Format validation errors from Zod
 * 
 * @param {Error} error - Zod validation error
 * @returns {Object} Formatted validation errors
 */
const formatValidationErrors = (error) => {
  const issues = Array.isArray(error?.issues)
    ? error.issues
    : Array.isArray(error?.errors)
    ? error.errors
    : null;

  if (error?.name === 'ZodError' && issues) {
    const errors = issues.map((issue) => {
      const field = Array.isArray(issue?.path) && issue.path.length
        ? issue.path.join('.')
        : 'request';
      const missingValue =
        issue?.received === 'undefined' ||
        issue?.input === undefined;
      const message = isTranslationKey(issue?.message)
        ? issue.message
        : issue?.code === 'invalid_type' && missingValue
          ? 'errors.validation.field.required'
          : 'errors.validation.invalid';

      return {
        field,
        message,
        ...(issue?.minimum !== undefined ? { min: issue.minimum } : {}),
        ...(issue?.maximum !== undefined ? { max: issue.maximum } : {}),
      };
    });
    
    return {
      message: 'errors.validation.failed',
      statusCode: 400,
      errors
    };
  }
  
  return null;
};

/**
 * Handle API errors and return standardized response
 * 
 * @param {Error} err - The error object
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next function
 */
const defaultErrorKeyByStatus = {
  400: 'errors.request.bad',
  401: 'errors.auth.unauthorized',
  403: 'errors.auth.forbidden',
  404: 'errors.not_found',
  409: 'errors.conflict',
  429: 'errors.rate_limit.exceeded',
  500: 'errors.server.unexpected',
  503: 'errors.service.unavailable'
};

const toErrorCode = (message, statusCode) => {
  if (isTranslationKey(message)) {
    const key = String(message).split('.').pop() || 'unknown_error';
    return key.toUpperCase().replace(/-/g, '_');
  }
  if (statusCode >= 500) return 'SERVER_ERROR';
  if (statusCode === 401) return 'UNAUTHORIZED';
  if (statusCode === 403) return 'FORBIDDEN';
  if (statusCode === 404) return 'NOT_FOUND';
  if (statusCode === 409) return 'CONFLICT';
  return 'UNKNOWN_ERROR';
};

const resolveMessage = (message, locale, statusCode) => {
  if (isTranslationKey(message)) {
    return translate(message, locale);
  }
  const fallbackKey = defaultErrorKeyByStatus[statusCode];
  if (fallbackKey) {
    return translate(fallbackKey, locale);
  }
  return message;
};

const resolveErrors = (errors, locale) => {
  if (!Array.isArray(errors)) {
    return [];
  }
  const resolved = errors.map((error) => {
    if (!error || typeof error !== 'object') {
      return error;
    }
    const resolvedMessage = isTranslationKey(error.message)
      ? translate(error.message, locale, error)
      : error.message;
    return { ...error, message: resolvedMessage };
  });
  return sanitizeFriendlyIds(resolved);
};

const handleApiError = (err, req, res, next) => {
  // If response already sent, delegate to default Express error handler
  if (res.headersSent) {
    return next(err);
  }
  
  let statusCode = 500;
  let message = 'errors.server.unexpected';
  let errors = [];
  
  // Handle known error types
  if (err instanceof HttpError) {
    statusCode = err.statusCode;
    message = err.message;
    errors = err.errors || [];
  } else if (err instanceof AppError) {
    statusCode = err.statusCode || 500;
    message = err.message;
  } else if (err.name === 'ZodError') {
    // Handle Zod validation errors
    const meta = getResponseMeta(res);
    const validationError = formatValidationErrors(err);
    if (validationError) {
      statusCode = validationError.statusCode;
      message = validationError.message;
      errors = validationError.errors;
    }
  } else if (Prisma && (
             err instanceof Prisma.PrismaClientKnownRequestError ||
             err instanceof Prisma.PrismaClientValidationError ||
             err instanceof Prisma.PrismaClientInitializationError ||
             err instanceof Prisma.PrismaClientRustPanicError)) {
    // Handle Prisma errors
    const prismaError = decodePrismaError(err);
    if (prismaError) {
      statusCode = prismaError.statusCode;
      message = prismaError.message;
      errors = prismaError.errors || [];
    }
  } else if (err.statusCode) {
    // Handle errors with statusCode property (e.g., from libraries)
    statusCode = err.statusCode;
    message = err.message || message;
  }
  
  // Log error for debugging (but never expose stack trace to client)
  // Logging will be handled by error middleware using logger
  // Stack traces should not be logged if they contain sensitive information
  
  const meta = getResponseMeta(res);
  const sanitizedMeta = sanitizeFriendlyIds(meta);
  const resolvedMessage = resolveMessage(message, meta.locale, statusCode);
  const resolvedErrors = resolveErrors(errors, meta.locale);
  applyLocaleHeader(res, meta.locale);

  const code = toErrorCode(message, statusCode);
  const problem = createProblemDetails({
    status: statusCode,
    title: resolvedMessage,
    detail: resolvedMessage,
    code,
    errors: resolvedErrors,
    meta: sanitizedMeta,
    req
  });

  applyProblemJsonContentType(res);

  res.status(statusCode).json(problem);
};

module.exports = handleApiError;

