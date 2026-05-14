/**
 * Availability slot service tests
 *
 * @module tests/modules/availability-slot/services
 * @description Tests for availability slot service
 * Per testing.mdc: Mock repository, test business logic
 */

const availabilitySlotService = require('@services/availability-slot/availability-slot.service');
const availabilitySlotRepository = require('@repositories/availability-slot/availability-slot.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveModelIdByIdentifier,
  resolveModelRecordByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');

// Mock dependencies
jest.mock('@repositories/availability-slot/availability-slot.repository');
jest.mock('@lib/audit');
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelIdByIdentifier: jest.fn(),
  resolveModelRecordByIdentifier: jest.fn(),
}));

describe('Availability Slot Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    resolveModelIdByIdentifier.mockImplementation(async ({ identifier }) => identifier);
    resolveModelRecordByIdentifier.mockImplementation(async ({ identifier }) =>
      identifier ? { id: identifier } : null
    );
  });

  describe('listAvailabilitySlots', () => {
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

    it('should list slots with pagination', async () => {
      availabilitySlotRepository.findMany.mockResolvedValue(mockSlots);
      availabilitySlotRepository.count.mockResolvedValue(2);

      const result = await availabilitySlotService.listAvailabilitySlots({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(result).toHaveProperty('slots', mockSlots);
      expect(result).toHaveProperty('pagination');
      expect(result.pagination).toMatchObject({
        page: 1,
        limit: 20,
        total: 2,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
    });

    it('should apply filters correctly', async () => {
      const filters = {
        schedule_id: '550e8400-e29b-41d4-a716-446655440001',
        is_available: true
      };
      availabilitySlotRepository.findMany.mockResolvedValue(mockSlots);
      availabilitySlotRepository.count.mockResolvedValue(2);

      await availabilitySlotService.listAvailabilitySlots(filters, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(availabilitySlotRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          schedule_id: filters.schedule_id,
          is_available: filters.is_available
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object),
        expect.any(Object)
      );
    });

    it('should throw HttpError on repository error', async () => {
      availabilitySlotRepository.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(availabilitySlotService.listAvailabilitySlots({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1'))
        .rejects.toThrow(HttpError);
    });
  });

  describe('getAvailabilitySlotById', () => {
    const slotId = '550e8400-e29b-41d4-a716-446655440000';
    const mockSlot = {
      id: slotId,
      schedule_id: '550e8400-e29b-41d4-a716-446655440001',
      is_available: true
    };

    it('should get slot by ID', async () => {
      availabilitySlotRepository.findById.mockResolvedValue(mockSlot);

      const result = await availabilitySlotService.getAvailabilitySlotById(slotId, 'user-id', '127.0.0.1');

      expect(result).toEqual(mockSlot);
      expect(availabilitySlotRepository.findById).toHaveBeenCalledWith(slotId, expect.any(Object));
    });

    it('should throw HttpError if slot not found', async () => {
      availabilitySlotRepository.findById.mockResolvedValue(null);

      await expect(availabilitySlotService.getAvailabilitySlotById(slotId, 'user-id', '127.0.0.1'))
        .rejects.toThrow(HttpError);
      await expect(availabilitySlotService.getAvailabilitySlotById(slotId, 'user-id', '127.0.0.1'))
        .rejects.toMatchObject({
          messageKey: 'errors.availability_slot.not_found',
          statusCode: 404
        });
    });
  });

  describe('createAvailabilitySlot', () => {
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

    it('should create a slot', async () => {
      availabilitySlotRepository.create.mockResolvedValue(createdSlot);
      availabilitySlotRepository.findById.mockResolvedValue(createdSlot);

      const result = await availabilitySlotService.createAvailabilitySlot(slotData, 'user-id', '127.0.0.1');

      expect(result).toEqual(createdSlot);
      expect(availabilitySlotRepository.create).toHaveBeenCalledWith(slotData);
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: 'user-id',
          action: 'CREATE',
          entity: 'availability_slot',
          entity_id: createdSlot.id
        })
      );
    });

    it('should throw HttpError on repository error', async () => {
      availabilitySlotRepository.create.mockRejectedValue(new Error('DB Error'));

      await expect(availabilitySlotService.createAvailabilitySlot(slotData, 'user-id', '127.0.0.1'))
        .rejects.toThrow(HttpError);
    });
  });

  describe('updateAvailabilitySlot', () => {
    const slotId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = { is_available: false };
    const existingSlot = { id: slotId, is_available: true };
    const updatedSlot = { id: slotId, is_available: false };

    it('should update a slot', async () => {
      availabilitySlotRepository.findById
        .mockResolvedValueOnce(existingSlot)
        .mockResolvedValueOnce(updatedSlot);
      availabilitySlotRepository.update.mockResolvedValue(updatedSlot);

      const result = await availabilitySlotService.updateAvailabilitySlot(slotId, updateData, 'user-id', '127.0.0.1');

      expect(result).toEqual(updatedSlot);
      expect(availabilitySlotRepository.findById).toHaveBeenNthCalledWith(1, slotId, expect.any(Object));
      expect(availabilitySlotRepository.findById).toHaveBeenNthCalledWith(2, slotId, expect.any(Object));
      expect(availabilitySlotRepository.update).toHaveBeenCalledWith(slotId, updateData);
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: 'user-id',
          action: 'UPDATE',
          entity: 'availability_slot',
          entity_id: slotId,
          diff: expect.objectContaining({
            before: existingSlot,
            after: updatedSlot
          })
        })
      );
    });

    it('should throw HttpError if slot not found', async () => {
      availabilitySlotRepository.findById.mockResolvedValue(null);

      await expect(availabilitySlotService.updateAvailabilitySlot(slotId, updateData, 'user-id', '127.0.0.1'))
        .rejects.toThrow(HttpError);
      await expect(availabilitySlotService.updateAvailabilitySlot(slotId, updateData, 'user-id', '127.0.0.1'))
        .rejects.toMatchObject({
          messageKey: 'errors.availability_slot.not_found',
          statusCode: 404
        });
    });
  });

  describe('deleteAvailabilitySlot', () => {
    const slotId = '550e8400-e29b-41d4-a716-446655440000';
    const existingSlot = { id: slotId, is_available: true };

    it('should soft delete a slot', async () => {
      availabilitySlotRepository.findById.mockResolvedValue(existingSlot);
      availabilitySlotRepository.softDelete.mockResolvedValue({ ...existingSlot, deleted_at: new Date() });

      await availabilitySlotService.deleteAvailabilitySlot(slotId, 'user-id', '127.0.0.1');

      expect(availabilitySlotRepository.findById).toHaveBeenCalledWith(slotId, expect.any(Object));
      expect(availabilitySlotRepository.softDelete).toHaveBeenCalledWith(slotId);
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: 'user-id',
          action: 'DELETE',
          entity: 'availability_slot',
          entity_id: slotId,
          diff: expect.objectContaining({ before: existingSlot })
        })
      );
    });

    it('should throw HttpError if slot not found', async () => {
      availabilitySlotRepository.findById.mockResolvedValue(null);

      await expect(availabilitySlotService.deleteAvailabilitySlot(slotId, 'user-id', '127.0.0.1'))
        .rejects.toThrow(HttpError);
      await expect(availabilitySlotService.deleteAvailabilitySlot(slotId, 'user-id', '127.0.0.1'))
        .rejects.toMatchObject({
          messageKey: 'errors.availability_slot.not_found',
          statusCode: 404
        });
    });
  });
});
