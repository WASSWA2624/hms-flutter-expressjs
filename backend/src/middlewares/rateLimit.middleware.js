/**
 * Rate Limit Middleware
 * 
 * API rate limiting per rate-limiting.mdc
 * Prevents abuse and ensures fair resource usage
 * 
 * Per rate-limiting.mdc:
 * - Rate limit data should be stored in Redis for distributed systems
 * - In-memory storage may be used for single-instance deployments
 * - Must use token bucket or sliding window algorithm
 * - Must return 429 when exceeded, include rate limit headers
 */

const rateLimitConfig = require('@config/rateLimit');
const { sendError } = require('@lib/response');
const { NODE_ENV } = require('@config/env');
const { logger } = require('@lib/logging');
const crypto = require('crypto');

// In-memory rate limit store (for single-instance deployments)
// In production with multiple instances, use Redis
const rateLimitStore = new Map();
const MAX_RATE_LIMIT_KEYS = 50000;

const pruneOldestEntries = (targetSize) => {
  while (rateLimitStore.size > targetSize) {
    const oldestKey = rateLimitStore.keys().next().value;
    if (!oldestKey) break;
    rateLimitStore.delete(oldestKey);
  }
};

/**
 * Get client identifier (IP address or user ID)
 * 
 * @param {Object} req - Express request object
 * @returns {string} Client identifier
 */
const getBearerToken = (req) => {
  const authorization = req?.headers?.authorization;
  if (typeof authorization !== 'string') return null;

  const [scheme, token] = authorization.trim().split(/\s+/, 2);
  if (!scheme || !token || scheme.toLowerCase() !== 'bearer') {
    return null;
  }

  return token;
};

const getClientId = (req) => {
  // Prefer user ID if authenticated
  if (req.user && req.user.id) {
    return `user:${req.user.id}`;
  }

  const bearerToken = getBearerToken(req);
  if (bearerToken) {
    const fingerprint = crypto
      .createHash('sha256')
      .update(bearerToken)
      .digest('hex')
      .slice(0, 16);
    return `token:${fingerprint}`;
  }
  
  // Fall back to IP address
  return `ip:${req.ip || req.connection.remoteAddress || 'unknown'}`;
};

const resolveRequestLimits = (req, config, options) => {
  if (options.windowMs || options.max) {
    return {
      windowMs: options.windowMs || config.windowMs || 15 * 60 * 1000,
      max: options.max || config.max || 100,
    };
  }

  const hasAuthenticatedSignal = Boolean(req?.user?.id || getBearerToken(req));
  const scopedConfig = hasAuthenticatedSignal
    ? (config.authenticated || {})
    : (config.global || {});

  return {
    windowMs:
      scopedConfig.windowMs ||
      config.windowMs ||
      15 * 60 * 1000,
    max:
      scopedConfig.max ||
      config.max ||
      100,
  };
};

/**
 * Get rate limit key
 * 
 * @param {string} clientId - Client identifier
 * @param {string} endpoint - Endpoint path
 * @returns {string} Rate limit key
 */
const getRateLimitKey = (clientId, endpoint) => {
  return `${clientId}:${endpoint}`;
};

/**
 * Clean expired entries from rate limit store
 */
const cleanExpiredEntries = () => {
  const now = Date.now();
  for (const [key, value] of rateLimitStore.entries()) {
    const windowMs = value.windowMs || 15 * 60 * 1000;
    const timestamps = (value.timestamps || []).filter((timestamp) => timestamp > now - windowMs);
    if (timestamps.length === 0) {
      rateLimitStore.delete(key);
    } else {
      rateLimitStore.set(key, { ...value, timestamps });
    }
  }

  // Guard against unbounded memory usage with very high cardinality keys.
  if (rateLimitStore.size > MAX_RATE_LIMIT_KEYS) {
    pruneOldestEntries(MAX_RATE_LIMIT_KEYS);
  }
};

// Clean expired entries every 5 minutes
const cleanupInterval = setInterval(cleanExpiredEntries, 5 * 60 * 1000);
if (typeof cleanupInterval.unref === 'function') {
  cleanupInterval.unref();
}

/**
 * Create rate limit middleware
 * 
 * @param {Object} [options] - Rate limit options
 * @param {number} [options.windowMs] - Time window in milliseconds
 * @param {number} [options.max] - Maximum requests per window
 * @param {string} [options.message] - Error message when limit exceeded
 * @returns {Function} Express middleware
 */
const rateLimit = (options = {}) => {
  // Get default config or use provided options
  const config = rateLimitConfig || {};
  const message = options.message || 'errors.rate_limit.exceeded';
  
  return (req, res, next) => {
    const { windowMs, max } = resolveRequestLimits(req, config, options);
    const clientId = getClientId(req);
    const endpoint = req.path;
    const key = getRateLimitKey(clientId, endpoint);
    const now = Date.now();
    
    // Get or create rate limit entry
    let entry = rateLimitStore.get(key);
    if (!entry) {
      entry = {
        timestamps: [],
        windowMs
      };
    }

    // Sliding window: keep only timestamps inside the window
    const windowStart = now - windowMs;
    const timestamps = (entry.timestamps || []).filter((timestamp) => timestamp > windowStart);
    timestamps.push(now);
    entry.timestamps = timestamps;
    entry.windowMs = windowMs;
    rateLimitStore.set(key, entry);
    if (rateLimitStore.size > MAX_RATE_LIMIT_KEYS) {
      cleanExpiredEntries();
    }

    const remaining = Math.max(0, max - timestamps.length);
    const resetTime = timestamps.length > 0 ? timestamps[0] + windowMs : now + windowMs;
    const resetTimestamp = Math.floor(resetTime / 1000);
    
    // Set rate limit headers
    res.setHeader('X-RateLimit-Limit', max);
    res.setHeader('X-RateLimit-Remaining', remaining);
    res.setHeader('X-RateLimit-Reset', resetTimestamp);
    
    // Check if limit exceeded
    if (timestamps.length > max) {
      logger.warn('Rate limit exceeded', {
        clientId,
        endpoint,
        max,
        windowMs,
        resetAt: new Date(resetTime).toISOString()
      });
      return sendError(res, 429, message, [{
        field: 'rate_limit',
        message: 'errors.rate_limit.reset',
        reset_at: new Date(resetTime).toISOString()
      }]);
    }
    
    next();
  };
};

/**
 * Get default rate limit middleware
 * Uses configuration from @config/rateLimit
 * 
 * @returns {Function} Express middleware
 */
const defaultRateLimit = () => {
  return rateLimit();
};

module.exports = {
  rateLimit,
  defaultRateLimit
};

