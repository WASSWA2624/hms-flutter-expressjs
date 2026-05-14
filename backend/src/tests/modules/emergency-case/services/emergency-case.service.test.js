/**
 * Emergency case service tests
 *
 * @module tests/modules/emergency-case/services
 * @description Tests for emergency case service business logic
 */

const emergencyCaseService = require('../../../../modules/emergency-case/services/emergency-case.service');
const emergencyCaseRepository = require('../../../../modules/emergency-case/repositories/emergency-case.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('../../../../modules/emergency-case/repositories/emergency-case.repository');
jest.mock('@lib/audit');

describe('Emergency Case Service', () => {
  const mockUser = { id: 'user-id', tenant_id: 'tenant-id' };

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  describe('listEmergencyCases', () => {
    it('should list emergency cases with pagination', async () => {
      const mockCases = [
        { id: '1', severity: 'HIGH', status: 'PENDING' },
        { id: '2', severity: 'CRITICAL', status: 'IN_PROGRESS' }
      ];

      emergencyCaseRepository.findMany.mockResolvedValue(mockCases);
      emergencyCaseRepository.count.mockResolvedValue(2);

      const result = await emergencyCaseService.listEmergencyCases({}, 1, 10, 'created_at', 'desc');

      expect(result.items).toEqual([
        expect.objectContaining(mockCases[0]),
        expect.objectContaining(mockCases[1]),
      ]);
      expect(result.items[0]).toEqual(expect.objectContaining({ display_id: '1' }));
      expect(result.total).toBe(2);
      expect(result.page).toBe(1);
      expect(result.limit).toBe(10);
      expect(result.totalPages).toBe(1);
    });

    it('should apply filters correctly', async () => {
      const filters = {
        tenant_id: 'tenant-id',
        severity: 'HIGH'
      };

      emergencyCaseRepository.findMany.mockResolvedValue([]);
      emergencyCaseRepository.count.mockResolvedValue(0);

      await emergencyCaseService.listEmergencyCases(filters, 1, 20);

      expect(emergencyCaseRepository.findMany).toHaveBeenCalledWith(
        filters,
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should calculate pagination correctly', async () => {
      emergencyCaseRepository.findMany.mockResolvedValue([]);
      emergencyCaseRepository.count.mockResolvedValue(25);

      const result = await emergencyCaseService.listEmergencyCases({}, 2, 10);

      expect(result.totalPages).toBe(3);
      expect(emergencyCaseRepository.findMany).toHaveBeenCalledWith({}, 10, 10, { created_at: 'desc' });
    });
  });

  describe('getEmergencyCaseById', () => {
    it('should return emergency case by id', async () => {
      const mockCase = { id: 'test-id', severity: 'HIGH', status: 'PENDING' };

      emergencyCaseRepository.findById.mockResolvedValue(mockCase);

      const result = await emergencyCaseService.getEmergencyCaseById('test-id');

      expect(result).toEqual(expect.objectContaining(mockCase));
      expect(result).toEqual(expect.objectContaining({ display_id: 'test-id' }));
      expect(emergencyCaseRepository.findById).toHaveBeenCalledWith('test-id');
    });

    it('should throw HttpError if emergency case not found', async () => {
      emergencyCaseRepository.findById.mockResolvedValue(null);

      await expect(
        emergencyCaseService.getEmergencyCaseById('non-existent')
      ).rejects.toThrow(HttpError);
      
      await expect(
        emergencyCaseService.getEmergencyCaseById('non-existent')
      ).rejects.toMatchObject({
        messageKey: 'errors.emergency_case.not_found',
        statusCode: 404
      });
    });
  });

  describe('createEmergencyCase', () => {
    it('should create emergency case and audit log', async () => {
      const caseData = {
        tenant_id: 'tenant-id',
        patient_id: 'patient-id',
        severity: 'HIGH',
        status: 'PENDING'
      };
      const mockCreatedCase = {
        id: 'new-id',
        ...caseData,
        status: 'OPEN'
      };
      const expectedCreatePayload = {
        tenant_id: 'tenant-id',
        patient_id: 'patient-id',
        severity: 'HIGH',
        status: 'OPEN'
      };

      emergencyCaseRepository.create.mockResolvedValue(mockCreatedCase);

      const result = await emergencyCaseService.createEmergencyCase(caseData, mockUser);

      expect(result).toEqual(expect.objectContaining(mockCreatedCase));
      expect(result).toEqual(expect.objectContaining({ display_id: 'new-id' }));
      expect(emergencyCaseRepository.create).toHaveBeenCalledWith(expectedCreatePayload);
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'CREATE',
        resource: 'emergency_case',
        resource_id: mockCreatedCase.id,
        user_id: mockUser.id,
        tenant_id: caseData.tenant_id,
        details: { data: expectedCreatePayload }
      });
    });

    it('should throw error if create fails', async () => {
      emergencyCaseRepository.create.mockRejectedValue(new Error('DB Error'));

      await expect(
        emergencyCaseService.createEmergencyCase({}, mockUser)
      ).rejects.toThrow();
    });
  });

  describe('updateEmergencyCase', () => {
    it('should update emergency case and audit log', async () => {
      const existingCase = {
        id: 'test-id',
        tenant_id: 'tenant-id',
        severity: 'HIGH',
        status: 'PENDING'
      };
      const updateData = { status: 'IN_PROGRESS' };
      const expectedUpdatePayload = { status: 'OPEN' };
      const updatedCase = { ...existingCase, ...expectedUpdatePayload };

      emergencyCaseRepository.findById.mockResolvedValue(existingCase);
      emergencyCaseRepository.update.mockResolvedValue(updatedCase);

      const result = await emergencyCaseService.updateEmergencyCase('test-id', updateData, mockUser);

      expect(result).toEqual(expect.objectContaining(updatedCase));
      expect(result).toEqual(expect.objectContaining({ display_id: 'test-id' }));
      expect(emergencyCaseRepository.findById).toHaveBeenCalledWith('test-id');
      expect(emergencyCaseRepository.update).toHaveBeenCalledWith('test-id', expectedUpdatePayload);
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'UPDATE',
        resource: 'emergency_case',
        resource_id: 'test-id',
        user_id: mockUser.id,
        tenant_id: existingCase.tenant_id,
        details: { before: existingCase, after: expectedUpdatePayload }
      });
    });

    it('should throw HttpError if emergency case not found', async () => {
      emergencyCaseRepository.findById.mockResolvedValue(null);

      await expect(
        emergencyCaseService.updateEmergencyCase('non-existent', {}, mockUser)
      ).rejects.toThrow(HttpError);
      
      await expect(
        emergencyCaseService.updateEmergencyCase('non-existent', {}, mockUser)
      ).rejects.toMatchObject({
        messageKey: 'errors.emergency_case.not_found',
        statusCode: 404
      });
    });

  });

  describe('deleteEmergencyCase', () => {
    it('should soft delete emergency case and audit log', async () => {
      const existingCase = {
        id: 'test-id',
        tenant_id: 'tenant-id',
        severity: 'HIGH',
        status: 'PENDING'
      };
      const deletedCase = { ...existingCase, deleted_at: new Date() };

      emergencyCaseRepository.findById.mockResolvedValue(existingCase);
      emergencyCaseRepository.softDelete.mockResolvedValue(deletedCase);

      const result = await emergencyCaseService.deleteEmergencyCase('test-id', mockUser);

      expect(result).toEqual(expect.objectContaining(deletedCase));
      expect(result).toEqual(expect.objectContaining({ display_id: 'test-id' }));
      expect(emergencyCaseRepository.findById).toHaveBeenCalledWith('test-id');
      expect(emergencyCaseRepository.softDelete).toHaveBeenCalledWith('test-id');
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'DELETE',
        resource: 'emergency_case',
        resource_id: 'test-id',
        user_id: mockUser.id,
        tenant_id: existingCase.tenant_id,
        details: { data: existingCase }
      });
    });

    it('should throw HttpError if emergency case not found', async () => {
      emergencyCaseRepository.findById.mockResolvedValue(null);

      await expect(
        emergencyCaseService.deleteEmergencyCase('non-existent', mockUser)
      ).rejects.toThrow(HttpError);
      
      await expect(
        emergencyCaseService.deleteEmergencyCase('non-existent', mockUser)
      ).rejects.toMatchObject({
        messageKey: 'errors.emergency_case.not_found',
        statusCode: 404
      });
    });

  });
});
