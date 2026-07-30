jest.mock('@repositories/billing/billing.repository', () => ({
  findManyInvoices: jest.fn(),
  countInvoices: jest.fn(),
  findManyClaims: jest.fn(),
  countClaims: jest.fn(),
  findManyPreAuthorizations: jest.fn(),
  countPreAuthorizations: jest.fn(),
  findManyApprovals: jest.fn(),
  countApprovals: jest.fn(),
  findInvoiceById: jest.fn(),
  findPaymentById: jest.fn(),
  updateInvoice: jest.fn(),
  withTransaction: jest.fn(),
  createApproval: jest.fn(),
  findApprovalById: jest.fn(),
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

jest.mock('@services/opd-flow/opd-flow.service', () => ({
  syncConsultationBillingFromInvoicePayment: jest.fn(async () => null),
}));

const billingRepository = require('@repositories/billing/billing.repository');
const { resolveModelRecordByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const { publishBillingRealtimeUpdate } = require('@lib/billing/realtime');
const billingService = require('@services/billing/billing.service');

describe('billing.service getWorkItems — All queue (no queue filter)', () => {
  const user = {
    id: 'user-billing',
    tenant_id: 'tenant-1',
    facility_id: 'facility-1',
    permissions: ['billing:read'],
  };

  beforeEach(() => {
    jest.clearAllMocks();
    billingRepository.findManyInvoices.mockResolvedValue([]);
    billingRepository.countInvoices.mockResolvedValue(0);
    billingRepository.findManyClaims.mockResolvedValue([]);
    billingRepository.countClaims.mockResolvedValue(0);
    billingRepository.findManyPreAuthorizations.mockResolvedValue([]);
    billingRepository.countPreAuthorizations.mockResolvedValue(0);
    billingRepository.findManyApprovals.mockResolvedValue([]);
    billingRepository.countApprovals.mockResolvedValue(0);
  });

  it('returns merged queue buckets when queue is omitted (All tab)', async () => {
    billingRepository.findManyInvoices.mockImplementation(async (where) => {
      if (where.billing_status === 'DRAFT') {
        return [{ id: 'inv-draft', human_friendly_id: 'INV-DRAFT', billing_status: 'DRAFT', total_amount: '50.00' }];
      }
      if (where.status === 'OVERDUE') {
        return [];
      }
      return [{ id: 'inv-issued', human_friendly_id: 'INV-ISS', billing_status: 'ISSUED', status: 'SENT', total_amount: '100.00' }];
    });
    billingRepository.countInvoices.mockImplementation(async (where) => {
      if (where.billing_status === 'DRAFT') return 1;
      if (where.status === 'OVERDUE') return 0;
      return 1;
    });
    billingRepository.findManyApprovals.mockResolvedValue([
      { id: 'app-1', human_friendly_id: 'APP-1', status: 'PENDING', approval_type: 'REFUND' },
    ]);
    billingRepository.countApprovals.mockResolvedValue(1);

    const result = await billingService.getWorkItems({}, 1, 20, user);

    expect(result.queues).toBeDefined();
    expect(Array.isArray(result.queues)).toBe(true);
    expect(result.queues.length).toBe(5);
    const queueKeys = result.queues.map((entry) => entry.queue);
    expect(queueKeys).toEqual(
      expect.arrayContaining([
        'NEEDS_ISSUE',
        'PENDING_PAYMENT',
        'CLAIMS_PENDING',
        'APPROVAL_REQUIRED',
        'OVERDUE',
      ])
    );
    const needsIssue = result.queues.find((entry) => entry.queue === 'NEEDS_ISSUE');
    expect(needsIssue.items.length).toBeGreaterThan(0);
    expect(needsIssue.total).toBe(1);
  });

  it('rejects users without tenant scope', async () => {
    await expect(
      billingService.getWorkItems({}, 1, 20, { id: 'user-1', permissions: [] })
    ).rejects.toMatchObject({ statusCode: 403 });
  });

  it('rejects users without billing:read on All queue', async () => {
    await expect(
      billingService.getWorkItems(
        {},
        1,
        20,
        { id: 'user-1', tenant_id: 'tenant-1', permissions: [] }
      )
    ).rejects.toMatchObject({ statusCode: 403 });
  });
});

describe('billing.service All-tab mutations post through Billing (no bypass)', () => {
  const writer = {
    id: 'user-billing',
    tenant_id: 'tenant-1',
    facility_id: 'facility-1',
    permissions: ['billing:read', 'billing:write'],
  };

  const reader = {
    id: 'user-read',
    tenant_id: 'tenant-1',
    facility_id: 'facility-1',
    permissions: ['billing:read'],
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('issueInvoice updates billing_status and emits realtime events', async () => {
    resolveModelRecordByIdentifier.mockImplementation(async ({ model }) => {
      if (model === 'invoice') {
        return {
          id: 'inv-draft',
          human_friendly_id: 'INV-DRAFT',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          status: 'DRAFT',
          billing_status: 'DRAFT',
          total_amount: '50.00',
        };
      }
      return null;
    });
    billingRepository.updateInvoice.mockResolvedValue({});
    billingRepository.findInvoiceById.mockResolvedValue({
      id: 'inv-draft',
      human_friendly_id: 'INV-DRAFT',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      status: 'SENT',
      billing_status: 'ISSUED',
      total_amount: '50.00',
      items: [],
      payments: [],
      adjustments: [],
    });

    const result = await billingService.issueInvoice(
      'INV-DRAFT',
      { notes: 'All tab issue' },
      writer,
      '127.0.0.1'
    );

    expect(billingRepository.updateInvoice).toHaveBeenCalledWith(
      'inv-draft',
      expect.objectContaining({ billing_status: 'ISSUED', status: 'SENT' })
    );
    expect(result.invoice.billing_status).toBe('ISSUED');
    expect(publishBillingRealtimeUpdate).toHaveBeenCalled();
  });

  it('issueInvoice replay on already ISSUED is idempotent (no duplicate charge)', async () => {
    resolveModelRecordByIdentifier.mockImplementation(async ({ model }) => {
      if (model === 'invoice') {
        return {
          id: 'inv-issued',
          human_friendly_id: 'INV-ISSUED',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          status: 'SENT',
          billing_status: 'ISSUED',
          total_amount: '50.00',
        };
      }
      return null;
    });
    billingRepository.updateInvoice.mockResolvedValue({});
    billingRepository.findInvoiceById.mockResolvedValue({
      id: 'inv-issued',
      human_friendly_id: 'INV-ISSUED',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      status: 'SENT',
      billing_status: 'ISSUED',
      total_amount: '50.00',
      items: [],
      payments: [],
      adjustments: [],
    });

    const result = await billingService.issueInvoice('INV-ISSUED', {}, writer, '127.0.0.1');

    expect(billingRepository.updateInvoice).toHaveBeenCalledWith(
      'inv-issued',
      expect.objectContaining({ billing_status: 'ISSUED', status: 'SENT' })
    );
    expect(result.invoice.billing_status).toBe('ISSUED');
  });

  it('issueInvoice rejects readers without billing:write', async () => {
    await expect(
      billingService.issueInvoice('INV-DRAFT', {}, reader, '127.0.0.1')
    ).rejects.toMatchObject({ statusCode: 403 });
    expect(billingRepository.updateInvoice).not.toHaveBeenCalled();
  });

  it('reconcilePayment posts settlement, updates patient balance, emits realtime', async () => {
    resolveModelRecordByIdentifier.mockImplementation(async ({ model }) => {
      if (model === 'payment') {
        return {
          id: 'pay-1',
          human_friendly_id: 'PAY-1',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          invoice_id: 'inv-1',
          status: 'PENDING',
          amount: '100.00',
          method: 'CASH',
          paid_at: null,
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
      human_friendly_id: 'PAY-1',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      invoice_id: 'inv-1',
      status: 'COMPLETED',
      amount: '100.00',
      method: 'CASH',
      paid_at: new Date('2026-07-30T06:00:00.000Z'),
    });
    billingRepository.findInvoiceById.mockResolvedValue({
      id: 'inv-1',
      human_friendly_id: 'INV-1',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      billing_status: 'PAID',
      status: 'SENT',
      total_amount: '100.00',
      currency: 'UGX',
      items: [],
      payments: [{ id: 'pay-1', status: 'COMPLETED', amount: '100.00' }],
      adjustments: [],
    });

    const result = await billingService.reconcilePayment(
      'PAY-1',
      { status: 'COMPLETED' },
      writer,
      '127.0.0.1'
    );

    expect(result.payment.status).toBe('COMPLETED');
    expect(result.invoice.billing_status).toBe('PAID');
    expect(result.financials.balance_due).toBe(0);
    expect(publishBillingRealtimeUpdate).toHaveBeenCalled();
  });

  it('reconcilePayment replay is idempotent (no orphan duplicate settlement)', async () => {
    resolveModelRecordByIdentifier.mockImplementation(async ({ model }) => {
      if (model === 'payment') {
        return {
          id: 'pay-1',
          human_friendly_id: 'PAY-1',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          invoice_id: 'inv-1',
          status: 'COMPLETED',
          amount: '100.00',
          method: 'CASH',
        };
      }
      return null;
    });
    billingRepository.findPaymentById.mockResolvedValue({
      id: 'pay-1',
      human_friendly_id: 'PAY-1',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      invoice_id: 'inv-1',
      status: 'COMPLETED',
      amount: '100.00',
      method: 'CASH',
    });
    billingRepository.findInvoiceById.mockResolvedValue({
      id: 'inv-1',
      human_friendly_id: 'INV-1',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      billing_status: 'PAID',
      status: 'SENT',
      total_amount: '100.00',
      items: [],
      payments: [],
      adjustments: [],
    });

    const result = await billingService.reconcilePayment(
      'PAY-1',
      { status: 'COMPLETED' },
      writer,
      '127.0.0.1'
    );

    expect(result.payment.status).toBe('COMPLETED');
    expect(result.invoice.billing_status).toBe('PAID');
    expect(billingRepository.withTransaction).not.toHaveBeenCalled();
  });

  it('reconcilePayment rejects readers without billing:write', async () => {
    await expect(
      billingService.reconcilePayment('PAY-1', { status: 'COMPLETED' }, reader, '127.0.0.1')
    ).rejects.toMatchObject({ statusCode: 403 });
    expect(billingRepository.withTransaction).not.toHaveBeenCalled();
  });

  it('requestAdjustment rejects readers without billing:write', async () => {
    await expect(
      billingService.requestAdjustment(
        { invoice_id: 'INV-1', amount: '10.00', reason: 'Waive' },
        reader,
        '127.0.0.1'
      )
    ).rejects.toMatchObject({ statusCode: 403 });
  });
});
