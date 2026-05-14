/**
 * Supplier repository tests
 *
 * @module tests/modules/supplier/repositories
 * @description Tests for supplier data access layer
 */

const supplierRepository = require('@modules/supplier/repositories/supplier.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  supplier: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Supplier Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find supplier by ID', async () => {
      const mockSupplier = {
        id: '550e8400-e29b-41d4-a716-446655440000',
        tenant_id: '660e8400-e29b-41d4-a716-446655440000',
        name: 'Medical Supplies Inc',
        contact_email: 'contact@medicalsupplies.com',
        phone: '+1234567890',
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null
      };

      prisma.supplier.findFirst.mockResolvedValue(mockSupplier);

      const result = await supplierRepository.findById('550e8400-e29b-41d4-a716-446655440000');

      expect(result).toEqual(mockSupplier);
      expect(prisma.supplier.findFirst).toHaveBeenCalledWith({
        where: {
          id: '550e8400-e29b-41d4-a716-446655440000',
          deleted_at: null
        },
        include: {}
      });
    });

    it('should return null if supplier not found', async () => {
      prisma.supplier.findFirst.mockResolvedValue(null);

      const result = await supplierRepository.findById('non-existent-id');

      expect(result).toBeNull();
    });

    it('should handle database errors', async () => {
      prisma.supplier.findFirst.mockRejectedValue(new Error('Database error'));

      await expect(supplierRepository.findById('550e8400-e29b-41d4-a716-446655440000'))
        .rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find multiple suppliers with pagination', async () => {
      const mockSuppliers = [
        {
          id: '550e8400-e29b-41d4-a716-446655440000',
          tenant_id: '660e8400-e29b-41d4-a716-446655440000',
          name: 'Supplier 1',
          created_at: new Date(),
          updated_at: new Date(),
          deleted_at: null
        },
        {
          id: '550e8400-e29b-41d4-a716-446655440001',
          tenant_id: '660e8400-e29b-41d4-a716-446655440000',
          name: 'Supplier 2',
          created_at: new Date(),
          updated_at: new Date(),
          deleted_at: null
        }
      ];

      prisma.supplier.findMany.mockResolvedValue(mockSuppliers);

      const result = await supplierRepository.findMany({}, 0, 20);

      expect(result).toEqual(mockSuppliers);
      expect(prisma.supplier.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply filters correctly', async () => {
      const filters = {
        tenant_id: '660e8400-e29b-41d4-a716-446655440000',
        name: { contains: 'Medical' }
      };

      prisma.supplier.findMany.mockResolvedValue([]);

      await supplierRepository.findMany(filters, 0, 20);

      expect(prisma.supplier.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          ...filters
        },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should handle database errors', async () => {
      prisma.supplier.findMany.mockRejectedValue(new Error('Database error'));

      await expect(supplierRepository.findMany())
        .rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count suppliers', async () => {
      prisma.supplier.count.mockResolvedValue(42);

      const result = await supplierRepository.count();

      expect(result).toBe(42);
      expect(prisma.supplier.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count with filters', async () => {
      const filters = {
        tenant_id: '660e8400-e29b-41d4-a716-446655440000'
      };

      prisma.supplier.count.mockResolvedValue(10);

      const result = await supplierRepository.count(filters);

      expect(result).toBe(10);
      expect(prisma.supplier.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          ...filters
        }
      });
    });

    it('should handle database errors', async () => {
      prisma.supplier.count.mockRejectedValue(new Error('Database error'));

      await expect(supplierRepository.count())
        .rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create new supplier', async () => {
      const supplierData = {
        tenant_id: '660e8400-e29b-41d4-a716-446655440000',
        name: 'Medical Supplies Inc',
        contact_email: 'contact@medicalsupplies.com',
        phone: '+1234567890'
      };

      const mockCreatedSupplier = {
        id: '550e8400-e29b-41d4-a716-446655440000',
        ...supplierData,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null
      };

      prisma.supplier.create.mockResolvedValue(mockCreatedSupplier);

      const result = await supplierRepository.create(supplierData);

      expect(result).toEqual(mockCreatedSupplier);
      expect(prisma.supplier.create).toHaveBeenCalledWith({
        data: supplierData
      });
    });

    it('should handle unique constraint violation', async () => {
      const error = new Error('Unique constraint violation');
      error.code = 'P2002';
      error.meta = { target: ['name'] };

      prisma.supplier.create.mockRejectedValue(error);

      await expect(supplierRepository.create({}))
        .rejects.toThrow(HttpError);
    });

    it('should handle foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint violation');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };

      prisma.supplier.create.mockRejectedValue(error);

      await expect(supplierRepository.create({}))
        .rejects.toThrow(HttpError);
    });

    it('should handle general database errors', async () => {
      prisma.supplier.create.mockRejectedValue(new Error('Database error'));

      await expect(supplierRepository.create({}))
        .rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update supplier', async () => {
      const updateData = {
        name: 'Updated Supplies Inc'
      };

      const mockUpdatedSupplier = {
        id: '550e8400-e29b-41d4-a716-446655440000',
        tenant_id: '660e8400-e29b-41d4-a716-446655440000',
        ...updateData,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null
      };

      prisma.supplier.update.mockResolvedValue(mockUpdatedSupplier);

      const result = await supplierRepository.update('550e8400-e29b-41d4-a716-446655440000', updateData);

      expect(result).toEqual(mockUpdatedSupplier);
      expect(prisma.supplier.update).toHaveBeenCalledWith({
        where: { id: '550e8400-e29b-41d4-a716-446655440000' },
        data: updateData
      });
    });

    it('should handle not found error', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';

      prisma.supplier.update.mockRejectedValue(error);

      await expect(supplierRepository.update('non-existent-id', {}))
        .rejects.toThrow(HttpError);
    });

    it('should handle unique constraint violation', async () => {
      const error = new Error('Unique constraint violation');
      error.code = 'P2002';
      error.meta = { target: ['name'] };

      prisma.supplier.update.mockRejectedValue(error);

      await expect(supplierRepository.update('550e8400-e29b-41d4-a716-446655440000', {}))
        .rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete supplier', async () => {
      const mockDeletedSupplier = {
        id: '550e8400-e29b-41d4-a716-446655440000',
        tenant_id: '660e8400-e29b-41d4-a716-446655440000',
        name: 'Medical Supplies Inc',
        deleted_at: new Date()
      };

      prisma.supplier.update.mockResolvedValue(mockDeletedSupplier);

      const result = await supplierRepository.softDelete('550e8400-e29b-41d4-a716-446655440000');

      expect(result).toEqual(mockDeletedSupplier);
      expect(prisma.supplier.update).toHaveBeenCalledWith({
        where: { id: '550e8400-e29b-41d4-a716-446655440000' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should handle not found error', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';

      prisma.supplier.update.mockRejectedValue(error);

      await expect(supplierRepository.softDelete('non-existent-id'))
        .rejects.toThrow(HttpError);
    });

    it('should handle database errors', async () => {
      prisma.supplier.update.mockRejectedValue(new Error('Database error'));

      await expect(supplierRepository.softDelete('550e8400-e29b-41d4-a716-446655440000'))
        .rejects.toThrow(HttpError);
    });
  });
});
