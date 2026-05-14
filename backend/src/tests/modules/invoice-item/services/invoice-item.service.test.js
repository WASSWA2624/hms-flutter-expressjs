/**
 * Invoice item service tests
 */

const invoiceItemService = require('@services/invoice-item/invoice-item.service');
const invoiceItemRepository = require('@repositories/invoice-item/invoice-item.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

jest.mock('@repositories/invoice-item/invoice-item.repository');
jest.mock('@lib/audit');
jest.mock('@lib/billing/identifiers', () => ({
  sanitizeIdentifier: (value) => (typeof value === 'string' ? value.trim() : ''),
  resolvePublicIdentifier: (...values) => {
    for (const value of values) {
      const normalized =
        typeof value === 'string'
          ? value.trim()
          : value == null
            ? ''
            : String(value).trim();
      if (normalized) return normalized;
    }
    return null;
  },
  resolveIdentifierForFilter: async ({ value }) => value,
  resolveIdentifierForPayload: async ({ value, nullable = false }) => {
    if (value === undefined) return undefined;
    if (value === null && nullable) return null;
    return value;
  },
  resolveEntityId: async ({ identifier }) => identifier,
}));

describe('Invoice Item Service', () => {
  const userId = 'user-123';
  const ipAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue(true);
  });

  describe('listInvoiceItems', () => {
    it('should list invoice items with pagination', async () => {
      invoiceItemRepository.findMany.mockResolvedValue([{ id: 'item-1' }]);
      invoiceItemRepository.count.mockResolvedValue(1);

      const result = await invoiceItemService.listInvoiceItems({}, 1, 20, null, 'desc');

      expect(result.invoiceItems).toEqual([
        expect.objectContaining({ id: 'item-1' }),
      ]);
      expect(result.pagination).toMatchObject({
        page: 1,
        limit: 20,
        total: 1
      });
    });

    it('should apply filters and search', async () => {
      invoiceItemRepository.findMany.mockResolvedValue([]);
      invoiceItemRepository.count.mockResolvedValue(0);

      await invoiceItemService.listInvoiceItems(
        { invoice_id: 'invoice-1', search: 'consult' },
        1,
        20,
        'created_at',
        'asc'
      );

      expect(invoiceItemRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          invoice_id: 'invoice-1',
          OR: expect.arrayContaining([
            expect.objectContaining({ description: { contains: 'consult' } }),
          ]),
        }),
        0,
        20,
        { created_at: 'asc' },
        expect.any(Object)
      );
    });
  });

  describe('getInvoiceItemById', () => {
    it('should get invoice item by id', async () => {
      const item = { id: 'item-1' };
      invoiceItemRepository.findById.mockResolvedValue(item);

      const result = await invoiceItemService.getInvoiceItemById('item-1');
      expect(result).toEqual(expect.objectContaining(item));
    });

    it('should throw if invoice item not found', async () => {
      invoiceItemRepository.findById.mockResolvedValue(null);
      await expect(invoiceItemService.getInvoiceItemById('missing')).rejects.toThrow(HttpError);
    });
  });

  describe('createInvoiceItem', () => {
    it('should create invoice item and write audit log with tenant_id', async () => {
      const payload = { invoice_id: 'invoice-1', description: 'Consultation', unit_price: '100.00', total_price: '100.00' };
      const created = { id: 'item-1', ...payload };
      invoiceItemRepository.create.mockResolvedValue(created);
      invoiceItemRepository.findById
        .mockResolvedValueOnce({ id: 'item-1', invoice: { tenant_id: 'tenant-1' } })
        .mockResolvedValueOnce(created);

      const result = await invoiceItemService.createInvoiceItem(payload, userId, ipAddress);
      await new Promise((resolve) => setImmediate(resolve));

      expect(result).toEqual(expect.objectContaining(created));
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-1',
          user_id: userId,
          action: 'CREATE',
          entity: 'invoice_item',
          entity_id: 'item-1'
        })
      );
    });
  });

  describe('updateInvoiceItem', () => {
    it('should update invoice item and write audit log with resolved tenant_id', async () => {
      const before = { id: 'item-1', invoice: { tenant_id: 'tenant-1' } };
      const after = { id: 'item-1', description: 'Updated', invoice: { tenant_id: 'tenant-2' } };

      invoiceItemRepository.findById
        .mockResolvedValueOnce(before)
        .mockResolvedValueOnce({ id: 'item-1', invoice: { tenant_id: 'tenant-2' } })
        .mockResolvedValueOnce(after);
      invoiceItemRepository.update.mockResolvedValue(after);

      const result = await invoiceItemService.updateInvoiceItem('item-1', { description: 'Updated' }, userId, ipAddress);
      await new Promise((resolve) => setImmediate(resolve));

      expect(result).toEqual(expect.objectContaining(after));
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-2',
          action: 'UPDATE',
          entity: 'invoice_item'
        })
      );
    });

    it('should throw if invoice item does not exist before update', async () => {
      invoiceItemRepository.findById.mockResolvedValue(null);
      await expect(
        invoiceItemService.updateInvoiceItem('missing', { description: 'Updated' }, userId, ipAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deleteInvoiceItem', () => {
    it('should soft delete invoice item and write audit log', async () => {
      const before = { id: 'item-1', invoice: { tenant_id: 'tenant-1' } };
      invoiceItemRepository.findById.mockResolvedValue(before);
      invoiceItemRepository.softDelete.mockResolvedValue({ id: 'item-1', deleted_at: new Date() });

      await invoiceItemService.deleteInvoiceItem('item-1', userId, ipAddress);
      await new Promise((resolve) => setImmediate(resolve));

      expect(invoiceItemRepository.softDelete).toHaveBeenCalledWith('item-1');
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
