/**
 * Patient Contact service tests
 *
 * @module tests/modules/patient-contact/services
 * @description Tests for patient contact service business logic
 * Per testing.mdc: Service tests must mock repository and audit functions
 */

const patientContactService = require('@services/patient-contact/patient-contact.service');
const patientContactRepository = require('@repositories/patient-contact/patient-contact.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/patient-contact/patient-contact.repository');
jest.mock('@lib/audit');

describe('Patient Contact Service', () => {
  const mockUserId = 'user-123';
  const mockIpAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockReturnValue(Promise.resolve());
  });

  describe('listPatientContacts', () => {
    it('should list patient contacts with pagination', async () => {
      const mockContacts = [{ id: '1', contact_type: 'PHONE' }];
      patientContactRepository.findMany.mockResolvedValue(mockContacts);
      patientContactRepository.count.mockResolvedValue(1);

      const result = await patientContactService.listPatientContacts({}, 1, 20, 'created_at', 'desc', mockUserId, mockIpAddress);

      expect(result.patientContacts).toEqual(mockContacts);
      expect(result.pagination.total).toBe(1);
    });

    it('should apply contact_type filter', async () => {
      patientContactRepository.findMany.mockResolvedValue([]);
      patientContactRepository.count.mockResolvedValue(0);

      await patientContactService.listPatientContacts({ contact_type: 'EMAIL' }, 1, 20, null, 'asc', mockUserId, mockIpAddress);

      expect(patientContactRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ contact_type: 'EMAIL' }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });
  });

  describe('getPatientContactById', () => {
    it('should get patient contact by id', async () => {
      const mockContact = { id: '123', contact_type: 'PHONE' };
      patientContactRepository.findById.mockResolvedValue(mockContact);

      const result = await patientContactService.getPatientContactById('123', mockUserId, mockIpAddress);

      expect(result).toEqual(mockContact);
    });

    it('should throw HttpError if not found', async () => {
      patientContactRepository.findById.mockResolvedValue(null);

      await expect(
        patientContactService.getPatientContactById('nonexistent', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createPatientContact', () => {
    it('should create patient contact and log audit', async () => {
      const mockData = { tenant_id: '123', patient_id: '456', contact_type: 'PHONE', value: '+256700000000' };
      const mockContact = { id: '789', ...mockData };
      patientContactRepository.create.mockResolvedValue(mockContact);

      const result = await patientContactService.createPatientContact(mockData, mockUserId, mockIpAddress);

      expect(result).toEqual(mockContact);
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        user_id: mockUserId,
        action: 'CREATE',
        entity: 'patient_contact'
      }));
    });
  });

  describe('updatePatientContact', () => {
    it('should update patient contact and log audit', async () => {
      const mockBefore = { id: '123', value: 'old@example.com' };
      const mockAfter = { id: '123', value: 'new@example.com' };
      patientContactRepository.findById.mockResolvedValue(mockBefore);
      patientContactRepository.update.mockResolvedValue(mockAfter);

      const result = await patientContactService.updatePatientContact('123', { value: 'new@example.com' }, mockUserId, mockIpAddress);

      expect(result).toEqual(mockAfter);
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'UPDATE',
        diff: { before: mockBefore, after: mockAfter }
      }));
    });

    it('should throw HttpError if not found', async () => {
      patientContactRepository.findById.mockResolvedValue(null);

      await expect(
        patientContactService.updatePatientContact('nonexistent', {}, mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deletePatientContact', () => {
    it('should soft delete patient contact and log audit', async () => {
      const mockContact = { id: '123', contact_type: 'PHONE' };
      patientContactRepository.findById.mockResolvedValue(mockContact);
      patientContactRepository.softDelete.mockResolvedValue({ ...mockContact, deleted_at: new Date() });

      await patientContactService.deletePatientContact('123', mockUserId, mockIpAddress);

      expect(patientContactRepository.softDelete).toHaveBeenCalledWith('123');
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'DELETE',
        entity: 'patient_contact'
      }));
    });

    it('should throw HttpError if not found', async () => {
      patientContactRepository.findById.mockResolvedValue(null);

      await expect(
        patientContactService.deletePatientContact('nonexistent', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });
});
