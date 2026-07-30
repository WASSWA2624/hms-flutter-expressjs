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
  updateInvoice: jest.fn(),
}));

jest.mock('@config/feature-flags', () => ({
  isFeatureEnabled: jest.fn(() => true),
}));

jest.mock('@lib/billing/clinical-request-billing', () => ({
  resolveClinicalInvoiceContexts: jest.fn(async () => ({})),
}));

jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelRecordByIdentifier: jest.fn(),
}));

jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn(async () => {}),
}));

jest.mock('@lib/websocket', () => ({
  publishDomainEvent: jest.fn(),
  BILLING_EVENTS: {
    BILLING_INVOICE_ISSUED: 'billing.invoice_issued',
    INVOICE_UPDATED: 'invoice.updated',
    BILLING_BALANCE_UPDATED: 'billing.balance_updated',
  },
}));

const billingRepository = require('@repositories/billing/billing.repository');
const { resolveModelRecordByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const { publishDomainEvent } = require('@lib/websocket');
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

  it('rejects unauthorized users without billing:read', async () => {
    await expect(
      billingService.getWorkItems({}, 1, 20, { id: 'user-1', tenant_id: 'tenant-1', permissions: [] })
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
    expect(publishDomainEvent).toHaveBeenCalled();
  });
});
