const { PERMISSIONS } = require('@config/permissions');

describe('ipd-flow.routes RBAC wiring', () => {
  const loadSubject = () => {
    let subject;
    const authenticate = jest.fn(() => (_req, _res, next) => next());
    const authorize = jest.fn(() => (_req, _res, next) => next());
    const validateRequest = jest.fn(() => (_req, _res, next) => next());
    const controller = new Proxy(
      {},
      {
        get: () => jest.fn(),
      }
    );

    jest.isolateModules(() => {
      jest.doMock('@middlewares/auth.middleware', () => ({
        authenticate,
        authorize,
      }));
      jest.doMock('@middlewares/validate.middleware', () => ({
        validateRequest,
      }));
      jest.doMock('@controllers/ipd-flow/ipd-flow.controller', () => controller);
      subject = require('@routes/ipd-flow/ipd-flow.routes');
    });

    return { subject, authenticate, authorize, validateRequest };
  };

  beforeEach(() => {
    jest.resetModules();
    jest.clearAllMocks();
  });

  it('uses clinical read scopes for read routes and clinical write scopes for mutating routes', () => {
    const { subject, authorize } = loadSubject();

    expect(subject).toBeDefined();
    expect(authorize).toHaveBeenCalledTimes(18);

    const readCalls = authorize.mock.calls.slice(0, 3);
    readCalls.forEach((call) => {
      expect(call).toEqual([[PERMISSIONS.CLINICAL_READ], 'permission']);
    });

    const writeCalls = authorize.mock.calls.slice(3);
    writeCalls.forEach((call) => {
      expect(call).toEqual([[PERMISSIONS.CLINICAL_WRITE], 'permission']);
    });
  });
});
