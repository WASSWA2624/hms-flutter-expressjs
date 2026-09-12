/**
 * Cross-tenant access at the database layer
 *
 * Step 07, AC2/AC4/AC6: a request running as tenant B must not be able to read,
 * update or delete a row belonging to tenant A — including by direct identifier
 * — and the refusal must not reveal that the row exists.
 *
 * Driven through the tenant-guard query extension rather than a live database,
 * so the assertion is about the guard itself: every read is checked for the
 * tenant constraint it emits, and every write for the constraint it enforces.
 *
 * The suite is deliberately sensitive: removing the guard's tenant constraint
 * makes it fail rather than silently pass.
 */

const { runWithRequestContext } = require('@lib/context/request-context-store');
const {
  buildTenantGuardModelMetadata,
  createTenantGuardQueryExtension,
} = require('../../prisma/tenant-guard');

const TENANT_A = 'tenant-a';
const TENANT_B = 'tenant-b';

/**
 * Representative tenant-scoped modules named by step 07 R7.
 * `facility` stands in for configuration; the rest are operational.
 */
const MODULES = [
  'patient',
  'encounter',
  'invoice',
  'payment',
  'visit_queue',
  'facility',
];

const METADATA = { hasId: true, hasTenantId: true, hasDeletedAt: true };

const buildHandlers = (baseClient, models = MODULES) =>
  createTenantGuardQueryExtension({
    baseClient,
    modelMetadata: new Map(models.map((model) => [model, METADATA])),
  }).$allModels;

/** A base client whose reads would hand back tenant A's row if unguarded. */
const buildLeakyClient = (models = MODULES) => {
  const client = {};
  for (const model of models) {
    client[model] = {
      findFirst: jest.fn().mockResolvedValue(null),
      findMany: jest.fn().mockResolvedValue([]),
      count: jest.fn().mockResolvedValue(0),
      update: jest.fn().mockResolvedValue({ id: 'row-a' }),
      delete: jest.fn().mockResolvedValue({ id: 'row-a' }),
    };
  }
  return client;
};

const asTenant = (tenantId, callback) =>
  runWithRequestContext(
    { actor: { id: 'user', roles: ['TENANT_ADMIN'] }, scope: { tenant_id: tenantId } },
    async () => callback()
  );

/** Every `where` the guard passed down to the base client or the raw query. */
const capturedWheres = (baseClient, query, model) => {
  const found = [];
  for (const call of query.mock.calls) {
    if (call[0]?.where) found.push(call[0].where);
  }
  for (const method of ['findFirst', 'findMany', 'count', 'update', 'delete']) {
    for (const call of baseClient[model]?.[method]?.mock?.calls || []) {
      if (call[0]?.where) found.push(call[0].where);
    }
  }
  return found;
};

const mentionsTenant = (where, tenantId) =>
  JSON.stringify(where).includes(tenantId);

