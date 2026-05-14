/**
 * Staff assignment controller tests
 *
 * @module tests/modules/staff-assignment/controllers
 * @description Tests for staff assignment controller request handlers
 * Per testing.mdc: Controller tests must mock service layer
 */

const staffAssignmentController = require('@controllers/staff-assignment/staff-assignment.controller');
const staffAssignmentService = require('@services/staff-assignment/staff-assignment.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@services/staff-assignment/staff-assignment.service');
jest.mock('@lib/response');
jest.mock('@config/constants', () => ({
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_LIMIT: 20
}));

describe('Staff Assignment Controller', () => {
  let mockReq;
  let mockRes;

  beforeEach(() => {
    jest.clearAllMocks();
    mockReq = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-123' },
      ip: '127.0.0.1'
    };
    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
  });

  describe('listStaffAssignments', () => {
    it('should call service and send paginated response', async () => {
      const mockResult = {
        staffAssignments: [{ id: '1', staff_profile_id: 'prof-1' }],
        pagination: { page: 1, limit: 20, total: 1, totalPages: 1, hasNextPage: false, hasPreviousPage: false }
      };
      staffAssignmentService.listStaffAssignments.mockResolvedValue(mockResult);

      await staffAssignmentController.listStaffAssignments(mockReq, mockRes);

      expect(staffAssignmentService.listStaffAssignments).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.staff_assignment.list.success',
        mockResult.staffAssignments,
        mockResult.pagination
      );
    });
  });

  describe('getStaffAssignmentById', () => {
    it('should call service and send success response', async () => {
      const mockAssignment = { id: '123', staff_profile_id: 'prof-1' };
      staffAssignmentService.getStaffAssignmentById.mockResolvedValue(mockAssignment);
      mockReq.params = { id: '123' };

      await staffAssignmentController.getStaffAssignmentById(mockReq, mockRes);

      expect(staffAssignmentService.getStaffAssignmentById).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.staff_assignment.get.success', mockAssignment);
    });
  });

  describe('createStaffAssignment', () => {
    it('should call service and send success response', async () => {
      const mockData = { staff_profile_id: 'prof-1', start_date: new Date() };
      const mockAssignment = { id: '456', ...mockData };
      staffAssignmentService.createStaffAssignment.mockResolvedValue(mockAssignment);
      mockReq.body = mockData;

      await staffAssignmentController.createStaffAssignment(mockReq, mockRes);

      expect(staffAssignmentService.createStaffAssignment).toHaveBeenCalledWith(mockData, 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 201, 'messages.staff_assignment.create.success', mockAssignment);
    });
  });

  describe('updateStaffAssignment', () => {
    it('should call service and send success response', async () => {
      const mockData = { department_id: 'dept-2' };
      const mockAssignment = { id: '123', ...mockData };
      staffAssignmentService.updateStaffAssignment.mockResolvedValue(mockAssignment);
      mockReq.params = { id: '123' };
      mockReq.body = mockData;

      await staffAssignmentController.updateStaffAssignment(mockReq, mockRes);

      expect(staffAssignmentService.updateStaffAssignment).toHaveBeenCalledWith('123', mockData, 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.staff_assignment.update.success', mockAssignment);
    });
  });

  describe('deleteStaffAssignment', () => {
    it('should call service and send no content response', async () => {
      staffAssignmentService.deleteStaffAssignment.mockResolvedValue(undefined);
      mockReq.params = { id: '123' };

      await staffAssignmentController.deleteStaffAssignment(mockReq, mockRes);

      expect(staffAssignmentService.deleteStaffAssignment).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
