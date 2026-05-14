jest.mock('@services/breach-notification/breach-notification.service');
jest.mock('@lib/response');

const breachNotificationController = require('@controllers/breach-notification/breach-notification.controller');
const breachNotificationService = require('@services/breach-notification/breach-notification.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

describe('Breach Notification Controller', () => {
  const mockRecord = {
    id: 'BRN0000001',
    severity: 'HIGH',
    status: 'OPEN',
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

  it('passes filters and req.user to listBreachNotifications', async () => {
    req.query = {
      severity: 'HIGH',
      page: '2',
      limit: '10',
      sort_by: 'reported_at',
      order: 'asc',
    };
    breachNotificationService.listBreachNotifications.mockResolvedValue({
      breachNotifications: [mockRecord],
      pagination: {
        page: 2,
        limit: 10,
        total: 1,
        totalPages: 1,
      },
    });

    await breachNotificationController.listBreachNotifications(req, res);

    expect(breachNotificationService.listBreachNotifications).toHaveBeenCalledWith(
      expect.objectContaining({ severity: 'HIGH' }),
      2,
      10,
      'reported_at',
      'asc',
      req.user
    );
    expect(sendPaginated).toHaveBeenCalledWith(
      res,
      'messages.breach_notification.list.success',
      [mockRecord],
      expect.objectContaining({ page: 2, limit: 10 })
    );
  });

  it('passes req.user to single-record and mutation handlers', async () => {
    breachNotificationService.getBreachNotificationById.mockResolvedValue(mockRecord);
    breachNotificationService.createBreachNotification.mockResolvedValue(mockRecord);
    breachNotificationService.updateBreachNotification.mockResolvedValue(mockRecord);
    breachNotificationService.resolveBreachNotification.mockResolvedValue({
      ...mockRecord,
      status: 'RESOLVED',
    });
    breachNotificationService.deleteBreachNotification.mockResolvedValue(undefined);

    req.params.id = 'BRN0000001';
    await breachNotificationController.getBreachNotificationById(req, res);
    expect(breachNotificationService.getBreachNotificationById).toHaveBeenCalledWith(
      'BRN0000001',
      req.user
    );

    req.body = { severity: 'HIGH', description: 'Security breach detected' };
    await breachNotificationController.createBreachNotification(req, res);
    expect(breachNotificationService.createBreachNotification).toHaveBeenCalledWith(
      req.body,
      req.user,
      req.ip
    );

    req.body = { status: 'INVESTIGATING' };
    await breachNotificationController.updateBreachNotification(req, res);
    expect(breachNotificationService.updateBreachNotification).toHaveBeenCalledWith(
      'BRN0000001',
      req.body,
      req.user,
      req.ip
    );

    req.body = { resolved_at: '2026-03-08T15:00:00.000Z' };
    await breachNotificationController.resolveBreachNotification(req, res);
    expect(breachNotificationService.resolveBreachNotification).toHaveBeenCalledWith(
      'BRN0000001',
      expect.any(Date),
      req.user,
      req.ip
    );

    req.body = {};
    await breachNotificationController.deleteBreachNotification(req, res);
    expect(breachNotificationService.deleteBreachNotification).toHaveBeenCalledWith(
      'BRN0000001',
      req.user,
      req.ip
    );
    expect(sendNoContent).toHaveBeenCalledWith(res);
  });

  it('passes a null resolution date when resolved_at is omitted', async () => {
    breachNotificationService.resolveBreachNotification.mockResolvedValue({
      ...mockRecord,
      status: 'RESOLVED',
    });
    req.params.id = 'BRN0000001';

    await breachNotificationController.resolveBreachNotification(req, res);

    expect(breachNotificationService.resolveBreachNotification).toHaveBeenCalledWith(
      'BRN0000001',
      null,
      req.user,
      req.ip
    );
    expect(sendSuccess).toHaveBeenCalledWith(
      res,
      200,
      'messages.breach_notification.resolve.success',
      expect.objectContaining({ status: 'RESOLVED' })
    );
  });
});
