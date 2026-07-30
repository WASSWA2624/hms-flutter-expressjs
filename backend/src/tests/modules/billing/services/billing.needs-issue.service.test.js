jest.mock('@repositories/billing/billing.repository', () => ({
  findManyInvoices: jest.fn(),
  countInvoices: jest.fn(),
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

jest.mock('@lib/billing/realtime', () => ({
  publishBillingRealtimeUpdate: jest.fn(async () => {}),
}));

const billingRepository = require('@repositories/billing/billing.repository');
const { resolveModelRecordByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const { publishBillingRealtimeUpdate } = require('@lib/billing/realtime');
const billingService = require('@services/billing/billing.service');

describe('billing.service Needs issue tab', () => {
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

  it('getWorkItems NEEDS_ISSUE returns only DRAFT invoices', async () => {
    billingRepository.findManyInvoices.mockResolvedValue([
      {
        id: 'inv-draft',
        human_friendly_id: 'INV-DRAFT',
        billing_status: 'DRAFT',
        status: 'DRAFT',
        total_amount: '75.00',
        items: [{ id: 'line-1', description: 'Consult', source_module: 'OPD' }],
      },
    ]);
    billingRepository.countInvoices.mockResolvedValue(1);

    const result = await billingService.getWorkItems(
      { queue: 'NEEDS_ISSUE' },
      1,
      20,
      reader
    );

    expect(billingRepository.findManyInvoices).toHaveBeenCalledWith(
      expect.objectContaining({ billing_status: 'DRAFT' }),
      0,
      20,
      { issued_at: 'desc' },
      expect.anything()
    );
    expect(result.queue).toBe('NEEDS_ISSUE');
    expect(result.items).toHaveLength(1);
    expect(result.items[0].billing_status).toBe('DRAFT');
  });

  it('rejects unauthorized users without billing:read on NEEDS_ISSUE queue', async () => {
    await expect(
      billingService.getWorkItems(
        { queue: 'NEEDS_ISSUE' },
        1,
        20,
        { id: 'user-1', tenant_id: 'tenant-1', permissions: [] }
      )
    ).rejects.toMatchObject({ statusCode: 403 });
  });
});

describe('billing.service Needs issue tab mutations post through Billing', () => {
  const writer = {
    id: 'user-billing',
    tenant_id: 'tenant-1',
    facility_id: 'facility-1',
    permissions: ['billing:read', 'billing:write'],
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('issueInvoice updates DRAFT to ISSUED and emits realtime events', async () => {
    resolveModelRecordByIdentifier.mockImplementation(async ({ model }) => {
      if (model === 'invoice') {
        return {
          id: 'inv-draft',
          human_friendly_id: 'INV-DRAFT',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          status: 'DRAFT',
          billing_status: 'DRAFT',
          total_amount: '120.00',
          items: [{ id: 'line-1', description: 'Lab', metadata_json: { source_module: 'Laboratory' } }],
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
      total_amount: '120.00',
      items: [{ id: 'line-1', description: 'Lab' }],
      payments: [],
      adjustments: [],
    });

    const result = await billingService.issueInvoice(
      'INV-DRAFT',
      { notes: 'Needs issue scan' },
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

  it('issueInvoice replay on already ISSUED invoice is idempotent (no duplicate charge)', async () => {
    resolveModelRecordByIdentifier.mockImplementation(async ({ model }) => {
      if (model === 'invoice') {
        return {
          id: 'inv-issued',
          human_friendly_id: 'INV-ISSUED',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          status: 'SENT',
          billing_status: 'ISSUED',
          total_amount: '120.00',
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
      total_amount: '120.00',
      items: [],
      payments: [],
      adjustments: [],
    });

    const result = await billingService.issueInvoice(
      'INV-ISSUED',
      {},
      writer,
      '127.0.0.1'
    );

    expect(billingRepository.updateInvoice).toHaveBeenCalledWith(
      'inv-issued',
      expect.objectContaining({ billing_status: 'ISSUED', status: 'SENT' })
    );
    expect(result.invoice.billing_status).toBe('ISSUED');
  });

  it('issueInvoice rejects cancelled invoices', async () => {
    resolveModelRecordByIdentifier.mockImplementation(async ({ model }) => {
      if (model === 'invoice') {
        return {
          id: 'inv-cancelled',
          human_friendly_id: 'INV-CANCEL',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          status: 'CANCELLED',
          billing_status: 'CANCELLED',
          total_amount: '50.00',
        };
      }
      return null;
    });

    await expect(
      billingService.issueInvoice('INV-CANCEL', {}, writer, '127.0.0.1')
    ).rejects.toMatchObject({
      messageKey: 'errors.invoice.cannot_issue_cancelled',
      statusCode: 400,
    });

    expect(billingRepository.updateInvoice).not.toHaveBeenCalled();
  });
});
