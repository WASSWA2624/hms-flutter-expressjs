/**
 * Emergency case repository tests
 *
 * @module tests/modules/emergency-case/repositories
 * @description Tests for emergency case repository data access layer
 */

const emergencyCaseRepository = require('../../../../modules/emergency-case/repositories/emergency-case.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  emergency_case: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Emergency Case Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find emergency case by id', async () => {
      const mockEmergencyCase = {
        id: 'test-id',
        tenant_id: 'tenant-id',
        patient_id: 'patient-id',
        severity: 'HIGH',
        status: 'PENDING',
        deleted_at: null
      };

      prisma.emergency_case.findFirst.mockResolvedValue(mockEmergencyCase);

      const result = await emergencyCaseRepository.findById('test-id');

      expect(prisma.emergency_case.findFirst).toHaveBeenCalledWith({
        where: { id: 'test-id', deleted_at: null },
        include: expect.any(Object)
      });
      expect(result).toEqual(mockEmergencyCase);
    });

    it('should return null if emergency case not found', async () => {
      prisma.emergency_case.findFirst.mockResolvedValue(null);

      const result = await emergencyCaseRepository.findById('non-existent-id');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.emergency_case.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(emergencyCaseRepository.findById('test-id')).rejects.toThrow(HttpError);
    });

    it('should support include parameter', async () => {
      const mockEmergencyCase = { id: 'test-id', deleted_at: null };
      prisma.emergency_case.findFirst.mockResolvedValue(mockEmergencyCase);

      await emergencyCaseRepository.findById('test-id', { triage_assessments: true });

      expect(prisma.emergency_case.findFirst).toHaveBeenCalledWith({
        where: { id: 'test-id', deleted_at: null },
        include: { triage_assessments: true }
      });
    });
  });

  describe('findMany', () => {
    it('should find emergency cases with filters and pagination', async () => {
      const mockCases = [
        { id: '1', severity: 'HIGH', deleted_at: null },
        { id: '2', severity: 'CRITICAL', deleted_at: null }
      ];

      prisma.emergency_case.findMany.mockResolvedValue(mockCases);

      const filters = { tenant_id: 'tenant-id', severity: 'HIGH' };
      const result = await emergencyCaseRepository.findMany(filters, 0, 10);

      expect(prisma.emergency_case.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, tenant_id: 'tenant-id', severity: 'HIGH' },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' },
        include: expect.any(Object)
      });
      expect(result).toEqual(mockCases);
    });

    it('should use default pagination values', async () => {
      prisma.emergency_case.findMany.mockResolvedValue([]);

      await emergencyCaseRepository.findMany();

      expect(prisma.emergency_case.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: expect.any(Object)
      });
    });

    it('should support custom orderBy', async () => {
      prisma.emergency_case.findMany.mockResolvedValue([]);

      await emergencyCaseRepository.findMany({}, 0, 10, { severity: 'asc' });

      expect(prisma.emergency_case.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 10,
        orderBy: { severity: 'asc' },
        include: expect.any(Object)
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.emergency_case.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(emergencyCaseRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count emergency cases with filters', async () => {
      prisma.emergency_case.count.mockResolvedValue(15);

      const filters = { status: 'PENDING', severity: 'HIGH' };
      const result = await emergencyCaseRepository.count(filters);

      expect(prisma.emergency_case.count).toHaveBeenCalledWith({
        where: { deleted_at: null, status: 'PENDING', severity: 'HIGH' }
      });
      expect(result).toBe(15);
    });

    it('should count all emergency cases if no filters provided', async () => {
      prisma.emergency_case.count.mockResolvedValue(100);

      const result = await emergencyCaseRepository.count();

      expect(prisma.emergency_case.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
      expect(result).toBe(100);
    });

    it('should throw HttpError on database error', async () => {
      prisma.emergency_case.count.mockRejectedValue(new Error('DB Error'));

      await expect(emergencyCaseRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create new emergency case', async () => {
      const caseData = {
        tenant_id: 'tenant-id',
        patient_id: 'patient-id',
        severity: 'HIGH',
        status: 'PENDING'
      };
      const mockCreatedCase = { id: 'new-id', ...caseData };

      prisma.emergency_case.create.mockResolvedValue(mockCreatedCase);

      const result = await emergencyCaseRepository.create(caseData);

      expect(prisma.emergency_case.create).toHaveBeenCalledWith({
        data: caseData,
        include: expect.any(Object)
      });
      expect(result).toEqual(mockCreatedCase);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = { code: 'P2002', meta: { target: ['identifier'] } };
      prisma.emergency_case.create.mockRejectedValue(error);

      await expect(emergencyCaseRepository.create({})).rejects.toThrow(HttpError);
      await expect(emergencyCaseRepository.create({})).rejects.toMatchObject({
        messageKey: 'errors.database.unique_field',
        statusCode: 409
      });
    });

    it('should throw HttpError on foreign key violation', async () => {
      const error = { code: 'P2003', meta: { field_name: 'patient_id' } };
      prisma.emergency_case.create.mockRejectedValue(error);

      await expect(emergencyCaseRepository.create({})).rejects.toThrow(HttpError);
      await expect(emergencyCaseRepository.create({})).rejects.toMatchObject({
        messageKey: 'errors.database.foreign_key_field',
        statusCode: 400
      });
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.emergency_case.create.mockRejectedValue(new Error('DB Error'));

      await expect(emergencyCaseRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update emergency case', async () => {
      const updateData = { status: 'IN_PROGRESS', severity: 'CRITICAL' };
      const mockUpdated = { id: 'test-id', ...updateData };

      prisma.emergency_case.update.mockResolvedValue(mockUpdated);

      const result = await emergencyCaseRepository.update('test-id', updateData);

      expect(prisma.emergency_case.update).toHaveBeenCalledWith({
        where: { id: 'test-id' },
        data: updateData,
        include: expect.any(Object)
      });
      expect(result).toEqual(mockUpdated);
    });

    it('should throw HttpError if emergency case not found', async () => {
      const error = { code: 'P2025' };
      prisma.emergency_case.update.mockRejectedValue(error);

      await expect(emergencyCaseRepository.update('non-existent-id', {})).rejects.toThrow(HttpError);
      await expect(emergencyCaseRepository.update('non-existent-id', {})).rejects.toMatchObject({
        messageKey: 'errors.emergency_case.not_found',
        statusCode: 404
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = { code: 'P2002', meta: { target: ['identifier'] } };
      prisma.emergency_case.update.mockRejectedValue(error);

      await expect(emergencyCaseRepository.update('test-id', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key violation', async () => {
      const error = { code: 'P2003', meta: { field_name: 'facility_id' } };
      prisma.emergency_case.update.mockRejectedValue(error);

      await expect(emergencyCaseRepository.update('test-id', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.emergency_case.update.mockRejectedValue(new Error('DB Error'));

      await expect(emergencyCaseRepository.update('test-id', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete emergency case', async () => {
      const mockDeleted = { id: 'test-id', deleted_at: new Date() };

      prisma.emergency_case.update.mockResolvedValue(mockDeleted);

      const result = await emergencyCaseRepository.softDelete('test-id');

      expect(prisma.emergency_case.update).toHaveBeenCalledWith({
        where: { id: 'test-id' },
        data: { deleted_at: expect.any(Date) },
        include: expect.any(Object)
      });
      expect(result).toEqual(mockDeleted);
    });

    it('should throw HttpError if emergency case not found', async () => {
      const error = { code: 'P2025' };
      prisma.emergency_case.update.mockRejectedValue(error);

      await expect(emergencyCaseRepository.softDelete('non-existent-id')).rejects.toThrow(HttpError);
      await expect(emergencyCaseRepository.softDelete('non-existent-id')).rejects.toMatchObject({
        messageKey: 'errors.emergency_case.not_found',
        statusCode: 404
      });
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.emergency_case.update.mockRejectedValue(new Error('DB Error'));

      await expect(emergencyCaseRepository.softDelete('test-id')).rejects.toThrow(HttpError);
    });
  });
});
