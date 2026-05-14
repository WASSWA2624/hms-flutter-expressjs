/**
 * Consent repository tests
 *
 * @module tests/modules/consent/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  consent: {
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
} = require('@repositories/consent/consent.repository');

const prisma = require('@prisma/client');

describe('Consent Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find consent by ID', async () => {
      const mockConsent = {
        id: 'consent-123',
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        consent_type: 'TREATMENT',
        status: 'GRANTED',
        granted_at: new Date('2026-01-19'),
        revoked_at: null,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.consent.findFirst.mockResolvedValue(mockConsent);

      const result = await findById('consent-123');

      expect(result).toEqual(mockConsent);
      expect(prisma.consent.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'consent-123',
          deleted_at: null
        },
        include: {}
      });
    });

    it('should return null if consent not found', async () => {
      prisma.consent.findFirst.mockResolvedValue(null);

      const result = await findById('consent-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.consent.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('consent-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should support include parameter', async () => {
      const mockConsent = { id: 'consent-123' };
      prisma.consent.findFirst.mockResolvedValue(mockConsent);

      await findById('consent-123', { patient: true });

      expect(prisma.consent.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'consent-123',
          deleted_at: null
        },
        include: { patient: true }
      });
    });
  });

  describe('findMany', () => {
    it('should find many consents with default pagination', async () => {
      const mockConsents = [
        {
          id: 'consent-1',
          tenant_id: 'tenant-123',
          patient_id: 'patient-123',
          consent_type: 'TREATMENT',
          status: 'GRANTED'
        },
        {
          id: 'consent-2',
          tenant_id: 'tenant-123',
          patient_id: 'patient-456',
          consent_type: 'DATA_SHARING',
          status: 'PENDING'
        }
      ];
      prisma.consent.findMany.mockResolvedValue(mockConsents);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockConsents);
      expect(prisma.consent.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should find consents with filters', async () => {
      const mockConsents = [
        {
          id: 'consent-1',
          patient_id: 'patient-123',
          consent_type: 'TREATMENT',
          status: 'GRANTED'
        }
      ];
      prisma.consent.findMany.mockResolvedValue(mockConsents);

      const result = await findMany({ 
        patient_id: 'patient-123', 
        consent_type: 'TREATMENT'
      }, 0, 10);

      expect(result).toEqual(mockConsents);
      expect(prisma.consent.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          patient_id: 'patient-123',
          consent_type: 'TREATMENT'
        },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should find consents with custom pagination', async () => {
      const mockConsents = [];
      prisma.consent.findMany.mockResolvedValue(mockConsents);

      const result = await findMany({}, 20, 50);

      expect(result).toEqual(mockConsents);
      expect(prisma.consent.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 20,
        take: 50,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should find consents with custom orderBy', async () => {
      const mockConsents = [];
      prisma.consent.findMany.mockResolvedValue(mockConsents);

      const result = await findMany({}, 0, 20, { granted_at: 'asc' });

      expect(result).toEqual(mockConsents);
      expect(prisma.consent.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { granted_at: 'asc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.consent.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count consents without filters', async () => {
      prisma.consent.count.mockResolvedValue(42);

      const result = await count({});

      expect(result).toBe(42);
      expect(prisma.consent.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count consents with filters', async () => {
      prisma.consent.count.mockResolvedValue(5);

      const result = await count({ 
        patient_id: 'patient-123',
        status: 'GRANTED'
      });

      expect(result).toBe(5);
      expect(prisma.consent.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          patient_id: 'patient-123',
          status: 'GRANTED'
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.consent.count.mockRejectedValue(new Error('DB error'));

      await expect(count({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create consent', async () => {
      const consentData = {
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        consent_type: 'TREATMENT',
        status: 'GRANTED',
        granted_at: new Date('2026-01-19')
      };
      const mockConsent = { id: 'consent-123', ...consentData };
      prisma.consent.create.mockResolvedValue(mockConsent);

      const result = await create(consentData);

      expect(result).toEqual(mockConsent);
      expect(prisma.consent.create).toHaveBeenCalledWith({
        data: consentData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['field'] };
      prisma.consent.create.mockRejectedValue(error);

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'patient_id' };
      prisma.consent.create.mockRejectedValue(error);

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.consent.create.mockRejectedValue(new Error('Unexpected error'));

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update consent', async () => {
      const updateData = {
        status: 'REVOKED',
        revoked_at: new Date('2026-01-19')
      };
      const mockConsent = { id: 'consent-123', ...updateData };
      prisma.consent.update.mockResolvedValue(mockConsent);

      const result = await update('consent-123', updateData);

      expect(result).toEqual(mockConsent);
      expect(prisma.consent.update).toHaveBeenCalledWith({
        where: { id: 'consent-123' },
        data: updateData
      });
    });

    it('should throw HttpError if consent not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.consent.update.mockRejectedValue(error);

      await expect(update('consent-123', {}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['field'] };
      prisma.consent.update.mockRejectedValue(error);

      await expect(update('consent-123', {}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'patient_id' };
      prisma.consent.update.mockRejectedValue(error);

      await expect(update('consent-123', {}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.consent.update.mockRejectedValue(new Error('Unexpected error'));

      await expect(update('consent-123', {}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete consent', async () => {
      const mockConsent = {
        id: 'consent-123',
        deleted_at: new Date('2026-01-19')
      };
      prisma.consent.update.mockResolvedValue(mockConsent);

      const result = await softDelete('consent-123');

      expect(result).toEqual(mockConsent);
      expect(prisma.consent.update).toHaveBeenCalledWith({
        where: { id: 'consent-123' },
        data: {
          deleted_at: expect.any(Date)
        }
      });
    });

    it('should throw HttpError if consent not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.consent.update.mockRejectedValue(error);

      await expect(softDelete('consent-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.consent.update.mockRejectedValue(new Error('Unexpected error'));

      await expect(softDelete('consent-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
