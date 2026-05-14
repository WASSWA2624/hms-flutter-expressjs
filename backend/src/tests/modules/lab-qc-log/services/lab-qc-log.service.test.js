const { HttpError } = require('@lib/errors');

jest.mock('@repositories/lab-qc-log/lab-qc-log.repository');
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

const labQcLogRepository = require('@repositories/lab-qc-log/lab-qc-log.repository');
const { createAuditLog } = require('@lib/audit');
const {
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
} = require('@services/lab-workspace/lab.shared');
const labQcLogService = require('@services/lab-qc-log/lab-qc-log.service');

const mockUserId = 'user-123';
const mockIpAddress = '127.0.0.1';
const now = new Date('2026-02-27T09:15:00.000Z');

const buildQcLogRecord = (overrides = {}) => ({
  id: 'qc-internal-1',
  human_friendly_id: 'LQC0000001',
  lab_test_id: 'lab-test-internal-1',
  status: 'PASSED',
  notes: 'Control within acceptable range',
  logged_at: now,
  created_at: now,
  updated_at: now,
  lab_test: {
    id: 'lab-test-internal-1',
    human_friendly_id: 'LBT0000001',
    name: 'CBC',
    code: 'CBC',
  },
  ...overrides,
});

describe('lab-qc-log.service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue(undefined);
  });

  it('lists QC logs with resolved test filters and friendly identifiers', async () => {
    resolveModelIdOrThrow.mockResolvedValue('lab-test-internal-1');
    labQcLogRepository.findMany.mockResolvedValue([buildQcLogRecord()]);
    labQcLogRepository.count.mockResolvedValue(1);

    const result = await labQcLogService.listLabQcLogs(
      {
        lab_test_id: 'LBT0000001',
        search: 'cbc',
      },
      1,
      20,
      'created_at',
      'desc',
      mockUserId,
      mockIpAddress
    );

    expect(resolveModelIdOrThrow).toHaveBeenCalledWith({
      identifier: 'LBT0000001',
      model: 'lab_test',
      where: { deleted_at: null },
      errorKey: 'errors.lab_test.not_found',
    });
    expect(labQcLogRepository.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        lab_test_id: 'lab-test-internal-1',
        OR: expect.arrayContaining([
          { status: { contains: 'cbc' } },
          { lab_test: { code: { contains: 'cbc' } } },
        ]),
      }),
      0,
      20,
      { created_at: 'desc' },
      expect.any(Object)
    );
    expect(result.labQcLogs).toEqual([
      expect.objectContaining({
        id: 'LQC0000001',
        display_id: 'LQC0000001',
        lab_test_id: 'LBT0000001',
        test_display_name: 'CBC',
        test_code: 'CBC',
      }),
    ]);
  });

  it('gets and creates QC logs using shared identifier resolution', async () => {
    resolveModelRecordOrThrow.mockResolvedValue(buildQcLogRecord());
    resolveModelIdOrThrow.mockResolvedValue('lab-test-internal-1');
    labQcLogRepository.create.mockResolvedValue({ id: 'qc-internal-1' });
    labQcLogRepository.findById.mockResolvedValue(buildQcLogRecord());

    const existing = await labQcLogService.getLabQcLogById(
      'LQC0000001',
      mockUserId,
      mockIpAddress
    );
    const created = await labQcLogService.createLabQcLog(
      {
        lab_test_id: 'LBT0000001',
        status: 'FAILED',
        notes: 'Out of range',
        logged_at: now.toISOString(),
      },
      mockUserId,
      mockIpAddress
    );

    expect(existing).toEqual(expect.objectContaining({ id: 'LQC0000001' }));
    expect(labQcLogRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        lab_test_id: 'lab-test-internal-1',
        status: 'FAILED',
        logged_at: expect.any(Date),
      })
    );
    expect(created).toEqual(expect.objectContaining({ id: 'LQC0000001' }));
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entity: 'lab_qc_log',
      })
    );
  });

  it('updates and deletes QC logs through resolved records', async () => {
    const before = buildQcLogRecord();
    const after = buildQcLogRecord({
      status: 'FAILED',
      notes: 'Out of range',
    });
    resolveModelRecordOrThrow.mockResolvedValue(before);
    resolveModelIdOrThrow.mockResolvedValue('lab-test-internal-1');
    labQcLogRepository.update.mockResolvedValue({ id: 'qc-internal-1' });
    labQcLogRepository.findById.mockResolvedValue(after);
    labQcLogRepository.softDelete.mockResolvedValue({ id: 'qc-internal-1' });

    const updated = await labQcLogService.updateLabQcLog(
      'LQC0000001',
      {
        lab_test_id: 'LBT0000001',
        status: 'FAILED',
        notes: 'Out of range',
      },
      mockUserId,
      mockIpAddress
    );

    await expect(
      labQcLogService.deleteLabQcLog(
        'LQC0000001',
        mockUserId,
        mockIpAddress
      )
    ).resolves.toBeUndefined();

    expect(labQcLogRepository.update).toHaveBeenCalledWith('qc-internal-1', {
      lab_test_id: 'lab-test-internal-1',
      status: 'FAILED',
      notes: 'Out of range',
    });
    expect(labQcLogRepository.softDelete).toHaveBeenCalledWith('qc-internal-1');
    expect(updated).toEqual(
      expect.objectContaining({
        id: 'LQC0000001',
        status: 'FAILED',
      })
    );
  });

  it('rethrows HttpError instances without wrapping them', async () => {
    const error = new HttpError('errors.lab_test.not_found', 404);
    resolveModelIdOrThrow.mockRejectedValue(error);

    await expect(
      labQcLogService.createLabQcLog(
        { lab_test_id: 'missing-test', status: 'FAILED' },
        mockUserId,
        mockIpAddress
      )
    ).rejects.toBe(error);
  });
});
