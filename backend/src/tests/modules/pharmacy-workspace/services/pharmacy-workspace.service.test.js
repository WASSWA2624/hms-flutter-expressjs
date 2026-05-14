const { HttpError } = require('@lib/errors');

jest.mock('@repositories/pharmacy-workspace/pharmacy-workspace.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn(),
}));
jest.mock('@lib/websocket', () => ({
  emitToUsers: jest.fn(),
  PHARMACY_EVENTS: {
    PHARMACY_WORKSPACE_UPDATED: 'pharmacy.workspace_updated',
    PHARMACY_ORDER_UPDATED: 'pharmacy.order_updated',
  },
  INVENTORY_EVENTS: {
    INVENTORY_STOCK_UPDATED: 'inventory.stock_updated',
  },
}));
jest.mock('@prisma/client', () => ({
  user_role: {
    findMany: jest.fn(),
  },
  inventory_stock: {
    fields: {
      reorder_level: 'reorder_level',
    },
  },
}));
jest.mock('@services/pharmacy-workspace/pharmacy.shared', () => {
  const actual = jest.requireActual('@services/pharmacy-workspace/pharmacy.shared');
  return {
    ...actual,
    resolveModelIdOrThrow: jest.fn(),
    resolveModelRecordOrThrow: jest.fn(),
  };
});

const pharmacyWorkspaceRepository = require('@repositories/pharmacy-workspace/pharmacy-workspace.repository');
const { createAuditLog } = require('@lib/audit');
const { emitToUsers } = require('@lib/websocket');
const prisma = require('@prisma/client');
const {
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
} = require('@services/pharmacy-workspace/pharmacy.shared');
const pharmacyWorkspaceService = require('@services/pharmacy-workspace/pharmacy-workspace.service');

const now = new Date('2026-02-27T10:20:00.000Z');
const mockUser = {
  id: 'actor-1',
  tenant_id: 'tenant-internal-1',
  facility_id: 'facility-internal-1',
  roles: ['PHARMACIST'],
};

const buildOrder = (overrides = {}) => ({
  id: 'order-internal-1',
  human_friendly_id: 'PHO0000001',
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
  items: [
    {
      id: 'item-internal-1',
      human_friendly_id: 'POI0000001',
      pharmacy_order_id: 'order-internal-1',
      drug_id: 'drug-internal-1',
      quantity: 10,
      status: 'ACTIVE',
      dosage: '1 tab',
      frequency: 'ONCE',
      route: 'ORAL',
      created_at: now,
      updated_at: now,
      dispense_logs: [],
      drug: {
        id: 'drug-internal-1',
        human_friendly_id: 'DRG0000001',
        name: 'Paracetamol',
        code: 'PCM',
        inventory_maps: [
          {
            id: 'map-1',
            human_friendly_id: 'DIM0000001',
            drug_id: 'drug-internal-1',
            inventory_item_id: 'inventory-item-internal-1',
            is_default: true,
            deduction_factor: 1,
            inventory_item: {
              id: 'inventory-item-internal-1',
              human_friendly_id: 'INV0000001',
              tenant_id: 'tenant-internal-1',
              name: 'Paracetamol 500mg',
              category: 'MEDICATION',
              sku: 'PCM',
              unit: 'tablet',
            },
          },
        ],
      },
    },
  ],
  dispense_attestations: [],
  ...overrides,
});

const flushAsync = () => new Promise((resolve) => setImmediate(resolve));

