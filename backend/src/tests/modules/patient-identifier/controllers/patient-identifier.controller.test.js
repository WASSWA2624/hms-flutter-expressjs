/**
 * Patient Identifier controller tests
 *
 * @module tests/modules/patient-identifier/controllers
 * @description Tests for patient identifier controller request handlers
 * Per testing.mdc: Controller tests must mock service layer
 */

const patientIdentifierController = require('@controllers/patient-identifier/patient-identifier.controller');
const patientIdentifierService = require('@services/patient-identifier/patient-identifier.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

jest.mock('@services/patient-identifier/patient-identifier.service');
jest.mock('@lib/response');
jest.mock('@config/constants', () => ({
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_LIMIT: 20
}));

describe('Patient Identifier Controller', () => {
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

  describe('listPatientIdentifiers', () => {
    it('should call service and send paginated response', async () => {
      const mockResult = {
        patientIdentifiers: [{ id: '1', identifier_type: 'MRN' }],
        pagination: { page: 1, limit: 20, total: 1 }
      };
      patientIdentifierService.listPatientIdentifiers.mockResolvedValue(mockResult);

      await patientIdentifierController.listPatientIdentifiers(mockReq, mockRes);

      expect(patientIdentifierService.listPatientIdentifiers).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.patient_identifier.list.success',
        mockResult.patientIdentifiers,
        mockResult.pagination
      );
    });

    it('should parse query parameters correctly', async () => {
      mockReq.query = {
        page: '2',
        limit: '50',
        sort_by: 'identifier_type',
        order: 'asc',
        tenant_id: '123'
      };
      patientIdentifierService.listPatientIdentifiers.mockResolvedValue({
        patientIdentifiers: [],
        pagination: {}
      });

      await patientIdentifierController.listPatientIdentifiers(mockReq, mockRes);

      expect(patientIdentifierService.listPatientIdentifiers).toHaveBeenCalledWith(
        expect.objectContaining({ tenant_id: '123' }),
        2,
        50,
        'identifier_type',
        'asc',
        'user-123',
        '127.0.0.1'
      );
    });
  });

  describe('getPatientIdentifierById', () => {
    it('should call service and send success response', async () => {
      mockReq.params.id = '123';
      const mockIdentifier = { id: '123', identifier_type: 'MRN' };
      patientIdentifierService.getPatientIdentifierById.mockResolvedValue(mockIdentifier);

      await patientIdentifierController.getPatientIdentifierById(mockReq, mockRes);

      expect(patientIdentifierService.getPatientIdentifierById).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.patient_identifier.get.success', mockIdentifier);
    });
  });

  describe('createPatientIdentifier', () => {
    it('should call service and send success response with 201 status', async () => {
      mockReq.body = { tenant_id: '123', patient_id: '456', identifier_type: 'MRN', identifier_value: 'MRN123' };
      const mockIdentifier = { id: '789', ...mockReq.body };
      patientIdentifierService.createPatientIdentifier.mockResolvedValue(mockIdentifier);

      await patientIdentifierController.createPatientIdentifier(mockReq, mockRes);

      expect(patientIdentifierService.createPatientIdentifier).toHaveBeenCalledWith(mockReq.body, 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 201, 'messages.patient_identifier.create.success', mockIdentifier);
    });
  });

  describe('updatePatientIdentifier', () => {
    it('should call service and send success response', async () => {
      mockReq.params.id = '123';
      mockReq.body = { identifier_value: 'UPDATED' };
      const mockIdentifier = { id: '123', identifier_value: 'UPDATED' };
      patientIdentifierService.updatePatientIdentifier.mockResolvedValue(mockIdentifier);

      await patientIdentifierController.updatePatientIdentifier(mockReq, mockRes);

      expect(patientIdentifierService.updatePatientIdentifier).toHaveBeenCalledWith('123', mockReq.body, 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.patient_identifier.update.success', mockIdentifier);
    });
  });

  describe('deletePatientIdentifier', () => {
    it('should call service and send no content response', async () => {
      mockReq.params.id = '123';
      patientIdentifierService.deletePatientIdentifier.mockResolvedValue();

      await patientIdentifierController.deletePatientIdentifier(mockReq, mockRes);

      expect(patientIdentifierService.deletePatientIdentifier).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
