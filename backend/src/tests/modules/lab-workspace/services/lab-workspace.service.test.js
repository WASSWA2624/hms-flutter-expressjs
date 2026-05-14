const { HttpError } = require('@lib/errors');

jest.mock('@repositories/lab-workspace/lab-workspace.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn(),
}));
jest.mock('@lib/websocket', () => ({
  emitToUsers: jest.fn(),
  DIAGNOSTIC_EVENTS: {
    LAB_WORKFLOW_UPDATED: 'diagnostic.lab_workflow_updated',
    LAB_RESULT_READY: 'diagnostic.lab_result_ready',
    LAB_RESULT_UPDATED: 'diagnostic.lab_result_updated',
  },
}));
jest.mock('@prisma/client', () => ({
  user_role: {
    findMany: jest.fn(),
  },
}));
jest.mock('@services/lab-workspace/lab.shared', () => {
  const actual = jest.requireActual('@services/lab-workspace/lab.shared');
  return {
    ...actual,
    resolveModelIdOrThrow: jest.fn(),
    resolveModelRecordOrThrow: jest.fn(),
  };
});

const labWorkspaceRepository = require('@repositories/lab-workspace/lab-workspace.repository');
const { createAuditLog } = require('@lib/audit');
const { emitToUsers } = require('@lib/websocket');
const prisma = require('@prisma/client');
const {
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
} = require('@services/lab-workspace/lab.shared');
const labWorkspaceService = require('@services/lab-workspace/lab-workspace.service');

const now = new Date('2026-02-27T09:15:00.000Z');

const buildBaseOrder = (overrides = {}) => ({
  id: 'order-internal-1',
  human_friendly_id: 'LAB0000001',
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
  items: [],
  samples: [],
  ...overrides,
});

const flushAsync = () => new Promise((resolve) => setImmediate(resolve));

