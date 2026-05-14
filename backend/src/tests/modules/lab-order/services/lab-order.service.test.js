const { HttpError } = require('@lib/errors');

jest.mock('@repositories/lab-order/lab-order.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn(),
}));
jest.mock('@services/lab-workspace/lab.shared', () => {
  const actual = jest.requireActual('@services/lab-workspace/lab.shared');
  return {
    ...actual,
    resolveModelIdOrThrow: jest.fn(),
    resolveModelRecordOrThrow: jest.fn(),
  };
});

const labOrderRepository = require('@repositories/lab-order/lab-order.repository');
const { createAuditLog } = require('@lib/audit');
const {
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
} = require('@services/lab-workspace/lab.shared');
const labOrderService = require('@services/lab-order/lab-order.service');

const mockUserId = 'user-123';
const mockIpAddress = '127.0.0.1';
const now = new Date('2026-02-27T09:15:00.000Z');

const buildOrderRecord = (overrides = {}) => ({
  id: 'order-internal-1',
  human_friendly_id: 'LAB0000001',
  patient_id: 'patient-internal-1',
  encounter_id: 'encounter-internal-1',
  status: 'ORDERED',
  ordered_at: now,
  created_at: now,
  updated_at: now,
  patient: {
    id: 'patient-internal-1',
    human_friendly_id: 'PAT0000001',
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

describe('lab-order.service', () => {
  beforeEach(() => {
    jest.resetAllMocks();
    createAuditLog.mockResolvedValue(undefined);
  });

  it('lists lab orders with resolved filters and friendly identifiers', async () => {
    resolveModelIdOrThrow
      .mockResolvedValueOnce('encounter-internal-1')
      .mockResolvedValueOnce('patient-internal-1');
    labOrderRepository.findMany.mockResolvedValue([buildOrderRecord()]);
    labOrderRepository.count.mockResolvedValue(1);

    const result = await labOrderService.listLabOrders(
      {
        encounter_id: 'ENC0000001',
        patient_id: 'PAT0000001',
        search: 'Amina',
      },
      1,
      20,
      'ordered_at',
      'desc',
      mockUserId,
      mockIpAddress
    );

    expect(resolveModelIdOrThrow).toHaveBeenNthCalledWith(1, {
      identifier: 'ENC0000001',
      model: 'encounter',
      where: { deleted_at: null },
      errorKey: 'errors.encounter.not_found',
    });
    expect(resolveModelIdOrThrow).toHaveBeenNthCalledWith(2, {
      identifier: 'PAT0000001',
      model: 'patient',
      where: { deleted_at: null },
      errorKey: 'errors.patient.not_found',
    });
    expect(labOrderRepository.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        encounter_id: 'encounter-internal-1',
        patient_id: 'patient-internal-1',
        OR: expect.arrayContaining([
          { patient: { first_name: { contains: 'Amina' } } },
          { patient: { human_friendly_id: { contains: 'AMINA' } } },
        ]),
      }),
      0,
      20,
      { ordered_at: 'desc' },
      expect.any(Object)
    );
    expect(result.labOrders).toEqual([
      expect.objectContaining({
        id: 'LAB0000001',
        display_id: 'LAB0000001',
        patient_id: 'PAT0000001',
        patient_display_name: 'Amina Stone',
        encounter_id: 'ENC0000001',
      }),
    ]);
    expect(result.pagination).toMatchObject({
      page: 1,
      limit: 20,
      total: 1,
      totalPages: 1,
    });
  });

  it('gets a lab order by friendly identifier through shared resolution', async () => {
    resolveModelRecordOrThrow.mockResolvedValue(buildOrderRecord());

    const result = await labOrderService.getLabOrderById(
      'LAB0000001',
      mockUserId,
      mockIpAddress
    );

    expect(resolveModelRecordOrThrow).toHaveBeenCalledWith({
      identifier: 'LAB0000001',
      model: 'lab_order',
      where: { deleted_at: null },
      include: expect.any(Object),
      errorKey: 'errors.lab_order.not_found',
    });
    expect(result).toEqual(
      expect.objectContaining({
        id: 'LAB0000001',
        patient_id: 'PAT0000001',
        encounter_id: 'ENC0000001',
      })
    );
  });

  it('creates a lab order with resolved identifiers and audit logging', async () => {
    resolveModelRecordOrThrow.mockResolvedValueOnce({
      id: 'patient-internal-1',
      tenant_id: 'tenant-1',
    });
    resolveModelIdOrThrow.mockResolvedValueOnce('encounter-internal-1');
    labOrderRepository.create.mockResolvedValue({ id: 'order-internal-1' });
    labOrderRepository.findById.mockResolvedValue(buildOrderRecord());

    const result = await labOrderService.createLabOrder(
      {
        patient_id: 'PAT0000001',
        encounter_id: 'ENC0000001',
        ordered_at: now.toISOString(),
        status: 'ORDERED',
      },
      mockUserId,
      mockIpAddress
    );

    expect(labOrderRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        patient_id: 'patient-internal-1',
        encounter_id: 'encounter-internal-1',
        ordered_at: expect.any(Date),
        status: 'ORDERED',
      })
    );
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        user_id: mockUserId,
        action: 'CREATE',
        entity: 'lab_order',
        entity_id: 'order-internal-1',
        ip_address: mockIpAddress,
      })
    );
    expect(result).toEqual(
      expect.objectContaining({
        id: 'LAB0000001',
        patient_id: 'PAT0000001',
      })
    );
  });

  it('creates nested order items from configured tests and panels without duplicates', async () => {
    resolveModelRecordOrThrow
      .mockResolvedValueOnce({
        id: 'patient-internal-1',
        tenant_id: 'tenant-1',
      })
      .mockResolvedValueOnce({ id: 'lab-test-1' })
      .mockResolvedValueOnce({
        id: 'lab-panel-1',
        panel_items: [
          { lab_test_id: 'lab-test-1' },
          { lab_test_id: 'lab-test-2' },
        ],
      });
    labOrderRepository.create.mockResolvedValue({ id: 'order-internal-1' });
    labOrderRepository.findById.mockResolvedValue(
      buildOrderRecord({
        items: [
          { id: 'item-1', lab_test_id: 'lab-test-1', status: 'ORDERED' },
          { id: 'item-2', lab_test_id: 'lab-test-2', status: 'ORDERED' },
        ],
      })
    );

    await labOrderService.createLabOrder(
      {
        patient_id: 'PAT0000001',
        requested_tests: [{ lab_test_id: 'LBT0000001' }],
        requested_panels: [{ lab_panel_id: 'LPN0000001' }],
      },
      mockUserId,
      mockIpAddress
    );

    expect(labOrderRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        patient_id: 'patient-internal-1',
        encounter_id: null,
        status: 'ORDERED',
        items: {
          create: [
            { lab_test_id: 'lab-test-1', status: 'ORDERED' },
            { lab_test_id: 'lab-test-2', status: 'ORDERED' },
          ],
        },
      })
    );
  });

  it('swallows audit failures after a successful create', async () => {
    resolveModelRecordOrThrow.mockResolvedValueOnce({
      id: 'patient-internal-1',
      tenant_id: 'tenant-1',
    });
    labOrderRepository.create.mockResolvedValue({ id: 'order-internal-1' });
    labOrderRepository.findById.mockResolvedValue(buildOrderRecord({ encounter: null, encounter_id: null }));
    createAuditLog.mockImplementation(() => Promise.reject(new Error('audit failed')));

    await expect(
      labOrderService.createLabOrder(
        {
          patient_id: 'PAT0000001',
          status: 'ORDERED',
        },
        mockUserId,
        mockIpAddress
      )
    ).resolves.toEqual(
      expect.objectContaining({
        id: 'LAB0000001',
      })
    );
  });

  it('updates and deletes lab orders through resolved records', async () => {
    const before = buildOrderRecord();
    const after = buildOrderRecord({ status: 'COMPLETED' });
    resolveModelRecordOrThrow.mockResolvedValue(before);
    labOrderRepository.update.mockResolvedValue({ id: 'order-internal-1' });
    labOrderRepository.findById.mockResolvedValue(after);
    labOrderRepository.softDelete.mockResolvedValue({ id: 'order-internal-1' });

    const updated = await labOrderService.updateLabOrder(
      'LAB0000001',
      { status: 'COMPLETED' },
      mockUserId,
      mockIpAddress
    );
    const removed = await labOrderService.deleteLabOrder(
      'LAB0000001',
      mockUserId,
      mockIpAddress
    );

    expect(labOrderRepository.update).toHaveBeenCalledWith('order-internal-1', {
      status: 'COMPLETED',
    });
    expect(labOrderRepository.softDelete).toHaveBeenCalledWith('order-internal-1');
    expect(updated).toEqual(
      expect.objectContaining({
        id: 'LAB0000001',
        status: 'COMPLETED',
      })
    );
    expect(removed).toEqual(
      expect.objectContaining({
        id: 'LAB0000001',
        status: 'ORDERED',
      })
    );
  });

  it('rethrows HttpError instances without wrapping them', async () => {
    const error = new HttpError('errors.patient.not_found', 404);
    resolveModelRecordOrThrow.mockRejectedValue(error);

    await expect(
      labOrderService.createLabOrder(
        { patient_id: 'missing-patient' },
        mockUserId,
        mockIpAddress
      )
    ).rejects.toBe(error);
  });
});
