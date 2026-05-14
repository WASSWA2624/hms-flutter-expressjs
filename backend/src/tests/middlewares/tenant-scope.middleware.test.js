const {
  hydrateRequestScope,
  enforceTenantScope
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
        branchId: 'branch-1',
        roles: ['NURSE']
      }
    };

    const error = await invokeMiddleware(hydrateRequestScope(), req);

    expect(error).toBeUndefined();
    expect(req.user.tenant_id).toBe('tenant-1');
    expect(req.user.facility_id).toBe('facility-1');
    expect(req.user.branch_id).toBe('branch-1');
    expect(req.tenant).toEqual({ id: 'tenant-1' });
    expect(req.facility).toEqual({ id: 'facility-1' });
    expect(req.branch).toEqual({ id: 'branch-1' });
  });

  test('enforceTenantScope injects missing scope fields from authenticated user', async () => {
    const req = {
      user: {
        id: 'user-2',
        tenant_id: 'tenant-2',
        facility_id: 'facility-2',
        branch_id: 'branch-2',
        roles: ['NURSE']
      },
      query: {},
      body: {}
    };

    const error = await invokeMiddleware(enforceTenantScope(), req);

    expect(error).toBeUndefined();
    expect(req.query.tenant_id).toBe('tenant-2');
    expect(req.query.facility_id).toBe('facility-2');
    expect(req.query.branch_id).toBe('branch-2');
    expect(req.body.tenant_id).toBe('tenant-2');
    expect(req.body.facility_id).toBe('facility-2');
    expect(req.body.branch_id).toBe('branch-2');
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
        roles: ['SUPER_ADMIN']
      },
      query: {},
      body: {
        tenant_id: 'tenant-other'
      }
    };

    const error = await invokeMiddleware(enforceTenantScope(), req);

    expect(error).toBeUndefined();
  });
});
