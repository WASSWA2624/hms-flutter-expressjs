jest.mock('@repositories/subscriptions-workspace/subscriptions-workspace.repository');
jest.mock('@lib/billing/identifiers', () => ({
  resolveIdentifierForFilter: jest.fn(),
  resolvePublicIdentifier: jest.fn((...values) => values.find(Boolean) || null),
}));

const repository = require('@repositories/subscriptions-workspace/subscriptions-workspace.repository');
const identifiers = require('@lib/billing/identifiers');
const subject = require('../../../../modules/subscriptions-workspace/services/subscriptions-workspace.service');

describe('subscriptions-workspace.service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    repository.findSummary.mockResolvedValue({
      active_subscriptions: 4,
      pending_changes: 1,
      past_due_invoices: 2,
      denied_modules: 1,
      expiring_licenses: 1,
      approaching_limits: 2,
    });
    repository.findLookups.mockResolvedValue({
      tenants: [{ id: 'tenant-uuid', human_friendly_id: 'TEN0001', name: 'Acme' }],
      plans: [{ id: 'plan-uuid', human_friendly_id: 'PLAN0001', name: 'Pro', tier_code: 'PRO' }],
      modules: [{ id: 'module-uuid', human_friendly_id: 'MOD0001', name: 'LIS', slug: 'lis' }],
      module_groups: [{ id: '11', label: 'Group 11' }],
      invoices: [
        {
          id: 'invoice-uuid',
          human_friendly_id: 'INV0001',
          status: 'OVERDUE',
          billing_status: 'PENDING',
          issued_at: '2026-03-01T00:00:00.000Z',
          total_amount: 120,
          currency: 'USD',
        },
      ],
    });
    repository.findOverview.mockResolvedValue({
      current_subscription: {
        id: 'subscription-uuid',
        human_friendly_id: 'SUB0001',
        tenant_id: 'tenant-uuid',
        tenant: { id: 'tenant-uuid', human_friendly_id: 'TEN0001', name: 'Acme' },
        plan_id: 'plan-uuid',
        plan: {
          id: 'plan-uuid',
          human_friendly_id: 'PLAN0001',
          name: 'Pro',
          tier_code: 'PRO',
          billing_cycle: 'MONTHLY',
          price: 49,
        },
        status: 'ACTIVE',
        change_status: 'PENDING',
        users_used: 12,
        facilities_used: 2,
        storage_used_mb: 600,
        modules_used: 4,
      },
      next_invoice: {
        id: 'subscription-invoice-uuid',
        human_friendly_id: 'SUBINV0001',
        subscription_id: 'subscription-uuid',
        subscription: {
          id: 'subscription-uuid',
          human_friendly_id: 'SUB0001',
          tenant_id: 'tenant-uuid',
          tenant: { id: 'tenant-uuid', human_friendly_id: 'TEN0001', name: 'Acme' },
          plan_id: 'plan-uuid',
          plan: { id: 'plan-uuid', human_friendly_id: 'PLAN0001', name: 'Pro' },
        },
        invoice_id: 'invoice-uuid',
        invoice: {
          id: 'invoice-uuid',
          human_friendly_id: 'INV0001',
          status: 'OVERDUE',
          billing_status: 'PENDING',
          total_amount: 120,
          currency: 'USD',
          issued_at: '2026-03-01T00:00:00.000Z',
        },
      },
      licenses: [
        {
          id: 'license-uuid',
          human_friendly_id: 'LIC0001',
          tenant_id: 'tenant-uuid',
          tenant: { id: 'tenant-uuid', human_friendly_id: 'TEN0001', name: 'Acme' },
          license_type: 'PER_USER',
          status: 'ACTIVE',
          plan_tier_code: 'PRO',
          expires_at: '2026-04-01T00:00:00.000Z',
        },
      ],
      denied_modules_count: 1,
    });
    repository.findItems.mockResolvedValue({
      items: [
        {
          id: 'subscription-uuid',
          human_friendly_id: 'SUB0001',
          tenant_id: 'tenant-uuid',
          tenant: { id: 'tenant-uuid', human_friendly_id: 'TEN0001', name: 'Acme' },
          plan_id: 'plan-uuid',
          plan: { id: 'plan-uuid', human_friendly_id: 'PLAN0001', name: 'Pro' },
          status: 'ACTIVE',
        },
      ],
      total: 1,
    });
    repository.findTimeline.mockResolvedValue({
      subscriptions: [
        {
          id: 'subscription-uuid',
          human_friendly_id: 'SUB0001',
          tenant_id: 'tenant-uuid',
          tenant: { id: 'tenant-uuid', human_friendly_id: 'TEN0001', name: 'Acme' },
          plan_id: 'plan-uuid',
          plan: { id: 'plan-uuid', human_friendly_id: 'PLAN0001', name: 'Pro' },
          status: 'ACTIVE',
          updated_at: '2026-03-02T00:00:00.000Z',
        },
      ],
      moduleSubscriptions: [],
      invoices: [],
      licenses: [],
    });
    repository.resolveLegacyRecord.mockResolvedValue({
      id: 'subscription-uuid',
      human_friendly_id: 'SUB0001',
    });
    identifiers.resolveIdentifierForFilter.mockResolvedValue(undefined);
  });

  it('exports workspace service methods', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject)).toEqual(
      expect.arrayContaining(['getWorkspace', 'getReferenceData', 'resolveLegacyRoute'])
    );
  });

  it('builds workspace payloads with public identifiers and pagination metadata', async () => {
    const result = await subject.getWorkspace(
      { panel: 'operations', resource: 'subscriptions' },
      1,
      20,
      'updated_at',
      'desc',
      { role: 'SUPER_ADMIN' }
    );

    expect(result.summary).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ id: 'active_subscriptions', value: 4 }),
      ])
    );
    expect(result.items).toEqual([
      expect.objectContaining({
        id: 'SUB0001',
        display_id: 'SUB0001',
        tenant_label: 'Acme',
      }),
    ]);
    expect(result.pagination).toEqual(
      expect.objectContaining({
        page: 1,
        limit: 20,
        total: 1,
        totalPages: 1,
      })
    );
    expect(result.overview.current_subscription).toEqual(
      expect.objectContaining({
        id: 'SUB0001',
        plan_label: 'Pro',
        tenant_label: 'Acme',
      })
    );
    expect(result.queue_summaries).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ queue: 'PAST_DUE' }),
      ])
    );
  });

  it('resolves legacy routes into workbench state with public identifiers', async () => {
    const result = await subject.resolveLegacyRoute(
      'subscriptions',
      'SUB0001',
      { role: 'SUPER_ADMIN' }
    );

    expect(repository.resolveLegacyRecord).toHaveBeenCalledWith(
      'subscriptions',
      'SUB0001',
      ''
    );
    expect(result).toEqual(
      expect.objectContaining({
        panel: 'operations',
        resource: 'subscriptions',
        id: 'SUB0001',
        action: 'view',
      })
    );
  });

  it('applies date presets and safe nested invoice sorting for billing workspace lists', async () => {
    await subject.getWorkspace(
      {
        panel: 'billing',
        resource: 'subscription-invoices',
        datePreset: 'next_30_days',
        queue: 'PAST_DUE',
      },
      1,
      20,
      'issued_at',
      'asc',
      { role: 'SUPER_ADMIN' }
    );

    expect(repository.findItems).toHaveBeenCalledWith(
      expect.objectContaining({
        resource: 'subscription-invoices',
        orderBy: { invoice: { issued_at: 'asc' } },
        filters: expect.objectContaining({
          queue: 'PAST_DUE',
          date_window: expect.objectContaining({
            field: 'invoice.issued_at',
            from: expect.any(Date),
            to: expect.any(Date),
          }),
        }),
      })
    );
  });

  it('maps pending change queue to subscriptions workspace filters', async () => {
    await subject.getWorkspace(
      {
        panel: 'operations',
        resource: 'subscriptions',
        queue: 'PENDING_CHANGES',
      },
      1,
      20,
      'change_status',
      'desc',
      { role: 'SUPER_ADMIN' }
    );

    expect(repository.findItems).toHaveBeenCalledWith(
      expect.objectContaining({
        resource: 'subscriptions',
        filters: expect.objectContaining({
          queue: 'PENDING_CHANGES',
        }),
      })
    );
  });
});
