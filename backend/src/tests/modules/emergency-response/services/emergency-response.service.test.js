/**
 * Emergency response service tests
 *
 * @module tests/modules/emergency-response/services
 * @description Tests for emergency response service business logic
 */

const emergencyResponseService = require('../../../../modules/emergency-response/services/emergency-response.service');
const emergencyResponseRepository = require('../../../../modules/emergency-response/repositories/emergency-response.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const prisma = require('@prisma/client');

// Mock dependencies
jest.mock('../../../../modules/emergency-response/repositories/emergency-response.repository');
jest.mock('@lib/audit');
jest.mock('@prisma/client', () => ({
  $transaction: jest.fn(async (callback) => await callback())
}));

describe('Emergency Response Service', () => {
  const mockUser = { id: 'user-id', tenant_id: 'tenant-id' };

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    prisma.$transaction.mockImplementation(async (callback) => await callback());
  });

  describe('listEmergencyResponses', () => {
    it('should list emergency responses with pagination', async () => {
      const mockResponses = [
        { id: '1', emergency_case_id: 'case-id' },
        { id: '2', emergency_case_id: 'case-id' }
      ];

      emergencyResponseRepository.findMany.mockResolvedValue(mockResponses);
      emergencyResponseRepository.count.mockResolvedValue(2);

      const result = await emergencyResponseService.listEmergencyResponses({}, 1, 10);

      expect(result.items).toEqual([
        expect.objectContaining(mockResponses[0]),
        expect.objectContaining(mockResponses[1]),
      ]);
      expect(result.items[0]).toEqual(expect.objectContaining({ display_id: '1' }));
      expect(result.total).toBe(2);
      expect(result.totalPages).toBe(1);
    });
  });

  describe('getEmergencyResponseById', () => {
    it('should return emergency response by id', async () => {
      const mockResponse = { id: 'test-id', emergency_case_id: 'case-id' };

      emergencyResponseRepository.findById.mockResolvedValue(mockResponse);

      const result = await emergencyResponseService.getEmergencyResponseById('test-id');

      expect(result).toEqual(expect.objectContaining(mockResponse));
      expect(result).toEqual(expect.objectContaining({ display_id: 'test-id' }));
    });

    it('should throw HttpError if not found', async () => {
      emergencyResponseRepository.findById.mockResolvedValue(null);

      await expect(
        emergencyResponseService.getEmergencyResponseById('non-existent')
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createEmergencyResponse', () => {
    it('should create emergency response and audit log', async () => {
      const responseData = {
        emergency_case_id: 'case-id',
        notes: 'test notes'
      };
      const mockCreated = { id: 'new-id', ...responseData };

      emergencyResponseRepository.create.mockResolvedValue(mockCreated);

      const result = await emergencyResponseService.createEmergencyResponse(responseData, mockUser);

      expect(result).toEqual(expect.objectContaining(mockCreated));
      expect(result).toEqual(expect.objectContaining({ display_id: 'new-id' }));
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('updateEmergencyResponse', () => {
    it('should update emergency response and audit log', async () => {
      const existing = { id: 'test-id', emergency_case_id: 'case-id' };
      const updateData = { notes: 'updated notes' };
      const updated = { ...existing, ...updateData };

      emergencyResponseRepository.findById.mockResolvedValue(existing);
      emergencyResponseRepository.update.mockResolvedValue(updated);

      const result = await emergencyResponseService.updateEmergencyResponse('test-id', updateData, mockUser);

      expect(result).toEqual(expect.objectContaining(updated));
      expect(result).toEqual(expect.objectContaining({ display_id: 'test-id' }));
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw HttpError if not found', async () => {
      emergencyResponseRepository.findById.mockResolvedValue(null);

      await expect(
        emergencyResponseService.updateEmergencyResponse('non-existent', {}, mockUser)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deleteEmergencyResponse', () => {
    it('should soft delete emergency response and audit log', async () => {
      const existing = { id: 'test-id', emergency_case_id: 'case-id' };
      const deleted = { ...existing, deleted_at: new Date() };

      emergencyResponseRepository.findById.mockResolvedValue(existing);
      emergencyResponseRepository.softDelete.mockResolvedValue(deleted);

      const result = await emergencyResponseService.deleteEmergencyResponse('test-id', mockUser);

      expect(result).toEqual(expect.objectContaining(deleted));
      expect(result).toEqual(expect.objectContaining({ display_id: 'test-id' }));
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw HttpError if not found', async () => {
      emergencyResponseRepository.findById.mockResolvedValue(null);

      await expect(
        emergencyResponseService.deleteEmergencyResponse('non-existent', mockUser)
      ).rejects.toThrow(HttpError);
    });
  });
});
