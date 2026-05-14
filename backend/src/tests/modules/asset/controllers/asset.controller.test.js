/**
 * Asset controller tests
 *
 * @module tests/modules/asset/controllers
 * @description Tests for asset controller request handlers
 */

const assetController = require('../../../../modules/asset/controllers/asset.controller');
const assetService = require('../../../../modules/asset/services/asset.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

// Mock service and response helpers
jest.mock('../../../../modules/asset/services/asset.service');
jest.mock('@lib/response');

describe('Asset Controller', () => {
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

  describe('listAssets', () => {
    it('should list assets with pagination', async () => {
      const mockResult = {
        assets: [{ id: '1' }, { id: '2' }],
        pagination: { page: 1, limit: 20, total: 2 }
      };

      assetService.listAssets.mockResolvedValue(mockResult);

      mockReq.query = {
        page: '1',
        limit: '20',
        sort_by: 'created_at',
        order: 'desc'
      };

      await assetController.listAssets(mockReq, mockRes);

      expect(assetService.listAssets).toHaveBeenCalledWith(
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
        'messages.asset.list.success',
        mockResult.assets,
        mockResult.pagination
      );
    });

    it('should apply filters from query parameters', async () => {
      const mockResult = {
        assets: [],
        pagination: { page: 1, limit: 20, total: 0 }
      };

      assetService.listAssets.mockResolvedValue(mockResult);

      mockReq.query = {
        tenant_id: '123',
        facility_id: '456',
        name: 'Equipment',
        asset_tag: 'MED-001',
        status: 'OPEN',
        search: 'medical'
      };

      await assetController.listAssets(mockReq, mockRes);

      expect(assetService.listAssets).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: '123',
          facility_id: '456',
          name: 'Equipment',
          asset_tag: 'MED-001',
          status: 'OPEN',
          search: 'medical'
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

  describe('getAssetById', () => {
    it('should get asset by ID', async () => {
      const mockAsset = { id: '1', name: 'Asset', status: 'OPEN' };
      assetService.getAssetById.mockResolvedValue(mockAsset);

      mockReq.params = { id: '1' };

      await assetController.getAssetById(mockReq, mockRes);

      expect(assetService.getAssetById).toHaveBeenCalledWith('1', 'user-123', '127.0.0.1', expect.any(Object));

      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.asset.get.success',
        mockAsset
      );
    });
  });

  describe('createAsset', () => {
    it('should create new asset', async () => {
      const mockData = { tenant_id: '123', name: 'New Asset', status: 'OPEN' };
      const mockCreated = { id: '1', ...mockData };

      assetService.createAsset.mockResolvedValue(mockCreated);

      mockReq.body = mockData;

      await assetController.createAsset(mockReq, mockRes);

      expect(assetService.createAsset).toHaveBeenCalledWith(
        mockData,
        'user-123',
        '127.0.0.1',
        expect.any(Object)
      );

      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        201,
        'messages.asset.create.success',
        mockCreated
      );
    });
  });

  describe('updateAsset', () => {
    it('should update asset', async () => {
      const mockData = { name: 'Updated Asset' };
      const mockUpdated = { id: '1', ...mockData };

      assetService.updateAsset.mockResolvedValue(mockUpdated);

      mockReq.params = { id: '1' };
      mockReq.body = mockData;

      await assetController.updateAsset(mockReq, mockRes);

      expect(assetService.updateAsset).toHaveBeenCalledWith(
        '1',
        mockData,
        'user-123',
        '127.0.0.1',
        expect.any(Object)
      );

      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.asset.update.success',
        mockUpdated
      );
    });
  });

  describe('deleteAsset', () => {
    it('should delete asset', async () => {
      assetService.deleteAsset.mockResolvedValue();

      mockReq.params = { id: '1' };

      await assetController.deleteAsset(mockReq, mockRes);

      expect(assetService.deleteAsset).toHaveBeenCalledWith('1', 'user-123', '127.0.0.1', expect.any(Object));

      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
