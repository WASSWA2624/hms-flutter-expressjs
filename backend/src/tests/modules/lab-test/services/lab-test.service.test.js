const { HttpError } = require('@lib/errors');

jest.mock('@repositories/lab-test/lab-test.repository');
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

const labTestRepository = require('@repositories/lab-test/lab-test.repository');
const { createAuditLog } = require('@lib/audit');
const {
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
} = require('@services/lab-workspace/lab.shared');
const labTestService = require('@services/lab-test/lab-test.service');

const mockUserId = 'user-123';
const mockIpAddress = '127.0.0.1';
const now = new Date('2026-02-27T09:15:00.000Z');

const buildLabTestRecord = (overrides = {}) => ({
  id: 'lab-test-internal-1',
  human_friendly_id: 'LBT0000001',
  tenant_id: 'tenant-internal-1',
  name: 'Complete Blood Count',
  code: 'CBC',
  category: 'Hematology',
  specimen_type: 'Whole blood',
  result_kind: 'QUALITATIVE',
  unit: 'g/dL',
  description: 'Configured demo test',
  reference_range: '13 - 18',
  unit_options: [
    {
      id: 'unit-option-internal-1',
      label: 'Default',
      unit: 'g/dL',
      ucum_code: 'g/dL',
      is_default: true,
      sort_order: 0,
    },
  ],
  reference_ranges: [
    {
      id: 'range-internal-1',
      label: 'Adult',
      unit: 'g/dL',
      gender: 'MALE',
      age_min_value: 18,
      age_min_unit: 'YEAR',
      normal_min_value: '13.0000',
      normal_max_value: '18.0000',
      reference_text: null,
      notes: null,
      sort_order: 0,
    },
  ],
  result_options: [
    {
      id: 'result-option-internal-1',
      value: 'POSITIVE',
      label: 'Positive',
      aliases_json: ['Reactive'],
      status: 'ABNORMAL',
      result_flag: 'POSITIVE',
      is_positive: true,
      sort_order: 0,
    },
  ],
  created_at: now,
  updated_at: now,
  tenant: {
    id: 'tenant-internal-1',
    human_friendly_id: 'TEN0000001',
  },
  ...overrides,
});

