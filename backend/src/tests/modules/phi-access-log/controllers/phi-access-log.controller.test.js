jest.mock('@modules/phi-access-log/services/phi-access-log.service');
jest.mock('@lib/response');

const phiAccessLogController = require('@modules/phi-access-log/controllers/phi-access-log.controller');
const phiAccessLogService = require('@modules/phi-access-log/services/phi-access-log.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

describe('PHI Access Log Controller', () => {
  let req;
  let res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      params: {},
      query: {},
      body: {},
      user: {
        id: 'USR0000001',
        tenant_id: 'TEN0000001',
      },
      ip: '192.168.1.1',
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
  });

  it('passes req.user to getPhiAccessLogById', async () => {
    const record = { id: 'PAL0000001', access_scope: 'PATIENT' };
    req.params.id = 'PAL0000001';
    phiAccessLogService.getPhiAccessLogById.mockResolvedValue(record);

    await phiAccessLogController.getPhiAccessLogById(req, res);

    expect(phiAccessLogService.getPhiAccessLogById).toHaveBeenCalledWith(
      'PAL0000001',
      req.user
    );
    expect(sendSuccess).toHaveBeenCalledWith(
      res,
      200,
      'messages.phi_access_log.retrieved',
      record
    );
  });

  it('passes filters, pagination, sorting, and scope to list queries', async () => {
    req.query = {
      tenant_id: 'TEN0000001',
      patient_id: 'PAT0000001',
      access_scope: 'PATIENT',
      page: '2',
      limit: '15',
      sort_by: 'created_at',
      order: 'asc',
    };
    phiAccessLogService.getPhiAccessLogs.mockResolvedValue({
      data: [],
      total: 0,
      page: 2,
      limit: 15,
      totalPages: 0,
    });

    await phiAccessLogController.getPhiAccessLogs(req, res);

    expect(phiAccessLogService.getPhiAccessLogs).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'TEN0000001',
        patient_id: 'PAT0000001',
        access_scope: 'PATIENT',
      }),
      2,
      15,
      'created_at',
      'asc',
      req.user
    );
    expect(sendPaginated).toHaveBeenCalled();
  });

  it('passes req.user to getPhiAccessLogsByUserId', async () => {
    req.params.userId = 'USR0000009';
    phiAccessLogService.getPhiAccessLogsByUserId.mockResolvedValue({
      data: [],
      total: 0,
      page: 1,
      limit: 20,
      totalPages: 0,
    });

    await phiAccessLogController.getPhiAccessLogsByUserId(req, res);

    expect(phiAccessLogService.getPhiAccessLogsByUserId).toHaveBeenCalledWith(
      'USR0000009',
      1,
      20,
      'accessed_at',
      'desc',
      req.user
    );
  });

  it('passes req.user and IP address to create/update/delete mutations', async () => {
    phiAccessLogService.createPhiAccessLog.mockResolvedValue({ id: 'PAL0000001' });
    phiAccessLogService.updatePhiAccessLog.mockResolvedValue({ id: 'PAL0000001' });
    phiAccessLogService.deletePhiAccessLog.mockResolvedValue(undefined);

    req.body = {
      patient_id: 'PAT0000001',
      access_scope: 'PATIENT',
      reason: 'Clinical review',
    };

    await phiAccessLogController.createPhiAccessLog(req, res);
    expect(phiAccessLogService.createPhiAccessLog).toHaveBeenCalledWith(
      req.body,
      req.user,
      req.ip
    );

    req.params.id = 'PAL0000001';
    req.body = { access_scope: 'FACILITY' };
    await phiAccessLogController.updatePhiAccessLog(req, res);
    expect(phiAccessLogService.updatePhiAccessLog).toHaveBeenCalledWith(
      'PAL0000001',
      req.body,
      req.user,
      req.ip
    );

    await phiAccessLogController.deletePhiAccessLog(req, res);
    expect(phiAccessLogService.deletePhiAccessLog).toHaveBeenCalledWith(
      'PAL0000001',
      req.user,
      req.ip
    );
    expect(sendNoContent).toHaveBeenCalledWith(res);
  });
});
