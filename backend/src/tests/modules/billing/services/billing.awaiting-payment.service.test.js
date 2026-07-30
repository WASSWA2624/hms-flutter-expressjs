jest.mock('@repositories/billing/billing.repository', () => ({
  findManyInvoices: jest.fn(),
  countInvoices: jest.fn(),
  findInvoiceById: jest.fn(),
  findPaymentById: jest.fn(),
  withTransaction: jest.fn(),
  findRealtimeRecipientUserIds: jest.fn(async () => ['billing-1']),
}));

jest.mock('@config/feature-flags', () => ({
  isFeatureEnabled: jest.fn(() => true),
}));

jest.mock('@lib/billing/clinical-request-billing', () => ({
  resolveClinicalInvoiceContexts: jest.fn(async () => ({})),
  resolveInvoiceIdsForEncounterToken: jest.fn(async () => []),
  resolveInvoiceIdsForSourceModule: jest.fn(async () => []),
  syncClinicalOrderBillingSnapshotsFromInvoiceTx: jest.fn(async () => ({
    labOrderIds: [],
  })),
}));

jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelRecordByIdentifier: jest.fn(),
}));

jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn(async () => {}),
}));

jest.mock('@lib/billing/realtime', () => ({
  publishBillingRealtimeUpdate: jest.fn(async () => {}),
}));

jest.mock('@lib/billing/financials', () => ({
  toDecimalNumber: (value) => Number(value || 0),
  toMoneyString: (value) => String(value ?? '0.00'),
  recalculateInvoiceStateTx: jest.fn(async (_tx, invoiceId) => ({
    invoice: {
      id: invoiceId,
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      billing_status: 'PAID',
      status: 'SENT',
      total_amount: '100.00',
      currency: 'UGX',
    },
    financials: {
      balance_due: 0,
      net_paid_total: 100,
      effective_total: 100,
      gross_paid_total: 100,
    },
  })),
  computeInvoiceFinancials: jest.fn(() => ({
    balance_due: 0,
    net_paid_total: 100,
    effective_total: 100,
  })),
}));

jest.mock('@services/lab-order/lab-order.service', () => ({
  notifyLabOrdersBillingUpdated: jest.fn(async () => {}),
}));

jest.mock('@lib/websocket', () => ({
  publishDomainEvent: jest.fn(),
  BILLING_EVENTS: {
    BILLING_INVOICE_ISSUED: 'billing.invoice_issued',
    BILLING_PAYMENT_RECEIVED: 'billing.payment_received',
    INVOICE_UPDATED: 'invoice.updated',
    BILLING_BALANCE_UPDATED: 'billing.balance_updated',
  },
  PAYMENT_EVENTS: {
    PAYMENT_RECONCILED: 'payment.reconciled',
  },
}));

jest.mock('@lib/realtime/recipients', () => ({
  findRealtimeRecipientUserIds: jest.fn(async () => ['billing-1']),
}));

const mockSyncConsultationBillingFromInvoicePayment = jest.fn(async () => null);
jest.mock('@services/opd-flow/opd-flow.service', () => ({
  syncConsultationBillingFromInvoicePayment: (...args) =>
    mockSyncConsultationBillingFromInvoicePayment(...args),
}));

