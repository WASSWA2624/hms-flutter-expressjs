const loadRateLimitConfig = (overrides = {}) => {
  jest.resetModules();

  const env = require('@config/env');
  env.setEnvForTests({
    JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
    DATABASE_URL: 'mysql://test:test@localhost:3306/test_db',
    CORS_ORIGINS: 'http://example.com',
    NODE_ENV: 'development',
    ...overrides,
  });

  return require('@config/rateLimit');
};

describe('rate limit config', () => {
  test('uses a high auth limit in development', () => {
    const config = loadRateLimitConfig({ NODE_ENV: 'development' });

    expect(config.endpoints.auth.max).toBe(1000);
  });

  test('keeps auth protection outside development', () => {
    const config = loadRateLimitConfig({ NODE_ENV: 'production' });

    expect(config.endpoints.auth.max).toBe(20);
  });
});
