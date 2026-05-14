describe('app initialization', () => {
  afterEach(() => {
    jest.resetModules();
    jest.restoreAllMocks();
  });

  it('applies the configured trust proxy value', () => {
    const passthrough = () => (req, res, next) => next();

    jest.doMock('@config/env', () => ({
      TRUST_PROXY: 1
    }));
    jest.doMock('@config/cors', () => ({
      corsOptions: {}
    }));
    jest.doMock('@middlewares/security.middleware', () => passthrough);
    jest.doMock('@middlewares/session.middleware', () => passthrough);
    jest.doMock('@middlewares/csrf.middleware', () => passthrough);
    jest.doMock('@middlewares/i18n.middleware', () => passthrough);
    jest.doMock('@middlewares/versioning.middleware', () => passthrough);
    jest.doMock('@middlewares/performance.middleware', () => passthrough);
    jest.doMock('@middlewares/error.middleware', () => (err, req, res, next) => next(err));
    jest.doMock('@middlewares/request-context.middleware', () => ({
      initializeRequestContext: passthrough
    }));
    jest.doMock('@middlewares/rateLimit.middleware', () => ({
      defaultRateLimit: passthrough
    }));
    jest.doMock('@middlewares/offline.middleware', () => ({
      offlineSupportMiddleware: passthrough
    }));
    jest.doMock('@app/router', () => (req, res, next) => next());

    let createApp;
    jest.isolateModules(() => {
      createApp = require('@app/index');
    });

    const app = createApp();

    expect(app.get('trust proxy')).toBe(1);
  });
});
