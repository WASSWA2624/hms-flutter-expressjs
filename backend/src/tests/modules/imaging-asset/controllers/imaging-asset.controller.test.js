/**
 * Imaging asset controller tests
 *
 * @module tests/modules/imaging-asset/controllers
 * @description Tests for imaging asset controller operations
 * Per testing.mdc: Controller tests must mock service layer
 */

const imagingAssetController = require('@controllers/imaging-asset/imaging-asset.controller');
const imagingAssetService = require('@services/imaging-asset/imaging-asset.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@services/imaging-asset/imaging-asset.service');
jest.mock('@lib/response');

describe('Imaging Asset Controller', () => {
  let mockReq, mockRes;

  beforeEach(() => {
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
    jest.clearAllMocks();
  });

  describe('listImagingAssets', () => {
    it('should list imaging assets with pagination', async () => {
      const mockData = { imagingAssets: [], pagination: {} };
      imagingAssetService.listImagingAssets.mockResolvedValue(mockData);

      await imagingAssetController.listImagingAssets(mockReq, mockRes);

      expect(sendPaginated).toHaveBeenCalled();
    });
  });

  describe('getImagingAssetById', () => {
    it('should get imaging asset by id', async () => {
      mockReq.params.id = '123';
      const mockData = { id: '123', storage_key: 'test.dcm' };
      imagingAssetService.getImagingAssetById.mockResolvedValue(mockData);

      await imagingAssetController.getImagingAssetById(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('createImagingAsset', () => {
    it('should create imaging asset', async () => {
      const mockData = { id: '123' };
      imagingAssetService.createImagingAsset.mockResolvedValue(mockData);

      await imagingAssetController.createImagingAsset(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 201, expect.any(String), mockData);
    });
  });

  describe('updateImagingAsset', () => {
    it('should update imaging asset', async () => {
      mockReq.params.id = '123';
      const mockData = { id: '123' };
      imagingAssetService.updateImagingAsset.mockResolvedValue(mockData);

      await imagingAssetController.updateImagingAsset(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('deleteImagingAsset', () => {
    it('should delete imaging asset', async () => {
      mockReq.params.id = '123';
      imagingAssetService.deleteImagingAsset.mockResolvedValue();

      await imagingAssetController.deleteImagingAsset(mockReq, mockRes);

      expect(sendNoContent).toHaveBeenCalled();
    });
  });
});
