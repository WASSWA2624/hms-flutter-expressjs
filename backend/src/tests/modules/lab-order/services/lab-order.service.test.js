const { HttpError } = require('@lib/errors');

jest.mock('@repositories/lab-order/lab-order.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn(),
}));
jest.mock('@lib/billing/clinical-request-billing', () => {
  const actual = jest.requireActual('@lib/billing/clinical-request-billing');
  return {
    ...actual,
    buildLabOrderBillingFromRequest: jest.fn().mockResolvedValue(null),
    normalizeBillingOfficeClinicalBilling: jest.fn().mockReturnValue(null),
    persistLabOrderBilling: jest.fn().mockResolvedValue(null),
  };
});
jest.mock('@services/lab-workspace/lab.shared', () => {
  const actual = jest.requireActual('@services/lab-workspace/lab.shared');
  return {
    ...actual,
    resolveModelIdOrThrow: jest.fn(),
    resolveModelRecordOrThrow: jest.fn(),
    resolveLabOrderEncounterId: jest.fn(),
  };
});

const labOrderRepository = require('@repositories/lab-order/lab-order.repository');
const { createAuditLog } = require('@lib/audit');
const {
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
  resolveLabOrderEncounterId,
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
    resolveModelRecordOrThrow
      .mockResolvedValueOnce({
        id: 'patient-internal-1',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
      })
      .mockResolvedValueOnce({ id: 'lab-test-1' });
    resolveLabOrderEncounterId.mockResolvedValueOnce('encounter-internal-1');
    labOrderRepository.create.mockResolvedValue({ id: 'order-internal-1' });
    labOrderRepository.findById.mockResolvedValue(buildOrderRecord());
    const manualOrderedAt = '2026-01-19T12:00:00.000Z';

    const result = await labOrderService.createLabOrder(
      {
        patient_id: 'PAT0000001',
        encounter_id: 'ENC0000001',
        ordered_at: manualOrderedAt,
        status: 'ORDERED',
        requested_tests: [{ lab_test_id: 'LBT0000001' }],
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
        items: {
          create: [
            expect.objectContaining({
              lab_test_id: 'lab-test-1',
              status: 'ORDERED',
              panel_id: null,
            }),
          ],
        },
      })
    );
    const createdPayload = labOrderRepository.create.mock.calls[0][0];
    expect(createdPayload.ordered_at.toISOString()).not.toBe(manualOrderedAt);
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

  it('creates a lab order when encounter_id is a visit queue public id', async () => {
    resolveModelRecordOrThrow
      .mockResolvedValueOnce({
        id: 'patient-internal-1',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
      })
      .mockResolvedValueOnce({ id: 'lab-test-1' });
    resolveLabOrderEncounterId.mockResolvedValueOnce('encounter-internal-1');
    labOrderRepository.create.mockResolvedValue({ id: 'order-internal-1' });
    labOrderRepository.findById.mockResolvedValue(buildOrderRecord());

    await labOrderService.createLabOrder(
      {
        patient_id: 'PAT0000001',
        encounter_id: 'VIS0000001',
        requested_tests: [{ lab_test_id: 'LBT0000001' }],
      },
      mockUserId,
      mockIpAddress
    );

    expect(resolveLabOrderEncounterId).toHaveBeenCalledWith({
      identifier: 'VIS0000001',
      patientId: 'patient-internal-1',
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
    });
    expect(labOrderRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        encounter_id: 'encounter-internal-1',
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
        human_friendly_id: 'LPN0000001',
        name: 'Full blood count',
        code: 'FBC',
        panel_items: [
          { lab_test_id: 'lab-test-1', sort_order: 0 },
          { lab_test_id: 'lab-test-2', sort_order: 10 },
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
            expect.objectContaining({
              lab_test_id: 'lab-test-1',
              status: 'ORDERED',
              panel_id: null,
            }),
            expect.objectContaining({
              lab_test_id: 'lab-test-2',
              status: 'ORDERED',
              panel_id: 'LPN0000001',
              panel_display_name: 'Full blood count',
              panel_code: 'FBC',
              panel_sort_order: 0,
              panel_item_sort_order: 10,
            }),
          ],
        },
      })
    );
  });

  it('models the standard CBC offering as a multi-test panel', () => {
    expect(labOrderService.STANDARD_LAB_PANELS.CBC_PANEL).toEqual([
      'CBC_HGB',
      'CBC_HCT',
      'CBC_RBC',
      'CBC_WBC',
      'CBC_PLT',
      'CBC_MCV',
      'CBC_MCH',
      'CBC_MCHC',
      'CBC_RDW',
    ]);
    expect(labOrderService.STANDARD_LAB_PANELS.CBC_PANEL).not.toContain('CBC');
    expect(labOrderService.STANDARD_LAB_TESTS.CBC).toBeDefined();
  });

  it('rejects creating a lab order without resolved tests', async () => {
    resolveModelRecordOrThrow.mockResolvedValueOnce({
      id: 'patient-internal-1',
      tenant_id: 'tenant-1',
    });

    await expect(
      labOrderService.createLabOrder(
        {
          patient_id: 'PAT0000001',
          requested_tests: [],
          requested_panels: [],
        },
        mockUserId,
        mockIpAddress
      )
    ).rejects.toMatchObject({
      message: 'errors.lab_order.no_tests',
      statusCode: 400,
    });
    expect(labOrderRepository.create).not.toHaveBeenCalled();
  });

  it('rejects creating a lab order from an empty panel', async () => {
    resolveModelRecordOrThrow
      .mockResolvedValueOnce({
        id: 'patient-internal-1',
        tenant_id: 'tenant-1',
      })
      .mockResolvedValueOnce({
        id: 'lab-panel-1',
        panel_items: [],
      });

    await expect(
      labOrderService.createLabOrder(
        {
          patient_id: 'PAT0000001',
          requested_panels: [{ lab_panel_id: 'LPN0000001' }],
        },
        mockUserId,
        mockIpAddress
      )
    ).rejects.toMatchObject({
      message: 'errors.lab_order.empty_panel',
      statusCode: 400,
    });
    expect(labOrderRepository.create).not.toHaveBeenCalled();
  });

  it('rejects replacing lab order items with an empty resolved item list', async () => {
    resolveModelRecordOrThrow.mockResolvedValueOnce(
      buildOrderRecord({
        patient: {
          id: 'patient-internal-1',
          tenant_id: 'tenant-1',
        },
      })
    );

    await expect(
      labOrderService.updateLabOrder(
        'LAB0000001',
        {
          requested_tests: [],
          requested_panels: [],
        },
        mockUserId,
        mockIpAddress
      )
    ).rejects.toMatchObject({
      message: 'errors.lab_order.no_tests',
      statusCode: 400,
    });
    expect(labOrderRepository.update).not.toHaveBeenCalled();
  });

  it('swallows audit failures after a successful create', async () => {
    resolveModelRecordOrThrow
      .mockResolvedValueOnce({
        id: 'patient-internal-1',
        tenant_id: 'tenant-1',
      })
      .mockResolvedValueOnce({ id: 'lab-test-1' });
    labOrderRepository.create.mockResolvedValue({ id: 'order-internal-1' });
    labOrderRepository.findById.mockResolvedValue(
      buildOrderRecord({ encounter: null, encounter_id: null })
    );
    createAuditLog.mockImplementation(() => Promise.reject(new Error('audit failed')));

    await expect(
      labOrderService.createLabOrder(
        {
          patient_id: 'PAT0000001',
          status: 'ORDERED',
          requested_tests: [{ lab_test_id: 'LBT0000001' }],
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
      { reason: 'Duplicate order entered' },
      mockUserId,
      mockIpAddress
    );

    expect(labOrderRepository.update).toHaveBeenCalledWith('order-internal-1', {
      status: 'COMPLETED',
    });
    expect(labOrderRepository.softDelete).toHaveBeenCalledWith('order-internal-1');
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'DELETE',
        entity: 'lab_order',
        diff: expect.objectContaining({
          deletion_reason: 'Duplicate order entered',
        }),
      })
    );
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

  it('requires a deletion reason when deleting lab orders', async () => {
    await expect(
      labOrderService.deleteLabOrder(
        'LAB0000001',
        { reason: ' ' },
        mockUserId,
        mockIpAddress
      )
    ).rejects.toMatchObject({
      message: 'errors.validation.required',
      statusCode: 400,
    });
    expect(labOrderRepository.softDelete).not.toHaveBeenCalled();
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
