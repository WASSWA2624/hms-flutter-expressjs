/**
 * Platform presets vs tenant configuration.
 *
 * Master data splits in two:
 *
 *   definition  a catalog entry. `tenant_id = null` makes it a platform preset
 *               owned centrally; a tenant id makes it that tenant's own entry.
 *               This mirrors how `role` and `permission` already carry platform
 *               scope, so there is one convention in the codebase, not two.
 *
 *   adoption    a facility taking a definition into use, carrying only the
 *               overrides that domain permits (price, availability, local
 *               naming). Adoptions are always tenant-scoped.
 *
 * A tenant may adopt a platform preset, override the permitted fields on its own
 * adoption row, and create its own definitions. It may never update or delete a
 * platform definition - that is enforced here, at the service layer, so the API
 * rejects it rather than the UI merely hiding it.
 *
 * @module lib/catalog/preset-ownership
 */

const { HttpError } = require('@lib/errors');
const {
  canActorCreatePlatformRole: actorHasPlatformAuthority,
  assertActorTenantMatches,
} = require('@lib/authorization/assignable-access');

/**
 * Per-domain contract.
 *
 * `overridable` lists the adoption fields a tenant may set. `platformOwned`
 * lists definition fields only a platform actor may change - they are the
 * clinical identity of the preset, which a tenant overriding locally would make
 * unsafe to share.
 */
const PRESET_DOMAINS = Object.freeze({
  lab_test: {
    definitionModel: 'lab_test',
    adoptionModel: 'facility_lab_test_offering',
    adoptionKey: 'lab_test_id',
    platformOwned: Object.freeze([
      'name', 'code', 'category', 'specimen_type', 'result_kind',
    ]),
    overridable: Object.freeze([
      'is_active', 'sort_order', 'unit_price', 'currency', 'unit',
      'description', 'reference_range', 'specimen_type', 'result_kind',
    ]),
  },
  lab_panel: {
    definitionModel: 'lab_panel',
    adoptionModel: 'facility_lab_panel_offering',
    adoptionKey: 'lab_panel_id',
    platformOwned: Object.freeze(['name', 'code', 'category']),
    overridable: Object.freeze([
      'is_active', 'sort_order', 'unit_price', 'currency',
    ]),
  },
  radiology_procedure: {
    definitionModel: 'radiology_procedure',
    adoptionModel: 'facility_radiology_procedure_offering',
    adoptionKey: 'radiology_procedure_id',
    platformOwned: Object.freeze([
      'name', 'code', 'modality', 'body_region', 'laterality', 'procedure_type',
    ]),
    overridable: Object.freeze([
      'is_active', 'sort_order', 'unit_price', 'currency',
    ]),
  },
  drug: {
    definitionModel: 'drug',
    adoptionModel: 'facility_pharmacy_offering',
    adoptionKey: 'drug_id',
    platformOwned: Object.freeze([
      'name', 'code', 'generic_name', 'form', 'strength',
    ]),
    overridable: Object.freeze([
      'is_active', 'sort_order', 'unit_price', 'currency',
      'default_storage_shelf_id',
    ]),
  },
  clinical_term_catalog: {
    definitionModel: 'clinical_term_catalog',
    // Keyed by (term_type, item_id) rather than a single FK column, because one
    // offering table serves diagnoses, procedures and the rest.
    adoptionModel: 'facility_catalog_offering',
    adoptionKey: 'item_id',
    platformOwned: Object.freeze([
      'description', 'code', 'term_type', 'catalog_key', 'category',
    ]),
    overridable: Object.freeze([
      'is_active', 'sort_order',
    ]),
  },
});

const DOMAIN_NAMES = Object.freeze(Object.keys(PRESET_DOMAINS));

/**
 * @param {string} domain
 * @returns {Object} Domain contract
 */
const getPresetDomain = (domain) => {
  const contract = PRESET_DOMAINS[domain];
  if (!contract) {
    throw new Error(`Unknown preset domain "${domain}".`);
  }
  return contract;
};

const normalizeId = (value) =>
  value == null || String(value).trim() === '' ? null : String(value).trim();

/** A definition with no tenant is a centrally owned platform preset. */
const isPlatformDefinition = (definition = {}) =>
  normalizeId(definition.tenant_id) === null;

/**
 * Is this a trusted internal call rather than a request actor?
 *
 * `auth.middleware` always normalises `permissions` to an array for anything
 * arriving over HTTP, so only in-process callers - seeders, backfills, other
 * services - reach here without one. The same signal already gates
 * `assertCanAccessTenantRecord` in the tenant module; this reuses it rather
 * than inventing a second notion of "internal".
 */
const isTrustedInternalCaller = (actor = {}) => !Array.isArray(actor?.permissions);

/** Does this actor hold platform authority over the preset catalog? */
const actorCanManagePlatformPresets = (actor = {}) => actorHasPlatformAuthority(actor);

