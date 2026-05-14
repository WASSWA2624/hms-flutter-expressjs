/**
 * Triage assessment controller tests
 *
 * @module tests/modules/triage-assessment/controllers
 * @description Tests for triage assessment controller request handlers
 */

const triageAssessmentController = require('../../../../modules/triage-assessment/controllers/triage-assessment.controller');
const triageAssessmentService = require('../../../../modules/triage-assessment/services/triage-assessment.service');

// Mock dependencies
jest.mock('../../../../modules/triage-assessment/services/triage-assessment.service');
jest.mock('@lib/response', () => ({
  sendSuccess: jest.fn(),
  sendPaginated: jest.fn(),
  sendNoContent: jest.fn()
}));

const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

describe('Triage Assessment Controller', () => {
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

  describe('listTriageAssessments', () => {
    it('should list triage assessments with pagination', async () => {
      const mockResult = {
        items: [{ id: '1' }, { id: '2' }],
        total: 2,
        page: 1,
        limit: 20,
        totalPages: 1
      };

      triageAssessmentService.listTriageAssessments.mockResolvedValue(mockResult);

      await triageAssessmentController.listTriageAssessments(mockReq, mockRes);

      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.triage_assessment.list.success',
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

  describe('getTriageAssessmentById', () => {
    it('should return triage assessment by id', async () => {
      const mockAssessment = { id: 'test-id', triage_level: 'URGENT' };

      mockReq.params = { id: 'test-id' };
      triageAssessmentService.getTriageAssessmentById.mockResolvedValue(mockAssessment);

      await triageAssessmentController.getTriageAssessmentById(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('createTriageAssessment', () => {
    it('should create triage assessment', async () => {
      const assessmentData = {
        emergency_case_id: 'case-id',
        triage_level: 'URGENT'
      };
      const mockCreated = { id: 'new-id', ...assessmentData };

      mockReq.body = assessmentData;
      triageAssessmentService.createTriageAssessment.mockResolvedValue(mockCreated);

      await triageAssessmentController.createTriageAssessment(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        201,
        'messages.triage_assessment.create.success',
        mockCreated
      );
    });
  });

  describe('updateTriageAssessment', () => {
    it('should update triage assessment', async () => {
      const updateData = { triage_level: 'IMMEDIATE' };
      const mockUpdated = { id: 'test-id', ...updateData };

      mockReq.params = { id: 'test-id' };
      mockReq.body = updateData;
      triageAssessmentService.updateTriageAssessment.mockResolvedValue(mockUpdated);

      await triageAssessmentController.updateTriageAssessment(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('deleteTriageAssessment', () => {
    it('should delete triage assessment', async () => {
      mockReq.params = { id: 'test-id' };
      triageAssessmentService.deleteTriageAssessment.mockResolvedValue({});

      await triageAssessmentController.deleteTriageAssessment(mockReq, mockRes);

      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
