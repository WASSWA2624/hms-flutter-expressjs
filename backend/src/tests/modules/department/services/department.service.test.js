/**
 * Department service tests
 *
 * @module tests/modules/department/services
 * Per testing.mdc: Mock all external dependencies
 */

const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/department/department.repository');
jest.mock('@lib/audit');
jest.mock('@services/unit/unit.service', () => ({
  listUnits: jest.fn()
}));

const departmentRepository = require('@repositories/department/department.repository');
const { createAuditLog } = require('@lib/audit');
const unitService = require('@services/unit/unit.service');
const {
  listDepartments,
  getDepartmentById,
  createDepartment,
  updateDepartment,
  deleteDepartment,
  getDepartmentUnits
} = require('@services/department/department.service');

describe('Department Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  describe('listDepartments', () => {
    it('should list departments with default pagination', async () => {
      const mockDepartments = [
        { id: 'dept-1', name: 'Emergency', tenant_id: 'tenant-123', department_type: 'CLINICAL' },
        { id: 'dept-2', name: 'Radiology', tenant_id: 'tenant-123', department_type: 'DIAGNOSTICS' }
      ];
      departmentRepository.findMany.mockResolvedValue(mockDepartments);
      departmentRepository.count.mockResolvedValue(10);

      const result = await listDepartments({}, 1, 20);

      expect(result.departments).toEqual(mockDepartments);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 10,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
      expect(departmentRepository.findMany).toHaveBeenCalledWith(
        {},
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by tenant_id', async () => {
      const mockDepartments = [{ id: 'dept-1', name: 'Emergency' }];
      departmentRepository.findMany.mockResolvedValue(mockDepartments);
      departmentRepository.count.mockResolvedValue(1);

      const result = await listDepartments({ tenant_id: 'tenant-123' }, 1, 20);

      expect(result.departments).toEqual(mockDepartments);
      expect(departmentRepository.findMany).toHaveBeenCalledWith(
        { tenant_id: 'tenant-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by facility_id', async () => {
      const mockDepartments = [{ id: 'dept-1', name: 'Emergency' }];
      departmentRepository.findMany.mockResolvedValue(mockDepartments);
      departmentRepository.count.mockResolvedValue(1);

      const result = await listDepartments({ facility_id: 'facility-123' }, 1, 20);

      expect(result.departments).toEqual(mockDepartments);
      expect(departmentRepository.findMany).toHaveBeenCalledWith(
        { facility_id: 'facility-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by branch_id', async () => {
      const mockDepartments = [{ id: 'dept-1', name: 'Emergency' }];
      departmentRepository.findMany.mockResolvedValue(mockDepartments);
      departmentRepository.count.mockResolvedValue(1);

      const result = await listDepartments({ branch_id: 'branch-123' }, 1, 20);

      expect(result.departments).toEqual(mockDepartments);
      expect(departmentRepository.findMany).toHaveBeenCalledWith(
        { branch_id: 'branch-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by department_type', async () => {
      const mockDepartments = [{ id: 'dept-1', name: 'Emergency', department_type: 'CLINICAL' }];
      departmentRepository.findMany.mockResolvedValue(mockDepartments);
      departmentRepository.count.mockResolvedValue(1);

      const result = await listDepartments({ department_type: 'CLINICAL' }, 1, 20);

      expect(result.departments).toEqual(mockDepartments);
      expect(departmentRepository.findMany).toHaveBeenCalledWith(
        { department_type: 'CLINICAL' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by is_active=true', async () => {
      const mockDepartments = [{ id: 'dept-1', name: 'Emergency' }];
      departmentRepository.findMany.mockResolvedValue(mockDepartments);
      departmentRepository.count.mockResolvedValue(1);

      const result = await listDepartments({ is_active: 'true' }, 1, 20);

      expect(result.departments).toEqual(mockDepartments);
      expect(departmentRepository.findMany).toHaveBeenCalledWith(
        { is_active: true },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by is_active=false', async () => {
      const mockDepartments = [{ id: 'dept-1', name: 'Emergency' }];
      departmentRepository.findMany.mockResolvedValue(mockDepartments);
      departmentRepository.count.mockResolvedValue(1);

      const result = await listDepartments({ is_active: 'false' }, 1, 20);

      expect(result.departments).toEqual(mockDepartments);
      expect(departmentRepository.findMany).toHaveBeenCalledWith(
        { is_active: false },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by search term', async () => {
      const mockDepartments = [{ id: 'dept-1', name: 'Emergency Department' }];
      departmentRepository.findMany.mockResolvedValue(mockDepartments);
      departmentRepository.count.mockResolvedValue(1);

      const result = await listDepartments({ search: 'emergency' }, 1, 20);

      expect(result.departments).toEqual(mockDepartments);
      expect(departmentRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          name: { contains: 'emergency', mode: 'insensitive' }
        }),
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should handle custom sorting', async () => {
      const mockDepartments = [];
      departmentRepository.findMany.mockResolvedValue(mockDepartments);
      departmentRepository.count.mockResolvedValue(0);

      await listDepartments({}, 1, 20, 'name', 'asc');

      expect(departmentRepository.findMany).toHaveBeenCalledWith(
        {},
        0,
        20,
        { name: 'asc' }
      );
    });

    it('should calculate pagination correctly for multiple pages', async () => {
      const mockDepartments = [];
      departmentRepository.findMany.mockResolvedValue(mockDepartments);
      departmentRepository.count.mockResolvedValue(50);

      const result = await listDepartments({}, 2, 20);

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

  describe('getDepartmentById', () => {
    it('should get department by ID', async () => {
      const mockDepartment = {
        id: 'dept-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        branch_id: 'branch-123',
        name: 'Emergency Department',
        department_type: 'CLINICAL',
        is_active: true
      };
      departmentRepository.findById.mockResolvedValue(mockDepartment);

      const result = await getDepartmentById('dept-123');

      expect(result).toEqual(mockDepartment);
      expect(departmentRepository.findById).toHaveBeenCalledWith('dept-123');
    });

    it('should throw HttpError if department not found', async () => {
      departmentRepository.findById.mockResolvedValue(null);

      await expect(getDepartmentById('dept-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('createDepartment', () => {
    it('should create department successfully', async () => {
      const departmentData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        branch_id: 'branch-123',
        name: 'New Department',
        department_type: 'CLINICAL',
        is_active: true
      };
      const mockCreatedDepartment = {
        id: 'dept-new',
        ...departmentData,
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

      departmentRepository.create.mockResolvedValue(mockCreatedDepartment);
      createAuditLog.mockResolvedValue(undefined);

      const result = await createDepartment(departmentData, context);

      expect(result).toEqual(mockCreatedDepartment);
      expect(departmentRepository.create).toHaveBeenCalledWith(departmentData);
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'DEPARTMENT_CREATED',
        entity: 'department',
        entity_id: mockCreatedDepartment.id,
        user_id: context.user_id,
        tenant_id: context.tenant_id,
        facility_id: context.facility_id,
        ip_address: context.ip_address,
        user_agent: undefined,
        details: {
          tenant_id: mockCreatedDepartment.tenant_id,
          facility_id: mockCreatedDepartment.facility_id,
          branch_id: mockCreatedDepartment.branch_id,
          name: mockCreatedDepartment.name,
          department_type: mockCreatedDepartment.department_type,
          is_active: mockCreatedDepartment.is_active
        }
      });
    });

    it('should create department without context', async () => {
      const departmentData = {
        tenant_id: 'tenant-123',
        name: 'New Department',
        department_type: 'CLINICAL'
      };
      const mockCreatedDepartment = {
        id: 'dept-new',
        ...departmentData,
        facility_id: null,
        branch_id: null,
        is_active: true,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };

      departmentRepository.create.mockResolvedValue(mockCreatedDepartment);
      createAuditLog.mockResolvedValue(undefined);

      const result = await createDepartment(departmentData);

      expect(result).toEqual(mockCreatedDepartment);
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should propagate repository errors', async () => {
      const error = new HttpError('errors.database.unique_field', 409);
      departmentRepository.create.mockRejectedValue(error);

      await expect(createDepartment({ 
        tenant_id: 'tenant-123', 
        name: 'Test',
        department_type: 'CLINICAL'
      }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('updateDepartment', () => {
    it('should update department successfully', async () => {
      const updateData = {
        name: 'Updated Department',
        department_type: 'ADMINISTRATIVE',
        is_active: false
      };
      const mockBeforeDepartment = {
        id: 'dept-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        branch_id: 'branch-123',
        name: 'Emergency Department',
        department_type: 'CLINICAL',
        is_active: true
      };
      const mockUpdatedDepartment = {
        ...mockBeforeDepartment,
        ...updateData,
        updated_at: new Date()
      };
      const context = {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '192.168.1.1'
      };

      departmentRepository.findById.mockResolvedValue(mockBeforeDepartment);
      departmentRepository.update.mockResolvedValue(mockUpdatedDepartment);
      createAuditLog.mockResolvedValue(undefined);

      const result = await updateDepartment('dept-123', updateData, context);

      expect(result).toEqual(mockUpdatedDepartment);
      expect(departmentRepository.findById).toHaveBeenCalledWith('dept-123');
      expect(departmentRepository.update).toHaveBeenCalledWith('dept-123', updateData);
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'DEPARTMENT_UPDATED',
        entity: 'department',
        entity_id: 'dept-123',
        user_id: context.user_id,
        tenant_id: context.tenant_id,
        facility_id: context.facility_id,
        ip_address: context.ip_address,
        user_agent: undefined,
        details: {
          before: {
            facility_id: mockBeforeDepartment.facility_id,
            branch_id: mockBeforeDepartment.branch_id,
            name: mockBeforeDepartment.name,
            department_type: mockBeforeDepartment.department_type,
            is_active: mockBeforeDepartment.is_active
          },
          after: {
            facility_id: mockUpdatedDepartment.facility_id,
            branch_id: mockUpdatedDepartment.branch_id,
            name: mockUpdatedDepartment.name,
            department_type: mockUpdatedDepartment.department_type,
            is_active: mockUpdatedDepartment.is_active
          }
        }
      });
    });

    it('should throw HttpError if department not found before update', async () => {
      departmentRepository.findById.mockResolvedValue(null);

      await expect(updateDepartment('dept-123', { name: 'Updated' }))
        .rejects
        .toThrow(HttpError);
      
      expect(departmentRepository.update).not.toHaveBeenCalled();
    });

    it('should propagate repository errors', async () => {
      const mockDepartment = { 
        id: 'dept-123', 
        name: 'Test', 
        tenant_id: 'tenant-123',
        department_type: 'CLINICAL'
      };
      const error = new HttpError('errors.database.unique_field', 409);
      
      departmentRepository.findById.mockResolvedValue(mockDepartment);
      departmentRepository.update.mockRejectedValue(error);

      await expect(updateDepartment('dept-123', { name: 'Updated' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('deleteDepartment', () => {
    it('should delete department successfully', async () => {
      const mockDepartment = {
        id: 'dept-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        branch_id: 'branch-123',
        name: 'Emergency Department',
        department_type: 'CLINICAL',
        is_active: true
      };
      const context = {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '192.168.1.1'
      };

      departmentRepository.findById.mockResolvedValue(mockDepartment);
      departmentRepository.softDelete.mockResolvedValue(mockDepartment);
      createAuditLog.mockResolvedValue(undefined);

      await deleteDepartment('dept-123', context);

      expect(departmentRepository.findById).toHaveBeenCalledWith('dept-123');
      expect(departmentRepository.softDelete).toHaveBeenCalledWith('dept-123');
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'DEPARTMENT_DELETED',
        entity: 'department',
        entity_id: 'dept-123',
        user_id: context.user_id,
        tenant_id: context.tenant_id,
        facility_id: context.facility_id,
        ip_address: context.ip_address,
        user_agent: undefined,
        details: {
          tenant_id: mockDepartment.tenant_id,
          facility_id: mockDepartment.facility_id,
          branch_id: mockDepartment.branch_id,
          name: mockDepartment.name,
          department_type: mockDepartment.department_type
        }
      });
    });

    it('should throw HttpError if department not found', async () => {
      departmentRepository.findById.mockResolvedValue(null);

      await expect(deleteDepartment('dept-123'))
        .rejects
        .toThrow(HttpError);
      
      expect(departmentRepository.softDelete).not.toHaveBeenCalled();
    });

    it('should propagate repository errors', async () => {
      const mockDepartment = { 
        id: 'dept-123', 
        name: 'Test', 
        tenant_id: 'tenant-123',
        department_type: 'CLINICAL'
      };
      const error = new HttpError('errors.database.unexpected', 500);
      
      departmentRepository.findById.mockResolvedValue(mockDepartment);
      departmentRepository.softDelete.mockRejectedValue(error);

      await expect(deleteDepartment('dept-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('getDepartmentUnits', () => {
    it('should throw HttpError if department not found', async () => {
      departmentRepository.findById.mockResolvedValue(null);

      await expect(getDepartmentUnits('dept-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should return empty units list when department exists', async () => {
      const mockDepartment = {
        id: 'dept-123',
        tenant_id: 'tenant-123',
        name: 'Emergency Department',
        department_type: 'CLINICAL'
      };
      departmentRepository.findById.mockResolvedValue(mockDepartment);
      unitService.listUnits.mockResolvedValue({
        units: [],
        pagination: {
          page: 1,
          limit: 20,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: false
        }
      });

      const result = await getDepartmentUnits('dept-123', 1, 20);

      expect(result.units).toEqual([]);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 0,
        totalPages: 0,
        hasNextPage: false,
        hasPreviousPage: false
      });
    });
  });
});
