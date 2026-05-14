/**
 * request-context middleware tests
 */

const {
  initializeRequestContext,
  hydrateRequestContext
} = require('@middlewares/request-context.middleware');
const { getRequestContext } = require('@lib/context/request-context-store');

const createResponse = () => {
  const headers = new Map();
  return {
    locals: {},
    setHeader: jest.fn((name, value) => headers.set(String(name).toLowerCase(), value)),
    getHeader: jest.fn((name) => headers.get(String(name).toLowerCase())),
  };
};

describe('request-context middleware', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  it('initializes request context with request_id, locale metadata and header', () => {
    const req = {
      headers: {},
      locale: 'en',
      localeDirection: 'ltr',
      user: null
    };
    const res = createResponse();
    let activeContext = null;
    const next = jest.fn(() => {
      activeContext = getRequestContext();
    });

    initializeRequestContext()(req, res, next);

    expect(next).toHaveBeenCalledTimes(1);
    expect(req.request_id).toBeTruthy();
    expect(req.requestContext).toMatchObject({
      request_id: req.request_id,
      locale: 'en',
      direction: 'ltr'
    });
    expect(res.locals.requestContext.request_id).toBe(req.request_id);
    expect(res.setHeader).toHaveBeenCalledWith('X-Request-Id', req.request_id);
    expect(activeContext).toBe(req.requestContext);
  });

  it('uses existing x-request-id and captures actor/scope when available', () => {
    const req = {
      headers: { 'x-request-id': 'external-request-id' },
      locale: 'fr',
      localeDirection: 'ltr',
      user: {
        id: 'user-1',
        role: 'TENANT_ADMIN',
        roles: ['TENANT_ADMIN'],
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        branch_id: 'branch-1'
      }
    };
    const res = createResponse();
    let activeContext = null;
    const next = jest.fn(() => {
      activeContext = getRequestContext();
    });

    initializeRequestContext()(req, res, next);

    expect(next).toHaveBeenCalledTimes(1);
    expect(req.request_id).toBe('external-request-id');
    expect(req.requestContext.actor).toMatchObject({
      id: 'user-1',
      role: 'TENANT_ADMIN'
    });
    expect(req.requestContext.scope).toMatchObject({
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      branch_id: 'branch-1'
    });
    expect(activeContext).toBe(req.requestContext);
  });

  it('hydrates actor and tenancy scope after auth middlewares run', () => {
    const req = {
      headers: {},
      locale: 'en',
      localeDirection: 'ltr',
      user: null
    };
    const res = createResponse();
    const next = jest.fn();

    initializeRequestContext()(req, res, next);

    req.user = {
      id: 'user-2',
      role: 'DOCTOR',
      roles: ['DOCTOR'],
      tenant_id: 'tenant-2',
      facility_id: 'facility-2',
      branch_id: 'branch-2'
    };
    req.tenant = { id: 'tenant-2' };
    req.facility = { id: 'facility-2' };
    req.branch = { id: 'branch-2' };

    const hydrateNext = jest.fn();
    hydrateRequestContext()(req, res, hydrateNext);

    expect(hydrateNext).toHaveBeenCalledTimes(1);
    expect(req.requestContext.actor).toMatchObject({
      id: 'user-2',
      role: 'DOCTOR'
    });
    expect(req.requestContext.scope).toEqual({
      tenant_id: 'tenant-2',
      facility_id: 'facility-2',
      branch_id: 'branch-2'
    });
  });
});
