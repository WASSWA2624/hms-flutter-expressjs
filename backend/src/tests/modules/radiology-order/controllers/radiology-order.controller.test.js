/**
 * Radiology Order controller tests
 *
 * @module tests/modules/radiology-order/controllers
 * @description Tests for radiology order controller
 * Per testing.mdc: Mock service, test HTTP handling
 */

const radiologyOrderController = require('@controllers/radiology-order/radiology-order.controller');
const radiologyOrderService = require('@services/radiology-order/radiology-order.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

// Mock dependencies
jest.mock('@services/radiology-order/radiology-order.service');
jest.mock('@lib/response');

describe('Radiology Order Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'requester-id' },
      ip: '127.0.0.1'
    };

    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
  });

  describe('listRadiologyOrders', () => {
    const mockResult = {
      radiology_orders: [
        { 
          id: '550e8400-e29b-41d4-a716-446655440000', 
          patient_id: '550e8400-e29b-41d4-a716-446655440001',
          status: 'ORDERED' 
        },
        { 
          id: '550e8400-e29b-41d4-a716-446655440002', 
          patient_id: '550e8400-e29b-41d4-a716-446655440003',
          status: 'IN_PROCESS' 
        }
      ],
      pagination: {
        page: 1,
        limit: 20,
        total: 2,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      }
    };

    it('should list radiology orders with default pagination', async () => {
      radiologyOrderService.listRadiologyOrders.mockResolvedValue(mockResult);

      await radiologyOrderController.listRadiologyOrders(req, res);

      expect(radiologyOrderService.listRadiologyOrders).toHaveBeenCalledWith(
        expect.any(Object),
        DEFAULT_PAGE,
        DEFAULT_PAGE_LIMIT,
        undefined,
        'asc',
        'requester-id',
        '127.0.0.1'
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.radiology_order.list.success',
        mockResult.radiology_orders,
        mockResult.pagination
      );
    });

    it('should apply filters from query params', async () => {
      req.query = {
        encounter_id: '550e8400-e29b-41d4-a716-446655440000',
        patient_id: '550e8400-e29b-41d4-a716-446655440001',
        radiology_test_id: '550e8400-e29b-41d4-a716-446655440002',
        status: 'ORDERED',
        search: 'CT scan',
        page: '2',
        limit: '10',
        sort_by: 'ordered_at',
        order: 'desc'
      };
      radiologyOrderService.listRadiologyOrders.mockResolvedValue(mockResult);

      await radiologyOrderController.listRadiologyOrders(req, res);

      expect(radiologyOrderService.listRadiologyOrders).toHaveBeenCalledWith(
        {
          encounter_id: '550e8400-e29b-41d4-a716-446655440000',
          patient_id: '550e8400-e29b-41d4-a716-446655440001',
          radiology_test_id: '550e8400-e29b-41d4-a716-446655440002',
          status: 'ORDERED',
          search: 'CT scan'
        },
        2,
        10,
        'ordered_at',
        'desc',
        'requester-id',
        '127.0.0.1'
      );
    });

    it('should handle missing user in request', async () => {
      req.user = undefined;
      radiologyOrderService.listRadiologyOrders.mockResolvedValue(mockResult);

      await radiologyOrderController.listRadiologyOrders(req, res);

      expect(radiologyOrderService.listRadiologyOrders).toHaveBeenCalledWith(
        expect.any(Object),
        expect.any(Number),
        expect.any(Number),
        undefined,
        'asc',
        undefined,
        '127.0.0.1'
      );
    });

    it('should parse pagination params as integers', async () => {
      req.query = { page: '3', limit: '50' };
      radiologyOrderService.listRadiologyOrders.mockResolvedValue(mockResult);

      await radiologyOrderController.listRadiologyOrders(req, res);

      expect(radiologyOrderService.listRadiologyOrders).toHaveBeenCalledWith(
        expect.any(Object),
        3,
        50,
        undefined,
        'asc',
        'requester-id',
        '127.0.0.1'
      );
    });
  });

  describe('getRadiologyOrderById', () => {
    const radiologyOrderId = '550e8400-e29b-41d4-a716-446655440000';
    const mockRadiologyOrder = {
      id: radiologyOrderId,
      patient_id: '550e8400-e29b-41d4-a716-446655440001',
      status: 'ORDERED',
      ordered_at: new Date('2026-01-19T09:00:00.000Z')
    };

    it('should get radiology order by ID', async () => {
      req.params = { id: radiologyOrderId };
      radiologyOrderService.getRadiologyOrderById.mockResolvedValue(mockRadiologyOrder);

      await radiologyOrderController.getRadiologyOrderById(req, res);

      expect(radiologyOrderService.getRadiologyOrderById).toHaveBeenCalledWith(
        radiologyOrderId,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.radiology_order.get.success',
        mockRadiologyOrder
      );
    });

    it('should handle missing user in request', async () => {
      req.params = { id: radiologyOrderId };
      req.user = undefined;
      radiologyOrderService.getRadiologyOrderById.mockResolvedValue(mockRadiologyOrder);

      await radiologyOrderController.getRadiologyOrderById(req, res);

      expect(radiologyOrderService.getRadiologyOrderById).toHaveBeenCalledWith(
        radiologyOrderId,
        undefined,
        '127.0.0.1'
      );
    });
  });

  describe('createRadiologyOrder', () => {
    const createData = {
      patient_id: '550e8400-e29b-41d4-a716-446655440000',
      radiology_test_id: '550e8400-e29b-41d4-a716-446655440001',
      status: 'ORDERED',
      ordered_at: '2026-01-19T09:00:00.000Z'
    };

    const mockCreatedRadiologyOrder = {
      id: '550e8400-e29b-41d4-a716-446655440002',
      ...createData,
      created_at: new Date(),
      updated_at: new Date()
    };

    it('should create radiology order', async () => {
      req.body = createData;
      radiologyOrderService.createRadiologyOrder.mockResolvedValue(mockCreatedRadiologyOrder);

      await radiologyOrderController.createRadiologyOrder(req, res);

      expect(radiologyOrderService.createRadiologyOrder).toHaveBeenCalledWith(
        createData,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.radiology_order.create.success',
        mockCreatedRadiologyOrder
      );
    });

    it('should handle missing user in request', async () => {
      req.body = createData;
      req.user = undefined;
      radiologyOrderService.createRadiologyOrder.mockResolvedValue(mockCreatedRadiologyOrder);

      await radiologyOrderController.createRadiologyOrder(req, res);

      expect(radiologyOrderService.createRadiologyOrder).toHaveBeenCalledWith(
        createData,
        undefined,
        '127.0.0.1'
      );
    });
  });

  describe('updateRadiologyOrder', () => {
    const radiologyOrderId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = {
      status: 'COMPLETED'
    };

    const mockUpdatedRadiologyOrder = {
      id: radiologyOrderId,
      patient_id: '550e8400-e29b-41d4-a716-446655440001',
      status: 'COMPLETED',
      ordered_at: new Date('2026-01-19T09:00:00.000Z')
    };

    it('should update radiology order', async () => {
      req.params = { id: radiologyOrderId };
      req.body = updateData;
      radiologyOrderService.updateRadiologyOrder.mockResolvedValue(mockUpdatedRadiologyOrder);

      await radiologyOrderController.updateRadiologyOrder(req, res);

      expect(radiologyOrderService.updateRadiologyOrder).toHaveBeenCalledWith(
        radiologyOrderId,
        updateData,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.radiology_order.update.success',
        mockUpdatedRadiologyOrder
      );
    });

    it('should handle missing user in request', async () => {
      req.params = { id: radiologyOrderId };
      req.body = updateData;
      req.user = undefined;
      radiologyOrderService.updateRadiologyOrder.mockResolvedValue(mockUpdatedRadiologyOrder);

      await radiologyOrderController.updateRadiologyOrder(req, res);

      expect(radiologyOrderService.updateRadiologyOrder).toHaveBeenCalledWith(
        radiologyOrderId,
        updateData,
        undefined,
        '127.0.0.1'
      );
    });
  });

  describe('deleteRadiologyOrder', () => {
    const radiologyOrderId = '550e8400-e29b-41d4-a716-446655440000';

    it('should delete radiology order', async () => {
      req.params = { id: radiologyOrderId };
      radiologyOrderService.deleteRadiologyOrder.mockResolvedValue();

      await radiologyOrderController.deleteRadiologyOrder(req, res);

      expect(radiologyOrderService.deleteRadiologyOrder).toHaveBeenCalledWith(
        radiologyOrderId,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });

    it('should handle missing user in request', async () => {
      req.params = { id: radiologyOrderId };
      req.user = undefined;
      radiologyOrderService.deleteRadiologyOrder.mockResolvedValue();

      await radiologyOrderController.deleteRadiologyOrder(req, res);

      expect(radiologyOrderService.deleteRadiologyOrder).toHaveBeenCalledWith(
        radiologyOrderId,
        undefined,
        '127.0.0.1'
      );
    });
  });
});