describe('lab-test.service', () => {
  beforeEach(() => {
    jest.resetAllMocks();
    createAuditLog.mockResolvedValue(undefined);
  });

  it('lists lab tests with resolved tenant filters and friendly identifiers', async () => {
    resolveModelIdOrThrow.mockResolvedValue('tenant-internal-1');
    labTestRepository.findMany.mockResolvedValue([buildLabTestRecord()]);
    labTestRepository.count.mockResolvedValue(1);

    const result = await labTestService.listLabTests(
      {
        tenant_id: 'TEN0000001',
        name: 'Blood',
        code: 'CBC',
        search: 'blood',
      },
      1,
      20,
      'name',
      'asc',
      mockUserId,
      mockIpAddress
    );

    expect(resolveModelIdOrThrow).toHaveBeenCalledWith({
      identifier: 'TEN0000001',
      model: 'tenant',
      where: { deleted_at: null },
      errorKey: 'errors.tenant.not_found',
    });
    expect(labTestRepository.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'tenant-internal-1',
        name: { contains: 'Blood' },
        code: { contains: 'CBC' },
        OR: expect.arrayContaining([
          { name: { contains: 'blood' } },
          { human_friendly_id: { contains: 'BLOOD' } },
          { tenant: { human_friendly_id: { contains: 'BLOOD' } } },
        ]),
      }),
      0,
      20,
      { name: 'asc' },
      expect.any(Object)
    );
    expect(result.labTests).toEqual([
      expect.objectContaining({
        id: 'LBT0000001',
        display_id: 'LBT0000001',
        tenant_id: 'TEN0000001',
        name: 'Complete Blood Count',
        code: 'CBC',
        category: 'Hematology',
        specimen_type: 'Whole blood',
        result_kind: 'QUALITATIVE',
        unit: 'g/dL',
        description: 'Configured demo test',
        reference_range: '13 - 18',
        unit_options: [
          expect.objectContaining({
            unit: 'g/dL',
            is_default: true,
          }),
        ],
        reference_ranges: [
          expect.objectContaining({
            label: 'Adult',
            unit: 'g/dL',
            gender: 'MALE',
          }),
        ],
        result_options: [
          expect.objectContaining({
            value: 'POSITIVE',
            result_flag: 'POSITIVE',
            is_positive: true,
          }),
        ],
      }),
    ]);
    expect(result.pagination).toMatchObject({
      page: 1,
      limit: 20,
      total: 1,
      totalPages: 1,
    });
  });

  it('gets a lab test by friendly identifier through shared resolution', async () => {
    resolveModelRecordOrThrow.mockResolvedValue(buildLabTestRecord());

    const result = await labTestService.getLabTestById(
      'LBT0000001',
      mockUserId,
      mockIpAddress
    );

    expect(resolveModelRecordOrThrow).toHaveBeenCalledWith({
      identifier: 'LBT0000001',
      model: 'lab_test',
      where: { deleted_at: null },
      include: expect.any(Object),
      errorKey: 'errors.lab_test.not_found',
    });
    expect(result).toEqual(
      expect.objectContaining({
        id: 'LBT0000001',
        tenant_id: 'TEN0000001',
      })
    );
  });

  it('creates and updates lab tests with resolved tenant identifiers', async () => {
    const createdRecord = buildLabTestRecord();
    const updatedRecord = buildLabTestRecord({
      name: 'Updated CBC',
      code: 'UCBC',
    });

    resolveModelIdOrThrow.mockResolvedValue('tenant-internal-1');
    resolveModelRecordOrThrow.mockResolvedValue(createdRecord);
    labTestRepository.create.mockResolvedValue({ id: 'lab-test-internal-1' });
    labTestRepository.update.mockResolvedValue({ id: 'lab-test-internal-1' });
    labTestRepository.findById
      .mockResolvedValueOnce(createdRecord)
      .mockResolvedValueOnce(updatedRecord);

    const created = await labTestService.createLabTest(
      {
        tenant_id: 'TEN0000001',
        name: 'Complete Blood Count',
        code: 'CBC',
        category: 'Hematology',
        specimen_type: 'Whole blood',
        result_kind: 'QUALITATIVE',
        unit: 'g/dL',
        description: 'Configured demo test',
        unit_options: [
          {
            label: 'Default',
            unit: 'g/dL',
            ucum_code: 'g/dL',
            is_default: true,
          },
        ],
        reference_range: '13 - 18',
        reference_ranges: [
          {
            label: 'Adult',
            unit: 'g/dL',
            gender: 'MALE',
            age_min_value: '18',
            age_min_unit: 'YEAR',
            normal_min_value: '13',
            normal_max_value: '18',
          },
        ],
        result_options: [
          {
            value: 'POSITIVE',
            label: 'Positive',
            aliases: ['Reactive'],
            status: 'ABNORMAL',
            result_flag: 'POSITIVE',
            is_positive: true,
          },
        ],
      },
      mockUserId,
      mockIpAddress
    );

    const updated = await labTestService.updateLabTest(
      'LBT0000001',
      {
        tenant_id: 'TEN0000001',
        name: 'Updated CBC',
        code: 'UCBC',
        category: 'Hematology',
        specimen_type: 'Whole blood',
        result_kind: 'NUMERIC',
        reference_range: 'Women 12 - 16',
        unit_options: [
          {
            label: 'Default',
            unit: 'g/dL',
            is_default: true,
          },
        ],
        reference_ranges: [
          {
            label: 'Women',
            unit: 'g/dL',
            gender: 'FEMALE',
            age_min_value: '18',
            age_min_unit: 'YEAR',
            normal_min_value: '12',
            normal_max_value: '16',
          },
        ],
        result_options: [
          {
            value: 'NEGATIVE',
            label: 'Negative',
            status: 'NORMAL',
            result_flag: 'NEGATIVE',
            is_positive: false,
          },
        ],
      },
      mockUserId,
      mockIpAddress
    );

    expect(labTestRepository.create).toHaveBeenCalledWith({
      tenant_id: 'tenant-internal-1',
      name: 'Complete Blood Count',
      code: 'CBC',
      category: 'Hematology',
      specimen_type: 'Whole blood',
      result_kind: 'QUALITATIVE',
      unit: 'g/dL',
      description: 'Configured demo test',
      unit_options: {
        create: [
          {
            label: 'Default',
            unit: 'g/dL',
            ucum_code: 'g/dL',
            is_default: true,
            sort_order: 0,
          },
        ],
      },
      reference_range: '13 - 18',
      reference_ranges: {
        create: [
          {
            label: 'Adult',
            unit: 'g/dL',
            gender: 'MALE',
            age_min_value: 18,
            age_min_unit: 'YEAR',
            age_max_value: null,
            age_max_unit: null,
            normal_min_value: '13.0000',
            normal_max_value: '18.0000',
            critical_min_value: null,
            critical_max_value: null,
            reference_text: null,
            notes: null,
            sort_order: 0,
          },
        ],
      },
      result_options: {
        create: [
          {
            value: 'POSITIVE',
            label: 'Positive',
            aliases_json: ['Reactive'],
            status: 'ABNORMAL',
            result_flag: 'POSITIVE',
            is_positive: true,
            sort_order: 0,
          },
        ],
      },
    });
    expect(labTestRepository.update).toHaveBeenCalledWith('lab-test-internal-1', {
      tenant_id: 'tenant-internal-1',
      name: 'Updated CBC',
      code: 'UCBC',
      category: 'Hematology',
      specimen_type: 'Whole blood',
      result_kind: 'NUMERIC',
      reference_range: 'Women 12 - 16',
      unit: 'g/dL',
      unit_options: {
        deleteMany: {},
        create: [
          {
            label: 'Default',
            unit: 'g/dL',
            ucum_code: null,
            is_default: true,
            sort_order: 0,
          },
        ],
      },
      reference_ranges: {
        deleteMany: {},
        create: [
          {
            label: 'Women',
            unit: 'g/dL',
            gender: 'FEMALE',
            age_min_value: 18,
            age_min_unit: 'YEAR',
            age_max_value: null,
            age_max_unit: null,
            normal_min_value: '12.0000',
            normal_max_value: '16.0000',
            critical_min_value: null,
            critical_max_value: null,
            reference_text: null,
            notes: null,
            sort_order: 0,
          },
        ],
      },
      result_options: {
        deleteMany: {},
        create: [
          {
            value: 'NEGATIVE',
            label: 'Negative',
            aliases_json: [],
            status: 'NORMAL',
            result_flag: 'NEGATIVE',
            is_positive: false,
            sort_order: 0,
          },
        ],
      },
    });
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        user_id: mockUserId,
        action: 'CREATE',
        entity: 'lab_test',
        entity_id: 'lab-test-internal-1',
        ip_address: mockIpAddress,
      })
    );
    expect(created).toEqual(expect.objectContaining({ id: 'LBT0000001' }));
    expect(updated).toEqual(
      expect.objectContaining({
        id: 'LBT0000001',
        name: 'Updated CBC',
        code: 'UCBC',
      })
    );
  });

  it('deletes lab tests using the resolved internal identifier', async () => {
    resolveModelRecordOrThrow.mockResolvedValue(buildLabTestRecord());
    labTestRepository.softDelete.mockResolvedValue({ id: 'lab-test-internal-1' });

    const result = await labTestService.deleteLabTest(
      'LBT0000001',
      mockUserId,
      mockIpAddress
    );

    expect(labTestRepository.softDelete).toHaveBeenCalledWith('lab-test-internal-1');
    expect(result).toEqual(
      expect.objectContaining({
        id: 'LBT0000001',
        name: 'Complete Blood Count',
      })
    );
  });

  it('rethrows HttpError instances without wrapping them', async () => {
    const error = new HttpError('errors.tenant.not_found', 404);
    resolveModelIdOrThrow.mockRejectedValue(error);

    await expect(
      labTestService.createLabTest(
        { tenant_id: 'missing-tenant', name: 'CBC', code: 'CBC' },
        mockUserId,
        mockIpAddress
      )
    ).rejects.toBe(error);
  });
});
