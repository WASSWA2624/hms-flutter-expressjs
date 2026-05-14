jest.mock('@repositories/report-schedule/report-schedule.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue(undefined),
}));
jest.mock('@lib/reports/runtime', () => ({
  getNextScheduledTime: jest.fn(() => new Date('2026-03-09T08:00:00.000Z')),
}));
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelIdByIdentifier: jest.fn(async ({ identifier }) => identifier),
}));

const reportScheduleRepository = require('@repositories/report-schedule/report-schedule.repository');
const { createAuditLog } = require('@lib/audit');
const { getNextScheduledTime } = require('@lib/reports/runtime');
const {
  createReportSchedule,
  deleteReportSchedule,
  listReportSchedules,
  pauseReportSchedule,
  updateReportSchedule,
} = require('@services/report-schedule/report-schedule.service');

const buildScheduleRecord = (overrides = {}) => ({
  id: 'report-schedule-123',
  human_friendly_id: 'RS-001',
  tenant_id: 'tenant-123',
  facility_id: 'facility-123',
  report_definition_id: 'report-definition-123',
  name: 'Morning schedule',
  status: 'ACTIVE',
  frequency: 'DAILY',
  time_of_day: '08:00',
  day_of_week: null,
  day_of_month: null,
  timezone: 'UTC',
  format: 'PDF',
  parameter_overrides_json: {},
  next_run_at: new Date('2026-03-09T08:00:00.000Z'),
  last_run_at: null,
  retention_days: 30,
  created_by: 'user-123',
  facility: { id: 'facility-123', human_friendly_id: 'FAC-001', name: 'Main Facility' },
  report_definition: {
    id: 'report-definition-123',
    human_friendly_id: 'RD-001',
    name: 'Admissions Daily',
    default_format: 'PDF',
  },
  creator: { id: 'user-123', human_friendly_id: 'USR-001', email: 'owner@example.com' },
  _count: { runs: 0 },
  version: 1,
  created_at: new Date('2026-03-08T08:00:00.000Z'),
  updated_at: new Date('2026-03-08T08:00:00.000Z'),
  ...overrides,
});

describe('Report Schedule Service', () => {
  const mutationContext = {
    user: {
      id: 'user-123',
      tenant_id: 'tenant-123',
      facility_id: 'facility-123',
    },
    user_id: 'user-123',
    ip_address: '127.0.0.1',
    user_agent: 'Jest',
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('lists scoped schedules using the object query contract', async () => {
    reportScheduleRepository.findMany.mockResolvedValue([buildScheduleRecord()]);
    reportScheduleRepository.count.mockResolvedValue(1);

    const result = await listReportSchedules(
      { status: 'ACTIVE', search: 'Morning' },
      1,
      20,
      undefined,
      undefined,
      { tenant_id: 'tenant-123', facility_id: 'facility-123' }
    );

    expect(reportScheduleRepository.findMany).toHaveBeenCalledWith({
      where: expect.objectContaining({
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        status: 'ACTIVE',
        OR: [{ name: { contains: 'Morning', mode: 'insensitive' } }],
      }),
      skip: 0,
      take: 20,
      orderBy: { next_run_at: 'desc' },
    });
    expect(result.reportSchedules[0]).toMatchObject({
      id: 'RS-001',
      report_definition_id: 'RD-001',
      facility_id: 'FAC-001',
    });
  });

  it('creates a schedule, computes the next run, and audits the change', async () => {
    reportScheduleRepository.create.mockResolvedValue(
      buildScheduleRecord({
        frequency: 'WEEKLY',
        day_of_week: 1,
      })
    );

    const result = await createReportSchedule(
      {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        report_definition_id: 'report-definition-123',
        name: 'Morning schedule',
        frequency: 'WEEKLY',
        day_of_week: 1,
      },
      mutationContext
    );

    expect(getNextScheduledTime).toHaveBeenCalled();
    expect(reportScheduleRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        report_definition_id: 'report-definition-123',
        status: 'ACTIVE',
        frequency: 'WEEKLY',
        time_of_day: '08:00',
        next_run_at: new Date('2026-03-09T08:00:00.000Z'),
      })
    );
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entity: 'report_schedule',
      })
    );
    expect(result).toMatchObject({
      id: 'RS-001',
      frequency: 'WEEKLY',
    });
  });

  it('updates a schedule with optimistic locking and next-run recalculation', async () => {
    reportScheduleRepository.findById.mockResolvedValue(buildScheduleRecord());
    reportScheduleRepository.update.mockResolvedValue(
      buildScheduleRecord({
        frequency: 'MONTHLY',
        day_of_month: 15,
        version: 2,
      })
    );

    const result = await updateReportSchedule(
      'report-schedule-123',
      {
        frequency: 'MONTHLY',
        day_of_month: 15,
        version: 1,
      },
      mutationContext
    );

    expect(reportScheduleRepository.update).toHaveBeenCalledWith(
      'report-schedule-123',
      expect.objectContaining({
        frequency: 'MONTHLY',
        day_of_month: 15,
        next_run_at: new Date('2026-03-09T08:00:00.000Z'),
        version: 2,
      })
    );
    expect(result).toMatchObject({
      id: 'RS-001',
      version: 2,
    });
  });

  it('pauses and soft deletes schedules within scope', async () => {
    reportScheduleRepository.findById.mockResolvedValue(buildScheduleRecord());
    reportScheduleRepository.update.mockResolvedValue(
      buildScheduleRecord({ status: 'PAUSED', version: 2 })
    );
    reportScheduleRepository.softDelete.mockResolvedValue({});

    const paused = await pauseReportSchedule('report-schedule-123', mutationContext);
    await deleteReportSchedule('report-schedule-123', mutationContext);

    expect(reportScheduleRepository.update).toHaveBeenCalledWith(
      'report-schedule-123',
      expect.objectContaining({
        status: 'PAUSED',
        version: 2,
      })
    );
    expect(reportScheduleRepository.softDelete).toHaveBeenCalledWith('report-schedule-123');
    expect(paused).toMatchObject({
      id: 'RS-001',
      status: 'PAUSED',
    });
  });
});
