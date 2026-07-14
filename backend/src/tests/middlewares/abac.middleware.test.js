const mockResolvePatientContext = jest.fn();
const mockResolveEncounterContext = jest.fn();
const mockFindApplicablePolicies = jest.fn().mockResolvedValue([]);

jest.mock('@prisma/client', () => ({
  phi_access_log: {
    create: jest.fn().mockResolvedValue({}),
  },
}));
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue({}),
}));
jest.mock('@lib/telemetry/metrics', () => ({
  recordSecurityEvent: jest.fn(),
  recordWorkflowEvent: jest.fn(),
}));
jest.mock('@lib/authorization/policy-evaluator', () => ({
  evaluatePolicies: jest.fn(() => ({ allowed: true, winner: null })),
}));
jest.mock('@lib/authorization/access.repository', () => ({
  findActiveBreakGlassAccess: jest.fn(),
  findApplicablePolicies: (...args) => mockFindApplicablePolicies(...args),
  findUserScopeContext: jest.fn().mockResolvedValue({
    department_id: null,
    has_active_shift: true,
    active_shift_id: 'shift-1',
  }),
  resolveAdmissionBackedContext: jest.fn(),
  resolveClinicalNoteContext: jest.fn(),
  resolveEncounterContext: (...args) => mockResolveEncounterContext(...args),
  resolveEquipmentWorkOrderContext: jest.fn(),
  resolveOfficeScopedContext: jest.fn(),
  resolvePatientContext: (...args) => mockResolvePatientContext(...args),
  resolvePaymentContext: jest.fn(),
  resolveRefundContext: jest.fn(),
}));

const { enforceAbacAccess } = require('@middlewares/abac.middleware');

const createRequest = (overrides = {}) => ({
  method: 'GET',
  path: '/encounters',
  originalUrl: '/encounters',
  params: {},
  query: {},
  body: {},
  user: {
    id: 'user-1',
    tenant_id: 'tenant-1',
    facility_id: 'facility-1',
    roles: ['DOCTOR'],
    permissions: ['clinical:read', 'clinical:write'],
  },
  ...overrides,
});

const runMiddleware = async (req) => {
  const next = jest.fn();
  await enforceAbacAccess()(req, {}, next);
  return next;
};

describe('ABAC unresolved-object non-enumeration', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockFindApplicablePolicies.mockResolvedValue([]);
  });

  it('returns uniform not-found for a classified detail ID that cannot be resolved', async () => {
    mockResolveEncounterContext.mockResolvedValue(null);
    const req = createRequest({
      path: '/encounters/unresolved-id',
      originalUrl: '/encounters/unresolved-id',
      params: { id: 'unresolved-id' },
    });

    const next = await runMiddleware(req);
    const error = next.mock.calls[0][0];

    expect(mockResolveEncounterContext).toHaveBeenCalledWith('unresolved-id');
    expect(error).toMatchObject({
      message: 'errors.not_found',
      statusCode: 404,
    });
    expect(mockFindApplicablePolicies).not.toHaveBeenCalled();
  });

  it('does not fall back to a body-linked object when a detail ID is unresolved', async () => {
    mockResolveEncounterContext.mockResolvedValue(null);
    const req = createRequest({
      method: 'PUT',
      path: '/encounters/unresolved-id',
      originalUrl: '/encounters/unresolved-id',
      params: { id: 'unresolved-id' },
      body: { patient_id: 'other-patient' },
    });

    const next = await runMiddleware(req);

    expect(next.mock.calls[0][0]).toMatchObject({ statusCode: 404 });
    expect(mockResolvePatientContext).not.toHaveBeenCalled();
  });

  it('continues list and create flows that do not address an object by ID', async () => {
    mockResolvePatientContext.mockResolvedValue({
      id: 'patient-1',
      patient_id: 'patient-1',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
    });

    const listNext = await runMiddleware(createRequest());
    const createNext = await runMiddleware(createRequest({
      method: 'POST',
      body: { patient_id: 'patient-1' },
    }));

    expect(listNext).toHaveBeenCalledWith();
    expect(createNext).toHaveBeenCalledWith();
    expect(mockResolvePatientContext).toHaveBeenCalledWith('patient-1');
    expect(mockFindApplicablePolicies).toHaveBeenCalledTimes(2);
  });
});
