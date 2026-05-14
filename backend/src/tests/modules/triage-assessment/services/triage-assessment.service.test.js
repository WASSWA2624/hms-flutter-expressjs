/**
 * Triage assessment service tests
 *
 * @module tests/modules/triage-assessment/services
 * @description Tests for triage assessment service business logic
 */

const triageAssessmentService = require('../../../../modules/triage-assessment/services/triage-assessment.service');
const triageAssessmentRepository = require('../../../../modules/triage-assessment/repositories/triage-assessment.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const prisma = require('@prisma/client');

// Mock dependencies
jest.mock('../../../../modules/triage-assessment/repositories/triage-assessment.repository');
jest.mock('@lib/audit');
jest.mock('@prisma/client', () => ({
  $transaction: jest.fn(async (callback) => await callback())
}));

describe('Triage Assessment Service', () => {
  const mockUser = { id: 'user-id', tenant_id: 'tenant-id' };

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    prisma.$transaction.mockImplementation(async (callback) => await callback());
  });

  describe('listTriageAssessments', () => {
    it('should list triage assessments with pagination', async () => {
      const mockAssessments = [
        { id: '1', triage_level: 'URGENT' },
        { id: '2', triage_level: 'IMMEDIATE' }
      ];

      triageAssessmentRepository.findMany.mockResolvedValue(mockAssessments);
      triageAssessmentRepository.count.mockResolvedValue(2);

      const result = await triageAssessmentService.listTriageAssessments({}, 1, 10);

      expect(result.items).toEqual([
        expect.objectContaining(mockAssessments[0]),
        expect.objectContaining(mockAssessments[1]),
      ]);
      expect(result.items[0]).toEqual(expect.objectContaining({ display_id: '1' }));
      expect(result.total).toBe(2);
      expect(result.totalPages).toBe(1);
    });
  });

  describe('getTriageAssessmentById', () => {
    it('should return triage assessment by id', async () => {
      const mockAssessment = { id: 'test-id', triage_level: 'URGENT' };

      triageAssessmentRepository.findById.mockResolvedValue(mockAssessment);

      const result = await triageAssessmentService.getTriageAssessmentById('test-id');

      expect(result).toEqual(expect.objectContaining(mockAssessment));
      expect(result).toEqual(expect.objectContaining({ display_id: 'test-id' }));
    });

    it('should throw HttpError if not found', async () => {
      triageAssessmentRepository.findById.mockResolvedValue(null);

      await expect(
        triageAssessmentService.getTriageAssessmentById('non-existent')
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createTriageAssessment', () => {
    it('should create triage assessment and audit log', async () => {
      const assessmentData = {
        emergency_case_id: 'case-id',
        triage_level: 'URGENT',
        notes: 'test notes'
      };
      const mockCreated = { id: 'new-id', ...assessmentData };

      triageAssessmentRepository.create.mockResolvedValue(mockCreated);

      const result = await triageAssessmentService.createTriageAssessment(assessmentData, mockUser);

      expect(result).toEqual(expect.objectContaining(mockCreated));
      expect(result).toEqual(expect.objectContaining({ display_id: 'new-id' }));
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('updateTriageAssessment', () => {
    it('should update triage assessment and audit log', async () => {
      const existing = { id: 'test-id', triage_level: 'URGENT' };
      const updateData = { triage_level: 'IMMEDIATE' };
      const updated = { ...existing, ...updateData };

      triageAssessmentRepository.findById.mockResolvedValue(existing);
      triageAssessmentRepository.update.mockResolvedValue(updated);

      const result = await triageAssessmentService.updateTriageAssessment('test-id', updateData, mockUser);

      expect(result).toEqual(expect.objectContaining(updated));
      expect(result).toEqual(expect.objectContaining({ display_id: 'test-id' }));
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw HttpError if not found', async () => {
      triageAssessmentRepository.findById.mockResolvedValue(null);

      await expect(
        triageAssessmentService.updateTriageAssessment('non-existent', {}, mockUser)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deleteTriageAssessment', () => {
    it('should soft delete triage assessment and audit log', async () => {
      const existing = { id: 'test-id', triage_level: 'URGENT' };
      const deleted = { ...existing, deleted_at: new Date() };

      triageAssessmentRepository.findById.mockResolvedValue(existing);
      triageAssessmentRepository.softDelete.mockResolvedValue(deleted);

      const result = await triageAssessmentService.deleteTriageAssessment('test-id', mockUser);

      expect(result).toEqual(expect.objectContaining(deleted));
      expect(result).toEqual(expect.objectContaining({ display_id: 'test-id' }));
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw HttpError if not found', async () => {
      triageAssessmentRepository.findById.mockResolvedValue(null);

      await expect(
        triageAssessmentService.deleteTriageAssessment('non-existent', mockUser)
      ).rejects.toThrow(HttpError);
    });
  });
});
