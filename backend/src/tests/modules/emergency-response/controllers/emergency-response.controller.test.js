/**
 * Emergency response controller tests
 *
 * @module tests/modules/emergency-response/controllers
 * @description Tests for emergency response controller request handlers
 */

const emergencyResponseController = require('../../../../modules/emergency-response/controllers/emergency-response.controller');
const emergencyResponseService = require('../../../../modules/emergency-response/services/emergency-response.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

// Mock dependencies
jest.mock('../../../../modules/emergency-response/services/emergency-response.service');
jest.mock('@lib/response');

describe('Emergency Response Controller', () => {
  let mockReq;
  let mockRes;

  beforeEach(() => {
    mockReq = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-id', tenant_id: 'tenant-id' }
    };
    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
    jest.clearAllMocks();
  });

  describe('listEmergencyResponses', () => {
    it('should list emergency responses with pagination', async () => {
      const mockResult = {
        items: [{ id: '1' }, { id: '2' }],
        total: 2,
        page: 1,
        limit: 20,
        totalPages: 1
      };

      emergencyResponseService.listEmergencyResponses.mockResolvedValue(mockResult);

      await emergencyResponseController.listEmergencyResponses(mockReq, mockRes);

      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.emergency_response.list.success',
        mockResult.items,
        {
          page: 1,
          limit: 20,
          total: 2,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      );
    });
  });

  describe('getEmergencyResponseById', () => {
    it('should return emergency response by id', async () => {
      const mockResponse = { id: 'test-id', emergency_case_id: 'case-id' };

      mockReq.params = { id: 'test-id' };
      emergencyResponseService.getEmergencyResponseById.mockResolvedValue(mockResponse);

      await emergencyResponseController.getEmergencyResponseById(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('createEmergencyResponse', () => {
    it('should create emergency response', async () => {
      const responseData = {
        emergency_case_id: 'case-id',
        notes: 'test notes'
      };
      const mockCreated = { id: 'new-id', ...responseData };

      mockReq.body = responseData;
      emergencyResponseService.createEmergencyResponse.mockResolvedValue(mockCreated);

      await emergencyResponseController.createEmergencyResponse(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 201, expect.any(String), mockCreated);
    });
  });

  describe('updateEmergencyResponse', () => {
    it('should update emergency response', async () => {
      const updateData = { notes: 'updated notes' };
      const mockUpdated = { id: 'test-id', ...updateData };

      mockReq.params = { id: 'test-id' };
      mockReq.body = updateData;
      emergencyResponseService.updateEmergencyResponse.mockResolvedValue(mockUpdated);

      await emergencyResponseController.updateEmergencyResponse(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('deleteEmergencyResponse', () => {
    it('should delete emergency response', async () => {
      mockReq.params = { id: 'test-id' };
      emergencyResponseService.deleteEmergencyResponse.mockResolvedValue({});

      await emergencyResponseController.deleteEmergencyResponse(mockReq, mockRes);

      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
