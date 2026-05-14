/**
 * Cross-Site Request Forgery (CSRF) Protection Middleware
 *
 * Enforces CSRF tokens for state-changing requests per auth-security.mdc.
 * Validates CSRF token from request headers against session token.
 */

const SecurityConfig = require('@config/security');
const { HttpError } = require('@lib/errors');
const { logger } = require('@lib/logging');

const SAFE_METHODS = new Set(['GET', 'HEAD', 'OPTIONS']);
const CSRF_HEADER = 'x-csrf-token';
const CSRF_SESSION_KEY = '_csrf';
const CSRF_EXEMPT_ROUTES = new Set([
  'POST /api/v1/auth/identify',
  'POST /api/v1/auth/login',
  'POST /api/v1/auth/register',
  'POST /api/v1/auth/verify-email',
  'POST /api/v1/auth/verify-phone',
  'POST /api/v1/auth/resend-verification',
  'POST /api/v1/auth/forgot-password',
  'POST /api/v1/auth/reset-password',
]);

const isCsrfExempt = (req) => {
  const method = String(req?.method || '').toUpperCase();
  const path = String(req?.path || '').trim();
  return CSRF_EXEMPT_ROUTES.has(`${method} ${path}`);
};

/**
 * CSRF middleware.
 * Validates CSRF token for state-changing requests.
 * Token must be stored in session and sent in x-csrf-token header.
 *
 * @returns {Function} Express middleware
 */
const csrfMiddleware = () => {
  return (req, res, next) => {
    if (!SecurityConfig?.csrf?.enabled) {
      return next();
    }

    if (SAFE_METHODS.has(req.method)) {
      return next();
    }

    // Public auth bootstrap routes must work before any CSRF session exists.
    if (isCsrfExempt(req)) {
      return next();
    }

    // Get CSRF token from request header
    const token = req.headers[CSRF_HEADER];
    if (!token) {
      logger.warn('CSRF token missing from request', {
        method: req.method,
        path: req.path,
        ip: req.ip
      });
      return next(new HttpError('errors.csrf.missing', 403));
    }

    // Get stored CSRF token from session
    const sessionToken = req.session?.[CSRF_SESSION_KEY];
    if (!sessionToken) {
      logger.warn('CSRF session token not found', {
        method: req.method,
        path: req.path,
        ip: req.ip
      });
      return next(new HttpError('errors.csrf.missing', 403));
    }

    // Validate token matches session token
    if (token !== sessionToken) {
      logger.warn('CSRF token validation failed', {
        method: req.method,
        path: req.path,
        ip: req.ip,
        tokenMatch: token === sessionToken
      });
      return next(new HttpError('errors.csrf.invalid', 403));
    }

    return next();
  };
};

module.exports = csrfMiddleware;
