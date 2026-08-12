const { PERMISSIONS } = require('@config/permissions');

const passthrough = () => (_req, _res, next) => next();

const loadRoute = () => {
  jest.resetModules();
  const authenticate = jest.fn(passthrough);
  const authorize = jest.fn(passthrough);
  jest.doMock('@middlewares/auth.middleware', () => ({
    authenticate,
    authorize,
  }));
  jest.doMock('@controllers/ai/ai.controller', () => ({
    getAiStatus: jest.fn(),
    runAiTask: jest.fn(),
  }));

  let router;
  jest.isolateModules(() => {
    router = require('@routes/ai/ai.routes');
  });
  return { router, authenticate, authorize };
};

const getRouteSignatures = (router) =>
  router.stack
    .filter((layer) => layer.route)
    .flatMap((layer) =>
      Object.keys(layer.route.methods).map(
        (method) => `${method.toUpperCase()} ${layer.route.path}`
      )
    )
    .sort();

describe('ai.routes', () => {
  test('registers status and generic task routes', () => {
    const { router } = loadRoute();
    expect(getRouteSignatures(router)).toEqual([
      'GET /status',
      'POST /tasks/:task_key',
    ]);
  });

  test('requires authentication and profile:read', () => {
    const { authenticate, authorize } = loadRoute();
    expect(authenticate).toHaveBeenCalledTimes(2);
    expect(authorize.mock.calls).toEqual([
      [PERMISSIONS.PROFILE_READ, 'permission'],
      [PERMISSIONS.PROFILE_READ, 'permission'],
    ]);
  });
});
