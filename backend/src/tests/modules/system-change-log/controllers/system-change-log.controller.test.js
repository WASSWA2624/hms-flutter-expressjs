jest.mock('@services/system-change-log/system-change-log.service');
jest.mock('@lib/response');

const systemChangeLogController = require('@controllers/system-change-log/system-change-log.controller');
const systemChangeLogService = require('@services/system-change-log/system-change-log.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

describe('System Change Log Controller', () => {
  const mockRecord = {
    id: 'SCL0000001',
    change_type: 'DATABASE_MIGRATION',
    details: 'Pending review',
  };

  let req;
  let res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: {
        id: 'USR0000001',
        tenant_id: 'TEN0000001',
      },
      ip: '127.0.0.1',
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
    };
  });

  it('passes filters and req.user to listSystemChangeLogs', async () => {
    req.query = {
      change_type: 'DATABASE_MIGRATION',
      page: '2',
      limit: '5',
      sort_by: 'created_at',
      order: 'asc',
    };
    systemChangeLogService.listSystemChangeLogs.mockResolvedValue({
      systemChangeLogs: [mockRecord],
      pagination: {
        page: 2,
        limit: 5,
        total: 1,
        totalPages: 1,
      },
    });

    await systemChangeLogController.listSystemChangeLogs(req, res);

    expect(systemChangeLogService.listSystemChangeLogs).toHaveBeenCalledWith(
      expect.objectContaining({ change_type: 'DATABASE_MIGRATION' }),
      2,
      5,
      'created_at',
      'asc',
      req.user
    );
    expect(sendPaginated).toHaveBeenCalled();
  });

  it('passes req.user to get/create/update/delete handlers', async () => {
    systemChangeLogService.getSystemChangeLogById.mockResolvedValue(mockRecord);
    systemChangeLogService.createSystemChangeLog.mockResolvedValue(mockRecord);
    systemChangeLogService.updateSystemChangeLog.mockResolvedValue(mockRecord);
    systemChangeLogService.deleteSystemChangeLog.mockResolvedValue(undefined);

    req.params.id = 'SCL0000001';
    await systemChangeLogController.getSystemChangeLogById(req, res);
    expect(systemChangeLogService.getSystemChangeLogById).toHaveBeenCalledWith(
      'SCL0000001',
      req.user
    );

    req.body = { change_type: 'DATABASE_MIGRATION', details: 'Rollout notes' };
    await systemChangeLogController.createSystemChangeLog(req, res);
    expect(systemChangeLogService.createSystemChangeLog).toHaveBeenCalledWith(
      req.body,
      req.user,
      req.ip
    );

    req.body = { change_type: 'CONFIG_UPDATE' };
    await systemChangeLogController.updateSystemChangeLog(req, res);
    expect(systemChangeLogService.updateSystemChangeLog).toHaveBeenCalledWith(
      'SCL0000001',
      req.body,
      req.user,
      req.ip
    );

    await systemChangeLogController.deleteSystemChangeLog(req, res);
    expect(systemChangeLogService.deleteSystemChangeLog).toHaveBeenCalledWith(
      'SCL0000001',
      req.user,
      req.ip
    );
    expect(sendNoContent).toHaveBeenCalledWith(res);
  });

  it('passes note payloads to approve and implement handlers', async () => {
    systemChangeLogService.approveSystemChangeLog.mockResolvedValue(mockRecord);
    systemChangeLogService.implementSystemChangeLog.mockResolvedValue(mockRecord);
    req.params.id = 'SCL0000001';

    req.body = { approval_notes: 'Approved after CAB review' };
    await systemChangeLogController.approveSystemChangeLog(req, res);
    expect(systemChangeLogService.approveSystemChangeLog).toHaveBeenCalledWith(
      'SCL0000001',
      'Approved after CAB review',
      req.user,
      req.ip
    );

    req.body = { implementation_notes: 'Released to production' };
    await systemChangeLogController.implementSystemChangeLog(req, res);
    expect(systemChangeLogService.implementSystemChangeLog).toHaveBeenCalledWith(
      'SCL0000001',
      'Released to production',
      req.user,
      req.ip
    );
  });
});
