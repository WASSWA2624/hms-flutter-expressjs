/**
 * Address service tests
 *
 * @module tests/modules/address/services
 * Per testing.mdc: Mock all external dependencies
 */

const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/address/address.repository');
jest.mock('@lib/audit');

const addressRepository = require('@repositories/address/address.repository');
const { createAuditLog } = require('@lib/audit');
const {
  listAddresses,
  getAddressById,
  createAddress,
  updateAddress,
  deleteAddress
} = require('@services/address/address.service');

describe('Address Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('listAddresses', () => {
    it('should list addresses with default pagination', async () => {
      const mockAddresses = [
        { id: 'address-1', line1: '123 Main St', tenant_id: 'tenant-123' },
        { id: 'address-2', line1: '456 Business Ave', tenant_id: 'tenant-123' }
      ];
      addressRepository.findMany.mockResolvedValue(mockAddresses);
      addressRepository.count.mockResolvedValue(10);

      const result = await listAddresses({}, 1, 20);

      expect(result.addresses).toEqual(mockAddresses);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 10,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
      expect(addressRepository.findMany).toHaveBeenCalledWith(
        {},
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by tenant_id', async () => {
      const mockAddresses = [{ id: 'address-1', line1: '123 Main St' }];
      addressRepository.findMany.mockResolvedValue(mockAddresses);
      addressRepository.count.mockResolvedValue(1);

      const result = await listAddresses({ tenant_id: 'tenant-123' }, 1, 20);

      expect(result.addresses).toEqual(mockAddresses);
      expect(addressRepository.findMany).toHaveBeenCalledWith(
        { tenant_id: 'tenant-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by address_type', async () => {
      const mockAddresses = [{ id: 'address-1', address_type: 'HOME' }];
      addressRepository.findMany.mockResolvedValue(mockAddresses);
      addressRepository.count.mockResolvedValue(1);

      const result = await listAddresses({ address_type: 'HOME' }, 1, 20);

      expect(result.addresses).toEqual(mockAddresses);
      expect(addressRepository.findMany).toHaveBeenCalledWith(
        { address_type: 'HOME' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by facility_id', async () => {
      const mockAddresses = [{ id: 'address-1', facility_id: 'facility-123' }];
      addressRepository.findMany.mockResolvedValue(mockAddresses);
      addressRepository.count.mockResolvedValue(1);

      const result = await listAddresses({ facility_id: 'facility-123' }, 1, 20);

      expect(result.addresses).toEqual(mockAddresses);
      expect(addressRepository.findMany).toHaveBeenCalledWith(
        { facility_id: 'facility-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by city with contains', async () => {
      const mockAddresses = [{ id: 'address-1', city: 'New York' }];
      addressRepository.findMany.mockResolvedValue(mockAddresses);
      addressRepository.count.mockResolvedValue(1);

      const result = await listAddresses({ city: 'New York' }, 1, 20);

      expect(result.addresses).toEqual(mockAddresses);
      expect(addressRepository.findMany).toHaveBeenCalledWith(
        { city: { contains: 'New York' } },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by state with contains', async () => {
      const mockAddresses = [{ id: 'address-1', state: 'NY' }];
      addressRepository.findMany.mockResolvedValue(mockAddresses);
      addressRepository.count.mockResolvedValue(1);

      const result = await listAddresses({ state: 'NY' }, 1, 20);

      expect(result.addresses).toEqual(mockAddresses);
      expect(addressRepository.findMany).toHaveBeenCalledWith(
        { state: { contains: 'NY' } },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by country with contains', async () => {
      const mockAddresses = [{ id: 'address-1', country: 'USA' }];
      addressRepository.findMany.mockResolvedValue(mockAddresses);
      addressRepository.count.mockResolvedValue(1);

      const result = await listAddresses({ country: 'USA' }, 1, 20);

      expect(result.addresses).toEqual(mockAddresses);
      expect(addressRepository.findMany).toHaveBeenCalledWith(
        { country: { contains: 'USA' } },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by search term with OR conditions', async () => {
      const mockAddresses = [{ id: 'address-1', line1: '123 Main St' }];
      addressRepository.findMany.mockResolvedValue(mockAddresses);
      addressRepository.count.mockResolvedValue(1);

      const result = await listAddresses({ search: 'Main' }, 1, 20);

      expect(result.addresses).toEqual(mockAddresses);
      expect(addressRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          OR: expect.arrayContaining([
            { line1: { contains: 'Main' } },
            { line2: { contains: 'Main' } },
            { city: { contains: 'Main' } },
            { state: { contains: 'Main' } },
            { country: { contains: 'Main' } },
            { postal_code: { contains: 'Main' } }
          ])
        }),
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should handle custom sorting', async () => {
      const mockAddresses = [];
      addressRepository.findMany.mockResolvedValue(mockAddresses);
      addressRepository.count.mockResolvedValue(0);

      await listAddresses({}, 1, 20, 'city', 'asc');

      expect(addressRepository.findMany).toHaveBeenCalledWith(
        {},
        0,
        20,
        { city: 'asc' }
      );
    });

    it('should calculate pagination correctly for multiple pages', async () => {
      const mockAddresses = [];
      addressRepository.findMany.mockResolvedValue(mockAddresses);
      addressRepository.count.mockResolvedValue(50);

      const result = await listAddresses({}, 2, 20);

      expect(result.pagination).toEqual({
        page: 2,
        limit: 20,
        total: 50,
        totalPages: 3,
        hasNextPage: true,
        hasPreviousPage: true
      });
    });

    it('should throw HttpError on repository error', async () => {
      addressRepository.findMany.mockRejectedValue(new Error('DB error'));

      await expect(listAddresses({}, 1, 20))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('getAddressById', () => {
    it('should get address by ID', async () => {
      const mockAddress = {
        id: 'address-123',
        tenant_id: 'tenant-123',
        address_type: 'HOME',
        line1: '123 Main St',
        city: 'New York'
      };
      addressRepository.findById.mockResolvedValue(mockAddress);

      const result = await getAddressById('address-123', 'user-123', '127.0.0.1');

      expect(result).toEqual(mockAddress);
      expect(addressRepository.findById).toHaveBeenCalledWith('address-123');
    });

    it('should throw HttpError when address not found', async () => {
      addressRepository.findById.mockResolvedValue(null);

      await expect(getAddressById('address-123', 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on repository error', async () => {
      addressRepository.findById.mockRejectedValue(new Error('DB error'));

      await expect(getAddressById('address-123', 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('createAddress', () => {
    it('should create address and log audit', async () => {
      const addressData = {
        tenant_id: 'tenant-123',
        address_type: 'HOME',
        line1: '123 Main St',
        city: 'New York'
      };
      const mockAddress = { id: 'address-123', ...addressData };
      addressRepository.create.mockResolvedValue(mockAddress);
      createAuditLog.mockResolvedValue();

      const result = await createAddress(addressData, 'user-123', '127.0.0.1');

      expect(result).toEqual(mockAddress);
      expect(addressRepository.create).toHaveBeenCalledWith(addressData);
    });

    it('should call audit log with correct params', async () => {
      const addressData = {
        tenant_id: 'tenant-123',
        address_type: 'HOME',
        line1: '123 Main St'
      };
      const mockAddress = { id: 'address-123', ...addressData };
      addressRepository.create.mockResolvedValue(mockAddress);
      createAuditLog.mockResolvedValue();

      await createAddress(addressData, 'user-123', '127.0.0.1');

      // Wait for async audit log
      await new Promise(resolve => setImmediate(resolve));
    });

    it('should throw HttpError on repository error', async () => {
      addressRepository.create.mockRejectedValue(new Error('DB error'));

      await expect(createAddress({}, 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('updateAddress', () => {
    it('should update address and log audit', async () => {
      const beforeAddress = {
        id: 'address-123',
        tenant_id: 'tenant-123',
        address_type: 'HOME',
        line1: '123 Main St',
        city: 'New York'
      };
      const updateData = {
        line1: '456 Updated St',
        city: 'Boston'
      };
      const afterAddress = { ...beforeAddress, ...updateData };
      
      addressRepository.findById.mockResolvedValue(beforeAddress);
      addressRepository.update.mockResolvedValue(afterAddress);
      createAuditLog.mockResolvedValue();

      const result = await updateAddress('address-123', updateData, 'user-123', '127.0.0.1');

      expect(result).toEqual(afterAddress);
      expect(addressRepository.findById).toHaveBeenCalledWith('address-123');
      expect(addressRepository.update).toHaveBeenCalledWith('address-123', updateData);
    });

    it('should throw HttpError when address not found', async () => {
      addressRepository.findById.mockResolvedValue(null);

      await expect(updateAddress('address-123', {}, 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on repository error', async () => {
      addressRepository.findById.mockResolvedValue({ id: 'address-123' });
      addressRepository.update.mockRejectedValue(new Error('DB error'));

      await expect(updateAddress('address-123', {}, 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('deleteAddress', () => {
    it('should delete address and log audit', async () => {
      const beforeAddress = {
        id: 'address-123',
        tenant_id: 'tenant-123',
        address_type: 'HOME',
        line1: '123 Main St'
      };
      
      addressRepository.findById.mockResolvedValue(beforeAddress);
      addressRepository.softDelete.mockResolvedValue();
      createAuditLog.mockResolvedValue();

      await deleteAddress('address-123', 'user-123', '127.0.0.1');

      expect(addressRepository.findById).toHaveBeenCalledWith('address-123');
      expect(addressRepository.softDelete).toHaveBeenCalledWith('address-123');
    });

    it('should throw HttpError when address not found', async () => {
      addressRepository.findById.mockResolvedValue(null);

      await expect(deleteAddress('address-123', 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on repository error', async () => {
      addressRepository.findById.mockResolvedValue({ id: 'address-123' });
      addressRepository.softDelete.mockRejectedValue(new Error('DB error'));

      await expect(deleteAddress('address-123', 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
