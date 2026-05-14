const { HttpError } = require('@lib/errors');

jest.mock('@repositories/radiology-workspace/radiology-workspace.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn(),
}));
jest.mock('@lib/websocket', () => ({
  emitToUsers: jest.fn(),
  DIAGNOSTIC_EVENTS: {
    RADIOLOGY_WORKFLOW_UPDATED: 'diagnostic.radiology_workflow_updated',
    RADIOLOGY_RESULT_UPDATED: 'diagnostic.radiology_result_updated',
    RADIOLOGY_RESULT_READY: 'diagnostic.radiology_result_ready',
  },
}));
jest.mock('@prisma/client', () => ({
  user_role: {
    findMany: jest.fn(),
  },
}));
jest.mock('@lib/dicomweb/client', () => ({
  isConfigured: jest.fn(),
  stowStudy: jest.fn(),
  buildStudyUrl: jest.fn(),
}));
jest.mock('@services/radiology-workspace/radiology.shared', () => {
  const actual = jest.requireActual('@services/radiology-workspace/radiology.shared');
  return {
    ...actual,
    resolveModelIdOrThrow: jest.fn(),
    resolveModelRecordOrThrow: jest.fn(),
  };
});

const radiologyWorkspaceRepository = require('@repositories/radiology-workspace/radiology-workspace.repository');
const { createAuditLog } = require('@lib/audit');
const { emitToUsers } = require('@lib/websocket');
const prisma = require('@prisma/client');
const dicomWebClient = require('@lib/dicomweb/client');
const {
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
} = require('@services/radiology-workspace/radiology.shared');
const radiologyWorkspaceService = require('@services/radiology-workspace/radiology-workspace.service');

const now = new Date('2026-02-27T10:20:00.000Z');

const buildOrder = (overrides = {}) => ({
  id: 'order-internal-1',
  human_friendly_id: 'RAD0000001',
  status: 'ORDERED',
  ordered_at: now,
  created_at: now,
  updated_at: now,
  patient_id: 'patient-internal-1',
  encounter_id: 'encounter-internal-1',
  patient: {
    id: 'patient-internal-1',
    human_friendly_id: 'PAT0000001',
    tenant_id: 'tenant-internal-1',
    facility_id: 'facility-internal-1',
    first_name: 'Amina',
    last_name: 'Stone',
  },
  encounter: {
    id: 'encounter-internal-1',
    human_friendly_id: 'ENC0000001',
  },
  radiology_test: {
    id: 'rtest-internal-1',
    human_friendly_id: 'RDT0000001',
    name: 'Chest XRay',
    code: 'CXR',
    modality: 'XRAY',
  },
  results: [],
  imaging_studies: [],
  ...overrides,
});

const flushAsync = () => new Promise((resolve) => setImmediate(resolve));

