/**
 * Imaging asset repository tests
 *
 * @module tests/modules/imaging-asset/repositories
 * @description Tests for imaging asset repository operations
 * Per testing.mdc: Repository tests must mock Prisma client
 */

const imagingAssetRepository = require('@repositories/imaging-asset/imaging-asset.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  imaging_asset: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Imaging Asset Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find imaging asset by id', async () => {
      const mockImagingAsset = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        imaging_study_id: '456e7890-e89b-12d3-a456-426614174000',
        storage_key: 'imaging/xray.dcm',
        file_name: 'chest-xray.dcm',
        content_type: 'application/dicom'
      };
      prisma.imaging_asset.findFirst.mockResolvedValue(mockImagingAsset);

      const result = await imagingAssetRepository.findById('123e4567-e89b-12d3-a456-426614174000');
      expect(result).toEqual(mockImagingAsset);
      expect(prisma.imaging_asset.findFirst).toHaveBeenCalledWith({
        where: { id: '123e4567-e89b-12d3-a456-426614174000', deleted_at: null },
        include: {}
      });
    });

    it('should return null if imaging asset not found', async () => {
      prisma.imaging_asset.findFirst.mockResolvedValue(null);

      const result = await imagingAssetRepository.findById('nonexistent');
      expect(result).toBeNull();
    });

    it('should include relations when specified', async () => {
      const mockImagingAsset = { id: '123', storage_key: 'test.dcm' };
      prisma.imaging_asset.findFirst.mockResolvedValue(mockImagingAsset);

      const include = { imaging_study: true };
      await imagingAssetRepository.findById('123', include);

      expect(prisma.imaging_asset.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.imaging_asset.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(imagingAssetRepository.findById('123')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many imaging assets with pagination', async () => {
      const mockImagingAssets = [
        { id: '1', storage_key: 'image1.dcm' },
        { id: '2', storage_key: 'image2.dcm' }
      ];
      prisma.imaging_asset.findMany.mockResolvedValue(mockImagingAssets);

      const result = await imagingAssetRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockImagingAssets);
      expect(prisma.imaging_asset.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply filters when provided', async () => {
      const filters = { content_type: 'application/dicom' };
      prisma.imaging_asset.findMany.mockResolvedValue([]);

      await imagingAssetRepository.findMany(filters);

      expect(prisma.imaging_asset.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { deleted_at: null, content_type: 'application/dicom' }
        })
      );
    });

    it('should apply custom orderBy when provided', async () => {
      prisma.imaging_asset.findMany.mockResolvedValue([]);

      await imagingAssetRepository.findMany({}, 0, 20, { file_name: 'asc' });

      expect(prisma.imaging_asset.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          orderBy: { file_name: 'asc' }
        })
      );
    });

    it('should include relations when specified', async () => {
      prisma.imaging_asset.findMany.mockResolvedValue([]);

      await imagingAssetRepository.findMany({}, 0, 20, {}, { imaging_study: true });

      expect(prisma.imaging_asset.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          include: { imaging_study: true }
        })
      );
    });

    it('should throw HttpError on database error', async () => {
      prisma.imaging_asset.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(imagingAssetRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count imaging assets', async () => {
      prisma.imaging_asset.count.mockResolvedValue(42);

      const result = await imagingAssetRepository.count({});
      expect(result).toBe(42);
      expect(prisma.imaging_asset.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should apply filters when counting', async () => {
      const filters = { imaging_study_id: '123' };
      prisma.imaging_asset.count.mockResolvedValue(10);

      await imagingAssetRepository.count(filters);

      expect(prisma.imaging_asset.count).toHaveBeenCalledWith({
        where: { deleted_at: null, imaging_study_id: '123' }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.imaging_asset.count.mockRejectedValue(new Error('DB Error'));

      await expect(imagingAssetRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create imaging asset', async () => {
      const mockData = {
        imaging_study_id: '456e7890-e89b-12d3-a456-426614174000',
        storage_key: 'imaging/xray.dcm'
      };
      const mockImagingAsset = { id: '123', ...mockData };
      prisma.imaging_asset.create.mockResolvedValue(mockImagingAsset);

      const result = await imagingAssetRepository.create(mockData);
      expect(result).toEqual(mockImagingAsset);
      expect(prisma.imaging_asset.create).toHaveBeenCalledWith({
        data: mockData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['field'] };
      prisma.imaging_asset.create.mockRejectedValue(error);

      await expect(imagingAssetRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'imaging_study_id' };
      prisma.imaging_asset.create.mockRejectedValue(error);

      await expect(imagingAssetRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.imaging_asset.create.mockRejectedValue(new Error('DB Error'));

      await expect(imagingAssetRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update imaging asset', async () => {
      const mockData = { file_name: 'updated.dcm' };
      const mockUpdated = { id: '123', ...mockData };
      prisma.imaging_asset.update.mockResolvedValue(mockUpdated);

      const result = await imagingAssetRepository.update('123', mockData);
      expect(result).toEqual(mockUpdated);
      expect(prisma.imaging_asset.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: mockData
      });
    });

    it('should throw HttpError when imaging asset not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.imaging_asset.update.mockRejectedValue(error);

      await expect(imagingAssetRepository.update('nonexistent', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['field'] };
      prisma.imaging_asset.update.mockRejectedValue(error);

      await expect(imagingAssetRepository.update('123', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'imaging_study_id' };
      prisma.imaging_asset.update.mockRejectedValue(error);

      await expect(imagingAssetRepository.update('123', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.imaging_asset.update.mockRejectedValue(new Error('DB Error'));

      await expect(imagingAssetRepository.update('123', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete imaging asset', async () => {
      const mockDeleted = { id: '123', deleted_at: new Date() };
      prisma.imaging_asset.update.mockResolvedValue(mockDeleted);

      const result = await imagingAssetRepository.softDelete('123');
      expect(result).toEqual(mockDeleted);
      expect(prisma.imaging_asset.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError when imaging asset not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.imaging_asset.update.mockRejectedValue(error);

      await expect(imagingAssetRepository.softDelete('nonexistent')).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.imaging_asset.update.mockRejectedValue(new Error('DB Error'));

      await expect(imagingAssetRepository.softDelete('123')).rejects.toThrow(HttpError);
    });
  });
});
