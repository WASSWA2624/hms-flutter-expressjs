/**
 * Imaging asset service tests
 *
 * @module tests/modules/imaging-asset/services
 * @description Tests for imaging asset service operations
 * Per testing.mdc: Service tests must mock repository and audit
 */

const imagingAssetService = require('@services/imaging-asset/imaging-asset.service');
const imagingAssetRepository = require('@repositories/imaging-asset/imaging-asset.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

jest.mock('@repositories/imaging-asset/imaging-asset.repository');
jest.mock('@lib/audit');

describe('Imaging Asset Service', () => {
  const mockUserId = 'user-123';
  const mockIpAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  describe('listImagingAssets', () => {
    it('should list imaging assets with pagination', async () => {
      const mockData = [{ id: '1', storage_key: 'test.dcm' }];
      imagingAssetRepository.findMany.mockResolvedValue(mockData);
      imagingAssetRepository.count.mockResolvedValue(1);

      const result = await imagingAssetService.listImagingAssets({}, 1, 20, null, 'asc', mockUserId, mockIpAddress);

      expect(result.imagingAssets).toEqual(mockData);
      expect(result.pagination).toMatchObject({
        page: 1,
        limit: 20,
        total: 1,
        totalPages: 1
      });
    });

    it('should apply filters correctly', async () => {
      imagingAssetRepository.findMany.mockResolvedValue([]);
      imagingAssetRepository.count.mockResolvedValue(0);

      await imagingAssetService.listImagingAssets({ content_type: 'application/dicom' }, 1, 20, null, 'asc', mockUserId, mockIpAddress);

      expect(imagingAssetRepository.findMany).toHaveBeenCalledWith(
        { content_type: { contains: 'application/dicom' } },
        0,
        20,
        { created_at: 'desc' },
      );
    });
  });

  describe('getImagingAssetById', () => {
    it('should return imaging asset when found', async () => {
      const mockData = { id: '123', storage_key: 'test.dcm' };
      imagingAssetRepository.findById.mockResolvedValue(mockData);

      const result = await imagingAssetService.getImagingAssetById('123', mockUserId, mockIpAddress);

      expect(result).toEqual(mockData);
    });

    it('should throw HttpError when not found', async () => {
      imagingAssetRepository.findById.mockResolvedValue(null);

      await expect(
        imagingAssetService.getImagingAssetById('123', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createImagingAsset', () => {
    it('should create imaging asset and audit log', async () => {
      const mockData = { imaging_study_id: '456', storage_key: 'test.dcm' };
      const mockCreated = { id: '123', ...mockData };
      imagingAssetRepository.create.mockResolvedValue(mockCreated);

      const result = await imagingAssetService.createImagingAsset(mockData, mockUserId, mockIpAddress);

      expect(result).toEqual(mockCreated);
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('updateImagingAsset', () => {
    it('should update imaging asset and audit log', async () => {
      const mockBefore = { id: '123', file_name: 'old.dcm' };
      const mockAfter = { id: '123', file_name: 'new.dcm' };
      imagingAssetRepository.findById.mockResolvedValue(mockBefore);
      imagingAssetRepository.update.mockResolvedValue(mockAfter);

      const result = await imagingAssetService.updateImagingAsset('123', { file_name: 'new.dcm' }, mockUserId, mockIpAddress);

      expect(result).toEqual(mockAfter);
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw HttpError when not found', async () => {
      imagingAssetRepository.findById.mockResolvedValue(null);

      await expect(
        imagingAssetService.updateImagingAsset('123', {}, mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deleteImagingAsset', () => {
    it('should delete imaging asset and audit log', async () => {
      const mockData = { id: '123', storage_key: 'test.dcm' };
      imagingAssetRepository.findById.mockResolvedValue(mockData);
      imagingAssetRepository.softDelete.mockResolvedValue(mockData);

      await imagingAssetService.deleteImagingAsset('123', mockUserId, mockIpAddress);

      expect(imagingAssetRepository.softDelete).toHaveBeenCalledWith('123');
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw HttpError when not found', async () => {
      imagingAssetRepository.findById.mockResolvedValue(null);

      await expect(
        imagingAssetService.deleteImagingAsset('123', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });
});
