jest.mock('@repositories/billing/billing.repository', () => ({
  findManyInvoices: jest.fn(),
  countInvoices: jest.fn(),
  findManyClaims: jest.fn(),
  countClaims: jest.fn(),
  findManyPreAuthorizations: jest.fn(),
  countPreAuthorizations: jest.fn(),
  findManyApprovals: jest.fn(),
  countApprovals: jest.fn(),
}));

jest.mock('@config/feature-flags', () => ({
  isFeatureEnabled: jest.fn(() => true),
}));

jest.mock('@lib/billing/clinical-request-billing', () => ({
  resolveClinicalInvoiceContexts: jest.fn(async () => ({})),
}));

const billingRepository = require('@repositories/billing/billing.repository');
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
