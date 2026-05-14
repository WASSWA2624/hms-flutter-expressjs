/**
 * Availability slot repository tests
 *
 * @module tests/modules/availability-slot/repositories
 * @description Tests for availability slot repository
 * Per testing.mdc: Mock all Prisma calls, test error handling
 */

const availabilitySlotRepository = require('@repositories/availability-slot/availability-slot.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  availability_slot: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Availability Slot Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    const slotId = '550e8400-e29b-41d4-a716-446655440000';
    const mockSlot = {
      id: slotId,
      schedule_id: '550e8400-e29b-41d4-a716-446655440001',
      start_time: new Date('2026-01-20T08:00:00.000Z'),
      end_time: new Date('2026-01-20T09:00:00.000Z'),
      is_available: true
    };

    it('should find availability slot by ID', async () => {
      prisma.availability_slot.findFirst.mockResolvedValue(mockSlot);

      const result = await availabilitySlotRepository.findById(slotId);

      expect(result).toEqual(mockSlot);
      expect(prisma.availability_slot.findFirst).toHaveBeenCalledWith({
        where: { id: slotId, deleted_at: null },
        include: {}
      });
    });

    it('should return null if slot not found', async () => {
      prisma.availability_slot.findFirst.mockResolvedValue(null);

      const result = await availabilitySlotRepository.findById(slotId);

      expect(result).toBeNull();
    });

    it('should filter out soft-deleted slots', async () => {
      prisma.availability_slot.findFirst.mockResolvedValue(null);

      await availabilitySlotRepository.findById(slotId);

      expect(prisma.availability_slot.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ deleted_at: null })
        })
      );
    });

    it('should accept include parameter', async () => {
      const include = { schedule: true };
      prisma.availability_slot.findFirst.mockResolvedValue(mockSlot);

      await availabilitySlotRepository.findById(slotId, include);

      expect(prisma.availability_slot.findFirst).toHaveBeenCalledWith({
        where: { id: slotId, deleted_at: null },
        include
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.availability_slot.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(availabilitySlotRepository.findById(slotId)).rejects.toThrow(HttpError);
      await expect(availabilitySlotRepository.findById(slotId)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('findMany', () => {
    const mockSlots = [
      {
        id: '550e8400-e29b-41d4-a716-446655440000',
        schedule_id: '550e8400-e29b-41d4-a716-446655440001',
        is_available: true
      },
      {
        id: '550e8400-e29b-41d4-a716-446655440002',
        schedule_id: '550e8400-e29b-41d4-a716-446655440001',
        is_available: false
      }
    ];

    it('should find many slots with default params', async () => {
      prisma.availability_slot.findMany.mockResolvedValue(mockSlots);

      const result = await availabilitySlotRepository.findMany();

      expect(result).toEqual(mockSlots);
      expect(prisma.availability_slot.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply filters', async () => {
      const filters = { schedule_id: '550e8400-e29b-41d4-a716-446655440001', is_available: true };
      prisma.availability_slot.findMany.mockResolvedValue(mockSlots);

      await availabilitySlotRepository.findMany(filters);

      expect(prisma.availability_slot.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { deleted_at: null, ...filters }
        })
      );
    });

    it('should apply pagination', async () => {
      prisma.availability_slot.findMany.mockResolvedValue(mockSlots);

      await availabilitySlotRepository.findMany({}, 20, 10);

      expect(prisma.availability_slot.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          skip: 20,
          take: 10
        })
      );
    });

    it('should apply custom ordering', async () => {
      const orderBy = { start_time: 'asc' };
      prisma.availability_slot.findMany.mockResolvedValue(mockSlots);

      await availabilitySlotRepository.findMany({}, 0, 20, orderBy);

      expect(prisma.availability_slot.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ orderBy })
      );
    });

    it('should return empty array if no slots found', async () => {
      prisma.availability_slot.findMany.mockResolvedValue([]);

      const result = await availabilitySlotRepository.findMany();

      expect(result).toEqual([]);
    });

    it('should throw HttpError on database error', async () => {
      prisma.availability_slot.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(availabilitySlotRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count slots with default filters', async () => {
      prisma.availability_slot.count.mockResolvedValue(42);

      const result = await availabilitySlotRepository.count();

      expect(result).toBe(42);
      expect(prisma.availability_slot.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count slots with filters', async () => {
      const filters = { schedule_id: '550e8400-e29b-41d4-a716-446655440001', is_available: true };
      prisma.availability_slot.count.mockResolvedValue(10);

      const result = await availabilitySlotRepository.count(filters);

      expect(result).toBe(10);
      expect(prisma.availability_slot.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.availability_slot.count.mockRejectedValue(new Error('DB Error'));

      await expect(availabilitySlotRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    const slotData = {
      schedule_id: '550e8400-e29b-41d4-a716-446655440001',
      start_time: new Date('2026-01-20T08:00:00.000Z'),
      end_time: new Date('2026-01-20T09:00:00.000Z'),
      is_available: true
    };

    const createdSlot = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      ...slotData
    };

    it('should create an availability slot', async () => {
      prisma.availability_slot.create.mockResolvedValue(createdSlot);

      const result = await availabilitySlotRepository.create(slotData);

      expect(result).toEqual(createdSlot);
      expect(prisma.availability_slot.create).toHaveBeenCalledWith({
        data: slotData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = { code: 'P2002', meta: { target: ['schedule_id', 'start_time'] } };
      prisma.availability_slot.create.mockRejectedValue(error);

      await expect(availabilitySlotRepository.create(slotData)).rejects.toThrow(HttpError);
      await expect(availabilitySlotRepository.create(slotData)).rejects.toMatchObject({
        messageKey: 'errors.database.unique_field',
        statusCode: 409
      });
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = { code: 'P2003', meta: { field_name: 'schedule_id' } };
      prisma.availability_slot.create.mockRejectedValue(error);

      await expect(availabilitySlotRepository.create(slotData)).rejects.toThrow(HttpError);
      await expect(availabilitySlotRepository.create(slotData)).rejects.toMatchObject({
        messageKey: 'errors.database.foreign_key_field',
        statusCode: 400
      });
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.availability_slot.create.mockRejectedValue(new Error('DB Error'));

      await expect(availabilitySlotRepository.create(slotData)).rejects.toThrow(HttpError);
      await expect(availabilitySlotRepository.create(slotData)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('update', () => {
    const slotId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = { is_available: false };
    const updatedSlot = { id: slotId, ...updateData };

    it('should update an availability slot', async () => {
      prisma.availability_slot.update.mockResolvedValue(updatedSlot);

      const result = await availabilitySlotRepository.update(slotId, updateData);

      expect(result).toEqual(updatedSlot);
      expect(prisma.availability_slot.update).toHaveBeenCalledWith({
        where: { id: slotId },
        data: updateData
      });
    });

    it('should throw HttpError if slot not found', async () => {
      const error = { code: 'P2025' };
      prisma.availability_slot.update.mockRejectedValue(error);

      await expect(availabilitySlotRepository.update(slotId, updateData)).rejects.toThrow(HttpError);
      await expect(availabilitySlotRepository.update(slotId, updateData)).rejects.toMatchObject({
        messageKey: 'errors.availability_slot.not_found',
        statusCode: 404
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = { code: 'P2002', meta: { target: ['schedule_id', 'start_time'] } };
      prisma.availability_slot.update.mockRejectedValue(error);

      await expect(availabilitySlotRepository.update(slotId, updateData)).rejects.toThrow(HttpError);
      await expect(availabilitySlotRepository.update(slotId, updateData)).rejects.toMatchObject({
        statusCode: 409
      });
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = { code: 'P2003', meta: { field_name: 'schedule_id' } };
      prisma.availability_slot.update.mockRejectedValue(error);

      await expect(availabilitySlotRepository.update(slotId, updateData)).rejects.toThrow(HttpError);
      await expect(availabilitySlotRepository.update(slotId, updateData)).rejects.toMatchObject({
        statusCode: 400
      });
    });
  });

  describe('softDelete', () => {
    const slotId = '550e8400-e29b-41d4-a716-446655440000';

    it('should soft delete an availability slot', async () => {
      const deletedSlot = { id: slotId, deleted_at: expect.any(Date) };
      prisma.availability_slot.update.mockResolvedValue(deletedSlot);

      const result = await availabilitySlotRepository.softDelete(slotId);

      expect(result).toEqual(deletedSlot);
      expect(prisma.availability_slot.update).toHaveBeenCalledWith({
        where: { id: slotId },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError if slot not found', async () => {
      const error = { code: 'P2025' };
      prisma.availability_slot.update.mockRejectedValue(error);

      await expect(availabilitySlotRepository.softDelete(slotId)).rejects.toThrow(HttpError);
      await expect(availabilitySlotRepository.softDelete(slotId)).rejects.toMatchObject({
        messageKey: 'errors.availability_slot.not_found',
        statusCode: 404
      });
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.availability_slot.update.mockRejectedValue(new Error('DB Error'));

      await expect(availabilitySlotRepository.softDelete(slotId)).rejects.toThrow(HttpError);
      await expect(availabilitySlotRepository.softDelete(slotId)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });
});
