/**
 * Session lifetime policy tests
 *
 * @module tests/config
 * @description The policy decides when a session may still be refreshed. These
 * pin the three rules that matter: an expired access token is recoverable, an
 * idle chain is revoked, and rotation cannot push a chain past its absolute
 * ceiling.
 */

jest.mock('@config/env', () => ({
  NODE_ENV: 'production',
  JWT_ACCESS_TOKEN_EXPIRATION: '15m',
  JWT_REFRESH_TOKEN_EXPIRATION: '7d',
  AUTH_SESSION_TTL_DAYS: 7,
  AUTH_SESSION_IDLE_TIMEOUT_MINUTES: 10080,
  AUTH_SESSION_ABSOLUTE_TIMEOUT_HOURS: 720
}));

const env = require('@config/env');
const {
  getSessionPolicy,
  resolveAbsoluteDeadline,
  resolveSessionExpiry,
  evaluateSessionLifetime
} = require('@config/session-policy');

const MINUTE = 60 * 1000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;

const NOW = new Date('2026-09-11T12:00:00.000Z');

const sessionAt = ({ chainStartedAt, lastUsedAt, createdAt }) => ({
  chain_started_at: chainStartedAt,
  last_used_at: lastUsedAt,
  created_at: createdAt
});

describe('getSessionPolicy', () => {
  it('reads every limit from configuration, never from NODE_ENV', () => {
    const policy = getSessionPolicy();

    expect(policy.accessTokenExpiration).toBe('15m');
    expect(policy.refreshTokenExpiration).toBe('7d');
    expect(policy.sessionTtlDays).toBe(7);
    expect(policy.idleTimeoutMs).toBe(10080 * MINUTE);
    expect(policy.absoluteTimeoutMs).toBe(720 * HOUR);
  });

  it('follows a configuration change without re-requiring the module', () => {
    env.AUTH_SESSION_IDLE_TIMEOUT_MINUTES = 30;
    try {
      expect(getSessionPolicy().idleTimeoutMs).toBe(30 * MINUTE);
    } finally {
      env.AUTH_SESSION_IDLE_TIMEOUT_MINUTES = 10080;
    }
  });
});

describe('resolveSessionExpiry', () => {
  it('issues a full refresh TTL for a chain that just started', () => {
    const expiry = resolveSessionExpiry({ chainStartedAt: NOW, now: NOW });

    expect(expiry.getTime()).toBe(NOW.getTime() + 7 * DAY);
  });

  it('clamps a rotation to the absolute deadline instead of extending past it', () => {
    // 29 days into a 30-day chain: a plain 7-day TTL would run 6 days past the
    // ceiling, which is how a session becomes immortal by refreshing.
    const chainStartedAt = new Date(NOW.getTime() - 29 * DAY);

    const expiry = resolveSessionExpiry({ chainStartedAt, now: NOW });

    expect(expiry.getTime()).toBe(chainStartedAt.getTime() + 720 * HOUR);
    expect(expiry.getTime()).toBeLessThan(NOW.getTime() + 7 * DAY);
  });

  it('falls back to the plain TTL when the chain origin is unknown', () => {
    const expiry = resolveSessionExpiry({ chainStartedAt: null, now: NOW });

    expect(expiry.getTime()).toBe(NOW.getTime() + 7 * DAY);
  });

  it('reports the deadline for a chain', () => {
    const chainStartedAt = new Date(NOW.getTime() - 2 * DAY);

    expect(resolveAbsoluteDeadline(chainStartedAt).getTime()).toBe(
      chainStartedAt.getTime() + 720 * HOUR
    );
    expect(resolveAbsoluteDeadline(null)).toBeNull();
  });
});

describe('evaluateSessionLifetime', () => {
  it('allows a chain that is inside both limits', () => {
    const session = sessionAt({
      chainStartedAt: new Date(NOW.getTime() - 3 * DAY),
      lastUsedAt: new Date(NOW.getTime() - 2 * HOUR)
    });

    expect(evaluateSessionLifetime(session, { now: NOW })).toEqual({
      allowed: true,
      reason: null,
      messageKey: null
    });
  });

  it('revokes a chain that has gone unused past the idle timeout', () => {
    const session = sessionAt({
      chainStartedAt: new Date(NOW.getTime() - 10 * DAY),
      lastUsedAt: new Date(NOW.getTime() - 8 * DAY)
    });

    expect(evaluateSessionLifetime(session, { now: NOW })).toEqual({
      allowed: false,
      reason: 'idle_timeout',
      messageKey: 'errors.auth.session_idle_timeout'
    });
  });

  it('revokes a chain past its absolute deadline even when it is actively used', () => {
    const session = sessionAt({
      chainStartedAt: new Date(NOW.getTime() - 31 * DAY),
      lastUsedAt: new Date(NOW.getTime() - MINUTE)
    });

    expect(evaluateSessionLifetime(session, { now: NOW })).toEqual({
      allowed: false,
      reason: 'absolute_timeout',
      messageKey: 'errors.auth.session_absolute_timeout'
    });
  });

  it('holds a row written before the policy to the idle rule via created_at', () => {
    const session = sessionAt({
      chainStartedAt: null,
      lastUsedAt: null,
      createdAt: new Date(NOW.getTime() - 8 * DAY)
    });

    expect(evaluateSessionLifetime(session, { now: NOW }).reason).toBe('idle_timeout');
  });

  it('never revokes a row it cannot date', () => {
    const session = sessionAt({ chainStartedAt: null, lastUsedAt: null, createdAt: null });

    expect(evaluateSessionLifetime(session, { now: NOW }).allowed).toBe(true);
  });
});
