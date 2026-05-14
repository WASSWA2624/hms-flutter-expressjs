/**
 * Imaging study repository tests
 *
 * @module tests/modules/imaging-study/repositories
 * @description Tests for imaging study repository operations
 * Per testing.mdc: Repository tests must mock Prisma client
 */

const imagingStudyRepository = require('@repositories/imaging-study/imaging-study.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  imaging_study: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Imaging Study Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find imaging study by id', async () => {
      const mockImagingStudy = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        radiology_order_id: '456e7890-e89b-12d3-a456-426614174000',
        modality: 'XRAY',
        performed_at: new Date('2024-01-15T10:30:00.000Z')
      };
      prisma.imaging_study.findFirst.mockResolvedValue(mockImagingStudy);

      const result = await imagingStudyRepository.findById('123e4567-e89b-12d3-a456-426614174000');
      expect(result).toEqual(mockImagingStudy);
      expect(prisma.imaging_study.findFirst).toHaveBeenCalledWith({
        where: { id: '123e4567-e89b-12d3-a456-426614174000', deleted_at: null },
        include: {}
      });
    });

    it('should return null if imaging study not found', async () => {
      prisma.imaging_study.findFirst.mockResolvedValue(null);

      const result = await imagingStudyRepository.findById('nonexistent');
      expect(result).toBeNull();
    });

    it('should include relations when specified', async () => {
      const mockImagingStudy = { id: '123', modality: 'CT' };
      prisma.imaging_study.findFirst.mockResolvedValue(mockImagingStudy);

      const include = { assets: true };
      await imagingStudyRepository.findById('123', include);

      expect(prisma.imaging_study.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.imaging_study.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(imagingStudyRepository.findById('123')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many imaging studies with pagination', async () => {
      const mockImagingStudies = [
        { id: '1', modality: 'XRAY' },
        { id: '2', modality: 'CT' }
      ];
      prisma.imaging_study.findMany.mockResolvedValue(mockImagingStudies);

      const result = await imagingStudyRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockImagingStudies);
      expect(prisma.imaging_study.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply filters when provided', async () => {
      const filters = { modality: 'XRAY' };
      prisma.imaging_study.findMany.mockResolvedValue([]);

      await imagingStudyRepository.findMany(filters);

      expect(prisma.imaging_study.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { deleted_at: null, modality: 'XRAY' }
        })
      );
    });

    it('should apply custom orderBy when provided', async () => {
      prisma.imaging_study.findMany.mockResolvedValue([]);

      await imagingStudyRepository.findMany({}, 0, 20, { modality: 'asc' });

      expect(prisma.imaging_study.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          orderBy: { modality: 'asc' }
        })
      );
    });

    it('should include relations when specified', async () => {
      prisma.imaging_study.findMany.mockResolvedValue([]);

      await imagingStudyRepository.findMany({}, 0, 20, {}, { assets: true });

      expect(prisma.imaging_study.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          include: { assets: true }
        })
      );
    });

    it('should throw HttpError on database error', async () => {
      prisma.imaging_study.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(imagingStudyRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count imaging studies', async () => {
      prisma.imaging_study.count.mockResolvedValue(42);

      const result = await imagingStudyRepository.count({});
      expect(result).toBe(42);
      expect(prisma.imaging_study.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should apply filters when counting', async () => {
      const filters = { modality: 'MRI' };
      prisma.imaging_study.count.mockResolvedValue(10);

      await imagingStudyRepository.count(filters);

      expect(prisma.imaging_study.count).toHaveBeenCalledWith({
        where: { deleted_at: null, modality: 'MRI' }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.imaging_study.count.mockRejectedValue(new Error('DB Error'));

      await expect(imagingStudyRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create imaging study', async () => {
      const mockData = {
        radiology_order_id: '456e7890-e89b-12d3-a456-426614174000',
        modality: 'XRAY'
      };
      const mockImagingStudy = { id: '123', ...mockData };
      prisma.imaging_study.create.mockResolvedValue(mockImagingStudy);

      const result = await imagingStudyRepository.create(mockData);
      expect(result).toEqual(mockImagingStudy);
      expect(prisma.imaging_study.create).toHaveBeenCalledWith({
        data: mockData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['field'] };
      prisma.imaging_study.create.mockRejectedValue(error);

      await expect(imagingStudyRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'radiology_order_id' };
      prisma.imaging_study.create.mockRejectedValue(error);

      await expect(imagingStudyRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.imaging_study.create.mockRejectedValue(new Error('DB Error'));

      await expect(imagingStudyRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update imaging study', async () => {
      const mockData = { modality: 'CT' };
      const mockUpdated = { id: '123', ...mockData };
      prisma.imaging_study.update.mockResolvedValue(mockUpdated);

      const result = await imagingStudyRepository.update('123', mockData);
      expect(result).toEqual(mockUpdated);
      expect(prisma.imaging_study.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: mockData
      });
    });

    it('should throw HttpError when imaging study not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.imaging_study.update.mockRejectedValue(error);

      await expect(imagingStudyRepository.update('nonexistent', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['field'] };
      prisma.imaging_study.update.mockRejectedValue(error);

      await expect(imagingStudyRepository.update('123', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'radiology_order_id' };
      prisma.imaging_study.update.mockRejectedValue(error);

      await expect(imagingStudyRepository.update('123', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.imaging_study.update.mockRejectedValue(new Error('DB Error'));

      await expect(imagingStudyRepository.update('123', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete imaging study', async () => {
      const mockDeleted = { id: '123', deleted_at: new Date() };
      prisma.imaging_study.update.mockResolvedValue(mockDeleted);

      const result = await imagingStudyRepository.softDelete('123');
      expect(result).toEqual(mockDeleted);
      expect(prisma.imaging_study.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError when imaging study not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.imaging_study.update.mockRejectedValue(error);

      await expect(imagingStudyRepository.softDelete('nonexistent')).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.imaging_study.update.mockRejectedValue(new Error('DB Error'));

      await expect(imagingStudyRepository.softDelete('123')).rejects.toThrow(HttpError);
    });
  });
});
