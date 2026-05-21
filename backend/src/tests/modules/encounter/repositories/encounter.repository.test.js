/**
 * Encounter repository tests
 *
 * @module tests/modules/encounter/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  encounter: {
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
} = require('@repositories/encounter/encounter.repository');

const prisma = require('@prisma/client');

describe('Encounter Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find encounter by ID', async () => {
      const mockEncounter = {
        id: 'enc-123',
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        encounter_type: 'OPD',
        status: 'OPEN',
        started_at: new Date(),
        deleted_at: null
      };
      prisma.encounter.findFirst.mockResolvedValue(mockEncounter);

      const result = await findById('enc-123');

      expect(result).toEqual(mockEncounter);
      expect(prisma.encounter.findFirst).toHaveBeenCalledWith({
        where: expect.objectContaining({
          id: 'enc-123',
          deleted_at: null,
          AND: [{ patient: { deleted_at: null } }]
        }),
        include: {}
      });
    });

    it('should return null if encounter not found', async () => {
      prisma.encounter.findFirst.mockResolvedValue(null);

      const result = await findById('enc-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.encounter.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('enc-123')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many encounters with pagination', async () => {
      const mockEncounters = [
        { id: 'enc-1', encounter_type: 'OPD', status: 'OPEN' },
        { id: 'enc-2', encounter_type: 'IPD', status: 'OPEN' }
      ];
      prisma.encounter.findMany.mockResolvedValue(mockEncounters);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockEncounters);
      expect(prisma.encounter.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            deleted_at: null,
            AND: [{ patient: { deleted_at: null } }]
          })
        })
      );
    });
  });

  describe('count', () => {
    it('should count encounters', async () => {
      prisma.encounter.count.mockResolvedValue(5);

      const result = await count({});

      expect(result).toBe(5);
      expect(prisma.encounter.count).toHaveBeenCalledWith({
        where: expect.objectContaining({
          deleted_at: null,
          AND: [{ patient: { deleted_at: null } }]
        })
      });
    });
  });

  describe('create', () => {
    it('should create encounter', async () => {
      const mockEncounter = {
        id: 'enc-123',
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        encounter_type: 'OPD',
        status: 'OPEN',
        started_at: new Date()
      };
      prisma.encounter.create.mockResolvedValue(mockEncounter);

      const result = await create(mockEncounter);

      expect(result).toEqual(mockEncounter);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('FK violation');
      error.code = 'P2003';
      error.meta = { field_name: 'patient_id' };
      prisma.encounter.create.mockRejectedValue(error);

      await expect(create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update encounter', async () => {
      const mockEncounter = {
        id: 'enc-123',
        status: 'CLOSED'
      };
      prisma.encounter.update.mockResolvedValue(mockEncounter);

      const result = await update('enc-123', { status: 'CLOSED' });

      expect(result).toEqual(mockEncounter);
    });

    it('should throw HttpError if encounter not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.encounter.update.mockRejectedValue(error);

      await expect(update('enc-123', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete encounter', async () => {
      const mockEncounter = {
        id: 'enc-123',
        deleted_at: new Date()
      };
      prisma.encounter.update.mockResolvedValue(mockEncounter);

      const result = await softDelete('enc-123');

      expect(result).toEqual(mockEncounter);
      expect(prisma.encounter.update).toHaveBeenCalledWith({
        where: { id: 'enc-123' },
        data: {
          active_opd_lock_key: null,
          deleted_at: expect.any(Date)
        }
      });
    });
  });
});
