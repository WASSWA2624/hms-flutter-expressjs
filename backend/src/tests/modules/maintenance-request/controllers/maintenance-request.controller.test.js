/**
 * Maintenance request controller tests
 *
 * @module tests/modules/maintenance-request/controllers
 * @description Tests for maintenance request controller request handlers
 */

const maintenanceRequestController = require('../../../../modules/maintenance-request/controllers/maintenance-request.controller');
const maintenanceRequestService = require('../../../../modules/maintenance-request/services/maintenance-request.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

// Mock service and response helpers
jest.mock('../../../../modules/maintenance-request/services/maintenance-request.service');
jest.mock('@lib/response');

describe('Maintenance Request Controller', () => {
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
      json: jest.fn()
    };
  });

  describe('listMaintenanceRequests', () => {
    it('should list maintenance requests with pagination', async () => {
      const mockResult = {
        maintenanceRequests: [{ id: '1' }, { id: '2' }],
        pagination: { page: 1, limit: 20, total: 2 }
      };

      maintenanceRequestService.listMaintenanceRequests.mockResolvedValue(mockResult);

      mockReq.query = {
        page: '1',
        limit: '20',
        sort_by: 'created_at',
        order: 'desc'
      };

      await maintenanceRequestController.listMaintenanceRequests(mockReq, mockRes);

      expect(maintenanceRequestService.listMaintenanceRequests).toHaveBeenCalledWith(
        expect.any(Object),
        1,
        20,
        'created_at',
        'desc',
        'user-123',
        '127.0.0.1'
      );

      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.maintenance_request.list.success',
        mockResult.maintenanceRequests,
        mockResult.pagination
      );
    });

    it('should apply filters from query parameters', async () => {
      const mockResult = {
        maintenanceRequests: [],
        pagination: { page: 1, limit: 20, total: 0 }
      };

      maintenanceRequestService.listMaintenanceRequests.mockResolvedValue(mockResult);

      mockReq.query = {
        facility_id: '123',
        asset_id: '456',
        status: 'OPEN',
        search: 'repair'
      };

      await maintenanceRequestController.listMaintenanceRequests(mockReq, mockRes);

      expect(maintenanceRequestService.listMaintenanceRequests).toHaveBeenCalledWith(
        expect.objectContaining({
          facility_id: '123',
          asset_id: '456',
          status: 'OPEN',
          search: 'repair'
        }),
        1,
        20,
        undefined,
        'asc',
        'user-123',
        '127.0.0.1'
      );
    });
  });

  describe('getMaintenanceRequestById', () => {
    it('should get maintenance request by ID', async () => {
      const mockRequest = { id: '1', status: 'OPEN' };
      maintenanceRequestService.getMaintenanceRequestById.mockResolvedValue(mockRequest);

      mockReq.params = { id: '1' };

      await maintenanceRequestController.getMaintenanceRequestById(mockReq, mockRes);

      expect(maintenanceRequestService.getMaintenanceRequestById).toHaveBeenCalledWith('1', 'user-123', '127.0.0.1');

      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.maintenance_request.get.success',
        mockRequest
      );
    });
  });

  describe('createMaintenanceRequest', () => {
    it('should create new maintenance request', async () => {
      const mockData = { facility_id: '123', status: 'OPEN' };
      const mockCreated = { id: '1', ...mockData };

      maintenanceRequestService.createMaintenanceRequest.mockResolvedValue(mockCreated);

      mockReq.body = mockData;

      await maintenanceRequestController.createMaintenanceRequest(mockReq, mockRes);

      expect(maintenanceRequestService.createMaintenanceRequest).toHaveBeenCalledWith(
        mockData,
        'user-123',
        '127.0.0.1'
      );

      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        201,
        'messages.maintenance_request.create.success',
        mockCreated
      );
    });
  });

  describe('updateMaintenanceRequest', () => {
    it('should update maintenance request', async () => {
      const mockData = { status: 'COMPLETED' };
      const mockUpdated = { id: '1', ...mockData };

      maintenanceRequestService.updateMaintenanceRequest.mockResolvedValue(mockUpdated);

      mockReq.params = { id: '1' };
      mockReq.body = mockData;

      await maintenanceRequestController.updateMaintenanceRequest(mockReq, mockRes);

      expect(maintenanceRequestService.updateMaintenanceRequest).toHaveBeenCalledWith(
        '1',
        mockData,
        'user-123',
        '127.0.0.1'
      );

      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.maintenance_request.update.success',
        mockUpdated
      );
    });
  });

  describe('deleteMaintenanceRequest', () => {
    it('should delete maintenance request', async () => {
      maintenanceRequestService.deleteMaintenanceRequest.mockResolvedValue();

      mockReq.params = { id: '1' };

      await maintenanceRequestController.deleteMaintenanceRequest(mockReq, mockRes);

      expect(maintenanceRequestService.deleteMaintenanceRequest).toHaveBeenCalledWith('1', 'user-123', '127.0.0.1');

      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