describe('radiology-workspace.service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    prisma.user_role.findMany.mockResolvedValue([
      { user_id: 'user-1' },
      { user_id: 'actor-1' },
      { user_id: 'user-2' },
    ]);
  });

  it('resolves legacy radiology route identifiers to canonical /radiology routes', async () => {
    resolveModelRecordOrThrow.mockResolvedValue({
      id: '19e508a6-ea17-4c7f-a0f4-b6f0ac401cb5',
      human_friendly_id: 'RADRES0005',
    });

    const resolved = await radiologyWorkspaceService.resolveLegacyRouteIdentifier(
      'radiology-results',
      '19e508a6-ea17-4c7f-a0f4-b6f0ac401cb5'
    );

    expect(resolved).toEqual({
      id: 'RADRES0005',
      resource: 'results',
      identifier: 'RADRES0005',
      route: '/radiology/results/RADRES0005',
      matched_by: 'uuid',
    });
  });

  it('assignRadiologyOrder emits radiology workflow realtime update without blocking mutation', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');
    radiologyWorkspaceRepository.findOrderById.mockResolvedValue(buildOrder());

    const result = await radiologyWorkspaceService.assignRadiologyOrder(
      'RAD0000001',
      { assignee_user_id: 'USR0000009' },
      'actor-1',
      '127.0.0.1'
    );

    expect(result?.workflow?.order?.id).toBe('RAD0000001');

    await flushAsync();

    expect(emitToUsers).toHaveBeenCalledWith(
      ['user-1', 'user-2'],
      'diagnostic.radiology_workflow_updated',
      expect.objectContaining({
        action: 'ASSIGN',
        order_id: 'RAD0000001',
      })
    );
  });

  it('returns scoped reference data with friendly identifiers only', async () => {
    radiologyWorkspaceRepository.findReferencePatients.mockResolvedValue([
      {
        id: 'patient-internal-1',
        human_friendly_id: 'PAT0000001',
        first_name: 'Amina',
        last_name: 'Stone',
        contacts: [{ value: '+256700000001' }],
      },
    ]);
    radiologyWorkspaceRepository.findReferenceEncounters.mockResolvedValue([
      {
        id: 'encounter-internal-1',
        human_friendly_id: 'ENC0000001',
        status: 'IN_PROGRESS',
        started_at: now,
        patient: {
          id: 'patient-internal-1',
          human_friendly_id: 'PAT0000001',
          first_name: 'Amina',
          last_name: 'Stone',
        },
      },
    ]);
    radiologyWorkspaceRepository.findReferenceRadiologyTests.mockResolvedValue([
      {
        id: 'rtest-internal-1',
        human_friendly_id: 'RDT0000001',
        name: 'Chest XRay',
        code: 'CXR',
        modality: 'XRAY',
      },
    ]);
    radiologyWorkspaceRepository.findReferenceUsers.mockResolvedValue([
      {
        id: 'user-internal-1',
        human_friendly_id: 'USR0000001',
        email: 'tech@example.com',
        profile: { first_name: 'Imani', middle_name: null, last_name: 'Tech' },
      },
    ]);

    const data = await radiologyWorkspaceService.getRadiologyReferenceData(
      { search: 'amina' },
      { tenant_id: 'tenant-internal-1', facility_id: 'facility-internal-1' }
    );

    expect(data.patients[0]).toEqual(
      expect.objectContaining({
        value: 'PAT0000001',
      })
    );
    expect(data.encounters[0]).toEqual(
      expect.objectContaining({
        value: 'ENC0000001',
        patient_id: 'PAT0000001',
      })
    );
    expect(data.radiology_tests[0]).toEqual(
      expect.objectContaining({
        value: 'RDT0000001',
      })
    );
    expect(data.assignees[0]).toEqual(
      expect.objectContaining({
        value: 'USR0000001',
      })
    );
  });

  it('creates radiology order and returns workflow payload', async () => {
    resolveModelRecordOrThrow.mockResolvedValueOnce({
      id: 'patient-internal-1',
      tenant_id: 'tenant-internal-1',
    });
    resolveModelIdOrThrow
      .mockResolvedValueOnce('encounter-internal-1')
      .mockResolvedValueOnce('rtest-internal-1');
    radiologyWorkspaceRepository.withTransaction.mockImplementation(async (callback) => callback({}));
    radiologyWorkspaceRepository.txCreateOrder.mockResolvedValue({
      id: 'order-internal-1',
    });
    radiologyWorkspaceRepository.txFindOrderById.mockResolvedValue(buildOrder());

    const result = await radiologyWorkspaceService.createRadiologyOrder(
      {
        patient_id: 'PAT0000001',
        encounter_id: 'ENC0000001',
        radiology_test_id: 'RDT0000001',
      },
      'actor-1',
      '127.0.0.1'
    );

    expect(result.workflow?.order?.id).toBe('RAD0000001');
    expect(result.order?.id).toBe('RAD0000001');
  });

  it('syncStudyToPacs returns FAILED status when pacs is not configured', async () => {
    resolveModelIdOrThrow.mockResolvedValue('study-internal-1');
    radiologyWorkspaceRepository.findStudyById.mockResolvedValue({
      id: 'study-internal-1',
      human_friendly_id: 'STD0000001',
      radiology_order_id: 'order-internal-1',
      modality: 'XRAY',
      assets: [],
      pacs_links: [],
    });
    radiologyWorkspaceRepository.findOrderById.mockResolvedValue(buildOrder());
    dicomWebClient.isConfigured.mockReturnValue(false);

    const result = await radiologyWorkspaceService.syncStudyToPacs(
      'STD0000001',
      {},
      'actor-1',
      '127.0.0.1'
    );

    expect(result).toEqual(
      expect.objectContaining({
        sync_status: 'FAILED',
      })
    );
    expect(result.error).toContain('PACS_DICOMWEB_BASE_URL');
  });

  it('syncStudyToPacs returns refreshed workflow after successful sync', async () => {
    resolveModelIdOrThrow.mockResolvedValue('study-internal-1');
    radiologyWorkspaceRepository.findStudyById.mockResolvedValue({
      id: 'study-internal-1',
      human_friendly_id: 'STD0000001',
      radiology_order_id: 'order-internal-1',
      modality: 'XRAY',
      assets: [],
      pacs_links: [],
    });
    radiologyWorkspaceRepository.findOrderById.mockResolvedValue(
      buildOrder({
        imaging_studies: [
          {
            id: 'study-internal-1',
            human_friendly_id: 'STD0000001',
            modality: 'XRAY',
            performed_at: now,
            created_at: now,
            updated_at: now,
            assets: [],
            pacs_links: [],
          },
        ],
      })
    );
    dicomWebClient.isConfigured.mockReturnValue(true);
    dicomWebClient.stowStudy.mockResolvedValue({ studyUid: '1.2.3' });
    dicomWebClient.buildStudyUrl.mockReturnValue('https://pacs.example/studies/1.2.3');

    radiologyWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    radiologyWorkspaceRepository.txCreatePacsLink.mockResolvedValue({
      id: 'pacs-link-1',
      human_friendly_id: 'PAC0000001',
      url: 'https://pacs.example/studies/1.2.3',
      created_at: now,
      updated_at: now,
      imaging_study_id: 'study-internal-1',
    });
    radiologyWorkspaceRepository.txFindOrderById.mockResolvedValue(
      buildOrder({
        imaging_studies: [
          {
            id: 'study-internal-1',
            human_friendly_id: 'STD0000001',
            modality: 'XRAY',
            performed_at: now,
            created_at: now,
            updated_at: now,
            assets: [],
            pacs_links: [
              {
                id: 'pacs-link-1',
                human_friendly_id: 'PAC0000001',
                url: 'https://pacs.example/studies/1.2.3',
                created_at: now,
                updated_at: now,
              },
            ],
          },
        ],
      })
    );

    const result = await radiologyWorkspaceService.syncStudyToPacs(
      'STD0000001',
      {},
      'actor-1',
      '127.0.0.1'
    );

    expect(result.sync_status).toBe('SUCCESS');
    expect(result.workflow?.order?.unsynced_study_count).toBe(0);
  });

  it('requestRadiologyResultFinalization records REQUEST attestation', async () => {
    resolveModelIdOrThrow.mockResolvedValue('result-internal-1');

    const order = buildOrder({
      status: 'IN_PROCESS',
      results: [
        {
          id: 'result-internal-1',
          human_friendly_id: 'RADRES0001',
          radiology_order_id: 'order-internal-1',
          status: 'DRAFT',
          report_text: 'Draft report',
          reported_at: now,
          created_at: now,
          updated_at: now,
          attestations: [],
        },
      ],
    });

    const resultWithRequest = {
      ...order.results[0],
      attestations: [
        {
          id: 'att-request-1',
          human_friendly_id: 'RAT000001',
          radiology_result_id: 'result-internal-1',
          phase: 'REQUEST',
          attested_by_user_id: 'actor-1',
          attested_role: 'DOCTOR',
          attested_at: now,
          created_at: now,
          updated_at: now,
        },
      ],
    };

    radiologyWorkspaceRepository.withTransaction.mockImplementation(async (callback) => callback({}));
    radiologyWorkspaceRepository.txFindResultById
      .mockResolvedValueOnce(order.results[0])
      .mockResolvedValueOnce(resultWithRequest);
    radiologyWorkspaceRepository.txFindResultAttestation.mockResolvedValueOnce(null);
    radiologyWorkspaceRepository.txCreateResultAttestation.mockResolvedValue({
      id: 'att-request-1',
    });
    radiologyWorkspaceRepository.txFindOrderById.mockResolvedValue(order);

    const response = await radiologyWorkspaceService.requestRadiologyResultFinalization(
      'RADRES0001',
      { statement: 'Please finalize' },
      'actor-1',
      'DOCTOR',
      '127.0.0.1'
    );

    expect(response.result.finalization.requested).toBe(true);
    expect(response.result.finalization.pending_attestation).toBe(true);
  });

  it('attestRadiologyResultFinalization rejects same-user second signature', async () => {
    resolveModelIdOrThrow.mockResolvedValue('result-internal-1');

    radiologyWorkspaceRepository.withTransaction.mockImplementation(async (callback) => callback({}));
    radiologyWorkspaceRepository.txFindResultById.mockResolvedValue({
      id: 'result-internal-1',
      human_friendly_id: 'RADRES0001',
      radiology_order_id: 'order-internal-1',
      status: 'DRAFT',
      report_text: 'Draft report',
      reported_at: now,
      created_at: now,
      updated_at: now,
      attestations: [],
    });
    radiologyWorkspaceRepository.txFindResultAttestation.mockResolvedValueOnce({
      id: 'att-request-1',
      phase: 'REQUEST',
      attested_by_user_id: 'actor-1',
    });

    await expect(
      radiologyWorkspaceService.attestRadiologyResultFinalization(
        'RADRES0001',
        {},
        'actor-1',
        'DOCTOR',
        '127.0.0.1'
      )
    ).rejects.toBeInstanceOf(HttpError);
  });

  it('throws not found when legacy resource identifier is missing', async () => {
    await expect(
      radiologyWorkspaceService.resolveLegacyRouteIdentifier('radiology-results', '')
    ).rejects.toBeInstanceOf(HttpError);
  });
});
