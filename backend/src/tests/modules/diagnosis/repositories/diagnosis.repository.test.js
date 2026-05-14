/**
 * Diagnosis repository tests
 *
 * @module tests/modules/diagnosis/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  diagnosis: {
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
} = require('@repositories/diagnosis/diagnosis.repository');

const prisma = require('@prisma/client');

describe('Diagnosis Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find diagnosis by ID', async () => {
      const mockDiagnosis = {
        id: 'diag-123',
        encounter_id: 'encounter-123',
        diagnosis_type: 'PRIMARY',
        code: 'J00',
        description: 'Common cold',
        deleted_at: null
      };
      prisma.diagnosis.findFirst.mockResolvedValue(mockDiagnosis);

      const result = await findById('diag-123');

      expect(result).toEqual(mockDiagnosis);
      expect(prisma.diagnosis.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'diag-123',
          deleted_at: null
        },
        include: {}
      });
    });

    it('should return null if diagnosis not found', async () => {
      prisma.diagnosis.findFirst.mockResolvedValue(null);

      const result = await findById('diag-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.diagnosis.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('diag-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many diagnoses with pagination', async () => {
      const mockDiagnoses = [
        { id: 'diag-1', diagnosis_type: 'PRIMARY', description: 'Diagnosis 1' },
        { id: 'diag-2', diagnosis_type: 'SECONDARY', description: 'Diagnosis 2' }
      ];
      prisma.diagnosis.findMany.mockResolvedValue(mockDiagnoses);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockDiagnoses);
      expect(prisma.diagnosis.findMany).toHaveBeenCalled();
    });
  });

  describe('count', () => {
    it('should count diagnoses', async () => {
      prisma.diagnosis.count.mockResolvedValue(15);

      const result = await count({});

      expect(result).toBe(15);
    });
  });

  describe('create', () => {
    it('should create diagnosis', async () => {
      const mockDiagnosis = {
        id: 'diag-123',
        encounter_id: 'encounter-123',
        diagnosis_type: 'PRIMARY',
        code: 'J00',
        description: 'Common cold'
      };
      prisma.diagnosis.create.mockResolvedValue(mockDiagnosis);

      const result = await create(mockDiagnosis);

      expect(result).toEqual(mockDiagnosis);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('FK violation');
      error.code = 'P2003';
      error.meta = { field_name: 'encounter_id' };
      prisma.diagnosis.create.mockRejectedValue(error);

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update diagnosis', async () => {
      const mockDiagnosis = {
        id: 'diag-123',
        description: 'Updated diagnosis'
      };
      prisma.diagnosis.update.mockResolvedValue(mockDiagnosis);

      const result = await update('diag-123', { description: 'Updated diagnosis' });

      expect(result).toEqual(mockDiagnosis);
    });

    it('should throw HttpError if diagnosis not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.diagnosis.update.mockRejectedValue(error);

      await expect(update('diag-123', {}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete diagnosis', async () => {
      const mockDiagnosis = {
        id: 'diag-123',
        deleted_at: new Date()
      };
      prisma.diagnosis.update.mockResolvedValue(mockDiagnosis);

      const result = await softDelete('diag-123');

      expect(result).toEqual(mockDiagnosis);
      expect(prisma.diagnosis.update).toHaveBeenCalledWith({
        where: { id: 'diag-123' },
        data: { deleted_at: expect.any(Date) }
      });
    });
  });
});
