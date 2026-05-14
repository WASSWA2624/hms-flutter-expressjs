/**
 * API key helper tests
 */

const loadApiKeyHelpers = (argon2Factory) => {
  jest.resetModules();
  jest.doMock('argon2', argon2Factory);
  return require('@lib/crypto/hashApiKey');
};

describe('api key helpers', () => {
  afterEach(() => {
    jest.clearAllMocks();
    jest.resetModules();
  });

  it('hashes and verifies API keys using argon2id', async () => {
    const hash = jest.fn().mockResolvedValue('$argon2id$hash');
    const verify = jest.fn().mockResolvedValue(true);
    const argon2Mock = {
      argon2id: 'argon2id',
      hash,
      verify,
    };

    const { hashApiKey, verifyApiKey } = loadApiKeyHelpers(() => argon2Mock);

    await expect(hashApiKey('plain-api-key')).resolves.toBe('$argon2id$hash');
    await expect(verifyApiKey('$argon2id$hash', 'plain-api-key')).resolves.toBe(true);

    expect(hash).toHaveBeenCalledWith('plain-api-key', {
      type: 'argon2id',
      memoryCost: 65536,
      timeCost: 3,
      parallelism: 4,
    });
    expect(verify).toHaveBeenCalledWith('$argon2id$hash', 'plain-api-key');
  });

  it('rejects invalid helper inputs', async () => {
    const argon2Mock = {
      argon2id: 'argon2id',
      hash: jest.fn(),
      verify: jest.fn(),
    };

    const { hashApiKey, verifyApiKey } = loadApiKeyHelpers(() => argon2Mock);

    await expect(hashApiKey('')).rejects.toThrow('API key must be a non-empty string');
    await expect(verifyApiKey('', 'plain-api-key')).rejects.toThrow(
      'Hashed API key must be a non-empty string'
    );
    await expect(verifyApiKey('$argon2id$hash', '')).rejects.toThrow(
      'Plain API key must be a non-empty string'
    );
  });

  it('wraps missing argon2 dependency failures', async () => {
    const { hashApiKey, verifyApiKey } = loadApiKeyHelpers(() => {
      throw new Error('native module unavailable');
    });

    await expect(hashApiKey('plain-api-key')).rejects.toThrow(
      'Argon2 dependency is not available in this runtime.'
    );
    await expect(verifyApiKey('$argon2id$hash', 'plain-api-key')).rejects.toThrow(
      'Argon2 dependency is not available in this runtime.'
    );
  });
});