describe('pharmacy-workspace.service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    prisma.user_role.findMany.mockResolvedValue([
      { user_id: 'user-1' },
      { user_id: 'actor-1' },
      { user_id: 'user-2' },
    ]);
  });

  it('resolves legacy pharmacy identifiers to workspace route', async () => {
    resolveModelRecordOrThrow.mockResolvedValue({
      id: '6b6ee0e3-f57e-4d2a-81d6-c7b87a235cdf',
      human_friendly_id: 'PHO0000009',
    });

    const resolved = await pharmacyWorkspaceService.resolveLegacyRouteIdentifier(
      'pharmacy-orders',
      '6b6ee0e3-f57e-4d2a-81d6-c7b87a235cdf',
      mockUser
    );

    expect(resolved).toEqual({
      id: 'PHO0000009',
      resource: 'orders',
      identifier: 'PHO0000009',
      route: '/pharmacy/orders/PHO0000009',
      matched_by: 'uuid',
    });
  });

  it('prepareDispense creates pending dispense logs and emits realtime updates', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');

    const orderBefore = buildOrder();
    const orderAfter = buildOrder({
      dispense_attestations: [
        {
          id: 'att-prep-1',
          human_friendly_id: 'PDA000001',
          pharmacy_order_id: 'order-internal-1',
          dispense_batch_ref: 'DSPBATCH001',
          phase: 'PREPARE',
          attested_by_user_id: 'actor-1',
          attested_role: 'PHARMACIST',
          attested_at: now,
          created_at: now,
          updated_at: now,
        },
      ],
      items: [
        {
          ...orderBefore.items[0],
          dispense_logs: [
            {
              id: 'dlog-1',
              human_friendly_id: 'DLOG0001',
              pharmacy_order_item_id: 'item-internal-1',
              dispense_batch_ref: 'DSPBATCH001',
              status: 'PENDING',
              quantity_dispensed: 2,
              created_at: now,
              updated_at: now,
            },
          ],
        },
      ],
    });

    pharmacyWorkspaceRepository.withTransaction.mockImplementation(async (callback) => callback({}));
    pharmacyWorkspaceRepository.txFindOrderById
      .mockResolvedValueOnce(orderBefore)
      .mockResolvedValueOnce(orderAfter);
    pharmacyWorkspaceRepository.txFindDispenseAttestation
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce(null);
    pharmacyWorkspaceRepository.txCreateDispenseLog.mockResolvedValue({ id: 'dlog-1' });
    pharmacyWorkspaceRepository.txCreateDispenseAttestation.mockResolvedValue({ id: 'att-prep-1' });

    const result = await pharmacyWorkspaceService.prepareDispense(
      'PHO0000001',
      {
        dispense_batch_ref: 'DSPBATCH001',
        items: [{ order_item_id: 'POI0000001', quantity: 2 }],
      },
      'actor-1',
      'PHARMACIST',
      '127.0.0.1',
      mockUser
    );

    expect(result.dispense_batch_ref).toBe('DSPBATCH001');
    expect(pharmacyWorkspaceRepository.txCreateDispenseLog).toHaveBeenCalledTimes(1);

    await flushAsync();

    expect(emitToUsers).toHaveBeenCalledWith(
      ['user-1', 'user-2'],
      'pharmacy.workspace_updated',
      expect.objectContaining({
        action: 'PREPARE_DISPENSE',
      })
    );
  });

  it('prepareDispense rejects a new batch while another batch is pending attestation', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');

    const orderWithPendingBatch = buildOrder({
      dispense_attestations: [
        {
          id: 'att-prep-open-1',
          human_friendly_id: 'PDA000099',
          pharmacy_order_id: 'order-internal-1',
          dispense_batch_ref: 'DSPBATCH001',
          phase: 'PREPARE',
          attested_by_user_id: 'actor-1',
          attested_role: 'PHARMACIST',
          attested_at: now,
          created_at: now,
          updated_at: now,
        },
      ],
    });

    pharmacyWorkspaceRepository.withTransaction.mockImplementation(async (callback) => callback({}));
    pharmacyWorkspaceRepository.txFindOrderById.mockResolvedValue(orderWithPendingBatch);
    pharmacyWorkspaceRepository.txFindDispenseAttestation
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce(null);

    await expect(
      pharmacyWorkspaceService.prepareDispense(
        'PHO0000001',
        {
          dispense_batch_ref: 'DSPBATCH002',
          items: [{ order_item_id: 'POI0000001', quantity: 2 }],
        },
        'actor-2',
        'PHARMACIST',
        '127.0.0.1',
        {
          ...mockUser,
          id: 'actor-2',
        }
      )
    ).rejects.toBeInstanceOf(HttpError);

    expect(pharmacyWorkspaceRepository.txCreateDispenseLog).not.toHaveBeenCalled();
    expect(pharmacyWorkspaceRepository.txCreateDispenseAttestation).not.toHaveBeenCalled();
  });

  it('attestDispense rejects same-user second attestation', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');
    pharmacyWorkspaceRepository.withTransaction.mockImplementation(async (callback) => callback({}));
    pharmacyWorkspaceRepository.txFindOrderById.mockResolvedValue(buildOrder());
    pharmacyWorkspaceRepository.txFindDispenseAttestation
      .mockResolvedValueOnce({
        id: 'att-prep-1',
        phase: 'PREPARE',
        attested_by_user_id: 'actor-1',
      })
      .mockResolvedValueOnce(null);

    await expect(
      pharmacyWorkspaceService.attestDispense(
        'PHO0000001',
        { dispense_batch_ref: 'DSPBATCH001' },
        'actor-1',
        'PHARMACIST',
        '127.0.0.1',
        mockUser
      )
    ).rejects.toBeInstanceOf(HttpError);
  });
});
