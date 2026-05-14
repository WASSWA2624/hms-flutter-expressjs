/**
 * Offline support middleware
 *
 * Adds framework-level offline capabilities:
 * - Conditional GET support (`If-None-Match`, `If-Modified-Since`)
 * - Cache validation headers (`ETag`, `Last-Modified`, `Cache-Control`, `Vary`)
 * - Incremental sync metadata for list responses with `?since=...`
 * - Idempotency replay for mutation requests with `Idempotency-Key`
 */

const crypto = require('crypto');
const { logger } = require('@lib/logging');
const { HttpError } = require('@lib/errors');
const { resolveOfflinePolicy } = require('@config/offline-policies');

const OFFLINE_CACHE_CONTROL = 'private, max-age=60, stale-while-revalidate=30';
const MUTATION_CACHE_CONTROL = 'no-store';
const IDEMPOTENCY_TTL_MS = 24 * 60 * 60 * 1000;
const MAX_IDEMPOTENCY_ENTRIES = 5000;
const RESPONSE_HEADER_ALLOWLIST = [
  'Cache-Control',
  'Content-Language',
  'ETag',
  'Last-Modified',
  'Vary'
];

const idempotencyStore = new Map();

const normalizeRequestPath = (req) => {
  const rawPath = req?.originalUrl || req?.url || req?.path || '';
  const withoutQuery = String(rawPath).split('?')[0];
  return withoutQuery.toLowerCase();
};

const isAuthRequestPath = (req) => {
  const normalizedPath = normalizeRequestPath(req);
  return normalizedPath === '/api/v1/auth' || normalizedPath.startsWith('/api/v1/auth/');
};

const normalizeVersion = (value) => {
  if (value === undefined || value === null) return null;
  const normalized = String(value).trim();
  return normalized || null;
};

/**
 * Safely clone a response payload for idempotency replay.
 *
 * @param {any} payload - Response payload
 * @param {boolean} isJson - Whether payload is JSON
 * @returns {any} Cloned payload
 */
const clonePayload = (payload, isJson) => {
  if (payload === undefined) {
    return undefined;
  }

  if (payload === null) {
    return null;
  }

  if (Buffer.isBuffer(payload)) {
    return Buffer.from(payload);
  }

  if (!isJson || typeof payload !== 'object') {
    return payload;
  }

  try {
    return JSON.parse(JSON.stringify(payload));
  } catch (err) {
    return payload;
  }
};

/**
 * Convert a value into a deterministic string representation.
 *
 * @param {any} value - Value to serialize
 * @returns {string} Deterministic serialized string
 */
const serializeForHash = (value) => {
  if (Buffer.isBuffer(value)) {
    return value.toString('base64');
  }

  if (typeof value === 'string') {
    return value;
  }

  if (value === undefined) {
    return 'undefined';
  }

  return JSON.stringify(value);
};

/**
 * Compute a weak ETag value for any response payload.
 *
 * @param {any} payload - Response payload
 * @returns {string} Weak ETag header value
 */
const buildEtag = (payload) => {
  const digest = crypto
    .createHash('sha1')
    .update(serializeForHash(payload))
    .digest('base64url');
  return `W/"${digest}"`;
};

/**
 * Parse HTTP date safely.
 *
 * @param {string} value - HTTP date string
 * @returns {Date|null} Parsed date or null
 */
const parseHttpDate = (value) => {
  if (!value || typeof value !== 'string') {
    return null;
  }

  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }

  return parsed;
};

/**
 * Normalize and append a `Vary` header entry exactly once.
 *
 * @param {Object} res - Express response
 * @param {string} value - Header token to append
 */
const appendVaryHeader = (res, value) => {
  const existing = res.getHeader('Vary');
  if (!existing) {
    res.setHeader('Vary', value);
    return;
  }

  const current = String(existing)
    .split(',')
    .map((entry) => entry.trim())
    .filter(Boolean);

  if (!current.some((entry) => entry.toLowerCase() === value.toLowerCase())) {
    current.push(value);
    res.setHeader('Vary', current.join(', '));
  }
};

/**
 * Extract most recent update timestamp from response payload.
 *
 * @param {any} payload - Response payload
 * @returns {Date} Last modified timestamp candidate
 */
const getLastModifiedFromPayload = (payload) => {
  let latest = 0;

  const inspect = (value) => {
    if (!value || typeof value !== 'object') {
      return;
    }

    if (Array.isArray(value)) {
      value.forEach(inspect);
      return;
    }

    if (value.updated_at) {
      const parsed = new Date(value.updated_at);
      if (!Number.isNaN(parsed.getTime()) && parsed.getTime() > latest) {
        latest = parsed.getTime();
      }
    }
  };

  if (payload && typeof payload === 'object') {
    inspect(payload.data);
  }

  return latest > 0 ? new Date(latest) : new Date();
};

