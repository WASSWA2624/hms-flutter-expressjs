/**
 * Address repository tests
 *
 * @module tests/modules/address/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  address: {
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
} = require('@repositories/address/address.repository');

const prisma = require('@prisma/client');

describe('Address Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find address by ID', async () => {
      const mockAddress = {
        id: 'address-123',
        tenant_id: 'tenant-123',
        address_type: 'HOME',
        line1: '123 Main Street',
        line2: 'Apt 4B',
        city: 'New York',
        state: 'NY',
        postal_code: '10001',
        country: 'USA',
        latitude: 40.7128,
        longitude: -74.0060,
        facility_id: null,
        branch_id: null,
        patient_id: null,
        user_profile_id: null,
        staff_profile_id: null,
        supplier_id: null,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.address.findFirst.mockResolvedValue(mockAddress);

      const result = await findById('address-123');

      expect(result).toEqual(mockAddress);
      expect(prisma.address.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'address-123',
          deleted_at: null
        }
      });
    });

    it('should return null if address not found', async () => {
      prisma.address.findFirst.mockResolvedValue(null);

      const result = await findById('address-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.address.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('address-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many addresses with default pagination', async () => {
      const mockAddresses = [
        {
          id: 'address-1',
          tenant_id: 'tenant-123',
          address_type: 'HOME',
          line1: '123 Main Street',
          city: 'New York',
          state: 'NY',
          country: 'USA'
        },
        {
          id: 'address-2',
          tenant_id: 'tenant-123',
          address_type: 'WORK',
          line1: '456 Business Ave',
          city: 'Boston',
          state: 'MA',
          country: 'USA'
        }
      ];
      prisma.address.findMany.mockResolvedValue(mockAddresses);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockAddresses);
      expect(prisma.address.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find addresses with filters', async () => {
      const mockAddresses = [
        {
          id: 'address-1',
          tenant_id: 'tenant-123',
          address_type: 'HOME',
          line1: '123 Main Street',
          city: 'New York'
        }
      ];
      prisma.address.findMany.mockResolvedValue(mockAddresses);

      const result = await findMany({ 
        tenant_id: 'tenant-123', 
        address_type: 'HOME',
        city: 'New York'
      }, 0, 10);

      expect(result).toEqual(mockAddresses);
      expect(prisma.address.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: 'tenant-123',
          address_type: 'HOME',
          city: 'New York'
        },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find addresses with custom sort order', async () => {
      const mockAddresses = [];
      prisma.address.findMany.mockResolvedValue(mockAddresses);

      await findMany({}, 0, 20, { line1: 'asc' });

      expect(prisma.address.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { line1: 'asc' }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.address.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany({}, 0, 20))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count addresses without filters', async () => {
      prisma.address.count.mockResolvedValue(42);

      const result = await count({});

      expect(result).toBe(42);
      expect(prisma.address.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count addresses with filters', async () => {
      prisma.address.count.mockResolvedValue(5);

      const result = await count({ 
        tenant_id: 'tenant-123',
        address_type: 'HOME'
      });

      expect(result).toBe(5);
      expect(prisma.address.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: 'tenant-123',
          address_type: 'HOME'
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.address.count.mockRejectedValue(new Error('DB error'));

      await expect(count({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create address', async () => {
      const addressData = {
        tenant_id: 'tenant-123',
        address_type: 'HOME',
        line1: '123 Main Street',
        line2: 'Apt 4B',
        city: 'New York',
        state: 'NY',
        postal_code: '10001',
        country: 'USA',
        latitude: 40.7128,
        longitude: -74.0060
      };
      const mockAddress = { id: 'address-123', ...addressData };
      prisma.address.create.mockResolvedValue(mockAddress);

      const result = await create(addressData);

      expect(result).toEqual(mockAddress);
      expect(prisma.address.create).toHaveBeenCalledWith({
        data: addressData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['line1'] };
      prisma.address.create.mockRejectedValue(error);

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };
      prisma.address.create.mockRejectedValue(error);

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.address.create.mockRejectedValue(new Error('DB error'));

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update address', async () => {
      const updateData = {
        line1: '456 Updated Street',
        city: 'Boston'
      };
      const mockAddress = {
        id: 'address-123',
        tenant_id: 'tenant-123',
        address_type: 'HOME',
        ...updateData
      };
      prisma.address.update.mockResolvedValue(mockAddress);

      const result = await update('address-123', updateData);

      expect(result).toEqual(mockAddress);
      expect(prisma.address.update).toHaveBeenCalledWith({
        where: { id: 'address-123' },
        data: updateData
      });
    });

    it('should throw HttpError when address not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.address.update.mockRejectedValue(error);

      await expect(update('address-123', {}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['line1'] };
      prisma.address.update.mockRejectedValue(error);

      await expect(update('address-123', {}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'facility_id' };
      prisma.address.update.mockRejectedValue(error);

      await expect(update('address-123', {}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.address.update.mockRejectedValue(new Error('DB error'));

      await expect(update('address-123', {}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete address', async () => {
      const mockAddress = {
        id: 'address-123',
        deleted_at: new Date('2026-01-19')
      };
      prisma.address.update.mockResolvedValue(mockAddress);

      const result = await softDelete('address-123');

      expect(result).toEqual(mockAddress);
      expect(prisma.address.update).toHaveBeenCalledWith({
        where: { id: 'address-123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError when address not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.address.update.mockRejectedValue(error);

      await expect(softDelete('address-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.address.update.mockRejectedValue(new Error('DB error'));

      await expect(softDelete('address-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
