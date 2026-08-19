/**
 * Cross-Site Request Forgery (CSRF) Protection Middleware
 *
 * Enforces CSRF tokens for state-changing requests per auth-security.mdc.
 * Validates CSRF token from request headers against session token.
 */

const SecurityConfig = require('@config/security');
const { HttpError } = require('@lib/errors');
const { logger } = require('@lib/logging');
const { verifyCsrfToken } = require('@lib/security/csrf-token');

const CSRF_MISSING_CODE = 'CSRF_MISSING';
const CSRF_INVALID_CODE = 'CSRF_INVALID';

const SAFE_METHODS = new Set(['GET', 'HEAD', 'OPTIONS']);
const CSRF_HEADER = 'x-csrf-token';
const CSRF_SESSION_KEY = '_csrf';
const CSRF_EXEMPT_ROUTES = new Set([
  'POST /api/v1/auth/identify',
  'POST /api/v1/auth/login',
  'POST /api/v1/auth/register',
  'POST /api/v1/auth/logout',
  'POST /api/v1/auth/change-password',
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

    // Token-authenticated auth routes must work without a separate CSRF session.
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
      return next(
        new HttpError('errors.csrf.missing', 403, [], {
          problemCode: CSRF_MISSING_CODE
        })
      );
    }

    // Primary path: the token is self-verifying, so any worker process can
    // validate a token issued by any other. This is what makes CSRF survive a
    // multi-process deployment, where the in-memory session below is not shared.
    const verification = verifyCsrfToken(token, { sessionId: req.sessionId });
    if (verification.valid) {
      if (!verification.sessionBound) {
        // The token is authentic but the session cookie did not come back.
        // Usually SameSite/third-party cookie blocking on a cross-site client.
        logger.warn('CSRF token accepted without session cookie binding', {
          method: req.method,
          path: req.path,
          ip: req.ip
        });
      }
      return next();
    }

    // Compatibility path: tokens minted before this change (and single-process
    // dev sessions) still validate against the session copy.
    const sessionToken = req.session?.[CSRF_SESSION_KEY];
    if (sessionToken && token === sessionToken) {
      return next();
    }

    logger.warn('CSRF token validation failed', {
      method: req.method,
      path: req.path,
      ip: req.ip,
      reason: verification.reason,
      hasSessionToken: Boolean(sessionToken)
    });
    return next(
      new HttpError('errors.csrf.invalid', 403, [], {
        problemCode: CSRF_INVALID_CODE
      })
    );
  };
};

module.exports = csrfMiddleware;
