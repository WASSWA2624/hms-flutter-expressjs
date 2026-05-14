jest.mock('@repositories/report-run/report-run.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue(undefined),
}));
jest.mock('@lib/storage', () => ({
  createStorageService: jest.fn(),
}));
jest.mock('@lib/reports/runtime', () => ({
  cancelQueuedRun: jest.fn(),
  enqueueReportRun: jest.fn(),
}));
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelIdByIdentifier: jest.fn(async ({ identifier }) => identifier),
}));

const reportRunRepository = require('@repositories/report-run/report-run.repository');
const { createAuditLog } = require('@lib/audit');
const { createStorageService } = require('@lib/storage');
const { cancelQueuedRun, enqueueReportRun } = require('@lib/reports/runtime');
const {
  cancelReportRunById,
  createReportRun,
  downloadReportRun,
  getReportRunById,
  listReportRuns,
  retryReportRun,
  updateReportRun,
} = require('@services/report-run/report-run.service');

const buildRunRecord = (overrides = {}) => ({
  id: 'report-run-123',
  human_friendly_id: 'RR-001',
  tenant_id: 'tenant-123',
  facility_id: 'facility-123',
  report_definition_id: 'report-definition-123',
  requested_by_user_id: 'user-123',
  schedule_id: 'report-schedule-123',
  trigger_type: 'MANUAL',
  format: 'PDF',
  status: 'QUEUED',
  parameters_json: { limit: 10 },
  output_file_name: null,
  output_mime_type: null,
  output_size_bytes: null,
  output_storage_path: null,
  error_message: null,
  queued_at: new Date('2026-01-20T09:00:00.000Z'),
  started_at: null,
  completed_at: null,
  expires_at: null,
  created_at: new Date('2026-01-20T09:00:00.000Z'),
  updated_at: new Date('2026-01-20T09:00:00.000Z'),
  version: 1,
  facility: { id: 'facility-123', human_friendly_id: 'FAC-001', name: 'Main Facility' },
  report_definition: {
    id: 'report-definition-123',
    human_friendly_id: 'RD-001',
    name: 'Admissions Daily',
    default_format: 'PDF',
    dataset_key: 'patient_registrations',
    facility_id: 'facility-123',
  },
  requested_by: {
    id: 'user-123',
    human_friendly_id: 'USR-001',
    email: 'owner@example.com',
    profile: { first_name: 'Owner' },
  },
  schedule: {
    id: 'report-schedule-123',
    human_friendly_id: 'RS-001',
    name: 'Morning',
    retention_days: 45,
    status: 'ACTIVE',
  },
  ...overrides,
});

