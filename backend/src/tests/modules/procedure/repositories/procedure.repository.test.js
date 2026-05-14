/**
 * Procedure repository tests
 *
 * @module tests/modules/procedure/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  procedure: {
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
} = require('@repositories/procedure/procedure.repository');

const prisma = require('@prisma/client');

describe('Procedure Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find procedure by ID', async () => {
      const mockProcedure = {
        id: 'proc-123',
        encounter_id: 'encounter-123',
        code: '47562',
        description: 'Laparoscopic cholecystectomy',
        performed_at: new Date(),
        deleted_at: null
      };
      prisma.procedure.findFirst.mockResolvedValue(mockProcedure);

      const result = await findById('proc-123');

      expect(result).toEqual(mockProcedure);
      expect(prisma.procedure.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'proc-123',
          deleted_at: null
        },
        include: {}
      });
    });

    it('should return null if procedure not found', async () => {
      prisma.procedure.findFirst.mockResolvedValue(null);

      const result = await findById('proc-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.procedure.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('proc-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many procedures with pagination', async () => {
      const mockProcedures = [
        { id: 'proc-1', code: '47562', description: 'Procedure 1' },
        { id: 'proc-2', code: '47563', description: 'Procedure 2' }
      ];
      prisma.procedure.findMany.mockResolvedValue(mockProcedures);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockProcedures);
      expect(prisma.procedure.findMany).toHaveBeenCalled();
    });
  });

  describe('count', () => {
    it('should count procedures', async () => {
      prisma.procedure.count.mockResolvedValue(8);

      const result = await count({});

      expect(result).toBe(8);
    });
  });

  describe('create', () => {
    it('should create procedure', async () => {
      const mockProcedure = {
        id: 'proc-123',
        encounter_id: 'encounter-123',
        code: '47562',
        description: 'Laparoscopic cholecystectomy',
        performed_at: new Date()
      };
      prisma.procedure.create.mockResolvedValue(mockProcedure);

      const result = await create(mockProcedure);

      expect(result).toEqual(mockProcedure);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('FK violation');
      error.code = 'P2003';
      error.meta = { field_name: 'encounter_id' };
      prisma.procedure.create.mockRejectedValue(error);

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update procedure', async () => {
      const mockProcedure = {
        id: 'proc-123',
        description: 'Updated procedure'
      };
      prisma.procedure.update.mockResolvedValue(mockProcedure);

      const result = await update('proc-123', { description: 'Updated procedure' });

      expect(result).toEqual(mockProcedure);
    });

    it('should throw HttpError if procedure not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.procedure.update.mockRejectedValue(error);

      await expect(update('proc-123', {}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete procedure', async () => {
      const mockProcedure = {
        id: 'proc-123',
        deleted_at: new Date()
      };
      prisma.procedure.update.mockResolvedValue(mockProcedure);

      const result = await softDelete('proc-123');

      expect(result).toEqual(mockProcedure);
      expect(prisma.procedure.update).toHaveBeenCalledWith({
        where: { id: 'proc-123' },
        data: { deleted_at: expect.any(Date) }
      });
    });
  });
});