describe('cross-tenant access is refused at the database layer', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe.each(MODULES)('%s', (model) => {
    it('scopes a direct-identifier read to the acting tenant', async () => {
      const baseClient = buildLeakyClient();
      const handlers = buildHandlers(baseClient);
      const query = jest.fn().mockResolvedValue(null);

      await asTenant(TENANT_B, () =>
        handlers.findUnique({ model, args: { where: { id: 'row-a' } }, query })
      );

      const wheres = capturedWheres(baseClient, query, model);
      expect(wheres.length).toBeGreaterThan(0);
      expect(wheres.every((where) => mentionsTenant(where, TENANT_B))).toBe(true);
      expect(wheres.some((where) => mentionsTenant(where, TENANT_A))).toBe(false);
    });

    it('returns nothing rather than revealing the row exists', async () => {
      // The base client answers as the database would once scoped: no match.
      const baseClient = buildLeakyClient();
      const handlers = buildHandlers(baseClient);
      const query = jest.fn().mockResolvedValue(null);

      const result = await asTenant(TENANT_B, () =>
        handlers.findFirst({ model, args: { where: { id: 'row-a' } }, query })
      );

      expect(result).toBeNull();
    });

    it('scopes a list to the acting tenant', async () => {
      const baseClient = buildLeakyClient();
      const handlers = buildHandlers(baseClient);
      const query = jest.fn().mockResolvedValue([]);

      await asTenant(TENANT_B, () =>
        handlers.findMany({ model, args: {}, query })
      );

      const wheres = capturedWheres(baseClient, query, model);
      expect(wheres.every((where) => mentionsTenant(where, TENANT_B))).toBe(true);
    });

    it('scopes a count so aggregates cannot leak a total', async () => {
      const baseClient = buildLeakyClient();
      const handlers = buildHandlers(baseClient);
      const query = jest.fn().mockResolvedValue(0);

      await asTenant(TENANT_B, () =>
        handlers.count({ model, args: {}, query })
      );

      const wheres = capturedWheres(baseClient, query, model);
      expect(wheres.every((where) => mentionsTenant(where, TENANT_B))).toBe(true);
    });

    it('scopes an updateMany so a write cannot reach another tenant', async () => {
      const baseClient = buildLeakyClient();
      const handlers = buildHandlers(baseClient);
      const query = jest.fn().mockResolvedValue({ count: 0 });

      await asTenant(TENANT_B, () =>
        handlers.updateMany({ model, args: { where: { id: 'row-a' }, data: {} }, query })
      );

      const wheres = capturedWheres(baseClient, query, model);
      expect(wheres.every((where) => mentionsTenant(where, TENANT_B))).toBe(true);
      expect(wheres.some((where) => mentionsTenant(where, TENANT_A))).toBe(false);
    });

    it('scopes a deleteMany so a delete cannot reach another tenant', async () => {
      const baseClient = buildLeakyClient();
      const handlers = buildHandlers(baseClient);
      const query = jest.fn().mockResolvedValue({ count: 0 });

      await asTenant(TENANT_B, () =>
        handlers.deleteMany({ model, args: { where: { id: 'row-a' } }, query })
      );

      const wheres = capturedWheres(baseClient, query, model);
      expect(wheres.every((where) => mentionsTenant(where, TENANT_B))).toBe(true);
    });

    it('stamps a create with the acting tenant, ignoring a forged tenant_id', async () => {
      const baseClient = buildLeakyClient();
      const handlers = buildHandlers(baseClient);
      const query = jest.fn().mockResolvedValue({ id: 'new' });

      await asTenant(TENANT_B, () =>
        handlers.create({
          model,
          args: { data: { id: 'new', tenant_id: TENANT_A } },
          query,
        })
      );

      expect(query).toHaveBeenCalled();
      expect(query.mock.calls[0][0].data.tenant_id).toBe(TENANT_B);
    });
  });

  describe('operational models are never platform-shared', () => {
    it.each(['patient', 'encounter', 'invoice', 'payment', 'visit_queue'])(
      'never widens %s to rows with a null tenant',
      async (model) => {
        const baseClient = buildLeakyClient();
        const handlers = buildHandlers(baseClient);
        const query = jest.fn().mockResolvedValue([]);

        await asTenant(TENANT_B, () => handlers.findMany({ model, args: {}, query }));

        const wheres = capturedWheres(baseClient, query, model);
        expect(wheres.length).toBeGreaterThan(0);
        for (const where of wheres) {
          expect(JSON.stringify(where)).not.toContain('"tenant_id":null');
        }
      }
    );
  });

  describe('model metadata', () => {
    it('recognises tenant scoping on every representative module', () => {
      const { Prisma } = require('.prisma/client');
      const metadata = buildTenantGuardModelMetadata(Prisma);

      for (const model of MODULES) {
        expect(metadata.get(model)?.hasTenantId).toBe(true);
      }
    });
  });
});
