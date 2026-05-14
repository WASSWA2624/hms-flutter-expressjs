const subscriptionPlanService = require('../../../../modules/subscription-plan/services/subscription-plan.service');
const subscriptionPlanRepository = require('../../../../modules/subscription-plan/repositories/subscription-plan.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

jest.mock('../../../../modules/subscription-plan/repositories/subscription-plan.repository');
jest.mock('@lib/audit');
jest.mock('@lib/billing/identifiers', () => ({
  resolveEntityId: jest.fn(async ({ identifier }) => identifier),
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value),
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value),
  resolvePublicIdentifier: jest.fn((...values) => values.find(Boolean) || null),
}));

const buildPlanRecord = (overrides = {}) => ({
  id: 'plan-uuid',
  human_friendly_id: 'PLAN0001',
  tenant_id: 'tenant-uuid',
  tenant: {
    id: 'tenant-uuid',
    human_friendly_id: 'TEN0001',
    name: 'Acme Hospital',
  },
  code: 'PRO',
  name: 'Professional',
  tier_code: 'PRO',
  price: 49,
  billing_cycle: 'MONTHLY',
  max_users: 50,
  max_facilities: 5,
  max_storage_mb: 2048,
  max_modules: 10,
  plan_fit_warning_percent: 80,
  add_on_eligibility_json: { add_ons: ['analytics'] },
  limit_policy_json: { hard_stop: true },
  _count: { subscriptions: 3 },
  ...overrides,
});

describe('Subscription Plan Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  it('returns serialized plan details with public identifiers', async () => {
    subscriptionPlanRepository.findById.mockResolvedValue(buildPlanRecord());

    await expect(subscriptionPlanService.getSubscriptionPlanById('PLAN0001')).resolves.toEqual(
      expect.objectContaining({
        id: 'PLAN0001',
        tenant_id: 'TEN0001',
        tenant_label: 'Acme Hospital',
        name: 'Professional',
        subscription_count: 3,
      })
    );
  });

  it('lists plans with pagination and include graph', async () => {
    subscriptionPlanRepository.findMany.mockResolvedValue([
      buildPlanRecord(),
      buildPlanRecord({
        id: 'plan-uuid-2',
        human_friendly_id: 'PLAN0002',
        name: 'Advanced',
      }),
    ]);
    subscriptionPlanRepository.count.mockResolvedValue(2);

    const result = await subscriptionPlanService.listSubscriptionPlans(
      { billing_cycle: 'MONTHLY', search: 'Pro' },
      1,
      20
    );

    expect(subscriptionPlanRepository.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        billing_cycle: 'MONTHLY',
        OR: expect.any(Array),
      }),
      0,
      20,
      { created_at: 'desc' },
      expect.any(Object)
    );
    expect(result.subscriptionPlans).toEqual([
      expect.objectContaining({ id: 'PLAN0001' }),
      expect.objectContaining({ id: 'PLAN0002' }),
    ]);
  });

  it('creates a plan, reloads it, and writes an audit log', async () => {
    const created = buildPlanRecord({
      id: 'plan-uuid-2',
      human_friendly_id: 'PLAN0002',
      name: 'Advanced',
    });
    subscriptionPlanRepository.create.mockResolvedValue({ id: created.id });
    subscriptionPlanRepository.findById.mockResolvedValue(created);

    const result = await subscriptionPlanService.createSubscriptionPlan(
      {
        tenant_id: 'TEN0001',
        human_friendly_id: 'PLAN0002',
        name: 'Advanced',
        price: 99,
        billing_cycle: 'MONTHLY',
      },
      { id: 'user-1', role: 'SUPER_ADMIN' },
      '127.0.0.1'
    );

    expect(result).toEqual(expect.objectContaining({ id: 'PLAN0002' }));
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entity: 'subscription_plan',
      })
    );
  });

  it('returns add-on eligibility based on plan tier', async () => {
    subscriptionPlanRepository.findById.mockResolvedValue(buildPlanRecord());

    const result = await subscriptionPlanService.getPlanAddOnEligibility('PLAN0001');

    expect(result).toEqual(
      expect.objectContaining({
        subscription_plan_id: 'PLAN0001',
        tier_code: 'PRO',
        add_ons: expect.arrayContaining([
          expect.objectContaining({
            code: 'biomedical_engineering_suite',
            eligible: true,
          }),
        ]),
      })
    );
  });

  it('returns configured allowlists for bespoke plan entitlements', async () => {
    subscriptionPlanRepository.findById.mockResolvedValue(
      buildPlanRecord({
        extension_json: {
          allowed_modules: {
            included: ['core-messaging', 'biomed'],
            blocked: ['analytics'],
            notes: 'Upgrade customers can unlock biomedical on approval.',
          },
          add_on_module_ids: ['extra-storage'],
        },
        add_on_eligibility_json: {
          allowed_module_ids: ['extra-storage'],
        },
      })
    );

    const result = await subscriptionPlanService.getPlanEntitlements('PLAN0001');

    expect(result).toEqual(
      expect.objectContaining({
        subscription_plan_id: 'PLAN0001',
        allowed_modules: {
          included: ['core-messaging', 'biomed'],
          blocked: ['analytics'],
          add_on_eligible: ['extra-storage'],
          customization_notes:
            'Upgrade customers can unlock biomedical on approval.',
        },
      })
    );
  });

  it('throws HttpError when the plan does not exist', async () => {
    subscriptionPlanRepository.findById.mockResolvedValue(null);

    await expect(subscriptionPlanService.getSubscriptionPlanById('PLAN404')).rejects.toThrow(
      HttpError
    );
  });
});
