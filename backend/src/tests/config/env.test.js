const loadEnv = (overrides = {}) => {
  jest.resetModules();

  const env = require('@config/env');
  env.setEnvForTests({
    JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
    DATABASE_URL: 'mysql://test:test@localhost:3306/test_db',
    CORS_ORIGINS: 'http://example.com',
    NODE_ENV: 'development',
    TRUST_PROXY: undefined,
    PRISMA_MYSQL_ALLOW_PUBLIC_KEY_RETRIEVAL: undefined,
    ...overrides,
  });

  return env;
};

describe('env config', () => {
  test('defaults Prisma MySQL public key retrieval to true in development', () => {
    const env = loadEnv({
      NODE_ENV: 'development',
      PRISMA_MYSQL_ALLOW_PUBLIC_KEY_RETRIEVAL: undefined,
    });

    expect(env.PRISMA_MYSQL_ALLOW_PUBLIC_KEY_RETRIEVAL).toBe(true);
  });

  test('defaults Prisma MySQL public key retrieval to false in test', () => {
    const env = loadEnv({
      NODE_ENV: 'test',
      PRISMA_MYSQL_ALLOW_PUBLIC_KEY_RETRIEVAL: undefined,
    });

    expect(env.PRISMA_MYSQL_ALLOW_PUBLIC_KEY_RETRIEVAL).toBe(false);
  });

  test('honors explicit true override for Prisma MySQL public key retrieval', () => {
    const env = loadEnv({
      NODE_ENV: 'production',
      PRISMA_MYSQL_ALLOW_PUBLIC_KEY_RETRIEVAL: 'true',
    });

    expect(env.PRISMA_MYSQL_ALLOW_PUBLIC_KEY_RETRIEVAL).toBe(true);
  });

  test('honors explicit false override for Prisma MySQL public key retrieval', () => {
    const env = loadEnv({
      NODE_ENV: 'development',
      PRISMA_MYSQL_ALLOW_PUBLIC_KEY_RETRIEVAL: 'false',
    });

    expect(env.PRISMA_MYSQL_ALLOW_PUBLIC_KEY_RETRIEVAL).toBe(false);
  });

  test('rejects invalid Prisma MySQL public key retrieval values', () => {
    expect(() =>
      loadEnv({
        PRISMA_MYSQL_ALLOW_PUBLIC_KEY_RETRIEVAL: 'sometimes',
      })
    ).toThrow('Invalid boolean value: sometimes. Use "true" or "false".');
  });

  test('defaults trust proxy to false', () => {
    const env = loadEnv({
      TRUST_PROXY: undefined,
    });

    expect(env.TRUST_PROXY).toBe(false);
  });

  test('supports numeric trust proxy hop counts', () => {
    const env = loadEnv({
      TRUST_PROXY: '1',
    });

    expect(env.TRUST_PROXY).toBe(1);
  });

  test('rejects invalid trust proxy values', () => {
    expect(() =>
      loadEnv({
        TRUST_PROXY: 'loopback-only',
      })
    ).toThrow(
      'Invalid TRUST_PROXY value: loopback-only. Use "true", "false", or a non-negative integer.'
    );
  });

  test('defaults auth/session security toggles to bounded safe values', () => {
    const env = loadEnv({
      JWT_ACCESS_TOKEN_EXPIRATION: undefined,
      JWT_REFRESH_TOKEN_EXPIRATION: undefined,
      AUTH_SESSION_TTL_DAYS: undefined,
      ALLOW_PLAINTEXT_PASSWORD_EMAIL: undefined,
    });

    expect(env.JWT_ACCESS_TOKEN_EXPIRATION).toBe('15m');
    expect(env.JWT_REFRESH_TOKEN_EXPIRATION).toBe('7d');
    expect(env.AUTH_SESSION_TTL_DAYS).toBe(7);
    expect(env.ALLOW_PLAINTEXT_PASSWORD_EMAIL).toBe(false);
  });

  test('rejects invalid AUTH_SESSION_TTL_DAYS values', () => {
    expect(() =>
      loadEnv({
        AUTH_SESSION_TTL_DAYS: '0',
      })
    ).toThrow('AUTH_SESSION_TTL_DAYS must be an integer between 1 and 90.');
  });
});
