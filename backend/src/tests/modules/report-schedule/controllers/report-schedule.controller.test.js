jest.mock('@services/report-schedule/report-schedule.service');
jest.mock('@lib/response');

const reportScheduleService = require('@services/report-schedule/report-schedule.service');
const { sendNoContent, sendPaginated, sendSuccess } = require('@lib/response');
const {
  createReportSchedule,
  deleteReportSchedule,
  getReportScheduleById,
  listReportSchedules,
  pauseReportSchedule,
  resumeReportSchedule,
  updateReportSchedule,
} = require('@controllers/report-schedule/report-schedule.controller');

describe('Report Schedule Controller', () => {
  let mockReq;
  let mockRes;

  beforeEach(() => {
    jest.clearAllMocks();
    mockReq = {
      params: {},
      query: {},
      body: {},
      user: {
        id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
      },
      ip: '127.0.0.1',
      get: jest.fn().mockReturnValue('Test Agent'),
    };
    mockRes = {};
  });

  it('passes list filters and req.user to the service', async () => {
    const payload = {
      reportSchedules: [{ id: 'RS-001', name: 'Morning' }],
      pagination: {
        page: 1,
        limit: 20,
        total: 1,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false,
      },
    };
    mockReq.query = { page: '1', limit: '20', status: 'ACTIVE' };
    reportScheduleService.listReportSchedules.mockResolvedValue(payload);

    await listReportSchedules(mockReq, mockRes);

    expect(reportScheduleService.listReportSchedules).toHaveBeenCalledWith(
      { status: 'ACTIVE' },
      1,
      20,
      undefined,
      undefined,
      mockReq.user
    );
    expect(sendPaginated).toHaveBeenCalledWith(
      mockRes,
      'messages.report_schedule.list_success',
      payload.reportSchedules,
      payload.pagination
    );
  });

  it('passes req.user to get by id', async () => {
    const payload = { id: 'RS-001', name: 'Morning' };
    mockReq.params.id = 'report-schedule-123';
    reportScheduleService.getReportScheduleById.mockResolvedValue(payload);

    await getReportScheduleById(mockReq, mockRes);

    expect(reportScheduleService.getReportScheduleById).toHaveBeenCalledWith(
      'report-schedule-123',
      mockReq.user
    );
    expect(sendSuccess).toHaveBeenCalledWith(
      mockRes,
      200,
      'messages.report_schedule.get_success',
      payload
    );
  });

  it('builds mutation context for create and update flows', async () => {
    const payload = { id: 'RS-001', name: 'Morning' };
    mockReq.body = { name: 'Morning', frequency: 'DAILY', report_definition_id: 'report-definition-123' };
    reportScheduleService.createReportSchedule.mockResolvedValue(payload);
    reportScheduleService.updateReportSchedule.mockResolvedValue(payload);

    await createReportSchedule(mockReq, mockRes);
    mockReq.params.id = 'report-schedule-123';
    await updateReportSchedule(mockReq, mockRes);

    expect(reportScheduleService.createReportSchedule).toHaveBeenCalledWith(
      mockReq.body,
      expect.objectContaining({
        user: mockReq.user,
        user_id: 'user-123',
        ip_address: '127.0.0.1',
        user_agent: 'Test Agent',
      })
    );
    expect(reportScheduleService.updateReportSchedule).toHaveBeenCalledWith(
      'report-schedule-123',
      mockReq.body,
      expect.objectContaining({
        user: mockReq.user,
        user_id: 'user-123',
      })
    );
  });

  it('passes the current request context into pause, resume, and delete actions', async () => {
    const payload = { id: 'RS-001', status: 'PAUSED' };
    mockReq.params.id = 'report-schedule-123';
    reportScheduleService.pauseReportSchedule.mockResolvedValue(payload);
    reportScheduleService.resumeReportSchedule.mockResolvedValue({ ...payload, status: 'ACTIVE' });
    reportScheduleService.deleteReportSchedule.mockResolvedValue();

    await pauseReportSchedule(mockReq, mockRes);
    await resumeReportSchedule(mockReq, mockRes);
    await deleteReportSchedule(mockReq, mockRes);

    expect(reportScheduleService.pauseReportSchedule).toHaveBeenCalledWith(
      'report-schedule-123',
      expect.objectContaining({ user: mockReq.user, user_id: 'user-123' })
    );
    expect(reportScheduleService.resumeReportSchedule).toHaveBeenCalledWith(
      'report-schedule-123',
      expect.objectContaining({ user: mockReq.user, user_id: 'user-123' })
    );
    expect(reportScheduleService.deleteReportSchedule).toHaveBeenCalledWith(
      'report-schedule-123',
      expect.objectContaining({ user: mockReq.user, user_id: 'user-123' })
    );
    expect(sendNoContent).toHaveBeenCalledWith(mockRes);
  });
});
