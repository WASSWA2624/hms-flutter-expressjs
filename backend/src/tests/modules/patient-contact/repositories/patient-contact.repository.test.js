/**
 * Patient Contact repository tests
 *
 * @module tests/modules/patient-contact/repositories
 * @description Tests for patient contact repository operations
 * Per testing.mdc: Repository tests must mock Prisma client
 */

const patientContactRepository = require('@repositories/patient-contact/patient-contact.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  patient_contact: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Patient Contact Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find patient contact by id', async () => {
      const mockContact = { id: '123', contact_type: 'PHONE', value: '+256700000000' };
      prisma.patient_contact.findFirst.mockResolvedValue(mockContact);

      const result = await patientContactRepository.findById('123');
      expect(result).toEqual(mockContact);
      expect(prisma.patient_contact.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include: {}
      });
    });

    it('should return null if not found', async () => {
      prisma.patient_contact.findFirst.mockResolvedValue(null);

      const result = await patientContactRepository.findById('nonexistent');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.patient_contact.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(patientContactRepository.findById('123')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many patient contacts with pagination', async () => {
      const mockContacts = [
        { id: '1', contact_type: 'PHONE', value: '+256700000001' },
        { id: '2', contact_type: 'EMAIL', value: 'test@example.com' }
      ];
      prisma.patient_contact.findMany.mockResolvedValue(mockContacts);

      const result = await patientContactRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockContacts);
    });

    it('should apply filters correctly', async () => {
      prisma.patient_contact.findMany.mockResolvedValue([]);

      await patientContactRepository.findMany({ contact_type: 'EMAIL' }, 0, 20);
      expect(prisma.patient_contact.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, contact_type: 'EMAIL' },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });
  });

  describe('count', () => {
    it('should count patient contacts', async () => {
      prisma.patient_contact.count.mockResolvedValue(15);

      const result = await patientContactRepository.count({});
      expect(result).toBe(15);
    });
  });

  describe('create', () => {
    it('should create patient contact', async () => {
      const mockData = { tenant_id: '123', patient_id: '456', contact_type: 'PHONE', value: '+256700000000' };
      const mockContact = { id: '789', ...mockData };
      prisma.patient_contact.create.mockResolvedValue(mockContact);

      const result = await patientContactRepository.create(mockData);
      expect(result).toEqual(mockContact);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['value'] };
      prisma.patient_contact.create.mockRejectedValue(error);

      await expect(patientContactRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'patient_id' };
      prisma.patient_contact.create.mockRejectedValue(error);

      await expect(patientContactRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update patient contact', async () => {
      const mockContact = { id: '123', value: 'updated@example.com' };
      prisma.patient_contact.update.mockResolvedValue(mockContact);

      const result = await patientContactRepository.update('123', { value: 'updated@example.com' });
      expect(result).toEqual(mockContact);
    });

    it('should throw HttpError if not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.patient_contact.update.mockRejectedValue(error);

      await expect(patientContactRepository.update('nonexistent', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete patient contact', async () => {
      const mockContact = { id: '123', deleted_at: new Date() };
      prisma.patient_contact.update.mockResolvedValue(mockContact);

      const result = await patientContactRepository.softDelete('123');
      expect(result).toEqual(mockContact);
      expect(prisma.patient_contact.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { deleted_at: expect.any(Date) }
      });
    });
  });
});
