/**
 * preset-ownership unit tests
 *
 * Step 06, AC3/AC4: a tenant-scoped actor cannot mutate a platform preset
 * definition, and one tenant's customization cannot reach another tenant or the
 * platform source.
 */

const { HttpError } = require('@lib/errors');
const {
  PRESET_DOMAINS,
  DOMAIN_NAMES,
  getPresetDomain,
  isPlatformDefinition,
  isTrustedInternalCaller,
  actorCanManagePlatformPresets,
  assertCanMutatePresetDefinition,
  resolvePresetDefinitionScope,
  buildVisibleDefinitionWhere,
  filterAdoptionOverrides,
  assertAdoptionOverridesAllowed,
} = require('@lib/catalog/preset-ownership');

const platformActor = { id: 'admin-1', roles: ['PLATFORM_ADMIN'], permissions: ['platform:admin'] };
const tenantAActor = { id: 'user-a', tenant_id: 'tenant-a', roles: ['TENANT_ADMIN'], permissions: [] };
const tenantBActor = { id: 'user-b', tenant_id: 'tenant-b', roles: ['TENANT_ADMIN'], permissions: [] };

const platformDefinition = { id: 'def-1', tenant_id: null, name: 'Full Blood Count' };
const tenantADefinition = { id: 'def-2', tenant_id: 'tenant-a', name: 'House Panel' };

const statusOf = (thrown) => (thrown instanceof HttpError ? thrown.statusCode : null);

