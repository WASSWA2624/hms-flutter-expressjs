/**
 * Error Middleware
 * 
 * Centralized error handler middleware per error-logging.mdc
 * Uses handleApiError to format and send error responses
 * Must be the last middleware in the Express app
 * 
 * Per error-logging.mdc:
 * - All errors must be passed to centralized error middleware
 * - Error middleware must use handleApiError internally
 * - Stack traces must not be returned to clients
 */

const { handleApiError } = require('@lib/errors');
const { logger } = require('@lib/logging');
const { createAuditLog } = require('@lib/audit');

/**
 * Error middleware
 * Catches all errors and passes them to handleApiError
 * 
 * @param {Error} err - Error object
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next function
 */
const errorMiddleware = (err, req, res, next) => {
  const details = Array.isArray(err?.errors) ? err.errors : [];
  const diagnosticDetails = details
    .filter((item) => item && typeof item === 'object')
    .map((item) => ({
      ...item,
      originalError: item.originalError ? String(item.originalError) : undefined,
    }));

  // Log error for debugging (sanitized)
  logger.error('Error caught by error middleware', {
    error: err.message,
    messageKey: err?.messageKey,
    statusCode: err?.statusCode || err?.status,
    stack: err.stack, // Stack trace logged but not sent to client
    details: diagnosticDetails.length > 0 ? diagnosticDetails : undefined,
    path: req.path,
    method: req.method,
    ip: req.ip
  });
  
  // Log authorization failures for security monitoring
  if (err.statusCode === 403) {
    // Log permission denial attempt
    const userId = req.user?.id || null;
    const tenantId = req.user?.tenant_id || req.user?.tenantId || null;
    const facilityId = req.user?.facility_id || req.user?.facilityId || null;
    
    // Async log audit event (non-blocking)
    createAuditLog({
      action: 'ACCESS',
      entity: 'authorization',
      entity_id: req.path,
      user_id: userId,
      tenant_id: tenantId,
      facility_id: facilityId,
      ip_address: req.ip,
      user_agent: req.get('user-agent'),
      details: { 
        original_action: 'PERMISSION_DENIED',
        message: err.message,
        method: req.method,
        path: req.path
      }
    }).catch(auditErr => {
      logger.error('Failed to log audit event', { error: auditErr.message });
    });
  }
  
  // Pass error to centralized error handler
  handleApiError(err, req, res, next);
};

module.exports = errorMiddleware;

