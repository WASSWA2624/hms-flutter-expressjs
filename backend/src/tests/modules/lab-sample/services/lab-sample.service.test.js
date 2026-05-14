const { HttpError } = require('@lib/errors');

jest.mock('@repositories/lab-sample/lab-sample.repository');
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

const labSampleRepository = require('@repositories/lab-sample/lab-sample.repository');
const { createAuditLog } = require('@lib/audit');
const {
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
} = require('@services/lab-workspace/lab.shared');
const labSampleService = require('@services/lab-sample/lab-sample.service');

const mockUserId = 'user-123';
const mockIpAddress = '127.0.0.1';
const now = new Date('2026-02-27T09:15:00.000Z');

const buildLabSampleRecord = (overrides = {}) => ({
  id: 'sample-internal-1',
  human_friendly_id: 'LSP0000001',
  lab_order_id: 'order-internal-1',
  status: 'PENDING',
  collected_at: now,
  received_at: null,
  created_at: now,
  updated_at: now,
  lab_order: {
    id: 'order-internal-1',
    human_friendly_id: 'LAB0000001',
    patient_id: 'patient-internal-1',
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
  },
  ...overrides,
});

describe('lab-sample.service', () => {
  beforeEach(() => {
    jest.resetAllMocks();
    createAuditLog.mockResolvedValue(undefined);
  });

  it('lists lab samples with resolved order filters and friendly identifiers', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');
    labSampleRepository.findMany.mockResolvedValue([buildLabSampleRecord()]);
    labSampleRepository.count.mockResolvedValue(1);

    const result = await labSampleService.listLabSamples(
      {
        lab_order_id: 'LAB0000001',
        status: 'PENDING',
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
      identifier: 'LAB0000001',
      model: 'lab_order',
      where: { deleted_at: null },
      errorKey: 'errors.lab_order.not_found',
    });
    expect(labSampleRepository.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        lab_order_id: 'order-internal-1',
        status: 'PENDING',
        OR: expect.arrayContaining([
          { human_friendly_id: { contains: 'AMINA' } },
          { lab_order: { patient: { first_name: { contains: 'amina' } } } },
          { lab_order: { patient: { last_name: { contains: 'amina' } } } },
        ]),
      }),
      0,
      20,
      { created_at: 'desc' },
      expect.any(Object)
    );
    expect(result.labSamples).toEqual([
      expect.objectContaining({
        id: 'LSP0000001',
        display_id: 'LSP0000001',
        lab_order_id: 'LAB0000001',
        patient_id: 'PAT0000001',
        patient_display_name: 'Amina Stone',
      }),
    ]);
    expect(result.pagination).toMatchObject({
      page: 1,
      limit: 20,
      total: 1,
      totalPages: 1,
    });
  });

  it('gets a lab sample by friendly identifier through shared resolution', async () => {
    resolveModelRecordOrThrow.mockResolvedValue(buildLabSampleRecord());

    const result = await labSampleService.getLabSampleById(
      'LSP0000001',
      mockUserId,
      mockIpAddress
    );

    expect(resolveModelRecordOrThrow).toHaveBeenCalledWith({
      identifier: 'LSP0000001',
      model: 'lab_sample',
      where: { deleted_at: null },
      include: expect.any(Object),
      errorKey: 'errors.lab_sample.not_found',
    });
    expect(result).toEqual(
      expect.objectContaining({
        id: 'LSP0000001',
        lab_order_id: 'LAB0000001',
        patient_id: 'PAT0000001',
      })
    );
  });

  it('creates lab samples with resolved identifiers and normalized dates', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');
    labSampleRepository.create.mockResolvedValue({ id: 'sample-internal-1' });
    labSampleRepository.findById.mockResolvedValue(buildLabSampleRecord());

    const result = await labSampleService.createLabSample(
      {
        lab_order_id: 'LAB0000001',
        status: 'COLLECTED',
        collected_at: now.toISOString(),
        received_at: null,
      },
      mockUserId,
      mockIpAddress
    );

    expect(labSampleRepository.create).toHaveBeenCalledWith({
      lab_order_id: 'order-internal-1',
      status: 'COLLECTED',
      collected_at: expect.any(Date),
      received_at: null,
    });
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        user_id: mockUserId,
        action: 'CREATE',
        entity: 'lab_sample',
        entity_id: 'sample-internal-1',
        ip_address: mockIpAddress,
      })
    );
    expect(result).toEqual(
      expect.objectContaining({
        id: 'LSP0000001',
        status: 'PENDING',
      })
    );
  });

  it('swallows audit failures after a successful update', async () => {
    const before = buildLabSampleRecord({
      status: 'PENDING',
      collected_at: null,
    });
    const after = buildLabSampleRecord({
      status: 'COLLECTED',
      collected_at: now,
    });

    resolveModelRecordOrThrow.mockResolvedValue(before);
    labSampleRepository.update.mockResolvedValue({ id: 'sample-internal-1' });
    labSampleRepository.findById.mockResolvedValue(after);
    createAuditLog.mockImplementation(() => Promise.reject(new Error('audit failed')));

    await expect(
      labSampleService.updateLabSample(
        'LSP0000001',
        {
          status: 'COLLECTED',
          collected_at: now.toISOString(),
        },
        mockUserId,
        mockIpAddress
      )
    ).resolves.toEqual(
      expect.objectContaining({
        id: 'LSP0000001',
        status: 'COLLECTED',
      })
    );

    expect(labSampleRepository.update).toHaveBeenCalledWith('sample-internal-1', {
      status: 'COLLECTED',
      collected_at: expect.any(Date),
    });
  });

  it('deletes lab samples using the resolved internal identifier', async () => {
    resolveModelRecordOrThrow.mockResolvedValue(buildLabSampleRecord());
    labSampleRepository.softDelete.mockResolvedValue({ id: 'sample-internal-1' });

    await expect(
      labSampleService.deleteLabSample(
        'LSP0000001',
        mockUserId,
        mockIpAddress
      )
    ).resolves.toBeUndefined();

    expect(labSampleRepository.softDelete).toHaveBeenCalledWith('sample-internal-1');
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'DELETE',
        entity: 'lab_sample',
        entity_id: 'sample-internal-1',
      })
    );
  });

  it('rethrows HttpError instances without wrapping them', async () => {
    const error = new HttpError('errors.lab_order.not_found', 404);
    resolveModelIdOrThrow.mockRejectedValue(error);

    await expect(
      labSampleService.createLabSample(
        { lab_order_id: 'missing-order' },
        mockUserId,
        mockIpAddress
      )
    ).rejects.toBe(error);
  });
});
