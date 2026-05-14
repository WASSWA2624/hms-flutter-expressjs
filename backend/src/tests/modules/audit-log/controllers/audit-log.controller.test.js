jest.mock('@modules/audit-log/services/audit-log.service');
jest.mock('@lib/response');

const auditLogController = require('@modules/audit-log/controllers/audit-log.controller');
const auditLogService = require('@modules/audit-log/services/audit-log.service');
const { sendSuccess, sendPaginated } = require('@lib/response');

describe('Audit Log Controller', () => {
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
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
  });

  it('passes the request user through when loading a single audit log', async () => {
    const record = { id: 'AUD0000001', action: 'CREATE' };
    req.params.id = 'AUD0000001';
    auditLogService.getAuditLogById.mockResolvedValue(record);

    await auditLogController.getAuditLogById(req, res);

    expect(auditLogService.getAuditLogById).toHaveBeenCalledWith(
      'AUD0000001',
      req.user
    );
    expect(sendSuccess).toHaveBeenCalledWith(
      res,
      200,
      'messages.audit_log.retrieved',
      record
    );
  });

  it('passes filters, pagination, sorting, and scope to the list service', async () => {
    req.query = {
      tenant_id: 'TEN0000001',
      action: 'CREATE',
      entity: 'patient',
      page: '2',
      limit: '10',
      sort_by: 'action',
      order: 'asc',
    };
    auditLogService.getAuditLogs.mockResolvedValue({
      data: [{ id: 'AUD0000001' }],
      total: 11,
      page: 2,
      limit: 10,
      totalPages: 2,
    });

    await auditLogController.getAuditLogs(req, res);

    expect(auditLogService.getAuditLogs).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'TEN0000001',
        action: 'CREATE',
        entity: 'patient',
      }),
      2,
      10,
      'action',
      'asc',
      req.user
    );
    expect(sendPaginated).toHaveBeenCalledWith(
      res,
      'messages.audit_log.list_retrieved',
      [{ id: 'AUD0000001' }],
      expect.objectContaining({
        page: 2,
        limit: 10,
        total: 11,
        totalPages: 2,
      })
    );
  });

  it('passes the scoped user to user-specific audit log queries', async () => {
    auditLogService.getAuditLogsByUserId.mockResolvedValue({
      data: [],
      total: 0,
      page: 1,
      limit: 20,
      totalPages: 0,
    });
    req.params.userId = 'USR0000009';

    await auditLogController.getAuditLogsByUserId(req, res);

    expect(auditLogService.getAuditLogsByUserId).toHaveBeenCalledWith(
      'USR0000009',
      1,
      20,
      'created_at',
      'desc',
      req.user
    );
  });

  it('passes the scoped user to entity-specific audit log queries', async () => {
    auditLogService.getAuditLogsByEntity.mockResolvedValue({
      data: [],
      total: 0,
      page: 1,
      limit: 20,
      totalPages: 0,
    });
    req.params = {
      entity: 'patient',
      entityId: 'PAT0000001',
    };

    await auditLogController.getAuditLogsByEntity(req, res);

    expect(auditLogService.getAuditLogsByEntity).toHaveBeenCalledWith(
      'patient',
      'PAT0000001',
      1,
      20,
      'created_at',
      'desc',
      req.user
    );
  });
});
