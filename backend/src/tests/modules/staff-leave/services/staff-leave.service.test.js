/**
 * Staff leave service tests
 *
 * @module tests/modules/staff-leave/services
 * @description Tests for staff leave service business logic
 * Per testing.mdc: Service tests must mock repository and audit functions
 */

const staffLeaveService = require('@services/staff-leave/staff-leave.service');
const staffLeaveRepository = require('@repositories/staff-leave/staff-leave.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/staff-leave/staff-leave.repository');
jest.mock('@lib/audit');

describe('Staff Leave Service', () => {
  const mockUserId = 'user-123';
  const mockIpAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  describe('listStaffLeaves', () => {
    it('should list staff leaves with pagination', async () => {
      const mockLeaves = [{ id: '1', staff_profile_id: 'prof-1', status: 'REQUESTED' }];
      staffLeaveRepository.findMany.mockResolvedValue(mockLeaves);
      staffLeaveRepository.count.mockResolvedValue(1);

      const result = await staffLeaveService.listStaffLeaves({}, 1, 20, 'created_at', 'desc', mockUserId, mockIpAddress);

      expect(result.staffLeaves).toEqual(mockLeaves);
      expect(result.pagination.total).toBe(1);
    });

    it('should calculate pagination correctly', async () => {
      staffLeaveRepository.findMany.mockResolvedValue([]);
      staffLeaveRepository.count.mockResolvedValue(50);

      const result = await staffLeaveService.listStaffLeaves({}, 2, 20, null, 'asc', mockUserId, mockIpAddress);

      expect(result.pagination.totalPages).toBe(3);
      expect(result.pagination.hasNextPage).toBe(true);
    });
  });

  describe('getStaffLeaveById', () => {
    it('should get staff leave by id', async () => {
      const mockLeave = { id: '123', staff_profile_id: 'prof-1', status: 'REQUESTED' };
      staffLeaveRepository.findById.mockResolvedValue(mockLeave);

      const result = await staffLeaveService.getStaffLeaveById('123', mockUserId, mockIpAddress);

      expect(result).toEqual(mockLeave);
    });

    it('should throw HttpError if staff leave not found', async () => {
      staffLeaveRepository.findById.mockResolvedValue(null);

      await expect(
        staffLeaveService.getStaffLeaveById('nonexistent', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createStaffLeave', () => {
    it('should create staff leave and log audit', async () => {
      const mockData = {
        staff_profile_id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'REQUESTED',
        start_date: new Date(),
        end_date: new Date()
      };
      const mockLeave = { id: '456', ...mockData };
      staffLeaveRepository.create.mockResolvedValue(mockLeave);

      const result = await staffLeaveService.createStaffLeave(mockData, mockUserId, mockIpAddress);

      expect(result).toEqual(mockLeave);
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should not fail if audit log fails', async () => {
      const mockData = {
        staff_profile_id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'REQUESTED',
        start_date: new Date(),
        end_date: new Date()
      };
      const mockLeave = { id: '456', ...mockData };
      staffLeaveRepository.create.mockResolvedValue(mockLeave);
      createAuditLog.mockImplementation(() => Promise.reject(new Error('Audit failed')));

      const result = await staffLeaveService.createStaffLeave(mockData, mockUserId, mockIpAddress);

      expect(result).toEqual(mockLeave);
    });
  });

  describe('updateStaffLeave', () => {
    it('should update staff leave and log audit', async () => {
      const mockBefore = { id: '123', status: 'REQUESTED' };
      const mockData = { status: 'APPROVED' };
      const mockAfter = { id: '123', status: 'APPROVED' };
      staffLeaveRepository.findById.mockResolvedValue(mockBefore);
      staffLeaveRepository.update.mockResolvedValue(mockAfter);

      const result = await staffLeaveService.updateStaffLeave('123', mockData, mockUserId, mockIpAddress);

      expect(result).toEqual(mockAfter);
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw HttpError if staff leave not found', async () => {
      staffLeaveRepository.findById.mockResolvedValue(null);

      await expect(
        staffLeaveService.updateStaffLeave('nonexistent', {}, mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deleteStaffLeave', () => {
    it('should delete staff leave and log audit', async () => {
      const mockLeave = { id: '123', staff_profile_id: 'prof-1' };
      staffLeaveRepository.findById.mockResolvedValue(mockLeave);
      staffLeaveRepository.softDelete.mockResolvedValue(undefined);

      await staffLeaveService.deleteStaffLeave('123', mockUserId, mockIpAddress);

      expect(staffLeaveRepository.softDelete).toHaveBeenCalledWith('123');
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw HttpError if staff leave not found', async () => {
      staffLeaveRepository.findById.mockResolvedValue(null);

      await expect(
        staffLeaveService.deleteStaffLeave('nonexistent', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });
});
