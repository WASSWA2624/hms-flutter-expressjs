jest.mock('@repositories/billing/billing.repository', () => ({
  findManyInvoices: jest.fn(),
  countInvoices: jest.fn(),
  findInvoiceById: jest.fn(),
  findPaymentById: jest.fn(),
  withTransaction: jest.fn(),
  createApproval: jest.fn(),
  findApprovalById: jest.fn(),
  findRealtimeRecipientUserIds: jest.fn(async () => ['billing-1']),
}));

jest.mock('@config/feature-flags', () => ({
  isFeatureEnabled: jest.fn(() => true),
}));

jest.mock('@lib/billing/clinical-request-billing', () => ({
  resolveClinicalInvoiceContexts: jest.fn(async () => ({})),
  syncClinicalOrderBillingSnapshotsFromInvoiceTx: jest.fn(async () => ({
    labOrderIds: [],
  })),
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

jest.mock('@lib/billing/financials', () => ({
  toDecimalNumber: (value) => Number(value || 0),
  toMoneyString: (value) => String(value ?? '0.00'),
  toDate: (value) => (value ? new Date(value) : null),
  recalculateInvoiceStateTx: jest.fn(async (_tx, invoiceId) => ({
    invoice: {
      id: invoiceId,
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      billing_status: 'PARTIAL',
      status: 'OVERDUE',
      total_amount: '450.00',
      currency: 'UGX',
    },
    financials: {
      balance_due: 200,
      net_paid_total: 250,
      effective_total: 450,
      gross_paid_total: 250,
    },
  })),
  computeInvoiceFinancials: jest.fn((invoice = {}) => {
    const total = Number(invoice.total_amount || 0);
    const paid = (invoice.payments || [])
      .filter((p) => String(p.status || '').toUpperCase() === 'COMPLETED')
      .reduce((sum, p) => sum + Number(p.amount || 0), 0);
    return {
      balance_due: String(total - paid),
      net_paid_total: String(paid),
      effective_total: String(total),
      gross_paid_total: String(paid),
    };
  }),
}));

jest.mock('@lib/billing/realtime', () => ({
  publishBillingRealtimeUpdate: jest.fn(async () => {}),
}));

jest.mock('@services/lab-order/lab-order.service', () => ({
  notifyLabOrdersBillingUpdated: jest.fn(async () => {}),
}));

jest.mock('@services/opd-flow/opd-flow.service', () => ({
  syncConsultationBillingFromInvoicePayment: jest.fn(async () => null),
}));

const billingRepository = require('@repositories/billing/billing.repository');
const { resolveModelRecordByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const { publishBillingRealtimeUpdate } = require('@lib/billing/realtime');
const { recalculateInvoiceStateTx } = require('@lib/billing/financials');
const billingService = require('@services/billing/billing.service');

describe('billing.service Overdue tab', () => {
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

  it('getWorkItems OVERDUE returns only status OVERDUE invoices', async () => {
    billingRepository.findManyInvoices.mockResolvedValue([
      {
        id: 'inv-overdue',
        human_friendly_id: 'INV-OVERDUE',
        billing_status: 'ISSUED',
        status: 'OVERDUE',
        total_amount: '450.00',
        items: [{ id: 'line-1', description: 'Consult', source_module: 'OPD' }],
      },
    ]);
    billingRepository.countInvoices.mockResolvedValue(1);

    const result = await billingService.getWorkItems(
      { queue: 'OVERDUE' },
      1,
      20,
      reader
    );

    expect(billingRepository.findManyInvoices).toHaveBeenCalledWith(
      expect.objectContaining({
        status: 'OVERDUE',
        billing_status: { not: 'CANCELLED' },
      }),
      0,
      20,
      { issued_at: 'asc' },
      expect.anything()
    );
    expect(result.queue).toBe('OVERDUE');
    expect(result.items).toHaveLength(1);
    expect(result.items[0].status).toBe('OVERDUE');
  });

  it('rejects unauthorized users without billing:read on OVERDUE queue', async () => {
    await expect(
      billingService.getWorkItems(
        { queue: 'OVERDUE' },
        1,
        20,
        { id: 'user-1', tenant_id: 'tenant-1', permissions: [] }
      )
    ).rejects.toMatchObject({ statusCode: 403 });
  });
});

describe('billing.service Overdue tab mutations post through Billing', () => {
  const writer = {
    id: 'user-billing',
    tenant_id: 'tenant-1',
    facility_id: 'facility-1',
    permissions: ['billing:read', 'billing:write'],
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('reconcilePayment on overdue invoice posts settlement and emits realtime', async () => {
    resolveModelRecordByIdentifier.mockImplementation(async ({ model }) => {
      if (model === 'payment') {
        return {
          id: 'pay-ovd',
          human_friendly_id: 'PAY-OVD',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          invoice_id: 'inv-overdue',
          amount: '250.00',
          status: 'PENDING',
          paid_at: null,
        };
      }
      return null;
    });

    billingRepository.withTransaction.mockImplementation(async (callback) => {
      const tx = {
        invoice: {
          findFirst: jest.fn(async () => ({
            id: 'inv-overdue',
            tenant_id: 'tenant-1',
            facility_id: 'facility-1',
            billing_status: 'ISSUED',
            status: 'OVERDUE',
            total_amount: '450.00',
            payments: [],
            billing_adjustments: [],
          })),
        },
        payment: {
          update: jest.fn(async () => ({
            id: 'pay-ovd',
            invoice_id: 'inv-overdue',
            status: 'COMPLETED',
            amount: '250.00',
          })),
        },
      };
      return callback(tx);
    });

    billingRepository.findPaymentById.mockResolvedValue({
      id: 'pay-ovd',
      human_friendly_id: 'PAY-OVD',
      status: 'COMPLETED',
      amount: '250.00',
      method: 'CASH',
      invoice_id: 'inv-overdue',
    });
    billingRepository.findInvoiceById.mockResolvedValue({
      id: 'inv-overdue',
      human_friendly_id: 'INV-OVERDUE',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      billing_status: 'PARTIAL',
      status: 'OVERDUE',
      total_amount: '450.00',
      payments: [{ id: 'pay-ovd', amount: '250.00', status: 'COMPLETED' }],
      adjustments: [],
    });

    const result = await billingService.reconcilePayment(
      'PAY-OVD',
      { status: 'COMPLETED' },
      writer,
      '127.0.0.1'
    );

    expect(recalculateInvoiceStateTx).toHaveBeenCalled();
    expect(result.payment.status).toBe('COMPLETED');
    expect(result.invoice.status).toBe('OVERDUE');
    expect(publishBillingRealtimeUpdate).toHaveBeenCalled();
  });

  it('reconcilePayment replay on already COMPLETED payment is idempotent', async () => {
    resolveModelRecordByIdentifier.mockImplementation(async ({ model }) => {
      if (model === 'payment') {
        return {
          id: 'pay-ovd',
          human_friendly_id: 'PAY-OVD',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          invoice_id: 'inv-overdue',
          amount: '250.00',
          status: 'COMPLETED',
        };
      }
      return null;
    });
    billingRepository.findPaymentById.mockResolvedValue({
      id: 'pay-ovd',
      status: 'COMPLETED',
      amount: '250.00',
      invoice_id: 'inv-overdue',
    });
    billingRepository.findInvoiceById.mockResolvedValue({
      id: 'inv-overdue',
      billing_status: 'PARTIAL',
      status: 'OVERDUE',
      total_amount: '450.00',
      payments: [{ id: 'pay-ovd', amount: '250.00', status: 'COMPLETED' }],
      adjustments: [],
    });

    const result = await billingService.reconcilePayment(
      'PAY-OVD',
      { status: 'COMPLETED' },
      writer,
      '127.0.0.1'
    );

    expect(billingRepository.withTransaction).not.toHaveBeenCalled();
    expect(result.payment.status).toBe('COMPLETED');
  });

  it('reconcilePayment rejects amount exceeding overdue balance', async () => {
    resolveModelRecordByIdentifier.mockImplementation(async ({ model }) => {
      if (model === 'payment') {
        return {
          id: 'pay-over',
          human_friendly_id: 'PAY-OVER',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          invoice_id: 'inv-overdue',
          amount: '999.00',
          status: 'PENDING',
        };
      }
      return null;
    });

    billingRepository.withTransaction.mockImplementation(async (callback) => {
      const tx = {
        invoice: {
          findFirst: jest.fn(async () => ({
            id: 'inv-overdue',
            billing_status: 'ISSUED',
            status: 'OVERDUE',
            total_amount: '450.00',
            payments: [],
            billing_adjustments: [],
          })),
        },
        payment: { update: jest.fn() },
      };
      return callback(tx);
    });

    await expect(
      billingService.reconcilePayment(
        'PAY-OVER',
        { status: 'COMPLETED' },
        writer,
        '127.0.0.1'
      )
    ).rejects.toMatchObject({
      messageKey: 'errors.payment.amount_exceeds_balance',
      statusCode: 400,
    });
  });

  it('reconcilePayment rejects users without billing:write', async () => {
    await expect(
      billingService.reconcilePayment(
        'PAY-OVD',
        { status: 'COMPLETED' },
        {
          id: 'user-read',
          tenant_id: 'tenant-1',
          permissions: ['billing:read'],
        },
        '127.0.0.1'
      )
    ).rejects.toMatchObject({ statusCode: 403 });
  });

  it('requestAdjustment (waive) on overdue posts through Billing transaction', async () => {
    resolveModelRecordByIdentifier.mockImplementation(async ({ model }) => {
      if (model === 'invoice') {
        return {
          id: 'inv-overdue',
          human_friendly_id: 'INV-OVERDUE',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          status: 'OVERDUE',
          billing_status: 'ISSUED',
          total_amount: '450.00',
          items: [],
          payments: [],
          billing_adjustments: [],
        };
      }
      if (model === 'billing_adjustment') {
        return {
          id: 'adj-1',
          invoice_id: 'inv-overdue',
          amount: '-40.00',
          status: 'ISSUED',
          reason: 'Collections waiver',
        };
      }
      return null;
    });

    billingRepository.withTransaction.mockImplementation(async (callback) => {
      const tx = {
        billing_adjustment: {
          create: jest.fn(async () => ({
            id: 'adj-1',
            invoice_id: 'inv-overdue',
            amount: '-40.00',
            status: 'ISSUED',
            reason: 'Collections waiver',
          })),
        },
      };
      return callback(tx);
    });
    billingRepository.findInvoiceById.mockResolvedValue({
      id: 'inv-overdue',
      human_friendly_id: 'INV-OVERDUE',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      billing_status: 'ISSUED',
      status: 'OVERDUE',
      total_amount: '450.00',
      payments: [],
      adjustments: [{ id: 'adj-1', amount: '-40.00' }],
    });

    const result = await billingService.requestAdjustment(
      {
        invoice_id: 'INV-OVERDUE',
        amount: '-40.00',
        reason: 'Collections waiver',
      },
      writer,
      '127.0.0.1'
    );

    expect(result.approval_required).toBe(false);
    expect(result.adjustment.amount).toBe('-40.00');
    expect(publishBillingRealtimeUpdate).toHaveBeenCalled();
  });

  it('requestAdjustment rejects users without billing:write', async () => {
    await expect(
      billingService.requestAdjustment(
        { invoice_id: 'INV-OVERDUE', amount: '-10.00', reason: 'Waive' },
        {
          id: 'user-read',
          tenant_id: 'tenant-1',
          permissions: ['billing:read'],
        },
        '127.0.0.1'
      )
    ).rejects.toMatchObject({ statusCode: 403 });
  });
});
