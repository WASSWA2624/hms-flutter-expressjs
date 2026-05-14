/**
 * Password helper tests
 */

jest.mock('bcryptjs', () => ({
  hash: jest.fn(),
  compare: jest.fn(),
}));

const bcrypt = require('bcryptjs');
const { hashPassword } = require('@lib/crypto/hashPassword');
const { comparePassword } = require('@lib/crypto/comparePassword');

describe('password helpers', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('hashPassword', () => {
    it('hashes a valid password with default salt rounds', async () => {
      bcrypt.hash.mockResolvedValue('$2b$10$hashed');

      const result = await hashPassword('Password123!');

      expect(result).toBe('$2b$10$hashed');
      expect(bcrypt.hash).toHaveBeenCalledWith('Password123!', 10);
    });

    it('rejects invalid password inputs', async () => {
      await expect(hashPassword('')).rejects.toThrow('Password must be a non-empty string');
      await expect(hashPassword('short')).rejects.toThrow('Password must be at least 8 characters long');
    });

    it('wraps bcrypt hash failures', async () => {
      bcrypt.hash.mockRejectedValue(new Error('bcrypt unavailable'));

      await expect(hashPassword('Password123!')).rejects.toThrow(
        'Failed to hash password: bcrypt unavailable'
      );
    });
  });

  describe('comparePassword', () => {
    it('compares valid password values', async () => {
      bcrypt.compare.mockResolvedValue(true);

      const result = await comparePassword('Password123!', '$2b$10$hashed');

      expect(result).toBe(true);
      expect(bcrypt.compare).toHaveBeenCalledWith('Password123!', '$2b$10$hashed');
    });

    it('rejects invalid comparison inputs', async () => {
      await expect(comparePassword('', '$2b$10$hashed')).rejects.toThrow(
        'Plain password must be a non-empty string'
      );
      await expect(comparePassword('Password123!', '')).rejects.toThrow(
        'Hashed password must be a non-empty string'
      );
    });

    it('wraps bcrypt compare failures', async () => {
      bcrypt.compare.mockRejectedValue(new Error('bcrypt compare failed'));

      await expect(comparePassword('Password123!', '$2b$10$hashed')).rejects.toThrow(
        'Failed to compare passwords: bcrypt compare failed'
      );
    });
  });
});
