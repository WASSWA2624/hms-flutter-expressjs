jest.mock('@prisma/client', () => ({
  subscription: { findFirst: jest.fn(), findMany: jest.fn() },
  module: { findMany: jest.fn() },
  module_subscription: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    create: jest.fn(),
    update: jest.fn()}}));

const prisma = require('@prisma/client');
const {
  syncSubscriptionModuleEntitlements} = require('@lib/subscriptions/sync-subscription-module-entitlements');

describe('syncSubscriptionModuleEntitlements', () => {
  const modules = [
    {
      id: 'platform',
      slug: 'platform-identity',
      extension_json: { is_platform_infrastructure: true },
      minimum_plan_tier_code: 'FREE'},
    {
      id: 'patient',
      slug: 'patient-registry',
      extension_json: null,
      minimum_plan_tier_code: 'FREE'},
    {
      id: 'lab',
      slug: 'lab-workflows',
      extension_json: null,
      minimum_plan_tier_code: 'ADVANCED'}];

  beforeEach(() => {
    jest.clearAllMocks();
    prisma.module.findMany.mockResolvedValue(modules);
    prisma.module_subscription.findFirst.mockResolvedValue(null);
    prisma.module_subscription.findMany.mockResolvedValue([]);
    prisma.module_subscription.create.mockResolvedValue({});
  });

  it('bounds a developer plan to Free defaults in production', async () => {
    const previousNodeEnv = process.env.NODE_ENV;
    process.env.NODE_ENV = 'production';
    prisma.subscription.findFirst.mockResolvedValue({
      id: 'subscription-1',
      plan: {
        tier_code: 'DEVELOPER',
        extension_json: {
          is_developer_plan: true,
          includes_all_modules: true}}});
    try {
      await syncSubscriptionModuleEntitlements('subscription-1');
    } finally {
      process.env.NODE_ENV = previousNodeEnv;
    }

    const createdModuleIds =
      prisma.module_subscription.create.mock.calls.map(
        ([call]) => call.data.module_id
      );
    expect(createdModuleIds).toEqual(
      expect.arrayContaining(['platform', 'patient'])
    );
    expect(createdModuleIds).not.toContain('lab');
  });

  it('requires an explicit module allowlist for custom plans', async () => {
    prisma.subscription.findFirst.mockResolvedValue({
      id: 'subscription-1',
      plan: {
        tier_code: 'CUSTOM',
        extension_json: {
          allowed_modules: { included: ['lab'] }}}});

    await syncSubscriptionModuleEntitlements('subscription-1');

    const createdModuleIds =
      prisma.module_subscription.create.mock.calls.map(
        ([call]) => call.data.module_id
      );
    expect(createdModuleIds).toEqual(
      expect.arrayContaining(['platform', 'lab'])
    );
    expect(createdModuleIds).not.toContain('patient');
  });
});
