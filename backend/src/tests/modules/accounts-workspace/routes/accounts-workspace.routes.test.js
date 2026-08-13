const { PERMISSIONS } = require('@config/permissions');

jest.mock('@middlewares/auth.middleware', () => ({
  authenticate: jest.fn(() => function authenticateStub(_req, _res, next) {
    return next();
  }),
  authorize: jest.fn((scopes, mode) => {
    const handler = function authorizeStub(_req, _res, next) {
      return next();
    };
    handler.scopes = scopes;
    handler.mode = mode;
    return handler;
  }),
}));

const router = require('@routes/accounts-workspace/accounts-workspace.routes');
const { resolveOfflinePolicy } = require('@config/offline-policies');

/** Flatten the express layer stack into comparable route descriptors. */
const routeTable = () =>
  router.stack
    .filter((layer) => layer.route)
    .map((layer) => ({
      path: layer.route.path,
      methods: Object.keys(layer.route.methods).filter(
        (method) => layer.route.methods[method]
      ),
      scopes: layer.route.stack
        .map((entry) => entry.handle?.scopes)
        .find((scopes) => Array.isArray(scopes)),
      modes: layer.route.stack
        .map((entry) => entry.handle?.mode)
        .filter(Boolean),
    }));

const findRoute = (path, method) =>
  routeTable().find(
    (route) => route.path === path && route.methods.includes(method)
  );

describe('accounts-workspace routes — fiscal years & periods', () => {
  it('exports an express router', () => {
    expect(typeof router).toBe('function');
    expect(Array.isArray(router.stack)).toBe(true);
  });

  it('registers every operation in the target API contract', () => {
    expect(findRoute('/fiscal-years-and-periods', 'get')).toBeDefined();
    expect(
      findRoute('/fiscal-years-and-periods/:fiscalPeriodIdentifier', 'get')
    ).toBeDefined();
    expect(findRoute('/fiscal-years-and-periods', 'post')).toBeDefined();
    expect(
      findRoute('/fiscal-years-and-periods/:fiscalPeriodIdentifier', 'put')
    ).toBeDefined();
    expect(
      findRoute('/fiscal-years-and-periods/:fiscalPeriodIdentifier/:action', 'post')
    ).toBeDefined();
  });

  it('never exposes a hard delete for fiscal periods', () => {
    const deletes = routeTable().filter(
      (route) =>
        route.path.startsWith('/fiscal-years-and-periods') &&
        route.methods.includes('delete')
    );
    expect(deletes).toEqual([]);
  });

  it('gates reads on accounts:read or accounts:write', () => {
    expect(findRoute('/fiscal-years-and-periods', 'get').scopes).toEqual([
      PERMISSIONS.ACCOUNTS_READ,
      PERMISSIONS.ACCOUNTS_WRITE,
    ]);
  });

  it('gates create, update, and workflow actions on accounts:write only', () => {
    const writeOnly = [PERMISSIONS.ACCOUNTS_WRITE];
    expect(findRoute('/fiscal-years-and-periods', 'post').scopes).toEqual(writeOnly);
    expect(
      findRoute('/fiscal-years-and-periods/:fiscalPeriodIdentifier', 'put').scopes
    ).toEqual(writeOnly);
    expect(
      findRoute('/fiscal-years-and-periods/:fiscalPeriodIdentifier/:action', 'post')
        .scopes
    ).toEqual(writeOnly);
  });

  it('checks permissions rather than roles', () => {
    const modes = routeTable()
      .filter((route) => route.path.startsWith('/fiscal-years-and-periods'))
      .flatMap((route) => route.modes);
    expect(modes.length).toBeGreaterThan(0);
    expect(new Set(modes)).toEqual(new Set(['permission']));
  });
});

describe('accounts-workspace routes — currencies & exchange rates', () => {
  const BASE = '/currencies-and-exchange-rates';
  const ITEM = `${BASE}/:currencyRateIdentifier`;

  it('registers every operation in the target API contract', () => {
    expect(findRoute(BASE, 'get')).toBeDefined();
    expect(findRoute(ITEM, 'get')).toBeDefined();
    expect(findRoute(BASE, 'post')).toBeDefined();
    expect(findRoute(ITEM, 'put')).toBeDefined();
    expect(findRoute(`${ITEM}/:action`, 'post')).toBeDefined();
  });

  it('never exposes a hard delete for currency rates', () => {
    const deletes = routeTable().filter(
      (route) =>
        route.path.startsWith(BASE) && route.methods.includes('delete')
    );
    expect(deletes).toEqual([]);
  });

  it('gates reads on accounts:read or accounts:write', () => {
    expect(findRoute(BASE, 'get').scopes).toEqual([
      PERMISSIONS.ACCOUNTS_READ,
      PERMISSIONS.ACCOUNTS_WRITE,
    ]);
    expect(findRoute(ITEM, 'get').scopes).toEqual([
      PERMISSIONS.ACCOUNTS_READ,
      PERMISSIONS.ACCOUNTS_WRITE,
    ]);
  });

  it('gates create, update, and workflow actions on accounts:write only', () => {
    const writeOnly = [PERMISSIONS.ACCOUNTS_WRITE];
    expect(findRoute(BASE, 'post').scopes).toEqual(writeOnly);
    expect(findRoute(ITEM, 'put').scopes).toEqual(writeOnly);
    expect(findRoute(`${ITEM}/:action`, 'post').scopes).toEqual(writeOnly);
  });

  it('checks permissions rather than roles', () => {
    const modes = routeTable()
      .filter((route) => route.path.startsWith(BASE))
      .flatMap((route) => route.modes);
    expect(modes.length).toBeGreaterThan(0);
    expect(new Set(modes)).toEqual(new Set(['permission']));
  });

  it('lets the offline middleware replay duplicate currency mutations', () => {
    const policy = resolveOfflinePolicy({
      method: 'POST',
      originalUrl: `/api/v1/accounts${BASE}`,
    });
    expect(policy.allow_idempotency).toBe(true);
    expect(policy.cache).toBe('no-store');
  });
});
