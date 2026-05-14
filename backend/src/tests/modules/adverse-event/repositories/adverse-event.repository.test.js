/**
 * Adverse Event repository tests
 *
 * @module tests/modules/adverse-event/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  adverse_event: {
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
} = require('@repositories/adverse-event/adverse-event.repository');

const prisma = require('@prisma/client');

describe('Adverse Event Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find adverse event by ID', async () => {
      const mockAdverseEvent = {
        id: 'event-123',
        patient_id: 'patient-123',
        drug_id: 'drug-123',
        severity: 'MODERATE',
        description: 'Test description',
        reported_at: new Date('2026-01-19'),
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.adverse_event.findFirst.mockResolvedValue(mockAdverseEvent);

      const result = await findById('event-123');

      expect(result).toEqual(mockAdverseEvent);
      expect(prisma.adverse_event.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'event-123',
          deleted_at: null
        },
        include: {}
      });
    });

    it('should return null if adverse event not found', async () => {
      prisma.adverse_event.findFirst.mockResolvedValue(null);

      const result = await findById('event-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.adverse_event.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('event-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many adverse events with default pagination', async () => {
      const mockAdverseEvents = [
        {
          id: 'event-1',
          patient_id: 'patient-123',
          severity: 'MILD'
        },
        {
          id: 'event-2',
          patient_id: 'patient-123',
          severity: 'SEVERE'
        }
      ];
      prisma.adverse_event.findMany.mockResolvedValue(mockAdverseEvents);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockAdverseEvents);
      expect(prisma.adverse_event.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply filters correctly', async () => {
      prisma.adverse_event.findMany.mockResolvedValue([]);

      await findMany({ severity: 'SEVERE' }, 0, 20);

      expect(prisma.adverse_event.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          severity: 'SEVERE'
        },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.adverse_event.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany({}, 0, 20))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count adverse events', async () => {
      prisma.adverse_event.count.mockResolvedValue(42);

      const result = await count({});

      expect(result).toBe(42);
      expect(prisma.adverse_event.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count with filters', async () => {
      prisma.adverse_event.count.mockResolvedValue(10);

      const result = await count({ severity: 'MODERATE' });

      expect(result).toBe(10);
      expect(prisma.adverse_event.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          severity: 'MODERATE'
        }
      });
    });
  });

  describe('create', () => {
    it('should create new adverse event', async () => {
      const newAdverseEvent = {
        patient_id: 'patient-123',
        severity: 'MODERATE',
        description: 'Test description'
      };
      const mockCreatedAdverseEvent = {
        id: 'event-123',
        ...newAdverseEvent,
        drug_id: null,
        reported_at: new Date('2026-01-19'),
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };

      prisma.adverse_event.create.mockResolvedValue(mockCreatedAdverseEvent);

      const result = await create(newAdverseEvent);

      expect(result).toEqual(mockCreatedAdverseEvent);
      expect(prisma.adverse_event.create).toHaveBeenCalledWith({
        data: newAdverseEvent
      });
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = {
        code: 'P2003',
        meta: { field_name: 'patient_id' }
      };
      prisma.adverse_event.create.mockRejectedValue(error);

      await expect(create({ patient_id: 'invalid-id', severity: 'MILD' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update adverse event', async () => {
      const updateData = { severity: 'SEVERE', description: 'Updated' };
      const mockUpdatedAdverseEvent = {
        id: 'event-123',
        patient_id: 'patient-123',
        severity: 'SEVERE',
        description: 'Updated',
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 2
      };

      prisma.adverse_event.update.mockResolvedValue(mockUpdatedAdverseEvent);

      const result = await update('event-123', updateData);

      expect(result).toEqual(mockUpdatedAdverseEvent);
      expect(prisma.adverse_event.update).toHaveBeenCalledWith({
        where: { id: 'event-123' },
        data: updateData
      });
    });

    it('should throw HttpError if adverse event not found', async () => {
      const error = { code: 'P2025' };
      prisma.adverse_event.update.mockRejectedValue(error);

      await expect(update('event-123', { severity: 'SEVERE' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete adverse event', async () => {
      const mockDeletedAdverseEvent = {
        id: 'event-123',
        patient_id: 'patient-123',
        severity: 'MODERATE',
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: new Date('2026-01-19'),
        version: 1
      };

      prisma.adverse_event.update.mockResolvedValue(mockDeletedAdverseEvent);

      const result = await softDelete('event-123');

      expect(result).toEqual(mockDeletedAdverseEvent);
      expect(prisma.adverse_event.update).toHaveBeenCalledWith({
        where: { id: 'event-123' },
        data: {
          deleted_at: expect.any(Date)
        }
      });
    });

    it('should throw HttpError if adverse event not found', async () => {
      const error = { code: 'P2025' };
      prisma.adverse_event.update.mockRejectedValue(error);

      await expect(softDelete('event-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