/**
 * Check if request validators indicate unchanged resource.
 *
 * @param {Object} req - Express request
 * @param {string} etag - Response ETag
 * @param {Date} lastModified - Response last modified date
 * @returns {boolean} True if response should be 304
 */
const shouldReturnNotModified = (req, etag, lastModified) => {
  const ifNoneMatch = req.headers?.['if-none-match'];
  if (ifNoneMatch && typeof ifNoneMatch === 'string') {
    const candidates = ifNoneMatch
      .split(',')
      .map((token) => token.trim())
      .filter(Boolean);

    if (candidates.includes('*') || candidates.includes(etag)) {
      return true;
    }
  }

  const ifModifiedSince = req.headers?.['if-modified-since'];
  const sinceDate = parseHttpDate(ifModifiedSince);
  if (sinceDate && lastModified.getTime() <= sinceDate.getTime()) {
    return true;
  }

  return false;
};

/**
 * Normalize list payload for incremental sync responses.
 *
 * @param {Object} req - Express request
 * @param {any} payload - Response payload
 * @returns {any} Updated payload
 */
const applySyncMetadata = (req, payload) => {
  if (!req.query || !req.query.since) {
    return payload;
  }

  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    return payload;
  }

  if (!Array.isArray(payload.data)) {
    return payload;
  }

  payload.data = payload.data.map((item) => {
    if (!item || typeof item !== 'object' || Array.isArray(item)) {
      return item;
    }

    if (Object.prototype.hasOwnProperty.call(item, 'deleted')) {
      return item;
    }

    if (Object.prototype.hasOwnProperty.call(item, 'deleted_at')) {
      return {
        ...item,
        deleted: Boolean(item.deleted_at)
      };
    }

    return item;
  });

  const hasMore = Boolean(payload.pagination?.hasNextPage);
  const tokenSeed = JSON.stringify({
    method: req.method,
    path: req.path,
    since: String(req.query.since),
    count: payload.data.length,
    page: payload.pagination?.page || 1
  });

  payload.sync = {
    sync_token: crypto.createHash('sha1').update(tokenSeed).digest('hex'),
    has_more: hasMore,
    timestamp: new Date().toISOString()
  };

  return payload;
};

/**
 * Build deterministic idempotency replay key for a request.
 *
 * @param {Object} req - Express request
 * @param {string} idempotencyKey - Idempotency key header value
 * @returns {string} Cache key
 */
const buildIdempotencyReplayKey = (req, idempotencyKey) => {
  const scopeSeed = JSON.stringify({
    method: req.method,
    path: req.path,
    query: req.query || {},
    body: req.body || {},
    auth: req.headers?.authorization || null,
    apiKey: req.headers?.['x-api-key'] || null
  });

  const scopeHash = crypto.createHash('sha1').update(scopeSeed).digest('hex');
  return `${req.method}:${req.path}:${idempotencyKey}:${scopeHash}`;
};

/**
 * Remove expired idempotency records and keep memory bounded.
 */
const pruneIdempotencyStore = () => {
  const now = Date.now();

  for (const [key, value] of idempotencyStore.entries()) {
    if (!value || value.expires_at <= now) {
      idempotencyStore.delete(key);
    }
  }

  while (idempotencyStore.size > MAX_IDEMPOTENCY_ENTRIES) {
    const oldestKey = idempotencyStore.keys().next().value;
    if (!oldestKey) {
      break;
    }
    idempotencyStore.delete(oldestKey);
  }
};

/**
 * Capture selected response headers for idempotent replay.
 *
 * @param {Object} res - Express response
 * @returns {Object} Header map
 */
const captureReplayHeaders = (res) => {
  const headers = {};
  RESPONSE_HEADER_ALLOWLIST.forEach((headerName) => {
    const value = res.getHeader(headerName);
    if (value !== undefined) {
      headers[headerName] = value;
    }
  });
  return headers;
};

/**
 * Replay a previously stored idempotent response.
 *
 * @param {Object} res - Express response
 * @param {Object} entry - Stored response entry
 * @returns {Object} Express response
 */
const replayIdempotentResponse = (res, entry) => {
  Object.entries(entry.headers || {}).forEach(([headerName, headerValue]) => {
    if (headerValue !== undefined) {
      res.setHeader(headerName, headerValue);
    }
  });

  res.status(entry.status_code);

  if (entry.status_code === 204 || entry.body === undefined) {
    return res.send();
  }

  if (entry.is_json) {
    return res.json(clonePayload(entry.body, true));
  }

  return res.send(entry.body);
};

/**
 * Determine whether request method mutates state.
 *
 * @param {string} method - HTTP method
 * @returns {boolean} Whether method is mutating
 */
const isMutationMethod = (method) => {
  return ['POST', 'PUT', 'PATCH', 'DELETE'].includes(String(method || '').toUpperCase());
};

