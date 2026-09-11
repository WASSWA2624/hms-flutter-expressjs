/**
 * Registration truthfulness service tests
 *
 * @module tests/modules/auth/services
 * @description The client must never be told registration failed when an
 * account exists. These cover the four registration outcomes, idempotent
 * replay, the email-failure path, duplicate submissions, and the status lookup.
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
  ALLOW_PLAINTEXT_PASSWORD_EMAIL: false,
  AUTH_SESSION_TTL_DAYS: 7,
  REGISTRATION_IDEMPOTENCY_TTL_HOURS: 24,
}));

const authService = require('@services/auth/auth.service');
const authRepository = require('@repositories/auth/auth.repository');
const { hashPassword } = require('@lib/crypto');
const { createAuditLog } = require('@lib/audit');
const { sendEmail } = require('@lib/notifications');
const { HttpError } = require('@lib/errors');

const IDEMPOTENCY_KEY = 'f1a2b3c4-0000-4000-8000-000000000001';

const registerData = {
  email: 'Owner@Example.com',
  password: 'Password123!',
  facility_name: 'Mirembe Clinic',
  admin_name: 'Jane Doe',
  facility_type: 'CLINIC',
  phone: '256701234567',
  ip_address: '127.0.0.1',
  user_agent: 'Mozilla',
  idempotency_key: IDEMPOTENCY_KEY,
};

const createdUser = {
  id: 'user-123',
  email: 'owner@example.com',
  tenant_id: 'tenant-123',
  facility_id: 'facility-123',
  status: 'PENDING',
  password_hash: 'hashedpassword',
};

const mockFreshAttempt = () => {
  authRepository.beginRegistrationAttempt.mockResolvedValue({
    attempt: { id: 'attempt-1', status: 'IN_PROGRESS', email: 'owner@example.com' },
    replayed: false,
  });
};

describe('Registration truthfulness', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    hashPassword.mockResolvedValue('hashedpassword');
    sendEmail.mockResolvedValue({ sent: true, provider: 'smtp' });
    createAuditLog.mockResolvedValue({});
    authRepository.findUserByEmail.mockResolvedValue(null);
    authRepository.registerFacilityOwner.mockResolvedValue(createdUser);
    authRepository.createVerificationToken.mockResolvedValue({});
    authRepository.deleteExpiredTokens.mockResolvedValue({});
    authRepository.upsertRegistrationFollowUp.mockResolvedValue({});
    authRepository.completeRegistrationAttempt.mockResolvedValue({});
    authRepository.releaseRegistrationAttempt.mockResolvedValue(undefined);
  });

  describe('outcome codes', () => {
    it('reports ACCOUNT_CREATED_EMAIL_SENT when the verification email is accepted', async () => {
      mockFreshAttempt();

      const result = await authService.register(registerData);

      expect(result.outcome).toBe('ACCOUNT_CREATED_EMAIL_SENT');
      expect(result.verification.email_status).toBe('SENT');
      expect(result.user).not.toHaveProperty('password_hash');
      expect(authRepository.registerFacilityOwner).toHaveBeenCalledWith(
        expect.objectContaining({ registration_attempt_id: 'attempt-1' })
      );
      expect(authRepository.completeRegistrationAttempt).toHaveBeenCalledWith(
        'attempt-1',
        expect.objectContaining({
          status: 'SUCCEEDED',
          outcome_code: 'ACCOUNT_CREATED_EMAIL_SENT',
          email_status: 'SENT',
          user_id: 'user-123',
        })
      );
    });

    it('reports ACCOUNT_CREATED_EMAIL_PENDING when the transport refuses the email', async () => {
      mockFreshAttempt();
      sendEmail.mockResolvedValue({ sent: false, provider: 'smtp' });

      const result = await authService.register(registerData);

      expect(result.outcome).toBe('ACCOUNT_CREATED_EMAIL_PENDING');
      expect(result.verification.email_status).toBe('FAILED');
      expect(result.user).toHaveProperty('id', 'user-123');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({ action: 'USER_REGISTERED' })
      );
    });

    it('keeps the account when email delivery throws', async () => {
      mockFreshAttempt();
      sendEmail.mockRejectedValue(new Error('SMTP unreachable'));

      const result = await authService.register(registerData);

      expect(result.outcome).toBe('ACCOUNT_CREATED_EMAIL_PENDING');
      expect(result.user).toHaveProperty('id', 'user-123');
      expect(authRepository.completeRegistrationAttempt).toHaveBeenCalledWith(
        'attempt-1',
        expect.objectContaining({ status: 'SUCCEEDED' })
      );
    });

    it('keeps the account when the verification code cannot be issued', async () => {
      mockFreshAttempt();
      authRepository.createVerificationToken.mockRejectedValue(
        new Error('verification_token table unavailable')
      );

      const result = await authService.register(registerData);

      expect(result.outcome).toBe('ACCOUNT_CREATED_EMAIL_PENDING');
      expect(result.user).toHaveProperty('id', 'user-123');
      expect(sendEmail).not.toHaveBeenCalled();
      expect(authRepository.releaseRegistrationAttempt).not.toHaveBeenCalled();
      expect(authRepository.completeRegistrationAttempt).toHaveBeenCalledWith(
        'attempt-1',
        expect.objectContaining({ status: 'SUCCEEDED' })
      );
    });

    it('reports REGISTRATION_IN_PROGRESS while the first submission is still running', async () => {
      authRepository.beginRegistrationAttempt.mockResolvedValue({
        attempt: {
          id: 'attempt-1',
          status: 'IN_PROGRESS',
          email: 'owner@example.com',
          email_status: 'PENDING',
        },
        replayed: true,
      });

      const result = await authService.register(registerData);

      expect(result.outcome).toBe('REGISTRATION_IN_PROGRESS');
      expect(result.replayed).toBe(true);
      expect(authRepository.registerFacilityOwner).not.toHaveBeenCalled();
    });

    it('replays the original rejection for a repeated key', async () => {
      authRepository.beginRegistrationAttempt.mockResolvedValue({
        attempt: {
          id: 'attempt-1',
          status: 'REJECTED',
          error_code: 'errors.auth.account_suspended',
          error_status_code: 403,
          result_json: { errors: [] },
        },
        replayed: true,
      });

      await expect(authService.register(registerData)).rejects.toMatchObject({
        messageKey: 'errors.auth.account_suspended',
        statusCode: 403,
      });
      expect(authRepository.registerFacilityOwner).not.toHaveBeenCalled();
    });
  });

  describe('idempotent replay', () => {
    it('returns the original result without creating a second workspace', async () => {
      const storedResult = {
        user: { id: 'user-123', tenant_id: 'tenant-123', facility_id: 'facility-123' },
        outcome: 'ACCOUNT_CREATED_EMAIL_SENT',
        flow: 'NEW_REGISTRATION',
        next_path: '/login',
        verification: { email: 'owner@example.com', email_status: 'SENT' },
      };
      authRepository.beginRegistrationAttempt.mockResolvedValue({
        attempt: { id: 'attempt-1', status: 'SUCCEEDED', result_json: storedResult },
        replayed: true,
      });

      const result = await authService.register(registerData);

      expect(result).toMatchObject(storedResult);
      expect(result.replayed).toBe(true);
      expect(authRepository.registerFacilityOwner).not.toHaveBeenCalled();
      expect(authRepository.createVerificationToken).not.toHaveBeenCalled();
      expect(sendEmail).not.toHaveBeenCalled();
    });

    it('still reports the truth when the stored payload was lost', async () => {
      authRepository.beginRegistrationAttempt.mockResolvedValue({
        attempt: {
          id: 'attempt-1',
          status: 'SUCCEEDED',
          outcome_code: 'ACCOUNT_CREATED_EMAIL_SENT',
          email_status: 'SENT',
          email: 'owner@example.com',
          result_json: null,
        },
        replayed: true,
      });

      const result = await authService.register(registerData);

      expect(result.outcome).toBe('ACCOUNT_CREATED_EMAIL_SENT');
      expect(authRepository.registerFacilityOwner).not.toHaveBeenCalled();
    });

    it('registers without a key when attempt tracking is unavailable', async () => {
      authRepository.beginRegistrationAttempt.mockResolvedValue(null);

      const result = await authService.register(registerData);

      expect(result.outcome).toBe('ACCOUNT_CREATED_EMAIL_SENT');
      expect(authRepository.registerFacilityOwner).toHaveBeenCalledWith(
        expect.objectContaining({ registration_attempt_id: null })
      );
    });
  });

  describe('duplicate submissions', () => {
    it('resends verification instead of bootstrapping a second tenant', async () => {
      mockFreshAttempt();
      authRepository.findUserByEmail.mockResolvedValue({
        id: 'user-123',
        email: 'owner@example.com',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        status: 'PENDING',
        profile: { first_name: 'Jane', last_name: 'Doe' },
        tenant: { name: 'Mirembe Clinic' },
        facility: { name: 'Mirembe Clinic', facility_type: 'CLINIC' },
      });

      const result = await authService.register({
        ...registerData,
        idempotency_key: 'f1a2b3c4-0000-4000-8000-000000000002',
      });

      expect(result.flow).toBe('EXISTING_PENDING_ACCOUNT');
      expect(result.outcome).toBe('ACCOUNT_CREATED_EMAIL_SENT');
      expect(authRepository.registerFacilityOwner).not.toHaveBeenCalled();
    });

    it('recovers from a concurrent bootstrap that lost the email claim', async () => {
      mockFreshAttempt();
      authRepository.registerFacilityOwner.mockRejectedValue(
        new HttpError('errors.auth.user_exists', 409)
      );
      authRepository.findUserByEmail
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce({
          id: 'user-999',
          email: 'owner@example.com',
          tenant_id: 'tenant-999',
          facility_id: 'facility-999',
          status: 'PENDING',
          profile: { first_name: 'Jane', last_name: 'Doe' },
          tenant: { name: 'Mirembe Clinic' },
          facility: { name: 'Mirembe Clinic', facility_type: 'CLINIC' },
        });

      const result = await authService.register(registerData);

      expect(result.user.id).toBe('user-999');
      expect(result.flow).toBe('EXISTING_PENDING_ACCOUNT');
      expect(authRepository.registerFacilityOwner).toHaveBeenCalledTimes(1);
    });
  });

  describe('failed attempts', () => {
    it('records a client rejection so the same key replays it', async () => {
      mockFreshAttempt();
      authRepository.findUserByEmail.mockResolvedValue({
        id: 'user-123',
        email: 'owner@example.com',
        status: 'SUSPENDED',
      });

      await expect(authService.register(registerData)).rejects.toMatchObject({
        statusCode: 403,
      });

      expect(authRepository.completeRegistrationAttempt).toHaveBeenCalledWith(
        'attempt-1',
        expect.objectContaining({
          status: 'REJECTED',
          outcome_code: 'REGISTRATION_REJECTED',
          error_status_code: 403,
        })
      );
      expect(authRepository.releaseRegistrationAttempt).not.toHaveBeenCalled();
    });

    it('frees the key after an infrastructure failure so a retry can proceed', async () => {
      mockFreshAttempt();
      authRepository.registerFacilityOwner.mockRejectedValue(new Error('connection lost'));

      await expect(authService.register(registerData)).rejects.toThrow('connection lost');

      expect(authRepository.releaseRegistrationAttempt).toHaveBeenCalledWith('attempt-1');
      expect(authRepository.completeRegistrationAttempt).not.toHaveBeenCalled();
    });
  });

  describe('getRegistrationStatus', () => {
    it('reports REGISTRATION_UNKNOWN for a key the backend never saw', async () => {
      authRepository.findRegistrationAttemptByKey.mockResolvedValue(null);

      const result = await authService.getRegistrationStatus({
        idempotency_key: IDEMPOTENCY_KEY,
      });

      expect(result.outcome).toBe('REGISTRATION_UNKNOWN');
      expect(result.user).toBeNull();
    });

    it('reports REGISTRATION_UNKNOWN when no key is supplied', async () => {
      const result = await authService.getRegistrationStatus({});

      expect(result.outcome).toBe('REGISTRATION_UNKNOWN');
      expect(authRepository.findRegistrationAttemptByKey).not.toHaveBeenCalled();
    });

    it('reports the created account after a client timeout', async () => {
      authRepository.findRegistrationAttemptByKey.mockResolvedValue({
        id: 'attempt-1',
        status: 'SUCCEEDED',
        result_json: {
          user: { id: 'user-123' },
          outcome: 'ACCOUNT_CREATED_EMAIL_SENT',
          flow: 'NEW_REGISTRATION',
          next_path: '/login',
          verification: { email: 'owner@example.com', email_status: 'SENT' },
        },
      });

      const result = await authService.getRegistrationStatus({
        idempotency_key: IDEMPOTENCY_KEY,
      });

      expect(result.outcome).toBe('ACCOUNT_CREATED_EMAIL_SENT');
      expect(result.user.id).toBe('user-123');
      expect(result.next_path).toBe('/login');
    });

    it('reports an account created with a delayed email', async () => {
      authRepository.findRegistrationAttemptByKey.mockResolvedValue({
        id: 'attempt-1',
        status: 'SUCCEEDED',
        outcome_code: 'ACCOUNT_CREATED_EMAIL_PENDING',
        email_status: 'FAILED',
        email: 'owner@example.com',
        result_json: null,
      });

      const result = await authService.getRegistrationStatus({
        idempotency_key: IDEMPOTENCY_KEY,
      });

      expect(result.outcome).toBe('ACCOUNT_CREATED_EMAIL_PENDING');
      expect(result.verification.email_status).toBe('FAILED');
    });

    it('reports an attempt that is still running', async () => {
      authRepository.findRegistrationAttemptByKey.mockResolvedValue({
        id: 'attempt-1',
        status: 'IN_PROGRESS',
        email: 'owner@example.com',
        email_status: 'PENDING',
      });

      const result = await authService.getRegistrationStatus({
        idempotency_key: IDEMPOTENCY_KEY,
      });

      expect(result.outcome).toBe('REGISTRATION_IN_PROGRESS');
    });

    it('reports a rejection with its code instead of throwing', async () => {
      authRepository.findRegistrationAttemptByKey.mockResolvedValue({
        id: 'attempt-1',
        status: 'REJECTED',
        error_code: 'errors.auth.account_suspended',
        error_status_code: 403,
      });

      const result = await authService.getRegistrationStatus({
        idempotency_key: IDEMPOTENCY_KEY,
      });

      expect(result.outcome).toBe('REGISTRATION_REJECTED');
      expect(result.rejection).toEqual({
        code: 'errors.auth.account_suspended',
        status: 403,
      });
    });

    it('never returns credentials or verification codes', async () => {
      authRepository.findRegistrationAttemptByKey.mockResolvedValue({
        id: 'attempt-1',
        status: 'SUCCEEDED',
        result_json: {
          user: { id: 'user-123', email: 'owner@example.com' },
          outcome: 'ACCOUNT_CREATED_EMAIL_SENT',
          verification: { email: 'owner@example.com', email_status: 'SENT' },
        },
      });

      const result = await authService.getRegistrationStatus({
        idempotency_key: IDEMPOTENCY_KEY,
      });

      const serialized = JSON.stringify(result);
      expect(serialized).not.toContain('password');
      expect(serialized).not.toMatch(/"code"\s*:\s*"\d{6}"/);
    });
  });
});
