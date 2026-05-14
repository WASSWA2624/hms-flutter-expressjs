/**
 * Critical Alert controller tests
 *
 * @module tests/modules/critical-alert/controllers
 * @description Tests for critical alert controller request handlers
 * Per testing.mdc: Controller tests must mock service layer
 */

const criticalAlertController = require('@controllers/critical-alert/critical-alert.controller');
const criticalAlertService = require('@services/critical-alert/critical-alert.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@services/critical-alert/critical-alert.service');
jest.mock('@lib/response');
jest.mock('@config/constants', () => ({
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_LIMIT: 20
}));

describe('Critical Alert Controller', () => {
  let mockReq;
  let mockRes;

  beforeEach(() => {
    jest.clearAllMocks();
    mockReq = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-123' },
      ip: '127.0.0.1'
    };
    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
  });

  describe('listCriticalAlerts', () => {
    it('should call service and send paginated response', async () => {
      const mockResult = {
        critical_alerts: [{ id: '1', icu_stay_id: '100', severity: 'CRITICAL' }],
        pagination: { page: 1, limit: 20, total: 1 }
      };
      criticalAlertService.listCriticalAlerts.mockResolvedValue(mockResult);

      await criticalAlertController.listCriticalAlerts(mockReq, mockRes);

      expect(sendPaginated).toHaveBeenCalled();
    });
  });

  describe('getCriticalAlertById', () => {
    it('should call service and send success response', async () => {
      mockReq.params.id = '123';
      const mockAlert = { id: '123', icu_stay_id: '456', severity: 'HIGH' };
      criticalAlertService.getCriticalAlertById.mockResolvedValue(mockAlert);

      await criticalAlertController.getCriticalAlertById(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.critical_alert.get.success', mockAlert);
    });
  });

  describe('createCriticalAlert', () => {
    it('should call service and send 201 response', async () => {
      mockReq.body = { icu_stay_id: '123', severity: 'CRITICAL', message: 'Test' };
      const mockAlert = { id: '456', ...mockReq.body };
      criticalAlertService.createCriticalAlert.mockResolvedValue(mockAlert);

      await criticalAlertController.createCriticalAlert(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 201, 'messages.critical_alert.create.success', mockAlert);
    });
  });

  describe('updateCriticalAlert', () => {
    it('should call service and send success response', async () => {
      mockReq.params.id = '123';
      mockReq.body = { severity: 'HIGH' };
      const mockAlert = { id: '123', severity: 'HIGH' };
      criticalAlertService.updateCriticalAlert.mockResolvedValue(mockAlert);

      await criticalAlertController.updateCriticalAlert(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.critical_alert.update.success', mockAlert);
    });
  });

  describe('deleteCriticalAlert', () => {
    it('should call service and send no content response', async () => {
      mockReq.params.id = '123';
      criticalAlertService.deleteCriticalAlert.mockResolvedValue();

      await criticalAlertController.deleteCriticalAlert(mockReq, mockRes);

      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
