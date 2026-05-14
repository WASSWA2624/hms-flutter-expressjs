/**
 * Patient Allergy repository tests
 *
 * @module tests/modules/patient-allergy/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  patient_allergy: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

const {
  findById,
  findMany,
  count,
  create,
  update,
  softDelete
} = require('@repositories/patient-allergy/patient-allergy.repository');

const prisma = require('@prisma/client');

describe('Patient Allergy Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find patient allergy by ID', async () => {
      const mockPatientAllergy = {
        id: 'allergy-123',
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        allergen: 'Penicillin',
        severity: 'MODERATE',
        reaction: 'Rash',
        notes: 'Patient developed rash',
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.patient_allergy.findFirst.mockResolvedValue(mockPatientAllergy);

      const result = await findById('allergy-123');

      expect(result).toEqual(mockPatientAllergy);
      expect(prisma.patient_allergy.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'allergy-123',
          deleted_at: null
        },
        include: {}
      });
    });

    it('should return null if patient allergy not found', async () => {
      prisma.patient_allergy.findFirst.mockResolvedValue(null);

      const result = await findById('allergy-123');

      expect(result).toBeNull();
    });

    it('should find patient allergy with includes', async () => {
      const mockPatientAllergy = { id: 'allergy-123', allergen: 'Peanuts' };
      prisma.patient_allergy.findFirst.mockResolvedValue(mockPatientAllergy);

      await findById('allergy-123', { patient: true });

      expect(prisma.patient_allergy.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'allergy-123',
          deleted_at: null
        },
        include: { patient: true }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.patient_allergy.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('allergy-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many patient allergies with default pagination', async () => {
      const mockPatientAllergies = [
        {
          id: 'allergy-1',
          patient_id: 'patient-123',
          allergen: 'Penicillin',
          severity: 'MODERATE'
        },
        {
          id: 'allergy-2',
          patient_id: 'patient-123',
          allergen: 'Peanuts',
          severity: 'SEVERE'
        }
      ];
      prisma.patient_allergy.findMany.mockResolvedValue(mockPatientAllergies);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockPatientAllergies);
      expect(prisma.patient_allergy.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should find patient allergies with filters', async () => {
      const mockPatientAllergies = [
        {
          id: 'allergy-1',
          patient_id: 'patient-123',
          allergen: 'Penicillin',
          severity: 'MODERATE'
        }
      ];
      prisma.patient_allergy.findMany.mockResolvedValue(mockPatientAllergies);

      const result = await findMany({ 
        patient_id: 'patient-123', 
        severity: 'MODERATE'
      }, 0, 10);

      expect(result).toEqual(mockPatientAllergies);
      expect(prisma.patient_allergy.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          patient_id: 'patient-123',
          severity: 'MODERATE'
        },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should find patient allergies with custom pagination', async () => {
      const mockPatientAllergies = [];
      prisma.patient_allergy.findMany.mockResolvedValue(mockPatientAllergies);

      const result = await findMany({}, 20, 50);

      expect(result).toEqual(mockPatientAllergies);
      expect(prisma.patient_allergy.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 20,
        take: 50,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should find patient allergies with custom order', async () => {
      const mockPatientAllergies = [];
      prisma.patient_allergy.findMany.mockResolvedValue(mockPatientAllergies);

      const result = await findMany({}, 0, 20, { allergen: 'asc' });

      expect(result).toEqual(mockPatientAllergies);
      expect(prisma.patient_allergy.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { allergen: 'asc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.patient_allergy.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany({}, 0, 20))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count patient allergies', async () => {
      prisma.patient_allergy.count.mockResolvedValue(5);

      const result = await count({});

      expect(result).toBe(5);
      expect(prisma.patient_allergy.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count patient allergies with filters', async () => {
      prisma.patient_allergy.count.mockResolvedValue(2);

      const result = await count({ 
        patient_id: 'patient-123',
        severity: 'SEVERE'
      });

      expect(result).toBe(2);
      expect(prisma.patient_allergy.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          patient_id: 'patient-123',
          severity: 'SEVERE'
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.patient_allergy.count.mockRejectedValue(new Error('DB error'));

      await expect(count({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create new patient allergy', async () => {
      const newPatientAllergy = {
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        allergen: 'Penicillin',
        severity: 'MODERATE',
        reaction: 'Rash',
        notes: 'Patient developed rash'
      };
      const mockCreated = {
        id: 'allergy-123',
        ...newPatientAllergy,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.patient_allergy.create.mockResolvedValue(mockCreated);

      const result = await create(newPatientAllergy);

      expect(result).toEqual(mockCreated);
      expect(prisma.patient_allergy.create).toHaveBeenCalledWith({
        data: newPatientAllergy
      });
    });

    it('should throw HttpError on unique constraint violation (P2002)', async () => {
      const newPatientAllergy = {
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        allergen: 'Penicillin',
        severity: 'MODERATE'
      };
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['patient_id', 'allergen'] };
      prisma.patient_allergy.create.mockRejectedValue(error);

      await expect(create(newPatientAllergy))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation (P2003)', async () => {
      const newPatientAllergy = {
        tenant_id: 'tenant-123',
        patient_id: 'invalid-patient',
        allergen: 'Penicillin',
        severity: 'MODERATE'
      };
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'patient_id' };
      prisma.patient_allergy.create.mockRejectedValue(error);

      await expect(create(newPatientAllergy))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      const newPatientAllergy = {
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        allergen: 'Penicillin',
        severity: 'MODERATE'
      };
      prisma.patient_allergy.create.mockRejectedValue(new Error('DB error'));

      await expect(create(newPatientAllergy))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update patient allergy', async () => {
      const updateData = {
        severity: 'SEVERE',
        notes: 'Updated notes'
      };
      const mockUpdated = {
        id: 'allergy-123',
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        allergen: 'Penicillin',
        severity: 'SEVERE',
        reaction: 'Rash',
        notes: 'Updated notes',
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 2
      };
      prisma.patient_allergy.update.mockResolvedValue(mockUpdated);

      const result = await update('allergy-123', updateData);

      expect(result).toEqual(mockUpdated);
      expect(prisma.patient_allergy.update).toHaveBeenCalledWith({
        where: { id: 'allergy-123' },
        data: updateData
      });
    });

    it('should throw HttpError when patient allergy not found (P2025)', async () => {
      const updateData = { severity: 'SEVERE' };
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.patient_allergy.update.mockRejectedValue(error);

      await expect(update('allergy-123', updateData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation (P2002)', async () => {
      const updateData = { allergen: 'Duplicate' };
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['allergen'] };
      prisma.patient_allergy.update.mockRejectedValue(error);

      await expect(update('allergy-123', updateData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation (P2003)', async () => {
      const updateData = { patient_id: 'invalid-patient' };
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'patient_id' };
      prisma.patient_allergy.update.mockRejectedValue(error);

      await expect(update('allergy-123', updateData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      const updateData = { severity: 'SEVERE' };
      prisma.patient_allergy.update.mockRejectedValue(new Error('DB error'));

      await expect(update('allergy-123', updateData))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete patient allergy', async () => {
      const mockDeleted = {
        id: 'allergy-123',
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        allergen: 'Penicillin',
        severity: 'MODERATE',
        deleted_at: new Date('2026-01-19')
      };
      prisma.patient_allergy.update.mockResolvedValue(mockDeleted);

      const result = await softDelete('allergy-123');

      expect(result).toEqual(mockDeleted);
      expect(prisma.patient_allergy.update).toHaveBeenCalledWith({
        where: { id: 'allergy-123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError when patient allergy not found (P2025)', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.patient_allergy.update.mockRejectedValue(error);

      await expect(softDelete('allergy-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.patient_allergy.update.mockRejectedValue(new Error('DB error'));

      await expect(softDelete('allergy-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
