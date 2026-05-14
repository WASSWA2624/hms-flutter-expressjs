/**
 * Branch service tests
 *
 * @module tests/modules/branch/services
 * Per testing.mdc: Mock all external dependencies
 */

const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/branch/branch.repository');
jest.mock('@lib/audit');

const branchRepository = require('@repositories/branch/branch.repository');
const { createAuditLog } = require('@lib/audit');
const {
  listBranches,
  getBranchById,
  createBranch,
  updateBranch,
  deleteBranch
} = require('@services/branch/branch.service');

describe('Branch Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('listBranches', () => {
    it('should list branches with default pagination', async () => {
      const mockBranches = [
        { id: 'branch-1', name: 'Branch A', tenant_id: 'tenant-123' },
        { id: 'branch-2', name: 'Branch B', tenant_id: 'tenant-123' }
      ];
      branchRepository.findMany.mockResolvedValue(mockBranches);
      branchRepository.count.mockResolvedValue(10);

      const result = await listBranches({}, 1, 20);

      expect(result.branches).toEqual(mockBranches);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 10,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
      expect(branchRepository.findMany).toHaveBeenCalledWith(
        {},
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by tenant_id', async () => {
      const mockBranches = [{ id: 'branch-1', name: 'Branch A' }];
      branchRepository.findMany.mockResolvedValue(mockBranches);
      branchRepository.count.mockResolvedValue(1);

      const result = await listBranches({ tenant_id: 'tenant-123' }, 1, 20);

      expect(result.branches).toEqual(mockBranches);
      expect(branchRepository.findMany).toHaveBeenCalledWith(
        { tenant_id: 'tenant-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by facility_id', async () => {
      const mockBranches = [{ id: 'branch-1', name: 'Branch A' }];
      branchRepository.findMany.mockResolvedValue(mockBranches);
      branchRepository.count.mockResolvedValue(1);

      const result = await listBranches({ facility_id: 'facility-123' }, 1, 20);

      expect(result.branches).toEqual(mockBranches);
      expect(branchRepository.findMany).toHaveBeenCalledWith(
        { facility_id: 'facility-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by is_active=true', async () => {
      const mockBranches = [{ id: 'branch-1', name: 'Branch A' }];
      branchRepository.findMany.mockResolvedValue(mockBranches);
      branchRepository.count.mockResolvedValue(1);

      const result = await listBranches({ is_active: 'true' }, 1, 20);

      expect(result.branches).toEqual(mockBranches);
      expect(branchRepository.findMany).toHaveBeenCalledWith(
        { is_active: true },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by is_active=false', async () => {
      const mockBranches = [{ id: 'branch-1', name: 'Branch A' }];
      branchRepository.findMany.mockResolvedValue(mockBranches);
      branchRepository.count.mockResolvedValue(1);

      const result = await listBranches({ is_active: 'false' }, 1, 20);

      expect(result.branches).toEqual(mockBranches);
      expect(branchRepository.findMany).toHaveBeenCalledWith(
        { is_active: false },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by search term', async () => {
      const mockBranches = [{ id: 'branch-1', name: 'Main Branch' }];
      branchRepository.findMany.mockResolvedValue(mockBranches);
      branchRepository.count.mockResolvedValue(1);

      const result = await listBranches({ search: 'main' }, 1, 20);

      expect(result.branches).toEqual(mockBranches);
      expect(branchRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          name: { contains: 'main', mode: 'insensitive' }
        }),
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should handle custom sorting', async () => {
      const mockBranches = [];
      branchRepository.findMany.mockResolvedValue(mockBranches);
      branchRepository.count.mockResolvedValue(0);

      await listBranches({}, 1, 20, 'name', 'asc');

      expect(branchRepository.findMany).toHaveBeenCalledWith(
        {},
        0,
        20,
        { name: 'asc' }
      );
    });

    it('should calculate pagination correctly for multiple pages', async () => {
      const mockBranches = [];
      branchRepository.findMany.mockResolvedValue(mockBranches);
      branchRepository.count.mockResolvedValue(50);

      const result = await listBranches({}, 2, 20);

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

  describe('getBranchById', () => {
    it('should get branch by ID', async () => {
      const mockBranch = {
        id: 'branch-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        name: 'Main Branch',
        is_active: true
      };
      branchRepository.findById.mockResolvedValue(mockBranch);

      const result = await getBranchById('branch-123');

      expect(result).toEqual(mockBranch);
      expect(branchRepository.findById).toHaveBeenCalledWith('branch-123');
    });

    it('should throw HttpError if branch not found', async () => {
      branchRepository.findById.mockResolvedValue(null);

      await expect(getBranchById('branch-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('createBranch', () => {
    it('should create branch successfully', async () => {
      const branchData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        name: 'New Branch',
        is_active: true
      };
      const mockCreatedBranch = {
        id: 'branch-new',
        ...branchData,
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

      branchRepository.create.mockResolvedValue(mockCreatedBranch);
      createAuditLog.mockResolvedValue(undefined);

      const result = await createBranch(branchData, context);

      expect(result).toEqual(mockCreatedBranch);
      expect(branchRepository.create).toHaveBeenCalledWith(branchData);
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'BRANCH_CREATED',
        entity: 'branch',
        entity_id: mockCreatedBranch.id,
        user_id: context.user_id,
        tenant_id: context.tenant_id,
        facility_id: context.facility_id,
        ip_address: context.ip_address,
        user_agent: undefined,
        details: {
          tenant_id: mockCreatedBranch.tenant_id,
          facility_id: mockCreatedBranch.facility_id,
          name: mockCreatedBranch.name,
          is_active: mockCreatedBranch.is_active
        }
      });
    });

    it('should create branch without context', async () => {
      const branchData = {
        tenant_id: 'tenant-123',
        name: 'New Branch'
      };
      const mockCreatedBranch = {
        id: 'branch-new',
        ...branchData,
        facility_id: null,
        is_active: true,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };

      branchRepository.create.mockResolvedValue(mockCreatedBranch);
      createAuditLog.mockResolvedValue(undefined);

      const result = await createBranch(branchData);

      expect(result).toEqual(mockCreatedBranch);
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should propagate repository errors', async () => {
      const error = new HttpError('errors.database.unique_field', 409);
      branchRepository.create.mockRejectedValue(error);

      await expect(createBranch({ tenant_id: 'tenant-123', name: 'Test' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('updateBranch', () => {
    it('should update branch successfully', async () => {
      const updateData = {
        name: 'Updated Branch',
        is_active: false
      };
      const mockBeforeBranch = {
        id: 'branch-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        name: 'Main Branch',
        is_active: true
      };
      const mockUpdatedBranch = {
        ...mockBeforeBranch,
        ...updateData,
        updated_at: new Date()
      };
      const context = {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '192.168.1.1'
      };

      branchRepository.findById.mockResolvedValue(mockBeforeBranch);
      branchRepository.update.mockResolvedValue(mockUpdatedBranch);
      createAuditLog.mockResolvedValue(undefined);

      const result = await updateBranch('branch-123', updateData, context);

      expect(result).toEqual(mockUpdatedBranch);
      expect(branchRepository.findById).toHaveBeenCalledWith('branch-123');
      expect(branchRepository.update).toHaveBeenCalledWith('branch-123', updateData);
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'BRANCH_UPDATED',
        entity: 'branch',
        entity_id: 'branch-123',
        user_id: context.user_id,
        tenant_id: context.tenant_id,
        facility_id: context.facility_id,
        ip_address: context.ip_address,
        user_agent: undefined,
        details: {
          before: {
            facility_id: mockBeforeBranch.facility_id,
            name: mockBeforeBranch.name,
            is_active: mockBeforeBranch.is_active
          },
          after: {
            facility_id: mockUpdatedBranch.facility_id,
            name: mockUpdatedBranch.name,
            is_active: mockUpdatedBranch.is_active
          }
        }
      });
    });

    it('should throw HttpError if branch not found before update', async () => {
      branchRepository.findById.mockResolvedValue(null);

      await expect(updateBranch('branch-123', { name: 'Updated' }))
        .rejects
        .toThrow(HttpError);
      
      expect(branchRepository.update).not.toHaveBeenCalled();
    });

    it('should propagate repository errors', async () => {
      const mockBranch = { id: 'branch-123', name: 'Test', tenant_id: 'tenant-123' };
      const error = new HttpError('errors.database.unique_field', 409);
      
      branchRepository.findById.mockResolvedValue(mockBranch);
      branchRepository.update.mockRejectedValue(error);

      await expect(updateBranch('branch-123', { name: 'Updated' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('deleteBranch', () => {
    it('should delete branch successfully', async () => {
      const mockBranch = {
        id: 'branch-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        name: 'Main Branch',
        is_active: true
      };
      const context = {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '192.168.1.1'
      };

      branchRepository.findById.mockResolvedValue(mockBranch);
      branchRepository.softDelete.mockResolvedValue(mockBranch);
      createAuditLog.mockResolvedValue(undefined);

      await deleteBranch('branch-123', context);

      expect(branchRepository.findById).toHaveBeenCalledWith('branch-123');
      expect(branchRepository.softDelete).toHaveBeenCalledWith('branch-123');
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'BRANCH_DELETED',
        entity: 'branch',
        entity_id: 'branch-123',
        user_id: context.user_id,
        tenant_id: context.tenant_id,
        facility_id: context.facility_id,
        ip_address: context.ip_address,
        user_agent: undefined,
        details: {
          tenant_id: mockBranch.tenant_id,
          facility_id: mockBranch.facility_id,
          name: mockBranch.name
        }
      });
    });

    it('should throw HttpError if branch not found', async () => {
      branchRepository.findById.mockResolvedValue(null);

      await expect(deleteBranch('branch-123'))
        .rejects
        .toThrow(HttpError);
      
      expect(branchRepository.softDelete).not.toHaveBeenCalled();
    });

    it('should propagate repository errors', async () => {
      const mockBranch = { id: 'branch-123', name: 'Test', tenant_id: 'tenant-123' };
      const error = new HttpError('errors.database.unexpected', 500);
      
      branchRepository.findById.mockResolvedValue(mockBranch);
      branchRepository.softDelete.mockRejectedValue(error);

      await expect(deleteBranch('branch-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
