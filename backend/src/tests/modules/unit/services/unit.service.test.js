/**
 * Unit service tests
 *
 * @module tests/modules/unit/services
 * Per testing.mdc: Mock all external dependencies
 */

const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/unit/unit.repository');
jest.mock('@lib/audit');

const unitRepository = require('@repositories/unit/unit.repository');
const { createAuditLog } = require('@lib/audit');
const {
  listUnits,
  getUnitById,
  createUnit,
  updateUnit,
  deleteUnit
} = require('@services/unit/unit.service');

describe('Unit Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('listUnits', () => {
    it('should list units with default pagination', async () => {
      const mockUnits = [
        { id: 'unit-1', name: 'ICU Unit', tenant_id: 'tenant-123' },
        { id: 'unit-2', name: 'Surgery Unit', tenant_id: 'tenant-123' }
      ];
      unitRepository.findMany.mockResolvedValue(mockUnits);
      unitRepository.count.mockResolvedValue(10);

      const result = await listUnits({}, 1, 20);

      expect(result.units).toEqual(mockUnits);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 10,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
      expect(unitRepository.findMany).toHaveBeenCalledWith(
        {},
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by tenant_id', async () => {
      const mockUnits = [{ id: 'unit-1', name: 'ICU Unit' }];
      unitRepository.findMany.mockResolvedValue(mockUnits);
      unitRepository.count.mockResolvedValue(1);

      const result = await listUnits({ tenant_id: 'tenant-123' }, 1, 20);

      expect(result.units).toEqual(mockUnits);
      expect(unitRepository.findMany).toHaveBeenCalledWith(
        { tenant_id: 'tenant-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by facility_id', async () => {
      const mockUnits = [{ id: 'unit-1', name: 'ICU Unit' }];
      unitRepository.findMany.mockResolvedValue(mockUnits);
      unitRepository.count.mockResolvedValue(1);

      const result = await listUnits({ facility_id: 'facility-123' }, 1, 20);

      expect(result.units).toEqual(mockUnits);
      expect(unitRepository.findMany).toHaveBeenCalledWith(
        { facility_id: 'facility-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by department_id', async () => {
      const mockUnits = [{ id: 'unit-1', name: 'ICU Unit' }];
      unitRepository.findMany.mockResolvedValue(mockUnits);
      unitRepository.count.mockResolvedValue(1);

      const result = await listUnits({ department_id: 'department-123' }, 1, 20);

      expect(result.units).toEqual(mockUnits);
      expect(unitRepository.findMany).toHaveBeenCalledWith(
        { department_id: 'department-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by is_active=true', async () => {
      const mockUnits = [{ id: 'unit-1', name: 'ICU Unit' }];
      unitRepository.findMany.mockResolvedValue(mockUnits);
      unitRepository.count.mockResolvedValue(1);

      const result = await listUnits({ is_active: 'true' }, 1, 20);

      expect(result.units).toEqual(mockUnits);
      expect(unitRepository.findMany).toHaveBeenCalledWith(
        { is_active: true },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by is_active=false', async () => {
      const mockUnits = [{ id: 'unit-1', name: 'ICU Unit' }];
      unitRepository.findMany.mockResolvedValue(mockUnits);
      unitRepository.count.mockResolvedValue(1);

      const result = await listUnits({ is_active: 'false' }, 1, 20);

      expect(result.units).toEqual(mockUnits);
      expect(unitRepository.findMany).toHaveBeenCalledWith(
        { is_active: false },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by search term', async () => {
      const mockUnits = [{ id: 'unit-1', name: 'ICU Unit' }];
      unitRepository.findMany.mockResolvedValue(mockUnits);
      unitRepository.count.mockResolvedValue(1);

      const result = await listUnits({ search: 'icu' }, 1, 20);

      expect(result.units).toEqual(mockUnits);
      expect(unitRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          name: { contains: 'icu', mode: 'insensitive' }
        }),
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should handle custom sorting', async () => {
      const mockUnits = [];
      unitRepository.findMany.mockResolvedValue(mockUnits);
      unitRepository.count.mockResolvedValue(0);

      await listUnits({}, 1, 20, 'name', 'asc');

      expect(unitRepository.findMany).toHaveBeenCalledWith(
        {},
        0,
        20,
        { name: 'asc' }
      );
    });

    it('should calculate pagination correctly for multiple pages', async () => {
      const mockUnits = [];
      unitRepository.findMany.mockResolvedValue(mockUnits);
      unitRepository.count.mockResolvedValue(50);

      const result = await listUnits({}, 2, 20);

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

  describe('getUnitById', () => {
    it('should get unit by ID', async () => {
      const mockUnit = {
        id: 'unit-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        department_id: 'department-123',
        name: 'ICU Unit',
        is_active: true
      };
      unitRepository.findById.mockResolvedValue(mockUnit);

      const result = await getUnitById('unit-123');

      expect(result).toEqual(mockUnit);
      expect(unitRepository.findById).toHaveBeenCalledWith('unit-123');
    });

    it('should throw HttpError if unit not found', async () => {
      unitRepository.findById.mockResolvedValue(null);

      await expect(getUnitById('unit-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('createUnit', () => {
    it('should create unit successfully', async () => {
      const unitData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        department_id: 'department-123',
        name: 'New Unit',
        is_active: true
      };
      const mockCreatedUnit = {
        id: 'unit-new',
        ...unitData,
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

      unitRepository.create.mockResolvedValue(mockCreatedUnit);
      createAuditLog.mockResolvedValue(undefined);

      const result = await createUnit(unitData, context);

      expect(result).toEqual(mockCreatedUnit);
      expect(unitRepository.create).toHaveBeenCalledWith(unitData);
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'UNIT_CREATED',
        entity: 'unit',
        entity_id: mockCreatedUnit.id,
        user_id: context.user_id,
        tenant_id: context.tenant_id,
        facility_id: context.facility_id,
        ip_address: context.ip_address,
        user_agent: undefined,
        details: {
          tenant_id: mockCreatedUnit.tenant_id,
          facility_id: mockCreatedUnit.facility_id,
          department_id: mockCreatedUnit.department_id,
          name: mockCreatedUnit.name,
          is_active: mockCreatedUnit.is_active
        }
      });
    });

    it('should create unit without context', async () => {
      const unitData = {
        tenant_id: 'tenant-123',
        name: 'New Unit'
      };
      const mockCreatedUnit = {
        id: 'unit-new',
        ...unitData,
        facility_id: null,
        department_id: null,
        is_active: true,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };

      unitRepository.create.mockResolvedValue(mockCreatedUnit);
      createAuditLog.mockResolvedValue(undefined);

      const result = await createUnit(unitData);

      expect(result).toEqual(mockCreatedUnit);
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should propagate repository errors', async () => {
      const error = new HttpError('errors.database.unique_field', 409);
      unitRepository.create.mockRejectedValue(error);

      await expect(createUnit({ 
        tenant_id: 'tenant-123', 
        name: 'Test'
      }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('updateUnit', () => {
    it('should update unit successfully', async () => {
      const updateData = {
        name: 'Updated Unit',
        is_active: false
      };
      const mockBeforeUnit = {
        id: 'unit-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        department_id: 'department-123',
        name: 'ICU Unit',
        is_active: true
      };
      const mockUpdatedUnit = {
        ...mockBeforeUnit,
        ...updateData,
        updated_at: new Date()
      };
      const context = {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '192.168.1.1'
      };

      unitRepository.findById.mockResolvedValue(mockBeforeUnit);
      unitRepository.update.mockResolvedValue(mockUpdatedUnit);
      createAuditLog.mockResolvedValue(undefined);

      const result = await updateUnit('unit-123', updateData, context);

      expect(result).toEqual(mockUpdatedUnit);
      expect(unitRepository.findById).toHaveBeenCalledWith('unit-123');
      expect(unitRepository.update).toHaveBeenCalledWith('unit-123', updateData);
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'UNIT_UPDATED',
        entity: 'unit',
        entity_id: 'unit-123',
        user_id: context.user_id,
        tenant_id: context.tenant_id,
        facility_id: context.facility_id,
        ip_address: context.ip_address,
        user_agent: undefined,
        details: {
          before: {
            facility_id: mockBeforeUnit.facility_id,
            department_id: mockBeforeUnit.department_id,
            name: mockBeforeUnit.name,
            is_active: mockBeforeUnit.is_active
          },
          after: {
            facility_id: mockUpdatedUnit.facility_id,
            department_id: mockUpdatedUnit.department_id,
            name: mockUpdatedUnit.name,
            is_active: mockUpdatedUnit.is_active
          }
        }
      });
    });

    it('should throw HttpError if unit not found before update', async () => {
      unitRepository.findById.mockResolvedValue(null);

      await expect(updateUnit('unit-123', { name: 'Updated' }))
        .rejects
        .toThrow(HttpError);
      
      expect(unitRepository.update).not.toHaveBeenCalled();
    });

    it('should propagate repository errors', async () => {
      const mockUnit = { 
        id: 'unit-123', 
        name: 'Test', 
        tenant_id: 'tenant-123'
      };
      const error = new HttpError('errors.database.unique_field', 409);
      
      unitRepository.findById.mockResolvedValue(mockUnit);
      unitRepository.update.mockRejectedValue(error);

      await expect(updateUnit('unit-123', { name: 'Updated' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('deleteUnit', () => {
    it('should delete unit successfully', async () => {
      const mockUnit = {
        id: 'unit-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        department_id: 'department-123',
        name: 'ICU Unit',
        is_active: true
      };
      const context = {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '192.168.1.1'
      };

      unitRepository.findById.mockResolvedValue(mockUnit);
      unitRepository.softDelete.mockResolvedValue(mockUnit);
      createAuditLog.mockResolvedValue(undefined);

      await deleteUnit('unit-123', context);

      expect(unitRepository.findById).toHaveBeenCalledWith('unit-123');
      expect(unitRepository.softDelete).toHaveBeenCalledWith('unit-123');
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'UNIT_DELETED',
        entity: 'unit',
        entity_id: 'unit-123',
        user_id: context.user_id,
        tenant_id: context.tenant_id,
        facility_id: context.facility_id,
        ip_address: context.ip_address,
        user_agent: undefined,
        details: {
          tenant_id: mockUnit.tenant_id,
          facility_id: mockUnit.facility_id,
          department_id: mockUnit.department_id,
          name: mockUnit.name
        }
      });
    });

    it('should throw HttpError if unit not found before delete', async () => {
      unitRepository.findById.mockResolvedValue(null);

      await expect(deleteUnit('unit-123'))
        .rejects
        .toThrow(HttpError);
      
      expect(unitRepository.softDelete).not.toHaveBeenCalled();
    });

    it('should propagate repository errors', async () => {
      const mockUnit = { id: 'unit-123', name: 'Test', tenant_id: 'tenant-123' };
      const error = new HttpError('errors.database.unexpected', 500);
      
      unitRepository.findById.mockResolvedValue(mockUnit);
      unitRepository.softDelete.mockRejectedValue(error);

      await expect(deleteUnit('unit-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