/**
 * Reject a tenant-scoped actor mutating a platform preset definition.
 *
 * Used by update and delete on every definition service. Tenant actors get the
 * standard 403 rather than a 404, because the preset legitimately exists and is
 * readable - it is the write that is refused.
 *
 * @param {Object} definition - The stored definition row
 * @param {Object} actor - Request actor
 * @param {Object} [options]
 * @param {string} [options.action] - 'update' | 'delete', for the error detail
 * @returns {void}
 */
const assertCanMutatePresetDefinition = (definition = {}, actor = {}, { action = 'update' } = {}) => {
  if (isTrustedInternalCaller(actor)) {
    return;
  }

  if (!isPlatformDefinition(definition)) {
    // Tenant-owned definition: ordinary tenant scoping applies.
    assertActorTenantMatches(normalizeId(definition.tenant_id), actor);
    return;
  }

  if (actorCanManagePlatformPresets(actor)) {
    return;
  }

  throw new HttpError('errors.auth.insufficient_permissions', 403, [
    {
      field: 'tenant_id',
      reason: action === 'delete'
        ? 'platform_preset_delete_forbidden'
        : 'platform_preset_update_forbidden',
    },
  ]);
};

/**
 * Resolve the scope a new definition is created at.
 *
 * Explicit `scope: 'platform'` asks for a platform preset and requires platform
 * authority. Anything else is created inside the actor's own tenant, whatever
 * `tenant_id` the payload claims - a tenant actor cannot create a definition in
 * another tenant, or at platform scope, by crafting the body.
 *
 * @param {Object} payload
 * @param {Object} actor
 * @returns {Object} Payload with a settled `tenant_id`
 */
const resolvePresetDefinitionScope = (payload = {}, actor = {}) => {
  const requestedScope = String(payload.scope || '').trim().toLowerCase();
  const { scope: _scope, ...fields } = payload;

  if (isTrustedInternalCaller(actor)) {
    return requestedScope === 'platform' ? { ...fields, tenant_id: null } : fields;
  }

  if (requestedScope === 'platform') {
    if (!actorCanManagePlatformPresets(actor)) {
      throw new HttpError('errors.auth.insufficient_permissions', 403, [
        { field: 'tenant_id', reason: 'platform_scope_forbidden' },
      ]);
    }
    return { ...fields, tenant_id: null };
  }

  const actorTenantId = normalizeId(actor.tenant_id || actor.tenantId);
  const requestedTenantId = normalizeId(fields.tenant_id);

  if (actorCanManagePlatformPresets(actor)) {
    // Platform actors may act on behalf of a named tenant.
    return { ...fields, tenant_id: requestedTenantId ?? actorTenantId };
  }

  if (requestedTenantId && requestedTenantId !== actorTenantId) {
    throw new HttpError('errors.auth.scope_mismatch', 403, [
      { field: 'tenant_id', reason: 'outside_actor_tenant' },
    ]);
  }

  if (!actorTenantId) {
    throw new HttpError('errors.auth.insufficient_permissions', 403, [
      { field: 'tenant_id', reason: 'tenant_scope_required' },
    ]);
  }

  return { ...fields, tenant_id: actorTenantId };
};

/**
 * Where-clause selecting the definitions a tenant may see: the platform catalog
 * plus its own entries. Never another tenant's.
 *
 * @param {string|null} tenantId
 * @returns {Object}
 */
const buildVisibleDefinitionWhere = (tenantId) => {
  const normalized = normalizeId(tenantId);
  if (!normalized) {
    return { tenant_id: null };
  }
  return { OR: [{ tenant_id: null }, { tenant_id: normalized }] };
};

/**
 * Drop any field a tenant is not allowed to set on an adoption row.
 *
 * Returns the permitted subset plus the rejected keys, so callers can surface a
 * precise error instead of silently ignoring input.
 *
 * @param {string} domain
 * @param {Object} payload
 * @returns {{ allowed: Object, rejected: string[] }}
 */
const filterAdoptionOverrides = (domain, payload = {}) => {
  const { overridable } = getPresetDomain(domain);
  const permitted = new Set(overridable);
  const allowed = {};
  const rejected = [];

  for (const [key, value] of Object.entries(payload)) {
    if (permitted.has(key)) {
      allowed[key] = value;
    } else {
      rejected.push(key);
    }
  }

  return { allowed, rejected };
};

/**
 * Throw when an adoption payload carries a field the domain does not permit.
 *
 * @param {string} domain
 * @param {Object} payload
 * @returns {Object} The permitted subset
 */
const assertAdoptionOverridesAllowed = (domain, payload = {}) => {
  const { allowed, rejected } = filterAdoptionOverrides(domain, payload);
  if (rejected.length > 0) {
    throw new HttpError('errors.catalog.preset.not_overridable', 422,
      rejected.map((field) => ({ field, reason: 'not_overridable' })));
  }
  return allowed;
};

module.exports = {
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
};
