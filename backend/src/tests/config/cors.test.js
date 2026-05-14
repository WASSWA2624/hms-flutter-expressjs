jest.mock('@lib/logging', () => ({
  logger: {
    warn: jest.fn(),
    info: jest.fn(),
    error: jest.fn()
  }
}));

const loadCorsConfig = (overrides = {}) => {
  jest.resetModules();
  const { setEnvForTests } = require('@config/env');
  setEnvForTests({
    JWT_SECRET: 'test-jwt-secret-key-minimum-32-characters-long',
    DATABASE_URL: 'mysql://test:test@localhost:3306/test_db',
    NODE_ENV: 'development',
    CORS_ORIGINS: 'http://example.com',
    ALLOW_PRIVATE_NETWORK_ORIGINS: 'true',
    ...overrides,
  });
  return require('@config/cors');
};

describe('CORS config', () => {
  test('allows configured origin', (done) => {
    const { corsOptions } = loadCorsConfig();
    corsOptions.origin('http://example.com', (err, allowed) => {
      expect(err).toBeNull();
      expect(allowed).toBe(true);
      done();
    });
  });

  test('exposes required methods and headers', () => {
    const { corsOptions } = loadCorsConfig();
    expect(corsOptions.credentials).toBe(true);
    expect(corsOptions.methods).toContain('OPTIONS');
    expect(corsOptions.allowedHeaders).toContain('Content-Type');
    expect(corsOptions.allowedHeaders).toContain('Authorization');
    expect(corsOptions.allowedHeaders).toContain('X-Locale');
    expect(corsOptions.allowedHeaders).toContain('X-Timezone');
    expect(corsOptions.allowedHeaders).toContain('X-Platform');
    expect(corsOptions.allowedHeaders).toContain('Sec-CH-UA');
    expect(corsOptions.allowedHeaders).toContain('Sec-CH-UA-Mobile');
    expect(corsOptions.allowedHeaders).toContain('Sec-CH-UA-Platform');
  });

  test('allows requests with no origin', (done) => {
    const { corsOptions } = loadCorsConfig();
    corsOptions.origin(undefined, (err, allowed) => {
      expect(err).toBeNull();
      expect(allowed).toBe(true);
      done();
    });
  });

  test('allows private IPv4 origin for LAN/mobile in development', (done) => {
    const { corsOptions } = loadCorsConfig();
    corsOptions.origin('http://192.168.1.40:8081', (err, allowed) => {
      expect(err).toBeNull();
      expect(allowed).toBe(true);
      done();
    });
  });

  test('allows local hostname origin in development', (done) => {
    const { corsOptions } = loadCorsConfig();
    corsOptions.origin('http://desktop-hms.local:8081', (err, allowed) => {
      expect(err).toBeNull();
      expect(allowed).toBe(true);
      done();
    });
  });

  test('allows local Playwright static-export origin in development', (done) => {
    const { corsOptions } = loadCorsConfig({
      ALLOW_PRIVATE_NETWORK_ORIGINS: 'false',
    });
    corsOptions.origin('http://localhost:8084', (err, allowed) => {
      expect(err).toBeNull();
      expect(allowed).toBe(true);
      done();
    });
  });

  test('allows private-network origin in production when explicitly enabled', (done) => {
    const { corsOptions } = loadCorsConfig({
      NODE_ENV: 'production',
      ALLOW_PRIVATE_NETWORK_ORIGINS: 'true',
    });
    corsOptions.origin('http://192.168.10.22:8081', (err, allowed) => {
      expect(err).toBeNull();
      expect(allowed).toBe(true);
      done();
    });
  });

  test('allows local Playwright static-export origin in production when loopback origins are explicitly configured', (done) => {
    const { corsOptions } = loadCorsConfig({
      NODE_ENV: 'production',
      CORS_ORIGINS: 'http://localhost:8081,http://127.0.0.1:8081',
      ALLOW_PRIVATE_NETWORK_ORIGINS: 'false',
    });
    corsOptions.origin('http://localhost:8085', (err, allowed) => {
      expect(err).toBeNull();
      expect(allowed).toBe(true);
      done();
    });
  });

  test('rejects disallowed origin', (done) => {
    const { corsOptions } = loadCorsConfig();
    corsOptions.origin('http://evil.test', (err) => {
      expect(err).toBeInstanceOf(Error);
      expect(err.statusCode).toBe(403);
      done();
    });
  });

  test('rejects private-network origin in production when disabled', (done) => {
    const { corsOptions } = loadCorsConfig({
      NODE_ENV: 'production',
      ALLOW_PRIVATE_NETWORK_ORIGINS: 'false',
    });
    corsOptions.origin('http://192.168.10.22:8081', (err) => {
      expect(err).toBeInstanceOf(Error);
      expect(err.statusCode).toBe(403);
      done();
    });
  });
});
