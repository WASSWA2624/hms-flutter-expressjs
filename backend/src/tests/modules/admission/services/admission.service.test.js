/**
 * Admission service tests
 *
 * @module tests/modules/admission/services
 * @description Tests for admission service business logic
 */

const admissionService = require('../../../../modules/admission/services/admission.service');
const admissionRepository = require('../../../../modules/admission/repositories/admission.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('../../../../modules/admission/repositories/admission.repository');
jest.mock('@lib/audit');

describe('Admission Service', () => {
  const mockUserId = 'user-id';
  const mockIpAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  describe('listAdmissions', () => {
    it('should list admissions with pagination', async () => {
      const mockAdmissions = [
        { id: '1', status: 'ADMITTED' },
        { id: '2', status: 'DISCHARGED' }
      ];

      admissionRepository.findMany.mockResolvedValue(mockAdmissions);
      admissionRepository.count.mockResolvedValue(2);

      const result = await admissionService.listAdmissions({}, 1, 10, 'created_at', 'desc', mockUserId, mockIpAddress);

      expect(result.admissions).toEqual(mockAdmissions);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 10,
        total: 2,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
    });

    it('should apply filters correctly', async () => {
      const filters = {
        tenant_id: 'tenant-id',
        status: 'ADMITTED'
      };

      admissionRepository.findMany.mockResolvedValue([]);
      admissionRepository.count.mockResolvedValue(0);

      await admissionService.listAdmissions(filters, 1, 10, null, 'asc', mockUserId, mockIpAddress);

      expect(admissionRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining(filters),
        0,
        10,
        { created_at: 'desc' }
      );
    });

    it('should throw HttpError on repository error', async () => {
      admissionRepository.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(
        admissionService.listAdmissions({}, 1, 10, null, 'asc', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('getAdmissionById', () => {
    it('should return admission by id', async () => {
      const mockAdmission = { id: 'test-id', status: 'ADMITTED' };

      admissionRepository.findById.mockResolvedValue(mockAdmission);

      const result = await admissionService.getAdmissionById('test-id', mockUserId, mockIpAddress);

      expect(result).toEqual(mockAdmission);
    });

    it('should throw HttpError if admission not found', async () => {
      admissionRepository.findById.mockResolvedValue(null);

      await expect(
        admissionService.getAdmissionById('non-existent', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createAdmission', () => {
    it('should create admission and audit log', async () => {
      const admissionData = {
        tenant_id: 'tenant-id',
        patient_id: 'patient-id',
        status: 'ADMITTED'
      };
      const mockCreatedAdmission = { id: 'new-id', ...admissionData };

      admissionRepository.create.mockResolvedValue(mockCreatedAdmission);

      const result = await admissionService.createAdmission(admissionData, mockUserId, mockIpAddress);

      expect(result).toEqual(mockCreatedAdmission);
      expect(admissionRepository.create).toHaveBeenCalledWith(admissionData);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: mockUserId,
        action: 'CREATE',
        entity: 'admission',
        entity_id: mockCreatedAdmission.id,
        diff: { after: mockCreatedAdmission },
        ip_address: mockIpAddress
      });
    });

    it('should throw HttpError on repository error', async () => {
      admissionRepository.create.mockRejectedValue(new HttpError('errors.database.unexpected', 500));

      await expect(
        admissionService.createAdmission({}, mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('updateAdmission', () => {
    it('should update admission and create audit log', async () => {
      const before = { id: 'test-id', status: 'ADMITTED' };
      const updateData = { status: 'DISCHARGED' };
      const after = { id: 'test-id', status: 'DISCHARGED' };

      admissionRepository.findById.mockResolvedValue(before);
      admissionRepository.update.mockResolvedValue(after);

      const result = await admissionService.updateAdmission('test-id', updateData, mockUserId, mockIpAddress);

      expect(result).toEqual(after);
      expect(admissionRepository.update).toHaveBeenCalledWith('test-id', updateData);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: mockUserId,
        action: 'UPDATE',
        entity: 'admission',
        entity_id: after.id,
        diff: { before, after },
        ip_address: mockIpAddress
      });
    });

    it('should throw HttpError if admission not found', async () => {
      admissionRepository.findById.mockResolvedValue(null);

      await expect(
        admissionService.updateAdmission('non-existent', {}, mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deleteAdmission', () => {
    it('should soft delete admission and create audit log', async () => {
      const before = { id: 'test-id', status: 'ADMITTED' };

      admissionRepository.findById.mockResolvedValue(before);
      admissionRepository.softDelete.mockResolvedValue({});

      await admissionService.deleteAdmission('test-id', mockUserId, mockIpAddress);

      expect(admissionRepository.softDelete).toHaveBeenCalledWith('test-id');
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: mockUserId,
        action: 'DELETE',
        entity: 'admission',
        entity_id: 'test-id',
        diff: { before },
        ip_address: mockIpAddress
      });
    });

    it('should throw HttpError if admission not found', async () => {
      admissionRepository.findById.mockResolvedValue(null);

      await expect(
        admissionService.deleteAdmission('non-existent', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('dischargeAdmission', () => {
    it('should discharge admission with provided date', async () => {
      const before = { id: 'test-id', status: 'ADMITTED', discharged_at: null };
      const dischargeData = { discharged_at: '2026-01-20T10:00:00Z' };
      const after = { id: 'test-id', status: 'DISCHARGED', discharged_at: '2026-01-20T10:00:00Z' };

      admissionRepository.findById.mockResolvedValue(before);
      admissionRepository.update.mockResolvedValue(after);

      const result = await admissionService.dischargeAdmission('test-id', dischargeData, mockUserId, mockIpAddress);

      expect(result).toEqual(after);
      expect(admissionRepository.update).toHaveBeenCalledWith('test-id', {
        status: 'DISCHARGED',
        discharged_at: dischargeData.discharged_at
      });
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: mockUserId,
        action: 'DISCHARGE',
        entity: 'admission',
        entity_id: 'test-id',
        diff: { before, after },
        ip_address: mockIpAddress
      });
    });

    it('should discharge admission with current date if not provided', async () => {
      const before = { id: 'test-id', status: 'ADMITTED', discharged_at: null };
      const after = { id: 'test-id', status: 'DISCHARGED', discharged_at: expect.any(String) };

      admissionRepository.findById.mockResolvedValue(before);
      admissionRepository.update.mockResolvedValue(after);

      await admissionService.dischargeAdmission('test-id', {}, mockUserId, mockIpAddress);

      expect(admissionRepository.update).toHaveBeenCalledWith('test-id', {
        status: 'DISCHARGED',
        discharged_at: expect.any(String)
      });
    });

    it('should throw HttpError if admission not found', async () => {
      admissionRepository.findById.mockResolvedValue(null);

      await expect(
        admissionService.dischargeAdmission('non-existent', {}, mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });

    it('should throw HttpError if already discharged', async () => {
      const before = { id: 'test-id', status: 'DISCHARGED', discharged_at: '2026-01-19T10:00:00Z' };

      admissionRepository.findById.mockResolvedValue(before);

      await expect(
        admissionService.dischargeAdmission('test-id', {}, mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });
});
