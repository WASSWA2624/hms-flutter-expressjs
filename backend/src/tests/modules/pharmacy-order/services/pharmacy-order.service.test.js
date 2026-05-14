/**
 * Pharmacy order service tests
 *
 * @module tests/modules/pharmacy-order/services
 * @description Tests for pharmacy order service business logic
 * Per testing.mdc: Service tests must mock repository and audit functions
 */

const pharmacyOrderService = require('@services/pharmacy-order/pharmacy-order.service');
const pharmacyOrderRepository = require('@repositories/pharmacy-order/pharmacy-order.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
} = require('@services/pharmacy-workspace/pharmacy.shared');

// Mock dependencies
jest.mock('@repositories/pharmacy-order/pharmacy-order.repository');
jest.mock('@lib/audit');
jest.mock('@services/pharmacy-workspace/pharmacy.shared', () => {
  const actual = jest.requireActual('@services/pharmacy-workspace/pharmacy.shared');
  return {
    ...actual,
    resolveModelIdOrThrow: jest.fn(),
    resolveModelRecordOrThrow: jest.fn(),
  };
});

const mockUser = {
  id: 'user-123',
  tenant_id: 'tenant-123',
  facility_id: 'facility-123',
  roles: ['PHARMACIST'],
};

const buildScopedOrder = (overrides = {}) => ({
  id: '123',
  patient_id: 'patient-123',
  status: 'ORDERED',
  patient: {
    tenant_id: 'tenant-123',
    facility_id: 'facility-123',
  },
  ...overrides,
});

