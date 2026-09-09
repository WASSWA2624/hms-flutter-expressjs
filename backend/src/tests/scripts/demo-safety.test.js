const env = require('@config/env');

describe('demo-safety script guard', () => {
  beforeEach(() => {
    jest.resetModules();
    env.setEnvForTests({
      NODE_ENV: 'test',
      DATABASE_URL: 'mysql://test:test@localhost:3306/hms_demo',
      JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
      CORS_ORIGINS: 'http://localhost:3000'});
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
      CORS_ORIGINS: 'http://localhost:3000'});

    const { assertDemoTaskAllowed } = require('../../../scripts/demo-safety');

    expect(assertDemoTaskAllowed('demo seed')).toEqual({
      allowed: false,
      reason: 'production_environment'});
  });

  describe('production override', () => {
    const asProduction = () =>
      env.setEnvForTests({
        NODE_ENV: 'production',
        DATABASE_URL: 'mysql://test:test@localhost:3306/hms_demo',
        JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
        CORS_ORIGINS: 'http://localhost:3000'});

    afterEach(() => {
      delete process.env.ALLOW_PRODUCTION_DEMO_SEED;
    });

    it('allows an opted-in caller when the override variable is set', () => {
      asProduction();
      process.env.ALLOW_PRODUCTION_DEMO_SEED = '1';

      const { assertDemoTaskAllowed } = require('../../../scripts/demo-safety');

      expect(assertDemoTaskAllowed('demo seed', { allowProductionOverride: true })).toEqual({
        allowed: true,
        reason: null});
    });

    it('still blocks callers that do not opt in, even with the variable set', () => {
      asProduction();
      process.env.ALLOW_PRODUCTION_DEMO_SEED = '1';

      const { assertDemoTaskAllowed } = require('../../../scripts/demo-safety');

      // clear-demo-data and clean-duplicate-encounters delete rows; the
      // variable must never unlock them.
      expect(assertDemoTaskAllowed('demo data clear')).toEqual({
        allowed: false,
        reason: 'production_environment'});
    });

    it('still blocks an opted-in caller when the variable is unset', () => {
      asProduction();

      const { assertDemoTaskAllowed } = require('../../../scripts/demo-safety');

      expect(assertDemoTaskAllowed('demo seed', { allowProductionOverride: true })).toEqual({
        allowed: false,
        reason: 'production_environment'});
    });
  });

  it('rejects production-like database targets outside production too', () => {
    env.setEnvForTests({
      NODE_ENV: 'development',
      DATABASE_URL: 'mysql://demo:demo@localhost:3306/hms-live',
      JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
      CORS_ORIGINS: 'http://localhost:3000'});

    const { assertDemoTaskAllowed } = require('../../../scripts/demo-safety');

    expect(() => assertDemoTaskAllowed('demo seed')).toThrow('production/live database');
  });
});
