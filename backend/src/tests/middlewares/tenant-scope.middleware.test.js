const {
  hydrateRequestScope,
  enforceTenantScope,
  restoreRequestedScope
} = require('@middlewares/tenant-scope.middleware');

const invokeMiddleware = (middleware, req, res = {}) =>
  new Promise((resolve) => {
    middleware(req, res, (error) => resolve(error));
  });

describe('tenant scope middleware', () => {
  test('hydrateRequestScope normalizes user context and sets scoped request objects', async () => {
    const req = {
      user: {
        id: 'user-1',
        tenantId: 'tenant-1',
        facility_id: 'facility-1',
        roles: ['NURSE']
      }
    };

    const error = await invokeMiddleware(hydrateRequestScope(), req);

    expect(error).toBeUndefined();
    expect(req.user.tenant_id).toBe('tenant-1');
    expect(req.user.facility_id).toBe('facility-1');
    expect(req.tenant).toEqual({ id: 'tenant-1' });
    expect(req.facility).toEqual({ id: 'facility-1' });
  });

  test('enforceTenantScope injects missing scope fields from authenticated user', async () => {
    const req = {
      user: {
        id: 'user-2',
        tenant_id: 'tenant-2',
        facility_id: 'facility-2',
        roles: ['NURSE']
      },
      query: {},
      body: {}
    };

    const error = await invokeMiddleware(enforceTenantScope(), req);

    expect(error).toBeUndefined();
    expect(req.query.tenant_id).toBe('tenant-2');
    expect(req.query.facility_id).toBe('facility-2');
    expect(req.body.tenant_id).toBe('tenant-2');
    expect(req.body.facility_id).toBe('facility-2');
  });

  test('enforceTenantScope normalizes cross-scope payload values for non-elevated roles', async () => {
    const req = {
      user: {
        id: 'user-3',
        tenant_id: 'tenant-3',
        facility_id: 'facility-3',
        roles: ['NURSE']
      },
      query: {
        tenant_id: 'tenant-other'
      },
      body: {
        tenant_id: 'tenant-other',
        facilityId: 'facility-other'
      }
    };

    const error = await invokeMiddleware(enforceTenantScope(), req);

    expect(error).toBeUndefined();
    expect(req.query.tenant_id).toBe('tenant-3');
    expect(req.body.tenant_id).toBe('tenant-3');
    expect(req.body.facility_id).toBe('facility-3');
    expect(req.body.facilityId).toBe('facility-3');
  });

  test('enforceTenantScope bypasses checks for elevated roles', async () => {
    const req = {
      user: {
        id: 'user-4',
        tenant_id: 'tenant-4',
        roles: ['PLATFORM_ADMIN']
      },
      query: {},
      body: {
        tenant_id: 'tenant-other'
      }
    };

    const error = await invokeMiddleware(enforceTenantScope(), req);

    expect(error).toBeUndefined();
  });

  test('enforceTenantScope records what the caller sent before rewriting it', async () => {
    const req = {
      user: {
        id: 'user-5',
        tenant_id: 'tenant-5',
        facility_id: 'facility-5',
        roles: ['TENANT_ADMIN']
      },
      query: {},
      body: { tenant_id: 'tenant-5', facility_id: 'facility-other' }
    };

    await invokeMiddleware(enforceTenantScope(), req);

    expect(req.body.facility_id).toBe('facility-5');
    expect(req.scopeAdjustments.body.facility_id).toEqual({
      provided: true,
      value: 'facility-other'
    });
    expect(req.scopeAdjustments.body.tenant_id).toBeUndefined();
  });

  test('restoreRequestedScope returns the requested facility and keeps the tenant rewrite', async () => {
    const req = {
      user: {
        id: 'user-6',
        tenant_id: 'tenant-6',
        facility_id: 'facility-a',
        roles: ['TENANT_ADMIN']
      },
      query: {},
      body: { tenant_id: 'tenant-other', facility_id: 'facility-b', status: 'INACTIVE' }
    };

    await invokeMiddleware(enforceTenantScope(), req);
    const error = await invokeMiddleware(
      restoreRequestedScope(['facility_id', 'tenant_id']),
      req
    );

    expect(error).toBeUndefined();
    expect(req.body).toEqual({
      tenant_id: 'tenant-6',
      facility_id: 'facility-b',
      status: 'INACTIVE'
    });
  });

  test('restoreRequestedScope removes a facility the rewrite injected', async () => {
    const req = {
      user: {
        id: 'user-7',
        tenant_id: 'tenant-7',
        facility_id: 'facility-a',
        roles: ['TENANT_ADMIN']
      },
      query: {},
      body: { status: 'INACTIVE' }
    };

    await invokeMiddleware(enforceTenantScope(), req);
    expect(req.body.facility_id).toBe('facility-a');

    await invokeMiddleware(restoreRequestedScope(['facility_id']), req);

    expect(req.body).toEqual({ status: 'INACTIVE', tenant_id: 'tenant-7' });
  });

  test('restoreRequestedScope leaves untouched requests alone', async () => {
    const req = { body: { facility_id: 'facility-b' } };

    const error = await invokeMiddleware(restoreRequestedScope(['facility_id']), req);

    expect(error).toBeUndefined();
    expect(req.body).toEqual({ facility_id: 'facility-b' });
  });
});
