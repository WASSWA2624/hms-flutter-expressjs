jest.mock('@repositories/reports-workspace/reports-workspace.repository');
jest.mock('@repositories/report-run/report-run.repository');
jest.mock('@repositories/report-schedule/report-schedule.repository');
jest.mock('@repositories/report-definition/report-definition.repository');
jest.mock('@lib/billing/clinical-request-billing', () => ({
  upsertClinicalRequestBilling: jest.fn(),
  receiveClinicalRequestPayment: jest.fn(),
  adjustClinicalRequestBilling: jest.fn(),
}));
jest.mock('@lib/billing/financials', () => ({
  recalculateInvoiceBalances: jest.fn(),
}));
jest.mock('@services/dashboard-widget/dashboard-widget.service', () => ({
  getDashboardSummary: jest.fn(),
}));
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue(undefined),
}));
jest.mock('@lib/storage', () => ({
  createStorageService: jest.fn(),
}));
jest.mock('@lib/reports/runtime', () => ({
  cancelQueuedRun: jest.fn(),
  enqueueReportRun: jest.fn(),
  getNextScheduledTime: jest.fn(() => new Date('2026-03-09T08:00:00.000Z')),
}));
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelIdByIdentifier: jest.fn(async ({ identifier }) => identifier),
}));

const reportsWorkspaceRepository = require('@repositories/reports-workspace/reports-workspace.repository');
const reportRunRepository = require('@repositories/report-run/report-run.repository');
const reportDefinitionRepository = require('@repositories/report-definition/report-definition.repository');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const financials = require('@lib/billing/financials');
const dashboardWidgetService = require('@services/dashboard-widget/dashboard-widget.service');
const { createStorageService } = require('@lib/storage');
const { cancelQueuedRun, enqueueReportRun } = require('@lib/reports/runtime');
const reportsWorkspaceService = require('@services/reports-workspace/reports-workspace.service');
const {
  cancelReportRunById,
  createReportRun,
  downloadReportRun,
  retryReportRun,
} = require('@services/report-run/report-run.service');
const reportDefinitionService = require('@services/report-definition/report-definition.service');
const { createReportSchedule } = require('@services/report-schedule/report-schedule.service');
const reportScheduleRepository = require('@repositories/report-schedule/report-schedule.repository');

const buildRunRecord = (overrides = {}) => ({
  id: 'report-run-123',
  human_friendly_id: 'RR-001',
  tenant_id: 'tenant-123',
  facility_id: 'facility-123',
  report_definition_id: 'report-definition-123',
  requested_by_user_id: 'user-123',
  schedule_id: null,
  trigger_type: 'MANUAL',
  format: 'PDF',
  status: 'QUEUED',
  parameters_json: {},
  output_storage_path: null,
  output_file_name: null,
  output_mime_type: null,
  output_size_bytes: null,
  error_message: null,
  queued_at: new Date('2026-03-08T08:00:00.000Z'),
  created_at: new Date('2026-03-08T08:00:00.000Z'),
  updated_at: new Date('2026-03-08T08:00:00.000Z'),
  version: 1,
  report_definition: {
    id: 'report-definition-123',
    human_friendly_id: 'RD-001',
    name: 'Admissions Daily',
    default_format: 'PDF',
    dataset_key: 'patient_registrations',
  },
  requested_by: {
    id: 'user-123',
    human_friendly_id: 'USR-001',
    email: 'owner@example.com',
    profile: { first_name: 'Owner' },
  },
  facility: { id: 'facility-123', human_friendly_id: 'FAC-001', name: 'Main Facility' },
  ...overrides,
});

const buildDefinitionRecord = (overrides = {}) => ({
  id: 'report-definition-123',
  human_friendly_id: 'RD-001',
  tenant_id: 'tenant-123',
  facility_id: 'facility-123',
  name: 'Admissions Daily',
  default_format: 'PDF',
  dataset_key: 'patient_registrations',
  status: 'ACTIVE',
  version: 1,
  created_at: new Date('2026-03-08T08:00:00.000Z'),
  updated_at: new Date('2026-03-08T08:00:00.000Z'),
  ...overrides,
});

