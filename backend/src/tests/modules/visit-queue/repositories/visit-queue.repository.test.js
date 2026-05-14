/**
 * Visit queue repository tests
 *
 * @module tests/modules/visit-queue/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  visit_queue: {
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
} = require('@repositories/visit-queue/visit-queue.repository');

const prisma = require('@prisma/client');

describe('Visit Queue Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find visit queue entry by ID', async () => {
      const mockEntry = {
        id: 'queue-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        patient_id: 'patient-123',
        appointment_id: 'appointment-123',
        provider_user_id: 'user-123',
        status: 'SCHEDULED',
        queued_at: new Date('2026-01-19'),
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.visit_queue.findFirst.mockResolvedValue(mockEntry);

      const result = await findById('queue-123');

      expect(result).toEqual(mockEntry);
      expect(prisma.visit_queue.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'queue-123',
          deleted_at: null
        },
        include: {
          tenant: true,
          facility: true,
          patient: true,
          appointment: true,
          provider: true
        }
      });
    });

    it('should return null if visit queue entry not found', async () => {
      prisma.visit_queue.findFirst.mockResolvedValue(null);

      const result = await findById('queue-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.visit_queue.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('queue-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many visit queue entries with default pagination', async () => {
      const mockEntries = [
        {
          id: 'queue-1',
          tenant_id: 'tenant-123',
          patient_id: 'patient-123',
          status: 'SCHEDULED',
          queued_at: new Date('2026-01-19')
        },
        {
          id: 'queue-2',
          tenant_id: 'tenant-123',
          patient_id: 'patient-456',
          status: 'CONFIRMED',
          queued_at: new Date('2026-01-19')
        }
      ];
      prisma.visit_queue.findMany.mockResolvedValue(mockEntries);

      const result = await findMany({}, 0, 20, { queued_at: 'desc' });

      expect(result).toEqual(mockEntries);
      expect(prisma.visit_queue.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null
        },
        skip: 0,
        take: 20,
        orderBy: { queued_at: 'desc' },
        include: {
          tenant: true,
          facility: true,
          patient: true,
          appointment: true,
          provider: true
        }
      });
    });

    it('should find visit queue entries with filters', async () => {
      const mockEntries = [
        {
          id: 'queue-1',
          tenant_id: 'tenant-123',
          patient_id: 'patient-123',
          status: 'SCHEDULED'
        }
      ];
      prisma.visit_queue.findMany.mockResolvedValue(mockEntries);

      await findMany(
        { 
          tenant_id: 'tenant-123',
          patient_id: 'patient-123',
          status: 'SCHEDULED'
        },
        0,
        20,
        { queued_at: 'desc' }
      );

      expect(prisma.visit_queue.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: 'tenant-123',
          patient_id: 'patient-123',
          status: 'SCHEDULED'
        },
        skip: 0,
        take: 20,
        orderBy: { queued_at: 'desc' },
        include: {
          tenant: true,
          facility: true,
          patient: true,
          appointment: true,
          provider: true
        }
      });
    });

    it('should apply pagination correctly', async () => {
      prisma.visit_queue.findMany.mockResolvedValue([]);

      await findMany({}, 40, 20, { queued_at: 'asc' });

      expect(prisma.visit_queue.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          skip: 40,
          take: 20,
          orderBy: { queued_at: 'asc' }
        })
      );
    });

    it('should throw HttpError on database error', async () => {
      prisma.visit_queue.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany({}, 0, 20))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count visit queue entries without filters', async () => {
      prisma.visit_queue.count.mockResolvedValue(10);

      const result = await count({});

      expect(result).toBe(10);
      expect(prisma.visit_queue.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null
        }
      });
    });

    it('should count visit queue entries with filters', async () => {
      prisma.visit_queue.count.mockResolvedValue(5);

      await count({ 
        tenant_id: 'tenant-123',
        status: 'SCHEDULED'
      });

      expect(prisma.visit_queue.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: 'tenant-123',
          status: 'SCHEDULED'
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.visit_queue.count.mockRejectedValue(new Error('DB error'));

      await expect(count({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create visit queue entry', async () => {
      const entryData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        patient_id: 'patient-123',
        appointment_id: 'appointment-123',
        provider_user_id: 'user-123',
        status: 'SCHEDULED',
        queued_at: new Date('2026-01-19')
      };
      const mockCreated = {
        id: 'queue-123',
        ...entryData,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.visit_queue.create.mockResolvedValue(mockCreated);

      const result = await create(entryData);

      expect(result).toEqual(mockCreated);
      expect(prisma.visit_queue.create).toHaveBeenCalledWith({
        data: entryData,
        include: {
          tenant: true,
          facility: true,
          patient: true,
          appointment: true,
          provider: true
        }
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['tenant_id', 'patient_id'] };
      prisma.visit_queue.create.mockRejectedValue(error);

      await expect(create({ tenant_id: 'tenant-123', patient_id: 'patient-123', status: 'SCHEDULED' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'patient_id' };
      prisma.visit_queue.create.mockRejectedValue(error);

      await expect(create({ tenant_id: 'tenant-123', patient_id: 'invalid-id', status: 'SCHEDULED' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on general database error', async () => {
      prisma.visit_queue.create.mockRejectedValue(new Error('DB error'));

      await expect(create({ tenant_id: 'tenant-123', patient_id: 'patient-123', status: 'SCHEDULED' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update visit queue entry', async () => {
      const updateData = { status: 'IN_PROGRESS' };
      const mockUpdated = {
        id: 'queue-123',
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        status: 'IN_PROGRESS',
        updated_at: new Date('2026-01-19')
      };
      prisma.visit_queue.update.mockResolvedValue(mockUpdated);

      const result = await update('queue-123', updateData);

      expect(result).toEqual(mockUpdated);
      expect(prisma.visit_queue.update).toHaveBeenCalledWith({
        where: { id: 'queue-123' },
        data: updateData,
        include: {
          tenant: true,
          facility: true,
          patient: true,
          appointment: true,
          provider: true
        }
      });
    });

    it('should throw HttpError if entry not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.visit_queue.update.mockRejectedValue(error);

      await expect(update('queue-123', { status: 'COMPLETED' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['field'] };
      prisma.visit_queue.update.mockRejectedValue(error);

      await expect(update('queue-123', { status: 'SCHEDULED' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'provider_user_id' };
      prisma.visit_queue.update.mockRejectedValue(error);

      await expect(update('queue-123', { provider_user_id: 'invalid-id' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on general database error', async () => {
      prisma.visit_queue.update.mockRejectedValue(new Error('DB error'));

      await expect(update('queue-123', { status: 'COMPLETED' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete visit queue entry', async () => {
      const mockDeleted = {
        id: 'queue-123',
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        deleted_at: new Date('2026-01-19')
      };
      prisma.visit_queue.update.mockResolvedValue(mockDeleted);

      const result = await softDelete('queue-123');

      expect(result).toEqual(mockDeleted);
      expect(prisma.visit_queue.update).toHaveBeenCalledWith({
        where: { id: 'queue-123' },
        data: {
          deleted_at: expect.any(Date)
        }
      });
    });

    it('should throw HttpError if entry not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.visit_queue.update.mockRejectedValue(error);

      await expect(softDelete('queue-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on general database error', async () => {
      prisma.visit_queue.update.mockRejectedValue(new Error('DB error'));

      await expect(softDelete('queue-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
