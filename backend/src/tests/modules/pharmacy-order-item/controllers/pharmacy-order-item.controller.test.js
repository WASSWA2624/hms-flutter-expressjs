/**
 * Pharmacy order item controller tests
 */

const pharmacyOrderItemController = require('@controllers/pharmacy-order-item/pharmacy-order-item.controller');
const pharmacyOrderItemService = require('@services/pharmacy-order-item/pharmacy-order-item.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

jest.mock('@services/pharmacy-order-item/pharmacy-order-item.service');
jest.mock('@lib/response');

describe('Pharmacy Order Item Controller', () => {
  let req;
  let res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'requester-id', tenant_id: 'tenant-123' },
      ip: '127.0.0.1'
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
  });

  describe('listPharmacyOrderItems', () => {
    it('should list items with default pagination', async () => {
      const mockResult = {
        pharmacyOrderItems: [{ id: 'item-1' }],
        pagination: {
          page: 1,
          limit: 20,
          total: 1,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      pharmacyOrderItemService.listPharmacyOrderItems.mockResolvedValue(mockResult);

      await pharmacyOrderItemController.listPharmacyOrderItems(req, res);

      expect(pharmacyOrderItemService.listPharmacyOrderItems).toHaveBeenCalledWith(
        expect.any(Object),
        DEFAULT_PAGE,
        DEFAULT_PAGE_LIMIT,
        undefined,
        'asc',
        'requester-id',
        '127.0.0.1',
        req.user
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.pharmacy_order_item.list.success',
        mockResult.pharmacyOrderItems,
        mockResult.pagination
      );
    });
  });

  describe('getPharmacyOrderItemById', () => {
    it('should get item by id', async () => {
      req.params = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const mockItem = { id: req.params.id };
      pharmacyOrderItemService.getPharmacyOrderItemById.mockResolvedValue(mockItem);

      await pharmacyOrderItemController.getPharmacyOrderItemById(req, res);

      expect(pharmacyOrderItemService.getPharmacyOrderItemById).toHaveBeenCalledWith(
        req.params.id,
        'requester-id',
        '127.0.0.1',
        req.user
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.pharmacy_order_item.get.success',
        mockItem
      );
    });
  });

  describe('createPharmacyOrderItem', () => {
    it('should create item', async () => {
      req.body = {
        pharmacy_order_id: '550e8400-e29b-41d4-a716-446655440000',
        drug_id: '550e8400-e29b-41d4-a716-446655440001',
        quantity: 2
      };
      const mockCreated = { id: 'item-1', ...req.body };
      pharmacyOrderItemService.createPharmacyOrderItem.mockResolvedValue(mockCreated);

      await pharmacyOrderItemController.createPharmacyOrderItem(req, res);

      expect(pharmacyOrderItemService.createPharmacyOrderItem).toHaveBeenCalledWith(
        req.body,
        'requester-id',
        '127.0.0.1',
        req.user
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.pharmacy_order_item.create.success',
        mockCreated
      );
    });
  });

  describe('updatePharmacyOrderItem', () => {
    it('should update item', async () => {
      req.params = { id: '550e8400-e29b-41d4-a716-446655440000' };
      req.body = { quantity: 3 };
      const mockUpdated = { id: req.params.id, ...req.body };
      pharmacyOrderItemService.updatePharmacyOrderItem.mockResolvedValue(mockUpdated);

      await pharmacyOrderItemController.updatePharmacyOrderItem(req, res);

      expect(pharmacyOrderItemService.updatePharmacyOrderItem).toHaveBeenCalledWith(
        req.params.id,
        req.body,
        'requester-id',
        '127.0.0.1',
        req.user
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.pharmacy_order_item.update.success',
        mockUpdated
      );
    });
  });

  describe('deletePharmacyOrderItem', () => {
    it('should delete item', async () => {
      req.params = { id: '550e8400-e29b-41d4-a716-446655440000' };
      pharmacyOrderItemService.deletePharmacyOrderItem.mockResolvedValue(undefined);

      await pharmacyOrderItemController.deletePharmacyOrderItem(req, res);

      expect(pharmacyOrderItemService.deletePharmacyOrderItem).toHaveBeenCalledWith(
        req.params.id,
        'requester-id',
        '127.0.0.1',
        req.user
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });
});
