/**
 * Inventory item service tests
 *
 * @module tests/modules/inventory-item/services
 * @description Tests for inventory item service business logic
 * Per testing.mdc: Service tests must mock repository and audit functions
 */

const inventoryItemService = require('@services/inventory-item/inventory-item.service');
const inventoryItemRepository = require('@repositories/inventory-item/inventory-item.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/inventory-item/inventory-item.repository');
jest.mock('@lib/audit');

const mockUser = {
  id: 'user-123',
  tenant_id: 'tenant-123',
  roles: ['PHARMACIST'],
};

const buildScopedInventoryItem = (overrides = {}) => ({
  id: '123',
  tenant_id: 'tenant-123',
  name: 'Surgical Gloves',
  category: 'SUPPLY',
  ...overrides,
});

describe('Inventory Item Service', () => {
  const mockUserId = 'user-123';
  const mockIpAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockReturnValue(Promise.resolve());
  });

  describe('listInventoryItems', () => {
    it('should list inventory items with pagination', async () => {
      const mockItems = [{ id: '1', name: 'Surgical Gloves', category: 'SUPPLY' }];
      inventoryItemRepository.findMany.mockResolvedValue(mockItems);
      inventoryItemRepository.count.mockResolvedValue(1);

      const result = await inventoryItemService.listInventoryItems(
        {},
        1,
        20,
        'created_at',
        'desc',
        mockUserId,
        mockIpAddress,
        mockUser
      );

      expect(result.inventoryItems).toEqual(mockItems);
      expect(result.pagination.total).toBe(1);
      expect(result.pagination.totalPages).toBe(1);
      expect(result.pagination.hasNextPage).toBe(false);
      expect(result.pagination.hasPreviousPage).toBe(false);
      expect(inventoryItemRepository.findMany).toHaveBeenCalled();
      expect(inventoryItemRepository.count).toHaveBeenCalled();
    });

    it('should handle search filters', async () => {
      inventoryItemRepository.findMany.mockResolvedValue([]);
      inventoryItemRepository.count.mockResolvedValue(0);

      await inventoryItemService.listInventoryItems(
        { search: 'Glove' },
        1,
        20,
        null,
        'asc',
        mockUserId,
        mockIpAddress,
        mockUser
      );

      expect(inventoryItemRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ OR: expect.any(Array) }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should handle name filter', async () => {
      inventoryItemRepository.findMany.mockResolvedValue([]);
      inventoryItemRepository.count.mockResolvedValue(0);

      await inventoryItemService.listInventoryItems(
        { name: 'Surgical Gloves' },
        1,
        20,
        null,
        'asc',
        mockUserId,
        mockIpAddress,
        mockUser
      );

      expect(inventoryItemRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ name: { contains: 'Surgical Gloves' } }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should handle category filter', async () => {
      inventoryItemRepository.findMany.mockResolvedValue([]);
      inventoryItemRepository.count.mockResolvedValue(0);

      await inventoryItemService.listInventoryItems(
        { category: 'MEDICATION' },
        1,
        20,
        null,
        'asc',
        mockUserId,
        mockIpAddress,
        mockUser
      );

      expect(inventoryItemRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ category: 'MEDICATION' }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should handle multiple filters', async () => {
      inventoryItemRepository.findMany.mockResolvedValue([]);
      inventoryItemRepository.count.mockResolvedValue(0);

      await inventoryItemService.listInventoryItems(
        { tenant_id: '123', category: 'SUPPLY', sku: 'SG-001', unit: 'Box' },
        1,
        20,
        null,
        'asc',
        mockUserId,
        mockIpAddress,
        mockUser
      );

      expect(inventoryItemRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-123',
          category: 'SUPPLY',
          sku: { contains: 'SG-001' },
          unit: { contains: 'Box' }
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should calculate pagination correctly', async () => {
      inventoryItemRepository.findMany.mockResolvedValue([]);
      inventoryItemRepository.count.mockResolvedValue(50);

      const result = await inventoryItemService.listInventoryItems(
        {},
        2,
        20,
        null,
        'asc',
        mockUserId,
        mockIpAddress,
        mockUser
      );

      expect(result.pagination.totalPages).toBe(3);
      expect(result.pagination.hasNextPage).toBe(true);
      expect(result.pagination.hasPreviousPage).toBe(true);
    });

    it('should handle repository errors', async () => {
      inventoryItemRepository.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(
        inventoryItemService.listInventoryItems(
          {},
          1,
          20,
          null,
          'asc',
          mockUserId,
          mockIpAddress,
          mockUser
        )
      ).rejects.toThrow(HttpError);
    });
  });

  describe('getInventoryItemById', () => {
    it('should get inventory item by id', async () => {
      const mockItem = buildScopedInventoryItem();
      inventoryItemRepository.findById.mockResolvedValue(mockItem);

      const result = await inventoryItemService.getInventoryItemById(
        '123',
        mockUserId,
        mockIpAddress,
        mockUser
      );

      expect(result).toEqual(mockItem);
      expect(inventoryItemRepository.findById).toHaveBeenCalledWith('123');
    });

    it('should throw HttpError if inventory item not found', async () => {
      inventoryItemRepository.findById.mockResolvedValue(null);

      await expect(
        inventoryItemService.getInventoryItemById('nonexistent', mockUserId, mockIpAddress, mockUser)
      ).rejects.toThrow(HttpError);
      await expect(
        inventoryItemService.getInventoryItemById('nonexistent', mockUserId, mockIpAddress, mockUser)
      ).rejects.toMatchObject({
        message: 'errors.inventory_item.not_found',
        statusCode: 404
      });
    });

    it('should reject out-of-scope inventory items', async () => {
      inventoryItemRepository.findById.mockResolvedValue(
        buildScopedInventoryItem({ tenant_id: 'tenant-other' })
      );

      await expect(
        inventoryItemService.getInventoryItemById('123', mockUserId, mockIpAddress, mockUser)
      ).rejects.toThrow(HttpError);
    });

    it('should handle repository errors', async () => {
      inventoryItemRepository.findById.mockRejectedValue(new Error('DB Error'));

      await expect(
        inventoryItemService.getInventoryItemById('123', mockUserId, mockIpAddress, mockUser)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createInventoryItem', () => {
    it('should create inventory item and log audit', async () => {
      const mockData = { tenant_id: '123', name: 'Surgical Gloves', category: 'SUPPLY' };
      const mockItem = { id: '456', ...mockData };
      inventoryItemRepository.create.mockResolvedValue(mockItem);

      const result = await inventoryItemService.createInventoryItem(
        mockData,
        mockUserId,
        mockIpAddress,
        mockUser
      );

      expect(result).toEqual(mockItem);
      expect(inventoryItemRepository.create).toHaveBeenCalledWith({
        ...mockData,
        tenant_id: 'tenant-123',
      });
      expect(createAuditLog).toHaveBeenCalledWith({
        tenant_id: 'tenant-123',
        user_id: mockUserId,
        action: 'CREATE',
        entity: 'inventory_item',
        entity_id: mockItem.id,
        diff: { after: mockItem },
        ip_address: mockIpAddress
      });
    });

    it('should handle repository errors', async () => {
      inventoryItemRepository.create.mockRejectedValue(new Error('DB Error'));

      await expect(
        inventoryItemService.createInventoryItem({}, mockUserId, mockIpAddress, mockUser)
      ).rejects.toThrow(HttpError);
    });

    it('should not fail if audit log fails', async () => {
      const mockData = { tenant_id: '123', name: 'Surgical Gloves', category: 'SUPPLY' };
      const mockItem = { id: '456', ...mockData };
      inventoryItemRepository.create.mockResolvedValue(mockItem);
      createAuditLog.mockImplementation(() => Promise.reject(new Error('Audit failed')));

      const result = await inventoryItemService.createInventoryItem(
        mockData,
        mockUserId,
        mockIpAddress,
        mockUser
      );

      expect(result).toEqual(mockItem);
    });
  });

  describe('updateInventoryItem', () => {
    it('should update inventory item and log audit', async () => {
      const mockBefore = buildScopedInventoryItem({ name: 'Old Name' });
      const mockData = { name: 'New Name' };
      const mockAfter = { id: '123', name: 'New Name', category: 'SUPPLY' };
      inventoryItemRepository.findById.mockResolvedValue(mockBefore);
      inventoryItemRepository.update.mockResolvedValue(mockAfter);

      const result = await inventoryItemService.updateInventoryItem(
        '123',
        mockData,
        mockUserId,
        mockIpAddress,
        mockUser
      );

      expect(result).toEqual(mockAfter);
      expect(inventoryItemRepository.findById).toHaveBeenCalledWith('123');
      expect(inventoryItemRepository.update).toHaveBeenCalledWith('123', {
        ...mockData,
        tenant_id: 'tenant-123',
      });
      expect(createAuditLog).toHaveBeenCalledWith({
        tenant_id: 'tenant-123',
        user_id: mockUserId,
        action: 'UPDATE',
        entity: 'inventory_item',
        entity_id: mockAfter.id,
        diff: { before: mockBefore, after: mockAfter },
        ip_address: mockIpAddress
      });
    });

    it('should throw HttpError if inventory item not found', async () => {
      inventoryItemRepository.findById.mockResolvedValue(null);

      await expect(
        inventoryItemService.updateInventoryItem(
          'nonexistent',
          {},
          mockUserId,
          mockIpAddress,
          mockUser
        )
      ).rejects.toThrow(HttpError);
      await expect(
        inventoryItemService.updateInventoryItem(
          'nonexistent',
          {},
          mockUserId,
          mockIpAddress,
          mockUser
        )
      ).rejects.toMatchObject({
        message: 'errors.inventory_item.not_found',
        statusCode: 404
      });
    });

    it('should handle repository errors', async () => {
      inventoryItemRepository.findById.mockResolvedValue(buildScopedInventoryItem());
      inventoryItemRepository.update.mockRejectedValue(new Error('DB Error'));

      await expect(
        inventoryItemService.updateInventoryItem('123', {}, mockUserId, mockIpAddress, mockUser)
      ).rejects.toThrow(HttpError);
    });

    it('should not fail if audit log fails', async () => {
      const mockBefore = buildScopedInventoryItem({ name: 'Old Name' });
      const mockAfter = { id: '123', name: 'New Name' };
      inventoryItemRepository.findById.mockResolvedValue(mockBefore);
      inventoryItemRepository.update.mockResolvedValue(mockAfter);
      createAuditLog.mockImplementation(() => Promise.reject(new Error('Audit failed')));

      const result = await inventoryItemService.updateInventoryItem(
        '123',
        { name: 'New Name' },
        mockUserId,
        mockIpAddress,
        mockUser
      );

      expect(result).toEqual(mockAfter);
    });
  });

  describe('deleteInventoryItem', () => {
    it('should delete inventory item and log audit', async () => {
      const mockItem = buildScopedInventoryItem();
      inventoryItemRepository.findById.mockResolvedValue(mockItem);
      inventoryItemRepository.softDelete.mockResolvedValue(undefined);

      await inventoryItemService.deleteInventoryItem('123', mockUserId, mockIpAddress, mockUser);

      expect(inventoryItemRepository.findById).toHaveBeenCalledWith('123');
      expect(inventoryItemRepository.softDelete).toHaveBeenCalledWith('123');
      expect(createAuditLog).toHaveBeenCalledWith({
        tenant_id: 'tenant-123',
        user_id: mockUserId,
        action: 'DELETE',
        entity: 'inventory_item',
        entity_id: '123',
        diff: { before: mockItem },
        ip_address: mockIpAddress
      });
    });

    it('should throw HttpError if inventory item not found', async () => {
      inventoryItemRepository.findById.mockResolvedValue(null);

      await expect(
        inventoryItemService.deleteInventoryItem('nonexistent', mockUserId, mockIpAddress, mockUser)
      ).rejects.toThrow(HttpError);
      await expect(
        inventoryItemService.deleteInventoryItem('nonexistent', mockUserId, mockIpAddress, mockUser)
      ).rejects.toMatchObject({
        message: 'errors.inventory_item.not_found',
        statusCode: 404
      });
    });

    it('should handle repository errors', async () => {
      inventoryItemRepository.findById.mockResolvedValue(buildScopedInventoryItem());
      inventoryItemRepository.softDelete.mockRejectedValue(new Error('DB Error'));

      await expect(
        inventoryItemService.deleteInventoryItem('123', mockUserId, mockIpAddress, mockUser)
      ).rejects.toThrow(HttpError);
    });

    it('should not fail if audit log fails', async () => {
      const mockItem = buildScopedInventoryItem();
      inventoryItemRepository.findById.mockResolvedValue(mockItem);
      inventoryItemRepository.softDelete.mockResolvedValue(undefined);
      createAuditLog.mockImplementation(() => Promise.reject(new Error('Audit failed')));

      await expect(
        inventoryItemService.deleteInventoryItem('123', mockUserId, mockIpAddress, mockUser)
      ).resolves.not.toThrow();
    });
  });
});
