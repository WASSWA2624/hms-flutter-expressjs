/**
 * Patient Guardian service tests
 *
 * @module tests/modules/patient-guardian/services
 * @description Tests for patient guardian service business logic
 * Per testing.mdc: Service tests must mock repository and audit functions
 */

const patientGuardianService = require('@services/patient-guardian/patient-guardian.service');
const patientGuardianRepository = require('@repositories/patient-guardian/patient-guardian.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/patient-guardian/patient-guardian.repository');
jest.mock('@lib/audit');

describe('Patient Guardian Service', () => {
  const mockUserId = 'user-123';
  const mockIpAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockReturnValue(Promise.resolve());
  });

  describe('listPatientGuardians', () => {
    it('should list patient guardians with pagination', async () => {
      const mockGuardians = [{ id: '1', name: 'Jane Doe' }];
      patientGuardianRepository.findMany.mockResolvedValue(mockGuardians);
      patientGuardianRepository.count.mockResolvedValue(1);

      const result = await patientGuardianService.listPatientGuardians({}, 1, 20, 'created_at', 'desc', mockUserId, mockIpAddress);

      expect(result.patientGuardians).toEqual(mockGuardians);
      expect(result.pagination.total).toBe(1);
      expect(result.pagination.page).toBe(1);
      expect(result.pagination.limit).toBe(20);
    });

    it('should apply search filter', async () => {
      patientGuardianRepository.findMany.mockResolvedValue([]);
      patientGuardianRepository.count.mockResolvedValue(0);

      await patientGuardianService.listPatientGuardians({ search: 'Jane' }, 1, 20, null, 'asc', mockUserId, mockIpAddress);

      expect(patientGuardianRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ OR: expect.any(Array) }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should calculate pagination correctly', async () => {
      patientGuardianRepository.findMany.mockResolvedValue([]);
      patientGuardianRepository.count.mockResolvedValue(100);

      const result = await patientGuardianService.listPatientGuardians({}, 2, 20, null, 'asc', mockUserId, mockIpAddress);

      expect(result.pagination.totalPages).toBe(5);
      expect(result.pagination.hasNextPage).toBe(true);
      expect(result.pagination.hasPreviousPage).toBe(true);
    });
  });

  describe('getPatientGuardianById', () => {
    it('should get patient guardian by id', async () => {
      const mockGuardian = { id: '123', name: 'Jane Doe' };
      patientGuardianRepository.findById.mockResolvedValue(mockGuardian);

      const result = await patientGuardianService.getPatientGuardianById('123', mockUserId, mockIpAddress);

      expect(result).toEqual(mockGuardian);
      expect(patientGuardianRepository.findById).toHaveBeenCalledWith('123');
    });

    it('should throw HttpError if not found', async () => {
      patientGuardianRepository.findById.mockResolvedValue(null);

      await expect(
        patientGuardianService.getPatientGuardianById('nonexistent', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createPatientGuardian', () => {
    it('should create patient guardian and log audit', async () => {
      const mockData = {
        tenant_id: '123',
        patient_id: '456',
        name: 'Jane Doe',
        relationship: 'Mother'
      };
      const mockGuardian = { id: '789', ...mockData };
      patientGuardianRepository.create.mockResolvedValue(mockGuardian);

      const result = await patientGuardianService.createPatientGuardian(mockData, mockUserId, mockIpAddress);

      expect(result).toEqual(mockGuardian);
      expect(patientGuardianRepository.create).toHaveBeenCalledWith(mockData);
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        user_id: mockUserId,
        action: 'CREATE',
        entity: 'patient_guardian',
        entity_id: '789',
        ip_address: mockIpAddress
      }));
    });
  });

  describe('updatePatientGuardian', () => {
    it('should update patient guardian and log audit', async () => {
      const mockBefore = { id: '123', name: 'Jane Doe' };
      const mockAfter = { id: '123', name: 'Jane Smith' };
      patientGuardianRepository.findById.mockResolvedValue(mockBefore);
      patientGuardianRepository.update.mockResolvedValue(mockAfter);

      const result = await patientGuardianService.updatePatientGuardian('123', { name: 'Jane Smith' }, mockUserId, mockIpAddress);

      expect(result).toEqual(mockAfter);
      expect(patientGuardianRepository.update).toHaveBeenCalledWith('123', { name: 'Jane Smith' });
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'UPDATE',
        entity: 'patient_guardian',
        diff: { before: mockBefore, after: mockAfter }
      }));
    });

    it('should throw HttpError if not found', async () => {
      patientGuardianRepository.findById.mockResolvedValue(null);

      await expect(
        patientGuardianService.updatePatientGuardian('nonexistent', {}, mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deletePatientGuardian', () => {
    it('should soft delete patient guardian and log audit', async () => {
      const mockGuardian = { id: '123', name: 'Jane Doe' };
      patientGuardianRepository.findById.mockResolvedValue(mockGuardian);
      patientGuardianRepository.softDelete.mockResolvedValue({ ...mockGuardian, deleted_at: new Date() });

      await patientGuardianService.deletePatientGuardian('123', mockUserId, mockIpAddress);

      expect(patientGuardianRepository.softDelete).toHaveBeenCalledWith('123');
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'DELETE',
        entity: 'patient_guardian',
        entity_id: '123',
        diff: { before: mockGuardian }
      }));
    });

    it('should throw HttpError if not found', async () => {
      patientGuardianRepository.findById.mockResolvedValue(null);

      await expect(
        patientGuardianService.deletePatientGuardian('nonexistent', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });
});
