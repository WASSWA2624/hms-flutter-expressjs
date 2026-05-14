/**
 * Triage assessment repository tests
 *
 * @module tests/modules/triage-assessment/repositories
 * @description Tests for triage assessment repository data access layer
 */

const triageAssessmentRepository = require('../../../../modules/triage-assessment/repositories/triage-assessment.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  triage_assessment: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Triage Assessment Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find triage assessment by id', async () => {
      const mockAssessment = {
        id: 'test-id',
        emergency_case_id: 'case-id',
        triage_level: 'URGENT',
        notes: 'test notes',
        deleted_at: null
      };

      prisma.triage_assessment.findFirst.mockResolvedValue(mockAssessment);

      const result = await triageAssessmentRepository.findById('test-id');

      expect(prisma.triage_assessment.findFirst).toHaveBeenCalledWith({
        where: { id: 'test-id', deleted_at: null },
        include: expect.any(Object)
      });
      expect(result).toEqual(mockAssessment);
    });

    it('should return null if not found', async () => {
      prisma.triage_assessment.findFirst.mockResolvedValue(null);

      const result = await triageAssessmentRepository.findById('non-existent');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.triage_assessment.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(triageAssessmentRepository.findById('test-id')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find triage assessments with filters', async () => {
      const mockAssessments = [
        { id: '1', triage_level: 'URGENT', deleted_at: null },
        { id: '2', triage_level: 'IMMEDIATE', deleted_at: null }
      ];

      prisma.triage_assessment.findMany.mockResolvedValue(mockAssessments);

      const filters = { emergency_case_id: 'case-id' };
      const result = await triageAssessmentRepository.findMany(filters, 0, 10);

      expect(prisma.triage_assessment.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, emergency_case_id: 'case-id' },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' },
        include: expect.any(Object)
      });
      expect(result).toEqual(mockAssessments);
    });

    it('should throw HttpError on database error', async () => {
      prisma.triage_assessment.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(triageAssessmentRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count triage assessments with filters', async () => {
      prisma.triage_assessment.count.mockResolvedValue(10);

      const filters = { triage_level: 'URGENT' };
      const result = await triageAssessmentRepository.count(filters);

      expect(prisma.triage_assessment.count).toHaveBeenCalledWith({
        where: { deleted_at: null, triage_level: 'URGENT' }
      });
      expect(result).toBe(10);
    });

    it('should throw HttpError on database error', async () => {
      prisma.triage_assessment.count.mockRejectedValue(new Error('DB Error'));

      await expect(triageAssessmentRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create new triage assessment', async () => {
      const assessmentData = {
        emergency_case_id: 'case-id',
        triage_level: 'URGENT',
        notes: 'test notes'
      };
      const mockCreated = { id: 'new-id', ...assessmentData };

      prisma.triage_assessment.create.mockResolvedValue(mockCreated);

      const result = await triageAssessmentRepository.create(assessmentData);

      expect(prisma.triage_assessment.create).toHaveBeenCalledWith({
        data: assessmentData,
        include: expect.any(Object)
      });
      expect(result).toEqual(mockCreated);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = { code: 'P2002', meta: { target: ['id'] } };
      prisma.triage_assessment.create.mockRejectedValue(error);

      await expect(triageAssessmentRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key violation', async () => {
      const error = { code: 'P2003', meta: { field_name: 'emergency_case_id' } };
      prisma.triage_assessment.create.mockRejectedValue(error);

      await expect(triageAssessmentRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update triage assessment', async () => {
      const updateData = { triage_level: 'IMMEDIATE' };
      const mockUpdated = { id: 'test-id', ...updateData };

      prisma.triage_assessment.update.mockResolvedValue(mockUpdated);

      const result = await triageAssessmentRepository.update('test-id', updateData);

      expect(prisma.triage_assessment.update).toHaveBeenCalledWith({
        where: { id: 'test-id' },
        data: updateData,
        include: expect.any(Object)
      });
      expect(result).toEqual(mockUpdated);
    });

    it('should throw HttpError if not found', async () => {
      const error = { code: 'P2025' };
      prisma.triage_assessment.update.mockRejectedValue(error);

      await expect(triageAssessmentRepository.update('non-existent', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete triage assessment', async () => {
      const mockDeleted = { id: 'test-id', deleted_at: new Date() };

      prisma.triage_assessment.update.mockResolvedValue(mockDeleted);

      const result = await triageAssessmentRepository.softDelete('test-id');

      expect(prisma.triage_assessment.update).toHaveBeenCalledWith({
        where: { id: 'test-id' },
        data: { deleted_at: expect.any(Date) },
        include: expect.any(Object)
      });
      expect(result).toEqual(mockDeleted);
    });

    it('should throw HttpError if not found', async () => {
      const error = { code: 'P2025' };
      prisma.triage_assessment.update.mockRejectedValue(error);

      await expect(triageAssessmentRepository.softDelete('non-existent')).rejects.toThrow(HttpError);
    });
  });
});
