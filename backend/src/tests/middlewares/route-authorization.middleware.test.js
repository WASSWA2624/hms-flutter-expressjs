const { PERMISSIONS } = require('@config/permissions');

const passthrough = () => (_req, _res, next) => next();

const loadRoute = (routeModule, controllerModule, extraMocks = {}) => {
  jest.resetModules();

  const authenticate = jest.fn(passthrough);
  const authorize = jest.fn(passthrough);
  const controller = new Proxy({}, { get: () => jest.fn() });

  jest.doMock('@middlewares/auth.middleware', () => ({
    authenticate,
    authorize,
  }));
  jest.doMock(controllerModule, () => controller);
  Object.entries(extraMocks).forEach(([moduleName, factory]) => {
    jest.doMock(moduleName, factory);
  });

  let router;
  jest.isolateModules(() => {
    router = require(routeModule);
  });

  return { router, authenticate, authorize };
};

describe('high-risk route permission wiring', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  it('protects encounter reads and writes with clinical permissions', () => {
    const { authorize } = loadRoute(
      '@routes/encounter/encounter.routes',
      '@controllers/encounter/encounter.controller'
    );

    expect(authorize.mock.calls).toEqual([
      [PERMISSIONS.CLINICAL_READ, 'permission'],
      [PERMISSIONS.CLINICAL_READ, 'permission'],
      [PERMISSIONS.CLINICAL_WRITE, 'permission'],
      [PERMISSIONS.CLINICAL_WRITE, 'permission'],
      [PERMISSIONS.CLINICAL_WRITE, 'permission'],
    ]);
  });

  it('keeps admission and clinical-note PHI routes permission-gated', () => {
    const admission = loadRoute(
      '@routes/admission/admission.routes',
      '@controllers/admission/admission.controller'
    );
    expect(admission.authorize).toHaveBeenCalledTimes(7);
    expect(admission.authorize.mock.calls.slice(0, 2)).toEqual([
      [[PERMISSIONS.CLINICAL_READ], 'permission'],
      [[PERMISSIONS.CLINICAL_READ], 'permission'],
    ]);

    const clinicalNote = loadRoute(
      '@routes/clinical-note/clinical-note.routes',
      '@controllers/clinical-note/clinical-note.controller',
      {
        '@middlewares/clinical-guard.middleware': () => ({
          requireClinicalDeletePrivilege: jest.fn(passthrough),
        }),
      }
    );
    expect(clinicalNote.authorize.mock.calls).toEqual([
      [PERMISSIONS.CLINICAL_READ, 'permission'],
      [PERMISSIONS.CLINICAL_READ, 'permission'],
      [PERMISSIONS.CLINICAL_WRITE, 'permission'],
      [PERMISSIONS.CLINICAL_WRITE, 'permission'],
      [PERMISSIONS.CLINICAL_WRITE, 'permission'],
    ]);
  });

  it('uses HR permissions for user administration', () => {
    const { authorize } = loadRoute(
      '@routes/user/user.routes',
      '@controllers/user/user.controller'
    );
    const readScopes = [
      PERMISSIONS.HR_READ,
      PERMISSIONS.TENANT_ADMIN,
      PERMISSIONS.FACILITY_ADMIN,
      PERMISSIONS.SYSTEM_ADMIN,
    ];
    const writeScopes = [
      PERMISSIONS.HR_WRITE,
      PERMISSIONS.TENANT_ADMIN,
      PERMISSIONS.FACILITY_ADMIN,
      PERMISSIONS.SYSTEM_ADMIN,
    ];

    expect(authorize.mock.calls).toEqual([
      [readScopes, 'permission'],
      [writeScopes, 'permission'],
      [readScopes, 'permission'],
      [writeScopes, 'permission'],
      [writeScopes, 'permission'],
      [writeScopes, 'permission'],
    ]);
  });

  it.each([
    ['@routes/role/role.routes', '@controllers/role/role.controller'],
    ['@routes/permission/permission.routes', '@controllers/permission/permission.controller'],
  ])('restricts access-catalog route %s to admin permissions', (routeModule, controllerModule) => {
    const { authorize } = loadRoute(routeModule, controllerModule);
    const adminScopes = [
      PERMISSIONS.TENANT_ADMIN,
      PERMISSIONS.FACILITY_ADMIN,
      PERMISSIONS.SYSTEM_ADMIN,
    ];

    expect(authorize).toHaveBeenCalledTimes(5);
    authorize.mock.calls.forEach((call) => {
      expect(call).toEqual([adminScopes, 'permission']);
    });
  });

  it('requires evidence-export permission for report and interop downloads', () => {
    const reportRun = loadRoute(
      '@routes/report-run/report-run.routes',
      '@controllers/report-run/report-run.controller'
    );
    expect(reportRun.authorize).toHaveBeenLastCalledWith(
      PERMISSIONS.EVIDENCE_EXPORT,
      'permission'
    );

    const interop = loadRoute(
      '@routes/interop/interop.routes',
      '@controllers/interop/interop.controller'
    );
    expect(interop.authorize.mock.calls).toEqual([
      [PERMISSIONS.EVIDENCE_EXPORT, 'permission'],
      [PERMISSIONS.EVIDENCE_EXPORT, 'permission'],
    ]);
  });
});
