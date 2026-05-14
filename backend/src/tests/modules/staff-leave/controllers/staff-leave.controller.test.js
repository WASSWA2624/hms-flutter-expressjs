/**
 * Staff leave controller tests
 *
 * @module tests/modules/staff-leave/controllers
 * @description Tests for staff leave controller request handlers
 * Per testing.mdc: Controller tests must mock service layer
 */

const staffLeaveController = require('@controllers/staff-leave/staff-leave.controller');
const staffLeaveService = require('@services/staff-leave/staff-leave.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@services/staff-leave/staff-leave.service');
jest.mock('@lib/response');
jest.mock('@config/constants', () => ({
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_LIMIT: 20
}));

describe('Staff Leave Controller', () => {
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

  describe('listStaffLeaves', () => {
    it('should call service and send paginated response', async () => {
      const mockResult = {
        staffLeaves: [{ id: '1', staff_profile_id: 'prof-1', status: 'REQUESTED' }],
        pagination: { page: 1, limit: 20, total: 1, totalPages: 1, hasNextPage: false, hasPreviousPage: false }
      };
      staffLeaveService.listStaffLeaves.mockResolvedValue(mockResult);

      await staffLeaveController.listStaffLeaves(mockReq, mockRes);

      expect(staffLeaveService.listStaffLeaves).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.staff_leave.list.success',
        mockResult.staffLeaves,
        mockResult.pagination
      );
    });
  });

  describe('getStaffLeaveById', () => {
    it('should call service and send success response', async () => {
      const mockLeave = { id: '123', staff_profile_id: 'prof-1', status: 'REQUESTED' };
      staffLeaveService.getStaffLeaveById.mockResolvedValue(mockLeave);
      mockReq.params = { id: '123' };

      await staffLeaveController.getStaffLeaveById(mockReq, mockRes);

      expect(staffLeaveService.getStaffLeaveById).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.staff_leave.get.success', mockLeave);
    });
  });

  describe('createStaffLeave', () => {
    it('should call service and send success response', async () => {
      const mockData = { staff_profile_id: 'prof-1', status: 'REQUESTED', start_date: new Date(), end_date: new Date() };
      const mockLeave = { id: '456', ...mockData };
      staffLeaveService.createStaffLeave.mockResolvedValue(mockLeave);
      mockReq.body = mockData;

      await staffLeaveController.createStaffLeave(mockReq, mockRes);

      expect(staffLeaveService.createStaffLeave).toHaveBeenCalledWith(mockData, 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 201, 'messages.staff_leave.create.success', mockLeave);
    });
  });

  describe('updateStaffLeave', () => {
    it('should call service and send success response', async () => {
      const mockData = { status: 'APPROVED' };
      const mockLeave = { id: '123', ...mockData };
      staffLeaveService.updateStaffLeave.mockResolvedValue(mockLeave);
      mockReq.params = { id: '123' };
      mockReq.body = mockData;

      await staffLeaveController.updateStaffLeave(mockReq, mockRes);

      expect(staffLeaveService.updateStaffLeave).toHaveBeenCalledWith('123', mockData, 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.staff_leave.update.success', mockLeave);
    });
  });

  describe('deleteStaffLeave', () => {
    it('should call service and send no content response', async () => {
      staffLeaveService.deleteStaffLeave.mockResolvedValue(undefined);
      mockReq.params = { id: '123' };

      await staffLeaveController.deleteStaffLeave(mockReq, mockRes);

      expect(staffLeaveService.deleteStaffLeave).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