const billingRepository = require('@repositories/billing/billing.repository');
const { resolveModelRecordByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const { publishBillingRealtimeUpdate } = require('@lib/billing/realtime');
const { recalculateInvoiceStateTx } = require('@lib/billing/financials');
const billingService = require('@services/billing/billing.service');

describe('billing.service Awaiting payment tab (PENDING_PAYMENT)', () => {
  const reader = {
    id: 'user-read',
    tenant_id: 'tenant-1',
    facility_id: 'facility-1',
    permissions: ['billing:read'],
  };

  const writer = {
    id: 'user-write',
    tenant_id: 'tenant-1',
    facility_id: 'facility-1',
    permissions: ['billing:read', 'billing:write'],
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('getWorkItems PENDING_PAYMENT returns ISSUED/PARTIAL invoices only', async () => {
    billingRepository.findManyInvoices.mockResolvedValue([
      {
        id: 'inv-issued',
        human_friendly_id: 'INV-ISSUED',
        billing_status: 'ISSUED',
        status: 'SENT',
        total_amount: '100.00',
        items: [{ id: 'line-1', description: 'Consult' }],
        payments: [],
      },
    ]);
    billingRepository.countInvoices.mockResolvedValue(1);

    const result = await billingService.getWorkItems(
      { queue: 'PENDING_PAYMENT' },
      1,
      20,
      reader
    );

    expect(billingRepository.findManyInvoices).toHaveBeenCalledWith(
      expect.objectContaining({
        billing_status: { in: ['ISSUED', 'PARTIAL'] },
        status: { in: ['SENT', 'OVERDUE'] },
      }),
      0,
      20,
      { issued_at: 'desc' },
      expect.anything()
    );
    expect(result.queue).toBe('PENDING_PAYMENT');
    expect(result.items).toHaveLength(1);
    expect(result.items[0].billing_status).toBe('ISSUED');
  });

  it('rejects unauthorized users without tenant scope on PENDING_PAYMENT', async () => {
    await expect(
      billingService.getWorkItems(
        { queue: 'PENDING_PAYMENT' },
        1,
        20,
        { id: 'user-1', permissions: [] }
      )
    ).rejects.toMatchObject({ statusCode: 403 });
  });
});

describe('billing.service Awaiting payment mutations post through Billing', () => {
  const writer = {
    id: 'user-billing',
    tenant_id: 'tenant-1',
    facility_id: 'facility-1',
    permissions: ['billing:read', 'billing:write'],
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('reconcilePayment posts payment, updates invoice balance, emits realtime', async () => {
    resolveModelRecordByIdentifier.mockImplementation(async ({ model }) => {
      if (model === 'payment') {
        return {
          id: 'pay-1',
          human_friendly_id: 'PAY-AWAIT',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          invoice_id: 'inv-1',
          amount: '100.00',
          status: 'PENDING',
          method: 'CASH',
          paid_at: null,
          invoice: {
            id: 'inv-1',
            tenant_id: 'tenant-1',
            facility_id: 'facility-1',
            patient_id: 'patient-1',
          },
        };
      }
      return null;
    });

    billingRepository.withTransaction.mockImplementation(async (callback) => {
      const tx = {
        payment: {
          update: jest.fn(async () => ({
            id: 'pay-1',
            invoice_id: 'inv-1',
            status: 'COMPLETED',
            amount: '100.00',
            paid_at: new Date('2026-07-30T06:00:00.000Z'),
          })),
        },
      };
      return callback(tx);
    });

    billingRepository.findPaymentById.mockResolvedValue({
      id: 'pay-1',
      human_friendly_id: 'PAY-AWAIT',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      invoice_id: 'inv-1',
      status: 'COMPLETED',
      amount: '100.00',
      method: 'CASH',
      paid_at: new Date('2026-07-30T06:00:00.000Z'),
      invoice: {
        id: 'inv-1',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        billing_status: 'PAID',
        status: 'SENT',
        total_amount: '100.00',
        currency: 'UGX',
        patient_id: 'patient-1',
      },
    });
    billingRepository.findInvoiceById.mockResolvedValue({
      id: 'inv-1',
      human_friendly_id: 'INV-AWAIT',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      billing_status: 'PAID',
      status: 'SENT',
      total_amount: '100.00',
      currency: 'UGX',
      patient_id: 'patient-1',
      payments: [{ id: 'pay-1', status: 'COMPLETED', amount: '100.00' }],
      adjustments: [],
    });

    const result = await billingService.reconcilePayment(
      'PAY-AWAIT',
      { status: 'COMPLETED' },
      writer,
      '127.0.0.1'
    );

    expect(result.payment.status).toBe('COMPLETED');
    expect(result.invoice.billing_status).toBe('PAID');
    expect(recalculateInvoiceStateTx).toHaveBeenCalled();
    expect(publishBillingRealtimeUpdate).toHaveBeenCalled();
    expect(mockSyncConsultationBillingFromInvoicePayment).toHaveBeenCalled();
  });

  it('reconcilePayment replay on already COMPLETED is idempotent (no duplicate post)', async () => {
    resolveModelRecordByIdentifier.mockImplementation(async ({ model }) => {
      if (model === 'payment') {
        return {
          id: 'pay-done',
          human_friendly_id: 'PAY-DONE',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          invoice_id: 'inv-1',
          amount: '100.00',
          status: 'COMPLETED',
          method: 'MOBILE_MONEY',
          paid_at: new Date('2026-07-30T05:00:00.000Z'),
        };
      }
      return null;
    });

    billingRepository.findPaymentById.mockResolvedValue({
      id: 'pay-done',
      human_friendly_id: 'PAY-DONE',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      invoice_id: 'inv-1',
      status: 'COMPLETED',
      amount: '100.00',
      method: 'MOBILE_MONEY',
      paid_at: new Date('2026-07-30T05:00:00.000Z'),
    });
    billingRepository.findInvoiceById.mockResolvedValue({
      id: 'inv-1',
      human_friendly_id: 'INV-AWAIT',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      billing_status: 'PAID',
      status: 'SENT',
      total_amount: '100.00',
      currency: 'UGX',
      payments: [{ id: 'pay-done', status: 'COMPLETED', amount: '100.00' }],
      adjustments: [],
    });

    const result = await billingService.reconcilePayment(
      'PAY-DONE',
      { status: 'COMPLETED' },
      writer,
      '127.0.0.1'
    );

    expect(result.payment.status).toBe('COMPLETED');
    expect(result.invoice.billing_status).toBe('PAID');
    expect(billingRepository.withTransaction).not.toHaveBeenCalled();
    expect(recalculateInvoiceStateTx).not.toHaveBeenCalled();
    expect(publishBillingRealtimeUpdate).not.toHaveBeenCalled();
  });

  it('reconcilePayment rejects users without tenant scope (authorization)', async () => {
    await expect(
      billingService.reconcilePayment(
        'PAY-AWAIT',
        { status: 'COMPLETED' },
        { id: 'user-1', permissions: [] },
        '127.0.0.1'
      )
    ).rejects.toMatchObject({ statusCode: 403 });
  });
});
