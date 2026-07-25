jest.mock('@middlewares/auth.middleware', () => ({
  authenticate: jest.fn(() => (_req, _res, next) => next()),
  authorize: jest.fn(() => (_req, _res, next) => next()),
}));

const { PERMISSIONS } = require('@config/permissions');

const RADIOLOGY_CATALOG_WRITE_SCOPES = [
  PERMISSIONS.RADIOLOGY_WRITE,
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];

describe('radiology-procedure.routes contract', () => {
  beforeEach(() => {
    jest.resetModules();
    jest.clearAllMocks();
  });

  it('exports an express router with registered handlers', () => {
    const subject = require('@routes/radiology-procedure/radiology-procedure.routes');
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('function');
    expect(Array.isArray(subject.stack)).toBe(true);
    expect(subject.stack.length).toBeGreaterThan(0);
  });

  it('authorizes create, update, and delete with radiology catalog write scopes', () => {
    const authMiddleware = require('@middlewares/auth.middleware');
    require('@routes/radiology-procedure/radiology-procedure.routes');

    expect(authMiddleware.authorize).toHaveBeenCalledTimes(3);
    expect(authMiddleware.authorize).toHaveBeenNthCalledWith(
      1,
      RADIOLOGY_CATALOG_WRITE_SCOPES,
      'permission'
    );
    expect(authMiddleware.authorize).toHaveBeenNthCalledWith(
      2,
      RADIOLOGY_CATALOG_WRITE_SCOPES,
      'permission'
    );
    expect(authMiddleware.authorize).toHaveBeenNthCalledWith(
      3,
      RADIOLOGY_CATALOG_WRITE_SCOPES,
      'permission'
    );
  });
});
