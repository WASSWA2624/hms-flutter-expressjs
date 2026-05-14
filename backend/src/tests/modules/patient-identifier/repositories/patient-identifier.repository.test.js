/**
 * Patient Identifier repository tests
 *
 * @module tests/modules/patient-identifier/repositories
 * @description Tests for patient identifier repository operations
 * Per testing.mdc: Repository tests must mock Prisma client
 */

const patientIdentifierRepository = require('@repositories/patient-identifier/patient-identifier.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  patient_identifier: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Patient Identifier Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find patient identifier by id', async () => {
      const mockIdentifier = { id: '123', identifier_type: 'MRN', identifier_value: 'MRN123' };
      prisma.patient_identifier.findFirst.mockResolvedValue(mockIdentifier);

      const result = await patientIdentifierRepository.findById('123');
      expect(result).toEqual(mockIdentifier);
      expect(prisma.patient_identifier.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include: {}
      });
    });

    it('should return null if not found', async () => {
      prisma.patient_identifier.findFirst.mockResolvedValue(null);

      const result = await patientIdentifierRepository.findById('nonexistent');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.patient_identifier.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(patientIdentifierRepository.findById('123')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many patient identifiers with pagination', async () => {
      const mockIdentifiers = [
        { id: '1', identifier_type: 'MRN', identifier_value: 'MRN001' },
        { id: '2', identifier_type: 'SSN', identifier_value: 'SSN002' }
      ];
      prisma.patient_identifier.findMany.mockResolvedValue(mockIdentifiers);

      const result = await patientIdentifierRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockIdentifiers);
      expect(prisma.patient_identifier.findMany).toHaveBeenCalled();
    });

    it('should apply filters correctly', async () => {
      prisma.patient_identifier.findMany.mockResolvedValue([]);

      await patientIdentifierRepository.findMany({ patient_id: '123' }, 0, 20);
      expect(prisma.patient_identifier.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, patient_id: '123' },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });
  });

  describe('count', () => {
    it('should count patient identifiers', async () => {
      prisma.patient_identifier.count.mockResolvedValue(10);

      const result = await patientIdentifierRepository.count({});
      expect(result).toBe(10);
    });

    it('should count with filters', async () => {
      prisma.patient_identifier.count.mockResolvedValue(5);

      const result = await patientIdentifierRepository.count({ is_primary: true });
      expect(result).toBe(5);
    });
  });

  describe('create', () => {
    it('should create patient identifier', async () => {
      const mockData = { tenant_id: '123', patient_id: '456', identifier_type: 'MRN', identifier_value: 'MRN123' };
      const mockIdentifier = { id: '789', ...mockData };
      prisma.patient_identifier.create.mockResolvedValue(mockIdentifier);

      const result = await patientIdentifierRepository.create(mockData);
      expect(result).toEqual(mockIdentifier);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['identifier_value'] };
      prisma.patient_identifier.create.mockRejectedValue(error);

      await expect(patientIdentifierRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'patient_id' };
      prisma.patient_identifier.create.mockRejectedValue(error);

      await expect(patientIdentifierRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update patient identifier', async () => {
      const mockIdentifier = { id: '123', identifier_value: 'UPDATED123' };
      prisma.patient_identifier.update.mockResolvedValue(mockIdentifier);

      const result = await patientIdentifierRepository.update('123', { identifier_value: 'UPDATED123' });
      expect(result).toEqual(mockIdentifier);
    });

    it('should throw HttpError if not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.patient_identifier.update.mockRejectedValue(error);

      await expect(patientIdentifierRepository.update('nonexistent', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete patient identifier', async () => {
      const mockIdentifier = { id: '123', deleted_at: new Date() };
      prisma.patient_identifier.update.mockResolvedValue(mockIdentifier);

      const result = await patientIdentifierRepository.softDelete('123');
      expect(result).toEqual(mockIdentifier);
      expect(prisma.patient_identifier.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError if not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.patient_identifier.update.mockRejectedValue(error);

      await expect(patientIdentifierRepository.softDelete('nonexistent')).rejects.toThrow(HttpError);
    });
  });
});
