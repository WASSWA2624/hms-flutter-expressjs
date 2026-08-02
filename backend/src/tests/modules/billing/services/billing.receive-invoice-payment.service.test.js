jest.mock('@repositories/billing/billing.repository', () => ({
  withTransaction: jest.fn(),
  findPaymentById: jest.fn(),
  findInvoiceById: jest.fn(),
  findRealtimeRecipientUserIds: jest.fn(async () => ['billing-1', 'reception-1']),
}));

jest.mock('@config/feature-flags', () => ({
  isFeatureEnabled: jest.fn(() => true),
}));

jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelRecordByIdentifier: jest.fn(),
}));

jest.mock('@lib/notifications/sendEmail', () => ({
  sendEmail: jest.fn(async () => ({ sent: true, provider: 'smtp' })),
}));

jest.mock('@lib/billing/pdf', () => ({
  generateInvoicePdfBuffer: jest.fn(async () => Buffer.from('pdf')),
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
      total_amount: '210000.00',
      currency: 'UGX',
    },
    financials: {
      balance_due: 0,
      net_paid_total: 210000,
      effective_total: 210000,
      gross_paid_total: 210000,
    },
  })),
  computeInvoiceFinancials: jest.fn((invoice = {}) => {
    const total = Number(invoice.total_amount || 0);
    const paid = (invoice.payments || [])
      .filter((p) => String(p.status || '').toUpperCase() === 'COMPLETED')
      .reduce((sum, p) => sum + Number(p.amount || 0), 0);
    return {
      balance_due: Math.max(0, total - paid),
      net_paid_total: paid,
      effective_total: total,
    };
  }),
}));

jest.mock('@lib/billing/clinical-request-billing', () => ({
  resolveClinicalInvoiceContexts: jest.fn(async () => ({})),
  resolveInvoiceIdsForEncounterToken: jest.fn(async () => []),
  resolveInvoiceIdsForSourceModule: jest.fn(async () => []),
  syncClinicalOrderBillingSnapshotsFromInvoiceTx: jest.fn(async () => ({
    labOrderIds: [],
    radiologyOrderIds: [],
  })),
}));

jest.mock('@services/lab-order/lab-order.service', () => ({
  notifyLabOrdersBillingUpdated: jest.fn(async () => {}),
}));

jest.mock('@services/radiology-workspace/radiology-workspace.service', () => ({
  notifyRadiologyOrdersBillingUpdated: jest.fn(async () => {}),
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
  findRealtimeRecipientUserIds: jest.fn(async () => ['billing-1', 'reception-1']),
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

describe('billing.service receiveInvoicePayment', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('creates COMPLETED payment, fails orphan PENDING rows, and marks invoice PAID', async () => {
    resolveModelRecordByIdentifier.mockResolvedValue({
      id: 'inv-1',
      human_friendly_id: 'INV0000021',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      patient_id: 'patient-1',
      encounter_id: 'encounter-1',
      billing_status: 'ISSUED',
      status: 'SENT',
      total_amount: '210000.00',
      currency: 'UGX',
      payments: [
        { id: 'pay-orphan-1', status: 'PENDING', amount: '210000.00' },
        { id: 'pay-orphan-2', status: 'PENDING', amount: '210000.00' },
        { id: 'pay-orphan-3', status: 'PENDING', amount: '210000.00' },
      ],
      adjustments: [],
    });

    const updateMany = jest.fn(async () => ({ count: 3 }));
    const paymentCreate = jest.fn(async () => ({
      id: 'pay-new',
      human_friendly_id: 'PAY0000019',
      invoice_id: 'inv-1',
      status: 'COMPLETED',
      method: 'CASH',
      amount: 210000,
      paid_at: new Date('2026-08-02T18:00:00.000Z'),
    }));

    billingRepository.withTransaction.mockImplementation(async (callback) => {
      const tx = {
        payment: {
          updateMany,
          create: paymentCreate,
        },
      };
      return callback(tx);
    });

    billingRepository.findPaymentById.mockResolvedValue({
      id: 'pay-new',
      human_friendly_id: 'PAY0000019',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      invoice_id: 'inv-1',
      status: 'COMPLETED',
      method: 'CASH',
      amount: '210000.00',
      paid_at: new Date('2026-08-02T18:00:00.000Z'),
      invoice: {
        id: 'inv-1',
        billing_status: 'PAID',
        status: 'SENT',
      },
    });
    billingRepository.findInvoiceById.mockResolvedValue({
      id: 'inv-1',
      human_friendly_id: 'INV0000021',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      billing_status: 'PAID',
      status: 'SENT',
      total_amount: '210000.00',
      currency: 'UGX',
      patient_id: 'patient-1',
      encounter_id: 'encounter-1',
      payments: [
        { id: 'pay-new', status: 'COMPLETED', amount: '210000.00' },
      ],
      adjustments: [],
    });

    const result = await billingService.receiveInvoicePayment(
      'INV0000021',
      { amount: 210000, method: 'CASH' },
      {
        id: 'user-billing',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        permissions: ['billing:read', 'billing:write'],
      },
      '127.0.0.1'
    );

    expect(updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          invoice_id: 'inv-1',
          status: 'PENDING',
        }),
        data: { status: 'FAILED' },
      })
    );
    expect(paymentCreate).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          invoice_id: 'inv-1',
          status: 'COMPLETED',
          method: 'CASH',
          amount: 210000,
        }),
      })
    );
    expect(recalculateInvoiceStateTx).toHaveBeenCalled();
    expect(result.payment.status).toBe('COMPLETED');
    expect(result.invoice.billing_status).toBe('PAID');
    expect(result.financials.balance_due).toBe(0);
    expect(publishBillingRealtimeUpdate).toHaveBeenCalled();
    expect(mockSyncConsultationBillingFromInvoicePayment).toHaveBeenCalledWith(
      expect.objectContaining({ invoiceId: 'inv-1' })
    );
  });
});
