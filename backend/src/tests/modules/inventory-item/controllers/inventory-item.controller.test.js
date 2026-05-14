/**
 * Inventory item controller tests
 *
 * @module tests/modules/inventory-item/controllers
 * @description Tests for inventory item controller request handlers
 * Per testing.mdc: Controller tests must mock service layer
 */

const inventoryItemController = require('@controllers/inventory-item/inventory-item.controller');
const inventoryItemService = require('@services/inventory-item/inventory-item.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@services/inventory-item/inventory-item.service');
jest.mock('@lib/response');
jest.mock('@config/constants', () => ({
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_LIMIT: 20
}));

describe('Inventory Item Controller', () => {
  let mockReq;
  let mockRes;

  beforeEach(() => {
    jest.clearAllMocks();
    mockReq = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-123' },
      ip: '127.0.0.1'
    };
    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
  });

  describe('listInventoryItems', () => {
    it('should call service and send paginated response', async () => {
      const mockResult = {
        inventoryItems: [{ id: '1', name: 'Surgical Gloves', category: 'SUPPLY' }],
        pagination: { page: 1, limit: 20, total: 1, totalPages: 1, hasNextPage: false, hasPreviousPage: false }
      };
      inventoryItemService.listInventoryItems.mockResolvedValue(mockResult);

      await inventoryItemController.listInventoryItems(mockReq, mockRes);

      expect(inventoryItemService.listInventoryItems).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.inventory_item.list.success',
        mockResult.inventoryItems,
        mockResult.pagination
      );
    });

    it('should parse query parameters correctly', async () => {
      mockReq.query = {
        page: '2',
        limit: '50',
        sort_by: 'name',
        order: 'asc',
        tenant_id: '123',
        name: 'Surgical Gloves',
        category: 'SUPPLY',
        sku: 'SG-001',
        unit: 'Box',
        search: 'glove'
      };
      inventoryItemService.listInventoryItems.mockResolvedValue({
        inventoryItems: [],
        pagination: { page: 2, limit: 50, total: 0 }
      });

      await inventoryItemController.listInventoryItems(mockReq, mockRes);

      expect(inventoryItemService.listInventoryItems).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: '123',
          name: 'Surgical Gloves',
          category: 'SUPPLY',
          sku: 'SG-001',
          unit: 'Box',
          search: 'glove'
        }),
        2,
        50,
        'name',
        'asc',
        'user-123',
        '127.0.0.1',
        mockReq.user
      );
    });

    it('should use default page and limit when not provided', async () => {
      inventoryItemService.listInventoryItems.mockResolvedValue({
        inventoryItems: [],
        pagination: {}
      });

      await inventoryItemController.listInventoryItems(mockReq, mockRes);

      expect(inventoryItemService.listInventoryItems).toHaveBeenCalledWith(
        expect.any(Object),
        1,
        20,
        undefined,
        'asc',
        'user-123',
        '127.0.0.1',
        mockReq.user
      );
    });
  });

  describe('getInventoryItemById', () => {
    it('should call service and send success response', async () => {
      mockReq.params.id = '123';
      const mockItem = { id: '123', name: 'Surgical Gloves', category: 'SUPPLY' };
      inventoryItemService.getInventoryItemById.mockResolvedValue(mockItem);

      await inventoryItemController.getInventoryItemById(mockReq, mockRes);

      expect(inventoryItemService.getInventoryItemById).toHaveBeenCalledWith(
        '123',
        'user-123',
        '127.0.0.1',
        mockReq.user
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.inventory_item.get.success',
        mockItem
      );
    });
  });

  describe('createInventoryItem', () => {
    it('should call service and send success response', async () => {
      mockReq.body = { tenant_id: '123', name: 'Surgical Gloves', category: 'SUPPLY' };
      const mockItem = { id: '456', ...mockReq.body };
      inventoryItemService.createInventoryItem.mockResolvedValue(mockItem);

      await inventoryItemController.createInventoryItem(mockReq, mockRes);

      expect(inventoryItemService.createInventoryItem).toHaveBeenCalledWith(
        mockReq.body,
        'user-123',
        '127.0.0.1',
        mockReq.user
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        201,
        'messages.inventory_item.create.success',
        mockItem
      );
    });
  });

  describe('updateInventoryItem', () => {
    it('should call service and send success response', async () => {
      mockReq.params.id = '123';
      mockReq.body = { name: 'Updated Gloves' };
      const mockItem = { id: '123', name: 'Updated Gloves' };
      inventoryItemService.updateInventoryItem.mockResolvedValue(mockItem);

      await inventoryItemController.updateInventoryItem(mockReq, mockRes);

      expect(inventoryItemService.updateInventoryItem).toHaveBeenCalledWith(
        '123',
        mockReq.body,
        'user-123',
        '127.0.0.1',
        mockReq.user
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.inventory_item.update.success',
        mockItem
      );
    });
  });

  describe('deleteInventoryItem', () => {
    it('should call service and send no content response', async () => {
      mockReq.params.id = '123';
      inventoryItemService.deleteInventoryItem.mockResolvedValue(undefined);

      await inventoryItemController.deleteInventoryItem(mockReq, mockRes);

      expect(inventoryItemService.deleteInventoryItem).toHaveBeenCalledWith(
        '123',
        'user-123',
        '127.0.0.1',
        mockReq.user
      );
      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
