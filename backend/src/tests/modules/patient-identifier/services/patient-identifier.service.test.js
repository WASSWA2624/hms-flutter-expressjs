/**
 * Patient Identifier service tests
 *
 * @module tests/modules/patient-identifier/services
 * @description Tests for patient identifier service business logic
 * Per testing.mdc: Service tests must mock repository and audit functions
 */

const patientIdentifierService = require('@services/patient-identifier/patient-identifier.service');
const patientIdentifierRepository = require('@repositories/patient-identifier/patient-identifier.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/patient-identifier/patient-identifier.repository');
jest.mock('@lib/audit');

describe('Patient Identifier Service', () => {
  const mockUserId = 'user-123';
  const mockIpAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockReturnValue(Promise.resolve());
  });

  describe('listPatientIdentifiers', () => {
    it('should list patient identifiers with pagination', async () => {
      const mockIdentifiers = [{ id: '1', identifier_type: 'MRN' }];
      patientIdentifierRepository.findMany.mockResolvedValue(mockIdentifiers);
      patientIdentifierRepository.count.mockResolvedValue(1);

      const result = await patientIdentifierService.listPatientIdentifiers({}, 1, 20, 'created_at', 'desc', mockUserId, mockIpAddress);

      expect(result.patientIdentifiers).toEqual(mockIdentifiers);
      expect(result.pagination.total).toBe(1);
    });

    it('should apply filters correctly', async () => {
      patientIdentifierRepository.findMany.mockResolvedValue([]);
      patientIdentifierRepository.count.mockResolvedValue(0);

      await patientIdentifierService.listPatientIdentifiers({ identifier_type: 'MRN' }, 1, 20, null, 'asc', mockUserId, mockIpAddress);

      expect(patientIdentifierRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ identifier_type: expect.objectContaining({ contains: 'MRN' }) }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });
  });

  describe('getPatientIdentifierById', () => {
    it('should get patient identifier by id', async () => {
      const mockIdentifier = { id: '123', identifier_type: 'MRN' };
      patientIdentifierRepository.findById.mockResolvedValue(mockIdentifier);

      const result = await patientIdentifierService.getPatientIdentifierById('123', mockUserId, mockIpAddress);

      expect(result).toEqual(mockIdentifier);
    });

    it('should throw HttpError if not found', async () => {
      patientIdentifierRepository.findById.mockResolvedValue(null);

      await expect(
        patientIdentifierService.getPatientIdentifierById('nonexistent', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createPatientIdentifier', () => {
    it('should create patient identifier and log audit', async () => {
      const mockData = { tenant_id: '123', patient_id: '456', identifier_type: 'MRN', identifier_value: 'MRN123' };
      const mockIdentifier = { id: '789', ...mockData };
      patientIdentifierRepository.create.mockResolvedValue(mockIdentifier);

      const result = await patientIdentifierService.createPatientIdentifier(mockData, mockUserId, mockIpAddress);

      expect(result).toEqual(mockIdentifier);
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        user_id: mockUserId,
        action: 'CREATE',
        entity: 'patient_identifier'
      }));
    });
  });

  describe('updatePatientIdentifier', () => {
    it('should update patient identifier and log audit', async () => {
      const mockBefore = { id: '123', identifier_value: 'OLD' };
      const mockAfter = { id: '123', identifier_value: 'NEW' };
      patientIdentifierRepository.findById.mockResolvedValue(mockBefore);
      patientIdentifierRepository.update.mockResolvedValue(mockAfter);

      const result = await patientIdentifierService.updatePatientIdentifier('123', { identifier_value: 'NEW' }, mockUserId, mockIpAddress);

      expect(result).toEqual(mockAfter);
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'UPDATE',
        diff: { before: mockBefore, after: mockAfter }
      }));
    });

    it('should throw HttpError if not found', async () => {
      patientIdentifierRepository.findById.mockResolvedValue(null);

      await expect(
        patientIdentifierService.updatePatientIdentifier('nonexistent', {}, mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deletePatientIdentifier', () => {
    it('should soft delete patient identifier and log audit', async () => {
      const mockIdentifier = { id: '123', identifier_type: 'MRN' };
      patientIdentifierRepository.findById.mockResolvedValue(mockIdentifier);
      patientIdentifierRepository.softDelete.mockResolvedValue({ ...mockIdentifier, deleted_at: new Date() });

      await patientIdentifierService.deletePatientIdentifier('123', mockUserId, mockIpAddress);

      expect(patientIdentifierRepository.softDelete).toHaveBeenCalledWith('123');
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'DELETE',
        entity: 'patient_identifier'
      }));
    });

    it('should throw HttpError if not found', async () => {
      patientIdentifierRepository.findById.mockResolvedValue(null);

      await expect(
        patientIdentifierService.deletePatientIdentifier('nonexistent', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });
});
