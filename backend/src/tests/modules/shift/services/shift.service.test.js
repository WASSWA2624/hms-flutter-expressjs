/**
 * Shift service tests
 *
 * @module tests/modules/shift/services
 * @description Tests for shift service operations
 * Per testing.mdc: Service tests must mock repository and audit functions
 */

const shiftService = require('@services/shift/shift.service');
const shiftRepository = require('@repositories/shift/shift.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId,
} = require('@lib/billing/identifiers');

// Mock dependencies
jest.mock('@repositories/shift/shift.repository');
jest.mock('@lib/audit');
jest.mock('@lib/billing/identifiers', () => ({
  resolveIdentifierForFilter: jest.fn(),
  resolveIdentifierForPayload: jest.fn(),
  resolveEntityId: jest.fn(),
}));

describe('Shift Service', () => {
  const userId = 'user-123';
  const ipAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    resolveIdentifierForFilter.mockImplementation(async ({ value }) => value);
    resolveIdentifierForPayload.mockImplementation(async ({ value }) => value);
    resolveEntityId.mockImplementation(async ({ identifier }) => identifier);
  });

  describe('listShifts', () => {
    it('should list shifts with pagination', async () => {
      const mockShifts = [
        { id: '1', tenant_id: '123', shift_type: 'DAY' },
        { id: '2', tenant_id: '123', shift_type: 'NIGHT' }
      ];
      shiftRepository.findMany.mockResolvedValue(mockShifts);
      shiftRepository.count.mockResolvedValue(2);

      const result = await shiftService.listShifts({}, 1, 20, 'created_at', 'desc', userId, ipAddress);

      expect(result.shifts).toEqual(mockShifts);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 2,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
    });

    it('should apply filters correctly', async () => {
      const filters = { tenant_id: '123', shift_type: 'DAY', status: 'SCHEDULED' };
      shiftRepository.findMany.mockResolvedValue([]);
      shiftRepository.count.mockResolvedValue(0);

      await shiftService.listShifts(filters, 1, 20, 'created_at', 'desc', userId, ipAddress);

      expect(shiftRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: '123',
          shift_type: 'DAY',
          status: 'SCHEDULED'
        }),
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should handle date range filters', async () => {
      const filters = {
        start_time_from: '2026-01-20T00:00:00.000Z',
        start_time_to: '2026-01-21T00:00:00.000Z'
      };
      shiftRepository.findMany.mockResolvedValue([]);
      shiftRepository.count.mockResolvedValue(0);

      await shiftService.listShifts(filters, 1, 20, 'created_at', 'desc', userId, ipAddress);

      expect(shiftRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          start_time: expect.objectContaining({
            gte: expect.any(Date),
            lte: expect.any(Date)
          })
        }),
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should throw HttpError on repository error', async () => {
      shiftRepository.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(
        shiftService.listShifts({}, 1, 20, 'created_at', 'desc', userId, ipAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('getShiftById', () => {
    it('should return shift by id', async () => {
      const mockShift = { id: '123', tenant_id: '456', shift_type: 'DAY' };
      shiftRepository.findById.mockResolvedValue(mockShift);

      const result = await shiftService.getShiftById('123', userId, ipAddress);

      expect(result).toEqual(mockShift);
      expect(shiftRepository.findById).toHaveBeenCalledWith('123');
    });

    it('should throw HttpError if shift not found', async () => {
      shiftRepository.findById.mockResolvedValue(null);

      await expect(
        shiftService.getShiftById('nonexistent', userId, ipAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createShift', () => {
    const mockData = {
      tenant_id: '123',
      shift_type: 'DAY',
      status: 'SCHEDULED',
      start_time: '2026-01-20T08:00:00.000Z',
      end_time: '2026-01-20T16:00:00.000Z'
    };

    it('should create shift and create audit log', async () => {
      const mockShift = { id: '456', ...mockData };
      shiftRepository.create.mockResolvedValue(mockShift);

      const result = await shiftService.createShift(mockData, userId, ipAddress);

      expect(result).toEqual(mockShift);
      expect(shiftRepository.create).toHaveBeenCalledWith(mockData);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: userId,
        action: 'CREATE',
        entity: 'shift',
        entity_id: mockShift.id,
        diff: { after: mockShift },
        ip_address: ipAddress
      });
    });

    it('should handle audit log failure gracefully', async () => {
      const mockShift = { id: '456', ...mockData };
      shiftRepository.create.mockResolvedValue(mockShift);
      createAuditLog.mockRejectedValue(new Error('Audit error'));

      const result = await shiftService.createShift(mockData, userId, ipAddress);

      expect(result).toEqual(mockShift);
    });

    it('should throw HttpError on repository error', async () => {
      shiftRepository.create.mockRejectedValue(new Error('DB Error'));

      await expect(
        shiftService.createShift(mockData, userId, ipAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('updateShift', () => {
    const mockUpdateData = { shift_type: 'NIGHT', status: 'COMPLETED' };

    it('should update shift and create audit log', async () => {
      const mockBefore = { id: '123', tenant_id: '456', shift_type: 'DAY', status: 'SCHEDULED' };
      const mockAfter = { ...mockBefore, ...mockUpdateData };
      shiftRepository.findById.mockResolvedValue(mockBefore);
      shiftRepository.update.mockResolvedValue(mockAfter);

      const result = await shiftService.updateShift('123', mockUpdateData, userId, ipAddress);

      expect(result).toEqual(mockAfter);
      expect(shiftRepository.update).toHaveBeenCalledWith('123', mockUpdateData);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: userId,
        action: 'UPDATE',
        entity: 'shift',
        entity_id: mockAfter.id,
        diff: { before: mockBefore, after: mockAfter },
        ip_address: ipAddress
      });
    });

    it('should throw HttpError if shift not found', async () => {
      shiftRepository.findById.mockResolvedValue(null);

      await expect(
        shiftService.updateShift('nonexistent', mockUpdateData, userId, ipAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deleteShift', () => {
    it('should soft delete shift and create audit log', async () => {
      const mockShift = { id: '123', tenant_id: '456', shift_type: 'DAY' };
      shiftRepository.findById.mockResolvedValue(mockShift);
      shiftRepository.softDelete.mockResolvedValue({ ...mockShift, deleted_at: new Date() });

      await shiftService.deleteShift('123', userId, ipAddress);

      expect(shiftRepository.softDelete).toHaveBeenCalledWith('123');
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: userId,
        action: 'DELETE',
        entity: 'shift',
        entity_id: '123',
        diff: { before: mockShift },
        ip_address: ipAddress
      });
    });

    it('should throw HttpError if shift not found', async () => {
      shiftRepository.findById.mockResolvedValue(null);

      await expect(
        shiftService.deleteShift('nonexistent', userId, ipAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('publishShift', () => {
    it('should publish shift and create audit log', async () => {
      const mockBefore = { id: '123', tenant_id: '456', shift_type: 'DAY', status: 'SCHEDULED' };
      const mockAfter = { ...mockBefore, status: 'SCHEDULED' };
      shiftRepository.findById.mockResolvedValue(mockBefore);
      shiftRepository.update.mockResolvedValue(mockAfter);

      const result = await shiftService.publishShift('123', true, userId, ipAddress);

      expect(result).toEqual(mockAfter);
      expect(shiftRepository.update).toHaveBeenCalledWith('123', { status: 'SCHEDULED' });
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: userId,
        action: 'PUBLISH',
        entity: 'shift',
        entity_id: mockAfter.id,
        diff: { before: mockBefore, after: mockAfter, metadata: { notifyStaff: true } },
        ip_address: ipAddress
      });
    });

    it('should throw HttpError if shift not found', async () => {
      shiftRepository.findById.mockResolvedValue(null);

      await expect(
        shiftService.publishShift('nonexistent', true, userId, ipAddress)
      ).rejects.toThrow(HttpError);
    });

    it('should throw HttpError if shift already published', async () => {
      const mockShift = { id: '123', tenant_id: '456', shift_type: 'DAY', status: 'COMPLETED' };
      shiftRepository.findById.mockResolvedValue(mockShift);

      await expect(
        shiftService.publishShift('123', true, userId, ipAddress)
      ).rejects.toThrow(HttpError);
    });
  });
});
