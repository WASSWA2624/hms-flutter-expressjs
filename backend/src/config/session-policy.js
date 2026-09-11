/**
 * Session Lifetime Policy
 *
 * One place that answers "how long may a session live?" so login, refresh, and
 * the tests cannot drift apart, and so the answer is identical under
 * `NODE_ENV=development` and `NODE_ENV=production` -- the policy is read from
 * configuration, never from the environment name.
 *
 * Four independent limits, all configurable:
 *
 *   1. Access-token TTL   (`JWT_ACCESS_TOKEN_EXPIRATION`)  -- how long a bearer
 *      token is accepted. Expiry here is a NORMAL, RECOVERABLE event: the
 *      client refreshes and carries on. It never ends a session.
 *   2. Refresh-token TTL  (`AUTH_SESSION_TTL_DAYS`)        -- how long one
 *      issued refresh token stays usable. Rotation restarts this window.
 *   3. Idle timeout       (`AUTH_SESSION_IDLE_TIMEOUT_MINUTES`) -- how long a
 *      chain may go without a successful refresh before it is revoked.
 *   4. Absolute timeout   (`AUTH_SESSION_ABSOLUTE_TIMEOUT_HOURS`) -- the hard
 *      ceiling measured from the original sign-in. Rotation cannot push a chain
 *      past it, so a session cannot live forever by refreshing.
 *
 * A "chain" is the sequence of sessions produced by rotating a refresh token.
 * Every rotation writes a new `user_session` row and revokes the previous one,
 * but `chain_started_at` is inherited, so the absolute deadline survives
 * rotation while `last_used_at` resets.
 *
 * @module config/session-policy
 */

const env = require('@config/env');

const MS_PER_MINUTE = 60 * 1000;
const MS_PER_HOUR = 60 * MS_PER_MINUTE;
const MS_PER_DAY = 24 * MS_PER_HOUR;

/**
 * Resolve the configured policy.
 *
 * Read on each call rather than captured at module load so tests (and a config
 * reload) observe the current environment without re-requiring the module.
 *
 * @returns {{accessTokenExpiration: string, refreshTokenExpiration: string,
 *   sessionTtlDays: number, sessionTtlMs: number, idleTimeoutMinutes: number,
 *   idleTimeoutMs: number, absoluteTimeoutHours: number,
 *   absoluteTimeoutMs: number}} Resolved policy
 */
const getSessionPolicy = () => {
  const sessionTtlDays = Number(env.AUTH_SESSION_TTL_DAYS || 7);
  const idleTimeoutMinutes = Number(env.AUTH_SESSION_IDLE_TIMEOUT_MINUTES || 10080);
  const absoluteTimeoutHours = Number(env.AUTH_SESSION_ABSOLUTE_TIMEOUT_HOURS || 720);

  return {
    accessTokenExpiration: env.JWT_ACCESS_TOKEN_EXPIRATION || '15m',
    refreshTokenExpiration: env.JWT_REFRESH_TOKEN_EXPIRATION || '7d',
    sessionTtlDays,
    sessionTtlMs: sessionTtlDays * MS_PER_DAY,
    idleTimeoutMinutes,
    idleTimeoutMs: idleTimeoutMinutes * MS_PER_MINUTE,
    absoluteTimeoutHours,
    absoluteTimeoutMs: absoluteTimeoutHours * MS_PER_HOUR
  };
};

/**
 * Coerce a stored timestamp to a Date, or null when it is absent/unparseable.
 *
 * Sessions written before the lifetime columns existed have NULL for both, and
 * a null anchor must not be read as "epoch" -- that would revoke every legacy
 * session on its next refresh.
 *
 * @param {Date|string|null|undefined} value - Stored timestamp
 * @returns {Date|null} Parsed date or null
 */
const toDateOrNull = (value) => {
  if (value === null || value === undefined) return null;
  const parsed = value instanceof Date ? value : new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

/**
 * Absolute deadline for a chain that began at `chainStartedAt`.
 *
 * @param {Date|string|null} chainStartedAt - When the chain's first session was created
 * @returns {Date|null} Deadline, or null when the chain origin is unknown
 */
const resolveAbsoluteDeadline = (chainStartedAt) => {
  const startedAt = toDateOrNull(chainStartedAt);
  if (!startedAt) return null;

  return new Date(startedAt.getTime() + getSessionPolicy().absoluteTimeoutMs);
};

/**
 * Expiry for a refresh token issued now.
 *
 * The refresh TTL is clamped to the chain's absolute deadline so a rotated
 * token never outlives the ceiling. A chain with no recorded origin (a legacy
 * row) falls back to the plain TTL.
 *
 * @param {Object} [options] - Options
 * @param {Date|string|null} [options.chainStartedAt] - Chain origin; defaults to now
 * @param {Date} [options.now] - Clock injection point for tests
 * @returns {Date} Refresh-token expiry
 */
const resolveSessionExpiry = ({ chainStartedAt = null, now = new Date() } = {}) => {
  const ttlExpiry = new Date(now.getTime() + getSessionPolicy().sessionTtlMs);
  const absoluteDeadline = resolveAbsoluteDeadline(chainStartedAt || now);
  if (!absoluteDeadline) return ttlExpiry;

  return absoluteDeadline < ttlExpiry ? absoluteDeadline : ttlExpiry;
};

/**
 * Decide whether a stored session may still be refreshed.
 *
 * Only a policy breach ends a session here. Transport failures and expired
 * access tokens never reach this function -- they are recoverable by design.
 *
 * @param {Object} session - Stored `user_session` row
 * @param {Object} [options] - Options
 * @param {Date} [options.now] - Clock injection point for tests
 * @returns {{allowed: boolean, reason: string|null, messageKey: string|null}} Verdict
 */
const evaluateSessionLifetime = (session, { now = new Date() } = {}) => {
  const policy = getSessionPolicy();

  const chainStartedAt = toDateOrNull(session?.chain_started_at);
  if (chainStartedAt && now.getTime() - chainStartedAt.getTime() > policy.absoluteTimeoutMs) {
    return {
      allowed: false,
      reason: 'absolute_timeout',
      messageKey: 'errors.auth.session_absolute_timeout'
    };
  }

  // Fall back to the row's creation time so a session written before the
  // lifetime columns existed is still held to the idle rule.
  const lastUsedAt = toDateOrNull(session?.last_used_at) || toDateOrNull(session?.created_at);
  if (lastUsedAt && now.getTime() - lastUsedAt.getTime() > policy.idleTimeoutMs) {
    return {
      allowed: false,
      reason: 'idle_timeout',
      messageKey: 'errors.auth.session_idle_timeout'
    };
  }

  return { allowed: true, reason: null, messageKey: null };
};

module.exports = {
  getSessionPolicy,
  resolveAbsoluteDeadline,
  resolveSessionExpiry,
  evaluateSessionLifetime
};
