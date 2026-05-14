/**
 * Tenant controller tests
 *
 * @module tests/modules/tenant/controllers
 * Per testing.mdc: Mock all service dependencies
 */

// Mock dependencies
jest.mock('@services/tenant/tenant.service');
jest.mock('@lib/response');

const tenantService = require('@services/tenant/tenant.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  listTenants,
  getTenantById,
  createTenant,
  updateTenant,
  deleteTenant
} = require('@controllers/tenant/tenant.controller');

describe('Tenant Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: {
        id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123'
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

  describe('listTenants', () => {
    it('should list tenants with default pagination', async () => {
      const mockResult = {
        tenants: [
          { id: 'tenant-1', name: 'Hospital A' },
          { id: 'tenant-2', name: 'Hospital B' }
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
      tenantService.listTenants.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = { page: 1, limit: 20 };

      await listTenants(req, res);

      expect(tenantService.listTenants).toHaveBeenCalledWith(
        {},
        1,
        20,
        undefined,
        undefined
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.tenant.list.success',
        mockResult.tenants,
        mockResult.pagination
      );
    });

    it('should list tenants with filters', async () => {
      const mockResult = {
        tenants: [{ id: 'tenant-1', name: 'Hospital A' }],
        pagination: {
          page: 1,
          limit: 20,
          total: 1,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      tenantService.listTenants.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = {
        page: 1,
        limit: 20,
        is_active: 'true',
        search: 'hospital'
      };

      await listTenants(req, res);

      expect(tenantService.listTenants).toHaveBeenCalledWith(
        { is_active: 'true', search: 'hospital' },
        1,
        20,
        undefined,
        undefined
      );
    });

    it('should list tenants with sorting', async () => {
      const mockResult = {
        tenants: [],
        pagination: {
          page: 1,
          limit: 20,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      tenantService.listTenants.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = {
        page: 1,
        limit: 20,
        sort_by: 'name',
        order: 'asc'
      };

      await listTenants(req, res);

      expect(tenantService.listTenants).toHaveBeenCalledWith(
        {},
        1,
        20,
        'name',
        'asc'
      );
    });
  });

  describe('getTenantById', () => {
    it('should get tenant by ID', async () => {
      const mockTenant = {
        id: 'tenant-123',
        name: 'Test Hospital',
        slug: 'test-hospital',
        is_active: true
      };
      tenantService.getTenantById.mockResolvedValue(mockTenant);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'tenant-123' };

      await getTenantById(req, res);

      expect(tenantService.getTenantById).toHaveBeenCalledWith('tenant-123');
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.tenant.get.success',
        mockTenant
      );
    });
  });

  describe('createTenant', () => {
    it('should create tenant successfully', async () => {
      const tenantData = {
        name: 'New Hospital',
        slug: 'new-hospital',
        is_active: true
      };
      const mockCreatedTenant = {
        id: 'tenant-new',
        ...tenantData,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };
      tenantService.createTenant.mockResolvedValue(mockCreatedTenant);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.body = tenantData;

      await createTenant(req, res);

      expect(tenantService.createTenant).toHaveBeenCalledWith(
        tenantData,
        {
          user_id: 'user-123',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          ip_address: '192.168.1.1',
          user_agent: 'Mozilla/5.0'
        }
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.tenant.create.success',
        mockCreatedTenant
      );
    });

    it('should create tenant without user context', async () => {
      const tenantData = {
        name: 'New Hospital'
      };
      const mockCreatedTenant = {
        id: 'tenant-new',
        ...tenantData,
        slug: null,
        is_active: true,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };
      tenantService.createTenant.mockResolvedValue(mockCreatedTenant);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.body = tenantData;
      req.user = undefined;

      await createTenant(req, res);

      expect(tenantService.createTenant).toHaveBeenCalledWith(
        tenantData,
        {
          user_id: undefined,
          tenant_id: undefined,
          facility_id: undefined,
          ip_address: '192.168.1.1',
          user_agent: 'Mozilla/5.0'
        }
      );
    });
  });

  describe('updateTenant', () => {
    it('should update tenant successfully', async () => {
      const updateData = {
        name: 'Updated Hospital',
        is_active: false
      };
      const mockUpdatedTenant = {
        id: 'tenant-123',
        name: 'Updated Hospital',
        slug: 'test-hospital',
        is_active: false,
        created_at: new Date('2026-01-19'),
        updated_at: new Date(),
        deleted_at: null,
        version: 2
      };
      tenantService.updateTenant.mockResolvedValue(mockUpdatedTenant);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'tenant-123' };
      req.body = updateData;

      await updateTenant(req, res);

      expect(tenantService.updateTenant).toHaveBeenCalledWith(
        'tenant-123',
        updateData,
        {
          user_id: 'user-123',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          ip_address: '192.168.1.1',
          user_agent: 'Mozilla/5.0'
        }
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.tenant.update.success',
        mockUpdatedTenant
      );
    });
  });

  describe('deleteTenant', () => {
    it('should delete tenant successfully', async () => {
      tenantService.deleteTenant.mockResolvedValue(undefined);
      sendNoContent.mockImplementation((res) => {
        res.status(204).send();
      });

      req.params = { id: 'tenant-123' };

      await deleteTenant(req, res);

      expect(tenantService.deleteTenant).toHaveBeenCalledWith(
        'tenant-123',
        {
          user_id: 'user-123',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          ip_address: '192.168.1.1',
          user_agent: 'Mozilla/5.0'
        }
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });
});
