const subscriptionService = require('../../../../modules/subscription/services/subscription.service');
const subscriptionRepository = require('../../../../modules/subscription/repositories/subscription.repository');
const subscriptionPlanRepository = require('../../../../modules/subscription-plan/repositories/subscription-plan.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

jest.mock('../../../../modules/subscription/repositories/subscription.repository');
jest.mock('../../../../modules/subscription-plan/repositories/subscription-plan.repository');
jest.mock('@lib/audit');
jest.mock('@lib/billing/identifiers', () => ({
  resolveEntityId: jest.fn(async ({ identifier }) => identifier),
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value),
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value),
  resolvePublicIdentifier: jest.fn((...values) => values.find(Boolean) || null),
}));

const buildSubscriptionRecord = (overrides = {}) => ({
  id: 'subscription-uuid',
  human_friendly_id: 'SUB0001',
  tenant_id: 'tenant-uuid',
  tenant: {
    id: 'tenant-uuid',
    human_friendly_id: 'TEN0001',
    name: 'Acme Hospital',
  },
  plan_id: 'plan-uuid',
  plan: {
    id: 'plan-uuid',
    human_friendly_id: 'PLAN0001',
    name: 'Pro',
    code: 'PRO',
    tier_code: 'PRO',
    billing_cycle: 'MONTHLY',
    price: 49,
    plan_fit_warning_percent: 80,
  },
  pending_plan_id: null,
  pending_plan: null,
  status: 'ACTIVE',
  change_status: 'NONE',
  start_date: '2026-01-01T00:00:00.000Z',
  end_date: '2026-02-01T00:00:00.000Z',
  users_used: 10,
  facilities_used: 2,
  storage_used_mb: 512,
  modules_used: 3,
  module_subscriptions: [],
  ...overrides,
});

