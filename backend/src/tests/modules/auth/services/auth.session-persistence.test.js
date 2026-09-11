/**
 * Session persistence service tests
 *
 * @module tests/modules/auth/services
 * @description Sessions must survive normal use and end only on a real policy
 * breach or an explicit logout. These cover the refresh-chain anchors, idle and
 * absolute enforcement, rotation, and logout revocation.
 */

jest.mock('@repositories/auth/auth.repository');
jest.mock('@lib/crypto');
jest.mock('@lib/jwt');
jest.mock('@lib/audit');
jest.mock('@lib/notifications');
jest.mock('@lib/subscriptions/tenant-entitlements', () => ({
  resolveTenantModuleEntitlements: jest.fn().mockResolvedValue([]),
}));
jest.mock('@lib/subscriptions/tenant-subscription-summary', () => ({
  resolveTenantSubscriptionSummary: jest.fn().mockResolvedValue({}),
  resolvePlatformAdminContact: jest.fn().mockReturnValue({
    email: 'platform.admin@hosspi.com',
    phone: '+256700000000',
  }),
}));
jest.mock('@lib/authorization/org-admin-contacts', () => ({
  resolveOrgAdminContacts: jest.fn().mockResolvedValue({
    tenant_admins: [],
    facility_admins: [],
    platform_admins: [],
  }),
}));
jest.mock('@config/env', () => ({
  NODE_ENV: 'production',
  JWT_SECRET: '12345678901234567890123456789012',
  APP_PUBLIC_URL: 'http://localhost:8081',
  APP_DISPLAY_NAME: 'Hospital Management System',
  APP_SHORT_NAME: 'HOSSPI HMS',
  ALLOW_PLAINTEXT_PASSWORD_EMAIL: false,
  JWT_ACCESS_TOKEN_EXPIRATION: '15m',
  JWT_REFRESH_TOKEN_EXPIRATION: '7d',
  AUTH_SESSION_TTL_DAYS: 7,
  AUTH_SESSION_IDLE_TIMEOUT_MINUTES: 10080,
  AUTH_SESSION_ABSOLUTE_TIMEOUT_HOURS: 720,
}));

const authService = require('@services/auth/auth.service');
const authRepository = require('@repositories/auth/auth.repository');
const { comparePassword } = require('@lib/crypto');
const { generateToken, generateRefreshToken } = require('@lib/jwt');
const { createAuditLog } = require('@lib/audit');

const MINUTE = 60 * 1000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;

const sessionUser = {
  id: 'user-123',
  email: 'nurse@example.com',
  tenant_id: '550e8400-e29b-41d4-a716-446655440000',
  facility_id: '550e8400-e29b-41d4-a716-446655440001',
  status: 'ACTIVE',
  email_verified_at: new Date('2026-01-01T00:00:00.000Z'),
  password_hash: 'hashedpassword',
  roles: [{ role: { name: 'NURSE' } }],
};

const storedSession = (overrides = {}) => ({
  id: 'session-old',
  user_id: sessionUser.id,
  refresh_token_hash: 'hash',
  expires_at: new Date(Date.now() + 3 * DAY),
  revoked_at: null,
  created_at: new Date(Date.now() - DAY),
  chain_started_at: new Date(Date.now() - DAY),
  last_used_at: new Date(Date.now() - HOUR),
  user: sessionUser,
  ...overrides,
});

beforeEach(() => {
  jest.clearAllMocks();
  generateToken.mockReturnValue('access-token');
  generateRefreshToken.mockReturnValue('refresh-token');
  createAuditLog.mockResolvedValue({});
  authRepository.createSession.mockResolvedValue({ id: 'session-new' });
  authRepository.revokeSession.mockResolvedValue({});
  authRepository.revokeAllUserSessions.mockResolvedValue({ count: 1 });
  authRepository.findUserById.mockResolvedValue(sessionUser);
  authRepository.getUserFacilities.mockResolvedValue([]);
});

describe('login', () => {
  it('anchors a new refresh chain so the absolute timeout has an origin', async () => {
    authRepository.findUserByEmailAndTenant.mockResolvedValue(sessionUser);
    comparePassword.mockResolvedValue(true);

    await authService.login({
      email: sessionUser.email,
      password: 'Password123!',
      tenant_id: sessionUser.tenant_id,
    });

    const created = authRepository.createSession.mock.calls[0][0];
    expect(created.chain_started_at).toBeInstanceOf(Date);
    expect(created.last_used_at).toEqual(created.chain_started_at);
    // A fresh chain gets the full refresh TTL; nothing clamps it yet.
    expect(created.expires_at.getTime()).toBeCloseTo(
      created.chain_started_at.getTime() + 7 * DAY,
      -3
    );
  });
});

