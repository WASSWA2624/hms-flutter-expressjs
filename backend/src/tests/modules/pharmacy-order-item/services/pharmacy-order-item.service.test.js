/**
 * Pharmacy order item service tests
 */

const pharmacyOrderItemService = require('@services/pharmacy-order-item/pharmacy-order-item.service');
const pharmacyOrderItemRepository = require('@repositories/pharmacy-order-item/pharmacy-order-item.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { resolveModelIdOrThrow } = require('@services/pharmacy-workspace/pharmacy.shared');

jest.mock('@repositories/pharmacy-order-item/pharmacy-order-item.repository');
jest.mock('@lib/audit');
jest.mock('@services/pharmacy-workspace/pharmacy.shared', () => {
  const actual = jest.requireActual('@services/pharmacy-workspace/pharmacy.shared');
  return {
    ...actual,
    resolveModelIdOrThrow: jest.fn(),
  };
});

const mockUser = {
  id: 'user-123',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  roles: ['PHARMACIST'],
};

const buildScopedItem = (overrides = {}) => ({
  id: 'item-1',
  pharmacy_order: {
    patient: {
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
    },
  },
  ...overrides,
});

describe('Pharmacy Order Item Service', () => {
  const userId = 'user-123';
  const ipAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue(true);
    resolveModelIdOrThrow.mockReset();
  });

  describe('listPharmacyOrderItems', () => {
    it('should list pharmacy order items with pagination', async () => {
      pharmacyOrderItemRepository.findMany.mockResolvedValue([{ id: 'item-1' }]);
      pharmacyOrderItemRepository.count.mockResolvedValue(1);

      const result = await pharmacyOrderItemService.listPharmacyOrderItems(
        {},
        1,
        20,
        null,
        'asc',
        userId,
        ipAddress,
        mockUser
      );

      expect(result.pharmacyOrderItems).toEqual([{ id: 'item-1' }]);
      expect(result.pagination).toMatchObject({
        page: 1,
        limit: 20,
        total: 1
      });
    });

    it('should build query filters', async () => {
      pharmacyOrderItemRepository.findMany.mockResolvedValue([]);
      pharmacyOrderItemRepository.count.mockResolvedValue(0);

      resolveModelIdOrThrow
        .mockResolvedValueOnce('order-1')
        .mockResolvedValueOnce('drug-1');

      await pharmacyOrderItemService.listPharmacyOrderItems(
        {
          pharmacy_order_id: 'order-1',
          drug_id: 'drug-1',
          status: 'ACTIVE',
          route: 'ORAL',
          frequency: 'BID',
          search: '10mg'
        },
        1,
        20,
        'created_at',
        'desc',
        userId,
        ipAddress,
        mockUser
      );

      expect(pharmacyOrderItemRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          pharmacy_order_id: 'order-1',
          drug_id: 'drug-1',
          status: 'ACTIVE',
          route: 'ORAL',
          frequency: 'BID',
          OR: expect.any(Array)
        }),
        0,
        20,
        { created_at: 'desc' }
      );
    });
  });

  describe('getPharmacyOrderItemById', () => {
    it('should get pharmacy order item by id', async () => {
      const mockItem = buildScopedItem({
        drug: { id: 'drug-1' },
        dispense_logs: [],
      });
      pharmacyOrderItemRepository.findById.mockResolvedValue(mockItem);

      const result = await pharmacyOrderItemService.getPharmacyOrderItemById(
        'item-1',
        userId,
        ipAddress,
        mockUser
      );
      expect(result).toEqual(mockItem);
    });

    it('should throw if pharmacy order item not found', async () => {
      pharmacyOrderItemRepository.findById.mockResolvedValue(null);
      await expect(
        pharmacyOrderItemService.getPharmacyOrderItemById('missing', userId, ipAddress, mockUser)
      ).rejects.toThrow(HttpError);
    });

    it('should reject out-of-scope pharmacy order items', async () => {
      pharmacyOrderItemRepository.findById.mockResolvedValue(
        buildScopedItem({
          pharmacy_order: {
            patient: {
              tenant_id: 'tenant-other',
              facility_id: 'facility-other',
            },
          },
        })
      );

      await expect(
        pharmacyOrderItemService.getPharmacyOrderItemById('item-1', userId, ipAddress, mockUser)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createPharmacyOrderItem', () => {
    it('should create item and write audit log with tenant_id', async () => {
      const payload = { pharmacy_order_id: 'order-1', drug_id: 'drug-1', quantity: 2 };
      const created = { id: 'item-1', ...payload };
      resolveModelIdOrThrow
        .mockResolvedValueOnce('order-1')
        .mockResolvedValueOnce('drug-1');
      pharmacyOrderItemRepository.create.mockResolvedValue(created);
      pharmacyOrderItemRepository.findById.mockResolvedValue({
        id: 'item-1',
        pharmacy_order: {
          patient: { tenant_id: 'tenant-1' }
        }
      });

      const result = await pharmacyOrderItemService.createPharmacyOrderItem(
        payload,
        userId,
        ipAddress,
        mockUser
      );
      await new Promise((resolve) => setImmediate(resolve));

      expect(result).toEqual(created);
      expect(pharmacyOrderItemRepository.create).toHaveBeenCalledWith({
        ...payload,
        pharmacy_order_id: 'order-1',
        drug_id: 'drug-1',
      });
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-1',
          action: 'CREATE',
          entity: 'pharmacy_order_item'
        })
      );
    });
  });

  describe('updatePharmacyOrderItem', () => {
    it('should update item and write audit log with resolved tenant_id', async () => {
      const before = buildScopedItem();
      const after = { id: 'item-1', quantity: 5 };

      pharmacyOrderItemRepository.findById
        .mockResolvedValueOnce(before)
        .mockResolvedValueOnce({
          id: 'item-1',
          pharmacy_order: {
            patient: { tenant_id: 'tenant-2' }
          }
        });
      pharmacyOrderItemRepository.update.mockResolvedValue(after);

      const result = await pharmacyOrderItemService.updatePharmacyOrderItem(
        'item-1',
        { quantity: 5 },
        userId,
        ipAddress,
        mockUser
      );
      await new Promise((resolve) => setImmediate(resolve));

      expect(result).toEqual(after);
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-2',
          action: 'UPDATE',
          entity: 'pharmacy_order_item'
        })
      );
    });

    it('should throw if item missing before update', async () => {
      pharmacyOrderItemRepository.findById.mockResolvedValue(null);
      await expect(
        pharmacyOrderItemService.updatePharmacyOrderItem('missing', {}, userId, ipAddress, mockUser)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deletePharmacyOrderItem', () => {
    it('should soft delete item and write audit log', async () => {
      const before = buildScopedItem();
      pharmacyOrderItemRepository.findById.mockResolvedValue(before);
      pharmacyOrderItemRepository.softDelete.mockResolvedValue({ id: 'item-1', deleted_at: new Date() });

      await pharmacyOrderItemService.deletePharmacyOrderItem('item-1', userId, ipAddress, mockUser);
      await new Promise((resolve) => setImmediate(resolve));

      expect(pharmacyOrderItemRepository.softDelete).toHaveBeenCalledWith('item-1');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-1',
          action: 'DELETE',
          entity_id: 'item-1'
        })
      );
    });
  });
});