describe('preset-ownership', () => {
  describe('domain contracts', () => {
    it('describes every domain with a definition and an adoption model', () => {
      for (const domain of DOMAIN_NAMES) {
        const contract = getPresetDomain(domain);
        expect(contract.definitionModel).toBeTruthy();
        expect(contract.adoptionModel).toBeTruthy();
        expect(contract.adoptionKey).toBeTruthy();
        expect(contract.overridable.length).toBeGreaterThan(0);
      }
    });

    it('never lets a domain declare the definition and adoption as one table', () => {
      for (const domain of DOMAIN_NAMES) {
        const contract = getPresetDomain(domain);
        expect(contract.adoptionModel).not.toBe(contract.definitionModel);
      }
    });

    it('always permits an availability override', () => {
      // Every adoption can be switched off for a facility, whatever the domain.
      for (const domain of DOMAIN_NAMES) {
        const { overridable } = getPresetDomain(domain);
        expect(overridable).toContain('is_active');
      }
    });

    it('permits a price override wherever the domain is priced', () => {
      // clinical_term_catalog is deliberately absent: a diagnosis is not sold,
      // and facility_catalog_offering carries no price column to override.
      const pricedDomains = ['lab_test', 'lab_panel', 'radiology_procedure', 'drug'];

      for (const domain of pricedDomains) {
        expect(getPresetDomain(domain).overridable).toContain('unit_price');
      }
      expect(getPresetDomain('clinical_term_catalog').overridable).not.toContain('unit_price');
    });

    it('rejects an unknown domain', () => {
      expect(() => getPresetDomain('not_a_domain')).toThrow(/Unknown preset domain/);
    });
  });

  describe('isPlatformDefinition', () => {
    it.each([
      [null, true],
      [undefined, true],
      ['', true],
      ['   ', true],
      ['tenant-a', false],
    ])('treats tenant_id %p as platform=%p', (tenantId, expected) => {
      expect(isPlatformDefinition({ tenant_id: tenantId })).toBe(expected);
    });
  });

  describe('actorCanManagePlatformPresets', () => {
    it('accepts a platform admin', () => {
      expect(actorCanManagePlatformPresets(platformActor)).toBe(true);
    });

    it('rejects a tenant admin', () => {
      expect(actorCanManagePlatformPresets(tenantAActor)).toBe(false);
    });

    it('rejects an actor with no roles or permissions', () => {
      expect(actorCanManagePlatformPresets({})).toBe(false);
    });
  });

  describe('trusted internal callers', () => {
    // Seeders, backfills and service-to-service calls arrive without the
    // permissions array the auth middleware always attaches to a request.
    const internalCaller = { id: 'seeder' };

    it('recognises a caller with no permissions array as internal', () => {
      expect(isTrustedInternalCaller(internalCaller)).toBe(true);
    });

    it('never treats a request actor as internal', () => {
      for (const actor of [platformActor, tenantAActor, tenantBActor]) {
        expect(isTrustedInternalCaller(actor)).toBe(false);
      }
    });

    it('lets an internal caller write a platform definition', () => {
      expect(() =>
        assertCanMutatePresetDefinition(platformDefinition, internalCaller)
      ).not.toThrow();
    });

    it('lets an internal caller seed at platform scope', () => {
      expect(
        resolvePresetDefinitionScope({ scope: 'platform', name: 'X' }, internalCaller)
      ).toEqual({ name: 'X', tenant_id: null });
    });

    it('leaves an internal caller tenant_id untouched', () => {
      expect(
        resolvePresetDefinitionScope({ name: 'X', tenant_id: 'tenant-b' }, internalCaller)
      ).toEqual({ name: 'X', tenant_id: 'tenant-b' });
    });
  });

  describe('assertCanMutatePresetDefinition', () => {
    it('lets a platform admin update a platform definition', () => {
      expect(() =>
        assertCanMutatePresetDefinition(platformDefinition, platformActor)
      ).not.toThrow();
    });

    it('rejects a tenant admin updating a platform definition with 403', () => {
      const thrown = (() => {
        try {
          assertCanMutatePresetDefinition(platformDefinition, tenantAActor);
          return null;
        } catch (error) {
          return error;
        }
      })();

      expect(statusOf(thrown)).toBe(403);
      expect(thrown.messageKey).toBe('errors.auth.insufficient_permissions');
    });

    it('reports delete separately from update', () => {
      try {
        assertCanMutatePresetDefinition(platformDefinition, tenantAActor, { action: 'delete' });
        throw new Error('expected a rejection');
      } catch (error) {
        expect(error.errors?.[0]?.reason).toBe('platform_preset_delete_forbidden');
      }
    });

    it('lets a tenant admin mutate its own definition', () => {
      expect(() =>
        assertCanMutatePresetDefinition(tenantADefinition, tenantAActor)
      ).not.toThrow();
    });

    it('stops tenant B mutating tenant A\'s definition', () => {
      expect(() =>
        assertCanMutatePresetDefinition(tenantADefinition, tenantBActor)
      ).toThrow(HttpError);
    });
  });

  describe('resolvePresetDefinitionScope', () => {
    it('creates a platform preset for a platform admin who asks for one', () => {
      const payload = resolvePresetDefinitionScope(
        { scope: 'platform', name: 'Malaria RDT' },
        platformActor
      );

      expect(payload).toEqual({ name: 'Malaria RDT', tenant_id: null });
    });

    it('refuses platform scope to a tenant admin', () => {
      expect(() =>
        resolvePresetDefinitionScope({ scope: 'platform', name: 'X' }, tenantAActor)
      ).toThrow(HttpError);
    });

    it('pins a tenant admin\'s definition to their own tenant', () => {
      const payload = resolvePresetDefinitionScope({ name: 'House Panel' }, tenantAActor);

      expect(payload.tenant_id).toBe('tenant-a');
    });

    it('ignores a tenant_id a tenant admin tries to forge', () => {
      expect(() =>
        resolvePresetDefinitionScope({ name: 'X', tenant_id: 'tenant-b' }, tenantAActor)
      ).toThrow(/scope_mismatch|Insufficient/i);
    });

    it('lets a platform admin create inside a named tenant', () => {
      const payload = resolvePresetDefinitionScope(
        { name: 'X', tenant_id: 'tenant-b' },
        platformActor
      );

      expect(payload.tenant_id).toBe('tenant-b');
    });

    it('refuses a tenantless non-platform request actor', () => {
      expect(() =>
        resolvePresetDefinitionScope({ name: 'X' }, { id: 'u1', permissions: [] })
      ).toThrow(HttpError);
    });

    it('never leaves the scope hint on the payload', () => {
      const payload = resolvePresetDefinitionScope(
        { scope: 'platform', name: 'X' },
        platformActor
      );

      expect(payload).not.toHaveProperty('scope');
    });
  });

  describe('buildVisibleDefinitionWhere', () => {
    it('shows a tenant the platform catalog plus its own entries', () => {
      expect(buildVisibleDefinitionWhere('tenant-a')).toEqual({
        OR: [{ tenant_id: null }, { tenant_id: 'tenant-a' }],
      });
    });

    it('never includes another tenant', () => {
      const where = buildVisibleDefinitionWhere('tenant-a');
      expect(JSON.stringify(where)).not.toContain('tenant-b');
    });

    it('shows only the platform catalog when there is no tenant', () => {
      expect(buildVisibleDefinitionWhere(null)).toEqual({ tenant_id: null });
    });
  });

  describe('adoption overrides', () => {
    it('keeps permitted fields and reports the rest', () => {
      const { allowed, rejected } = filterAdoptionOverrides('lab_test', {
        unit_price: 1200,
        is_active: false,
        name: 'Renamed',
        code: 'FBC',
      });

      expect(allowed).toEqual({ unit_price: 1200, is_active: false });
      expect(rejected.sort()).toEqual(['code', 'name']);
    });

    it('rejects an attempt to override the clinical identity of a preset', () => {
      expect(() =>
        assertAdoptionOverridesAllowed('lab_test', { unit_price: 10, name: 'Renamed' })
      ).toThrow(HttpError);
    });

    it('returns the permitted subset when everything is allowed', () => {
      expect(
        assertAdoptionOverridesAllowed('lab_panel', { unit_price: 50, is_active: true })
      ).toEqual({ unit_price: 50, is_active: true });
    });

    it.each(DOMAIN_NAMES)('never lets %s override its identity fields', (domain) => {
      const { platformOwned, overridable } = PRESET_DOMAINS[domain];
      const protectedFields = platformOwned.filter((field) => !overridable.includes(field));

      // `code` is how a shared preset is recognised across tenants, and the
      // naming field is how a clinician recognises it. Neither may be
      // overridden locally, whatever else the domain allows.
      const namingField = domain === 'clinical_term_catalog' ? 'description' : 'name';

      expect(protectedFields).toEqual(expect.arrayContaining(['code', namingField]));
      expect(overridable).not.toContain('code');
      expect(overridable).not.toContain(namingField);
    });
  });
});
