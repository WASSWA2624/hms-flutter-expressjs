/**
 * Tenant service tests
 *
 * @module tests/modules/tenant/services
 * Per testing.mdc: Mock all external dependencies
 */

const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/tenant/tenant.repository');
jest.mock('@lib/audit');

const tenantRepository = require('@repositories/tenant/tenant.repository');
const { createAuditLog } = require('@lib/audit');
const {
  listTenants,
  getTenantById,
  createTenant,
  updateTenant,
  deleteTenant
} = require('@services/tenant/tenant.service');

describe('Tenant Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('listTenants', () => {
    it('should list tenants with default pagination', async () => {
      const mockTenants = [
        { id: 'tenant-1', name: 'Hospital A' },
        { id: 'tenant-2', name: 'Hospital B' }
      ];
      tenantRepository.findMany.mockResolvedValue(mockTenants);
      tenantRepository.count.mockResolvedValue(10);

      const result = await listTenants({}, 1, 20);

      expect(result.tenants).toEqual(mockTenants);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 10,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
      expect(tenantRepository.findMany).toHaveBeenCalledWith(
        {},
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by is_active=true', async () => {
      const mockTenants = [{ id: 'tenant-1', name: 'Hospital A' }];
      tenantRepository.findMany.mockResolvedValue(mockTenants);
      tenantRepository.count.mockResolvedValue(1);

      const result = await listTenants({ is_active: 'true' }, 1, 20);

      expect(result.tenants).toEqual(mockTenants);
      expect(tenantRepository.findMany).toHaveBeenCalledWith(
        { is_active: true },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by is_active=false', async () => {
      const mockTenants = [{ id: 'tenant-1', name: 'Hospital A' }];
      tenantRepository.findMany.mockResolvedValue(mockTenants);
      tenantRepository.count.mockResolvedValue(1);

      const result = await listTenants({ is_active: 'false' }, 1, 20);

      expect(result.tenants).toEqual(mockTenants);
      expect(tenantRepository.findMany).toHaveBeenCalledWith(
        { is_active: false },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by search term', async () => {
      const mockTenants = [{ id: 'tenant-1', name: 'Test Hospital' }];
      tenantRepository.findMany.mockResolvedValue(mockTenants);
      tenantRepository.count.mockResolvedValue(1);

      const result = await listTenants({ search: 'hospital' }, 1, 20);

      expect(result.tenants).toEqual(mockTenants);
      expect(tenantRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          OR: expect.arrayContaining([
            { name: { contains: 'hospital' } },
            { slug: { contains: 'hospital' } }
          ])
        }),
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should handle custom sorting', async () => {
      const mockTenants = [];
      tenantRepository.findMany.mockResolvedValue(mockTenants);
      tenantRepository.count.mockResolvedValue(0);

      await listTenants({}, 1, 20, 'name', 'asc');

      expect(tenantRepository.findMany).toHaveBeenCalledWith(
        {},
        0,
        20,
        { name: 'asc' }
      );
    });

    it('should calculate pagination correctly for multiple pages', async () => {
      const mockTenants = [];
      tenantRepository.findMany.mockResolvedValue(mockTenants);
      tenantRepository.count.mockResolvedValue(50);

      const result = await listTenants({}, 2, 20);

      expect(result.pagination).toEqual({
        page: 2,
        limit: 20,
        total: 50,
        totalPages: 3,
        hasNextPage: true,
        hasPreviousPage: true
      });
    });

    it('should expose the primary tenant admin in list payloads when available', async () => {
      tenantRepository.findMany.mockResolvedValue([
        {
          id: 'tenant-1',
          name: 'Hospital A',
          user_roles: [
            {
              id: 'user-role-1',
              human_friendly_id: 'URO0000001',
              role_id: 'role-1',
              facility_id: 'facility-1',
              role: {
                id: 'role-1',
                human_friendly_id: 'ROL0000001',
                name: 'TENANT_ADMIN',
              },
              user: {
                id: 'user-1',
                human_friendly_id: 'USR0000001',
                email: 'tenant.admin@hms-demo.test',
                phone: '+256700000001',
                status: 'ACTIVE',
                facility_id: 'facility-1',
                profile: {
                  first_name: 'Taylor',
                  middle_name: null,
                  last_name: 'Demo',
                },
                facility: {
                  id: 'facility-1',
                  human_friendly_id: 'FAC0000001',
                  name: 'DemoCare General Hospital',
                },
              },
            },
          ],
        },
      ]);
      tenantRepository.count.mockResolvedValue(1);

      const result = await listTenants({}, 1, 20);

      expect(result.tenants).toEqual([
        expect.objectContaining({
          id: 'tenant-1',
          name: 'Hospital A',
          primary_tenant_admin: {
            id: 'user-1',
            human_friendly_id: 'USR0000001',
            email: 'tenant.admin@hms-demo.test',
            phone: '+256700000001',
            status: 'ACTIVE',
            first_name: 'Taylor',
            middle_name: null,
            last_name: 'Demo',
            full_name: 'Taylor Demo',
            facility_id: 'facility-1',
            facility_name: 'DemoCare General Hospital',
            role_id: 'role-1',
            role_human_friendly_id: 'ROL0000001',
            role_name: 'TENANT_ADMIN',
            user_role_id: 'user-role-1',
            user_role_human_friendly_id: 'URO0000001',
          },
        }),
      ]);
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
      tenantRepository.findById.mockResolvedValue(mockTenant);

      const result = await getTenantById('tenant-123');

      expect(result).toEqual(mockTenant);
      expect(tenantRepository.findById).toHaveBeenCalledWith('tenant-123');
    });

    it('should throw HttpError if tenant not found', async () => {
      tenantRepository.findById.mockResolvedValue(null);

      await expect(getTenantById('tenant-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should expose the primary tenant admin on detail payloads when available', async () => {
      tenantRepository.findById.mockResolvedValue({
        id: 'tenant-123',
        name: 'Test Hospital',
        slug: 'test-hospital',
        is_active: true,
        user_roles: [
          {
            id: 'user-role-1',
            human_friendly_id: 'URO0000001',
            role_id: 'role-1',
            facility_id: 'facility-1',
            role: {
              id: 'role-1',
              human_friendly_id: 'ROL0000001',
              name: 'TENANT_ADMIN',
            },
            user: {
              id: 'user-1',
              human_friendly_id: 'USR0000001',
              email: 'tenant.admin@hms-demo.test',
              phone: '+256700000001',
              status: 'ACTIVE',
              facility_id: 'facility-1',
              profile: {
                first_name: 'Taylor',
                middle_name: null,
                last_name: 'Demo',
              },
              facility: {
                id: 'facility-1',
                human_friendly_id: 'FAC0000001',
                name: 'DemoCare General Hospital',
              },
            },
          },
        ],
      });

      const result = await getTenantById('tenant-123');

      expect(result).toEqual({
        id: 'tenant-123',
        name: 'Test Hospital',
        slug: 'test-hospital',
        is_active: true,
        primary_tenant_admin: {
          id: 'user-1',
          human_friendly_id: 'USR0000001',
          email: 'tenant.admin@hms-demo.test',
          phone: '+256700000001',
          status: 'ACTIVE',
          first_name: 'Taylor',
          middle_name: null,
          last_name: 'Demo',
          full_name: 'Taylor Demo',
          facility_id: 'facility-1',
          facility_name: 'DemoCare General Hospital',
          role_id: 'role-1',
          role_human_friendly_id: 'ROL0000001',
          role_name: 'TENANT_ADMIN',
          user_role_id: 'user-role-1',
          user_role_human_friendly_id: 'URO0000001',
        },
      });
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
      const context = {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        ip_address: '192.168.1.1'
      };

      tenantRepository.create.mockResolvedValue(mockCreatedTenant);
      createAuditLog.mockResolvedValue(undefined);

      const result = await createTenant(tenantData, context);

      expect(result).toEqual(mockCreatedTenant);
      expect(tenantRepository.create).toHaveBeenCalledWith(tenantData);
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'TENANT_CREATED',
        entity: 'tenant',
        entity_id: mockCreatedTenant.id,
        user_id: context.user_id,
        tenant_id: context.tenant_id,
        facility_id: undefined,
        ip_address: context.ip_address,
        user_agent: undefined,
        details: {
          name: mockCreatedTenant.name,
          slug: mockCreatedTenant.slug,
          is_active: mockCreatedTenant.is_active
        }
      });
    });

    it('should create tenant without context', async () => {
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

      tenantRepository.create.mockResolvedValue(mockCreatedTenant);
      createAuditLog.mockResolvedValue(undefined);

      const result = await createTenant(tenantData);

      expect(result).toEqual(mockCreatedTenant);
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should propagate repository errors', async () => {
      const error = new HttpError('errors.database.unique_field', 409);
      tenantRepository.create.mockRejectedValue(error);

      await expect(createTenant({ name: 'Test' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('updateTenant', () => {
    it('should update tenant successfully', async () => {
      const updateData = {
        name: 'Updated Hospital',
        is_active: false
      };
      const mockBeforeTenant = {
        id: 'tenant-123',
        name: 'Test Hospital',
        slug: 'test-hospital',
        is_active: true
      };
      const mockUpdatedTenant = {
        ...mockBeforeTenant,
        ...updateData,
        updated_at: new Date()
      };
      const context = {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        ip_address: '192.168.1.1'
      };

      tenantRepository.findById.mockResolvedValue(mockBeforeTenant);
      tenantRepository.update.mockResolvedValue(mockUpdatedTenant);
      createAuditLog.mockResolvedValue(undefined);

      const result = await updateTenant('tenant-123', updateData, context);

      expect(result).toEqual(mockUpdatedTenant);
      expect(tenantRepository.findById).toHaveBeenCalledWith('tenant-123');
      expect(tenantRepository.update).toHaveBeenCalledWith('tenant-123', updateData);
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'TENANT_UPDATED',
        entity: 'tenant',
        entity_id: 'tenant-123',
        user_id: context.user_id,
        tenant_id: context.tenant_id,
        facility_id: undefined,
        ip_address: context.ip_address,
        user_agent: undefined,
        details: {
          before: {
            name: mockBeforeTenant.name,
            slug: mockBeforeTenant.slug,
            is_active: mockBeforeTenant.is_active
          },
          after: {
            name: mockUpdatedTenant.name,
            slug: mockUpdatedTenant.slug,
            is_active: mockUpdatedTenant.is_active
          }
        }
      });
    });

    it('should throw HttpError if tenant not found before update', async () => {
      tenantRepository.findById.mockResolvedValue(null);

      await expect(updateTenant('tenant-123', { name: 'Updated' }))
        .rejects
        .toThrow(HttpError);
      
      expect(tenantRepository.update).not.toHaveBeenCalled();
    });

    it('should propagate repository errors', async () => {
      const mockTenant = { id: 'tenant-123', name: 'Test' };
      const error = new HttpError('errors.database.unique_field', 409);
      
      tenantRepository.findById.mockResolvedValue(mockTenant);
      tenantRepository.update.mockRejectedValue(error);

      await expect(updateTenant('tenant-123', { name: 'Updated' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('deleteTenant', () => {
    it('should delete tenant successfully', async () => {
      const mockTenant = {
        id: 'tenant-123',
        name: 'Test Hospital',
        slug: 'test-hospital',
        is_active: true
      };
      const context = {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        ip_address: '192.168.1.1'
      };

      tenantRepository.findById.mockResolvedValue(mockTenant);
      tenantRepository.softDelete.mockResolvedValue(mockTenant);
      createAuditLog.mockResolvedValue(undefined);

      await deleteTenant('tenant-123', context);

      expect(tenantRepository.findById).toHaveBeenCalledWith('tenant-123');
      expect(tenantRepository.softDelete).toHaveBeenCalledWith('tenant-123');
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'TENANT_DELETED',
        entity: 'tenant',
        entity_id: 'tenant-123',
        user_id: context.user_id,
        tenant_id: context.tenant_id,
        facility_id: undefined,
        ip_address: context.ip_address,
        user_agent: undefined,
        details: {
          name: mockTenant.name,
          slug: mockTenant.slug
        }
      });
    });

    it('should throw HttpError if tenant not found', async () => {
      tenantRepository.findById.mockResolvedValue(null);

      await expect(deleteTenant('tenant-123'))
        .rejects
        .toThrow(HttpError);
      
      expect(tenantRepository.softDelete).not.toHaveBeenCalled();
    });

    it('should propagate repository errors', async () => {
      const mockTenant = { id: 'tenant-123', name: 'Test' };
      const error = new HttpError('errors.database.unexpected', 500);
      
      tenantRepository.findById.mockResolvedValue(mockTenant);
      tenantRepository.softDelete.mockRejectedValue(error);

      await expect(deleteTenant('tenant-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
