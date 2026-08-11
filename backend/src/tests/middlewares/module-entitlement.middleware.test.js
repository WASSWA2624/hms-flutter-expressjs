const invokeMiddleware = (middleware, req, res = {}) =>
  new Promise((resolve) => {
    middleware(req, res, (error) => resolve(error));
  });

describe('module entitlement middleware', () => {
  let moduleRepository;
  let moduleSubscriptionRepository;
  let subscriptionRepository;
  let prismaMock;

  const platformModules = [
    {
      slug: 'platform-facility-structure',
      extension_json: {
        is_platform_infrastructure: true,
        api_path_segments: ['branch', 'branches', 'facility']}},
    {
      slug: 'platform-workspace-shell',
      extension_json: {
        is_platform_infrastructure: true,
        api_path_segments: ['dashboard-workspace']}}];

  const loadMiddleware = () => {
    jest.resetModules();

    moduleRepository = {
      count: jest.fn()};
    moduleSubscriptionRepository = {
      count: jest.fn()};
    subscriptionRepository = {
      count: jest.fn()};
    prismaMock = {
      module: {
        findMany: jest.fn().mockResolvedValue(platformModules),
        findFirst: jest.fn().mockResolvedValue(null)},
      subscription: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'sub-1',
          tenant_id: 'tenant-1',
          status: 'ACTIVE',
          plan: { tier_code: 'FREE', extension_json: { allowed_modules: { included: [] } } }})}};

    jest.doMock('@repositories/module/module.repository', () => moduleRepository);
    jest.doMock(
      '@repositories/module-subscription/module-subscription.repository',
      () => moduleSubscriptionRepository
    );
    jest.doMock(
      '@repositories/subscription/subscription.repository',
      () => subscriptionRepository
    );
    jest.doMock('@prisma/client', () => prismaMock);

    return require('@middlewares/module-entitlement.middleware');
  };

  test('allows platform infrastructure paths without commercial entitlement lookup', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      user: { tenant_id: 'tenant-free', roles: ['PLATFORM_ADMIN'] }};

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeUndefined();
    expect(moduleRepository.count).not.toHaveBeenCalled();
    expect(moduleSubscriptionRepository.count).not.toHaveBeenCalled();
  });

  test('allows dashboard workspace as platform infrastructure', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/dashboard-workspace/workspace',
      user: { tenant_id: 'tenant-dashboard', roles: ['PLATFORM_ADMIN'] }};

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeUndefined();
    expect(moduleSubscriptionRepository.count).not.toHaveBeenCalled();
  });

  test('evaluates commercial patient paths via DB entitlement', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/patient-allergies',
      user: { tenant_id: 'tenant-patient-core', roles: ['DOCTOR'] }};

    moduleRepository.count.mockResolvedValue(1);
    moduleSubscriptionRepository.count.mockResolvedValue(1);

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeUndefined();
    expect(moduleRepository.count).toHaveBeenCalledWith({
      slug: 'patient-registry'});
    expect(moduleSubscriptionRepository.count).toHaveBeenCalledWith(
      expect.objectContaining({
        is_active: true,
        module: expect.objectContaining({
          slug: { in: ['patient-registry'] }})})
    );
  });

  test('blocks paid module when active subscription exists but tenant lacks entitlement', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/equipment-work-orders',
      user: { tenant_id: 'tenant-no-entitlement', roles: ['NURSE'] }};

    moduleRepository.count.mockResolvedValue(1);
    moduleSubscriptionRepository.count.mockResolvedValue(0);
    prismaMock.module.findFirst.mockResolvedValue({
      id: 'mod-biomed',
      slug: 'biomedical-engineering-suite',
      minimum_plan_tier_code: 'ADVANCED'});

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeDefined();
    expect(error.messageKey).toBe('errors.auth.module_not_entitled');
    expect(error.statusCode).toBe(403);
  });

  test('maps IPD flow endpoints to the inpatient subscription module slug', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/ipd-flows',
      user: { tenant_id: 'tenant-no-ipd', roles: ['NURSE'] }};

    moduleRepository.count.mockImplementation(async (filters = {}) =>
      filters.slug === 'inpatient-bed-management' ? 1 : 0
    );
    moduleSubscriptionRepository.count.mockResolvedValue(0);
    prismaMock.module.findFirst.mockResolvedValue({
      id: 'mod-ipd',
      slug: 'inpatient-bed-management',
      minimum_plan_tier_code: 'PRO'});

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(moduleRepository.count).toHaveBeenCalledWith({
      slug: 'inpatient-bed-management'});
    expect(moduleSubscriptionRepository.count).toHaveBeenCalledWith(
      expect.objectContaining({
        is_active: true,
        module: expect.objectContaining({
          slug: { in: ['inpatient-bed-management'] }})})
    );
    expect(error).toBeDefined();
    expect(error.messageKey).toBe('errors.auth.module_not_entitled');
  });

  test.each([
    ['/lab/workbench', 'lab-workflows'],
    ['/lab-orders', 'lab-workflows'],
    ['/facility-lab-catalog/tests', 'lab-workflows'],
    ['/radiology/workbench', 'radiology-workflows'],
    ['/radiology-orders', 'radiology-workflows'],
    ['/pharmacy/workbench', 'pharmacy-dispensing'],
    ['/pharmacy-orders', 'pharmacy-dispensing'],
    ['/invoices', 'billing-payments'],
    ['/payments', 'billing-payments'],
    ['/accounts/workspace', 'facility-accounts'],
    ['/accounts', 'facility-accounts'],
    ['/chart-accounts', 'facility-accounts'],
    ['/pre-authorizations', 'insurance-claims'],
    ['/insurance-claims', 'insurance-claims'],
    ['/api-keys', 'developer-tools'],
    ['/inventory-items', 'inventory-procurement-lite'],
    ['/purchase-orders', 'inventory-procurement-lite']])('maps %s to subscription module slug %s', async (path, expectedSlug) => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path,
      user: { tenant_id: 'tenant-entitled-diagnostics', roles: ['DOCTOR'] }};

    moduleRepository.count.mockImplementation(async (filters = {}) =>
      filters.slug === expectedSlug ? 1 : 0
    );
    moduleSubscriptionRepository.count.mockResolvedValue(1);

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeUndefined();
    expect(moduleRepository.count).toHaveBeenCalledWith({ slug: expectedSlug });
    expect(moduleSubscriptionRepository.count).toHaveBeenCalledWith(
      expect.objectContaining({
        is_active: true,
        module: expect.objectContaining({
          slug: expect.objectContaining({
            in: expect.arrayContaining([expectedSlug])})})})
    );
  });

  test.each([
    ['/triage', 'scheduling-queue'],
    ['/opd-flows', 'scheduling-queue'],
    ['/emergency-cases', 'scheduling-queue'],
    ['/icu-stays', 'icu-critical-care'],
    ['/hr/workspace', 'hr-rosters'],
    ['/maintenance-requests', 'facilities-maintenance'],
    ['/biomedical/workspace', 'biomedical-engineering-suite'],
    ['/reports-workspace/workspace', 'reporting-analytics'],
    ['/subscriptions-workspace/workspace', 'subscription-controls'],
    ['/integrations', 'integrations-core']])('maps %s to catalog module slug %s', async (path, expectedSlug) => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path,
      user: { tenant_id: 'tenant-entitled-workspace', roles: ['FACILITY_ADMIN'] }};

    moduleRepository.count.mockImplementation(async (filters = {}) =>
      filters.slug === expectedSlug ? 1 : 0
    );
    moduleSubscriptionRepository.count.mockResolvedValue(1);

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeUndefined();
    expect(moduleRepository.count).toHaveBeenCalledWith({ slug: expectedSlug });
  });

  test('allows mortuary from the core catalog fallback when module metadata is missing', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/mortuary',
      user: { tenant_id: 'tenant-advanced-demo', roles: ['MORTUARY_MANAGER'] }};

    moduleRepository.count.mockResolvedValue(0);
    subscriptionRepository.count.mockResolvedValue(1);

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeUndefined();
    expect(moduleRepository.count).toHaveBeenCalledWith({ slug: 'mortuary' });
    expect(subscriptionRepository.count).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'tenant-advanced-demo',
        plan: expect.objectContaining({
          tier_code: expect.objectContaining({
            in: expect.arrayContaining(['PRO', 'CUSTOM', 'DEVELOPER'])})})})
    );
  });

  test('blocks paid module when tenant has no active subscription', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/equipment-work-orders',
      user: { tenant_id: 'tenant-legacy', roles: ['NURSE'] }};

    prismaMock.subscription.findFirst.mockResolvedValue(null);

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeDefined();
    expect(error.messageKey).toBe('errors.auth.module_not_entitled');
    expect(error.statusCode).toBe(403);
    expect(error.errors).toEqual([
      expect.objectContaining({
        tenant_id: 'tenant-legacy',
        module: 'biomedical-engineering-suite',
        reason: 'subscription_required'})]);
    expect(moduleRepository.count).not.toHaveBeenCalled();
    expect(moduleSubscriptionRepository.count).not.toHaveBeenCalled();
  });

  test('allows physiotherapy from the core catalog fallback when module metadata is missing', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/therapy-flows',
      user: { tenant_id: 'tenant-advanced-demo', roles: ['NURSE'] }};

    moduleRepository.count.mockResolvedValue(0);
    subscriptionRepository.count.mockResolvedValue(1);

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeUndefined();
    expect(moduleRepository.count).toHaveBeenCalledWith({
      slug: 'physiotherapy'});
    expect(subscriptionRepository.count).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'tenant-advanced-demo',
        plan: expect.objectContaining({
          tier_code: expect.objectContaining({
            in: expect.arrayContaining(['PRO', 'ADVANCED', 'CUSTOM', 'DEVELOPER'])})})})
    );
  });

  test('blocks paid module when module metadata is missing and no fallback applies', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/equipment-work-orders',
      user: { tenant_id: 'tenant-missing-module', roles: ['NURSE'] }};

    moduleRepository.count.mockResolvedValue(0);
    subscriptionRepository.count.mockResolvedValue(0);

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeDefined();
    expect(error.messageKey).toBe('errors.auth.module_not_entitled');
    expect(error.statusCode).toBe(403);
    expect(error.errors).toEqual([
      expect.objectContaining({
        tenant_id: 'tenant-missing-module',
        module: 'biomedical-engineering-suite',
        reason: 'module_metadata_missing'})]);
    expect(moduleSubscriptionRepository.count).not.toHaveBeenCalled();
  });

  test('allows paid module when entitlement exists', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/equipment-work-orders',
      user: { tenant_id: 'tenant-entitled', roles: ['NURSE'] }};

    moduleRepository.count.mockResolvedValue(1);
    moduleSubscriptionRepository.count.mockResolvedValue(1);

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeUndefined();
  });

  test('accepts legacy billing-insurance entitlement for billing-payments paths', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/invoices',
      user: { tenant_id: 'tenant-legacy-billing', roles: ['BILLING'] }};

    moduleRepository.count.mockResolvedValue(1);
    moduleSubscriptionRepository.count.mockResolvedValue(1);

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeUndefined();
    expect(moduleSubscriptionRepository.count).toHaveBeenCalledWith(
      expect.objectContaining({
        module: expect.objectContaining({
          slug: { in: ['billing-payments', 'billing-insurance'] }})})
    );
  });

  test('allows pharmacy-orders when tenant has encounters-vitals but not pharmacy-dispensing', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/pharmacy-orders',
      user: { tenant_id: 'tenant-clinical-only', roles: ['DOCTOR'] }};

    moduleRepository.count.mockResolvedValue(1);
    moduleSubscriptionRepository.count.mockImplementation(async (filters = {}) => {
      const slugs = filters?.module?.slug?.in || [];
      return slugs.includes('encounters-vitals') ? 1 : 0;
    });

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeUndefined();
    expect(moduleSubscriptionRepository.count).toHaveBeenCalledWith(
      expect.objectContaining({
        module: expect.objectContaining({
          slug: expect.objectContaining({
            in: expect.arrayContaining(['pharmacy-dispensing'])})})})
    );
    expect(moduleSubscriptionRepository.count).toHaveBeenCalledWith(
      expect.objectContaining({
        module: expect.objectContaining({
          slug: expect.objectContaining({
            in: expect.arrayContaining(['encounters-vitals'])})})})
    );
  });

  test('allows suppliers when tenant has pharmacy-dispensing but not inventory-procurement-lite', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/suppliers',
      user: { tenant_id: 'tenant-pharmacy-only', roles: ['PHARMACIST'] }};

    moduleRepository.count.mockResolvedValue(1);
    moduleSubscriptionRepository.count.mockImplementation(async (filters = {}) => {
      const slugs = filters?.module?.slug?.in || [];
      return slugs.includes('pharmacy-dispensing') ? 1 : 0;
    });

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeUndefined();
    expect(moduleSubscriptionRepository.count).toHaveBeenCalledWith(
      expect.objectContaining({
        module: expect.objectContaining({
          slug: expect.objectContaining({
            in: expect.arrayContaining(['inventory-procurement-lite'])})})})
    );
    expect(moduleSubscriptionRepository.count).toHaveBeenCalledWith(
      expect.objectContaining({
        module: expect.objectContaining({
          slug: expect.objectContaining({
            in: expect.arrayContaining(['pharmacy-dispensing'])})})})
    );
  });

  test('still blocks pharmacy dispense paths without pharmacy-dispensing entitlement', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/pharmacy/workbench',
      user: { tenant_id: 'tenant-clinical-only', roles: ['DOCTOR'] }};

    moduleRepository.count.mockResolvedValue(1);
    moduleSubscriptionRepository.count.mockImplementation(async (filters = {}) => {
      const slugs = filters?.module?.slug?.in || [];
      return slugs.includes('encounters-vitals') ? 1 : 0;
    });
    prismaMock.module.findFirst.mockResolvedValue({
      id: 'mod-pharmacy',
      slug: 'pharmacy-dispensing',
      minimum_plan_tier_code: 'PRO'});

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeDefined();
    expect(error.messageKey).toBe('errors.auth.module_not_entitled');
    expect(error.statusCode).toBe(403);
  });

  test('allows PLATFORM_ADMIN to access commercial modules without plan entitlement', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/subscription-plans',
      user: {
        tenant_id: 'tenant-advanced-demo',
        roles: ['PLATFORM_ADMIN']}};

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeUndefined();
    expect(moduleRepository.count).not.toHaveBeenCalled();
    expect(moduleSubscriptionRepository.count).not.toHaveBeenCalled();
  });

  test('does not bypass entitlement checks for elevated tenant roles', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/equipment-work-orders',
      user: { tenant_id: 'tenant-admin-no-entitlement', roles: ['TENANT_ADMIN'] }};

    moduleRepository.count.mockResolvedValue(1);
    moduleSubscriptionRepository.count.mockResolvedValue(0);
    prismaMock.module.findFirst.mockResolvedValue({
      id: 'mod-biomed',
      slug: 'biomedical-engineering-suite',
      minimum_plan_tier_code: 'ADVANCED'});

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeDefined();
    expect(error.messageKey).toBe('errors.auth.module_not_entitled');
    expect(error.statusCode).toBe(403);
  });

  test('allows tenant billing flows without subscription-controls entitlement', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/subscriptions-workspace/upgrade-context',
      user: { tenant_id: 'tenant-advanced', roles: ['TENANT_ADMIN'] }};

    moduleRepository.count.mockResolvedValue(1);
    moduleSubscriptionRepository.count.mockResolvedValue(0);

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeUndefined();
    expect(moduleSubscriptionRepository.count).not.toHaveBeenCalled();
  });

  test.each([
    ['/staff-leaves/me'],
    ['/shift-assignments/me']])(
    'allows staff self-service %s without hr-rosters entitlement',
    async (path) => {
      const {
        enforceModuleEntitlement,
        isStaffSelfServicePath} = loadMiddleware();
      expect(isStaffSelfServicePath(path)).toBe(true);

      const req = {
        path,
        user: { tenant_id: 'tenant-no-hr', roles: ['NURSE'] }};

      moduleRepository.count.mockResolvedValue(1);
      moduleSubscriptionRepository.count.mockResolvedValue(0);

      const error = await invokeMiddleware(enforceModuleEntitlement(), req);

      expect(error).toBeUndefined();
      expect(moduleRepository.count).not.toHaveBeenCalled();
      expect(moduleSubscriptionRepository.count).not.toHaveBeenCalled();
    }
  );

  test.each([
    ['/staff-leaves'],
    ['/staff-leaves/leave-1'],
    ['/shift-assignments'],
    ['/shift-assignments/asg-1']])(
    'still requires hr-rosters for desk path %s',
    async (path) => {
      const {
        enforceModuleEntitlement,
        isStaffSelfServicePath} = loadMiddleware();
      expect(isStaffSelfServicePath(path)).toBe(false);

      const req = {
        path,
        user: { tenant_id: 'tenant-no-hr', roles: ['NURSE'] }};

      moduleRepository.count.mockResolvedValue(1);
      moduleSubscriptionRepository.count.mockResolvedValue(0);
      prismaMock.module.findFirst.mockResolvedValue({
        id: 'mod-hr',
        slug: 'hr-rosters',
        minimum_plan_tier_code: 'PRO'});

      const error = await invokeMiddleware(enforceModuleEntitlement(), req);

      expect(error).toBeDefined();
      expect(error.messageKey).toBe('errors.auth.module_not_entitled');
      expect(error.statusCode).toBe(403);
    }
  );

  test('still blocks subscription workspace admin routes for tenant admins', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/subscriptions-workspace/workspace',
      user: { tenant_id: 'tenant-advanced', roles: ['TENANT_ADMIN'] }};

    moduleRepository.count.mockResolvedValue(1);
    moduleSubscriptionRepository.count.mockResolvedValue(0);
    prismaMock.module.findFirst.mockResolvedValue({
      id: 'mod-subscription-controls',
      slug: 'subscription-controls',
      minimum_plan_tier_code: 'ADVANCED'});

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeDefined();
    expect(error.messageKey).toBe('errors.auth.module_not_entitled');
  });
});
