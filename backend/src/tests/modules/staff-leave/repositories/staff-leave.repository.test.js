/**
 * Staff leave repository tests
 *
 * @module tests/modules/staff-leave/repositories
 * @description Tests for staff leave repository operations
 * Per testing.mdc: Repository tests must mock Prisma client
 */

const staffLeaveRepository = require('@repositories/staff-leave/staff-leave.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  staff_leave: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Staff Leave Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find staff leave by id', async () => {
      const mockLeave = { id: '123', staff_profile_id: 'prof-1', status: 'REQUESTED' };
      prisma.staff_leave.findFirst.mockResolvedValue(mockLeave);

      const result = await staffLeaveRepository.findById('123');
      expect(result).toEqual(mockLeave);
    });

    it('should return null if staff leave not found', async () => {
      prisma.staff_leave.findFirst.mockResolvedValue(null);

      const result = await staffLeaveRepository.findById('nonexistent');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.staff_leave.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(staffLeaveRepository.findById('123')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many staff leaves with pagination', async () => {
      const mockLeaves = [
        { id: '1', staff_profile_id: 'prof-1', status: 'REQUESTED' },
        { id: '2', staff_profile_id: 'prof-2', status: 'APPROVED' }
      ];
      prisma.staff_leave.findMany.mockResolvedValue(mockLeaves);

      const result = await staffLeaveRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockLeaves);
    });

    it('should throw HttpError on database error', async () => {
      prisma.staff_leave.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(staffLeaveRepository.findMany({}, 0, 20)).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count staff leaves', async () => {
      prisma.staff_leave.count.mockResolvedValue(42);

      const result = await staffLeaveRepository.count({});
      expect(result).toBe(42);
    });
  });

  describe('create', () => {
    it('should create staff leave', async () => {
      const mockData = { staff_profile_id: 'prof-1', status: 'REQUESTED', start_date: new Date(), end_date: new Date() };
      const mockLeave = { id: '456', ...mockData };
      prisma.staff_leave.create.mockResolvedValue(mockLeave);

      const result = await staffLeaveRepository.create(mockData);
      expect(result).toEqual(mockLeave);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'staff_profile_id' };
      prisma.staff_leave.create.mockRejectedValue(error);

      await expect(staffLeaveRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update staff leave', async () => {
      const mockData = { status: 'APPROVED' };
      const mockLeave = { id: '123', ...mockData };
      prisma.staff_leave.update.mockResolvedValue(mockLeave);

      const result = await staffLeaveRepository.update('123', mockData);
      expect(result).toEqual(mockLeave);
    });

    it('should throw HttpError on not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.staff_leave.update.mockRejectedValue(error);

      await expect(staffLeaveRepository.update('123', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete staff leave', async () => {
      const mockLeave = { id: '123', deleted_at: new Date() };
      prisma.staff_leave.update.mockResolvedValue(mockLeave);

      const result = await staffLeaveRepository.softDelete('123');
      expect(result).toEqual(mockLeave);
    });

    it('should throw HttpError on not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.staff_leave.update.mockRejectedValue(error);

      await expect(staffLeaveRepository.softDelete('123')).rejects.toThrow(HttpError);
    });
  });
});
