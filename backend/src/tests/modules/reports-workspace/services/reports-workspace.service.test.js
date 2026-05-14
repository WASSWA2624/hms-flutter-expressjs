jest.mock('@repositories/reports-workspace/reports-workspace.repository');
jest.mock('@services/dashboard-widget/dashboard-widget.service', () => ({
  getDashboardSummary: jest.fn(),
}));
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelIdByIdentifier: jest.fn(async ({ identifier }) => identifier),
}));

const reportsWorkspaceRepository = require('@repositories/reports-workspace/reports-workspace.repository');
const dashboardWidgetService = require('@services/dashboard-widget/dashboard-widget.service');
const {
  getLookups,
  getWorkspace,
} = require('@services/reports-workspace/reports-workspace.service');

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
  },
  requested_by: {
    id: 'user-123',
    human_friendly_id: 'USR-001',
    email: 'owner@example.com',
    profile: { first_name: 'Owner' },
  },
  facility: { id: 'facility-123', human_friendly_id: 'FAC-001', name: 'Main Facility' },
  schedule: {
    id: 'report-schedule-123',
    human_friendly_id: 'RS-001',
    name: 'Morning',
    retention_days: 30,
    status: 'ACTIVE',
  },
  ...overrides,
});

describe('Reports Workspace Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('builds the workspace payload with default panel/resource selection', async () => {
    reportsWorkspaceRepository.findSummary.mockResolvedValue({
      total_definitions: 3,
      queued_runs: 2,
      due_schedules: 1,
      pinned_widgets: 1,
      critical_kpis: 1,
      warning_kpis: 0,
      recent_activity: 4,
      failed_runs: 0,
      total_schedules: 1,
      stale_widgets: 0,
    });
    reportsWorkspaceRepository.findLookups.mockResolvedValue({
      facilities: [{ id: 'facility-123', human_friendly_id: 'FAC-001', name: 'Main Facility' }],
      branches: [{ id: 'branch-123', human_friendly_id: 'BR-001', name: 'North Wing', facility_id: 'facility-123' }],
      users: [{
        id: 'user-123',
        human_friendly_id: 'USR-001',
        email: 'owner@example.com',
        profile: { first_name: 'Owner', last_name: 'One' },
      }],
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

    const result = await getWorkspace({}, 1, 20, undefined, 'desc', {
      tenant_id: 'tenant-123',
      facility_id: 'facility-123',
    });

    expect(reportsWorkspaceRepository.findItems).toHaveBeenCalledWith(
      expect.objectContaining({
        resource: 'report-runs',
        where: expect.objectContaining({
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
        }),
      })
    );
    expect(result.filters).toMatchObject({
      panel: 'overview',
      resource: 'report-runs',
      facilityId: 'FAC-001',
    });
    expect(result.lookups.facilities[0]).toEqual({
      id: 'FAC-001',
      label: 'Main Facility',
    });
    expect(result.items[0]).toMatchObject({
      id: 'RR-001',
      report_definition_label: 'Admissions Daily',
    });
    expect(result.summary).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ id: 'definitions', value: 3 }),
        expect.objectContaining({ id: 'runs_queued', value: 2 }),
      ])
    );
  });

  it('maps lookup payloads for the workbench filter UI', async () => {
    reportsWorkspaceRepository.findLookups.mockResolvedValue({
      facilities: [{ id: 'facility-123', human_friendly_id: 'FAC-001', name: 'Main Facility' }],
      branches: [{ id: 'branch-123', human_friendly_id: 'BR-001', name: 'North Wing', facility_id: 'facility-123' }],
      users: [{
        id: 'user-123',
        human_friendly_id: 'USR-001',
        email: 'owner@example.com',
        profile: { first_name: 'Owner', last_name: 'One' },
      }],
    });

    const result = await getLookups({ facilityId: 'facility-123' }, {
      tenant_id: 'tenant-123',
    });

    expect(reportsWorkspaceRepository.findLookups).toHaveBeenCalledWith({
      tenant_id: 'tenant-123',
      facility_id: 'facility-123',
      branch_id: null,
      owner_id: null,
      report_definition_id: null,
      schedule_id: null,
      user_id: null,
      resource: null,
    });
    expect(result).toMatchObject({
      facilities: [{ id: 'FAC-001', label: 'Main Facility' }],
      branches: [{
        id: 'BR-001',
        label: 'North Wing',
        meta: { facility_id: 'FAC-001' },
      }],
      owners: [{ id: 'USR-001', label: 'Owner One' }],
    });
  });
});
