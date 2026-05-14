/**
 * Patient Guardian controller tests
 *
 * @module tests/modules/patient-guardian/controllers
 * @description Tests for patient guardian controller request handlers
 * Per testing.mdc: Controller tests must mock service layer
 */

const patientGuardianController = require('@controllers/patient-guardian/patient-guardian.controller');
const patientGuardianService = require('@services/patient-guardian/patient-guardian.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@services/patient-guardian/patient-guardian.service');
jest.mock('@lib/response');
jest.mock('@config/constants', () => ({
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_LIMIT: 20
}));

describe('Patient Guardian Controller', () => {
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

  describe('listPatientGuardians', () => {
    it('should call service and send paginated response', async () => {
      const mockResult = {
        patientGuardians: [{ id: '1', name: 'Jane Doe' }],
        pagination: { page: 1, limit: 20, total: 1 }
      };
      patientGuardianService.listPatientGuardians.mockResolvedValue(mockResult);

      await patientGuardianController.listPatientGuardians(mockReq, mockRes);

      expect(patientGuardianService.listPatientGuardians).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.patient_guardian.list.success',
        mockResult.patientGuardians,
        mockResult.pagination
      );
    });

    it('should parse query parameters correctly', async () => {
      mockReq.query = {
        page: '3',
        limit: '10',
        sort_by: 'name',
        order: 'asc',
        search: 'Jane'
      };
      patientGuardianService.listPatientGuardians.mockResolvedValue({
        patientGuardians: [],
        pagination: {}
      });

      await patientGuardianController.listPatientGuardians(mockReq, mockRes);

      expect(patientGuardianService.listPatientGuardians).toHaveBeenCalledWith(
        expect.objectContaining({ search: 'Jane' }),
        3,
        10,
        'name',
        'asc',
        'user-123',
        '127.0.0.1'
      );
    });
  });

  describe('getPatientGuardianById', () => {
    it('should call service and send success response', async () => {
      mockReq.params.id = '123';
      const mockGuardian = { id: '123', name: 'Jane Doe' };
      patientGuardianService.getPatientGuardianById.mockResolvedValue(mockGuardian);

      await patientGuardianController.getPatientGuardianById(mockReq, mockRes);

      expect(patientGuardianService.getPatientGuardianById).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.patient_guardian.get.success', mockGuardian);
    });
  });

  describe('createPatientGuardian', () => {
    it('should call service and send success response with 201 status', async () => {
      mockReq.body = {
        tenant_id: '123',
        patient_id: '456',
        name: 'Jane Doe',
        relationship: 'Mother'
      };
      const mockGuardian = { id: '789', ...mockReq.body };
      patientGuardianService.createPatientGuardian.mockResolvedValue(mockGuardian);

      await patientGuardianController.createPatientGuardian(mockReq, mockRes);

      expect(patientGuardianService.createPatientGuardian).toHaveBeenCalledWith(mockReq.body, 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 201, 'messages.patient_guardian.create.success', mockGuardian);
    });
  });

  describe('updatePatientGuardian', () => {
    it('should call service and send success response', async () => {
      mockReq.params.id = '123';
      mockReq.body = { name: 'Jane Smith' };
      const mockGuardian = { id: '123', name: 'Jane Smith' };
      patientGuardianService.updatePatientGuardian.mockResolvedValue(mockGuardian);

      await patientGuardianController.updatePatientGuardian(mockReq, mockRes);

      expect(patientGuardianService.updatePatientGuardian).toHaveBeenCalledWith('123', mockReq.body, 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.patient_guardian.update.success', mockGuardian);
    });
  });

  describe('deletePatientGuardian', () => {
    it('should call service and send no content response', async () => {
      mockReq.params.id = '123';
      patientGuardianService.deletePatientGuardian.mockResolvedValue();

      await patientGuardianController.deletePatientGuardian(mockReq, mockRes);

      expect(patientGuardianService.deletePatientGuardian).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
