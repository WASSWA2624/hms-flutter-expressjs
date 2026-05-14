/**
 * JWT helper tests
 */

jest.mock('jsonwebtoken', () => ({
  sign: jest.fn(),
  verify: jest.fn(),
}));

jest.mock('@config/jwt', () => ({
  accessTokenExpiration: '15m',
  algorithm: 'HS512',
}));

jest.mock('@config/env', () => ({
  JWT_SECRET: 'test-secret-test-secret-test-secret-123',
}));

const jwt = require('jsonwebtoken');
const { generateToken } = require('@lib/jwt/generateToken');
const { verifyToken } = require('@lib/jwt/verifyToken');

describe('JWT helpers', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('generateToken', () => {
    it('uses configured defaults for expiration and algorithm', () => {
      jwt.sign.mockReturnValue('signed-token');

      const token = generateToken({ id: 'user-1' });

      expect(token).toBe('signed-token');
      expect(jwt.sign).toHaveBeenCalledWith(
        { id: 'user-1' },
        'test-secret-test-secret-test-secret-123',
        { expiresIn: '15m', algorithm: 'HS512' }
      );
    });

    it('uses explicit expiration override when provided', () => {
      jwt.sign.mockReturnValue('override-token');

      const token = generateToken({ id: 'user-1' }, '2h');

      expect(token).toBe('override-token');
      expect(jwt.sign).toHaveBeenCalledWith(
        { id: 'user-1' },
        'test-secret-test-secret-test-secret-123',
        { expiresIn: '2h', algorithm: 'HS512' }
      );
    });

    it('throws when JWT secret is missing', () => {
      jest.resetModules();
      jest.doMock('jsonwebtoken', () => ({ sign: jest.fn() }));
      jest.doMock('@config/jwt', () => ({ accessTokenExpiration: '15m', algorithm: 'HS256' }));
      jest.doMock('@config/env', () => ({ JWT_SECRET: '' }));

      let isolatedGenerateToken;
      jest.isolateModules(() => {
        ({ generateToken: isolatedGenerateToken } = require('@lib/jwt/generateToken'));
      });

      expect(() => isolatedGenerateToken({ id: 'user-1' })).toThrow(
        'JWT_SECRET is not configured'
      );
    });
  });

  describe('verifyToken', () => {
    it('verifies token with configured algorithm', () => {
      jwt.verify.mockReturnValue({ id: 'user-1' });

      const decoded = verifyToken('token-value');

      expect(decoded).toEqual({ id: 'user-1' });
      expect(jwt.verify).toHaveBeenCalledWith(
        'token-value',
        'test-secret-test-secret-test-secret-123',
        { algorithms: ['HS512'] }
      );
    });

    it('maps TokenExpiredError to a user-friendly message', () => {
      jwt.verify.mockImplementation(() => {
        const err = new Error('expired');
        err.name = 'TokenExpiredError';
        throw err;
      });

      expect(() => verifyToken('expired-token')).toThrow('Token has expired');
    });

    it('maps JsonWebTokenError to a user-friendly message', () => {
      jwt.verify.mockImplementation(() => {
        const err = new Error('invalid');
        err.name = 'JsonWebTokenError';
        throw err;
      });

      expect(() => verifyToken('invalid-token')).toThrow('Invalid token');
    });

    it('maps NotBeforeError to a user-friendly message', () => {
      jwt.verify.mockImplementation(() => {
        const err = new Error('inactive');
        err.name = 'NotBeforeError';
        throw err;
      });

      expect(() => verifyToken('inactive-token')).toThrow('Token not active yet');
    });

    it('maps unexpected errors to generic verification failure', () => {
      jwt.verify.mockImplementation(() => {
        const err = new Error('unknown');
        err.name = 'SomeOtherJwtError';
        throw err;
      });

      expect(() => verifyToken('unknown-error-token')).toThrow('Token verification failed');
    });
  });
});
