/**
 * Admission controller tests
 *
 * @module tests/modules/admission/controllers
 * @description Tests for admission controller request handlers
 */

const admissionController = require('../../../../modules/admission/controllers/admission.controller');
const admissionService = require('../../../../modules/admission/services/admission.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

// Mock dependencies
jest.mock('../../../../modules/admission/services/admission.service');
jest.mock('@lib/response');

describe('Admission Controller', () => {
  let mockReq;
  let mockRes;

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

  describe('listAdmissions', () => {
    it('should list admissions with pagination', async () => {
      const mockResult = {
        admissions: [{ id: '1' }, { id: '2' }],
        pagination: {
          page: 1,
          limit: 20,
          total: 2,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };

      mockReq.query = { page: '1', limit: '20' };
      admissionService.listAdmissions.mockResolvedValue(mockResult);

      await admissionController.listAdmissions(mockReq, mockRes);

      expect(admissionService.listAdmissions).toHaveBeenCalledWith(
        expect.any(Object),
        1,
        20,
        undefined,
        'asc',
        'user-id',
        '127.0.0.1'
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.admission.list.success',
        mockResult.admissions,
        mockResult.pagination
      );
    });

    it('should apply filters from query params', async () => {
      mockReq.query = {
        tenant_id: 'tenant-id',
        status: 'ADMITTED'
      };

      admissionService.listAdmissions.mockResolvedValue({
        admissions: [],
        pagination: {}
      });

      await admissionController.listAdmissions(mockReq, mockRes);

      const callArgs = admissionService.listAdmissions.mock.calls[0];
      expect(callArgs[0].tenant_id).toBe('tenant-id');
      expect(callArgs[0].status).toBe('ADMITTED');
      expect(callArgs[5]).toBe('user-id');
      expect(callArgs[6]).toBe('127.0.0.1');
    });
  });

  describe('getAdmissionById', () => {
    it('should return admission by id', async () => {
      const mockAdmission = { id: 'test-id', status: 'ADMITTED' };

      mockReq.params = { id: 'test-id' };
      admissionService.getAdmissionById.mockResolvedValue(mockAdmission);

      await admissionController.getAdmissionById(mockReq, mockRes);

      expect(admissionService.getAdmissionById).toHaveBeenCalledWith(
        'test-id',
        'user-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.admission.get.success',
        mockAdmission
      );
    });
  });

  describe('createAdmission', () => {
    it('should create new admission', async () => {
      const admissionData = {
        tenant_id: 'tenant-id',
        patient_id: 'patient-id',
        status: 'ADMITTED'
      };
      const mockCreatedAdmission = { id: 'new-id', ...admissionData };

      mockReq.body = admissionData;
      admissionService.createAdmission.mockResolvedValue(mockCreatedAdmission);

      await admissionController.createAdmission(mockReq, mockRes);

      expect(admissionService.createAdmission).toHaveBeenCalledWith(
        admissionData,
        'user-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        201,
        'messages.admission.create.success',
        mockCreatedAdmission
      );
    });
  });

  describe('updateAdmission', () => {
    it('should update admission', async () => {
      const updateData = { status: 'DISCHARGED' };
      const mockUpdatedAdmission = { id: 'test-id', status: 'DISCHARGED' };

      mockReq.params = { id: 'test-id' };
      mockReq.body = updateData;
      admissionService.updateAdmission.mockResolvedValue(mockUpdatedAdmission);

      await admissionController.updateAdmission(mockReq, mockRes);

      expect(admissionService.updateAdmission).toHaveBeenCalledWith(
        'test-id',
        updateData,
        'user-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.admission.update.success',
        mockUpdatedAdmission
      );
    });
  });

  describe('deleteAdmission', () => {
    it('should delete admission', async () => {
      mockReq.params = { id: 'test-id' };
      admissionService.deleteAdmission.mockResolvedValue();

      await admissionController.deleteAdmission(mockReq, mockRes);

      expect(admissionService.deleteAdmission).toHaveBeenCalledWith(
        'test-id',
        'user-id',
        '127.0.0.1'
      );
      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });

  describe('dischargeAdmission', () => {
    it('should discharge admission', async () => {
      const dischargeData = { discharged_at: '2026-01-20T10:00:00Z' };
      const mockDischargedAdmission = {
        id: 'test-id',
        status: 'DISCHARGED',
        discharged_at: '2026-01-20T10:00:00Z'
      };

      mockReq.params = { id: 'test-id' };
      mockReq.body = dischargeData;
      admissionService.dischargeAdmission.mockResolvedValue(mockDischargedAdmission);

      await admissionController.dischargeAdmission(mockReq, mockRes);

      expect(admissionService.dischargeAdmission).toHaveBeenCalledWith(
        'test-id',
        dischargeData,
        'user-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.admission.discharge.success',
        mockDischargedAdmission
      );
    });
  });
});