describe('refresh', () => {
  it('rotates the token and carries the chain origin forward', async () => {
    const chainStartedAt = new Date(Date.now() - 5 * DAY);
    authRepository.findSessionByRefreshToken.mockResolvedValue(
      storedSession({ chain_started_at: chainStartedAt })
    );
    generateRefreshToken.mockReturnValue('rotated-refresh-token');

    const result = await authService.refresh({ refresh_token: 'old-refresh-token' });

    expect(result.refresh_token).toBe('rotated-refresh-token');
    // Old session revoked, new one written: rotation, not reuse.
    expect(authRepository.revokeSession).toHaveBeenCalledWith('session-old');
    const created = authRepository.createSession.mock.calls[0][0];
    expect(created.chain_started_at.getTime()).toBe(chainStartedAt.getTime());
    expect(created.last_used_at.getTime()).toBeGreaterThan(chainStartedAt.getTime());
  });

  it('never extends a chain past its absolute deadline', async () => {
    // 28 days into a 30-day ceiling: a plain 7-day TTL would overshoot it.
    const chainStartedAt = new Date(Date.now() - 28 * DAY);
    authRepository.findSessionByRefreshToken.mockResolvedValue(
      storedSession({ chain_started_at: chainStartedAt })
    );

    await authService.refresh({ refresh_token: 'old-refresh-token' });

    const created = authRepository.createSession.mock.calls[0][0];
    expect(created.expires_at.getTime()).toBe(chainStartedAt.getTime() + 720 * HOUR);
  });

  it('treats an expired access token as recoverable, not as the end of the session', async () => {
    // The stored session is healthy; only the bearer token has expired. The
    // refresh must succeed -- this is the everyday path, not an error path.
    authRepository.findSessionByRefreshToken.mockResolvedValue(storedSession());

    const result = await authService.refresh({ refresh_token: 'old-refresh-token' });

    expect(result).toHaveProperty('access_token', 'access-token');
    expect(authRepository.createSession).toHaveBeenCalled();
  });

  it('revokes a chain that breached the idle timeout', async () => {
    authRepository.findSessionByRefreshToken.mockResolvedValue(
      storedSession({
        chain_started_at: new Date(Date.now() - 10 * DAY),
        last_used_at: new Date(Date.now() - 8 * DAY),
      })
    );

    await expect(
      authService.refresh({ refresh_token: 'old-refresh-token' })
    ).rejects.toMatchObject({
      messageKey: 'errors.auth.session_idle_timeout',
      statusCode: 401,
    });

    expect(authRepository.revokeSession).toHaveBeenCalledWith('session-old');
    expect(authRepository.createSession).not.toHaveBeenCalled();
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'SESSION_POLICY_REVOKED',
        details: { reason: 'idle_timeout' },
      })
    );
  });

  it('revokes a chain past the absolute timeout even when it is actively used', async () => {
    authRepository.findSessionByRefreshToken.mockResolvedValue(
      storedSession({
        chain_started_at: new Date(Date.now() - 31 * DAY),
        last_used_at: new Date(Date.now() - MINUTE),
      })
    );

    await expect(
      authService.refresh({ refresh_token: 'old-refresh-token' })
    ).rejects.toMatchObject({
      messageKey: 'errors.auth.session_absolute_timeout',
      statusCode: 401,
    });

    expect(authRepository.revokeSession).toHaveBeenCalledWith('session-old');
    expect(authRepository.createSession).not.toHaveBeenCalled();
  });

  it('rejects a revoked refresh token', async () => {
    authRepository.findSessionByRefreshToken.mockResolvedValue(
      storedSession({ revoked_at: new Date() })
    );

    await expect(
      authService.refresh({ refresh_token: 'old-refresh-token' })
    ).rejects.toMatchObject({
      messageKey: 'errors.auth.session_revoked',
      statusCode: 401,
    });
  });

  it('rejects an unknown refresh token', async () => {
    authRepository.findSessionByRefreshToken.mockResolvedValue(null);

    await expect(
      authService.refresh({ refresh_token: 'never-issued' })
    ).rejects.toMatchObject({
      messageKey: 'errors.auth.refresh_token_invalid',
      statusCode: 401,
    });
  });

  it('still refreshes a session written before the lifetime columns existed', async () => {
    authRepository.findSessionByRefreshToken.mockResolvedValue(
      storedSession({
        chain_started_at: null,
        last_used_at: null,
        created_at: new Date(Date.now() - 2 * DAY),
      })
    );

    await authService.refresh({ refresh_token: 'old-refresh-token' });

    const created = authRepository.createSession.mock.calls[0][0];
    // The legacy row creation time becomes the chain origin rather than the
    // epoch, so a pre-migration session is not revoked for being too old.
    expect(created.chain_started_at.getTime()).toBeCloseTo(Date.now() - 2 * DAY, -4);
  });
});

describe('logout', () => {
  it('revokes the server-side session for the presented refresh token', async () => {
    authRepository.findSessionByRefreshToken.mockResolvedValue(storedSession());

    await authService.logout({
      user_id: sessionUser.id,
      refresh_token: 'old-refresh-token',
    });

    expect(authRepository.revokeSession).toHaveBeenCalledWith('session-old');
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'USER_LOGOUT' })
    );
  });

  it('revokes every session when no refresh token is presented', async () => {
    await authService.logout({ user_id: sessionUser.id });

    expect(authRepository.revokeAllUserSessions).toHaveBeenCalledWith(sessionUser.id);
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'USER_LOGOUT_ALL' })
    );
  });
});