describe('reports workspace billing sections scan', () => {
  const scopedUser = {
    id: 'user-123',
    tenant_id: 'tenant-123',
    facility_id: 'facility-123',
    permissions: ['reports:read', 'reports:write', 'evidence:export'],
  };

  const mutationContext = {
    user: scopedUser,
    user_id: 'user-123',
    ip_address: '127.0.0.1',
    user_agent: 'Jest',
  };

  beforeEach(() => {
    jest.clearAllMocks();
    reportsWorkspaceRepository.findSummary.mockResolvedValue({
      total_definitions: 1,
      queued_runs: 1,
      due_schedules: 0,
      pinned_widgets: 0,
      critical_kpis: 0,
      warning_kpis: 0,
      recent_activity: 1,
      failed_runs: 0,
      total_schedules: 0,
      stale_widgets: 0,
    });
    reportsWorkspaceRepository.findLookups.mockResolvedValue({
      facilities: [{ id: 'facility-123', human_friendly_id: 'FAC-001', name: 'Main Facility' }],
      branches: [],
      users: [],
    });
    reportsWorkspaceRepository.findItems.mockResolvedValue({
      items: [buildRunRecord()],
      total: 1,
    });
    reportsWorkspaceRepository.findTimeline.mockResolvedValue({
      runs: [buildRunRecord()],
      schedules: [],
      kpis: [],
      events: [],
    });
    dashboardWidgetService.getDashboardSummary.mockResolvedValue({
      roleProfile: { id: 'tenant_admin' },
    });
  });

  it('workspace read does not touch patient billing ledger', async () => {
    const data = await reportsWorkspaceService.getWorkspace({}, 1, 20, undefined, 'desc', scopedUser);

    expect(data.items).toHaveLength(1);
    expect(data.items[0].id).toBe('RR-001');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('workspace GET is idempotent on replay', async () => {
    const query = { panel: 'overview' };
    const first = await reportsWorkspaceService.getWorkspace(query, 1, 20, undefined, 'desc', scopedUser);
    const second = await reportsWorkspaceService.getWorkspace(query, 1, 20, undefined, 'desc', scopedUser);

    expect(first.items).toEqual(second.items);
    expect(reportsWorkspaceRepository.findItems).toHaveBeenCalledTimes(2);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('serializes workspace items without local paid flags or balances', async () => {
    const data = await reportsWorkspaceService.getWorkspace({}, 1, 20, undefined, 'desc', scopedUser);
    const item = data.items[0];

    expect(item).not.toHaveProperty('payment_status');
    expect(item).not.toHaveProperty('balance');
    expect(item).not.toHaveProperty('amount_due');
    expect(item).not.toHaveProperty('paid');
  });

  it('run-now mutation enqueues report run without billing post', async () => {
    reportDefinitionRepository.findById.mockResolvedValue(buildDefinitionRecord());
    enqueueReportRun.mockResolvedValue(buildRunRecord());

    const result = await reportDefinitionService.runReportDefinitionNow(
      'report-definition-123',
      { format: 'PDF' },
      mutationContext
    );

    expect(result.id).toBe('RR-001');
    expect(enqueueReportRun).toHaveBeenCalled();
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });

  it('retry run does not post to billing ledger', async () => {
    reportRunRepository.findById.mockResolvedValue(buildRunRecord({ status: 'FAILED' }));
    enqueueReportRun.mockResolvedValue(buildRunRecord({ status: 'QUEUED' }));

    const result = await retryReportRun('report-run-123', { format: 'PDF' }, mutationContext);

    expect(result.status).toBe('QUEUED');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('cancel run does not post to billing ledger', async () => {
    reportRunRepository.findById
      .mockResolvedValueOnce(buildRunRecord({ status: 'QUEUED' }))
      .mockResolvedValueOnce(buildRunRecord({ status: 'CANCELLED' }));
    cancelQueuedRun.mockResolvedValue(true);

    const result = await cancelReportRunById('report-run-123', mutationContext);

    expect(result.status).toBe('CANCELLED');
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('download run exports evidence without collecting payment', async () => {
    reportRunRepository.findById.mockResolvedValue(
      buildRunRecord({
        status: 'COMPLETED',
        output_storage_path: '/reports/output.pdf',
        output_file_name: 'output.pdf',
        output_mime_type: 'application/pdf',
        output_size_bytes: 128,
      })
    );
    createStorageService.mockReturnValue({
      download: jest.fn().mockResolvedValue(Buffer.from('pdf')),
    });

    const result = await downloadReportRun('report-run-123', mutationContext);

    expect(result.file_name).toBe('output.pdf');
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });

  it('create report run record path does not bypass billing for patient charges', async () => {
    enqueueReportRun.mockResolvedValue(buildRunRecord());

    await createReportRun(
      { report_definition_id: 'report-definition-123', format: 'PDF' },
      mutationContext
    );

    expect(enqueueReportRun).toHaveBeenCalled();
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('scoped run lookup rejects cross-tenant access without billing fallback', async () => {
    reportRunRepository.findById.mockResolvedValue(
      buildRunRecord({ tenant_id: 'other-tenant' })
    );

    await expect(
      downloadReportRun('report-run-123', mutationContext)
    ).rejects.toMatchObject({ statusCode: 404 });

    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });

  it('create schedule does not post to patient billing ledger', async () => {
    reportScheduleRepository.create.mockResolvedValue({
      id: 'report-schedule-123',
      human_friendly_id: 'RS-001',
      tenant_id: 'tenant-123',
      facility_id: 'facility-123',
      report_definition_id: 'report-definition-123',
      name: 'Daily census email',
      status: 'ACTIVE',
      frequency: 'DAILY',
      time_of_day: '08:00',
      timezone: 'UTC',
      format: 'PDF',
      retention_days: 30,
      next_run_at: new Date('2026-03-09T08:00:00.000Z'),
      created_at: new Date('2026-03-08T08:00:00.000Z'),
      updated_at: new Date('2026-03-08T08:00:00.000Z'),
      version: 1,
    });

    const result = await createReportSchedule(
      {
        report_definition_id: 'report-definition-123',
        name: 'Daily census email',
        frequency: 'DAILY',
        format: 'PDF',
      },
      mutationContext
    );

    expect(result.id).toBe('RS-001');
    expect(reportScheduleRepository.create).toHaveBeenCalled();
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });

  it('run-now replay does not duplicate billing posts', async () => {
    reportDefinitionRepository.findById.mockResolvedValue(buildDefinitionRecord());
    enqueueReportRun.mockResolvedValue(buildRunRecord());

    const payload = { format: 'PDF' };
    await reportDefinitionService.runReportDefinitionNow(
      'report-definition-123',
      payload,
      mutationContext
    );
    await reportDefinitionService.runReportDefinitionNow(
      'report-definition-123',
      payload,
      mutationContext
    );

    expect(enqueueReportRun).toHaveBeenCalledTimes(2);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });
});
