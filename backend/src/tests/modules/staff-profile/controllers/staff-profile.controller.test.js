/**
 * Staff profile controller tests
 *
 * @module tests/modules/staff-profile/controllers
 * @description Tests for staff profile controller request handlers
 * Per testing.mdc: Controller tests must mock service layer
 */

const staffProfileController = require('@controllers/staff-profile/staff-profile.controller');
const staffProfileService = require('@services/staff-profile/staff-profile.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@services/staff-profile/staff-profile.service');
jest.mock('@lib/response');
jest.mock('@config/constants', () => ({
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_LIMIT: 20
}));

describe('Staff Profile Controller', () => {
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

  describe('listStaffProfiles', () => {
    it('should call service and send paginated response', async () => {
      const mockResult = {
        staffProfiles: [{ id: '1', staff_number: 'STF001' }],
        pagination: { page: 1, limit: 20, total: 1, totalPages: 1, hasNextPage: false, hasPreviousPage: false }
      };
      staffProfileService.listStaffProfiles.mockResolvedValue(mockResult);

      await staffProfileController.listStaffProfiles(mockReq, mockRes);

      expect(staffProfileService.listStaffProfiles).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.staff_profile.list.success',
        mockResult.staffProfiles,
        mockResult.pagination
      );
    });

    it('should parse query parameters correctly', async () => {
      mockReq.query = { page: '2', limit: '50', tenant_id: '123', staff_number: 'STF001' };
      staffProfileService.listStaffProfiles.mockResolvedValue({
        staffProfiles: [],
        pagination: { page: 2, limit: 50, total: 0 }
      });

      await staffProfileController.listStaffProfiles(mockReq, mockRes);

      expect(staffProfileService.listStaffProfiles).toHaveBeenCalledWith(
        expect.objectContaining({ tenant_id: '123', staff_number: 'STF001' }),
        2,
        50,
        undefined,
        'asc',
        'user-123',
        '127.0.0.1'
      );
    });
  });

  describe('getStaffProfileById', () => {
    it('should call service and send success response', async () => {
      const mockProfile = { id: '123', staff_number: 'STF001' };
      staffProfileService.getStaffProfileById.mockResolvedValue(mockProfile);
      mockReq.params = { id: '123' };

      await staffProfileController.getStaffProfileById(mockReq, mockRes);

      expect(staffProfileService.getStaffProfileById).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.staff_profile.get.success', mockProfile);
    });
  });

  describe('createStaffProfile', () => {
    it('should call service and send success response', async () => {
      const mockData = { tenant_id: '123', user_id: 'user-1' };
      const mockProfile = { id: '456', ...mockData };
      staffProfileService.createStaffProfile.mockResolvedValue(mockProfile);
      mockReq.body = mockData;

      await staffProfileController.createStaffProfile(mockReq, mockRes);

      expect(staffProfileService.createStaffProfile).toHaveBeenCalledWith(mockData, 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 201, 'messages.staff_profile.create.success', mockProfile);
    });
  });

  describe('updateStaffProfile', () => {
    it('should call service and send success response', async () => {
      const mockData = { position: 'Senior Nurse' };
      const mockProfile = { id: '123', ...mockData };
      staffProfileService.updateStaffProfile.mockResolvedValue(mockProfile);
      mockReq.params = { id: '123' };
      mockReq.body = mockData;

      await staffProfileController.updateStaffProfile(mockReq, mockRes);

      expect(staffProfileService.updateStaffProfile).toHaveBeenCalledWith('123', mockData, 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.staff_profile.update.success', mockProfile);
    });
  });

  describe('deleteStaffProfile', () => {
    it('should call service and send no content response', async () => {
      staffProfileService.deleteStaffProfile.mockResolvedValue(undefined);
      mockReq.params = { id: '123' };

      await staffProfileController.deleteStaffProfile(mockReq, mockRes);

      expect(staffProfileService.deleteStaffProfile).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
