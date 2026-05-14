/**
 * Supplier service tests
 *
 * @module tests/modules/supplier/services
 * @description Tests for supplier business logic layer
 */

const supplierService = require('@modules/supplier/services/supplier.service');
const supplierRepository = require('@modules/supplier/repositories/supplier.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@modules/supplier/repositories/supplier.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue({})
}));

describe('Supplier Service', () => {
  const mockUser = {
    id: 'user-123',
    tenant_id: '660e8400-e29b-41d4-a716-446655440000',
    roles: ['PHARMACIST'],
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  const mockAuditContext = {
    user_id: 'user-123',
    ip_address: '127.0.0.1',
    user: mockUser,
  };

  describe('getSupplierById', () => {
    it('should return supplier when found', async () => {
      const mockSupplier = {
        id: '550e8400-e29b-41d4-a716-446655440000',
        tenant_id: '660e8400-e29b-41d4-a716-446655440000',
        name: 'Medical Supplies Inc'
      };

      supplierRepository.findById.mockResolvedValue(mockSupplier);

      const result = await supplierService.getSupplierById(
        '550e8400-e29b-41d4-a716-446655440000',
        mockUser
      );

      expect(result).toEqual(mockSupplier);
      expect(supplierRepository.findById).toHaveBeenCalledWith('550e8400-e29b-41d4-a716-446655440000');
    });

    it('should throw HttpError when supplier not found', async () => {
      supplierRepository.findById.mockResolvedValue(null);

      await expect(supplierService.getSupplierById('non-existent-id', mockUser))
        .rejects.toThrow(HttpError);
    });

    it('should reject out-of-scope suppliers', async () => {
      supplierRepository.findById.mockResolvedValue({
        id: '550e8400-e29b-41d4-a716-446655440000',
        tenant_id: 'tenant-other',
        name: 'Medical Supplies Inc',
      });

      await expect(
        supplierService.getSupplierById('550e8400-e29b-41d4-a716-446655440000', mockUser)
      )
        .rejects.toThrow(HttpError);
    });
  });

  describe('listSuppliers', () => {
    it('should return paginated suppliers', async () => {
      const mockSuppliers = [
        { id: '1', name: 'Supplier 1' },
        { id: '2', name: 'Supplier 2' }
      ];

      supplierRepository.findMany.mockResolvedValue(mockSuppliers);
      supplierRepository.count.mockResolvedValue(10);

      const result = await supplierService.listSuppliers(
        {},
        { page: 1, limit: 20 },
        { sort_by: 'created_at', order: 'desc' },
        mockUser
      );

      expect(result).toEqual({
        data: mockSuppliers,
        total: 10,
        page: 1,
        limit: 20
      });
    });

    it('should apply tenant_id filter', async () => {
      supplierRepository.findMany.mockResolvedValue([]);
      supplierRepository.count.mockResolvedValue(0);

      await supplierService.listSuppliers(
        { tenant_id: '660e8400-e29b-41d4-a716-446655440000' },
        { page: 1, limit: 20 },
        {},
        mockUser
      );

      expect(supplierRepository.findMany).toHaveBeenCalledWith(
        { tenant_id: '660e8400-e29b-41d4-a716-446655440000' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should apply name filter', async () => {
      supplierRepository.findMany.mockResolvedValue([]);
      supplierRepository.count.mockResolvedValue(0);

      await supplierService.listSuppliers(
        { name: 'Medical' },
        { page: 1, limit: 20 },
        {},
        mockUser
      );

      expect(supplierRepository.findMany).toHaveBeenCalledWith(
        {
          tenant_id: '660e8400-e29b-41d4-a716-446655440000',
          name: { contains: 'Medical' },
        },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should apply search filter with OR conditions', async () => {
      supplierRepository.findMany.mockResolvedValue([]);
      supplierRepository.count.mockResolvedValue(0);

      await supplierService.listSuppliers(
        { search: 'supplies' },
        { page: 1, limit: 20 },
        {},
        mockUser
      );

      expect(supplierRepository.findMany).toHaveBeenCalledWith(
        {
          tenant_id: '660e8400-e29b-41d4-a716-446655440000',
          OR: [
            { name: { contains: 'supplies' } },
            { contact_email: { contains: 'supplies' } },
            { phone: { contains: 'supplies' } }
          ]
        },
        0,
        20,
        { created_at: 'desc' }
      );
    });
  });

  describe('createSupplier', () => {
    it('should create supplier and log audit', async () => {
      const supplierData = {
        tenant_id: '660e8400-e29b-41d4-a716-446655440000',
        name: 'Medical Supplies Inc'
      };

      const mockCreatedSupplier = {
        id: '550e8400-e29b-41d4-a716-446655440000',
        ...supplierData
      };

      supplierRepository.create.mockResolvedValue(mockCreatedSupplier);

      const result = await supplierService.createSupplier(supplierData, mockAuditContext);

      expect(result).toEqual(mockCreatedSupplier);
      expect(supplierRepository.create).toHaveBeenCalledWith({
        ...supplierData,
        tenant_id: mockUser.tenant_id,
      });
      expect(createAuditLog).toHaveBeenCalledWith({
        tenant_id: mockUser.tenant_id,
        user_id: mockAuditContext.user_id,
        action: 'CREATE',
        entity: 'supplier',
        entity_id: mockCreatedSupplier.id,
        diff: { after: mockCreatedSupplier },
        ip_address: mockAuditContext.ip_address
      });
    });
  });

  describe('updateSupplier', () => {
    it('should update supplier and log audit', async () => {
      const existingSupplier = {
        id: '550e8400-e29b-41d4-a716-446655440000',
        tenant_id: '660e8400-e29b-41d4-a716-446655440000',
        name: 'Old Name'
      };

      const updateData = { name: 'New Name' };

      const updatedSupplier = {
        ...existingSupplier,
        ...updateData
      };

      supplierRepository.findById.mockResolvedValue(existingSupplier);
      supplierRepository.update.mockResolvedValue(updatedSupplier);

      const result = await supplierService.updateSupplier(
        '550e8400-e29b-41d4-a716-446655440000',
        updateData,
        mockAuditContext
      );

      expect(result).toEqual(updatedSupplier);
      expect(createAuditLog).toHaveBeenCalledWith({
        tenant_id: existingSupplier.tenant_id,
        user_id: mockAuditContext.user_id,
        action: 'UPDATE',
        entity: 'supplier',
        entity_id: existingSupplier.id,
        diff: { before: existingSupplier, after: updatedSupplier },
        ip_address: mockAuditContext.ip_address
      });
    });

    it('should throw HttpError when supplier not found', async () => {
      supplierRepository.findById.mockResolvedValue(null);

      await expect(supplierService.updateSupplier('non-existent-id', {}, mockAuditContext))
        .rejects.toThrow(HttpError);
    });
  });

  describe('deleteSupplier', () => {
    it('should delete supplier and log audit', async () => {
      const existingSupplier = {
        id: '550e8400-e29b-41d4-a716-446655440000',
        tenant_id: '660e8400-e29b-41d4-a716-446655440000',
        name: 'Medical Supplies Inc'
      };

      const deletedSupplier = {
        ...existingSupplier,
        deleted_at: new Date()
      };

      supplierRepository.findById.mockResolvedValue(existingSupplier);
      supplierRepository.softDelete.mockResolvedValue(deletedSupplier);

      const result = await supplierService.deleteSupplier(
        '550e8400-e29b-41d4-a716-446655440000',
        mockAuditContext
      );

      expect(result).toEqual(deletedSupplier);
      expect(createAuditLog).toHaveBeenCalledWith({
        tenant_id: existingSupplier.tenant_id,
        user_id: mockAuditContext.user_id,
        action: 'DELETE',
        entity: 'supplier',
        entity_id: existingSupplier.id,
        diff: { before: existingSupplier },
        ip_address: mockAuditContext.ip_address
      });
    });

    it('should throw HttpError when supplier not found', async () => {
      supplierRepository.findById.mockResolvedValue(null);

      await expect(supplierService.deleteSupplier('non-existent-id', mockAuditContext))
        .rejects.toThrow(HttpError);
    });
  });
});
