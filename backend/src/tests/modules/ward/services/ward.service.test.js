/**
 * Ward service tests
 *
 * @module tests/modules/ward/services
 * Per testing.mdc: Mock all external dependencies
 */

const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/ward/ward.repository');
jest.mock('@lib/audit');

const wardRepository = require('@repositories/ward/ward.repository');
const { createAuditLog } = require('@lib/audit');
const {
  listWards,
  getWardById,
  getWardBeds,
  createWard,
  updateWard,
  deleteWard
} = require('@services/ward/ward.service');

describe('Ward Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('listWards', () => {
    it('should list wards with default pagination', async () => {
      const mockWards = [
        { id: 'ward-1', name: 'ICU Ward', tenant_id: 'tenant-123', ward_type: 'ICU' },
        { id: 'ward-2', name: 'General Ward', tenant_id: 'tenant-123', ward_type: 'GENERAL' }
      ];
      wardRepository.findMany.mockResolvedValue(mockWards);
      wardRepository.count.mockResolvedValue(10);

      const result = await listWards({}, 1, 20);

      expect(result.wards).toEqual(mockWards);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 10,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
      expect(wardRepository.findMany).toHaveBeenCalledWith(
        {},
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by tenant_id', async () => {
      const mockWards = [{ id: 'ward-1', name: 'ICU Ward', ward_type: 'ICU' }];
      wardRepository.findMany.mockResolvedValue(mockWards);
      wardRepository.count.mockResolvedValue(1);

      const result = await listWards({ tenant_id: 'tenant-123' }, 1, 20);

      expect(result.wards).toEqual(mockWards);
      expect(wardRepository.findMany).toHaveBeenCalledWith(
        { tenant_id: 'tenant-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by facility_id', async () => {
      const mockWards = [{ id: 'ward-1', name: 'ICU Ward', ward_type: 'ICU' }];
      wardRepository.findMany.mockResolvedValue(mockWards);
      wardRepository.count.mockResolvedValue(1);

      const result = await listWards({ facility_id: 'facility-123' }, 1, 20);

      expect(result.wards).toEqual(mockWards);
      expect(wardRepository.findMany).toHaveBeenCalledWith(
        { facility_id: 'facility-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by department_id', async () => {
      const mockWards = [{ id: 'ward-1', name: 'ICU Ward', ward_type: 'ICU' }];
      wardRepository.findMany.mockResolvedValue(mockWards);
      wardRepository.count.mockResolvedValue(1);

      const result = await listWards({ department_id: 'department-123' }, 1, 20);

      expect(result.wards).toEqual(mockWards);
      expect(wardRepository.findMany).toHaveBeenCalledWith(
        { department_id: 'department-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by ward_type', async () => {
      const mockWards = [{ id: 'ward-1', name: 'ICU Ward', ward_type: 'ICU' }];
      wardRepository.findMany.mockResolvedValue(mockWards);
      wardRepository.count.mockResolvedValue(1);

      const result = await listWards({ ward_type: 'ICU' }, 1, 20);

      expect(result.wards).toEqual(mockWards);
      expect(wardRepository.findMany).toHaveBeenCalledWith(
        { ward_type: 'ICU' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by is_active=true', async () => {
      const mockWards = [{ id: 'ward-1', name: 'ICU Ward', ward_type: 'ICU' }];
      wardRepository.findMany.mockResolvedValue(mockWards);
      wardRepository.count.mockResolvedValue(1);

      const result = await listWards({ is_active: 'true' }, 1, 20);

      expect(result.wards).toEqual(mockWards);
      expect(wardRepository.findMany).toHaveBeenCalledWith(
        { is_active: true },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by is_active=false', async () => {
      const mockWards = [{ id: 'ward-1', name: 'ICU Ward', ward_type: 'ICU' }];
      wardRepository.findMany.mockResolvedValue(mockWards);
      wardRepository.count.mockResolvedValue(1);

      const result = await listWards({ is_active: 'false' }, 1, 20);

      expect(result.wards).toEqual(mockWards);
      expect(wardRepository.findMany).toHaveBeenCalledWith(
        { is_active: false },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by search term', async () => {
      const mockWards = [{ id: 'ward-1', name: 'ICU Ward', ward_type: 'ICU' }];
      wardRepository.findMany.mockResolvedValue(mockWards);
      wardRepository.count.mockResolvedValue(1);

      const result = await listWards({ search: 'icu' }, 1, 20);

      expect(result.wards).toEqual(mockWards);
      expect(wardRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          name: { contains: 'icu', mode: 'insensitive' }
        }),
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should handle custom sorting', async () => {
      const mockWards = [];
      wardRepository.findMany.mockResolvedValue(mockWards);
      wardRepository.count.mockResolvedValue(0);

      await listWards({}, 1, 20, 'name', 'asc');

      expect(wardRepository.findMany).toHaveBeenCalledWith(
        {},
        0,
        20,
        { name: 'asc' }
      );
    });

    it('should calculate pagination correctly for multiple pages', async () => {
      const mockWards = [];
      wardRepository.findMany.mockResolvedValue(mockWards);
      wardRepository.count.mockResolvedValue(50);

      const result = await listWards({}, 2, 20);

      expect(result.pagination).toEqual({
        page: 2,
        limit: 20,
        total: 50,
        totalPages: 3,
        hasNextPage: true,
        hasPreviousPage: true
      });
    });
  });

  describe('getWardById', () => {
    it('should get ward by ID', async () => {
      const mockWard = {
        id: 'ward-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        department_id: 'department-123',
        name: 'ICU Ward',
        ward_type: 'ICU',
        is_active: true
      };
      wardRepository.findById.mockResolvedValue(mockWard);

      const result = await getWardById('ward-123');

      expect(result).toEqual(mockWard);
      expect(wardRepository.findById).toHaveBeenCalledWith('ward-123');
    });

    it('should throw HttpError if ward not found', async () => {
      wardRepository.findById.mockResolvedValue(null);

      await expect(getWardById('ward-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('getWardBeds', () => {
    it('should get ward beds', async () => {
      const mockWard = {
        id: 'ward-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        name: 'ICU Ward',
        ward_type: 'ICU',
        is_active: true
      };
      wardRepository.findById.mockResolvedValue(mockWard);

      const result = await getWardBeds('ward-123');

      expect(result).toEqual(mockWard);
      expect(wardRepository.findById).toHaveBeenCalledWith('ward-123');
    });

    it('should throw HttpError if ward not found', async () => {
      wardRepository.findById.mockResolvedValue(null);

      await expect(getWardBeds('ward-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('createWard', () => {
    it('should create ward successfully', async () => {
      const wardData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        department_id: 'department-123',
        name: 'New Ward',
        ward_type: 'GENERAL',
        is_active: true
      };
      const mockCreatedWard = {
        id: 'ward-new',
        ...wardData,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };
      const context = {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '192.168.1.1'
      };

      wardRepository.create.mockResolvedValue(mockCreatedWard);
      createAuditLog.mockResolvedValue(undefined);

      const result = await createWard(wardData, context);

      expect(result).toEqual(mockCreatedWard);
      expect(wardRepository.create).toHaveBeenCalledWith(wardData);
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'WARD_CREATED',
        entity: 'ward',
        entity_id: mockCreatedWard.id,
        user_id: context.user_id,
        tenant_id: context.tenant_id,
        facility_id: context.facility_id,
        ip_address: context.ip_address,
        user_agent: undefined,
        details: {
          tenant_id: mockCreatedWard.tenant_id,
          facility_id: mockCreatedWard.facility_id,
          department_id: mockCreatedWard.department_id,
          name: mockCreatedWard.name,
          ward_type: mockCreatedWard.ward_type,
          is_active: mockCreatedWard.is_active
        }
      });
    });

    it('should create ward without context', async () => {
      const wardData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        name: 'New Ward',
        ward_type: 'GENERAL'
      };
      const mockCreatedWard = {
        id: 'ward-new',
        ...wardData,
        department_id: null,
        is_active: true,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };

      wardRepository.create.mockResolvedValue(mockCreatedWard);
      createAuditLog.mockResolvedValue(undefined);

      const result = await createWard(wardData);

      expect(result).toEqual(mockCreatedWard);
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should propagate repository errors', async () => {
      const error = new HttpError('errors.database.unique_field', 409);
      wardRepository.create.mockRejectedValue(error);

      await expect(createWard({ 
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        name: 'Test',
        ward_type: 'GENERAL'
      }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('updateWard', () => {
    it('should update ward successfully', async () => {
      const updateData = {
        name: 'Updated Ward',
        ward_type: 'SURGICAL',
        is_active: false
      };
      const mockBeforeWard = {
        id: 'ward-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        department_id: 'department-123',
        name: 'ICU Ward',
        ward_type: 'ICU',
        is_active: true
      };
      const mockUpdatedWard = {
        ...mockBeforeWard,
        ...updateData,
        updated_at: new Date()
      };
      const context = {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '192.168.1.1'
      };

      wardRepository.findById.mockResolvedValue(mockBeforeWard);
      wardRepository.update.mockResolvedValue(mockUpdatedWard);
      createAuditLog.mockResolvedValue(undefined);

      const result = await updateWard('ward-123', updateData, context);

      expect(result).toEqual(mockUpdatedWard);
      expect(wardRepository.findById).toHaveBeenCalledWith('ward-123');
      expect(wardRepository.update).toHaveBeenCalledWith('ward-123', updateData);
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'WARD_UPDATED',
        entity: 'ward',
        entity_id: 'ward-123',
        user_id: context.user_id,
        tenant_id: context.tenant_id,
        facility_id: context.facility_id,
        ip_address: context.ip_address,
        user_agent: undefined,
        details: {
          before: {
            facility_id: mockBeforeWard.facility_id,
            department_id: mockBeforeWard.department_id,
            name: mockBeforeWard.name,
            ward_type: mockBeforeWard.ward_type,
            is_active: mockBeforeWard.is_active
          },
          after: {
            facility_id: mockUpdatedWard.facility_id,
            department_id: mockUpdatedWard.department_id,
            name: mockUpdatedWard.name,
            ward_type: mockUpdatedWard.ward_type,
            is_active: mockUpdatedWard.is_active
          }
        }
      });
    });

    it('should throw HttpError if ward not found before update', async () => {
      wardRepository.findById.mockResolvedValue(null);

      await expect(updateWard('ward-123', { name: 'Updated' }))
        .rejects
        .toThrow(HttpError);
      
      expect(wardRepository.update).not.toHaveBeenCalled();
    });

    it('should propagate repository errors', async () => {
      const mockWard = { 
        id: 'ward-123', 
        name: 'Test', 
        tenant_id: 'tenant-123',
        ward_type: 'GENERAL'
      };
      const error = new HttpError('errors.database.unique_field', 409);
      
      wardRepository.findById.mockResolvedValue(mockWard);
      wardRepository.update.mockRejectedValue(error);

      await expect(updateWard('ward-123', { name: 'Updated' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('deleteWard', () => {
    it('should delete ward successfully', async () => {
      const mockWard = {
        id: 'ward-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        department_id: 'department-123',
        name: 'ICU Ward',
        ward_type: 'ICU',
        is_active: true
      };
      const context = {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '192.168.1.1'
      };

      wardRepository.findById.mockResolvedValue(mockWard);
      wardRepository.softDelete.mockResolvedValue(mockWard);
      createAuditLog.mockResolvedValue(undefined);

      await deleteWard('ward-123', context);

      expect(wardRepository.findById).toHaveBeenCalledWith('ward-123');
      expect(wardRepository.softDelete).toHaveBeenCalledWith('ward-123');
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'WARD_DELETED',
        entity: 'ward',
        entity_id: 'ward-123',
        user_id: context.user_id,
        tenant_id: context.tenant_id,
        facility_id: context.facility_id,
        ip_address: context.ip_address,
        user_agent: undefined,
        details: {
          tenant_id: mockWard.tenant_id,
          facility_id: mockWard.facility_id,
          department_id: mockWard.department_id,
          name: mockWard.name,
          ward_type: mockWard.ward_type
        }
      });
    });

    it('should throw HttpError if ward not found before delete', async () => {
      wardRepository.findById.mockResolvedValue(null);

      await expect(deleteWard('ward-123'))
        .rejects
        .toThrow(HttpError);
      
      expect(wardRepository.softDelete).not.toHaveBeenCalled();
    });

    it('should propagate repository errors', async () => {
      const mockWard = { 
        id: 'ward-123', 
        name: 'Test', 
        tenant_id: 'tenant-123',
        ward_type: 'GENERAL'
      };
      const error = new HttpError('errors.database.unexpected', 500);
      
      wardRepository.findById.mockResolvedValue(mockWard);
      wardRepository.softDelete.mockRejectedValue(error);

      await expect(deleteWard('ward-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
