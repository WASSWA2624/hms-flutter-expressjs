/**
 * Tenant-scope route coverage
 *
 * Step 07, AC3: every tenant-scoped route must enforce tenant scope, with no
 * unenforced route left.
 *
 * The router gives a stronger guarantee than a per-route audit: `authenticate`,
 * `hydrateRequestScope`, `enforceTenantScope`, `hydrateRequestContext` and
 * `enforceAbacAccess` are mounted once on the v1 router, ahead of every module.
 * Coverage is therefore structural — a new module is enforced the moment it is
 * mounted, and nobody has to remember to add a guard.
 *
 * That guarantee holds only while the mount order does, which is what this
 * suite pins down. It reads the router source rather than booting the app, so
 * it stays a fast unit test and cannot be satisfied by a route that merely
 * happens to work at runtime.
 */

const fs = require('fs');
const path = require('path');

const ROUTER_SOURCE = fs.readFileSync(
  path.join(__dirname, '..', '..', 'app', 'router.js'),
  'utf8'
);

const lineIndexOf = (needle) => {
  const index = ROUTER_SOURCE.indexOf(needle);
  if (index === -1) throw new Error(`router.js does not contain ${needle}`);
  return index;
};

/** Every `apiV1Router.use('/path', ...)` mount, in source order. */
const moduleMounts = () =>
  [...ROUTER_SOURCE.matchAll(/apiV1Router\.use\(\s*'(\/[\w-]+)'/g)].map((match) => ({
    route: match[1],
    index: match.index,
  }));

/**
 * Mounted before authentication on purpose: `/auth` issues the token and
 * `/public` is unauthenticated by design. Neither is tenant-scoped.
 */
const PRE_AUTH_ROUTES = new Set(['/auth', '/public']);

describe('tenant-scope route coverage', () => {
  const scopeIndex = lineIndexOf('apiV1Router.use(enforceTenantScope());');
  const authIndex = lineIndexOf('apiV1Router.use(authenticate());');

  it('authenticates before it scopes', () => {
    expect(authIndex).toBeLessThan(scopeIndex);
  });

  it('hydrates scope before enforcing it', () => {
    expect(lineIndexOf('apiV1Router.use(hydrateRequestScope());')).toBeLessThan(scopeIndex);
  });

  it('enforces tenant scope before the ABAC layer', () => {
    expect(scopeIndex).toBeLessThan(lineIndexOf('apiV1Router.use(enforceAbacAccess());'));
  });

  it('establishes the request context the database guard reads', () => {
    // The Prisma tenant guard resolves the acting tenant from this context.
    // Mounted after scope enforcement so the values it stores are canonical.
    const contextIndex = lineIndexOf('apiV1Router.use(hydrateRequestContext());');

    expect(scopeIndex).toBeLessThan(contextIndex);
  });

  it('mounts every module route after tenant scope is enforced', () => {
    const unenforced = moduleMounts()
      .filter((mount) => mount.index < scopeIndex)
      .map((mount) => mount.route)
      .filter((route) => !PRE_AUTH_ROUTES.has(route));

    expect(unenforced).toEqual([]);
  });

  it('mounts only the pre-auth routes ahead of authentication', () => {
    const beforeAuth = moduleMounts()
      .filter((mount) => mount.index < authIndex)
      .map((mount) => mount.route);

    expect(new Set(beforeAuth)).toEqual(PRE_AUTH_ROUTES);
  });

  it('covers a substantial module surface', () => {
    // Guards against the ordering assertions passing vacuously if the mount
    // pattern is ever refactored into something this test cannot see.
    const enforced = moduleMounts().filter((mount) => mount.index > scopeIndex);

    expect(enforced.length).toBeGreaterThan(100);
  });

  it('covers the modules step 07 names explicitly', () => {
    const enforced = new Set(
      moduleMounts().filter((mount) => mount.index > scopeIndex).map((mount) => mount.route)
    );

    for (const route of [
      '/patients', '/encounters', '/invoices', '/payments',
      '/dispense-logs', '/lab-orders', '/facilities',
    ]) {
      expect(enforced.has(route)).toBe(true);
    }
  });
});
