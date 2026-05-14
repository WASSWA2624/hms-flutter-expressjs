/**
 * Staff assignment repository tests
 *
 * @module tests/modules/staff-assignment/repositories
 * @description Tests for staff assignment repository operations
 * Per testing.mdc: Repository tests must mock Prisma client
 */

const staffAssignmentRepository = require('@repositories/staff-assignment/staff-assignment.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  staff_assignment: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Staff Assignment Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find staff assignment by id', async () => {
      const mockAssignment = { id: '123', staff_profile_id: 'prof-1', department_id: 'dept-1' };
      prisma.staff_assignment.findFirst.mockResolvedValue(mockAssignment);

      const result = await staffAssignmentRepository.findById('123');
      expect(result).toEqual(mockAssignment);
    });

    it('should return null if staff assignment not found', async () => {
      prisma.staff_assignment.findFirst.mockResolvedValue(null);

      const result = await staffAssignmentRepository.findById('nonexistent');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.staff_assignment.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(staffAssignmentRepository.findById('123')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many staff assignments with pagination', async () => {
      const mockAssignments = [
        { id: '1', staff_profile_id: 'prof-1' },
        { id: '2', staff_profile_id: 'prof-2' }
      ];
      prisma.staff_assignment.findMany.mockResolvedValue(mockAssignments);

      const result = await staffAssignmentRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockAssignments);
    });

    it('should throw HttpError on database error', async () => {
      prisma.staff_assignment.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(staffAssignmentRepository.findMany({}, 0, 20)).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count staff assignments', async () => {
      prisma.staff_assignment.count.mockResolvedValue(42);

      const result = await staffAssignmentRepository.count({});
      expect(result).toBe(42);
    });
  });

  describe('create', () => {
    it('should create staff assignment', async () => {
      const mockData = { staff_profile_id: 'prof-1', department_id: 'dept-1', start_date: new Date() };
      const mockAssignment = { id: '456', ...mockData };
      prisma.staff_assignment.create.mockResolvedValue(mockAssignment);

      const result = await staffAssignmentRepository.create(mockData);
      expect(result).toEqual(mockAssignment);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'staff_profile_id' };
      prisma.staff_assignment.create.mockRejectedValue(error);

      await expect(staffAssignmentRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update staff assignment', async () => {
      const mockData = { department_id: 'dept-2' };
      const mockAssignment = { id: '123', ...mockData };
      prisma.staff_assignment.update.mockResolvedValue(mockAssignment);

      const result = await staffAssignmentRepository.update('123', mockData);
      expect(result).toEqual(mockAssignment);
    });

    it('should throw HttpError on not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.staff_assignment.update.mockRejectedValue(error);

      await expect(staffAssignmentRepository.update('123', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete staff assignment', async () => {
      const mockAssignment = { id: '123', deleted_at: new Date() };
      prisma.staff_assignment.update.mockResolvedValue(mockAssignment);

      const result = await staffAssignmentRepository.softDelete('123');
      expect(result).toEqual(mockAssignment);
    });

    it('should throw HttpError on not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.staff_assignment.update.mockRejectedValue(error);

      await expect(staffAssignmentRepository.softDelete('123')).rejects.toThrow(HttpError);
    });
  });
});
