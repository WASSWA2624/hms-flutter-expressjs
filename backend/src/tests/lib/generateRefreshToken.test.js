jest.mock('@config/env', () => ({
  JWT_SECRET: '12345678901234567890123456789012',
}));

jest.mock('@config/jwt', () => ({
  refreshTokenExpiration: '7d',
  algorithm: 'HS256',
}));

const jwt = require('jsonwebtoken');
const { generateRefreshToken } = require('@lib/jwt/generateRefreshToken');

describe('generateRefreshToken', () => {
  test('generates a valid refresh token when payload is omitted', () => {
    const token = generateRefreshToken();

    expect(typeof token).toBe('string');
    expect(token.length).toBeGreaterThan(20);

    const decoded = jwt.verify(token, '12345678901234567890123456789012');
    expect(decoded.type).toBe('refresh');
    expect(typeof decoded.jti).toBe('string');
    expect(decoded.jti.length).toBeGreaterThan(10);
  });

  test('preserves provided payload fields and does not mutate input', () => {
    const payload = { userId: 'user-123' };
    const token = generateRefreshToken(payload);
    const decoded = jwt.verify(token, '12345678901234567890123456789012');

    expect(decoded.userId).toBe('user-123');
    expect(payload).toEqual({ userId: 'user-123' });
  });
});

