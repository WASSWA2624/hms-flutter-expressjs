const { HttpError } = require('@lib/errors');
const moduleSubscriptionRepository = require('@repositories/module-subscription/module-subscription.repository');
const { createAuditLog } = require('@lib/audit');
const subject = require('@services/module-subscription/module-subscription.service');

jest.mock('@repositories/module-subscription/module-subscription.repository');
jest.mock('@lib/audit');
jest.mock('@lib/billing/identifiers', () => ({
  resolveEntityId: jest.fn(async ({ identifier }) => identifier),
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value),
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value),
  resolvePublicIdentifier: jest.fn((...values) => values.find(Boolean) || null),
}));

const buildRecord = (overrides = {}) => ({
  id: 'module-subscription-uuid',
  human_friendly_id: 'MSUB0001',
  subscription_id: 'subscription-uuid',
  subscription: {
    id: 'subscription-uuid',
    human_friendly_id: 'SUB0001',
    tenant_id: 'tenant-uuid',
    tenant: { id: 'tenant-uuid', human_friendly_id: 'TEN0001', name: 'Acme' },
    plan: { id: 'plan-uuid', human_friendly_id: 'PLAN0001', name: 'Pro', tier_code: 'PRO' },
    plan_fit_status: 'GOOD',
  },
  module_id: 'module-uuid',
  module: {
    id: 'module-uuid',
    human_friendly_id: 'MOD0001',
    name: 'LIS',
    slug: 'lis',
    minimum_plan_tier_code: 'PRO',
  },
  is_active: true,
  entitlement_denied: false,
  entitlement_denial_reason: null,
  ...overrides,
});

describe('Module Subscription Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  it('returns serialized module subscription details', async () => {
    moduleSubscriptionRepository.findById.mockResolvedValue(buildRecord());

    await expect(subject.getModuleSubscriptionById('MSUB0001')).resolves.toEqual(
      expect.objectContaining({
        id: 'MSUB0001',
        subscription_id: 'SUB0001',
        module_id: 'MOD0001',
        module_label: 'LIS',
        tenant_label: 'Acme',
      })
    );
  });

  it('lists module subscriptions with serialized rows and pagination', async () => {
    moduleSubscriptionRepository.findMany.mockResolvedValue([
      buildRecord(),
      buildRecord({
        id: 'module-subscription-uuid-2',
        human_friendly_id: 'MSUB0002',
      }),
    ]);
    moduleSubscriptionRepository.count.mockResolvedValue(2);

    const result = await subject.listModuleSubscriptions(
      { module_id: 'MOD0001' },
      1,
      20
    );

    expect(moduleSubscriptionRepository.findMany).toHaveBeenCalledWith(
      { module_id: 'MOD0001' },
      0,
      20,
      { created_at: 'desc' }
    );
    expect(result.module_subscriptions).toEqual([
      expect.objectContaining({ id: 'MSUB0001' }),
      expect.objectContaining({ id: 'MSUB0002' }),
    ]);
  });

  it('creates a module subscription, reloads it, and audits the change', async () => {
    const created = buildRecord({
      id: 'module-subscription-uuid-2',
      human_friendly_id: 'MSUB0002',
    });
    moduleSubscriptionRepository.create.mockResolvedValue({ id: created.id });
    moduleSubscriptionRepository.findById.mockResolvedValue(created);

    const result = await subject.createModuleSubscription(
      {
        module_id: 'MOD0001',
        subscription_id: 'SUB0001',
        human_friendly_id: 'MSUB0002',
      },
      {
        user: { id: 'user-1', role: 'SUPER_ADMIN' },
        ip: '127.0.0.1',
        tenant_id: 'tenant-uuid',
      }
    );

    expect(result).toEqual(expect.objectContaining({ id: 'MSUB0002' }));
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entity: 'module_subscription',
      })
    );
  });

  it('marks denied entitlement when the plan tier is below the module minimum', async () => {
    const before = buildRecord({
      subscription: {
        ...buildRecord().subscription,
        plan: {
          id: 'plan-uuid',
          human_friendly_id: 'PLAN0001',
          name: 'Basic',
          tier_code: 'BASIC',
        },
      },
      module: {
        ...buildRecord().module,
        minimum_plan_tier_code: 'PRO',
      },
    });
    const after = {
      ...before,
      entitlement_denied: true,
      entitlement_denial_reason: 'requires_PRO',
      eligibility_checked_at: '2026-03-01T00:00:00.000Z',
    };
    moduleSubscriptionRepository.findById
      .mockResolvedValueOnce(before)
      .mockResolvedValueOnce(after);
    moduleSubscriptionRepository.update.mockResolvedValue(after);

    const result = await subject.checkModuleSubscriptionEligibility('MSUB0001');

    expect(result).toEqual(
      expect.objectContaining({
        module_subscription_id: 'MSUB0001',
        eligible: false,
        reason: 'requires_PRO',
      })
    );
  });

  it('marks denied entitlement when subscription customization blocks the module', async () => {
    const before = buildRecord({
      subscription: {
        ...buildRecord().subscription,
        extension_json: {
          module_overrides: {
            blocked: ['lis'],
          },
        },
      },
      module: {
        ...buildRecord().module,
        slug: 'lis',
      },
    });
    const after = {
      ...before,
      entitlement_denied: true,
      entitlement_denial_reason: 'blocked_by_subscription_customization',
      eligibility_checked_at: '2026-03-01T00:00:00.000Z',
    };
    moduleSubscriptionRepository.findById
      .mockResolvedValueOnce(before)
      .mockResolvedValueOnce(after);
    moduleSubscriptionRepository.update.mockResolvedValue(after);

    const result = await subject.checkModuleSubscriptionEligibility('MSUB0001');

    expect(result).toEqual(
      expect.objectContaining({
        module_subscription_id: 'MSUB0001',
        eligible: false,
        reason: 'blocked_by_subscription_customization',
      })
    );
  });

  it('throws HttpError when the module subscription does not exist', async () => {
    moduleSubscriptionRepository.findById.mockResolvedValue(null);

    await expect(subject.getModuleSubscriptionById('MSUB404')).rejects.toThrow(
      HttpError
    );
  });
});