describe('Report Run Service', () => {
  const scopedUser = {
    id: 'user-123',
    tenant_id: 'tenant-123',
    facility_id: 'facility-123',
  };

  const mutationContext = {
    user: scopedUser,
    user_id: 'user-123',
    ip_address: '127.0.0.1',
    user_agent: 'Jest',
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('lists scoped runs using the object query contract', async () => {
    reportRunRepository.findMany.mockResolvedValue([buildRunRecord()]);
    reportRunRepository.count.mockResolvedValue(1);

    const result = await listReportRuns(
      { status: 'failed', format: 'pdf' },
      1,
      20,
      undefined,
      undefined,
      { tenant_id: 'tenant-123', facility_id: 'facility-123' }
    );

    expect(reportRunRepository.findMany).toHaveBeenCalledWith({
      where: expect.objectContaining({
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        status: 'FAILED',
        format: 'PDF',
      }),
      skip: 0,
      take: 20,
      orderBy: { queued_at: 'desc' },
    });
    expect(result.reportRuns[0]).toMatchObject({
      id: 'RR-001',
      display_id: 'RR-001',
      report_definition_label: 'Admissions Daily',
      facility_id: 'FAC-001',
    });
  });

  it('loads a single run within scope', async () => {
    reportRunRepository.findById.mockResolvedValue(buildRunRecord());

    const result = await getReportRunById('report-run-123', {
      tenant_id: 'tenant-123',
      facility_id: 'facility-123',
    });

    expect(reportRunRepository.findById).toHaveBeenCalledWith('report-run-123');
    expect(result).toMatchObject({
      id: 'RR-001',
      status: 'QUEUED',
      report_definition_id: 'RD-001',
    });
  });

  it('queues a manual run and returns the serialized record', async () => {
    enqueueReportRun.mockResolvedValue(
      buildRunRecord({
        id: 'report-run-999',
        human_friendly_id: 'RR-999',
        format: 'CSV',
        status: 'QUEUED',
      })
    );

    const result = await createReportRun(
      {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        report_definition_id: 'report-definition-123',
        format: 'csv',
        parameters_json: { limit: 25 },
      },
      mutationContext
    );

    expect(enqueueReportRun).toHaveBeenCalledWith(
      expect.objectContaining({
        report_definition_id: 'report-definition-123',
        facility_id: 'facility-123',
        requested_by_user_id: 'user-123',
        trigger_type: 'MANUAL',
        format: 'CSV',
        parameters_json: { limit: 25 },
      })
    );
    expect(result).toMatchObject({
      id: 'RR-999',
      format: 'CSV',
      status: 'QUEUED',
    });
  });

  it('updates a run with optimistic locking, version bumping, and audit logging', async () => {
    reportRunRepository.findById.mockResolvedValue(buildRunRecord());
    reportRunRepository.update.mockResolvedValue(
      buildRunRecord({
        status: 'FAILED',
        error_message: 'Timed out',
        version: 2,
        completed_at: new Date('2026-01-20T09:10:00.000Z'),
      })
    );

    const result = await updateReportRun(
      'report-run-123',
      {
        status: 'failed',
        error_message: 'Timed out',
        completed_at: '2026-01-20T09:10:00.000Z',
        version: 1,
      },
      mutationContext
    );

    expect(reportRunRepository.update).toHaveBeenCalledWith(
      'report-run-123',
      expect.objectContaining({
        status: 'FAILED',
        error_message: 'Timed out',
        completed_at: expect.any(Date),
        version: 2,
      })
    );
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'UPDATE',
        entity: 'report_run',
      })
    );
    expect(result).toMatchObject({
      id: 'RR-001',
      status: 'FAILED',
      version: 2,
    });
  });

  it('retries a failed run using the runtime queue', async () => {
    reportRunRepository.findById.mockResolvedValue(
      buildRunRecord({
        status: 'FAILED',
        format: 'JSON',
      })
    );
    enqueueReportRun.mockResolvedValue(
      buildRunRecord({
        id: 'report-run-777',
        human_friendly_id: 'RR-777',
        trigger_type: 'RETRY',
        status: 'QUEUED',
      })
    );

    const result = await retryReportRun('report-run-123', {}, mutationContext);

    expect(enqueueReportRun).toHaveBeenCalledWith(
      expect.objectContaining({
        report_definition_id: 'report-definition-123',
        facility_id: 'facility-123',
        requested_by_user_id: 'user-123',
        trigger_type: 'RETRY',
        format: 'JSON',
        retention_days: 45,
      })
    );
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entity: 'report_run',
      })
    );
    expect(result).toMatchObject({
      id: 'RR-777',
      trigger_type: 'RETRY',
    });
  });

  it('cancels a queued run and returns the refreshed state', async () => {
    reportRunRepository.findById
      .mockResolvedValueOnce(buildRunRecord())
      .mockResolvedValueOnce(
        buildRunRecord({
          status: 'CANCELLED',
          completed_at: new Date('2026-01-20T09:05:00.000Z'),
        })
      );
    cancelQueuedRun.mockResolvedValue(true);

    const result = await cancelReportRunById('report-run-123', mutationContext);

    expect(cancelQueuedRun).toHaveBeenCalledWith('report-run-123');
    expect(reportRunRepository.findById).toHaveBeenCalledTimes(2);
    expect(result).toMatchObject({
      id: 'RR-001',
      status: 'CANCELLED',
    });
  });

  it('downloads completed output from storage and returns the file contract', async () => {
    const storage = {
      download: jest.fn().mockResolvedValue(Buffer.from('report-bytes')),
    };
    createStorageService.mockReturnValue(storage);
    reportRunRepository.findById.mockResolvedValue(
      buildRunRecord({
        status: 'COMPLETED',
        output_storage_path: 'reports/tenant-123/2026/01/report.pdf',
        output_file_name: 'report.pdf',
        output_mime_type: 'application/pdf',
      })
    );

    const result = await downloadReportRun('report-run-123', mutationContext);

    expect(storage.download).toHaveBeenCalledWith('reports/tenant-123/2026/01/report.pdf');
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'EXPORT',
        entity: 'report_run',
      })
    );
    expect(result).toEqual({
      buffer: Buffer.from('report-bytes'),
      file_name: 'report.pdf',
      mime_type: 'application/pdf',
    });
  });
});
