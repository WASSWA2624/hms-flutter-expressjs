/**
 * Security headers middleware
 *
 * Applies security headers per auth-security.mdc.
 */

const SecurityConfig = require('@config/security');
const { NODE_ENV } = require('@config/env');

/**
 * Apply security headers.
 *
 * @returns {Function} Express middleware
 */
const securityHeaders = () => {
  return (req, res, next) => {
    const isProd = NODE_ENV === 'production';

    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('X-XSS-Protection', '1; mode=block');
    res.setHeader('Referrer-Policy', 'no-referrer');

    if (isProd) {
      res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload');
    }

    if (SecurityConfig?.headers?.contentSecurityPolicy) {
      res.setHeader('Content-Security-Policy', SecurityConfig.headers.contentSecurityPolicy);
    }

    next();
  };
};

module.exports = securityHeaders;
