/**
 * Radiology Order service tests
 *
 * @module tests/modules/radiology-order/services
 * @description Tests for radiology order service
 * Per testing.mdc: Mock repository, test business logic
 */

const radiologyOrderService = require('@services/radiology-order/radiology-order.service');
const radiologyOrderRepository = require('@repositories/radiology-order/radiology-order.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
} = require('@lib/identifiers/service-identifier-resolution');
const {
  normalizeIdentifier,
  resolveModelIdByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');

// Mock dependencies
jest.mock('@repositories/radiology-order/radiology-order.repository');
jest.mock('@lib/audit');
jest.mock('@lib/identifiers/service-identifier-resolution', () => ({
  resolveIdentifierForFilter: jest.fn(),
  resolveIdentifierForPayload: jest.fn(),
}));
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  normalizeIdentifier: jest.fn((value) => value),
  resolveModelIdByIdentifier: jest.fn(),
}));

describe('Radiology Order Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    normalizeIdentifier.mockImplementation((value) => value);
    resolveModelIdByIdentifier.mockResolvedValue(null);
    resolveIdentifierForFilter.mockImplementation(async ({ value }) => value);
    resolveIdentifierForPayload.mockImplementation(async ({ value, nullable = false }) => {
      if (value === undefined) return undefined;
      if ((value === null || value === '') && nullable) return null;
      return value;
    });
  });

  describe('listRadiologyOrders', () => {
    const mockRadiologyOrders = [
      {
        id: '550e8400-e29b-41d4-a716-446655440000',
        encounter_id: '550e8400-e29b-41d4-a716-446655440001',
        patient_id: '550e8400-e29b-41d4-a716-446655440002',
        radiology_test_id: '550e8400-e29b-41d4-a716-446655440003',
        status: 'ORDERED',
        ordered_at: new Date('2026-01-19T09:00:00.000Z')
      },
      {
        id: '550e8400-e29b-41d4-a716-446655440004',
        encounter_id: '550e8400-e29b-41d4-a716-446655440005',
        patient_id: '550e8400-e29b-41d4-a716-446655440006',
        radiology_test_id: '550e8400-e29b-41d4-a716-446655440007',
        status: 'IN_PROCESS',
        ordered_at: new Date('2026-01-19T10:00:00.000Z')
      }
    ];

    it('should list radiology orders with pagination', async () => {
      radiologyOrderRepository.findMany.mockResolvedValue(mockRadiologyOrders);
      radiologyOrderRepository.count.mockResolvedValue(2);

      const result = await radiologyOrderService.listRadiologyOrders({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(result).toHaveProperty('radiology_orders', mockRadiologyOrders);
      expect(result).toHaveProperty('pagination');
      expect(result.pagination).toMatchObject({
        page: 1,
        limit: 20,
        total: 2,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
    });

    it('should apply filters correctly', async () => {
      const filters = {
        encounter_id: '550e8400-e29b-41d4-a716-446655440001',
        patient_id: '550e8400-e29b-41d4-a716-446655440002',
        status: 'ORDERED'
      };
      radiologyOrderRepository.findMany.mockResolvedValue(mockRadiologyOrders);
      radiologyOrderRepository.count.mockResolvedValue(2);

      await radiologyOrderService.listRadiologyOrders(filters, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(radiologyOrderRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          encounter_id: filters.encounter_id,
          patient_id: filters.patient_id,
          status: filters.status
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should calculate pagination correctly', async () => {
      radiologyOrderRepository.findMany.mockResolvedValue(mockRadiologyOrders);
      radiologyOrderRepository.count.mockResolvedValue(42);

      const result = await radiologyOrderService.listRadiologyOrders({}, 2, 10, null, 'asc', 'user-id', '127.0.0.1');

      expect(result.pagination).toMatchObject({
        page: 2,
        limit: 10,
        total: 42,
        totalPages: 5,
        hasNextPage: true,
        hasPreviousPage: true
      });
      expect(radiologyOrderRepository.findMany).toHaveBeenCalledWith(
        expect.any(Object),
        10, // skip: (2-1) * 10
        10,
        expect.any(Object)
      );
    });

    it('should apply custom sorting', async () => {
      radiologyOrderRepository.findMany.mockResolvedValue(mockRadiologyOrders);
      radiologyOrderRepository.count.mockResolvedValue(2);

      await radiologyOrderService.listRadiologyOrders({}, 1, 20, 'ordered_at', 'asc', 'user-id', '127.0.0.1');

      expect(radiologyOrderRepository.findMany).toHaveBeenCalledWith(
        expect.any(Object),
        expect.any(Number),
        expect.any(Number),
        { ordered_at: 'asc' }
      );
    });

    it('should use default sorting when sortBy not provided', async () => {
      radiologyOrderRepository.findMany.mockResolvedValue(mockRadiologyOrders);
      radiologyOrderRepository.count.mockResolvedValue(2);

      await radiologyOrderService.listRadiologyOrders({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(radiologyOrderRepository.findMany).toHaveBeenCalledWith(
        expect.any(Object),
        expect.any(Number),
        expect.any(Number),
        { created_at: 'desc' }
      );
    });

    it('should handle repository errors', async () => {
      radiologyOrderRepository.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(
        radiologyOrderService.listRadiologyOrders({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });

    it('should propagate HttpError from repository', async () => {
      const httpError = new HttpError('errors.database.unexpected', 500);
      radiologyOrderRepository.findMany.mockRejectedValue(httpError);

      await expect(
        radiologyOrderService.listRadiologyOrders({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1')
      ).rejects.toThrow(httpError);
    });
  });

  describe('getRadiologyOrderById', () => {
    const radiologyOrderId = '550e8400-e29b-41d4-a716-446655440000';
    const mockRadiologyOrder = {
      id: radiologyOrderId,
      encounter_id: '550e8400-e29b-41d4-a716-446655440001',
      patient_id: '550e8400-e29b-41d4-a716-446655440002',
      radiology_test_id: '550e8400-e29b-41d4-a716-446655440003',
      status: 'ORDERED',
      ordered_at: new Date('2026-01-19T09:00:00.000Z')
    };

    it('should get radiology order by ID', async () => {
      radiologyOrderRepository.findById.mockResolvedValue(mockRadiologyOrder);

      const result = await radiologyOrderService.getRadiologyOrderById(radiologyOrderId, 'user-id', '127.0.0.1');

      expect(result).toEqual(mockRadiologyOrder);
      expect(radiologyOrderRepository.findById).toHaveBeenCalledWith(radiologyOrderId);
    });

    it('should throw HttpError if radiology order not found', async () => {
      radiologyOrderRepository.findById.mockResolvedValue(null);

      await expect(
        radiologyOrderService.getRadiologyOrderById(radiologyOrderId, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
      await expect(
        radiologyOrderService.getRadiologyOrderById(radiologyOrderId, 'user-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.radiology_order.not_found',
        statusCode: 404
      });
    });

    it('should handle repository errors', async () => {
      radiologyOrderRepository.findById.mockRejectedValue(new Error('DB Error'));

      await expect(
        radiologyOrderService.getRadiologyOrderById(radiologyOrderId, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });

    it('should propagate HttpError from repository', async () => {
      const httpError = new HttpError('errors.database.unexpected', 500);
      radiologyOrderRepository.findById.mockRejectedValue(httpError);

      await expect(
        radiologyOrderService.getRadiologyOrderById(radiologyOrderId, 'user-id', '127.0.0.1')
      ).rejects.toThrow(httpError);
    });
  });

  describe('createRadiologyOrder', () => {
    const createData = {
      encounter_id: '550e8400-e29b-41d4-a716-446655440001',
      patient_id: '550e8400-e29b-41d4-a716-446655440002',
      radiology_test_id: '550e8400-e29b-41d4-a716-446655440003',
      status: 'ORDERED',
      ordered_at: new Date('2026-01-19T09:00:00.000Z')
    };

    const mockCreatedRadiologyOrder = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      ...createData,
      created_at: new Date(),
      updated_at: new Date(),
      deleted_at: null,
      version: 1
    };

    it('should create radiology order', async () => {
      radiologyOrderRepository.create.mockResolvedValue(mockCreatedRadiologyOrder);
      createAuditLog.mockResolvedValue({});

      const result = await radiologyOrderService.createRadiologyOrder(createData, 'user-id', '127.0.0.1');

      expect(result).toEqual(mockCreatedRadiologyOrder);
      expect(radiologyOrderRepository.create).toHaveBeenCalledWith(
        expect.objectContaining(createData)
      );
    });

    it('defaults status and ordered timestamp when omitted', async () => {
      radiologyOrderRepository.create.mockImplementation(async (payload) => ({
        id: '550e8400-e29b-41d4-a716-446655440099',
        ...payload,
      }));

      const result = await radiologyOrderService.createRadiologyOrder(
        {
          patient_id: '550e8400-e29b-41d4-a716-446655440002',
          radiology_test_id: '550e8400-e29b-41d4-a716-446655440003',
        },
        'user-id',
        '127.0.0.1'
      );

      expect(radiologyOrderRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({
          patient_id: '550e8400-e29b-41d4-a716-446655440002',
          radiology_test_id: '550e8400-e29b-41d4-a716-446655440003',
          status: 'ORDERED',
          ordered_at: expect.any(Date),
        })
      );
      expect(result.status).toBe('ORDERED');
      expect(result.ordered_at).toBeInstanceOf(Date);
    });

    it('should create audit log on creation', async () => {
      radiologyOrderRepository.create.mockResolvedValue(mockCreatedRadiologyOrder);
      createAuditLog.mockResolvedValue({});

      await radiologyOrderService.createRadiologyOrder(createData, 'user-id', '127.0.0.1');

      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-id',
        action: 'CREATE',
        entity: 'radiology_order',
        entity_id: mockCreatedRadiologyOrder.id,
        diff: { after: mockCreatedRadiologyOrder },
        ip_address: '127.0.0.1'
      });
    });

    it('should handle repository errors', async () => {
      radiologyOrderRepository.create.mockRejectedValue(new Error('DB Error'));

      await expect(
        radiologyOrderService.createRadiologyOrder(createData, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });

    it('should propagate HttpError from repository', async () => {
      const httpError = new HttpError('errors.database.foreign_key_field', 400);
      radiologyOrderRepository.create.mockRejectedValue(httpError);

      await expect(
        radiologyOrderService.createRadiologyOrder(createData, 'user-id', '127.0.0.1')
      ).rejects.toThrow(httpError);
    });

    it('should not fail if audit log creation fails', async () => {
      radiologyOrderRepository.create.mockResolvedValue(mockCreatedRadiologyOrder);
      createAuditLog.mockRejectedValue(new Error('Audit log failed'));

      const result = await radiologyOrderService.createRadiologyOrder(createData, 'user-id', '127.0.0.1');

      expect(result).toEqual(mockCreatedRadiologyOrder);
    });
  });

  describe('updateRadiologyOrder', () => {
    const radiologyOrderId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = {
      status: 'COMPLETED'
    };

    const mockBeforeRadiologyOrder = {
      id: radiologyOrderId,
      encounter_id: '550e8400-e29b-41d4-a716-446655440001',
      patient_id: '550e8400-e29b-41d4-a716-446655440002',
      radiology_test_id: '550e8400-e29b-41d4-a716-446655440003',
      status: 'IN_PROCESS',
      ordered_at: new Date('2026-01-19T09:00:00.000Z')
    };

    const mockUpdatedRadiologyOrder = {
      ...mockBeforeRadiologyOrder,
      status: 'COMPLETED',
      updated_at: new Date()
    };

    it('should update radiology order', async () => {
      radiologyOrderRepository.findById.mockResolvedValue(mockBeforeRadiologyOrder);
      radiologyOrderRepository.update.mockResolvedValue(mockUpdatedRadiologyOrder);
      createAuditLog.mockResolvedValue({});

      const result = await radiologyOrderService.updateRadiologyOrder(radiologyOrderId, updateData, 'user-id', '127.0.0.1');

      expect(result).toEqual(mockUpdatedRadiologyOrder);
      expect(radiologyOrderRepository.findById).toHaveBeenCalledWith(radiologyOrderId);
      expect(radiologyOrderRepository.update).toHaveBeenCalledWith(radiologyOrderId, updateData);
    });

    it('should throw HttpError if radiology order not found', async () => {
      radiologyOrderRepository.findById.mockResolvedValue(null);

      await expect(
        radiologyOrderService.updateRadiologyOrder(radiologyOrderId, updateData, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
      await expect(
        radiologyOrderService.updateRadiologyOrder(radiologyOrderId, updateData, 'user-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.radiology_order.not_found',
        statusCode: 404
      });
    });

    it('should create audit log on update', async () => {
      radiologyOrderRepository.findById.mockResolvedValue(mockBeforeRadiologyOrder);
      radiologyOrderRepository.update.mockResolvedValue(mockUpdatedRadiologyOrder);
      createAuditLog.mockResolvedValue({});

      await radiologyOrderService.updateRadiologyOrder(radiologyOrderId, updateData, 'user-id', '127.0.0.1');

      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-id',
        action: 'UPDATE',
        entity: 'radiology_order',
        entity_id: mockUpdatedRadiologyOrder.id,
        diff: { before: mockBeforeRadiologyOrder, after: mockUpdatedRadiologyOrder },
        ip_address: '127.0.0.1'
      });
    });

    it('should handle repository errors', async () => {
      radiologyOrderRepository.findById.mockResolvedValue(mockBeforeRadiologyOrder);
      radiologyOrderRepository.update.mockRejectedValue(new Error('DB Error'));

      await expect(
        radiologyOrderService.updateRadiologyOrder(radiologyOrderId, updateData, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });

    it('should propagate HttpError from repository', async () => {
      radiologyOrderRepository.findById.mockResolvedValue(mockBeforeRadiologyOrder);
      const httpError = new HttpError('errors.database.unexpected', 500);
      radiologyOrderRepository.update.mockRejectedValue(httpError);

      await expect(
        radiologyOrderService.updateRadiologyOrder(radiologyOrderId, updateData, 'user-id', '127.0.0.1')
      ).rejects.toThrow(httpError);
    });

    it('should not fail if audit log creation fails', async () => {
      radiologyOrderRepository.findById.mockResolvedValue(mockBeforeRadiologyOrder);
      radiologyOrderRepository.update.mockResolvedValue(mockUpdatedRadiologyOrder);
      createAuditLog.mockRejectedValue(new Error('Audit log failed'));

      const result = await radiologyOrderService.updateRadiologyOrder(radiologyOrderId, updateData, 'user-id', '127.0.0.1');

      expect(result).toEqual(mockUpdatedRadiologyOrder);
    });
  });

  describe('deleteRadiologyOrder', () => {
    const radiologyOrderId = '550e8400-e29b-41d4-a716-446655440000';
    const mockRadiologyOrder = {
      id: radiologyOrderId,
      encounter_id: '550e8400-e29b-41d4-a716-446655440001',
      patient_id: '550e8400-e29b-41d4-a716-446655440002',
      radiology_test_id: '550e8400-e29b-41d4-a716-446655440003',
      status: 'ORDERED',
      ordered_at: new Date('2026-01-19T09:00:00.000Z')
    };

    it('should delete radiology order', async () => {
      radiologyOrderRepository.findById.mockResolvedValue(mockRadiologyOrder);
      radiologyOrderRepository.softDelete.mockResolvedValue({});
      createAuditLog.mockResolvedValue({});

      await radiologyOrderService.deleteRadiologyOrder(radiologyOrderId, 'user-id', '127.0.0.1');

      expect(radiologyOrderRepository.findById).toHaveBeenCalledWith(radiologyOrderId);
      expect(radiologyOrderRepository.softDelete).toHaveBeenCalledWith(radiologyOrderId);
    });

    it('should throw HttpError if radiology order not found', async () => {
      radiologyOrderRepository.findById.mockResolvedValue(null);

      await expect(
        radiologyOrderService.deleteRadiologyOrder(radiologyOrderId, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
      await expect(
        radiologyOrderService.deleteRadiologyOrder(radiologyOrderId, 'user-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.radiology_order.not_found',
        statusCode: 404
      });
    });

    it('should create audit log on deletion', async () => {
      radiologyOrderRepository.findById.mockResolvedValue(mockRadiologyOrder);
      radiologyOrderRepository.softDelete.mockResolvedValue({});
      createAuditLog.mockResolvedValue({});

      await radiologyOrderService.deleteRadiologyOrder(radiologyOrderId, 'user-id', '127.0.0.1');

      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-id',
        action: 'DELETE',
        entity: 'radiology_order',
        entity_id: radiologyOrderId,
        diff: { before: mockRadiologyOrder },
        ip_address: '127.0.0.1'
      });
    });

    it('should handle repository errors', async () => {
      radiologyOrderRepository.findById.mockResolvedValue(mockRadiologyOrder);
      radiologyOrderRepository.softDelete.mockRejectedValue(new Error('DB Error'));

      await expect(
        radiologyOrderService.deleteRadiologyOrder(radiologyOrderId, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });

    it('should propagate HttpError from repository', async () => {
      radiologyOrderRepository.findById.mockResolvedValue(mockRadiologyOrder);
      const httpError = new HttpError('errors.database.unexpected', 500);
      radiologyOrderRepository.softDelete.mockRejectedValue(httpError);

      await expect(
        radiologyOrderService.deleteRadiologyOrder(radiologyOrderId, 'user-id', '127.0.0.1')
      ).rejects.toThrow(httpError);
    });

    it('should not fail if audit log creation fails', async () => {
      radiologyOrderRepository.findById.mockResolvedValue(mockRadiologyOrder);
      radiologyOrderRepository.softDelete.mockResolvedValue({});
      createAuditLog.mockRejectedValue(new Error('Audit log failed'));

      await expect(
        radiologyOrderService.deleteRadiologyOrder(radiologyOrderId, 'user-id', '127.0.0.1')
      ).resolves.not.toThrow();
    });
  });
});