describe('lab-workspace.service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    prisma.user_role.findMany.mockResolvedValue([
      { user_id: 'user-1' },
      { user_id: 'actor-1' },
      { user_id: 'user-2' },
    ]);
  });

  it('resolves legacy lab route identifiers to canonical /lab routes', async () => {
    resolveModelRecordOrThrow.mockResolvedValue({
      id: '46e0498d-c2be-4f1d-bc69-d6a72fd6fb85',
      human_friendly_id: 'LABRES0005',
    });

    const resolved = await labWorkspaceService.resolveLegacyRouteIdentifier(
      'lab-results',
      '46e0498d-c2be-4f1d-bc69-d6a72fd6fb85'
    );

    expect(resolved).toEqual({
      id: 'LABRES0005',
      resource: 'results',
      identifier: 'LABRES0005',
      route: '/lab/results/LABRES0005',
      matched_by: 'uuid',
    });
  });

  it('collectLabOrder emits lab workflow realtime update without blocking mutation', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');

    const initialOrder = buildBaseOrder({
      status: 'ORDERED',
      items: [
        {
          id: 'item-internal-1',
          human_friendly_id: 'LIT0000001',
          status: 'ORDERED',
          created_at: now,
          updated_at: now,
          lab_test: {
            id: 'lab-test-internal-1',
            human_friendly_id: 'LBT0000001',
            name: 'CBC',
            code: 'CBC',
            unit: null,
          },
          results: [],
        },
      ],
      samples: [],
    });

    const refreshedOrder = buildBaseOrder({
      status: 'COLLECTED',
      items: [
        {
          id: 'item-internal-1',
          human_friendly_id: 'LIT0000001',
          status: 'COLLECTED',
          created_at: now,
          updated_at: now,
          lab_test: {
            id: 'lab-test-internal-1',
            human_friendly_id: 'LBT0000001',
            name: 'CBC',
            code: 'CBC',
            unit: null,
          },
          results: [],
        },
      ],
      samples: [
        {
          id: 'sample-internal-1',
          human_friendly_id: 'LSP0000001',
          status: 'COLLECTED',
          collected_at: now,
          received_at: null,
          created_at: now,
          updated_at: now,
        },
      ],
    });

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderById
      .mockResolvedValueOnce(initialOrder)
      .mockResolvedValueOnce(refreshedOrder);
    labWorkspaceRepository.txCreateSample.mockResolvedValue({
      id: 'sample-internal-1',
    });
    labWorkspaceRepository.txUpdateOrderItemsMany.mockResolvedValue({ count: 1 });
    labWorkspaceRepository.txUpdateOrder.mockResolvedValue({ id: 'order-internal-1' });

    const result = await labWorkspaceService.collectLabOrder(
      'LAB0000001',
      { notes: 'Collected at bedside' },
      'actor-1',
      '127.0.0.1'
    );

    expect(result?.workflow?.order?.id).toBe('LAB0000001');

    await flushAsync();

    expect(emitToUsers).toHaveBeenCalledWith(
      ['user-1', 'user-2'],
      'diagnostic.lab_workflow_updated',
      expect.objectContaining({
        action: 'COLLECT',
        order_id: 'LAB0000001',
      })
    );
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'tenant-internal-1',
        entity: 'lab_order',
      })
    );
  });

  it('releaseLabOrderItem emits workflow and compatibility result realtime events', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-item-internal-1');

    const releasedResultInternal = {
      id: 'result-internal-1',
      human_friendly_id: 'LRS0000001',
      status: 'CRITICAL',
      result_value: '12.8',
      result_unit: 'mg/dL',
      result_text: 'Critical potassium level',
      result_flag: 'CRITICAL_HIGH',
      is_positive: false,
      reference_range_label: 'Adult',
      reference_range_summary: 'Adult | Unit mg/dL | 3.5 - 5.1',
      reported_at: now,
      created_at: now,
      updated_at: now,
      lab_order_item_id: 'order-item-internal-1',
    };

    const refreshedOrder = buildBaseOrder({
      status: 'COMPLETED',
      items: [
        {
          id: 'order-item-internal-1',
          human_friendly_id: 'LIT0000002',
          status: 'COMPLETED',
          created_at: now,
          updated_at: now,
          lab_test: {
            id: 'lab-test-internal-2',
            human_friendly_id: 'LBT0000002',
            name: 'Potassium',
            code: 'K',
            unit: 'mg/dL',
          },
          results: [releasedResultInternal],
        },
      ],
      samples: [],
    });

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderItemById.mockResolvedValue({
      id: 'order-item-internal-1',
      lab_order_id: 'order-internal-1',
      status: 'IN_PROCESS',
      lab_test: {
        id: 'lab-test-internal-2',
        unit: 'mg/dL',
        reference_ranges: [
          {
            label: 'Adult',
            unit: 'mg/dL',
            age_min_value: 18,
            age_min_unit: 'YEAR',
            normal_min_value: '3.5',
            normal_max_value: '5.1',
            critical_min_value: '2.5',
            critical_max_value: '6.5',
            sort_order: 0,
          },
        ],
        unit_options: [],
        result_options: [],
      },
      lab_order: {
        id: 'order-internal-1',
        status: 'IN_PROCESS',
        patient: {
          gender: 'FEMALE',
          date_of_birth: new Date('1994-06-01T00:00:00.000Z'),
        },
      },
    });
    labWorkspaceRepository.txFindFirstResult
      .mockResolvedValueOnce({
        id: 'result-internal-1',
        status: 'PENDING',
        result_value: null,
        result_unit: null,
        result_text: null,
        reported_at: null,
      })
      .mockResolvedValueOnce(null);
    labWorkspaceRepository.txUpdateResult.mockResolvedValue(releasedResultInternal);
    labWorkspaceRepository.txUpdateOrderItem.mockResolvedValue({
      id: 'order-item-internal-1',
    });
    labWorkspaceRepository.txCountOrderItems.mockResolvedValue(0);
    labWorkspaceRepository.txUpdateOrder.mockResolvedValue({ id: 'order-internal-1' });
    labWorkspaceRepository.txFindOrderById.mockResolvedValue(refreshedOrder);

    const result = await labWorkspaceService.releaseLabOrderItem(
      'LIT0000002',
      {
        status: 'CRITICAL',
        result_value: '12.8',
        result_unit: 'mg/dL',
        result_text: 'Critical potassium level',
      },
      'actor-1',
      '127.0.0.1'
    );

    expect(result?.released_result?.id).toBe('LRS0000001');

    await flushAsync();

    const emittedEvents = emitToUsers.mock.calls.map((call) => call[1]);
    expect(emittedEvents).toContain('diagnostic.lab_workflow_updated');
    expect(emittedEvents).toContain('diagnostic.lab_result_updated');
    expect(emittedEvents).toContain('diagnostic.lab_result_ready');

    const resultUpdatedPayload = emitToUsers.mock.calls.find(
      (call) => call[1] === 'diagnostic.lab_result_updated'
    )?.[2];
    expect(resultUpdatedPayload).toEqual(
      expect.objectContaining({
        result_id: 'LRS0000001',
        result_status: 'CRITICAL',
      })
    );
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'tenant-internal-1',
        entity: 'lab_order_item',
      })
    );
  });

  it('reverseLabOrderWorkflow reopens the latest released result and emits realtime updates', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');

    const releaseTimestamp = new Date('2026-02-27T10:45:00.000Z');
    const currentOrder = buildBaseOrder({
      status: 'COMPLETED',
      samples: [
        {
          id: 'sample-internal-1',
          human_friendly_id: 'LSP0000001',
          status: 'RECEIVED',
          collected_at: now,
          received_at: now,
          created_at: now,
          updated_at: now,
        },
      ],
      items: [
        {
          id: 'order-item-internal-3',
          human_friendly_id: 'LIT0000003',
          status: 'COMPLETED',
          created_at: now,
          updated_at: releaseTimestamp,
          lab_test: {
            id: 'lab-test-internal-3',
            human_friendly_id: 'LBT0000003',
            name: 'CBC',
            code: 'CBC',
            unit: 'g/dL',
          },
          results: [
            {
              id: 'result-internal-3',
              human_friendly_id: 'LRS0000003',
              status: 'NORMAL',
              result_value: '13.4',
              result_unit: 'g/dL',
              result_text: 'Normal result',
              result_flag: null,
              is_positive: false,
              reference_range_label: 'Adult',
              reference_range_summary: 'Adult | Unit g/dL | 11.5 - 15.5',
              reported_at: releaseTimestamp,
              created_at: now,
              updated_at: releaseTimestamp,
              lab_order_item_id: 'order-item-internal-3',
            },
          ],
        },
      ],
    });

    const reopenedOrder = buildBaseOrder({
      status: 'IN_PROCESS',
      samples: [
        {
          id: 'sample-internal-1',
          human_friendly_id: 'LSP0000001',
          status: 'RECEIVED',
          collected_at: now,
          received_at: now,
          created_at: now,
          updated_at: now,
        },
      ],
      items: [
        {
          id: 'order-item-internal-3',
          human_friendly_id: 'LIT0000003',
          status: 'IN_PROCESS',
          created_at: now,
          updated_at: releaseTimestamp,
          lab_test: {
            id: 'lab-test-internal-3',
            human_friendly_id: 'LBT0000003',
            name: 'CBC',
            code: 'CBC',
            unit: 'g/dL',
          },
          results: [
            {
              id: 'result-internal-3',
              human_friendly_id: 'LRS0000003',
              status: 'PENDING',
              result_value: '13.4',
              result_unit: 'g/dL',
              result_text: 'Normal result',
              result_flag: null,
              is_positive: false,
              reference_range_label: 'Adult',
              reference_range_summary: 'Adult | Unit g/dL | 11.5 - 15.5',
              reported_at: null,
              created_at: now,
              updated_at: releaseTimestamp,
              lab_order_item_id: 'order-item-internal-3',
            },
          ],
        },
      ],
    });

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderById
      .mockResolvedValueOnce(currentOrder)
      .mockResolvedValueOnce(reopenedOrder);
    labWorkspaceRepository.txFindOrderItemById.mockResolvedValue({
      id: 'order-item-internal-3',
      status: 'COMPLETED',
    });
    labWorkspaceRepository.txFindResultById.mockResolvedValue({
      id: 'result-internal-3',
      status: 'NORMAL',
      reported_at: releaseTimestamp,
    });
    labWorkspaceRepository.txUpdateResult.mockResolvedValue({
      id: 'result-internal-3',
    });
    labWorkspaceRepository.txUpdateOrderItem.mockResolvedValue({
      id: 'order-item-internal-3',
    });
    labWorkspaceRepository.txCountSamples
      .mockResolvedValueOnce(1)
      .mockResolvedValueOnce(0);
    labWorkspaceRepository.txCountOrderItems
      .mockResolvedValueOnce(0)
      .mockResolvedValueOnce(1);
    labWorkspaceRepository.txUpdateOrderItemsMany.mockResolvedValue({ count: 1 });
    labWorkspaceRepository.txUpdateOrder.mockResolvedValue({ id: 'order-internal-1' });

    const result = await labWorkspaceService.reverseLabOrderWorkflow(
      'LAB0000001',
      { reason: 'Released by mistake' },
      'actor-1',
      '127.0.0.1'
    );

    expect(result?.workflow?.order?.id).toBe('LAB0000001');
    expect(labWorkspaceRepository.txUpdateResult).toHaveBeenCalledWith(
      {},
      'result-internal-3',
      expect.objectContaining({
        status: 'PENDING',
        reported_at: null,
      })
    );
    expect(labWorkspaceRepository.txUpdateOrderItemsMany).toHaveBeenCalledWith(
      {},
      expect.objectContaining({
        lab_order_id: 'order-internal-1',
      }),
      { status: 'IN_PROCESS' }
    );

    await flushAsync();

    expect(emitToUsers).toHaveBeenCalledWith(
      ['user-1', 'user-2'],
      'diagnostic.lab_workflow_updated',
      expect.objectContaining({
        action: 'REVERSE',
        order_id: 'LAB0000001',
      })
    );
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'tenant-internal-1',
        action: 'REVERSE',
        entity: 'lab_order',
      })
    );
  });

  it('rejects reverseLabOrderWorkflow when no reversible workflow step exists', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderById.mockResolvedValue(
      buildBaseOrder({
        status: 'ORDERED',
        samples: [
          {
            id: 'sample-internal-1',
            human_friendly_id: 'LSP0000001',
            status: 'PENDING',
            collected_at: null,
            received_at: null,
            created_at: now,
            updated_at: now,
          },
        ],
        items: [
          {
            id: 'order-item-internal-1',
            human_friendly_id: 'LIT0000001',
            status: 'ORDERED',
            created_at: now,
            updated_at: now,
            lab_test: {
              id: 'lab-test-internal-1',
              human_friendly_id: 'LBT0000001',
              name: 'CBC',
              code: 'CBC',
              unit: null,
            },
            results: [],
          },
        ],
      })
    );

    await expect(
      labWorkspaceService.reverseLabOrderWorkflow(
        'LAB0000001',
        { reason: 'Wrong status' },
        'actor-1',
        '127.0.0.1'
      )
    ).rejects.toBeInstanceOf(HttpError);
  });

  it('throws not found when legacy resource identifier is missing', async () => {
    await expect(
      labWorkspaceService.resolveLegacyRouteIdentifier('lab-results', '')
    ).rejects.toBeInstanceOf(HttpError);
  });
});
