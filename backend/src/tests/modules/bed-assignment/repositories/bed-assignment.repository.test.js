/**
 * Bed Assignment repository tests
 */

const bedAssignmentRepository = require('../../../../modules/bed-assignment/repositories/bed-assignment.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  bed_assignment: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Bed Assignment Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find bed assignment by id', async () => {
      const mockBedAssignment = { id: 'test-id', admission_id: 'admission-id', bed_id: 'bed-id', deleted_at: null };
      prisma.bed_assignment.findFirst.mockResolvedValue(mockBedAssignment);
      const result = await bedAssignmentRepository.findById('test-id');
      expect(result).toEqual(mockBedAssignment);
    });

    it('should return null if not found', async () => {
      prisma.bed_assignment.findFirst.mockResolvedValue(null);
      const result = await bedAssignmentRepository.findById('non-existent');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.bed_assignment.findFirst.mockRejectedValue(new Error('DB Error'));
      await expect(bedAssignmentRepository.findById('test-id')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find bed assignments with filters', async () => {
      const mockBedAssignments = [{ id: '1' }, { id: '2' }];
      prisma.bed_assignment.findMany.mockResolvedValue(mockBedAssignments);
      const result = await bedAssignmentRepository.findMany({ admission_id: 'test' }, 0, 10);
      expect(result).toEqual(mockBedAssignments);
    });
  });

  describe('count', () => {
    it('should count bed assignments', async () => {
      prisma.bed_assignment.count.mockResolvedValue(5);
      const result = await bedAssignmentRepository.count({});
      expect(result).toBe(5);
    });
  });

  describe('create', () => {
    it('should create bed assignment', async () => {
      const data = { admission_id: 'a-id', bed_id: 'b-id' };
      const mockCreated = { id: 'new-id', ...data };
      prisma.bed_assignment.create.mockResolvedValue(mockCreated);
      const result = await bedAssignmentRepository.create(data);
      expect(result).toEqual(mockCreated);
    });

    it('should throw HttpError on unique constraint', async () => {
      const error = { code: 'P2002', meta: { target: ['field'] } };
      prisma.bed_assignment.create.mockRejectedValue(error);
      await expect(bedAssignmentRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update bed assignment', async () => {
      const mockUpdated = { id: 'test-id', released_at: '2026-01-20T10:00:00Z' };
      prisma.bed_assignment.update.mockResolvedValue(mockUpdated);
      const result = await bedAssignmentRepository.update('test-id', { released_at: '2026-01-20T10:00:00Z' });
      expect(result).toEqual(mockUpdated);
    });

    it('should throw HttpError if not found', async () => {
      const error = { code: 'P2025' };
      prisma.bed_assignment.update.mockRejectedValue(error);
      await expect(bedAssignmentRepository.update('non-existent', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete bed assignment', async () => {
      const mockDeleted = { id: 'test-id', deleted_at: expect.any(Date) };
      prisma.bed_assignment.update.mockResolvedValue(mockDeleted);
      const result = await bedAssignmentRepository.softDelete('test-id');
      expect(result).toEqual(mockDeleted);
    });
  });
});
