/**
 * Staff assignment service tests
 *
 * @module tests/modules/staff-assignment/services
 * @description Tests for staff assignment service business logic
 * Per testing.mdc: Service tests must mock repository and audit functions
 */

const staffAssignmentService = require('@services/staff-assignment/staff-assignment.service');
const staffAssignmentRepository = require('@repositories/staff-assignment/staff-assignment.repository');
const { createAuditLog } = require('@lib/audit');
const {
  endActiveStaffAssignments,
  syncStaffProfilePrimaryDepartment} = require('@lib/hr/staff-department-sync');
const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/staff-assignment/staff-assignment.repository');
jest.mock('@lib/audit');
jest.mock('@lib/hr/staff-department-sync');

describe('Staff Assignment Service', () => {
  const mockUserId = 'user-123';
  const mockIpAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    syncStaffProfilePrimaryDepartment.mockResolvedValue(null);
    endActiveStaffAssignments.mockResolvedValue({ count: 0 });
  });

  describe('listStaffAssignments', () => {
    it('should list staff assignments with pagination', async () => {
      const mockAssignments = [{ id: '1', staff_profile_id: 'prof-1' }];
      staffAssignmentRepository.findMany.mockResolvedValue(mockAssignments);
      staffAssignmentRepository.count.mockResolvedValue(1);

      const result = await staffAssignmentService.listStaffAssignments({}, 1, 20, 'created_at', 'desc', mockUserId, mockIpAddress);

      expect(result.staffAssignments).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ id: '1', staff_profile_id: 'prof-1' })])
      );
      expect(result.pagination.total).toBe(1);
    });

    it('should calculate pagination correctly', async () => {
      staffAssignmentRepository.findMany.mockResolvedValue([]);
      staffAssignmentRepository.count.mockResolvedValue(50);

      const result = await staffAssignmentService.listStaffAssignments({}, 2, 20, null, 'asc', mockUserId, mockIpAddress);

      expect(result.pagination.totalPages).toBe(3);
      expect(result.pagination.hasNextPage).toBe(true);
    });
  });

  describe('getStaffAssignmentById', () => {
    it('should get staff assignment by id', async () => {
      const mockAssignment = { id: '123', staff_profile_id: 'prof-1' };
      staffAssignmentRepository.findById.mockResolvedValue(mockAssignment);

      const result = await staffAssignmentService.getStaffAssignmentById('123', mockUserId, mockIpAddress);

      expect(result).toEqual(expect.objectContaining({ id: '123', staff_profile_id: 'prof-1' }));
    });

    it('should throw HttpError if staff assignment not found', async () => {
      staffAssignmentRepository.findById.mockResolvedValue(null);

      await expect(
        staffAssignmentService.getStaffAssignmentById('nonexistent', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createStaffAssignment', () => {
    it('should create staff assignment and log audit', async () => {
      const mockData = {
        staff_profile_id: '550e8400-e29b-41d4-a716-446655440000',
        department_id: '550e8400-e29b-41d4-a716-446655440001',
        start_date: new Date()
      };
      const mockAssignment = { id: '456', ...mockData };
      staffAssignmentRepository.create.mockResolvedValue(mockAssignment);
      staffAssignmentRepository.findById.mockResolvedValue(mockAssignment);

      const result = await staffAssignmentService.createStaffAssignment(mockData, mockUserId, mockIpAddress);

      expect(result).toEqual(expect.objectContaining({ id: '456' }));
      expect(endActiveStaffAssignments).toHaveBeenCalledWith(
        mockData.staff_profile_id,
        expect.any(Date)
      );
      expect(syncStaffProfilePrimaryDepartment).toHaveBeenCalledWith(mockData.staff_profile_id);
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should end previous active assignments when changing department', async () => {
      const startDate = new Date('2026-08-10T00:00:00.000Z');
      const mockData = {
        staff_profile_id: '550e8400-e29b-41d4-a716-446655440000',
        department_id: '550e8400-e29b-41d4-a716-446655440099',
        start_date: startDate
      };
      const mockAssignment = { id: '789', ...mockData };
      staffAssignmentRepository.create.mockResolvedValue(mockAssignment);
      staffAssignmentRepository.findById.mockResolvedValue(mockAssignment);
      endActiveStaffAssignments.mockResolvedValue({ count: 1 });

      await staffAssignmentService.createStaffAssignment(mockData, mockUserId, mockIpAddress);

      expect(endActiveStaffAssignments).toHaveBeenCalledWith(
        mockData.staff_profile_id,
        startDate
      );
      expect(staffAssignmentRepository.create).toHaveBeenCalled();
    });

    it('should not fail if audit log fails', async () => {
      const mockData = {
        staff_profile_id: '550e8400-e29b-41d4-a716-446655440000',
        department_id: '550e8400-e29b-41d4-a716-446655440001',
        start_date: new Date()
      };
      const mockAssignment = { id: '456', ...mockData };
      staffAssignmentRepository.create.mockResolvedValue(mockAssignment);
      staffAssignmentRepository.findById.mockResolvedValue(mockAssignment);
      createAuditLog.mockImplementation(() => Promise.reject(new Error('Audit failed')));

      const result = await staffAssignmentService.createStaffAssignment(mockData, mockUserId, mockIpAddress);

      expect(result).toEqual(expect.objectContaining({ id: '456' }));
    });

    it('should create one assignment per room when room_ids is provided', async () => {
      const mockData = {
        staff_profile_id: '550e8400-e29b-41d4-a716-446655440000',
        department_id: '550e8400-e29b-41d4-a716-446655440001',
        unit_id: '550e8400-e29b-41d4-a716-446655440002',
        room_ids: [
          '550e8400-e29b-41d4-a716-446655440003',
          '550e8400-e29b-41d4-a716-446655440004'],
        start_date: new Date()};
      staffAssignmentRepository.create
        .mockResolvedValueOnce({ id: 'room-1', ...mockData, room_id: mockData.room_ids[0] })
        .mockResolvedValueOnce({ id: 'room-2', ...mockData, room_id: mockData.room_ids[1] });
      staffAssignmentRepository.findById
        .mockResolvedValueOnce({ id: 'room-1', ...mockData, room_id: mockData.room_ids[0] })
        .mockResolvedValueOnce({ id: 'room-2', ...mockData, room_id: mockData.room_ids[1] });

      const result = await staffAssignmentService.createStaffAssignment(mockData, mockUserId, mockIpAddress);

      expect(staffAssignmentRepository.create).toHaveBeenCalledTimes(2);
      expect(result).toEqual({
        assignments: [
          expect.objectContaining({ id: 'room-1', room_id: mockData.room_ids[0] }),
          expect.objectContaining({ id: 'room-2', room_id: mockData.room_ids[1] })],
        count: 2});
      expect(createAuditLog).toHaveBeenCalledTimes(2);
    });
  });

  describe('updateStaffAssignment', () => {
    it('should update staff assignment and log audit', async () => {
      const mockBefore = {
        id: '123',
        staff_profile_id: 'prof-1',
        department_id: '550e8400-e29b-41d4-a716-446655440001'};
      const mockData = { department_id: '550e8400-e29b-41d4-a716-446655440002' };
      const mockAfter = {
        id: '123',
        staff_profile_id: 'prof-1',
        department_id: '550e8400-e29b-41d4-a716-446655440002'};
      staffAssignmentRepository.findById
        .mockResolvedValueOnce(mockBefore)
        .mockResolvedValueOnce(mockAfter);
      staffAssignmentRepository.update.mockResolvedValue(mockAfter);

      const result = await staffAssignmentService.updateStaffAssignment('123', mockData, mockUserId, mockIpAddress);

      expect(result).toEqual(expect.objectContaining({ id: '123' }));
      expect(syncStaffProfilePrimaryDepartment).toHaveBeenCalledWith('prof-1');
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw HttpError if staff assignment not found', async () => {
      staffAssignmentRepository.findById.mockResolvedValue(null);

      await expect(
        staffAssignmentService.updateStaffAssignment('nonexistent', {}, mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deleteStaffAssignment', () => {
    it('should delete staff assignment and log audit', async () => {
      const mockAssignment = { id: '123', staff_profile_id: 'prof-1' };
      staffAssignmentRepository.findById.mockResolvedValue(mockAssignment);
      staffAssignmentRepository.softDelete.mockResolvedValue(undefined);

      await staffAssignmentService.deleteStaffAssignment('123', mockUserId, mockIpAddress);

      expect(staffAssignmentRepository.softDelete).toHaveBeenCalledWith('123');
      expect(syncStaffProfilePrimaryDepartment).toHaveBeenCalledWith('prof-1');
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw HttpError if staff assignment not found', async () => {
      staffAssignmentRepository.findById.mockResolvedValue(null);

      await expect(
        staffAssignmentService.deleteStaffAssignment('nonexistent', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });
});
