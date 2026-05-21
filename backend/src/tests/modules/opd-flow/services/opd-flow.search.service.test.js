jest.mock('@repositories/opd-flow/opd-flow.repository', () => ({
  findMany: jest.fn(),
  count: jest.fn(),
}));
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn(),
}));
jest.mock('@lib/websocket', () => ({
  emitToUser: jest.fn(),
  emitToUsers: jest.fn(),
  OPD_EVENTS: {
    OPD_FLOW_UPDATED: 'opd.flow.updated',
  },
  NOTIFICATION_EVENTS: {
    NOTIFICATION_CREATED: 'notification.created',
  },
}));
jest.mock('@prisma/client', () => ({
  $transaction: jest.fn(),
  user_role: {
    findMany: jest.fn(),
  },
  notification: {
    create: jest.fn(),
  },
  notification_delivery: {
    createMany: jest.fn(),
  },
  tenant: {
    findFirst: jest.fn(),
  },
  facility: {
    findFirst: jest.fn(),
  },
  patient: {
    findFirst: jest.fn(),
  },
  user: {
    findFirst: jest.fn(),
  },
}));

const opdFlowRepository = require('@repositories/opd-flow/opd-flow.repository');
const opdFlowService = require('@services/opd-flow/opd-flow.service');

describe('opd-flow.service search filters', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    opdFlowRepository.findMany.mockResolvedValue([]);
    opdFlowRepository.count.mockResolvedValue(0);
  });

  it('builds tokenized patient-linked search clauses for OPD list', async () => {
    await opdFlowService.listOpdFlows(
      {
        search: 'pat-001 guardian',
      },
      1,
      20,
      'started_at',
      'desc'
    );

    expect(opdFlowRepository.findMany).toHaveBeenCalledTimes(1);
    const where = opdFlowRepository.findMany.mock.calls[0][0];

    expect(Array.isArray(where.AND)).toBe(true);
    expect(where.AND).toHaveLength(4);
    expect(JSON.stringify(where.AND[0])).toContain('$.opd_flow.stage');

    const serialized = JSON.stringify(where);
    expect(serialized).toContain('"identifiers"');
    expect(serialized).toContain('"contacts"');
    expect(serialized).toContain('"guardians"');
    expect(serialized).toContain('PAT-001');
    expect(serialized).toContain('GUARDIAN');

    const hasForbiddenPatientLeafFields = where.AND.some((tokenClause) =>
      (tokenClause?.OR || []).some((clause) => {
        const patientClause = clause?.patient;
        return Boolean(
          patientClause?.middle_name || patientClause?.phone || patientClause?.email
        );
      })
    );
    expect(hasForbiddenPatientLeafFields).toBe(false);

    const hasProviderRegressionCoverage = where.AND.some((tokenClause) =>
      (tokenClause?.OR || []).some(
        (clause) =>
          clause?.provider?.phone ||
          clause?.provider?.email ||
          clause?.provider?.profile?.middle_name
      )
    );
    expect(hasProviderRegressionCoverage).toBe(true);

    const hasProviderPositionTitleClause = where.AND.some((tokenClause) =>
      (tokenClause?.OR || []).some((clause) => clause?.provider?.position_title)
    );
    expect(hasProviderPositionTitleClause).toBe(false);
  });

  it('preserves non-search filters while applying tokenized search', async () => {
    await opdFlowService.listOpdFlows(
      {
        encounter_type: 'OPD',
        stage: 'WAITING_VITALS',
        search: 'jane doe',
      },
      1,
      20,
      'started_at',
      'desc'
    );

    const where = opdFlowRepository.findMany.mock.calls[0][0];
    expect(where.encounter_type).toBe('OPD');
    expect(where.extension_json).toEqual({
      path: '$.opd_flow.stage',
      equals: 'WAITING_VITALS',
    });
    expect(Array.isArray(where.AND)).toBe(true);
    expect(where.AND).toHaveLength(3);
    expect(JSON.stringify(where.AND)).toContain('JANE');
    expect(JSON.stringify(where.AND)).toContain('DOE');
  });
});