/**
 * Clear in-memory idempotency entries (primarily for tests).
 */
const clearIdempotencyStore = () => {
  idempotencyStore.clear();
};

/**
 * Offline support middleware factory.
 *
 * @returns {Function} Express middleware
 */
const offlineSupportMiddleware = () => {
  return (req, res, next) => {
    pruneIdempotencyStore();
    appendVaryHeader(res, 'Accept-Language');
    const isAuthPath = isAuthRequestPath(req);
    const policy = resolveOfflinePolicy(req);
    req.offlinePolicy = policy;

    if (!res.getHeader('X-Offline-Policy')) {
      res.setHeader('X-Offline-Policy', policy.cache);
    }

    if (!res.getHeader('Cache-Control')) {
      if (policy.cache === 'no-store' || isAuthPath) {
        res.setHeader('Cache-Control', MUTATION_CACHE_CONTROL);
      } else if (policy.cache === 'sync' || policy.cache === 'revalidate') {
        res.setHeader('Cache-Control', OFFLINE_CACHE_CONTROL);
      } else if (isMutationMethod(req.method)) {
        res.setHeader('Cache-Control', MUTATION_CACHE_CONTROL);
      }
    }

    if (policy.require_conditional_mutation) {
      const headerVersion = normalizeVersion(req.headers?.['x-resource-version']);
      const bodyVersion =
        req.body && Object.prototype.hasOwnProperty.call(req.body, 'version')
          ? normalizeVersion(req.body.version)
          : null;
      const ifMatch = normalizeVersion(req.headers?.['if-match']);

      if (!headerVersion && !ifMatch) {
        return next(
          new HttpError('Precondition required', 428, [{ field: 'If-Match' }])
        );
      }

      if (headerVersion && bodyVersion && headerVersion !== bodyVersion) {
        return next(
          new HttpError('Version conflict', 409, [{ field: 'version' }])
        );
      }
    }

    const rawIdempotencyKey = req.headers?.['idempotency-key'];
    const idempotencyKey = isMutationMethod(req.method) && typeof rawIdempotencyKey === 'string'
      ? rawIdempotencyKey.trim()
      : '';

    const replayKey = !isAuthPath && policy.allow_idempotency && idempotencyKey
      ? buildIdempotencyReplayKey(req, idempotencyKey)
      : null;
    if (replayKey) {
      const existing = idempotencyStore.get(replayKey);
      if (existing && existing.expires_at > Date.now()) {
        logger.info('Idempotency replay served', {
          method: req.method,
          path: req.path
        });
        return replayIdempotentResponse(res, existing);
      }
    }

    const originalJson = res.json.bind(res);
    const originalSend = res.send.bind(res);
    let replayStored = false;

    const finalizePayload = (payload, isJson) => {
      let nextPayload = payload;

      if (req.method === 'GET' && isJson && policy.allow_sync_metadata) {
        nextPayload = applySyncMetadata(req, nextPayload);
      }

      const shouldComputeValidators =
        !isAuthPath &&
        policy.allow_validators &&
        (req.method === 'GET' || req.method === 'HEAD') &&
        res.statusCode >= 200 &&
        res.statusCode < 300 &&
        nextPayload !== undefined;

      if (shouldComputeValidators) {
        const existingEtag = res.getHeader('ETag');
        const etag = existingEtag || buildEtag(nextPayload);
        if (!existingEtag) {
          res.setHeader('ETag', etag);
        }

        const existingLastModified = res.getHeader('Last-Modified');
        const lastModifiedDate = existingLastModified
          ? parseHttpDate(String(existingLastModified)) || getLastModifiedFromPayload(nextPayload)
          : getLastModifiedFromPayload(nextPayload);

        if (!existingLastModified) {
          res.setHeader('Last-Modified', lastModifiedDate.toUTCString());
        }

        if (shouldReturnNotModified(req, String(etag), lastModifiedDate)) {
          res.status(304);
          return {
            notModified: true,
            payload: undefined
          };
        }
      }

      if (replayKey && !replayStored && res.statusCode < 500) {
        idempotencyStore.set(replayKey, {
          status_code: res.statusCode,
          is_json: isJson,
          body: clonePayload(nextPayload, isJson),
          headers: captureReplayHeaders(res),
          expires_at: Date.now() + IDEMPOTENCY_TTL_MS
        });
        replayStored = true;
      }

      return {
        notModified: false,
        payload: nextPayload
      };
    };

    res.json = (payload) => {
      const result = finalizePayload(payload, true);
      if (result.notModified) {
        return res.end();
      }
      return originalJson(result.payload);
    };

    res.send = (payload) => {
      const result = finalizePayload(payload, false);
      if (result.notModified) {
        return res.end();
      }
      return originalSend(result.payload);
    };

    next();
  };
};

module.exports = {
  offlineSupportMiddleware,
  clearIdempotencyStore
};
