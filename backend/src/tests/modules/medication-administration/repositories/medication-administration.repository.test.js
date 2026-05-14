/**
 * Medication administration repository tests
 *
 * @module tests/modules/medication-administration/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  medication_administration: {
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
} = require('@repositories/medication-administration/medication-administration.repository');

const prisma = require('@prisma/client');

describe('Medication Administration Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find medication administration by ID', async () => {
      const mockRecord = {
        id: 'med-123',
        admission_id: 'admission-123',
        dose: '500mg',
        route: 'ORAL',
        deleted_at: null
      };
      prisma.medication_administration.findFirst.mockResolvedValue(mockRecord);

      const result = await findById('med-123');

      expect(result).toEqual(mockRecord);
      expect(prisma.medication_administration.findFirst).toHaveBeenCalledWith({
        where: { id: 'med-123', deleted_at: null },
        include: {}
      });
    });

    it('should return null if not found', async () => {
      prisma.medication_administration.findFirst.mockResolvedValue(null);
      const result = await findById('med-123');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.medication_administration.findFirst.mockRejectedValue(new Error('DB error'));
      await expect(findById('med-123')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many with pagination', async () => {
      const mockRecords = [
        { id: 'med-1', dose: '500mg' },
        { id: 'med-2', dose: '1000mg' }
      ];
      prisma.medication_administration.findMany.mockResolvedValue(mockRecords);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockRecords);
      expect(prisma.medication_administration.findMany).toHaveBeenCalled();
    });

    it('should apply filters correctly', async () => {
      prisma.medication_administration.findMany.mockResolvedValue([]);

      await findMany({ route: 'IV' }, 0, 20);

      expect(prisma.medication_administration.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ route: 'IV', deleted_at: null })
        })
      );
    });
  });

  describe('count', () => {
    it('should count records', async () => {
      prisma.medication_administration.count.mockResolvedValue(10);
      const result = await count({});
      expect(result).toBe(10);
    });
  });

  describe('create', () => {
    it('should create record', async () => {
      const mockData = { admission_id: 'admission-123', dose: '500mg', route: 'ORAL' };
      const mockRecord = { id: 'med-123', ...mockData };
      prisma.medication_administration.create.mockResolvedValue(mockRecord);

      const result = await create(mockData);

      expect(result).toEqual(mockRecord);
    });

    it('should throw HttpError on FK violation', async () => {
      const error = new Error('FK violation');
      error.code = 'P2003';
      error.meta = { field_name: 'admission_id' };
      prisma.medication_administration.create.mockRejectedValue(error);

      await expect(create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update record', async () => {
      const mockRecord = { id: 'med-123', dose: '1000mg' };
      prisma.medication_administration.update.mockResolvedValue(mockRecord);

      const result = await update('med-123', { dose: '1000mg' });

      expect(result).toEqual(mockRecord);
    });

    it('should throw HttpError if not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.medication_administration.update.mockRejectedValue(error);

      await expect(update('med-123', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete record', async () => {
      const mockRecord = { id: 'med-123', deleted_at: new Date() };
      prisma.medication_administration.update.mockResolvedValue(mockRecord);

      const result = await softDelete('med-123');

      expect(result).toEqual(mockRecord);
      expect(prisma.medication_administration.update).toHaveBeenCalledWith({
        where: { id: 'med-123' },
        data: { deleted_at: expect.any(Date) }
      });
    });
  });
});
