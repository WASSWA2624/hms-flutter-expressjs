const env = require('@config/env');

describe('demo-safety script guard', () => {
  beforeEach(() => {
    jest.resetModules();
    env.setEnvForTests({
      NODE_ENV: 'test',
      DATABASE_URL: 'mysql://test:test@localhost:3306/hms_demo',
      JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
      CORS_ORIGINS: 'http://localhost:3000',
    });
  });

  it('allows demo tasks in a non-production environment with a safe database name', () => {
    const { assertDemoTaskAllowed } = require('../../../scripts/demo-safety');

    expect(assertDemoTaskAllowed('demo seed')).toEqual({ allowed: true, reason: null });
  });

  it('returns a skip result in production', () => {
    env.setEnvForTests({
      NODE_ENV: 'production',
      DATABASE_URL: 'mysql://test:test@localhost:3306/hms_demo',
      JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
      CORS_ORIGINS: 'http://localhost:3000',
    });

    const { assertDemoTaskAllowed } = require('../../../scripts/demo-safety');

    expect(assertDemoTaskAllowed('demo seed')).toEqual({
      allowed: false,
      reason: 'production_environment',
    });
  });

  it('rejects production-like database targets outside production too', () => {
    env.setEnvForTests({
      NODE_ENV: 'development',
      DATABASE_URL: 'mysql://demo:demo@localhost:3306/hms-live',
      JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
      CORS_ORIGINS: 'http://localhost:3000',
    });

    const { assertDemoTaskAllowed } = require('../../../scripts/demo-safety');

    expect(() => assertDemoTaskAllowed('demo seed')).toThrow('production/live database');
  });
});
