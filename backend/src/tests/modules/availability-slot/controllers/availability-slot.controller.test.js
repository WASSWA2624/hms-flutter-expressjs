/**
 * Availability slot controller tests
 *
 * @module tests/modules/availability-slot/controllers
 * @description Tests for availability slot controller
 * Per testing.mdc: Mock service, test HTTP handling
 */

const availabilitySlotController = require('@controllers/availability-slot/availability-slot.controller');
const availabilitySlotService = require('@services/availability-slot/availability-slot.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

// Mock dependencies
jest.mock('@services/availability-slot/availability-slot.service');
jest.mock('@lib/response');

describe('Availability Slot Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'requester-id' },
      ip: '127.0.0.1'
    };

    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
  });

  describe('listAvailabilitySlots', () => {
    const mockResult = {
      slots: [
        { id: '1', schedule_id: 'schedule-1', is_available: true },
        { id: '2', schedule_id: 'schedule-1', is_available: false }
      ],
      pagination: {
        page: 1,
        limit: 20,
        total: 2,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      }
    };

    it('should list slots with default pagination', async () => {
      availabilitySlotService.listAvailabilitySlots.mockResolvedValue(mockResult);

      await availabilitySlotController.listAvailabilitySlots(req, res);

      expect(availabilitySlotService.listAvailabilitySlots).toHaveBeenCalledWith(
        expect.any(Object),
        DEFAULT_PAGE,
        DEFAULT_PAGE_LIMIT,
        undefined,
        'asc',
        'requester-id',
        '127.0.0.1'
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.availability_slot.list.success',
        mockResult.slots,
        mockResult.pagination
      );
    });

    it('should apply filters from query params', async () => {
      req.query = {
        schedule_id: '550e8400-e29b-41d4-a716-446655440000',
        is_available: true,
        page: '2',
        limit: '10',
        sort_by: 'start_time',
        order: 'desc'
      };
      availabilitySlotService.listAvailabilitySlots.mockResolvedValue(mockResult);

      await availabilitySlotController.listAvailabilitySlots(req, res);

      expect(availabilitySlotService.listAvailabilitySlots).toHaveBeenCalledWith(
        {
          schedule_id: '550e8400-e29b-41d4-a716-446655440000',
          is_available: true
        },
        2,
        10,
        'start_time',
        'desc',
        'requester-id',
        '127.0.0.1'
      );
    });
  });

  describe('getAvailabilitySlotById', () => {
    const mockSlot = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      schedule_id: 'schedule-1',
      is_available: true
    };

    it('should get slot by ID', async () => {
      req.params.id = '550e8400-e29b-41d4-a716-446655440000';
      availabilitySlotService.getAvailabilitySlotById.mockResolvedValue(mockSlot);

      await availabilitySlotController.getAvailabilitySlotById(req, res);

      expect(availabilitySlotService.getAvailabilitySlotById).toHaveBeenCalledWith(
        '550e8400-e29b-41d4-a716-446655440000',
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.availability_slot.get.success',
        mockSlot
      );
    });
  });

  describe('createAvailabilitySlot', () => {
    const slotData = {
      schedule_id: '550e8400-e29b-41d4-a716-446655440001',
      start_time: '2026-01-20T08:00:00.000Z',
      end_time: '2026-01-20T09:00:00.000Z',
      is_available: true
    };

    const createdSlot = { id: '550e8400-e29b-41d4-a716-446655440000', ...slotData };

    it('should create a slot', async () => {
      req.body = slotData;
      availabilitySlotService.createAvailabilitySlot.mockResolvedValue(createdSlot);

      await availabilitySlotController.createAvailabilitySlot(req, res);

      expect(availabilitySlotService.createAvailabilitySlot).toHaveBeenCalledWith(
        slotData,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.availability_slot.create.success',
        createdSlot
      );
    });
  });

  describe('updateAvailabilitySlot', () => {
    const updateData = { is_available: false };
    const updatedSlot = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      is_available: false
    };

    it('should update a slot', async () => {
      req.params.id = '550e8400-e29b-41d4-a716-446655440000';
      req.body = updateData;
      availabilitySlotService.updateAvailabilitySlot.mockResolvedValue(updatedSlot);

      await availabilitySlotController.updateAvailabilitySlot(req, res);

      expect(availabilitySlotService.updateAvailabilitySlot).toHaveBeenCalledWith(
        '550e8400-e29b-41d4-a716-446655440000',
        updateData,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.availability_slot.update.success',
        updatedSlot
      );
    });
  });

  describe('deleteAvailabilitySlot', () => {
    it('should soft delete a slot', async () => {
      req.params.id = '550e8400-e29b-41d4-a716-446655440000';
      availabilitySlotService.deleteAvailabilitySlot.mockResolvedValue();

      await availabilitySlotController.deleteAvailabilitySlot(req, res);

      expect(availabilitySlotService.deleteAvailabilitySlot).toHaveBeenCalledWith(
        '550e8400-e29b-41d4-a716-446655440000',
        'requester-id',
        '127.0.0.1'
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });
});
