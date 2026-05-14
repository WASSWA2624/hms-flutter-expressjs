/**
 * License repository tests
 *
 * @module tests/modules/license/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  license: {
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
} = require('@repositories/license/license.repository');

const prisma = require('@prisma/client');

describe('License Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find license by ID with tenant', async () => {
      const mockLicense = {
        id: 'license-123',
        tenant_id: 'tenant-123',
        license_type: 'PER_USER',
        status: 'ACTIVE',
        deleted_at: null,
        tenant: { id: 'tenant-123', name: 'Test Tenant' }
      };
      prisma.license.findFirst.mockResolvedValue(mockLicense);

      const result = await findById('license-123');

      expect(result).toEqual(mockLicense);
      expect(prisma.license.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'license-123',
          deleted_at: null
        },
        include: {
          tenant: true
        }
      });
    });

    it('should return null if not found', async () => {
      prisma.license.findFirst.mockResolvedValue(null);
      const result = await findById('license-123');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.license.findFirst.mockRejectedValue(new Error('DB error'));
      await expect(findById('license-123')).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create license with tenant', async () => {
      const data = {
        tenant_id: 'tenant-123',
        license_type: 'PER_USER',
        status: 'ACTIVE'
      };
      const mockCreated = {
        id: 'license-new',
        ...data,
        tenant: { id: 'tenant-123' }
      };
      prisma.license.create.mockResolvedValue(mockCreated);

      const result = await create(data);

      expect(result).toEqual(mockCreated);
    });

    it('should throw HttpError on foreign key violation', async () => {
      const error = new Error('Foreign key constraint failed');
      error.code = 'P2003';
      prisma.license.create.mockRejectedValue(error);

      await expect(create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update license', async () => {
      const mockUpdated = {
        id: 'license-123',
        status: 'CANCELLED',
        tenant: { id: 'tenant-123' }
      };
      prisma.license.update.mockResolvedValue(mockUpdated);

      const result = await update('license-123', { status: 'CANCELLED' });

      expect(result).toEqual(mockUpdated);
    });

    it('should throw HttpError when not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.license.update.mockRejectedValue(error);

      await expect(update('license-123', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete license', async () => {
      const mockDeleted = {
        id: 'license-123',
        deleted_at: new Date()
      };
      prisma.license.update.mockResolvedValue(mockDeleted);

      const result = await softDelete('license-123');

      expect(result).toEqual(mockDeleted);
    });
  });
});
