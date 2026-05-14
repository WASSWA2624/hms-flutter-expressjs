const subscriptionInvoiceService = require('../../../../modules/subscription-invoice/services/subscription-invoice.service');
const subscriptionInvoiceRepository = require('../../../../modules/subscription-invoice/repositories/subscription-invoice.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

jest.mock('../../../../modules/subscription-invoice/repositories/subscription-invoice.repository');
jest.mock('@lib/audit');
jest.mock('@lib/billing/identifiers', () => ({
  resolveEntityId: jest.fn(async ({ identifier }) => identifier),
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value),
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value),
  resolvePublicIdentifier: jest.fn((...values) => values.find(Boolean) || null),
}));

const buildRecord = (overrides = {}) => ({
  id: 'subscription-invoice-uuid',
  human_friendly_id: 'SUBINV0001',
  subscription_id: 'subscription-uuid',
  subscription: {
    id: 'subscription-uuid',
    human_friendly_id: 'SUB0001',
    tenant_id: 'tenant-uuid',
    tenant: { id: 'tenant-uuid', human_friendly_id: 'TEN0001', name: 'Acme' },
    plan_id: 'plan-uuid',
    plan: { id: 'plan-uuid', human_friendly_id: 'PLAN0001', name: 'Pro', code: 'PRO' },
  },
  invoice_id: 'invoice-uuid',
  invoice: {
    id: 'invoice-uuid',
    human_friendly_id: 'INV0001',
    status: 'SENT',
    billing_status: 'PENDING',
    total_amount: 120,
    currency: 'USD',
    issued_at: '2026-03-01T00:00:00.000Z',
  },
  ...overrides,
});

describe('Subscription Invoice Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  it('returns serialized subscription invoice details', async () => {
    subscriptionInvoiceRepository.findById.mockResolvedValue(buildRecord());

    await expect(
      subscriptionInvoiceService.getSubscriptionInvoiceById('SUBINV0001')
    ).resolves.toEqual(
      expect.objectContaining({
        id: 'SUBINV0001',
        subscription_id: 'SUB0001',
        subscription_label: 'SUB0001',
        invoice_id: 'INV0001',
        invoice_display_id: 'INV0001',
        tenant_label: 'Acme',
      })
    );
  });

  it('lists subscription invoices with serialized rows and pagination', async () => {
    subscriptionInvoiceRepository.findMany.mockResolvedValue([
      buildRecord(),
      buildRecord({
        id: 'subscription-invoice-uuid-2',
        human_friendly_id: 'SUBINV0002',
      }),
    ]);
    subscriptionInvoiceRepository.count.mockResolvedValue(2);

    const result = await subscriptionInvoiceService.listSubscriptionInvoices(
      { subscription_id: 'SUB0001' },
      1,
      20
    );

    expect(subscriptionInvoiceRepository.findMany).toHaveBeenCalledWith(
      { subscription_id: 'SUB0001' },
      0,
      20,
      { created_at: 'desc' },
      expect.any(Object)
    );
    expect(result.subscriptionInvoices).toEqual([
      expect.objectContaining({ id: 'SUBINV0001' }),
      expect.objectContaining({ id: 'SUBINV0002' }),
    ]);
  });

  it('creates a subscription invoice, reloads it, and audits the change', async () => {
    const created = buildRecord({
      id: 'subscription-invoice-uuid-2',
      human_friendly_id: 'SUBINV0002',
    });
    subscriptionInvoiceRepository.create.mockResolvedValue({ id: created.id });
    subscriptionInvoiceRepository.findById.mockResolvedValue(created);

    const result = await subscriptionInvoiceService.createSubscriptionInvoice(
      {
        subscription_id: 'SUB0001',
        invoice_id: 'INV0002',
        human_friendly_id: 'SUBINV0002',
      },
      { id: 'user-1', role: 'SUPER_ADMIN' },
      '127.0.0.1'
    );

    expect(result).toEqual(expect.objectContaining({ id: 'SUBINV0002' }));
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entity: 'subscription_invoice',
      })
    );
  });

  it('returns collection metadata using public identifiers', async () => {
    subscriptionInvoiceRepository.findById.mockResolvedValue(buildRecord());

    const result = await subscriptionInvoiceService.collectSubscriptionInvoice(
      'SUBINV0001',
      { payment_method: 'cash', notes: 'Front desk collection' },
      { id: 'user-1', role: 'SUPER_ADMIN' },
      '127.0.0.1'
    );

    expect(result).toEqual(
      expect.objectContaining({
        subscription_invoice_id: 'SUBINV0001',
        collected: true,
        payment_method: 'cash',
      })
    );
  });

  it('throws HttpError when the subscription invoice does not exist', async () => {
    subscriptionInvoiceRepository.findById.mockResolvedValue(null);

    await expect(
      subscriptionInvoiceService.getSubscriptionInvoiceById('SUBINV404')
    ).rejects.toThrow(HttpError);
  });
});
