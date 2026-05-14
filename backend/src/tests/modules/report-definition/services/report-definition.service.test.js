jest.mock('@repositories/report-definition/report-definition.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue(undefined),
}));
jest.mock('@lib/reports/runtime', () => ({
  enqueueReportRun: jest.fn(),
}));
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelIdByIdentifier: jest.fn(async ({ identifier }) => identifier),
}));

const reportDefinitionRepository = require('@repositories/report-definition/report-definition.repository');
const { createAuditLog } = require('@lib/audit');
const { enqueueReportRun } = require('@lib/reports/runtime');
const { HttpError } = require('@lib/errors');
const {
  createReportDefinition,
  deleteReportDefinition,
  getReportDefinitionById,
  listReportDefinitions,
  runReportDefinitionNow,
  updateReportDefinition,
} = require('@services/report-definition/report-definition.service');

const buildDefinitionRecord = (overrides = {}) => ({
  id: 'report-definition-123',
  human_friendly_id: 'RD-001',
  tenant_id: 'tenant-123',
  facility_id: 'facility-123',
  name: 'Admissions Daily',
  description: 'Daily admissions volume',
  dataset_key: 'patient_registrations',
  category: 'patients',
  status: 'ACTIVE',
  default_format: 'PDF',
  definition_json: {
    dataset_key: 'patient_registrations',
    columns: ['date', 'registrations'],
    default_filters: [],
    group_by: [],
    sort: [],
    visualization: 'LINE_CHART',
  },
  parameter_schema_json: [],
  created_by: 'user-123',
  tenant: { id: 'tenant-123', human_friendly_id: 'TEN-001', name: 'Tenant One' },
  creator: { id: 'user-123', human_friendly_id: 'USR-001', email: 'owner@example.com' },
  facility: { id: 'facility-123', human_friendly_id: 'FAC-001', name: 'Main Facility' },
  schedules: [],
  runs: [],
  _count: { schedules: 0 },
  version: 1,
  created_at: new Date('2026-01-19T08:00:00.000Z'),
  updated_at: new Date('2026-01-19T08:00:00.000Z'),
  ...overrides,
});

const buildRunRecord = (overrides = {}) => ({
  id: 'report-run-123',
  human_friendly_id: 'RR-001',
  tenant_id: 'tenant-123',
  facility_id: 'facility-123',
  report_definition_id: 'report-definition-123',
  requested_by_user_id: 'user-123',
  trigger_type: 'MANUAL',
  format: 'CSV',
  status: 'QUEUED',
  parameters_json: {},
  output_file_name: null,
  output_mime_type: null,
  output_size_bytes: null,
  output_storage_path: null,
  error_message: null,
  queued_at: new Date('2026-01-20T09:00:00.000Z'),
  created_at: new Date('2026-01-20T09:00:00.000Z'),
  updated_at: new Date('2026-01-20T09:00:00.000Z'),
  version: 1,
  facility: { id: 'facility-123', human_friendly_id: 'FAC-001', name: 'Main Facility' },
  report_definition: {
    id: 'report-definition-123',
    human_friendly_id: 'RD-001',
    name: 'Admissions Daily',
    default_format: 'PDF',
    facility_id: 'facility-123',
  },
  requested_by: {
    id: 'user-123',
    human_friendly_id: 'USR-001',
    email: 'owner@example.com',
    profile: { first_name: 'Owner' },
  },
  schedule: null,
  ...overrides,
});