describe('Subscription Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  it('returns serialized public subscription details', async () => {
    subscriptionRepository.findById.mockResolvedValue(buildSubscriptionRecord());

    await expect(subscriptionService.getSubscriptionById('SUB0001')).resolves.toEqual(
      expect.objectContaining({
        id: 'SUB0001',
        display_id: 'SUB0001',
        tenant_id: 'TEN0001',
        tenant_label: 'Acme Hospital',
        plan_id: 'PLAN0001',
        plan_label: 'Pro',
      })
    );
  });

  it('lists subscriptions with serialized rows and pagination', async () => {
    subscriptionRepository.findMany.mockResolvedValue([
      buildSubscriptionRecord(),
      buildSubscriptionRecord({
        id: 'subscription-uuid-2',
        human_friendly_id: 'SUB0002',
      }),
    ]);
    subscriptionRepository.count.mockResolvedValue(2);

    const result = await subscriptionService.listSubscriptions(
      { status: 'ACTIVE', search: 'Acme' },
      1,
      20
    );

    expect(subscriptionRepository.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        status: 'ACTIVE',
        OR: expect.any(Array),
      }),
      0,
      20,
      { created_at: 'desc' },
      expect.any(Object)
    );
    expect(result.subscriptions).toEqual([
      expect.objectContaining({ id: 'SUB0001' }),
      expect.objectContaining({ id: 'SUB0002' }),
    ]);
    expect(result.pagination).toEqual(
      expect.objectContaining({ total: 2, totalPages: 1 })
    );
  });

  it('creates a subscription, reloads it, and writes an audit log', async () => {
    const created = buildSubscriptionRecord({
      id: 'subscription-uuid-2',
      human_friendly_id: 'SUB0002',
      change_status: 'NONE',
    });
    subscriptionRepository.create.mockResolvedValue({ id: created.id });
    subscriptionRepository.findById.mockResolvedValue(created);

    const result = await subscriptionService.createSubscription(
      {
        tenant_id: 'TEN0001',
        plan_id: 'PLAN0001',
        human_friendly_id: 'SUB0002',
      },
      { id: 'user-1', role: 'SUPER_ADMIN' },
      '127.0.0.1'
    );

    expect(subscriptionRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'TEN0001',
        plan_id: 'PLAN0001',
        human_friendly_id: 'SUB0002',
        status: 'ACTIVE',
        start_date: expect.any(String),
      })
    );
    expect(result).toEqual(expect.objectContaining({ id: 'SUB0002' }));
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entity: 'subscription',
        user_id: 'user-1',
      })
    );
  });

  it('updates a subscription and records an audit diff', async () => {
    const before = buildSubscriptionRecord();
    const after = buildSubscriptionRecord({
      status: 'PAST_DUE',
      users_used: 12,
    });
    subscriptionRepository.findById
      .mockResolvedValueOnce(before)
      .mockResolvedValueOnce(after);
    subscriptionRepository.update.mockResolvedValue(after);

    const result = await subscriptionService.updateSubscription(
      'SUB0001',
      { status: 'PAST_DUE' },
      { id: 'user-2', role: 'SUPER_ADMIN' },
      '127.0.0.1'
    );

    expect(result).toEqual(
      expect.objectContaining({
        id: 'SUB0001',
        status: 'PAST_DUE',
      })
    );
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'UPDATE',
        diff: { before, after },
      })
    );
  });

  it('returns proration preview using public identifiers', async () => {
    subscriptionRepository.findById.mockResolvedValue(
      buildSubscriptionRecord({
        end_date: '2099-02-01T00:00:00.000Z',
        pending_plan_id: 'plan-upgrade-uuid',
        pending_plan: {
          id: 'plan-upgrade-uuid',
          human_friendly_id: 'PLAN0002',
          name: 'Advanced',
          price: 99,
        },
      })
    );

    const result = await subscriptionService.getSubscriptionProrationPreview(
      'SUB0001'
    );

    expect(result).toEqual(
      expect.objectContaining({
        subscription_id: 'SUB0001',
        current_plan_id: 'PLAN0001',
        target_plan_id: 'PLAN0002',
      })
    );
    expect(typeof result.proration_amount).toBe('number');
  });

  it('recommends the first compatible plan when active modules require broader entitlements', async () => {
    subscriptionRepository.findById.mockResolvedValue(
      buildSubscriptionRecord({
        plan: {
          id: 'plan-basic-uuid',
          human_friendly_id: 'PLAN0001',
          name: 'Basic',
          code: 'BASIC',
          tier_code: 'BASIC',
          billing_cycle: 'MONTHLY',
          price: 29,
          extension_json: {
            allowed_modules: {
              included: ['appointments'],
            },
          },
        },
        module_subscriptions: [
          {
            id: 'module-subscription-1',
            human_friendly_id: 'MSUB0001',
            is_active: true,
            module: {
              id: 'module-analytics-uuid',
              human_friendly_id: 'MOD0001',
              name: 'Analytics',
              slug: 'analytics',
              minimum_plan_tier_code: 'BASIC',
              is_add_on: true,
            },
          },
        ],
      })
    );
    subscriptionPlanRepository.findMany.mockResolvedValue([
      {
        id: 'plan-pro-uuid',
        human_friendly_id: 'PLAN0002',
        name: 'Professional',
        code: 'PRO',
        tier_code: 'PRO',
        price: 49,
        extension_json: {
          allowed_modules: {
            included: ['appointments', 'analytics'],
          },
        },
      },
      {
        id: 'plan-custom-uuid',
        human_friendly_id: 'PLAN0003',
        name: 'Custom',
        code: 'CUSTOM',
        tier_code: 'CUSTOM',
        price: 99,
      },
    ]);

    const result = await subscriptionService.getSubscriptionUpgradeRecommendation(
      'SUB0001',
      { role: 'SUPER_ADMIN' }
    );

    expect(result).toEqual(
      expect.objectContaining({
        subscription_id: 'SUB0001',
        recommended_plan_id: 'PLAN0002',
        recommendation: 'upgrade_required',
      })
    );
  });

  it('falls back to a custom plan when no standard plan can satisfy the active module set', async () => {
    subscriptionRepository.findById.mockResolvedValue(
      buildSubscriptionRecord({
        plan: {
          id: 'plan-pro-uuid',
          human_friendly_id: 'PLAN0001',
          name: 'Professional',
          code: 'PRO',
          tier_code: 'PRO',
          billing_cycle: 'MONTHLY',
          price: 49,
        },
        module_subscriptions: [
          {
            id: 'module-subscription-1',
            human_friendly_id: 'MSUB0001',
            is_active: true,
            module: {
              id: 'module-biomed-uuid',
              human_friendly_id: 'MOD0001',
              name: 'Biomedical Suite',
              slug: 'biomedical-suite',
              minimum_plan_tier_code: 'PRO',
              is_add_on: true,
              entitlement_policy_json: {
                requires_customization: true,
              },
            },
          },
        ],
      })
    );
    subscriptionPlanRepository.findMany.mockResolvedValue([
      {
        id: 'plan-advanced-uuid',
        human_friendly_id: 'PLAN0002',
        name: 'Advanced',
        code: 'ADVANCED',
        tier_code: 'ADVANCED',
        price: 79,
      },
      {
        id: 'plan-custom-uuid',
        human_friendly_id: 'PLAN0003',
        name: 'Custom',
        code: 'CUSTOM',
        tier_code: 'CUSTOM',
        price: 109,
        extension_json: {
          allowed_modules: {
            included: ['biomedical-suite'],
          },
        },
      },
    ]);

    const result = await subscriptionService.getSubscriptionUpgradeRecommendation(
      'SUB0001',
      { role: 'SUPER_ADMIN' }
    );

    expect(result).toEqual(
      expect.objectContaining({
        subscription_id: 'SUB0001',
        recommended_plan_id: 'PLAN0003',
        recommended_tier: 'CUSTOM',
        recommendation: 'upgrade_required',
      })
    );
  });

  it('throws HttpError when the subscription does not exist', async () => {
    subscriptionRepository.findById.mockResolvedValue(null);

    await expect(subscriptionService.getSubscriptionById('SUB404')).rejects.toThrow(
      HttpError
    );
  });
});
