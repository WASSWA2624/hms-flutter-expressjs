const { PERMISSIONS } = require('@config/permissions');

describe('ipd-flow.routes RBAC wiring', () => {
  const loadSubject = () => {
    let subject;
    const authenticate = jest.fn(() => (_req, _res, next) => next());
    const authorize = jest.fn(() => (_req, _res, next) => next());
    const denyRoles = jest.fn(() => (_req, _res, next) => next());
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
        denyRoles,
      }));
      jest.doMock('@middlewares/validate.middleware', () => ({
        validateRequest,
      }));
      jest.doMock('@controllers/ipd-flow/ipd-flow.controller', () => controller);
      subject = require('@routes/ipd-flow/ipd-flow.routes');
    });

    return { subject, authenticate, authorize, denyRoles, validateRequest };
  };

  const READ_SCOPES = [
    PERMISSIONS.CLINICAL_READ,
    PERMISSIONS.OPERATIONS_READ,
    PERMISSIONS.BILLING_READ,
  ];
  const OPERATIONAL_WRITE_SCOPES = [
    PERMISSIONS.CLINICAL_WRITE,
    PERMISSIONS.OPERATIONS_WRITE,
  ];
  const CLINICAL_WRITE_SCOPES = [PERMISSIONS.CLINICAL_WRITE];

  beforeEach(() => {
    jest.resetModules();
    jest.clearAllMocks();
  });

  it('denies staff patient-flow roles at the router level', () => {
    const { denyRoles } = loadSubject();

    expect(denyRoles).toHaveBeenCalledTimes(1);
  });

  it('uses read scopes for reads and write scopes for mutating routes', () => {
    const { subject, authorize } = loadSubject();

    expect(subject).toBeDefined();
    // 3 read routes + 6 operational-write routes + 12 clinical-write routes.
    expect(authorize).toHaveBeenCalledTimes(21);

    const readCalls = authorize.mock.calls.slice(0, 3);
    readCalls.forEach((call) => {
      expect(call).toEqual([READ_SCOPES, 'permission']);
    });

    // Operational write routes: start, assign-bed, release-bed,
    // reject-admission, request-transfer, update-transfer.
    const operationalCalls = authorize.mock.calls.slice(3, 9);
    operationalCalls.forEach((call) => {
      expect(call).toEqual([OPERATIONAL_WRITE_SCOPES, 'permission']);
    });

    // Remaining clinical write routes.
    const clinicalCalls = authorize.mock.calls.slice(9);
    clinicalCalls.forEach((call) => {
      expect(call).toEqual([CLINICAL_WRITE_SCOPES, 'permission']);
    });
  });
});
