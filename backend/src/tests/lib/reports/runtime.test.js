jest.mock('@lib/storage', () => ({
  createStorageService: jest.fn(() => ({
    upload: jest.fn(),
    delete: jest.fn(),
  })),
}));

jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn(),
}));

jest.mock('@services/notification/notification.service', () => ({
  createNotification: jest.fn(),
}));

jest.mock('@lib/reports/datasets', () => ({
  executeReportDataset: jest.fn(),
}));

jest.mock('@lib/reports/files', () => ({
  generateReportFile: jest.fn(),
}));

jest.mock('@lib/logging', () => ({
  logger: {
    warn: jest.fn(),
    info: jest.fn(),
    error: jest.fn(),
  },
}));

describe('reports runtime scheduler', () => {
  const loadRuntime = ({ tableRows, reportScheduleError, runImmediate = false } = {}) => {
    jest.resetModules();

    const prismaMock = {
      $queryRawUnsafe: jest.fn().mockResolvedValue(tableRows || []),
      report_schedule: {
        findMany: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn(),
      },
      report_run: {
        findMany: jest.fn(),
        findFirst: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn(),
      },
      report_definition: {
        findFirst: jest.fn(),
      },
    };

    if (reportScheduleError) {
      prismaMock.report_schedule.findMany.mockRejectedValue(reportScheduleError);
    } else {
      prismaMock.report_schedule.findMany.mockResolvedValue([]);
    }
    prismaMock.report_run.findMany.mockResolvedValue([]);
    prismaMock.report_run.findFirst.mockResolvedValue(null);

    jest.doMock('@prisma/client', () => prismaMock);

    const intervalHandle = { unref: jest.fn() };
    jest.spyOn(global, 'setInterval').mockReturnValue(intervalHandle);
    jest.spyOn(global, 'clearInterval').mockImplementation(() => {});
    jest.spyOn(global, 'setImmediate').mockImplementation((callback) => {
      if (runImmediate && typeof callback === 'function') {
        callback();
      }
      return intervalHandle;
    });

    const runtime = require('@lib/reports/runtime');
    const { logger } = require('@lib/logging');

    return { runtime, prismaMock, logger };
  };

  afterEach(() => {
    jest.restoreAllMocks();
    jest.clearAllMocks();
  });

  it('does not start the scheduler when report runtime tables are missing', async () => {
    const { runtime, prismaMock, logger } = loadRuntime({
      tableRows: [{ table_name: 'report_run' }, { table_name: 'report_definition' }],
    });

    const started = await runtime.startReportRunScheduler();

    expect(started).toBe(false);
    expect(global.setInterval).not.toHaveBeenCalled();
    expect(prismaMock.report_schedule.findMany).not.toHaveBeenCalled();
    expect(logger.warn).toHaveBeenCalledWith(
      'Reports runtime disabled',
      expect.objectContaining({
        reason: 'missing_report_runtime_tables',
        missing_tables: ['report_schedule'],
      })
    );
  });

  it('disables the scheduler when a tick hits a missing schema artifact', async () => {
    const missingTableError = new Error('The table `report_schedule` does not exist in the current database.');
    missingTableError.code = 'P2021';

    const { runtime, logger } = loadRuntime({
      tableRows: [
        { table_name: 'report_definition' },
        { table_name: 'report_run' },
        { table_name: 'report_schedule' },
      ],
      reportScheduleError: missingTableError,
      runImmediate: true,
    });

    const started = await runtime.startReportRunScheduler();

    expect(started).toBe(true);
    expect(global.setInterval).toHaveBeenCalledTimes(1);
    expect(logger.warn).toHaveBeenCalledWith(
      'Reports runtime disabled',
      expect.objectContaining({
        reason: 'missing_report_schema_artifact',
        code: 'P2021',
        context: 'startup',
      })
    );
    expect(global.clearInterval).toHaveBeenCalledTimes(1);
  });

  it('computes weekly schedules using the requested weekday instead of the daily path', () => {
    jest.resetModules();
    const runtime = require('@lib/reports/runtime');
    const reference = new Date('2026-03-08T10:00:00.000Z'); // Sunday

    const nextRun = runtime.getNextScheduledTime(
      {
        frequency: 'WEEKLY',
        day_of_week: 1,
        time_of_day: '08:00',
        timezone: 'UTC',
      },
      reference
    );

    expect(nextRun.toISOString()).toBe('2026-03-09T08:00:00.000Z');
  });

  it('computes monthly schedules using the requested day of month instead of the daily path', () => {
    jest.resetModules();
    const runtime = require('@lib/reports/runtime');
    const reference = new Date('2026-03-08T10:00:00.000Z');

    const nextRun = runtime.getNextScheduledTime(
      {
        frequency: 'MONTHLY',
        day_of_month: 15,
        time_of_day: '08:00',
        timezone: 'UTC',
      },
      reference
    );

    expect(nextRun.toISOString()).toBe('2026-03-15T08:00:00.000Z');
  });
});
