/**
 * Admission repository tests
 *
 * @module tests/modules/admission/repositories
 * @description Tests for admission repository data access layer
 */

const admissionRepository = require('../../../../modules/admission/repositories/admission.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  admission: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Admission Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find admission by id', async () => {
      const mockAdmission = {
        id: 'test-id',
        tenant_id: 'tenant-id',
        patient_id: 'patient-id',
        status: 'ADMITTED',
        deleted_at: null
      };

      prisma.admission.findFirst.mockResolvedValue(mockAdmission);

      const result = await admissionRepository.findById('test-id');

      expect(prisma.admission.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'test-id',
          deleted_at: null,
          AND: [{ patient: { deleted_at: null } }]
        },
        include: {}
      });
      expect(result).toEqual(mockAdmission);
    });

    it('should return null if admission not found', async () => {
      prisma.admission.findFirst.mockResolvedValue(null);

      const result = await admissionRepository.findById('non-existent-id');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.admission.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(admissionRepository.findById('test-id')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find admissions with filters and pagination', async () => {
      const mockAdmissions = [
        { id: '1', status: 'ADMITTED', deleted_at: null },
        { id: '2', status: 'DISCHARGED', deleted_at: null }
      ];

      prisma.admission.findMany.mockResolvedValue(mockAdmissions);

      const filters = { tenant_id: 'tenant-id' };
      const result = await admissionRepository.findMany(filters, 0, 10);

      expect(prisma.admission.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: 'tenant-id',
          AND: [{ patient: { deleted_at: null } }]
        },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' },
        include: {}
      });
      expect(result).toEqual(mockAdmissions);
    });

    it('should throw HttpError on database error', async () => {
      prisma.admission.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(admissionRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count admissions with filters', async () => {
      prisma.admission.count.mockResolvedValue(5);

      const filters = { status: 'ADMITTED' };
      const result = await admissionRepository.count(filters);

      expect(prisma.admission.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          status: 'ADMITTED',
          AND: [{ patient: { deleted_at: null } }]
        }
      });
      expect(result).toBe(5);
    });

    it('should throw HttpError on database error', async () => {
      prisma.admission.count.mockRejectedValue(new Error('DB Error'));

      await expect(admissionRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create new admission', async () => {
      const admissionData = {
        tenant_id: 'tenant-id',
        patient_id: 'patient-id',
        status: 'ADMITTED'
      };
      const mockCreatedAdmission = { id: 'new-id', ...admissionData };

      prisma.admission.create.mockResolvedValue(mockCreatedAdmission);

      const result = await admissionRepository.create(admissionData);

      expect(prisma.admission.create).toHaveBeenCalledWith({ data: admissionData });
      expect(result).toEqual(mockCreatedAdmission);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = { code: 'P2002', meta: { target: ['patient_id'] } };
      prisma.admission.create.mockRejectedValue(error);

      await expect(admissionRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key violation', async () => {
      const error = { code: 'P2003', meta: { field_name: 'patient_id' } };
      prisma.admission.create.mockRejectedValue(error);

      await expect(admissionRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.admission.create.mockRejectedValue(new Error('DB Error'));

      await expect(admissionRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update admission', async () => {
      const updateData = { status: 'DISCHARGED' };
      const mockUpdatedAdmission = { id: 'test-id', ...updateData };

      prisma.admission.update.mockResolvedValue(mockUpdatedAdmission);

      const result = await admissionRepository.update('test-id', updateData);

      expect(prisma.admission.update).toHaveBeenCalledWith({
        where: { id: 'test-id' },
        data: updateData
      });
      expect(result).toEqual(mockUpdatedAdmission);
    });

    it('should throw HttpError if admission not found', async () => {
      const error = { code: 'P2025' };
      prisma.admission.update.mockRejectedValue(error);

      await expect(admissionRepository.update('non-existent', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = { code: 'P2002', meta: { target: ['field'] } };
      prisma.admission.update.mockRejectedValue(error);

      await expect(admissionRepository.update('test-id', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key violation', async () => {
      const error = { code: 'P2003', meta: { field_name: 'patient_id' } };
      prisma.admission.update.mockRejectedValue(error);

      await expect(admissionRepository.update('test-id', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete admission', async () => {
      const mockDeletedAdmission = {
        id: 'test-id',
        deleted_at: expect.any(Date)
      };

      prisma.admission.update.mockResolvedValue(mockDeletedAdmission);

      const result = await admissionRepository.softDelete('test-id');

      expect(prisma.admission.update).toHaveBeenCalledWith({
        where: { id: 'test-id' },
        data: { deleted_at: expect.any(Date) }
      });
      expect(result).toEqual(mockDeletedAdmission);
    });

    it('should throw HttpError if admission not found', async () => {
      const error = { code: 'P2025' };
      prisma.admission.update.mockRejectedValue(error);

      await expect(admissionRepository.softDelete('non-existent')).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on database error', async () => {
      prisma.admission.update.mockRejectedValue(new Error('DB Error'));

      await expect(admissionRepository.softDelete('test-id')).rejects.toThrow(HttpError);
    });
  });
});