describe('Report Definition Service', () => {
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

  it('lists scoped report definitions using the object query contract', async () => {
    reportDefinitionRepository.findMany.mockResolvedValue([buildDefinitionRecord()]);
    reportDefinitionRepository.count.mockResolvedValue(1);

    const result = await listReportDefinitions(
      { search: 'Admissions', status: 'active' },
      1,
      20,
      undefined,
      undefined,
      { tenant_id: 'tenant-123' }
    );

    expect(reportDefinitionRepository.findMany).toHaveBeenCalledWith({
      where: expect.objectContaining({
        tenant_id: 'tenant-123',
        status: 'ACTIVE',
        OR: [
          { name: { contains: 'Admissions', mode: 'insensitive' } },
          { description: { contains: 'Admissions', mode: 'insensitive' } },
          { dataset_key: { contains: 'Admissions', mode: 'insensitive' } },
          { category: { contains: 'Admissions', mode: 'insensitive' } },
        ],
      }),
      skip: 0,
      take: 20,
      orderBy: { updated_at: 'desc' },
    });
    expect(result.reportDefinitions[0]).toMatchObject({
      id: 'RD-001',
      display_id: 'RD-001',
      name: 'Admissions Daily',
      facility_id: 'FAC-001',
      tenant_label: 'Tenant One',
    });
    expect(result.pagination).toEqual({
      page: 1,
      limit: 20,
      total: 1,
      totalPages: 1,
      hasNextPage: false,
      hasPreviousPage: false,
    });
  });

  it('loads a single definition within tenant scope', async () => {
    reportDefinitionRepository.findById.mockResolvedValue(buildDefinitionRecord());

    const result = await getReportDefinitionById('report-definition-123', {
      tenant_id: 'tenant-123',
    });

    expect(reportDefinitionRepository.findById).toHaveBeenCalledWith('report-definition-123');
    expect(result).toMatchObject({
      id: 'RD-001',
      name: 'Admissions Daily',
      status: 'ACTIVE',
    });
  });

  it('creates a definition, normalizes dataset metadata, and audits the change', async () => {
    reportDefinitionRepository.create.mockResolvedValue(
      buildDefinitionRecord({
        id: 'report-definition-999',
        human_friendly_id: 'RD-999',
      })
    );

    const result = await createReportDefinition(
      {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        name: 'Registrations',
        dataset_key: 'patient_registrations',
        default_format: 'pdf',
        definition_json: {
          columns: ['date'],
        },
      },
      mutationContext
    );

    expect(reportDefinitionRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        created_by: 'user-123',
        name: 'Registrations',
        dataset_key: 'patient_registrations',
        status: 'DRAFT',
        default_format: 'PDF',
        definition_json: expect.objectContaining({
          dataset_key: 'patient_registrations',
          columns: ['date'],
          visualization: 'LINE_CHART',
        }),
      })
    );
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entity: 'report_definition',
        user_id: 'user-123',
      })
    );
    expect(result).toMatchObject({
      id: 'RD-999',
      default_format: 'PDF',
    });
  });

  it('updates a definition with optimistic locking and version bumping', async () => {
    reportDefinitionRepository.findById.mockResolvedValue(buildDefinitionRecord());
    reportDefinitionRepository.update.mockResolvedValue(
      buildDefinitionRecord({
        name: 'Admissions Weekly',
        version: 2,
        updated_at: new Date('2026-01-20T08:00:00.000Z'),
      })
    );

    const result = await updateReportDefinition(
      'report-definition-123',
      {
        name: 'Admissions Weekly',
        version: 1,
      },
      mutationContext
    );

    expect(reportDefinitionRepository.update).toHaveBeenCalledWith(
      'report-definition-123',
      expect.objectContaining({
        name: 'Admissions Weekly',
        version: 2,
      })
    );
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'UPDATE',
        entity: 'report_definition',
      })
    );
    expect(result).toMatchObject({
      id: 'RD-001',
      name: 'Admissions Weekly',
      version: 2,
    });
  });

  it('queues a manual run from a definition and audits the run creation', async () => {
    reportDefinitionRepository.findById.mockResolvedValue(buildDefinitionRecord());
    enqueueReportRun.mockResolvedValue(
      buildRunRecord({
        id: 'report-run-999',
        human_friendly_id: 'RR-999',
      })
    );

    const result = await runReportDefinitionNow(
      'report-definition-123',
      { format: 'csv', facility_id: 'facility-123', parameters_json: { limit: 10 } },
      mutationContext
    );

    expect(enqueueReportRun).toHaveBeenCalledWith(
      expect.objectContaining({
        report_definition_id: 'report-definition-123',
        facility_id: 'facility-123',
        requested_by_user_id: 'user-123',
        trigger_type: 'MANUAL',
        format: 'CSV',
        parameters_json: { limit: 10 },
      })
    );
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entity: 'report_run',
      })
    );
    expect(result).toMatchObject({
      id: 'RR-999',
      format: 'CSV',
      status: 'QUEUED',
    });
  });

  it('soft deletes a definition within scope and writes an audit record', async () => {
    reportDefinitionRepository.findById.mockResolvedValue(buildDefinitionRecord());
    reportDefinitionRepository.softDelete.mockResolvedValue({});

    await deleteReportDefinition('report-definition-123', mutationContext);

    expect(reportDefinitionRepository.softDelete).toHaveBeenCalledWith('report-definition-123');
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'DELETE',
        entity: 'report_definition',
        user_id: 'user-123',
      })
    );
  });

  it('rejects unknown datasets during creation', async () => {
    await expect(
      createReportDefinition(
        {
          tenant_id: 'tenant-123',
          name: 'Bad Dataset',
          dataset_key: 'not-real',
        },
        mutationContext
      )
    ).rejects.toThrow(HttpError);
  });
});
