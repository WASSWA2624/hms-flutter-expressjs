const invokeMiddleware = (middleware, req, res = {}) =>
  new Promise((resolve) => {
    middleware(req, res, (error) => resolve(error));
  });

describe('module entitlement middleware', () => {
  let moduleRepository;
  let moduleSubscriptionRepository;
  let subscriptionRepository;

  const loadMiddleware = () => {
    jest.resetModules();

    moduleRepository = {
      count: jest.fn()
    };
    moduleSubscriptionRepository = {
      count: jest.fn()
    };
    subscriptionRepository = {
      count: jest.fn()
    };

    jest.doMock('@repositories/module/module.repository', () => moduleRepository);
    jest.doMock('@repositories/module-subscription/module-subscription.repository', () => moduleSubscriptionRepository);
    jest.doMock('@repositories/subscription/subscription.repository', () => subscriptionRepository);

    return require('@middlewares/module-entitlement.middleware');
  };

  test('allows free-core equipment incident reporting without subscription lookup', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/equipment-incident-reports',
      user: { tenant_id: 'tenant-free', roles: ['NURSE'] }
    };

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeUndefined();
    expect(subscriptionRepository.count).not.toHaveBeenCalled();
    expect(moduleRepository.count).not.toHaveBeenCalled();
    expect(moduleSubscriptionRepository.count).not.toHaveBeenCalled();
  });

  test('allows dashboard workspace without subscription lookup because it is free-core', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/dashboard-workspace/workspace',
      user: { tenant_id: 'tenant-dashboard', roles: ['SUPER_ADMIN'] }
    };

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeUndefined();
    expect(subscriptionRepository.count).not.toHaveBeenCalled();
    expect(moduleRepository.count).not.toHaveBeenCalled();
    expect(moduleSubscriptionRepository.count).not.toHaveBeenCalled();
  });

  test('allows communications workspace without subscription lookup because it is free-core', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/communications-workspace/workspace',
      user: { tenant_id: 'tenant-communications', roles: ['SUPER_ADMIN'] }
    };

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeUndefined();
    expect(subscriptionRepository.count).not.toHaveBeenCalled();
    expect(moduleRepository.count).not.toHaveBeenCalled();
    expect(moduleSubscriptionRepository.count).not.toHaveBeenCalled();
  });

  test('blocks paid module when active subscription exists but tenant lacks entitlement', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/equipment-work-orders',
      user: { tenant_id: 'tenant-no-entitlement', roles: ['NURSE'] }
    };

    subscriptionRepository.count.mockResolvedValue(1);
    moduleRepository.count.mockResolvedValue(1);
    moduleSubscriptionRepository.count.mockResolvedValue(0);

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeDefined();
    expect(error.messageKey).toBe('errors.auth.module_not_entitled');
    expect(error.statusCode).toBe(403);
  });

  test('maps IPD flow endpoints to the inpatient subscription module slug', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/ipd-flows',
      user: { tenant_id: 'tenant-no-ipd', roles: ['NURSE'] }
    };

    subscriptionRepository.count.mockResolvedValue(1);
    moduleRepository.count.mockImplementation(async (filters = {}) =>
      filters.slug === 'inpatient-bed-management' ? 1 : 0
    );
    moduleSubscriptionRepository.count.mockResolvedValue(0);

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(moduleRepository.count).toHaveBeenCalledWith({ slug: 'inpatient-bed-management' });
    expect(moduleSubscriptionRepository.count).toHaveBeenCalledWith(
      expect.objectContaining({
        is_active: true,
        module: expect.objectContaining({
          slug: 'inpatient-bed-management',
        }),
      })
    );
    expect(error).toBeDefined();
    expect(error.messageKey).toBe('errors.auth.module_not_entitled');
  });

  test('maps theatre endpoints to the theatre and anesthesia subscription module slug', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/theatre-flows',
      user: { tenant_id: 'tenant-no-theatre', roles: ['NURSE'] }
    };

    subscriptionRepository.count.mockResolvedValue(1);
    moduleRepository.count.mockImplementation(async (filters = {}) =>
      filters.slug === 'theatre-anesthesia' ? 1 : 0
    );
    moduleSubscriptionRepository.count.mockResolvedValue(0);

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(moduleRepository.count).toHaveBeenCalledWith({ slug: 'theatre-anesthesia' });
    expect(moduleSubscriptionRepository.count).toHaveBeenCalledWith(
      expect.objectContaining({
        is_active: true,
        module: expect.objectContaining({
          slug: 'theatre-anesthesia',
        }),
      })
    );
    expect(error).toBeDefined();
    expect(error.messageKey).toBe('errors.auth.module_not_entitled');
  });

  test.each([
    ['/lab/workbench', 'lab-workflows'],
    ['/lab-orders', 'lab-workflows'],
    ['/radiology/workbench', 'radiology-workflows'],
    ['/radiology-orders', 'radiology-workflows'],
    ['/pharmacy/workbench', 'pharmacy-dispensing'],
    ['/pharmacy-orders', 'pharmacy-dispensing'],
  ])('maps %s to subscription module slug %s', async (path, expectedSlug) => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path,
      user: { tenant_id: 'tenant-entitled-diagnostics', roles: ['SUPER_ADMIN'] },
    };

    subscriptionRepository.count.mockResolvedValue(1);
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
          slug: expectedSlug,
        }),
      })
    );
  });

  test('allows mortuary from the core catalog fallback when module metadata is missing', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/mortuary',
      user: { tenant_id: 'tenant-advanced-demo', roles: ['SUPER_ADMIN'] },
    };

    subscriptionRepository.count
      .mockResolvedValueOnce(1)
      .mockResolvedValueOnce(1);
    moduleRepository.count.mockResolvedValue(0);

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeUndefined();
    expect(moduleRepository.count).toHaveBeenCalledWith({ slug: 'mortuary' });
    expect(subscriptionRepository.count).toHaveBeenLastCalledWith(
      expect.objectContaining({
        tenant_id: 'tenant-advanced-demo',
        plan: expect.objectContaining({
          tier_code: expect.objectContaining({
            in: ['BASIC', 'PRO', 'ADVANCED', 'CUSTOM'],
          }),
        }),
      })
    );
    expect(moduleSubscriptionRepository.count).not.toHaveBeenCalled();
  });

  test('blocks paid module when tenant has no active subscription', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/equipment-work-orders',
      user: { tenant_id: 'tenant-legacy', roles: ['NURSE'] }
    };

    subscriptionRepository.count.mockResolvedValue(0);

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeDefined();
    expect(error.messageKey).toBe('errors.auth.module_not_entitled');
    expect(error.statusCode).toBe(403);
    expect(error.errors).toEqual([
      expect.objectContaining({
        tenant_id: 'tenant-legacy',
        module: 'equipment-work-order',
        reason: 'subscription_required',
      }),
    ]);
    expect(moduleRepository.count).not.toHaveBeenCalled();
    expect(moduleSubscriptionRepository.count).not.toHaveBeenCalled();
  });

  test('blocks paid module when module metadata is missing', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/equipment-work-orders',
      user: { tenant_id: 'tenant-missing-module', roles: ['NURSE'] }
    };

    subscriptionRepository.count.mockResolvedValue(1);
    moduleRepository.count.mockResolvedValue(0);

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeDefined();
    expect(error.messageKey).toBe('errors.auth.module_not_entitled');
    expect(error.statusCode).toBe(403);
    expect(error.errors).toEqual([
      expect.objectContaining({
        tenant_id: 'tenant-missing-module',
        module: 'equipment-work-order',
        reason: 'module_metadata_missing',
      }),
    ]);
    expect(moduleSubscriptionRepository.count).not.toHaveBeenCalled();
  });

  test('allows paid module when entitlement exists', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/equipment-work-orders',
      user: { tenant_id: 'tenant-entitled', roles: ['NURSE'] }
    };

    subscriptionRepository.count.mockResolvedValue(1);
    moduleRepository.count.mockResolvedValue(1);
    moduleSubscriptionRepository.count.mockResolvedValue(1);

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeUndefined();
  });

  test('does not bypass entitlement checks for elevated tenant roles', async () => {
    const { enforceModuleEntitlement } = loadMiddleware();
    const req = {
      path: '/equipment-work-orders',
      user: { tenant_id: 'tenant-admin-no-entitlement', roles: ['TENANT_ADMIN'] }
    };

    subscriptionRepository.count.mockResolvedValue(1);
    moduleRepository.count.mockResolvedValue(1);
    moduleSubscriptionRepository.count.mockResolvedValue(0);

    const error = await invokeMiddleware(enforceModuleEntitlement(), req);

    expect(error).toBeDefined();
    expect(error.messageKey).toBe('errors.auth.module_not_entitled');
    expect(error.statusCode).toBe(403);
  });
});
