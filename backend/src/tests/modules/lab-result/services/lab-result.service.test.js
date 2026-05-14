const { HttpError } = require('@lib/errors');

jest.mock('@repositories/lab-result/lab-result.repository');
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

const labResultRepository = require('@repositories/lab-result/lab-result.repository');
const { createAuditLog } = require('@lib/audit');
const {
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
} = require('@services/lab-workspace/lab.shared');
const labResultService = require('@services/lab-result/lab-result.service');

const mockUserId = 'user-123';
const mockIpAddress = '127.0.0.1';
const now = new Date('2026-02-27T09:15:00.000Z');

const buildLabResultRecord = (overrides = {}) => ({
  id: 'result-internal-1',
  human_friendly_id: 'LRS0000001',
  lab_order_item_id: 'order-item-internal-1',
  status: 'PENDING',
  result_value: null,
  result_unit: 'g/dL',
  result_text: null,
  result_flag: null,
  is_positive: false,
  reference_range_label: null,
  reference_range_summary: null,
  reported_at: now,
  created_at: now,
  updated_at: now,
  lab_order_item: {
    id: 'order-item-internal-1',
    human_friendly_id: 'LIT0000001',
    lab_order_id: 'order-internal-1',
    lab_test_id: 'lab-test-internal-1',
    lab_test: {
      id: 'lab-test-internal-1',
      human_friendly_id: 'LBT0000001',
      name: 'CBC',
      code: 'CBC',
      unit: 'g/dL',
      reference_ranges: [],
      unit_options: [],
      result_options: [],
    },
    lab_order: {
      id: 'order-internal-1',
      human_friendly_id: 'LAB0000001',
      patient_id: 'patient-internal-1',
      patient: {
        id: 'patient-internal-1',
        human_friendly_id: 'PAT0000001',
        first_name: 'Amina',
        last_name: 'Stone',
        gender: 'FEMALE',
        date_of_birth: new Date('1994-06-01T00:00:00.000Z'),
      },
      encounter: {
        id: 'encounter-internal-1',
        human_friendly_id: 'ENC0000001',
      },
    },
  },
  ...overrides,
});

