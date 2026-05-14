/**
 * Asset service log controller tests
 *
 * @module tests/modules/asset-service-log/controllers
 * @description Tests for asset service log controller request handlers
 */

const assetServiceLogController = require('../../../../modules/asset-service-log/controllers/asset-service-log.controller');
const assetServiceLogService = require('../../../../modules/asset-service-log/services/asset-service-log.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

// Mock service and response helpers
jest.mock('../../../../modules/asset-service-log/services/asset-service-log.service');
jest.mock('@lib/response');

describe('Asset Service Log Controller', () => {
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
      json: jest.fn()
    };
  });

  describe('listAssetServiceLogs', () => {
    it('should list asset service logs with pagination', async () => {
      const mockResult = {
        assetServiceLogs: [{ id: '1' }, { id: '2' }],
        pagination: { page: 1, limit: 20, total: 2 }
      };

      assetServiceLogService.listAssetServiceLogs.mockResolvedValue(mockResult);

      mockReq.query = {
        page: '1',
        limit: '20',
        sort_by: 'created_at',
        order: 'desc'
      };

      await assetServiceLogController.listAssetServiceLogs(mockReq, mockRes);

      expect(assetServiceLogService.listAssetServiceLogs).toHaveBeenCalledWith(
        expect.any(Object),
        1,
        20,
        'created_at',
        'desc',
        'user-123',
        '127.0.0.1',
        expect.any(Object)
      );

      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.asset_service_log.list.success',
        mockResult.assetServiceLogs,
        mockResult.pagination
      );
    });

    it('should apply filters from query parameters', async () => {
      const mockResult = {
        assetServiceLogs: [],
        pagination: { page: 1, limit: 20, total: 0 }
      };

      assetServiceLogService.listAssetServiceLogs.mockResolvedValue(mockResult);

      mockReq.query = {
        asset_id: '123',
        search: 'maintenance'
      };

      await assetServiceLogController.listAssetServiceLogs(mockReq, mockRes);

      expect(assetServiceLogService.listAssetServiceLogs).toHaveBeenCalledWith(
        expect.objectContaining({
          asset_id: '123',
          search: 'maintenance'
        }),
        1,
        20,
        undefined,
        'asc',
        'user-123',
        '127.0.0.1',
        expect.any(Object)
      );
    });
  });

  describe('getAssetServiceLogById', () => {
    it('should get asset service log by ID', async () => {
      const mockLog = { id: '1', asset_id: 'asset-1', notes: 'Service log' };
      assetServiceLogService.getAssetServiceLogById.mockResolvedValue(mockLog);

      mockReq.params = { id: '1' };

      await assetServiceLogController.getAssetServiceLogById(mockReq, mockRes);

      expect(assetServiceLogService.getAssetServiceLogById).toHaveBeenCalledWith('1', 'user-123', '127.0.0.1', expect.any(Object));

      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.asset_service_log.get.success',
        mockLog
      );
    });
  });

  describe('createAssetServiceLog', () => {
    it('should create new asset service log', async () => {
      const mockData = { asset_id: '123', notes: 'New service log' };
      const mockCreated = { id: '1', ...mockData };

      assetServiceLogService.createAssetServiceLog.mockResolvedValue(mockCreated);

      mockReq.body = mockData;

      await assetServiceLogController.createAssetServiceLog(mockReq, mockRes);

      expect(assetServiceLogService.createAssetServiceLog).toHaveBeenCalledWith(
        mockData,
        'user-123',
        '127.0.0.1',
        expect.any(Object)
      );

      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        201,
        'messages.asset_service_log.create.success',
        mockCreated
      );
    });
  });

  describe('updateAssetServiceLog', () => {
    it('should update asset service log', async () => {
      const mockData = { notes: 'Updated notes' };
      const mockUpdated = { id: '1', ...mockData };

      assetServiceLogService.updateAssetServiceLog.mockResolvedValue(mockUpdated);

      mockReq.params = { id: '1' };
      mockReq.body = mockData;

      await assetServiceLogController.updateAssetServiceLog(mockReq, mockRes);

      expect(assetServiceLogService.updateAssetServiceLog).toHaveBeenCalledWith(
        '1',
        mockData,
        'user-123',
        '127.0.0.1',
        expect.any(Object)
      );

      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.asset_service_log.update.success',
        mockUpdated
      );
    });
  });

  describe('deleteAssetServiceLog', () => {
    it('should delete asset service log', async () => {
      assetServiceLogService.deleteAssetServiceLog.mockResolvedValue();

      mockReq.params = { id: '1' };

      await assetServiceLogController.deleteAssetServiceLog(mockReq, mockRes);

      expect(assetServiceLogService.deleteAssetServiceLog).toHaveBeenCalledWith('1', 'user-123', '127.0.0.1', expect.any(Object));

      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
