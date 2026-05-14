/**
 * Supplier controller tests
 *
 * @module tests/modules/supplier/controllers
 * @description Tests for supplier HTTP handlers
 */

const supplierController = require('@modules/supplier/controllers/supplier.controller');
const supplierService = require('@modules/supplier/services/supplier.service');
const { sendSuccess, sendCreated, sendNoContent } = require('@lib/response');

// Mock dependencies
jest.mock('@modules/supplier/services/supplier.service');
jest.mock('@lib/response');

describe('Supplier Controller', () => {
  let mockReq;
  let mockRes;

  beforeEach(() => {
    jest.clearAllMocks();
    
    mockReq = {
      params: {},
      query: {},
      body: {},
      user: { id: 'user-123' },
      ip: '127.0.0.1',
      locale: 'en'
    };
    
    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
  });

  describe('getSupplier', () => {
    it('should get supplier by ID', async () => {
      const mockSupplier = {
        id: '550e8400-e29b-41d4-a716-446655440000',
        name: 'Medical Supplies Inc'
      };

      mockReq.params = { id: '550e8400-e29b-41d4-a716-446655440000' };
      supplierService.getSupplierById.mockResolvedValue(mockSupplier);

      await supplierController.getSupplier(mockReq, mockRes);

      expect(supplierService.getSupplierById).toHaveBeenCalledWith(
        '550e8400-e29b-41d4-a716-446655440000',
        mockReq.user
      );
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, mockSupplier, 'messages.supplier.retrieved', 'en');
    });
  });

  describe('listSuppliers', () => {
    it('should list suppliers with pagination', async () => {
      const mockResult = {
        data: [
          { id: '1', name: 'Supplier 1' },
          { id: '2', name: 'Supplier 2' }
        ],
        total: 10,
        page: 1,
        limit: 20
      };

      mockReq.query = {
        page: '1',
        limit: '20',
        sort_by: 'name',
        order: 'asc'
      };

      supplierService.listSuppliers.mockResolvedValue(mockResult);

      await supplierController.listSuppliers(mockReq, mockRes);

      expect(supplierService.listSuppliers).toHaveBeenCalledWith(
        {},
        { page: 1, limit: 20 },
        { sort_by: 'name', order: 'asc' },
        mockReq.user
      );

      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        mockResult.data,
        'messages.supplier.list_retrieved',
        'en',
        {
          pagination: {
            page: 1,
            limit: 20,
            total: 10,
            total_pages: 1
          }
        }
      );
    });

    it('should apply filters', async () => {
      mockReq.query = {
        tenant_id: '660e8400-e29b-41d4-a716-446655440000',
        name: 'Medical',
        page: '1',
        limit: '20'
      };

      supplierService.listSuppliers.mockResolvedValue({
        data: [],
        total: 0,
        page: 1,
        limit: 20
      });

      await supplierController.listSuppliers(mockReq, mockRes);

      expect(supplierService.listSuppliers).toHaveBeenCalledWith(
        {
          tenant_id: '660e8400-e29b-41d4-a716-446655440000',
          name: 'Medical'
        },
        { page: 1, limit: 20 },
        { sort_by: undefined, order: undefined },
        mockReq.user
      );
    });
  });

  describe('createSupplier', () => {
    it('should create new supplier', async () => {
      const supplierData = {
        tenant_id: '660e8400-e29b-41d4-a716-446655440000',
        name: 'Medical Supplies Inc'
      };

      const mockCreatedSupplier = {
        id: '550e8400-e29b-41d4-a716-446655440000',
        ...supplierData
      };

      mockReq.body = supplierData;
      supplierService.createSupplier.mockResolvedValue(mockCreatedSupplier);

      await supplierController.createSupplier(mockReq, mockRes);

      expect(supplierService.createSupplier).toHaveBeenCalledWith(
        supplierData,
        {
          user_id: 'user-123',
          ip_address: '127.0.0.1',
          user: mockReq.user
        }
      );

      expect(sendCreated).toHaveBeenCalledWith(mockRes, mockCreatedSupplier, 'messages.supplier.created', 'en');
    });
  });

  describe('updateSupplier', () => {
    it('should update supplier', async () => {
      const updateData = { name: 'Updated Name' };
      const mockUpdatedSupplier = {
        id: '550e8400-e29b-41d4-a716-446655440000',
        ...updateData
      };

      mockReq.params = { id: '550e8400-e29b-41d4-a716-446655440000' };
      mockReq.body = updateData;
      supplierService.updateSupplier.mockResolvedValue(mockUpdatedSupplier);

      await supplierController.updateSupplier(mockReq, mockRes);

      expect(supplierService.updateSupplier).toHaveBeenCalledWith(
        '550e8400-e29b-41d4-a716-446655440000',
        updateData,
        {
          user_id: 'user-123',
          ip_address: '127.0.0.1',
          user: mockReq.user
        }
      );

      expect(sendSuccess).toHaveBeenCalledWith(mockRes, mockUpdatedSupplier, 'messages.supplier.updated', 'en');
    });
  });

  describe('deleteSupplier', () => {
    it('should delete supplier', async () => {
      mockReq.params = { id: '550e8400-e29b-41d4-a716-446655440000' };
      supplierService.deleteSupplier.mockResolvedValue({});

      await supplierController.deleteSupplier(mockReq, mockRes);

      expect(supplierService.deleteSupplier).toHaveBeenCalledWith(
        '550e8400-e29b-41d4-a716-446655440000',
        {
          user_id: 'user-123',
          ip_address: '127.0.0.1',
          user: mockReq.user
        }
      );

      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