describe('lab-result.service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue(undefined);
  });

  it('lists lab results with resolved filters and friendly identifiers', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-item-internal-1');
    labResultRepository.findMany.mockResolvedValue([buildLabResultRecord()]);
    labResultRepository.count.mockResolvedValue(1);

    const result = await labResultService.listLabResults(
      {
        lab_order_item_id: 'LIT0000001',
        search: 'amina',
      },
      1,
      20,
      'created_at',
      'desc',
      mockUserId,
      mockIpAddress
    );

    expect(resolveModelIdOrThrow).toHaveBeenCalledWith({
      identifier: 'LIT0000001',
      model: 'lab_order_item',
      where: { deleted_at: null },
      errorKey: 'errors.lab_order_item.not_found',
    });
    expect(labResultRepository.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        lab_order_item_id: 'order-item-internal-1',
        OR: expect.arrayContaining([
          {
            lab_order_item: {
              lab_order: {
                patient: { first_name: { contains: 'amina' } },
              },
            },
          },
        ]),
      }),
      0,
      20,
      { created_at: 'desc' },
      expect.any(Object)
    );
    expect(result.labResults).toEqual([
      expect.objectContaining({
        id: 'LRS0000001',
        lab_order_item_id: 'LIT0000001',
        lab_order_id: 'LAB0000001',
        lab_test_id: 'LBT0000001',
      patient_id: 'PAT0000001',
      patient_display_name: 'Amina Stone',
      test_display_name: 'CBC',
      result_unit: 'g/dL',
      result_flag: null,
    }),
  ]);
  });

  it('gets a lab result by friendly identifier through shared resolution', async () => {
    resolveModelRecordOrThrow.mockResolvedValue(buildLabResultRecord());

    const result = await labResultService.getLabResultById(
      'LRS0000001',
      mockUserId,
      mockIpAddress
    );

    expect(resolveModelRecordOrThrow).toHaveBeenCalledWith({
      identifier: 'LRS0000001',
      model: 'lab_result',
      where: { deleted_at: null },
      include: expect.any(Object),
      errorKey: 'errors.lab_result.not_found',
    });
    expect(result).toEqual(
      expect.objectContaining({
        id: 'LRS0000001',
        patient_id: 'PAT0000001',
      })
    );
  });

  it('creates lab results with default status and lab-test unit fallback', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-item-internal-1');
    resolveModelRecordOrThrow.mockResolvedValue({
      id: 'order-item-internal-1',
      lab_test: {
        unit: 'g/dL',
        reference_ranges: [],
        unit_options: [],
        result_options: [],
      },
      lab_order: {
        patient: {
          gender: 'FEMALE',
          date_of_birth: new Date('1994-06-01T00:00:00.000Z'),
        },
      },
    });
    labResultRepository.create.mockResolvedValue({ id: 'result-internal-1' });
    labResultRepository.findById.mockResolvedValue(buildLabResultRecord());

    const result = await labResultService.createLabResult(
      {
        lab_order_item_id: 'LIT0000001',
        reported_at: now.toISOString(),
      },
      mockUserId,
      mockIpAddress
    );

    expect(labResultRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        lab_order_item_id: 'order-item-internal-1',
        status: 'PENDING',
        result_unit: 'g/dL',
        reported_at: expect.any(Date),
      })
    );
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entity: 'lab_result',
        entity_id: 'result-internal-1',
      })
    );
    expect(result).toEqual(
      expect.objectContaining({
        id: 'LRS0000001',
        result_unit: 'g/dL',
      })
    );
  });

  it('updates and releases lab results through resolved records', async () => {
    const before = buildLabResultRecord();
    const interpretationContext = {
      id: 'order-item-internal-1',
      lab_test: {
        unit: 'g/dL',
        reference_ranges: [],
        unit_options: [],
        result_options: [],
      },
      lab_order: {
        patient: {
          gender: 'FEMALE',
          date_of_birth: new Date('1994-06-01T00:00:00.000Z'),
        },
      },
    };
    const afterUpdate = buildLabResultRecord({
      status: 'PENDING',
      result_text: 'Updated notes',
    });
    const afterRelease = buildLabResultRecord({
      status: 'CRITICAL',
      result_value: '12.8',
      result_text: 'Critical potassium level',
    });

    resolveModelRecordOrThrow
      .mockResolvedValueOnce(before)
      .mockResolvedValueOnce(interpretationContext)
      .mockResolvedValueOnce(before)
      .mockResolvedValueOnce(interpretationContext);
    resolveModelIdOrThrow.mockResolvedValue('order-item-internal-1');
    labResultRepository.update
      .mockResolvedValueOnce({ id: 'result-internal-1' })
      .mockResolvedValueOnce({ id: 'result-internal-1' });
    labResultRepository.findById
      .mockResolvedValueOnce(afterUpdate)
      .mockResolvedValueOnce(afterRelease);

    const updated = await labResultService.updateLabResult(
      'LRS0000001',
      {
        lab_order_item_id: 'LIT0000001',
        result_text: 'Updated notes',
      },
      mockUserId,
      mockIpAddress
    );
    const released = await labResultService.releaseLabResult(
      'LRS0000001',
      {
        status: 'CRITICAL',
        result_value: '12.8',
        result_text: 'Critical potassium level',
      },
      mockUserId,
      mockIpAddress
    );

    expect(labResultRepository.update).toHaveBeenNthCalledWith(1, 'result-internal-1', {
      lab_order_item_id: 'order-item-internal-1',
      result_value: null,
      result_unit: 'g/dL',
      result_text: 'Updated notes',
      status: 'PENDING',
      result_flag: null,
      is_positive: false,
      reference_range_label: null,
      reference_range_summary: null,
    });
    expect(labResultRepository.update).toHaveBeenNthCalledWith(
      2,
      'result-internal-1',
      expect.objectContaining({
        status: 'CRITICAL',
        result_value: '12.8',
        result_unit: 'g/dL',
        result_text: 'Critical potassium level',
        result_flag: null,
        is_positive: false,
        reference_range_label: null,
        reference_range_summary: null,
        reported_at: expect.any(Date),
      })
    );
    expect(updated).toEqual(expect.objectContaining({ result_text: 'Updated notes' }));
    expect(released).toEqual(
      expect.objectContaining({
        id: 'LRS0000001',
        status: 'CRITICAL',
        result_value: '12.8',
      })
    );
  });

  it('soft deletes lab results and rethrows HttpError instances', async () => {
    resolveModelRecordOrThrow.mockResolvedValue(buildLabResultRecord());
    labResultRepository.softDelete.mockResolvedValue({ id: 'result-internal-1' });

    await expect(
      labResultService.deleteLabResult(
        'LRS0000001',
        mockUserId,
        mockIpAddress
      )
    ).resolves.toBeUndefined();
    expect(labResultRepository.softDelete).toHaveBeenCalledWith('result-internal-1');

    const error = new HttpError('errors.lab_order_item.not_found', 404);
    resolveModelIdOrThrow.mockRejectedValue(error);

    await expect(
      labResultService.createLabResult(
        { lab_order_item_id: 'missing-item' },
        mockUserId,
        mockIpAddress
      )
    ).rejects.toBe(error);
  });
});
