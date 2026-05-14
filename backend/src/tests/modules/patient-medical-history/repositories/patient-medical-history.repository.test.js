/**
 * Patient Medical History repository tests
 *
 * @module tests/modules/patient-medical-history/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  patient_medical_history: {
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
} = require('@repositories/patient-medical-history/patient-medical-history.repository');

const prisma = require('@prisma/client');

describe('Patient Medical History Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find patient medical history by ID', async () => {
      const mockMedicalHistory = {
        id: 'history-123',
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        condition: 'Hypertension',
        diagnosis_date: new Date('2024-01-15'),
        notes: 'Patient diagnosed with high blood pressure',
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.patient_medical_history.findFirst.mockResolvedValue(mockMedicalHistory);

      const result = await findById('history-123');

      expect(result).toEqual(mockMedicalHistory);
      expect(prisma.patient_medical_history.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'history-123',
          deleted_at: null
        },
        include: {}
      });
    });

    it('should return null if patient medical history not found', async () => {
      prisma.patient_medical_history.findFirst.mockResolvedValue(null);

      const result = await findById('history-123');

      expect(result).toBeNull();
    });

    it('should find patient medical history with includes', async () => {
      const mockMedicalHistory = { id: 'history-123', condition: 'Diabetes' };
      prisma.patient_medical_history.findFirst.mockResolvedValue(mockMedicalHistory);

      await findById('history-123', { patient: true });

      expect(prisma.patient_medical_history.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'history-123',
          deleted_at: null
        },
        include: { patient: true }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.patient_medical_history.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('history-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many patient medical histories with default pagination', async () => {
      const mockMedicalHistories = [
        {
          id: 'history-1',
          patient_id: 'patient-123',
          condition: 'Hypertension',
          diagnosis_date: new Date('2024-01-15')
        },
        {
          id: 'history-2',
          patient_id: 'patient-123',
          condition: 'Diabetes',
          diagnosis_date: new Date('2023-05-20')
        }
      ];
      prisma.patient_medical_history.findMany.mockResolvedValue(mockMedicalHistories);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockMedicalHistories);
      expect(prisma.patient_medical_history.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should find patient medical histories with filters', async () => {
      const mockMedicalHistories = [
        {
          id: 'history-1',
          patient_id: 'patient-123',
          condition: 'Hypertension'
        }
      ];
      prisma.patient_medical_history.findMany.mockResolvedValue(mockMedicalHistories);

      const result = await findMany({ 
        patient_id: 'patient-123'
      }, 0, 10);

      expect(result).toEqual(mockMedicalHistories);
      expect(prisma.patient_medical_history.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          patient_id: 'patient-123'
        },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should find patient medical histories with custom pagination', async () => {
      const mockMedicalHistories = [];
      prisma.patient_medical_history.findMany.mockResolvedValue(mockMedicalHistories);

      const result = await findMany({}, 20, 50);

      expect(result).toEqual(mockMedicalHistories);
      expect(prisma.patient_medical_history.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 20,
        take: 50,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should find patient medical histories with custom order', async () => {
      const mockMedicalHistories = [];
      prisma.patient_medical_history.findMany.mockResolvedValue(mockMedicalHistories);

      const result = await findMany({}, 0, 20, { diagnosis_date: 'desc' });

      expect(result).toEqual(mockMedicalHistories);
      expect(prisma.patient_medical_history.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { diagnosis_date: 'desc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.patient_medical_history.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany({}, 0, 20))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count patient medical histories', async () => {
      prisma.patient_medical_history.count.mockResolvedValue(5);

      const result = await count({});

      expect(result).toBe(5);
      expect(prisma.patient_medical_history.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count patient medical histories with filters', async () => {
      prisma.patient_medical_history.count.mockResolvedValue(2);

      const result = await count({ 
        patient_id: 'patient-123'
      });

      expect(result).toBe(2);
      expect(prisma.patient_medical_history.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          patient_id: 'patient-123'
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.patient_medical_history.count.mockRejectedValue(new Error('DB error'));

      await expect(count({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create new patient medical history', async () => {
      const newMedicalHistory = {
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        condition: 'Hypertension',
        diagnosis_date: new Date('2024-01-15'),
        notes: 'Patient diagnosed with high blood pressure'
      };
      const mockCreated = {
        id: 'history-123',
        ...newMedicalHistory,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.patient_medical_history.create.mockResolvedValue(mockCreated);

      const result = await create(newMedicalHistory);

      expect(result).toEqual(mockCreated);
      expect(prisma.patient_medical_history.create).toHaveBeenCalledWith({
        data: newMedicalHistory
      });
    });

    it('should throw HttpError on unique constraint violation (P2002)', async () => {
      const newMedicalHistory = {
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        condition: 'Hypertension'
      };
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['patient_id', 'condition'] };
      prisma.patient_medical_history.create.mockRejectedValue(error);

      await expect(create(newMedicalHistory))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation (P2003)', async () => {
      const newMedicalHistory = {
        tenant_id: 'tenant-123',
        patient_id: 'invalid-patient',
        condition: 'Hypertension'
      };
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'patient_id' };
      prisma.patient_medical_history.create.mockRejectedValue(error);

      await expect(create(newMedicalHistory))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      const newMedicalHistory = {
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        condition: 'Hypertension'
      };
      prisma.patient_medical_history.create.mockRejectedValue(new Error('DB error'));

      await expect(create(newMedicalHistory))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update patient medical history', async () => {
      const updateData = {
        condition: 'Diabetes Type 2',
        notes: 'Updated diagnosis'
      };
      const mockUpdated = {
        id: 'history-123',
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        condition: 'Diabetes Type 2',
        diagnosis_date: new Date('2024-01-15'),
        notes: 'Updated diagnosis',
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 2
      };
      prisma.patient_medical_history.update.mockResolvedValue(mockUpdated);

      const result = await update('history-123', updateData);

      expect(result).toEqual(mockUpdated);
      expect(prisma.patient_medical_history.update).toHaveBeenCalledWith({
        where: { id: 'history-123' },
        data: updateData
      });
    });

    it('should throw HttpError when patient medical history not found (P2025)', async () => {
      const updateData = { condition: 'Diabetes' };
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.patient_medical_history.update.mockRejectedValue(error);

      await expect(update('history-123', updateData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation (P2002)', async () => {
      const updateData = { condition: 'Duplicate' };
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['condition'] };
      prisma.patient_medical_history.update.mockRejectedValue(error);

      await expect(update('history-123', updateData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation (P2003)', async () => {
      const updateData = { patient_id: 'invalid-patient' };
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'patient_id' };
      prisma.patient_medical_history.update.mockRejectedValue(error);

      await expect(update('history-123', updateData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      const updateData = { condition: 'Diabetes' };
      prisma.patient_medical_history.update.mockRejectedValue(new Error('DB error'));

      await expect(update('history-123', updateData))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete patient medical history', async () => {
      const mockDeleted = {
        id: 'history-123',
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        condition: 'Hypertension',
        deleted_at: new Date('2026-01-19')
      };
      prisma.patient_medical_history.update.mockResolvedValue(mockDeleted);

      const result = await softDelete('history-123');

      expect(result).toEqual(mockDeleted);
      expect(prisma.patient_medical_history.update).toHaveBeenCalledWith({
        where: { id: 'history-123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError when patient medical history not found (P2025)', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.patient_medical_history.update.mockRejectedValue(error);

      await expect(softDelete('history-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.patient_medical_history.update.mockRejectedValue(new Error('DB error'));

      await expect(softDelete('history-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
