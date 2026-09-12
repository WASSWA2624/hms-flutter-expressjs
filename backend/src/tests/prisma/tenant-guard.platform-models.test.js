/**
 * Platform-shared model coverage in the tenant guard
 *
 * Step 07, AC3/AC4: the database-level guard must let every tenant read the
 * platform preset tier while still hiding other tenants' rows.
 *
 * `PLATFORM_SHARED_MODELS` is written out literally in `tenant-guard.js` — it
 * sits under the Prisma client, so importing the preset registry there would
 * create a require cycle. That makes it possible for the two to drift, which is
 * what this suite exists to stop: a preset domain added without registering it
 * here would have its presets silently invisible to every tenant.
 */

const fs = require('fs');
const path = require('path');

const { buildGuardedWhere } = require('../../prisma/tenant-guard');
const { PRESET_DOMAINS } = require('@lib/catalog/preset-ownership');

const GUARD_SOURCE = fs.readFileSync(
  path.join(__dirname, '..', '..', 'prisma', 'tenant-guard.js'),
  'utf8'
);

/** Read the literal set out of the guard source. */
const declaredPlatformModels = () => {
  const block = GUARD_SOURCE.match(
    /const PLATFORM_SHARED_MODELS = new Set\(\[([\s\S]*?)\]\)/
  );
  if (!block) throw new Error('PLATFORM_SHARED_MODELS not found in tenant-guard.js');

  return new Set(
    [...block[1].matchAll(/'([^']+)'/g)].map((match) => match[1])
  );
};

const METADATA = { hasId: true, hasTenantId: true, hasDeletedAt: true };

describe('tenant guard platform-shared models', () => {
  describe('registry coverage', () => {
    it('shares every preset definition model', () => {
      const declared = declaredPlatformModels();
      const missing = Object.values(PRESET_DOMAINS)
        .map((contract) => contract.definitionModel)
        .filter((model) => !declared.has(model));

      expect(missing).toEqual([]);
    });

    it('keeps sharing roles and permissions', () => {
      const declared = declaredPlatformModels();

      expect(declared.has('role')).toBe(true);
      expect(declared.has('permission')).toBe(true);
    });

    it('never shares an adoption table', () => {
      // Adoptions are always tenant-owned. Sharing one would expose another
      // tenant's prices and availability.
      const declared = declaredPlatformModels();
      const shared = Object.values(PRESET_DOMAINS)
        .map((contract) => contract.adoptionModel)
        .filter((model) => declared.has(model));

      expect(shared).toEqual([]);
    });

    it('never shares an operational table', () => {
      const declared = declaredPlatformModels();
      const operational = [
        'patient', 'encounter', 'invoice', 'payment', 'visit_queue',
        'admission', 'appointment', 'lab_order', 'radiology_order',
      ];

      expect(operational.filter((model) => declared.has(model))).toEqual([]);
    });
  });

  describe('buildGuardedWhere', () => {
    it('widens a shared model to the tenant plus the platform tier', () => {
      const where = buildGuardedWhere({}, METADATA, 'tenant-a', {
        includePlatformCatalog: true,
      });

      expect(JSON.stringify(where)).toContain('"tenant_id":null');
      expect(JSON.stringify(where)).toContain('tenant-a');
    });

    it('never widens beyond the platform tier', () => {
      const where = buildGuardedWhere({}, METADATA, 'tenant-a', {
        includePlatformCatalog: true,
      });

      // The only relaxation is `tenant_id: null`. No other tenant appears.
      expect(JSON.stringify(where)).not.toContain('tenant-b');
    });

    it('pins an unshared model to the tenant alone', () => {
      const where = buildGuardedWhere({}, METADATA, 'tenant-a', {
        includePlatformCatalog: false,
      });

      expect(JSON.stringify(where)).not.toContain('"tenant_id":null');
      expect(JSON.stringify(where)).toContain('tenant-a');
    });

    it('keeps a caller-supplied filter alongside the tenant constraint', () => {
      const where = buildGuardedWhere({ code: 'FBC' }, METADATA, 'tenant-a', {
        includePlatformCatalog: true,
      });

      expect(JSON.stringify(where)).toContain('FBC');
      expect(JSON.stringify(where)).toContain('tenant-a');
    });

    it('adds the soft-delete filter when the model supports it', () => {
      const where = buildGuardedWhere({}, METADATA, 'tenant-a', {
        includePlatformCatalog: true,
        enforceActiveRecord: true,
      });

      expect(JSON.stringify(where)).toContain('"deleted_at":null');
    });
  });
});
