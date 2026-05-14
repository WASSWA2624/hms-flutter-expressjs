/**
 * Auth controller tests
 *
 * @module tests/modules/auth/controllers
 */

const authController = require('@controllers/auth/auth.controller');
const authService = require('@services/auth/auth.service');

// Mock dependencies
jest.mock('@services/auth/auth.service');

describe('Auth Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      body: {},
      user: {},
      ip: '127.0.0.1',
      get: jest.fn().mockReturnValue('Mozilla')
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
      setHeader: jest.fn(),
    };
  });

  describe('login', () => {
    it('should login user successfully', async () => {
      req.body = {
        email: 'test@example.com',
        password: 'Password123!',
        tenant_id: 'tenant-123'
      };

      const mockResult = {
        access_token: 'access-token',
        refresh_token: 'refresh-token',
        user: { id: 'user-123' }
      };

      authService.login.mockResolvedValue(mockResult);

      await authController.login(req, res);

      expect(authService.login).toHaveBeenCalledWith({
        email: 'test@example.com',
        phone: undefined,
        password: 'Password123!',
        tenant_id: 'tenant-123',
        facility_id: undefined,
        ip_address: '127.0.0.1',
        user_agent: 'Mozilla'
      });
      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        status: 200,
        data: mockResult
      }));
    });

    it('should login user with phone number', async () => {
      req.body = {
        phone: '256701234567',
        password: 'Password123!',
        tenant_id: 'tenant-123'
      };

      const mockResult = {
        access_token: 'access-token',
        refresh_token: 'refresh-token',
        user: { id: 'user-123' }
      };

      authService.login.mockResolvedValue(mockResult);

      await authController.login(req, res);

      expect(authService.login).toHaveBeenCalledWith({
        email: undefined,
        phone: '256701234567',
        password: 'Password123!',
        tenant_id: 'tenant-123',
        facility_id: undefined,
        ip_address: '127.0.0.1',
        user_agent: 'Mozilla'
      });
      expect(res.status).toHaveBeenCalledWith(200);
    });
  });

  describe('register', () => {
    it('should register user successfully', async () => {
      req.body = {
        email: 'newuser@example.com',
        password: 'Password123!',
        facility_name: 'Mirembe Clinic',
        admin_name: 'Jane Doe',
        facility_type: 'CLINIC',
        location: 'Kampala, Uganda',
        interests: 'Telemedicine'
      };

      const mockResult = {
        id: 'user-123',
        email: 'newuser@example.com'
      };

      authService.register.mockResolvedValue(mockResult);

      await authController.register(req, res);

      expect(authService.register).toHaveBeenCalledWith(expect.objectContaining({
        email: 'newuser@example.com',
        password: 'Password123!',
        facility_name: 'Mirembe Clinic',
        admin_name: 'Jane Doe',
        facility_type: 'CLINIC',
        location: 'Kampala, Uganda',
        interests: 'Telemedicine',
        request_context: expect.any(Object),
      }));
      expect(res.status).toHaveBeenCalledWith(201);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        status: 201
      }));
    });
  });

  describe('refresh', () => {
    it('should refresh tokens successfully', async () => {
      req.body = {
        refresh_token: 'old-refresh-token'
      };

      const mockResult = {
        access_token: 'new-access-token',
        refresh_token: 'new-refresh-token'
      };

      authService.refresh.mockResolvedValue(mockResult);

      await authController.refresh(req, res);

      expect(authService.refresh).toHaveBeenCalledWith({
        refresh_token: 'old-refresh-token',
        ip_address: '127.0.0.1',
        user_agent: 'Mozilla'
      });
      expect(res.status).toHaveBeenCalledWith(200);
    });
  });

  describe('logout', () => {
    it('should logout user successfully', async () => {
      req.user = { userId: 'user-123' };
      req.body = { refresh_token: 'refresh-token' };

      const mockResult = { message: 'Logged out successfully' };
      authService.logout.mockResolvedValue(mockResult);

      await authController.logout(req, res);

      expect(authService.logout).toHaveBeenCalledWith({
        user_id: 'user-123',
        refresh_token: 'refresh-token',
        ip_address: '127.0.0.1',
        user_agent: 'Mozilla'
      });
      expect(res.status).toHaveBeenCalledWith(200);
    });
  });

  describe('changePassword', () => {
    it('should change password successfully', async () => {
      req.user = { userId: 'user-123' };
      req.body = {
        old_password: 'OldPassword123!',
        new_password: 'NewPassword123!'
      };

      const mockResult = { message: 'Password changed successfully' };
      authService.changePassword.mockResolvedValue(mockResult);

      await authController.changePassword(req, res);

      expect(authService.changePassword).toHaveBeenCalledWith({
        user_id: 'user-123',
        old_password: 'OldPassword123!',
        new_password: 'NewPassword123!',
        ip_address: '127.0.0.1',
        user_agent: 'Mozilla'
      });
      expect(res.status).toHaveBeenCalledWith(200);
    });
  });

  describe('getMe', () => {
    it('should get current user info successfully', async () => {
      req.user = { userId: 'user-123' };

      const mockResult = {
        id: 'user-123',
        email: 'test@example.com'
      };
      authService.getMe.mockResolvedValue(mockResult);

      await authController.getMe(req, res);

      expect(authService.getMe).toHaveBeenCalledWith('user-123');
      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        status: 200,
        data: mockResult
      }));
    });
  });

  describe('verifyEmail', () => {
    it('should verify email successfully', async () => {
      req.body = { token: 'some-token', email: 'test@example.com' };

      const mockResult = { message: 'Email verified' };
      authService.verifyEmail.mockResolvedValue(mockResult);

      await authController.verifyEmail(req, res);

      expect(authService.verifyEmail).toHaveBeenCalledWith({
        token: 'some-token',
        email: 'test@example.com'
      });
      expect(res.status).toHaveBeenCalledWith(200);
    });
  });

  describe('verifyPhone', () => {
    it('should verify phone successfully', async () => {
      req.body = { token: 'some-token', phone: '256701234567' };

      const mockResult = { message: 'Phone verified' };
      authService.verifyPhone.mockResolvedValue(mockResult);

      await authController.verifyPhone(req, res);

      expect(authService.verifyPhone).toHaveBeenCalledWith({
        token: 'some-token',
        phone: '256701234567'
      });
      expect(res.status).toHaveBeenCalledWith(200);
    });
  });

  describe('resendVerification', () => {
    it('should resend verification successfully', async () => {
      req.body = { email: 'test@example.com', type: 'email' };

      const mockResult = { message: 'Verification sent' };
      authService.resendVerification.mockResolvedValue(mockResult);

      await authController.resendVerification(req, res);

      expect(authService.resendVerification).toHaveBeenCalledWith({
        email: 'test@example.com',
        phone: undefined,
        type: 'email',
        request_context: expect.any(Object)
      });
      expect(res.status).toHaveBeenCalledWith(200);
    });
  });

  describe('forgotPassword', () => {
    it('should send forgot password email successfully', async () => {
      req.body = { email: 'test@example.com', tenant_id: 'tenant-123' };

      const mockResult = { message: 'Password reset email sent' };
      authService.forgotPassword.mockResolvedValue(mockResult);

      await authController.forgotPassword(req, res);

      expect(authService.forgotPassword).toHaveBeenCalledWith({
        email: 'test@example.com',
        tenant_id: 'tenant-123',
        request_context: expect.any(Object),
      });
      expect(res.status).toHaveBeenCalledWith(200);
    });
  });

  describe('resetPassword', () => {
    it('should reset password successfully', async () => {
      req.body = { token: 'some-token', new_password: 'NewPassword123!' };

      const mockResult = { message: 'Password reset successful' };
      authService.resetPassword.mockResolvedValue(mockResult);

      await authController.resetPassword(req, res);

      expect(authService.resetPassword).toHaveBeenCalledWith({
        token: 'some-token',
        new_password: 'NewPassword123!'
      });
      expect(res.status).toHaveBeenCalledWith(200);
    });
  });
});
