/**
 * Auth service tests
 *
 * @module tests/modules/auth/services
 */

// Mock dependencies
jest.mock('@repositories/auth/auth.repository');
jest.mock('@lib/crypto');
jest.mock('@lib/jwt');
jest.mock('@lib/audit');
jest.mock('@lib/notifications');
jest.mock('@config/env', () => ({
  JWT_SECRET: '12345678901234567890123456789012',
  APP_PUBLIC_URL: 'http://localhost:8081',
  APP_DISPLAY_NAME: 'Hospital Management System',
  ALLOW_PLAINTEXT_PASSWORD_EMAIL: false,
  AUTH_SESSION_TTL_DAYS: 7,
}));

const authService = require('@services/auth/auth.service');
const authRepository = require('@repositories/auth/auth.repository');
const { hashPassword, comparePassword } = require('@lib/crypto');
const { generateToken, generateRefreshToken } = require('@lib/jwt');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { sendEmail } = require('@lib/notifications');

describe('Auth Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    authRepository.getUserFacilities.mockResolvedValue([]);
    sendEmail.mockResolvedValue({ sent: true, provider: 'smtp' });
  });

  describe('login', () => {
    it('should login user with valid credentials', async () => {
      const loginData = {
        email: 'test@example.com',
        password: 'Password123!',
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        ip_address: '127.0.0.1',
        user_agent: 'Mozilla'
      };

      const mockUser = {
        id: 'user-123',
        email: 'test@example.com',
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'ACTIVE',
        password_hash: 'hashedpassword',
        roles: [{ role: { name: 'DOCTOR' } }]
      };

      authRepository.findUserByEmailAndTenant.mockResolvedValue(mockUser);
      comparePassword.mockResolvedValue(true);
      generateToken.mockReturnValue('access-token');
      generateRefreshToken.mockReturnValue('refresh-token');
      authRepository.createSession.mockResolvedValue({ id: 'session-123' });
      createAuditLog.mockResolvedValue({});

      const result = await authService.login(loginData);

      expect(result).toHaveProperty('access_token', 'access-token');
      expect(result).toHaveProperty('refresh_token', 'refresh-token');
      expect(result).toHaveProperty('user');
      expect(result.user).not.toHaveProperty('password_hash');
      expect(generateToken).toHaveBeenCalledWith(expect.objectContaining({
        permissions: [],
      }));
      expect(authRepository.createSession).toHaveBeenCalled();
      expect(authRepository.createSession).toHaveBeenCalledWith(expect.objectContaining({
        expires_at: expect.any(Date),
      }));
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'USER_LOGIN'
      }));
    });

    it('should include direct permissions in the token and auth user payload', async () => {
      const loginData = {
        email: 'test@example.com',
        password: 'Password123!',
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      };

      const mockUser = {
        id: 'user-123',
        email: 'test@example.com',
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'ACTIVE',
        password_hash: 'hashedpassword',
        permissions: [
          { permission_id: 'perm-1', permission: { id: 'perm-1', name: 'patient:read' } },
          { permission_id: 'perm-2', permission: { id: 'perm-2', name: 'patient:write' } },
        ],
        roles: [{ role: { name: 'DOCTOR', permissions: [] } }],
      };

      authRepository.findUserByEmailAndTenant.mockResolvedValue(mockUser);
      comparePassword.mockResolvedValue(true);
      generateToken.mockReturnValue('access-token');
      generateRefreshToken.mockReturnValue('refresh-token');
      authRepository.createSession.mockResolvedValue({ id: 'session-123' });
      createAuditLog.mockResolvedValue({});

      const result = await authService.login(loginData);

      expect(generateToken).toHaveBeenCalledWith(expect.objectContaining({
        permissions: ['patient:read', 'patient:write'],
      }));
      expect(result.user.permissions).toEqual(['patient:read', 'patient:write']);
    });

    it('should login user with phone number', async () => {
      const loginData = {
        phone: '256701234567',
        password: 'Password123!',
        tenant_id: '550e8400-e29b-41d4-a716-446655440000'
      };

      const mockUser = {
        id: 'user-123',
        phone: '256701234567',
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'ACTIVE',
        password_hash: 'hashedpassword',
        roles: [{ role: { name: 'DOCTOR' } }]
      };

      authRepository.findUserByPhoneAndTenant.mockResolvedValue(mockUser);
      comparePassword.mockResolvedValue(true);
      generateToken.mockReturnValue('access-token');
      generateRefreshToken.mockReturnValue('refresh-token');
      authRepository.createSession.mockResolvedValue({ id: 'session-123' });
      createAuditLog.mockResolvedValue({});

      const result = await authService.login(loginData);

      expect(result).toHaveProperty('access_token', 'access-token');
      expect(result).toHaveProperty('refresh_token', 'refresh-token');
      expect(authRepository.findUserByPhoneAndTenant).toHaveBeenCalledWith(
        '256701234567',
        '550e8400-e29b-41d4-a716-446655440000'
      );
    });

    it('should reject login with invalid credentials', async () => {
      const loginData = {
        email: 'test@example.com',
        password: 'WrongPassword',
        tenant_id: '550e8400-e29b-41d4-a716-446655440000'
      };

      authRepository.findUserByEmailAndTenant.mockResolvedValue(null);

      await expect(authService.login(loginData))
        .rejects
        .toThrow(HttpError);
      await expect(authService.login(loginData))
        .rejects
        .toMatchObject({ statusCode: 401 });
    });

    it('should reject login with invalid phone credentials', async () => {
      const loginData = {
        phone: '256701234567',
        password: 'WrongPassword',
        tenant_id: '550e8400-e29b-41d4-a716-446655440000'
      };

      authRepository.findUserByPhoneAndTenant.mockResolvedValue(null);

      await expect(authService.login(loginData))
        .rejects
        .toThrow(HttpError);
      await expect(authService.login(loginData))
        .rejects
        .toMatchObject({ statusCode: 401 });
    });

    it('should reject login for inactive user', async () => {
      const loginData = {
        email: 'test@example.com',
        password: 'Password123!',
        tenant_id: '550e8400-e29b-41d4-a716-446655440000'
      };

      const mockUser = {
        id: 'user-123',
        status: 'SUSPENDED',
        password_hash: 'hashedpassword'
      };

      authRepository.findUserByEmailAndTenant.mockResolvedValue(mockUser);

      await expect(authService.login(loginData))
        .rejects
        .toThrow(HttpError);
      await expect(authService.login(loginData))
        .rejects
        .toMatchObject({ statusCode: 403 });
    });

    it('should reject login with wrong password', async () => {
      const loginData = {
        email: 'test@example.com',
        password: 'WrongPassword',
        tenant_id: '550e8400-e29b-41d4-a716-446655440000'
      };

      const mockUser = {
        id: 'user-123',
        status: 'ACTIVE',
        password_hash: 'hashedpassword'
      };

      authRepository.findUserByEmailAndTenant.mockResolvedValue(mockUser);
      comparePassword.mockResolvedValue(false);

      await expect(authService.login(loginData))
        .rejects
        .toThrow(HttpError);
      await expect(authService.login(loginData))
        .rejects
        .toMatchObject({ statusCode: 401 });
    });

    it('should require email verification for pending user when tenant is not provided', async () => {
      const loginData = {
        email: 'pending@example.com',
        password: 'Password123!',
      };

      authRepository.findUsersByIdentifier.mockResolvedValue([
        {
          id: 'user-pending-1',
          email: 'pending@example.com',
          tenant_id: 'tenant-123',
          status: 'PENDING',
          password_hash: 'hashedpassword',
        },
      ]);

      await expect(authService.login(loginData))
        .rejects
        .toMatchObject({ statusCode: 403, messageKey: 'errors.auth.account_pending' });
    });

    it('hydrates roles before issuing a token when tenant selection is implicit', async () => {
      const loginData = {
        email: 'tenant-admin@example.com',
        password: 'Password123!',
      };

      authRepository.findUsersByIdentifier.mockResolvedValue([
        {
          id: 'user-123',
          email: 'tenant-admin@example.com',
          tenant_id: 'tenant-123',
          status: 'ACTIVE',
          password_hash: 'hashedpassword',
        },
      ]);
      authRepository.findUserById.mockResolvedValue({
        id: 'user-123',
        email: 'tenant-admin@example.com',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        status: 'ACTIVE',
        password_hash: 'hashedpassword',
        roles: [{ role: { name: 'TENANT_ADMIN', permissions: [] } }],
      });
      comparePassword.mockResolvedValue(true);
      generateToken.mockReturnValue('access-token');
      generateRefreshToken.mockReturnValue('refresh-token');
      authRepository.createSession.mockResolvedValue({ id: 'session-123' });
      createAuditLog.mockResolvedValue({});

      const result = await authService.login(loginData);

      expect(authRepository.findUserById).toHaveBeenCalledWith('user-123');
      expect(generateToken).toHaveBeenCalledWith(expect.objectContaining({
        roles: ['TENANT_ADMIN'],
      }));
      expect(result.user.roles).toEqual([
        { role: { name: 'TENANT_ADMIN', permissions: [] } },
      ]);
    });

    it('should allow privileged users to login without MFA', async () => {
      const loginData = {
        email: 'tenant-admin@example.com',
        password: 'Password123!',
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      };

      const mockUser = {
        id: 'user-123',
        email: 'tenant-admin@example.com',
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'ACTIVE',
        password_hash: 'hashedpassword',
        roles: [{ role: { name: 'TENANT_ADMIN' } }],
      };

      authRepository.findUserByEmailAndTenant.mockResolvedValue(mockUser);
      comparePassword.mockResolvedValue(true);
      generateToken.mockReturnValue('access-token');
      generateRefreshToken.mockReturnValue('refresh-token');
      authRepository.createSession.mockResolvedValue({ id: 'session-123' });
      createAuditLog.mockResolvedValue({});

      const result = await authService.login(loginData);

      expect(result).toHaveProperty('access_token', 'access-token');
      expect(result).toHaveProperty('refresh_token', 'refresh-token');
      expect(authRepository.createSession).toHaveBeenCalled();
      expect(generateToken).toHaveBeenCalledWith(expect.objectContaining({
        roles: ['TENANT_ADMIN'],
      }));
    });

    it('should require facility selection when user has multiple facilities and no facility_id is provided', async () => {
      const loginData = {
        email: 'multifacility@example.com',
        password: 'Password123!',
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      };

      const mockUser = {
        id: 'user-123',
        email: 'multifacility@example.com',
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        facility_id: 'facility-legacy-default',
        status: 'ACTIVE',
        password_hash: 'hashedpassword',
        roles: [{ role: { name: 'DOCTOR' } }],
      };

      authRepository.findUserByEmailAndTenant.mockResolvedValue(mockUser);
      comparePassword.mockResolvedValue(true);
      authRepository.getUserFacilities.mockResolvedValue([
        {
          id: 'facility-1',
          name: 'Facility One',
          facility_type: 'HOSPITAL',
        },
        {
          id: 'facility-2',
          name: 'Facility Two',
          facility_type: 'CLINIC',
        },
      ]);

      const result = await authService.login(loginData);

      expect(result).toEqual({
        requires_facility_selection: true,
        facilities: [
          { id: 'facility-1', name: 'Facility One', facility_type: 'HOSPITAL' },
          { id: 'facility-2', name: 'Facility Two', facility_type: 'CLINIC' },
        ],
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      });
      expect(generateToken).not.toHaveBeenCalled();
      expect(authRepository.createSession).not.toHaveBeenCalled();
    });
  });

  describe('register', () => {
    it('should register new user', async () => {
      const registerData = {
        email: 'newuser@example.com',
        password: 'Password123!',
        facility_name: 'Mirembe Clinic',
        admin_name: 'Jane Doe',
        facility_type: 'CLINIC',
        phone: '256701234567',
        interests: 'Billing; Telemedicine\nEMR',
        ip_address: '127.0.0.1',
        user_agent: 'Mozilla'
      };

      const mockUser = {
        id: 'user-123',
        email: 'newuser@example.com',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        status: 'PENDING',
        password_hash: 'hashedpassword'
      };

      hashPassword.mockResolvedValue('hashedpassword');
      authRepository.findUserByEmail.mockResolvedValue(null);
      authRepository.registerFacilityOwner.mockResolvedValue(mockUser);
      authRepository.createVerificationToken.mockResolvedValue({});
      createAuditLog.mockResolvedValue({});

      const result = await authService.register(registerData);

      expect(result).toHaveProperty('user.id', 'user-123');
      expect(result).toHaveProperty('user.email', 'newuser@example.com');
      expect(result).toHaveProperty('flow', 'NEW_REGISTRATION');
      expect(result).toHaveProperty('next_path', '/setup');
      expect(result).toHaveProperty('verification.expires_in_minutes', 15);
      expect(result.user).not.toHaveProperty('password_hash');
      expect(authRepository.registerFacilityOwner).toHaveBeenCalledWith(expect.objectContaining({
        facility_name: 'Mirembe Clinic',
        admin_name: 'Jane Doe',
        facility_type: 'CLINIC',
        status: 'PENDING'
      }));
      expect(authRepository.createVerificationToken).toHaveBeenCalledTimes(2);
      expect(sendEmail).toHaveBeenCalledTimes(1);
      expect(sendEmail).toHaveBeenCalledWith(expect.objectContaining({
        html: expect.stringContaining('next=%2Fsetup'),
      }));
      expect(authRepository.upsertRegistrationFollowUp).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: 'user-123',
          email: 'newuser@example.com',
          account_status: 'PENDING',
          interests: 'Billing, Telemedicine, EMR',
        })
      );
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'USER_REGISTERED'
      }));
    });

    it('should resend verification when email already exists in pending state', async () => {
      const registerData = {
        email: 'pending@example.com',
        password: 'Password123!',
        facility_name: 'City Hospital',
        admin_name: 'Jane Doe',
        facility_type: 'HOSPITAL',
        phone: '256701234567',
        ip_address: '127.0.0.1',
        user_agent: 'Mozilla'
      };

      const existingPendingUser = {
        id: 'user-pending-123',
        email: 'pending@example.com',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        status: 'PENDING',
        password_hash: 'existing-hash',
        profile: { first_name: 'Jane', last_name: 'Doe' },
        tenant: { name: 'City Hospital' },
        facility: { name: 'City Hospital', facility_type: 'HOSPITAL' }
      };

      authRepository.findUserByEmail.mockResolvedValue(existingPendingUser);
      authRepository.createVerificationToken.mockResolvedValue({});
      createAuditLog.mockResolvedValue({});

      const result = await authService.register(registerData);

      expect(result).toHaveProperty('user.id', 'user-pending-123');
      expect(result).toHaveProperty('flow', 'EXISTING_PENDING_ACCOUNT');
      expect(result).toHaveProperty('next_path', '/setup');
      expect(result).toHaveProperty('verification.email', 'pending@example.com');
      expect(result).toHaveProperty('verification.email_already_used', true);
      expect(result).toHaveProperty('verification.expires_in_minutes', 15);
      expect(hashPassword).not.toHaveBeenCalled();
      expect(authRepository.registerFacilityOwner).not.toHaveBeenCalled();
      expect(authRepository.createVerificationToken).toHaveBeenCalledTimes(2);
      expect(sendEmail).toHaveBeenCalledTimes(1);
      expect(sendEmail).toHaveBeenCalledWith(expect.objectContaining({
        html: expect.stringContaining('next=%2Fsetup'),
      }));
      expect(authRepository.upsertRegistrationFollowUp).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: 'user-pending-123',
          email: 'pending@example.com',
          account_status: 'PENDING',
        })
      );
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'USER_REGISTERED_EXISTING_EMAIL'
      }));
    });

    it('should continue registration when existing email is already active', async () => {
      const registerData = {
        email: 'existing@example.com',
        password: 'Password123!',
        facility_name: 'Different Facility Name',
        admin_name: 'Jane Doe',
        facility_type: 'CLINIC',
      };

      authRepository.findUserByEmail.mockResolvedValue({
        id: 'user-active-123',
        email: 'existing@example.com',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        status: 'ACTIVE',
        profile: { first_name: 'Jane', last_name: 'Doe' },
        tenant: { name: 'City Hospital' },
        facility: { name: 'City Hospital', facility_type: 'HOSPITAL' },
      });
      authRepository.createVerificationToken.mockResolvedValue({});
      createAuditLog.mockResolvedValue({});

      const result = await authService.register(registerData);

      expect(result).toHaveProperty('user.id', 'user-active-123');
      expect(result).toHaveProperty('flow', 'EXISTING_ACTIVE_ACCOUNT');
      expect(result).toHaveProperty('next_path', '/landing?mode=signin');
      expect(result).toHaveProperty('verification.email_already_used', true);
      expect(result).toHaveProperty('verification.account_already_active', true);
      expect(result).toHaveProperty('verification.facility_details_differ', true);
      expect(hashPassword).not.toHaveBeenCalled();
      expect(authRepository.registerFacilityOwner).not.toHaveBeenCalled();
      expect(authRepository.createVerificationToken).toHaveBeenCalledTimes(2);
      expect(sendEmail).toHaveBeenCalledTimes(1);
      expect(sendEmail).toHaveBeenCalledWith(expect.objectContaining({
        html: expect.stringContaining('next=%2Flanding%3Fmode%3Dsignin'),
      }));
      expect(authRepository.upsertRegistrationFollowUp).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: 'user-active-123',
          email: 'existing@example.com',
          account_status: 'ACTIVE',
          registration_attempt_increment: 1,
        })
      );
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'USER_REGISTERED_EXISTING_EMAIL'
      }));
    });
  });

  describe('refresh', () => {
    it('should refresh tokens with valid refresh token', async () => {
      const refreshData = {
        refresh_token: 'old-refresh-token',
        ip_address: '127.0.0.1',
        user_agent: 'Mozilla'
      };

      const mockSession = {
        id: 'session-123',
        user: {
          id: 'user-123',
          tenant_id: 'tenant-123',
          status: 'ACTIVE',
          roles: [{ role: { name: 'DOCTOR' } }]
        }
      };

      authRepository.findSessionByRefreshToken.mockResolvedValue(mockSession);
      authRepository.revokeSession.mockResolvedValue({});
      generateToken.mockReturnValue('new-access-token');
      generateRefreshToken.mockReturnValue('new-refresh-token');
      authRepository.createSession.mockResolvedValue({ id: 'new-session-123' });
      createAuditLog.mockResolvedValue({});

      const result = await authService.refresh(refreshData);

      expect(result).toHaveProperty('access_token', 'new-access-token');
      expect(result).toHaveProperty('refresh_token', 'new-refresh-token');
      expect(authRepository.revokeSession).toHaveBeenCalledWith('session-123');
      expect(authRepository.createSession).toHaveBeenCalled();
    });

    it('should reject invalid refresh token', async () => {
      const refreshData = {
        refresh_token: 'invalid-token'
      };

      authRepository.findSessionByRefreshToken.mockResolvedValue(null);

      await expect(authService.refresh(refreshData))
        .rejects
        .toThrow(HttpError);
      await expect(authService.refresh(refreshData))
        .rejects
        .toMatchObject({ statusCode: 401 });
    });

    it('should reject refresh for inactive user', async () => {
      const refreshData = {
        refresh_token: 'valid-token'
      };

      const mockSession = {
        id: 'session-123',
        user: {
          id: 'user-123',
          status: 'SUSPENDED'
        }
      };

      authRepository.findSessionByRefreshToken.mockResolvedValue(mockSession);

      await expect(authService.refresh(refreshData))
        .rejects
        .toThrow(HttpError);
      await expect(authService.refresh(refreshData))
        .rejects
        .toMatchObject({ statusCode: 403 });
    });
  });

  describe('logout', () => {
    it('should logout single session with refresh token', async () => {
      const logoutData = {
        user_id: 'user-123',
        refresh_token: 'refresh-token',
        ip_address: '127.0.0.1',
        user_agent: 'Mozilla'
      };

      const mockSession = {
        id: 'session-123',
        user: {
          tenant_id: 'tenant-123',
          facility_id: 'facility-123'
        }
      };

      authRepository.findSessionByRefreshToken.mockResolvedValue(mockSession);
      authRepository.revokeSession.mockResolvedValue({});
      createAuditLog.mockResolvedValue({});

      const result = await authService.logout(logoutData);

      expect(result).toHaveProperty('message');
      expect(authRepository.revokeSession).toHaveBeenCalledWith('session-123');
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'USER_LOGOUT'
      }));
    });

    it('should logout all sessions without refresh token', async () => {
      const logoutData = {
        user_id: 'user-123',
        ip_address: '127.0.0.1',
        user_agent: 'Mozilla'
      };

      const mockUser = {
        id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123'
      };

      authRepository.revokeAllUserSessions.mockResolvedValue({ count: 3 });
      authRepository.findUserById.mockResolvedValue(mockUser);
      createAuditLog.mockResolvedValue({});

      const result = await authService.logout(logoutData);

      expect(result).toHaveProperty('message');
      expect(authRepository.revokeAllUserSessions).toHaveBeenCalledWith('user-123');
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'USER_LOGOUT_ALL'
      }));
    });
  });

  describe('changePassword', () => {
    it('should change password with valid old password', async () => {
      const changeData = {
        user_id: 'user-123',
        old_password: 'OldPassword123!',
        new_password: 'NewPassword123!',
        ip_address: '127.0.0.1',
        user_agent: 'Mozilla'
      };

      const mockUser = {
        id: 'user-123',
        tenant_id: 'tenant-123',
        password_hash: 'old-hash'
      };

      authRepository.findUserById.mockResolvedValue(mockUser);
      comparePassword.mockResolvedValue(true);
      hashPassword.mockResolvedValue('new-hash');
      authRepository.updateUserPassword.mockResolvedValue({});
      authRepository.revokeAllUserSessions.mockResolvedValue({ count: 2 });
      createAuditLog.mockResolvedValue({});

      const result = await authService.changePassword(changeData);

      expect(result).toHaveProperty('message');
      expect(authRepository.updateUserPassword).toHaveBeenCalledWith('user-123', 'new-hash');
      expect(authRepository.revokeAllUserSessions).toHaveBeenCalledWith('user-123');
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'PASSWORD_CHANGED'
      }));
    });

    it('should reject password change with wrong old password', async () => {
      const changeData = {
        user_id: 'user-123',
        old_password: 'WrongPassword',
        new_password: 'NewPassword123!'
      };

      const mockUser = {
        id: 'user-123',
        password_hash: 'old-hash'
      };

      authRepository.findUserById.mockResolvedValue(mockUser);
      comparePassword.mockResolvedValue(false);

      await expect(authService.changePassword(changeData))
        .rejects
        .toThrow(HttpError);
      await expect(authService.changePassword(changeData))
        .rejects
        .toMatchObject({ statusCode: 401 });
    });

    it('should reject password change for non-existent user', async () => {
      const changeData = {
        user_id: 'non-existent-user',
        old_password: 'OldPassword123!',
        new_password: 'NewPassword123!'
      };

      authRepository.findUserById.mockResolvedValue(null);

      await expect(authService.changePassword(changeData))
        .rejects
        .toThrow(HttpError);
      await expect(authService.changePassword(changeData))
        .rejects
        .toMatchObject({ statusCode: 404 });
    });
  });

  describe('getMe', () => {
    it('should return user data without password', async () => {
      const mockUser = {
        id: 'user-123',
        email: 'test@example.com',
        password_hash: 'hashed',
        profile: {},
        permissions: [
          { permission_id: 'perm-1', permission: { id: 'perm-1', name: 'patient:read' } },
        ],
      };

      authRepository.findUserById.mockResolvedValue(mockUser);

      const result = await authService.getMe('user-123');

      expect(result).toHaveProperty('id', 'user-123');
      expect(result).toHaveProperty('email', 'test@example.com');
      expect(result).toHaveProperty('permissions');
      expect(result.permissions).toEqual(['patient:read']);
      expect(result).not.toHaveProperty('password_hash');
    });

    it('should throw error if user not found', async () => {
      authRepository.findUserById.mockResolvedValue(null);

      await expect(authService.getMe('non-existent-user'))
        .rejects
        .toThrow(HttpError);
      await expect(authService.getMe('non-existent-user'))
        .rejects
        .toMatchObject({ statusCode: 404 });
    });
  });

  describe('verifyEmail', () => {
    it('should verify email with valid token', async () => {
      const verifyData = {
        token: 'valid-token',
        email: 'test@example.com'
      };

      const mockToken = {
        id: 'token-123',
        user_id: 'user-123',
        user: {
          id: 'user-123',
          email: 'test@example.com',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123'
        }
      };

      authRepository.findVerificationToken.mockResolvedValue(mockToken);
      authRepository.markTokenAsUsed.mockResolvedValue({});
      authRepository.updateUserStatus.mockResolvedValue({});
      authRepository.deleteExpiredTokens.mockResolvedValue({});
      createAuditLog.mockResolvedValue({});

      const result = await authService.verifyEmail(verifyData);

      expect(result).toHaveProperty('message');
      expect(result).toHaveProperty('next_path', '/setup');
      expect(authRepository.markTokenAsUsed).toHaveBeenCalledWith('token-123');
      expect(authRepository.deleteExpiredTokens).toHaveBeenCalledWith('user-123', 'EMAIL_VERIFICATION');
      expect(authRepository.updateUserStatus).toHaveBeenCalledWith('user-123', 'ACTIVE');
      expect(authRepository.updateRegistrationFollowUpStatus).toHaveBeenCalledWith('user-123', 'ACTIVE');
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'EMAIL_VERIFIED'
      }));
    });

    it('should reject with invalid token', async () => {
      authRepository.findVerificationToken.mockResolvedValue(null);

      await expect(authService.verifyEmail({ token: 'invalid-token' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should allow verify token for already active email', async () => {
      const verifyData = {
        token: 'active-token',
        email: 'verified@example.com'
      };

      const mockToken = {
        id: 'token-active-123',
        user_id: 'user-active-123',
        user: {
          id: 'user-active-123',
          email: 'verified@example.com',
          status: 'ACTIVE',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123'
        }
      };

      authRepository.findVerificationToken.mockResolvedValue(mockToken);
      authRepository.markTokenAsUsed.mockResolvedValue({});
      authRepository.deleteExpiredTokens.mockResolvedValue({});
      createAuditLog.mockResolvedValue({});

      const result = await authService.verifyEmail(verifyData);

      expect(result).toHaveProperty('message');
      expect(result).toHaveProperty('already_active', true);
      expect(result).toHaveProperty('next_path', '/landing?mode=signin');
      expect(authRepository.markTokenAsUsed).toHaveBeenCalledWith('token-active-123');
      expect(authRepository.deleteExpiredTokens).toHaveBeenCalledWith('user-active-123', 'EMAIL_VERIFICATION');
      expect(authRepository.updateUserStatus).not.toHaveBeenCalled();
      expect(authRepository.updateRegistrationFollowUpStatus).toHaveBeenCalledWith('user-active-123', 'ACTIVE');
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'EMAIL_VERIFIED_ALREADY_ACTIVE'
      }));
    });
  });

  describe('verifyPhone', () => {
    it('should verify phone with valid token', async () => {
      const verifyData = {
        token: 'valid-token',
        phone: '256701234567'
      };

      const mockToken = {
        id: 'token-123',
        user_id: 'user-123',
        user: {
          id: 'user-123',
          phone: '256701234567',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123'
        }
      };

      authRepository.findVerificationToken.mockResolvedValue(mockToken);
      authRepository.markTokenAsUsed.mockResolvedValue({});
      createAuditLog.mockResolvedValue({});

      const result = await authService.verifyPhone(verifyData);

      expect(result).toHaveProperty('message');
      expect(result).toHaveProperty('next_path', '/setup');
      expect(authRepository.markTokenAsUsed).toHaveBeenCalledWith('token-123');
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'PHONE_VERIFIED'
      }));
    });
  });

  describe('resendVerification', () => {
    it('should resend email verification', async () => {
      const resendData = {
        email: 'test@example.com',
        type: 'email'
      };

      const mockUser = {
        id: 'user-123',
        email: 'test@example.com',
        status: 'PENDING',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        profile: { first_name: 'Test' },
        facility: { name: 'City Hospital', facility_type: 'HOSPITAL' },
        tenant: { name: 'City Hospital' }
      };

      authRepository.findUserByEmail.mockResolvedValue(mockUser);
      authRepository.createVerificationToken.mockResolvedValue({});
      createAuditLog.mockResolvedValue({});

      const result = await authService.resendVerification(resendData);

      expect(result).toHaveProperty('message');
      expect(authRepository.createVerificationToken).toHaveBeenCalledTimes(2);
      expect(sendEmail).toHaveBeenCalledTimes(1);
      expect(sendEmail).toHaveBeenCalledWith(expect.objectContaining({
        html: expect.stringContaining('next=%2Fsetup'),
      }));
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'VERIFICATION_RESENT'
      }));
    });

    it('should resend email verification even if user is already active', async () => {
      const mockUser = {
        id: 'user-123',
        email: 'test@example.com',
        status: 'ACTIVE',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        profile: { first_name: 'Test' },
        facility: { name: 'City Hospital', facility_type: 'HOSPITAL' },
        tenant: { name: 'City Hospital' }
      };

      authRepository.findUserByEmail.mockResolvedValue(mockUser);
      authRepository.createVerificationToken.mockResolvedValue({});
      createAuditLog.mockResolvedValue({});

      const result = await authService.resendVerification({ email: 'test@example.com', type: 'email' });

      expect(result).toHaveProperty('message');
      expect(authRepository.createVerificationToken).toHaveBeenCalledTimes(2);
      expect(sendEmail).toHaveBeenCalledTimes(1);
      expect(sendEmail).toHaveBeenCalledWith(expect.objectContaining({
        html: expect.stringContaining('next=%2Flanding%3Fmode%3Dsignin'),
      }));
    });

    it('should fail resend when verification email cannot be delivered', async () => {
      const mockUser = {
        id: 'user-123',
        email: 'test@example.com',
        status: 'PENDING',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        profile: { first_name: 'Test' },
        facility: { name: 'City Hospital', facility_type: 'HOSPITAL' },
        tenant: { name: 'City Hospital' }
      };

      authRepository.findUserByEmail.mockResolvedValue(mockUser);
      authRepository.createVerificationToken.mockResolvedValue({});
      sendEmail.mockResolvedValueOnce({ sent: false, provider: 'skipped' });

      await expect(authService.resendVerification({ email: 'test@example.com', type: 'email' }))
        .rejects
        .toMatchObject({
          messageKey: 'errors.auth.email_delivery_unavailable',
          statusCode: 503
        });

      expect(createAuditLog).not.toHaveBeenCalled();
    });

    it('should reject phone resend if user is already active', async () => {
      const mockUser = {
        id: 'user-123',
        phone: '256701234567',
        status: 'ACTIVE'
      };

      authRepository.findUserByPhone.mockResolvedValue(mockUser);

      await expect(authService.resendVerification({ phone: '256701234567', type: 'phone' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('forgotPassword', () => {
    it('should send password reset email', async () => {
      const forgotData = {
        email: 'test@example.com',
        tenant_id: 'tenant-123'
      };

      const mockUser = {
        id: 'user-123',
        email: 'test@example.com',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123'
      };

      authRepository.findUserByEmailAndTenant.mockResolvedValue(mockUser);
      authRepository.deleteExpiredTokens.mockResolvedValue({});
      authRepository.createVerificationToken.mockResolvedValue({});
      createAuditLog.mockResolvedValue({});

      const result = await authService.forgotPassword(forgotData);

      expect(result).toHaveProperty('message');
      expect(authRepository.createVerificationToken).toHaveBeenCalled();
      expect(sendEmail).toHaveBeenCalledWith(expect.objectContaining({
        to: 'test@example.com',
        subject: expect.stringContaining('Reset your')
      }));
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'PASSWORD_RESET_REQUESTED'
      }));
    });

    it('should not reveal if user does not exist', async () => {
      authRepository.findUserByEmailAndTenant.mockResolvedValue(null);

      const result = await authService.forgotPassword({
        email: 'nonexistent@example.com',
        tenant_id: 'tenant-123'
      });

      expect(result).toHaveProperty('message');
      expect(authRepository.createVerificationToken).not.toHaveBeenCalled();
    });

    it('should return success even when reset email delivery fails', async () => {
      const forgotData = {
        email: 'test@example.com',
        tenant_id: 'tenant-123'
      };

      const mockUser = {
        id: 'user-123',
        email: 'test@example.com',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123'
      };

      authRepository.findUserByEmailAndTenant.mockResolvedValue(mockUser);
      authRepository.deleteExpiredTokens.mockResolvedValue({});
      authRepository.createVerificationToken.mockResolvedValue({});
      sendEmail.mockResolvedValue({ sent: false, provider: 'skipped' });
      createAuditLog.mockResolvedValue({});

      const result = await authService.forgotPassword(forgotData);

      expect(result).toHaveProperty('message');
      expect(sendEmail).toHaveBeenCalled();
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'PASSWORD_RESET_REQUESTED'
      }));
    });
  });

  describe('resetPassword', () => {
    it('should reset password with valid token', async () => {
      const resetData = {
        token: 'valid-token',
        new_password: 'NewPassword123!'
      };

      const mockToken = {
        id: 'token-123',
        user_id: 'user-123',
        user: {
          id: 'user-123',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123'
        }
      };

      authRepository.findVerificationToken.mockResolvedValue(mockToken);
      hashPassword.mockResolvedValue('newhashedpassword');
      authRepository.updateUserPassword.mockResolvedValue({});
      authRepository.markTokenAsUsed.mockResolvedValue({});
      authRepository.revokeAllUserSessions.mockResolvedValue({});
      createAuditLog.mockResolvedValue({});

      const result = await authService.resetPassword(resetData);

      expect(result).toHaveProperty('message');
      expect(authRepository.updateUserPassword).toHaveBeenCalledWith('user-123', 'newhashedpassword');
      expect(authRepository.markTokenAsUsed).toHaveBeenCalledWith('token-123');
      expect(authRepository.revokeAllUserSessions).toHaveBeenCalledWith('user-123');
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'PASSWORD_RESET'
      }));
    });

    it('should reject with invalid token', async () => {
      authRepository.findVerificationToken.mockResolvedValue(null);

      await expect(authService.resetPassword({ token: 'invalid-token', new_password: 'NewPass123!' }))
        .rejects
        .toThrow(HttpError);
    });
  });
});
