/**
 * Bed Assignment service tests
 */

const bedAssignmentService = require('../../../../modules/bed-assignment/services/bed-assignment.service');
const bedAssignmentRepository = require('../../../../modules/bed-assignment/repositories/bed-assignment.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

jest.mock('../../../../modules/bed-assignment/repositories/bed-assignment.repository');
jest.mock('@lib/audit');

describe('Bed Assignment Service', () => {
  const mockUserId = 'user-id';
  const mockIpAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  describe('listBedAssignments', () => {
    it('should list bed assignments with pagination', async () => {
      const mockBedAssignments = [{ id: '1' }, { id: '2' }];
      bedAssignmentRepository.findMany.mockResolvedValue(mockBedAssignments);
      bedAssignmentRepository.count.mockResolvedValue(2);
      const result = await bedAssignmentService.listBedAssignments({}, 1, 10, 'created_at', 'desc', mockUserId, mockIpAddress);
      expect(result.bedAssignments).toEqual(mockBedAssignments);
      expect(result.pagination.total).toBe(2);
    });
  });

  describe('getBedAssignmentById', () => {
    it('should return bed assignment by id', async () => {
      const mockBedAssignment = { id: 'test-id' };
      bedAssignmentRepository.findById.mockResolvedValue(mockBedAssignment);
      const result = await bedAssignmentService.getBedAssignmentById('test-id', mockUserId, mockIpAddress);
      expect(result).toEqual(mockBedAssignment);
    });

    it('should throw HttpError if not found', async () => {
      bedAssignmentRepository.findById.mockResolvedValue(null);
      await expect(bedAssignmentService.getBedAssignmentById('non-existent', mockUserId, mockIpAddress)).rejects.toThrow(HttpError);
    });
  });

  describe('createBedAssignment', () => {
    it('should create bed assignment and audit log', async () => {
      const data = { admission_id: 'a-id', bed_id: 'b-id' };
      const mockCreated = { id: 'new-id', ...data };
      bedAssignmentRepository.create.mockResolvedValue(mockCreated);
      const result = await bedAssignmentService.createBedAssignment(data, mockUserId, mockIpAddress);
      expect(result).toEqual(mockCreated);
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('updateBedAssignment', () => {
    it('should update bed assignment and create audit log', async () => {
      const before = { id: 'test-id', released_at: null };
      const after = { id: 'test-id', released_at: '2026-01-20T10:00:00Z' };
      bedAssignmentRepository.findById.mockResolvedValue(before);
      bedAssignmentRepository.update.mockResolvedValue(after);
      const result = await bedAssignmentService.updateBedAssignment('test-id', { released_at: '2026-01-20T10:00:00Z' }, mockUserId, mockIpAddress);
      expect(result).toEqual(after);
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('deleteBedAssignment', () => {
    it('should soft delete bed assignment and create audit log', async () => {
      const before = { id: 'test-id' };
      bedAssignmentRepository.findById.mockResolvedValue(before);
      bedAssignmentRepository.softDelete.mockResolvedValue({});
      await bedAssignmentService.deleteBedAssignment('test-id', mockUserId, mockIpAddress);
      expect(createAuditLog).toHaveBeenCalled();
    });
  });
});
