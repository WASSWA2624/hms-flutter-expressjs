jest.mock('@config/feature-flags', () => ({
  isFeatureEnabled: jest.fn(),
}));
jest.mock('@middlewares/auth.middleware', () => ({
  authorize: jest.fn(() => (_req, _res, next) => next()),
}));

const { HttpError } = require('@lib/errors');
const { isFeatureEnabled } = require('@config/feature-flags');
const { ROLES } = require('@config/roles');
const subject = require('../../../../modules/dashboard-workspace/routes/dashboard-workspace.routes');

const expectedDashboardRoles = Object.values(ROLES).filter(
  (role) => role !== ROLES.PATIENT && role !== ROLES.OTHER
);

describe('dashboard-workspace routes', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  it('exports an express router with registered handlers', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('function');
    expect(Array.isArray(subject.stack)).toBe(true);
    expect(subject.stack.length).toBeGreaterThan(0);
  });

  it('gates the router behind the dashboard workspace feature flag', () => {
    const next = jest.fn();
    const middleware = subject.stack[0]?.handle;

    isFeatureEnabled.mockReturnValue(false);
    middleware({}, {}, next);

    expect(isFeatureEnabled).toHaveBeenCalledWith('dashboard_workspace_v1');
    expect(next).toHaveBeenCalledWith(expect.any(HttpError));
    expect(next.mock.calls[0][0].statusCode).toBe(404);
  });

  it('allows the request through when the feature flag is enabled', () => {
    const next = jest.fn();
    const middleware = subject.stack[0]?.handle;

    isFeatureEnabled.mockReturnValue(true);
    middleware({}, {}, next);

    expect(next).toHaveBeenCalledWith();
  });

  it('restricts dashboard routes to staff roles', () => {
    jest.resetModules();

    const reloadedAuthMiddleware = require('@middlewares/auth.middleware');
    require('../../../../modules/dashboard-workspace/routes/dashboard-workspace.routes');

    expect(reloadedAuthMiddleware.authorize).toHaveBeenCalledTimes(2);
    expect(reloadedAuthMiddleware.authorize).toHaveBeenNthCalledWith(1, expectedDashboardRoles, 'role');
    expect(reloadedAuthMiddleware.authorize).toHaveBeenNthCalledWith(2, expectedDashboardRoles, 'role');
  });
});
