/**
 * Patient Guardian repository tests
 *
 * @module tests/modules/patient-guardian/repositories
 * @description Tests for patient guardian repository operations
 * Per testing.mdc: Repository tests must mock Prisma client
 */

const patientGuardianRepository = require('@repositories/patient-guardian/patient-guardian.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  patient_guardian: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Patient Guardian Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find patient guardian by id', async () => {
      const mockGuardian = { id: '123', name: 'Jane Doe', relationship: 'Mother' };
      prisma.patient_guardian.findFirst.mockResolvedValue(mockGuardian);

      const result = await patientGuardianRepository.findById('123');
      expect(result).toEqual(mockGuardian);
      expect(prisma.patient_guardian.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include: {}
      });
    });

    it('should return null if not found', async () => {
      prisma.patient_guardian.findFirst.mockResolvedValue(null);

      const result = await patientGuardianRepository.findById('nonexistent');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.patient_guardian.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(patientGuardianRepository.findById('123')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many patient guardians with pagination', async () => {
      const mockGuardians = [
        { id: '1', name: 'Jane Doe', relationship: 'Mother' },
        { id: '2', name: 'John Doe', relationship: 'Father' }
      ];
      prisma.patient_guardian.findMany.mockResolvedValue(mockGuardians);

      const result = await patientGuardianRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockGuardians);
    });

    it('should apply filters correctly', async () => {
      prisma.patient_guardian.findMany.mockResolvedValue([]);

      await patientGuardianRepository.findMany({ patient_id: '123' }, 0, 20);
      expect(prisma.patient_guardian.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, patient_id: '123' },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });
  });

  describe('count', () => {
    it('should count patient guardians', async () => {
      prisma.patient_guardian.count.mockResolvedValue(8);

      const result = await patientGuardianRepository.count({});
      expect(result).toBe(8);
    });

    it('should count with filters', async () => {
      prisma.patient_guardian.count.mockResolvedValue(3);

      const result = await patientGuardianRepository.count({ patient_id: '123' });
      expect(result).toBe(3);
    });
  });

  describe('create', () => {
    it('should create patient guardian', async () => {
      const mockData = {
        tenant_id: '123',
        patient_id: '456',
        name: 'Jane Doe',
        relationship: 'Mother',
        phone: '+256700000000',
        email: 'jane@example.com'
      };
      const mockGuardian = { id: '789', ...mockData };
      prisma.patient_guardian.create.mockResolvedValue(mockGuardian);

      const result = await patientGuardianRepository.create(mockData);
      expect(result).toEqual(mockGuardian);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['name'] };
      prisma.patient_guardian.create.mockRejectedValue(error);

      await expect(patientGuardianRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'patient_id' };
      prisma.patient_guardian.create.mockRejectedValue(error);

      await expect(patientGuardianRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update patient guardian', async () => {
      const mockGuardian = { id: '123', name: 'Jane Smith', relationship: 'Mother' };
      prisma.patient_guardian.update.mockResolvedValue(mockGuardian);

      const result = await patientGuardianRepository.update('123', { name: 'Jane Smith' });
      expect(result).toEqual(mockGuardian);
    });

    it('should throw HttpError if not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.patient_guardian.update.mockRejectedValue(error);

      await expect(patientGuardianRepository.update('nonexistent', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete patient guardian', async () => {
      const mockGuardian = { id: '123', deleted_at: new Date() };
      prisma.patient_guardian.update.mockResolvedValue(mockGuardian);

      const result = await patientGuardianRepository.softDelete('123');
      expect(result).toEqual(mockGuardian);
      expect(prisma.patient_guardian.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError if not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.patient_guardian.update.mockRejectedValue(error);

      await expect(patientGuardianRepository.softDelete('nonexistent')).rejects.toThrow(HttpError);
    });
  });
});
