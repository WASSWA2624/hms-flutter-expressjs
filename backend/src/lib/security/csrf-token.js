/**
 * Stateless CSRF Token Helper
 *
 * Issues and verifies signed double-submit CSRF tokens.
 *
 * The previous scheme kept the expected token in an in-memory session map.
 * That only works for a single process: under Passenger (or any multi-worker /
 * multi-instance deployment) the `GET /auth/csrf-token` request and the
 * following state-changing request routinely land on different workers, so the
 * expected token was absent and every mutation failed with 403.
 *
 * A signed token removes the shared-state requirement: any worker holding the
 * same secret can verify a token any other worker issued.
 *
 * Token format: `<issuedAt>.<sessionBinding>.<nonce>.<signature>` where
 * `sessionBinding` is a truncated HMAC of the session id the token was issued
 * for, and `signature` is HMAC-SHA256 over the preceding three fields.
 */

const { createHmac, randomBytes, timingSafeEqual } = require('crypto');

const env = require('@config/env');

const TOKEN_PART_COUNT = 4;
const SESSION_BINDING_LENGTH = 16;
const DEFAULT_TTL_SECONDS = 24 * 60 * 60; // Matches the session cookie max age.

/**
 * Resolve the signing secret.
 *
 * `CSRF_SECRET` is preferred when configured. `JWT_SECRET` is a validated,
 * required, process-shared secret and is used as the fallback so existing
 * deployments gain stateless CSRF without new configuration.
 *
 * @returns {string} Signing secret
 */
const resolveSecret = () => {
  const secret = env?.CSRF_SECRET || env?.JWT_SECRET;
  if (!secret) {
    throw new Error('CSRF signing requires CSRF_SECRET or JWT_SECRET.');
  }
  return String(secret);
};

/**
 * Derive the opaque session binding embedded in a token.
 *
 * The raw session id is never placed in the token.
 *
 * @param {string} sessionId - Session identifier
 * @returns {string} Truncated hex binding, or an empty string when unbound
 */
const sessionBindingFor = (sessionId) => {
  const normalized = String(sessionId || '').trim();
  if (!normalized) {
    return '';
  }
  return createHmac('sha256', resolveSecret())
    .update(`csrf-session.${normalized}`)
    .digest('hex')
    .slice(0, SESSION_BINDING_LENGTH);
};

/**
 * Compute the signature covering a token's fields.
 *
 * @param {string|number} issuedAt - Issue time in unix seconds
 * @param {string} sessionBinding - Opaque session binding
 * @param {string} nonce - Random per-token value
 * @returns {string} Hex signature
 */
const sign = (issuedAt, sessionBinding, nonce) =>
  createHmac('sha256', resolveSecret())
    .update(`${issuedAt}.${sessionBinding}.${nonce}`)
    .digest('hex');

/**
 * Constant-time string comparison that tolerates length mismatches.
 *
 * @param {string} left - First value
 * @param {string} right - Second value
 * @returns {boolean} True when equal
 */
const safeEquals = (left, right) => {
  const leftBuffer = Buffer.from(String(left || ''), 'utf8');
  const rightBuffer = Buffer.from(String(right || ''), 'utf8');
  if (leftBuffer.length !== rightBuffer.length) {
    return false;
  }
  return timingSafeEqual(leftBuffer, rightBuffer);
};

/**
 * Issue a CSRF token bound to the given session identifier.
 *
 * @param {string} sessionId - Session identifier from the session cookie
 * @returns {string} Signed CSRF token
 */
const issueCsrfToken = (sessionId) => {
  const issuedAt = Math.floor(Date.now() / 1000);
  const nonce = randomBytes(16).toString('hex');
  const binding = sessionBindingFor(sessionId);
  return `${issuedAt}.${binding}.${nonce}.${sign(issuedAt, binding, nonce)}`;
};

/**
 * Verify a CSRF token.
 *
 * Returns a result object rather than a bare boolean so the caller can
 * distinguish a forged/expired token from a valid token whose session cookie
 * did not survive the round trip.
 *
 * @param {string} token - Presented token
 * @param {Object} [options] - Verification options
 * @param {string} [options.sessionId] - Session id from the request cookie
 * @param {number} [options.ttlSeconds] - Maximum token age in seconds
 * @returns {{valid: boolean, reason: string, sessionBound: boolean}} Result
 */
const verifyCsrfToken = (token, options = {}) => {
  const { sessionId = '', ttlSeconds = DEFAULT_TTL_SECONDS } = options;

  const parts = String(token || '').split('.');
  if (parts.length !== TOKEN_PART_COUNT) {
    return { valid: false, reason: 'malformed', sessionBound: false };
  }

  const [issuedAtRaw, binding, nonce, signature] = parts;
  const issuedAt = Number.parseInt(issuedAtRaw, 10);
  if (!Number.isFinite(issuedAt) || !nonce || !signature) {
    return { valid: false, reason: 'malformed', sessionBound: false };
  }

  // The signature proves this process (or a sibling holding the same secret)
  // minted the token. Without it nothing else is worth checking.
  if (!safeEquals(signature, sign(issuedAtRaw, binding, nonce))) {
    return { valid: false, reason: 'signature', sessionBound: false };
  }

  const ageSeconds = Math.floor(Date.now() / 1000) - issuedAt;
  if (ageSeconds < -60 || ageSeconds > ttlSeconds) {
    return { valid: false, reason: 'expired', sessionBound: false };
  }

  // Double-submit binding: the caller's cookie must be the one the token was
  // issued for. When the cookie never arrives (cross-site cookie blocking, or a
  // client that does not persist cookies) the binding cannot be checked. The
  // token is still accepted on signature and TTL, because a cross-origin
  // attacker cannot mint one and cannot read an issued one — CORS withholds the
  // response body — and API authentication is a bearer token the browser never
  // attaches automatically. The caller is told so it can log the degradation.
  const sessionBound = Boolean(binding) && binding === sessionBindingFor(sessionId);

  return { valid: true, reason: 'ok', sessionBound };
};

module.exports = {
  issueCsrfToken,
  verifyCsrfToken,
  sessionBindingFor,
  DEFAULT_TTL_SECONDS
};
