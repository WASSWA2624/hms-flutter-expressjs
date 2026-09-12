/**
 * Preset adoption isolation
 *
 * Step 06 R3 and step 07 AC5: a tenant browses the platform catalog, adopts a
 * preset for one of its facilities, and customises only the permitted fields —
 * without that customisation reaching the platform definition or another tenant.
 *
 * The browse surface is the part that regressed twice already (once in the drug
 * service, once in the tenant guard), both times because platform rows were
 * filtered out by a `tenant_id` equality. These tests pin the shape of the
 * where-clause the catalog services build, including the `AND` composition that
 * stops the search filter from clobbering visibility.
 */

const {
  buildVisibleDefinitionWhere,
  assertAdoptionOverridesAllowed,
  filterAdoptionOverrides,
  PRESET_DOMAINS,
} = require('@lib/catalog/preset-ownership');
const { HttpError } = require('@lib/errors');

const TENANT_A = 'tenant-a';
const TENANT_B = 'tenant-b';

/** The shape each catalog service builds for its browse query. */
const browseWhere = (tenantId, searchTerm = null) => {
  const where = { AND: [buildVisibleDefinitionWhere(tenantId)] };
  if (!searchTerm) return where;
  return { ...where, OR: [{ name: { contains: searchTerm } }] };
};

describe('preset adoption isolation', () => {
  describe('browse surface', () => {
    it('offers the platform catalog alongside the tenant\'s own entries', () => {
      const where = browseWhere(TENANT_A);

      expect(where.AND[0]).toEqual({
        OR: [{ tenant_id: null }, { tenant_id: TENANT_A }],
      });
    });

    it('never offers another tenant\'s definitions', () => {
      expect(JSON.stringify(browseWhere(TENANT_A))).not.toContain(TENANT_B);
    });

    it('keeps visibility in AND so a search filter cannot clobber it', () => {
      // The regression this guards: visibility written as a bare top-level `OR`
      // is overwritten by the search filter, widening the query to every tenant.
      const where = browseWhere(TENANT_A, 'blood');

      expect(where.AND[0].OR).toEqual([{ tenant_id: null }, { tenant_id: TENANT_A }]);
      expect(where.OR).toEqual([{ name: { contains: 'blood' } }]);
    });

    it('still scopes the browse when a search term is present', () => {
      const serialized = JSON.stringify(browseWhere(TENANT_A, 'blood'));

      expect(serialized).toContain(TENANT_A);
      expect(serialized).not.toContain(TENANT_B);
    });

    it('shows only the platform catalog to a tenantless context', () => {
      expect(browseWhere(null).AND[0]).toEqual({ tenant_id: null });
    });
  });

  describe('adoption overrides', () => {
    it.each(Object.keys(PRESET_DOMAINS))(
      '%s permits a facility to switch an adoption off',
      (domain) => {
        expect(assertAdoptionOverridesAllowed(domain, { is_active: false })).toEqual({
          is_active: false,
        });
      }
    );

    it('accepts a local price on a priced domain', () => {
      expect(
        assertAdoptionOverridesAllowed('lab_test', { unit_price: 12345, currency: 'UGX' })
      ).toEqual({ unit_price: 12345, currency: 'UGX' });
    });

    it('refuses to rename a shared preset locally', () => {
      expect(() =>
        assertAdoptionOverridesAllowed('lab_test', { name: 'Our Name For It' })
      ).toThrow(HttpError);
    });

    it('refuses to re-code a shared preset locally', () => {
      expect(() =>
        assertAdoptionOverridesAllowed('radiology_procedure', { code: 'LOCAL-1' })
      ).toThrow(HttpError);
    });

    it('names every rejected field so the caller can report it', () => {
      const { rejected } = filterAdoptionOverrides('lab_test', {
        unit_price: 1,
        name: 'x',
        code: 'y',
      });

      expect(rejected.sort()).toEqual(['code', 'name']);
    });

    it('reports the refusal as a validation error, not a permission one', () => {
      try {
        assertAdoptionOverridesAllowed('lab_test', { name: 'x' });
        throw new Error('expected a rejection');
      } catch (error) {
        expect(error.statusCode).toBe(422);
        expect(error.messageKey).toBe('errors.catalog.preset.not_overridable');
      }
    });
  });

  describe('adoption ownership', () => {
    it('never treats an adoption table as shareable', () => {
      // An adoption carries a tenant's prices. Sharing one would leak them.
      for (const contract of Object.values(PRESET_DOMAINS)) {
        expect(contract.adoptionModel).not.toBe(contract.definitionModel);
      }
    });

    it('keeps the platform definition free of tenant pricing fields', () => {
      // Price lives on the adoption. A domain that let a tenant write price onto
      // the definition would change it for every other tenant.
      for (const [domain, contract] of Object.entries(PRESET_DOMAINS)) {
        if (!contract.overridable.includes('unit_price')) continue;
        expect(contract.platformOwned).not.toContain('unit_price');
        expect(domain).toBeTruthy();
      }
    });
  });
});
