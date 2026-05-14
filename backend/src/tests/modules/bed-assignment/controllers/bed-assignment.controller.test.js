/**
 * Bed Assignment controller tests
 */

const bedAssignmentController = require('../../../../modules/bed-assignment/controllers/bed-assignment.controller');
const bedAssignmentService = require('../../../../modules/bed-assignment/services/bed-assignment.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('../../../../modules/bed-assignment/services/bed-assignment.service');
jest.mock('@lib/response');

describe('Bed Assignment Controller', () => {
  let mockReq, mockRes;

  beforeEach(() => {
    mockReq = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-id' },
      ip: '127.0.0.1'
    };
    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
    jest.clearAllMocks();
  });

  describe('listBedAssignments', () => {
    it('should list bed assignments', async () => {
      const mockResult = {
        bedAssignments: [{ id: '1' }],
        pagination: { page: 1, limit: 20, total: 1, totalPages: 1, hasNextPage: false, hasPreviousPage: false }
      };
      mockReq.query = { page: '1', limit: '20' };
      bedAssignmentService.listBedAssignments.mockResolvedValue(mockResult);
      await bedAssignmentController.listBedAssignments(mockReq, mockRes);
      expect(sendPaginated).toHaveBeenCalled();
    });
  });

  describe('getBedAssignmentById', () => {
    it('should return bed assignment by id', async () => {
      const mockBedAssignment = { id: 'test-id' };
      mockReq.params = { id: 'test-id' };
      bedAssignmentService.getBedAssignmentById.mockResolvedValue(mockBedAssignment);
      await bedAssignmentController.getBedAssignmentById(mockReq, mockRes);
      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('createBedAssignment', () => {
    it('should create bed assignment', async () => {
      const data = { admission_id: 'a-id', bed_id: 'b-id' };
      const mockCreated = { id: 'new-id', ...data };
      mockReq.body = data;
      bedAssignmentService.createBedAssignment.mockResolvedValue(mockCreated);
      await bedAssignmentController.createBedAssignment(mockReq, mockRes);
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 201, 'messages.bed_assignment.create.success', mockCreated);
    });
  });

  describe('updateBedAssignment', () => {
    it('should update bed assignment', async () => {
      const mockUpdated = { id: 'test-id', released_at: '2026-01-20T10:00:00Z' };
      mockReq.params = { id: 'test-id' };
      mockReq.body = { released_at: '2026-01-20T10:00:00Z' };
      bedAssignmentService.updateBedAssignment.mockResolvedValue(mockUpdated);
      await bedAssignmentController.updateBedAssignment(mockReq, mockRes);
      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('deleteBedAssignment', () => {
    it('should delete bed assignment', async () => {
      mockReq.params = { id: 'test-id' };
      bedAssignmentService.deleteBedAssignment.mockResolvedValue();
      await bedAssignmentController.deleteBedAssignment(mockReq, mockRes);
      expect(sendNoContent).toHaveBeenCalled();
    });
  });
});