describe('Pharmacy Order Service', () => {
  const mockUserId = 'user-123';
  const mockIpAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockReturnValue(Promise.resolve());
    resolveModelIdOrThrow.mockReset();
    resolveModelRecordOrThrow.mockReset();
  });

  describe('listPharmacyOrders', () => {
    it('should list pharmacy orders with pagination', async () => {
      const mockPharmacyOrders = [
        { 
          id: 'order-1', 
          patient_id: 'patient-123', 
          status: 'ORDERED',
          ordered_at: new Date('2026-01-19T12:00:00.000Z')
        }
      ];
      pharmacyOrderRepository.findMany.mockResolvedValue(mockPharmacyOrders);
      pharmacyOrderRepository.count.mockResolvedValue(1);

      const result = await pharmacyOrderService.listPharmacyOrders(
        {}, 
        1, 
        20, 
        'ordered_at', 
        'desc', 
        mockUserId, 
        mockIpAddress,
        mockUser
      );

      expect(result.pharmacyOrders).toEqual(mockPharmacyOrders);
      expect(result.pagination.total).toBe(1);
      expect(result.pagination.page).toBe(1);
      expect(result.pagination.limit).toBe(20);
      expect(pharmacyOrderRepository.findMany).toHaveBeenCalled();
      expect(pharmacyOrderRepository.count).toHaveBeenCalled();
    });

    it('should handle patient_id filter', async () => {
      pharmacyOrderRepository.findMany.mockResolvedValue([]);
      pharmacyOrderRepository.count.mockResolvedValue(0);

      resolveModelIdOrThrow.mockResolvedValue('patient-123');

      await pharmacyOrderService.listPharmacyOrders(
        { patient_id: 'patient-123' }, 
        1, 
        20, 
        null, 
        'asc', 
        mockUserId, 
        mockIpAddress,
        mockUser
      );

      expect(pharmacyOrderRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ patient_id: 'patient-123' }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should handle encounter_id filter', async () => {
      pharmacyOrderRepository.findMany.mockResolvedValue([]);
      pharmacyOrderRepository.count.mockResolvedValue(0);

      resolveModelIdOrThrow.mockResolvedValue('encounter-123');

      await pharmacyOrderService.listPharmacyOrders(
        { encounter_id: 'encounter-123' }, 
        1, 
        20, 
        null, 
        'asc', 
        mockUserId, 
        mockIpAddress,
        mockUser
      );

      expect(pharmacyOrderRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ encounter_id: 'encounter-123' }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should handle status filter', async () => {
      pharmacyOrderRepository.findMany.mockResolvedValue([]);
      pharmacyOrderRepository.count.mockResolvedValue(0);

      await pharmacyOrderService.listPharmacyOrders(
        { status: 'DISPENSED' }, 
        1, 
        20, 
        null, 
        'asc', 
        mockUserId, 
        mockIpAddress,
        mockUser
      );

      expect(pharmacyOrderRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ status: 'DISPENSED' }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should handle date range filters', async () => {
      pharmacyOrderRepository.findMany.mockResolvedValue([]);
      pharmacyOrderRepository.count.mockResolvedValue(0);

      await pharmacyOrderService.listPharmacyOrders(
        { 
          ordered_at_from: '2026-01-01T00:00:00.000Z',
          ordered_at_to: '2026-12-31T23:59:59.999Z'
        }, 
        1, 
        20, 
        null, 
        'asc', 
        mockUserId, 
        mockIpAddress,
        mockUser
      );

      expect(pharmacyOrderRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          ordered_at: expect.objectContaining({
            gte: expect.any(Date),
            lte: expect.any(Date)
          })
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should calculate pagination correctly', async () => {
      pharmacyOrderRepository.findMany.mockResolvedValue([]);
      pharmacyOrderRepository.count.mockResolvedValue(45);

      const result = await pharmacyOrderService.listPharmacyOrders(
        {}, 
        2, 
        20, 
        null, 
        'desc', 
        mockUserId, 
        mockIpAddress,
        mockUser
      );

      expect(result.pagination.totalPages).toBe(3);
      expect(result.pagination.hasNextPage).toBe(true);
      expect(result.pagination.hasPreviousPage).toBe(true);
    });
  });

  describe('getPharmacyOrderById', () => {
    it('should get pharmacy order by friendly id', async () => {
      const mockPharmacyOrder = buildScopedOrder();
      resolveModelRecordOrThrow.mockResolvedValue(mockPharmacyOrder);

      const result = await pharmacyOrderService.getPharmacyOrderById(
        'PHO-B1DEB9CE0C',
        mockUserId, 
        mockIpAddress,
        mockUser
      );

      expect(result).toEqual(mockPharmacyOrder);
      expect(resolveModelRecordOrThrow).toHaveBeenCalledWith(
        expect.objectContaining({
          identifier: 'PHO-B1DEB9CE0C',
          model: 'pharmacy_order',
          errorKey: 'errors.pharmacy_order.not_found',
        })
      );
    });

    it('should throw HttpError if pharmacy order not found', async () => {
      resolveModelRecordOrThrow.mockRejectedValue(
        new HttpError('errors.pharmacy_order.not_found', 404)
      );

      await expect(
        pharmacyOrderService.getPharmacyOrderById('nonexistent', mockUserId, mockIpAddress, mockUser)
      ).rejects.toThrow(HttpError);
    });

    it('should reject out-of-scope pharmacy orders', async () => {
      resolveModelRecordOrThrow.mockResolvedValue(
        buildScopedOrder({
          patient: {
            tenant_id: 'tenant-other',
            facility_id: 'facility-other',
          },
        })
      );

      await expect(
        pharmacyOrderService.getPharmacyOrderById('123', mockUserId, mockIpAddress, mockUser)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createPharmacyOrder', () => {
    it('should create pharmacy order and log audit', async () => {
      const mockData = { 
        patient_id: 'patient-123',
        encounter_id: 'encounter-123',
        status: 'ORDERED'
      };
      const mockPharmacyOrder = { 
        id: 'order-456', 
        ...mockData,
        ordered_at: new Date(),
        created_at: new Date(),
        updated_at: new Date()
      };
      resolveModelIdOrThrow
        .mockResolvedValueOnce('patient-123')
        .mockResolvedValueOnce('encounter-123');
      pharmacyOrderRepository.create.mockResolvedValue(mockPharmacyOrder);

      const result = await pharmacyOrderService.createPharmacyOrder(
        mockData, 
        mockUserId, 
        mockIpAddress,
        mockUser
      );

      expect(result).toEqual(mockPharmacyOrder);
      expect(pharmacyOrderRepository.create).toHaveBeenCalledWith({
        ...mockData,
        patient_id: 'patient-123',
        encounter_id: 'encounter-123',
      });
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        tenant_id: 'tenant-123',
        user_id: mockUserId,
        action: 'CREATE',
        entity: 'pharmacy_order',
        entity_id: 'order-456',
        ip_address: mockIpAddress
      }));
    });

    it('should handle repository errors', async () => {
      const mockData = { patient_id: 'patient-123', status: 'ORDERED' };
      resolveModelIdOrThrow.mockResolvedValue('patient-123');
      pharmacyOrderRepository.create.mockRejectedValue(new Error('DB error'));

      await expect(
        pharmacyOrderService.createPharmacyOrder(mockData, mockUserId, mockIpAddress, mockUser)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('updatePharmacyOrder', () => {
    it('should update pharmacy order and log audit', async () => {
      const mockBefore = buildScopedOrder({ id: 'order-uuid-123' });
      const mockAfter = { 
        id: 'order-uuid-123',
        patient_id: 'patient-123',
        status: 'DISPENSED'
      };
      resolveModelRecordOrThrow.mockResolvedValue(mockBefore);
      pharmacyOrderRepository.update.mockResolvedValue(mockAfter);

      const result = await pharmacyOrderService.updatePharmacyOrder(
        'PHO-B1DEB9CE0C',
        { status: 'DISPENSED' }, 
        mockUserId, 
        mockIpAddress,
        mockUser
      );

      expect(result).toEqual(mockAfter);
      expect(resolveModelRecordOrThrow).toHaveBeenCalled();
      expect(pharmacyOrderRepository.update).toHaveBeenCalledWith('order-uuid-123', {
        status: 'DISPENSED',
      });
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        tenant_id: 'tenant-123',
        user_id: mockUserId,
        action: 'UPDATE',
        entity: 'pharmacy_order',
        entity_id: 'order-uuid-123',
        diff: { before: mockBefore, after: mockAfter },
        ip_address: mockIpAddress
      }));
    });

    it('should throw HttpError if pharmacy order not found before update', async () => {
      resolveModelRecordOrThrow.mockRejectedValue(
        new HttpError('errors.pharmacy_order.not_found', 404)
      );

      await expect(
        pharmacyOrderService.updatePharmacyOrder('nonexistent', {}, mockUserId, mockIpAddress, mockUser)
      ).rejects.toThrow(HttpError);
    });

    it('should handle repository errors', async () => {
      const mockBefore = buildScopedOrder();
      resolveModelRecordOrThrow.mockResolvedValue(mockBefore);
      pharmacyOrderRepository.update.mockRejectedValue(new Error('DB error'));

      await expect(
        pharmacyOrderService.updatePharmacyOrder(
          '123',
          { status: 'DISPENSED' },
          mockUserId,
          mockIpAddress,
          mockUser
        )
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deletePharmacyOrder', () => {
    it('should soft delete pharmacy order and log audit', async () => {
      const mockPharmacyOrder = buildScopedOrder({ id: 'order-uuid-123' });
      resolveModelRecordOrThrow.mockResolvedValue(mockPharmacyOrder);
      pharmacyOrderRepository.softDelete.mockResolvedValue({ 
        ...mockPharmacyOrder, 
        deleted_at: new Date() 
      });

      await pharmacyOrderService.deletePharmacyOrder(
        'PHO-B1DEB9CE0C',
        mockUserId,
        mockIpAddress,
        mockUser
      );

      expect(resolveModelRecordOrThrow).toHaveBeenCalled();
      expect(pharmacyOrderRepository.softDelete).toHaveBeenCalledWith('order-uuid-123');
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        tenant_id: 'tenant-123',
        user_id: mockUserId,
        action: 'DELETE',
        entity: 'pharmacy_order',
        entity_id: 'order-uuid-123',
        ip_address: mockIpAddress
      }));
    });

    it('should throw HttpError if pharmacy order not found', async () => {
      resolveModelRecordOrThrow.mockRejectedValue(
        new HttpError('errors.pharmacy_order.not_found', 404)
      );

      await expect(
        pharmacyOrderService.deletePharmacyOrder('nonexistent', mockUserId, mockIpAddress, mockUser)
      ).rejects.toThrow(HttpError);
    });

    it('should handle repository errors', async () => {
      const mockPharmacyOrder = buildScopedOrder();
      resolveModelRecordOrThrow.mockResolvedValue(mockPharmacyOrder);
      pharmacyOrderRepository.softDelete.mockRejectedValue(new Error('DB error'));

      await expect(
        pharmacyOrderService.deletePharmacyOrder('123', mockUserId, mockIpAddress, mockUser)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('dispensePharmacyOrder', () => {
    it('should resolve friendly ids before updating dispense status', async () => {
      const mockBefore = buildScopedOrder({ id: 'order-uuid-123' });
      const mockAfter = {
        id: 'order-uuid-123',
        patient_id: 'patient-123',
        status: 'DISPENSED',
      };
      resolveModelRecordOrThrow.mockResolvedValue(mockBefore);
      pharmacyOrderRepository.update.mockResolvedValue(mockAfter);

      const result = await pharmacyOrderService.dispensePharmacyOrder(
        'PHO-B1DEB9CE0C',
        {},
        mockUserId,
        mockIpAddress,
        mockUser
      );

      expect(result).toEqual(mockAfter);
      expect(pharmacyOrderRepository.update).toHaveBeenCalledWith('order-uuid-123', {
        status: 'DISPENSED',
      });
    });
  });
});
