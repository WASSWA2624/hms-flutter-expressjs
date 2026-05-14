/**
 * Pharmacy order controller tests
 *
 * @module tests/modules/pharmacy-order/controllers
 * @description Tests for pharmacy order controller request handlers
 * Per testing.mdc: Controller tests must mock service layer
 */

const pharmacyOrderController = require('@controllers/pharmacy-order/pharmacy-order.controller');
const pharmacyOrderService = require('@services/pharmacy-order/pharmacy-order.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@services/pharmacy-order/pharmacy-order.service');
jest.mock('@lib/response');
jest.mock('@config/constants', () => ({
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_LIMIT: 20
}));

describe('Pharmacy Order Controller', () => {
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

  describe('listPharmacyOrders', () => {
    it('should call service and send paginated response', async () => {
      const mockResult = {
        pharmacyOrders: [
          { 
            id: 'order-1', 
            patient_id: 'patient-123', 
            status: 'ORDERED',
            ordered_at: new Date('2026-01-19T12:00:00.000Z')
          }
        ],
        pagination: { 
          page: 1, 
          limit: 20, 
          total: 1, 
          totalPages: 1, 
          hasNextPage: false, 
          hasPreviousPage: false 
        }
      };
      pharmacyOrderService.listPharmacyOrders.mockResolvedValue(mockResult);

      await pharmacyOrderController.listPharmacyOrders(mockReq, mockRes);

      expect(pharmacyOrderService.listPharmacyOrders).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.pharmacy_order.list.success',
        mockResult.pharmacyOrders,
        mockResult.pagination
      );
    });

    it('should parse query parameters correctly', async () => {
      mockReq.query = {
        page: '2',
        limit: '50',
        sort_by: 'ordered_at',
        order: 'asc',
        patient_id: 'patient-123',
        encounter_id: 'encounter-456',
        status: 'DISPENSED',
        ordered_at_from: '2026-01-01T00:00:00.000Z',
        ordered_at_to: '2026-12-31T23:59:59.999Z'
      };
      pharmacyOrderService.listPharmacyOrders.mockResolvedValue({
        pharmacyOrders: [],
        pagination: { page: 2, limit: 50, total: 0 }
      });

      await pharmacyOrderController.listPharmacyOrders(mockReq, mockRes);

      expect(pharmacyOrderService.listPharmacyOrders).toHaveBeenCalledWith(
        expect.objectContaining({
          patient_id: 'patient-123',
          encounter_id: 'encounter-456',
          status: 'DISPENSED',
          ordered_at_from: '2026-01-01T00:00:00.000Z',
          ordered_at_to: '2026-12-31T23:59:59.999Z'
        }),
        2,
        50,
        'ordered_at',
        'asc',
        'user-123',
        '127.0.0.1',
        mockReq.user
      );
    });

    it('should use default page and limit when not provided', async () => {
      pharmacyOrderService.listPharmacyOrders.mockResolvedValue({
        pharmacyOrders: [],
        pagination: {}
      });

      await pharmacyOrderController.listPharmacyOrders(mockReq, mockRes);

      expect(pharmacyOrderService.listPharmacyOrders).toHaveBeenCalledWith(
        expect.anything(),
        1,
        20,
        undefined,
        'desc',
        'user-123',
        '127.0.0.1',
        mockReq.user
      );
    });

    it('should handle filters correctly', async () => {
      mockReq.query = {
        patient_id: 'patient-123',
        status: 'ORDERED'
      };
      pharmacyOrderService.listPharmacyOrders.mockResolvedValue({
        pharmacyOrders: [],
        pagination: {}
      });

      await pharmacyOrderController.listPharmacyOrders(mockReq, mockRes);

      expect(pharmacyOrderService.listPharmacyOrders).toHaveBeenCalledWith(
        {
          patient_id: 'patient-123',
          encounter_id: undefined,
          status: 'ORDERED',
          ordered_at_from: undefined,
          ordered_at_to: undefined
        },
        1,
        20,
        undefined,
        'desc',
        'user-123',
        '127.0.0.1',
        mockReq.user
      );
    });
  });

  describe('getPharmacyOrderById', () => {
    it('should call service and send success response', async () => {
      mockReq.params.id = 'order-123';
      const mockPharmacyOrder = { 
        id: 'order-123', 
        patient_id: 'patient-123',
        status: 'ORDERED'
      };
      pharmacyOrderService.getPharmacyOrderById.mockResolvedValue(mockPharmacyOrder);

      await pharmacyOrderController.getPharmacyOrderById(mockReq, mockRes);

      expect(pharmacyOrderService.getPharmacyOrderById).toHaveBeenCalledWith(
        'order-123', 
        'user-123', 
        '127.0.0.1',
        mockReq.user
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes, 
        200, 
        'messages.pharmacy_order.get.success', 
        mockPharmacyOrder
      );
    });
  });

  describe('createPharmacyOrder', () => {
    it('should call service and send success response with 201 status', async () => {
      mockReq.body = {
        patient_id: 'patient-123',
        encounter_id: 'encounter-456',
        status: 'ORDERED',
        ordered_at: '2026-01-19T12:00:00.000Z'
      };
      const mockPharmacyOrder = { 
        id: 'order-789', 
        ...mockReq.body,
        created_at: new Date(),
        updated_at: new Date()
      };
      pharmacyOrderService.createPharmacyOrder.mockResolvedValue(mockPharmacyOrder);

      await pharmacyOrderController.createPharmacyOrder(mockReq, mockRes);

      expect(pharmacyOrderService.createPharmacyOrder).toHaveBeenCalledWith(
        mockReq.body, 
        'user-123', 
        '127.0.0.1',
        mockReq.user
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes, 
        201, 
        'messages.pharmacy_order.create.success', 
        mockPharmacyOrder
      );
    });
  });

  describe('updatePharmacyOrder', () => {
    it('should call service and send success response', async () => {
      mockReq.params.id = 'order-123';
      mockReq.body = { status: 'DISPENSED' };
      const mockPharmacyOrder = { 
        id: 'order-123', 
        patient_id: 'patient-123',
        status: 'DISPENSED',
        updated_at: new Date()
      };
      pharmacyOrderService.updatePharmacyOrder.mockResolvedValue(mockPharmacyOrder);

      await pharmacyOrderController.updatePharmacyOrder(mockReq, mockRes);

      expect(pharmacyOrderService.updatePharmacyOrder).toHaveBeenCalledWith(
        'order-123', 
        mockReq.body, 
        'user-123', 
        '127.0.0.1',
        mockReq.user
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes, 
        200, 
        'messages.pharmacy_order.update.success', 
        mockPharmacyOrder
      );
    });

    it('should handle partial updates', async () => {
      mockReq.params.id = 'order-123';
      mockReq.body = { encounter_id: 'encounter-999' };
      const mockPharmacyOrder = { 
        id: 'order-123',
        encounter_id: 'encounter-999',
        patient_id: 'patient-123',
        status: 'ORDERED'
      };
      pharmacyOrderService.updatePharmacyOrder.mockResolvedValue(mockPharmacyOrder);

      await pharmacyOrderController.updatePharmacyOrder(mockReq, mockRes);

      expect(pharmacyOrderService.updatePharmacyOrder).toHaveBeenCalledWith(
        'order-123',
        { encounter_id: 'encounter-999' },
        'user-123',
        '127.0.0.1',
        mockReq.user
      );
    });
  });

  describe('deletePharmacyOrder', () => {
    it('should call service and send no content response', async () => {
      mockReq.params.id = 'order-123';
      pharmacyOrderService.deletePharmacyOrder.mockResolvedValue();

      await pharmacyOrderController.deletePharmacyOrder(mockReq, mockRes);

      expect(pharmacyOrderService.deletePharmacyOrder).toHaveBeenCalledWith(
        'order-123', 
        'user-123', 
        '127.0.0.1',
        mockReq.user
      );
      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
