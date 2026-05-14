/**
 * Patient Contact controller tests
 *
 * @module tests/modules/patient-contact/controllers
 * @description Tests for patient contact controller request handlers
 * Per testing.mdc: Controller tests must mock service layer
 */

const patientContactController = require('@controllers/patient-contact/patient-contact.controller');
const patientContactService = require('@services/patient-contact/patient-contact.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@services/patient-contact/patient-contact.service');
jest.mock('@lib/response');
jest.mock('@config/constants', () => ({
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_LIMIT: 20
}));

describe('Patient Contact Controller', () => {
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

  describe('listPatientContacts', () => {
    it('should call service and send paginated response', async () => {
      const mockResult = {
        patientContacts: [{ id: '1', contact_type: 'PHONE' }],
        pagination: { page: 1, limit: 20, total: 1 }
      };
      patientContactService.listPatientContacts.mockResolvedValue(mockResult);

      await patientContactController.listPatientContacts(mockReq, mockRes);

      expect(patientContactService.listPatientContacts).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.patient_contact.list.success',
        mockResult.patientContacts,
        mockResult.pagination
      );
    });
  });

  describe('getPatientContactById', () => {
    it('should call service and send success response', async () => {
      mockReq.params.id = '123';
      const mockContact = { id: '123', contact_type: 'PHONE' };
      patientContactService.getPatientContactById.mockResolvedValue(mockContact);

      await patientContactController.getPatientContactById(mockReq, mockRes);

      expect(patientContactService.getPatientContactById).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.patient_contact.get.success', mockContact);
    });
  });

  describe('createPatientContact', () => {
    it('should call service and send success response with 201 status', async () => {
      mockReq.body = { tenant_id: '123', patient_id: '456', contact_type: 'PHONE', value: '+256700000000' };
      const mockContact = { id: '789', ...mockReq.body };
      patientContactService.createPatientContact.mockResolvedValue(mockContact);

      await patientContactController.createPatientContact(mockReq, mockRes);

      expect(patientContactService.createPatientContact).toHaveBeenCalledWith(mockReq.body, 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 201, 'messages.patient_contact.create.success', mockContact);
    });
  });

  describe('updatePatientContact', () => {
    it('should call service and send success response', async () => {
      mockReq.params.id = '123';
      mockReq.body = { value: 'updated@example.com' };
      const mockContact = { id: '123', value: 'updated@example.com' };
      patientContactService.updatePatientContact.mockResolvedValue(mockContact);

      await patientContactController.updatePatientContact(mockReq, mockRes);

      expect(patientContactService.updatePatientContact).toHaveBeenCalledWith('123', mockReq.body, 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.patient_contact.update.success', mockContact);
    });
  });

  describe('deletePatientContact', () => {
    it('should call service and send no content response', async () => {
      mockReq.params.id = '123';
      patientContactService.deletePatientContact.mockResolvedValue();

      await patientContactController.deletePatientContact(mockReq, mockRes);

      expect(patientContactService.deletePatientContact).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
