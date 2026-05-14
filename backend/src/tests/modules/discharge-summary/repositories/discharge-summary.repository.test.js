/**
 * Discharge summary repository tests
 *
 * @module tests/modules/discharge-summary/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  discharge_summary: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

const {
  findById,
  findMany,
  count,
  create,
  update,
  softDelete
} = require('@repositories/discharge-summary/discharge-summary.repository');

const prisma = require('@prisma/client');

describe('Discharge Summary Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find discharge summary by ID', async () => {
      const mockRecord = {
        id: 'discharge-123',
        admission_id: 'admission-123',
        summary: 'Discharge summary content',
        status: 'COMPLETED',
        deleted_at: null
      };
      prisma.discharge_summary.findFirst.mockResolvedValue(mockRecord);

      const result = await findById('discharge-123');

      expect(result).toEqual(mockRecord);
      expect(prisma.discharge_summary.findFirst).toHaveBeenCalledWith({
        where: { id: 'discharge-123', deleted_at: null },
        include: {}
      });
    });

    it('should return null if not found', async () => {
      prisma.discharge_summary.findFirst.mockResolvedValue(null);
      const result = await findById('discharge-123');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.discharge_summary.findFirst.mockRejectedValue(new Error('DB error'));
      await expect(findById('discharge-123')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many with pagination', async () => {
      const mockRecords = [
        { id: 'discharge-1', summary: 'Summary 1' },
        { id: 'discharge-2', summary: 'Summary 2' }
      ];
      prisma.discharge_summary.findMany.mockResolvedValue(mockRecords);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockRecords);
      expect(prisma.discharge_summary.findMany).toHaveBeenCalled();
    });

    it('should apply filters correctly', async () => {
      prisma.discharge_summary.findMany.mockResolvedValue([]);

      await findMany({ status: 'COMPLETED' }, 0, 20);

      expect(prisma.discharge_summary.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ status: 'COMPLETED', deleted_at: null })
        })
      );
    });
  });

  describe('count', () => {
    it('should count records', async () => {
      prisma.discharge_summary.count.mockResolvedValue(10);
      const result = await count({});
      expect(result).toBe(10);
    });
  });

  describe('create', () => {
    it('should create record', async () => {
      const mockData = { admission_id: 'admission-123', summary: 'Summary', status: 'COMPLETED' };
      const mockRecord = { id: 'discharge-123', ...mockData };
      prisma.discharge_summary.create.mockResolvedValue(mockRecord);

      const result = await create(mockData);

      expect(result).toEqual(mockRecord);
    });

    it('should throw HttpError on FK violation', async () => {
      const error = new Error('FK violation');
      error.code = 'P2003';
      error.meta = { field_name: 'admission_id' };
      prisma.discharge_summary.create.mockRejectedValue(error);

      await expect(create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update record', async () => {
      const mockRecord = { id: 'discharge-123', summary: 'Updated summary' };
      prisma.discharge_summary.update.mockResolvedValue(mockRecord);

      const result = await update('discharge-123', { summary: 'Updated summary' });

      expect(result).toEqual(mockRecord);
    });

    it('should throw HttpError if not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.discharge_summary.update.mockRejectedValue(error);

      await expect(update('discharge-123', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete record', async () => {
      const mockRecord = { id: 'discharge-123', deleted_at: new Date() };
      prisma.discharge_summary.update.mockResolvedValue(mockRecord);

      const result = await softDelete('discharge-123');

      expect(result).toEqual(mockRecord);
      expect(prisma.discharge_summary.update).toHaveBeenCalledWith({
        where: { id: 'discharge-123' },
        data: { deleted_at: expect.any(Date) }
      });
    });
  });
});
