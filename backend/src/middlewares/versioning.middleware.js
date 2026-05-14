/**
 * API Versioning Middleware
 *
 * Emits deprecation headers for deprecated API versions.
 * Per dev-plan/P003_app.mdc: supports optional Deprecation/Sunset headers.
 */

const { DEPRECATED_API_VERSIONS, DEPRECATION_SUNSET } = require('@config/constants');

/**
 * Extract API version from request path.
 *
 * @param {string} path - Request path
 * @returns {string|null} Version string (e.g., "v1") or null
 */
const getVersionFromPath = (path) => {
  if (!path || typeof path !== 'string') {
    return null;
  }

  const match = path.match(/^\/api\/(v\d+)\b/i);
  return match ? match[1] : null;
};

/**
 * Apply deprecation headers for deprecated versions.
 *
 * @returns {Function} Express middleware
 */
const versioningMiddleware = () => {
  return (req, res, next) => {
    const version = getVersionFromPath(req.path);
    if (!version) {
      return next();
    }

    if (DEPRECATED_API_VERSIONS.includes(version)) {
      res.setHeader('Deprecation', 'true');
      if (DEPRECATION_SUNSET) {
        res.setHeader('Sunset', DEPRECATION_SUNSET);
      }
    }

    return next();
  };
};

module.exports = versioningMiddleware;
