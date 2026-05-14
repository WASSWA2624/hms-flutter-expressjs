/**
 * Emergency case controller tests
 *
 * @module tests/modules/emergency-case/controllers
 * @description Tests for emergency case controller request handlers
 */

const emergencyCaseController = require('../../../../modules/emergency-case/controllers/emergency-case.controller');
const emergencyCaseService = require('../../../../modules/emergency-case/services/emergency-case.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

// Mock dependencies
jest.mock('../../../../modules/emergency-case/services/emergency-case.service');
jest.mock('@lib/response');

describe('Emergency Case Controller', () => {
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

  describe('listEmergencyCases', () => {
    it('should list emergency cases with pagination', async () => {
      const mockResult = {
        items: [{ id: '1' }, { id: '2' }],
        total: 2,
        page: 1,
        limit: 20,
        totalPages: 1
      };

      mockReq.query = { page: '1', limit: '20' };
      emergencyCaseService.listEmergencyCases.mockResolvedValue(mockResult);

      await emergencyCaseController.listEmergencyCases(mockReq, mockRes);

      expect(emergencyCaseService.listEmergencyCases).toHaveBeenCalledWith(
        {},
        1,
        20,
        'created_at',
        'desc'
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.emergency_case.list.success',
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

    it('should apply filters from query params', async () => {
      mockReq.query = {
        tenant_id: 'tenant-id',
        severity: 'HIGH',
        status: 'PENDING'
      };

      emergencyCaseService.listEmergencyCases.mockResolvedValue({
        items: [],
        total: 0,
        page: 1,
        limit: 20,
        totalPages: 0
      });

      await emergencyCaseController.listEmergencyCases(mockReq, mockRes);

      const callArgs = emergencyCaseService.listEmergencyCases.mock.calls[0];
      expect(callArgs[0].tenant_id).toBe('tenant-id');
      expect(callArgs[0].severity).toBe('HIGH');
      expect(callArgs[0].status).toBe('PENDING');
    });

    it('should use default pagination values', async () => {
      emergencyCaseService.listEmergencyCases.mockResolvedValue({
        items: [],
        total: 0,
        page: 1,
        limit: 20,
        totalPages: 0
      });

      await emergencyCaseController.listEmergencyCases(mockReq, mockRes);

      expect(emergencyCaseService.listEmergencyCases).toHaveBeenCalledWith(
        expect.any(Object),
        1,
        20,
        'created_at',
        'desc'
      );
    });
  });

  describe('getEmergencyCaseById', () => {
    it('should return emergency case by id', async () => {
      const mockCase = { id: 'test-id', severity: 'HIGH' };

      mockReq.params = { id: 'test-id' };
      emergencyCaseService.getEmergencyCaseById.mockResolvedValue(mockCase);

      await emergencyCaseController.getEmergencyCaseById(mockReq, mockRes);

      expect(emergencyCaseService.getEmergencyCaseById).toHaveBeenCalledWith('test-id');
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.emergency_case.get.success',
        mockCase
      );
    });
  });

  describe('createEmergencyCase', () => {
    it('should create emergency case', async () => {
      const caseData = {
        tenant_id: 'tenant-id',
        patient_id: 'patient-id',
        severity: 'HIGH',
        status: 'PENDING'
      };
      const mockCreated = { id: 'new-id', ...caseData };

      mockReq.body = caseData;
      emergencyCaseService.createEmergencyCase.mockResolvedValue(mockCreated);

      await emergencyCaseController.createEmergencyCase(mockReq, mockRes);

      expect(emergencyCaseService.createEmergencyCase).toHaveBeenCalledWith(
        caseData,
        mockReq.user
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        201,
        'messages.emergency_case.create.success',
        mockCreated
      );
    });
  });

  describe('updateEmergencyCase', () => {
    it('should update emergency case', async () => {
      const updateData = { status: 'IN_PROGRESS' };
      const mockUpdated = { id: 'test-id', ...updateData };

      mockReq.params = { id: 'test-id' };
      mockReq.body = updateData;
      emergencyCaseService.updateEmergencyCase.mockResolvedValue(mockUpdated);

      await emergencyCaseController.updateEmergencyCase(mockReq, mockRes);

      expect(emergencyCaseService.updateEmergencyCase).toHaveBeenCalledWith(
        'test-id',
        updateData,
        mockReq.user
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.emergency_case.update.success',
        mockUpdated
      );
    });
  });

  describe('deleteEmergencyCase', () => {
    it('should delete emergency case', async () => {
      mockReq.params = { id: 'test-id' };
      emergencyCaseService.deleteEmergencyCase.mockResolvedValue({});

      await emergencyCaseController.deleteEmergencyCase(mockReq, mockRes);

      expect(emergencyCaseService.deleteEmergencyCase).toHaveBeenCalledWith(
        'test-id',
        mockReq.user
      );
      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
