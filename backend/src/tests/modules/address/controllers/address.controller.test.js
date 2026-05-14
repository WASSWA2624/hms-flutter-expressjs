/**
 * Address controller tests
 *
 * @module tests/modules/address/controllers
 * Per testing.mdc: Mock all service dependencies
 */

// Mock dependencies
jest.mock('@services/address/address.service');
jest.mock('@lib/response');

const addressService = require('@services/address/address.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  listAddresses,
  getAddressById,
  createAddress,
  updateAddress,
  deleteAddress
} = require('@controllers/address/address.controller');

describe('Address Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: {
        id: 'user-123',
        tenant_id: 'tenant-123'
      },
      ip: '192.168.1.1',
      get: jest.fn((header) => {
        if (header === 'user-agent') return 'Mozilla/5.0';
        return null;
      })
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis()
    };
  });

  describe('listAddresses', () => {
    it('should list addresses with default pagination', async () => {
      const mockResult = {
        addresses: [
          { id: 'address-1', line1: '123 Main St', tenant_id: 'tenant-123' },
          { id: 'address-2', line1: '456 Business Ave', tenant_id: 'tenant-123' }
        ],
        pagination: {
          page: 1,
          limit: 20,
          total: 2,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      addressService.listAddresses.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = { page: 1, limit: 20 };

      await listAddresses(req, res);

      expect(addressService.listAddresses).toHaveBeenCalledWith(
        {},
        1,
        20,
        undefined,
        'asc',
        'user-123',
        '192.168.1.1'
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.address.list.success',
        mockResult.addresses,
        mockResult.pagination
      );
    });

    it('should list addresses with filters', async () => {
      const mockResult = {
        addresses: [{ id: 'address-1', line1: '123 Main St' }],
        pagination: {
          page: 1,
          limit: 20,
          total: 1,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      addressService.listAddresses.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = {
        page: 1,
        limit: 20,
        tenant_id: 'tenant-123',
        address_type: 'HOME',
        facility_id: 'facility-123',
        city: 'New York',
        search: 'Main'
      };

      await listAddresses(req, res);

      expect(addressService.listAddresses).toHaveBeenCalledWith(
        {
          tenant_id: 'tenant-123',
          address_type: 'HOME',
          facility_id: 'facility-123',
          city: 'New York',
          search: 'Main'
        },
        1,
        20,
        undefined,
        'asc',
        'user-123',
        '192.168.1.1'
      );
    });

    it('should list addresses with sorting', async () => {
      const mockResult = {
        addresses: [],
        pagination: {
          page: 1,
          limit: 20,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      addressService.listAddresses.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = {
        page: 1,
        limit: 20,
        sort_by: 'city',
        order: 'desc'
      };

      await listAddresses(req, res);

      expect(addressService.listAddresses).toHaveBeenCalledWith(
        {},
        1,
        20,
        'city',
        'desc',
        'user-123',
        '192.168.1.1'
      );
    });

    it('should handle missing user gracefully', async () => {
      const mockResult = {
        addresses: [],
        pagination: {
          page: 1,
          limit: 20,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      addressService.listAddresses.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.user = null;

      await listAddresses(req, res);

      expect(addressService.listAddresses).toHaveBeenCalledWith(
        {},
        1,
        20,
        undefined,
        'asc',
        undefined,
        '192.168.1.1'
      );
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
      addressService.getAddressById.mockResolvedValue(mockAddress);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'address-123' };

      await getAddressById(req, res);

      expect(addressService.getAddressById).toHaveBeenCalledWith(
        'address-123',
        'user-123',
        '192.168.1.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.address.get.success',
        mockAddress
      );
    });

    it('should handle missing user gracefully', async () => {
      const mockAddress = { id: 'address-123', line1: '123 Main St' };
      addressService.getAddressById.mockResolvedValue(mockAddress);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.user = null;
      req.params = { id: 'address-123' };

      await getAddressById(req, res);

      expect(addressService.getAddressById).toHaveBeenCalledWith(
        'address-123',
        undefined,
        '192.168.1.1'
      );
    });
  });

  describe('createAddress', () => {
    it('should create address', async () => {
      const addressData = {
        tenant_id: 'tenant-123',
        address_type: 'HOME',
        line1: '123 Main St',
        city: 'New York'
      };
      const mockAddress = { id: 'address-123', ...addressData };
      addressService.createAddress.mockResolvedValue(mockAddress);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.body = addressData;

      await createAddress(req, res);

      expect(addressService.createAddress).toHaveBeenCalledWith(
        addressData,
        'user-123',
        '192.168.1.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.address.create.success',
        mockAddress
      );
    });

    it('should handle missing user gracefully', async () => {
      const addressData = {
        tenant_id: 'tenant-123',
        address_type: 'HOME',
        line1: '123 Main St'
      };
      const mockAddress = { id: 'address-123', ...addressData };
      addressService.createAddress.mockResolvedValue(mockAddress);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.user = null;
      req.body = addressData;

      await createAddress(req, res);

      expect(addressService.createAddress).toHaveBeenCalledWith(
        addressData,
        undefined,
        '192.168.1.1'
      );
    });
  });

  describe('updateAddress', () => {
    it('should update address', async () => {
      const updateData = {
        line1: '456 Updated St',
        city: 'Boston'
      };
      const mockAddress = {
        id: 'address-123',
        tenant_id: 'tenant-123',
        ...updateData
      };
      addressService.updateAddress.mockResolvedValue(mockAddress);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'address-123' };
      req.body = updateData;

      await updateAddress(req, res);

      expect(addressService.updateAddress).toHaveBeenCalledWith(
        'address-123',
        updateData,
        'user-123',
        '192.168.1.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.address.update.success',
        mockAddress
      );
    });

    it('should handle missing user gracefully', async () => {
      const updateData = { line1: '456 Updated St' };
      const mockAddress = { id: 'address-123', ...updateData };
      addressService.updateAddress.mockResolvedValue(mockAddress);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.user = null;
      req.params = { id: 'address-123' };
      req.body = updateData;

      await updateAddress(req, res);

      expect(addressService.updateAddress).toHaveBeenCalledWith(
        'address-123',
        updateData,
        undefined,
        '192.168.1.1'
      );
    });
  });

  describe('deleteAddress', () => {
    it('should delete address', async () => {
      addressService.deleteAddress.mockResolvedValue();
      sendNoContent.mockImplementation((res) => {
        res.status(204).send();
      });

      req.params = { id: 'address-123' };

      await deleteAddress(req, res);

      expect(addressService.deleteAddress).toHaveBeenCalledWith(
        'address-123',
        'user-123',
        '192.168.1.1'
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });

    it('should handle missing user gracefully', async () => {
      addressService.deleteAddress.mockResolvedValue();
      sendNoContent.mockImplementation((res) => {
        res.status(204).send();
      });

      req.user = null;
      req.params = { id: 'address-123' };

      await deleteAddress(req, res);

      expect(addressService.deleteAddress).toHaveBeenCalledWith(
        'address-123',
        undefined,
        '192.168.1.1'
      );
    });
  });
});
