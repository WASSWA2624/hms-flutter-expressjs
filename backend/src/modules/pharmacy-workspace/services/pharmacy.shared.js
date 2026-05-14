const { HttpError } = require('@lib/errors');
const { normalizeUserContext } = require('@middlewares/auth.middleware');
const { ROLES } = require('@config/roles');
const {
  normalizeIdentifier,
  resolveModelIdByIdentifier,
  resolveModelRecordByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');

const PATIENT_PUBLIC_SELECT = {
  id: true,
  human_friendly_id: true,
  tenant_id: true,
  facility_id: true,
  first_name: true,
  last_name: true,
};

const ENCOUNTER_PUBLIC_SELECT = {
  id: true,
  human_friendly_id: true,
};

const DRUG_PUBLIC_SELECT = {
  id: true,
  human_friendly_id: true,
  name: true,
  code: true,
  form: true,
  strength: true,
};

const INVENTORY_ITEM_PUBLIC_SELECT = {
  id: true,
  human_friendly_id: true,
  tenant_id: true,
  name: true,
  category: true,
  sku: true,
  unit: true,
};

const PHARMACY_ORDER_WITH_RELATIONS_INCLUDE = {
  patient: { select: PATIENT_PUBLIC_SELECT },
  encounter: { select: ENCOUNTER_PUBLIC_SELECT },
  items: {
    where: { deleted_at: null },
    orderBy: { created_at: 'asc' },
    include: {
      dispense_logs: {
        where: { deleted_at: null },
        orderBy: { created_at: 'asc' },
      },
      drug: {
        select: {
          ...DRUG_PUBLIC_SELECT,
          inventory_maps: {
            where: { deleted_at: null },
            orderBy: [{ is_default: 'desc' }, { created_at: 'asc' }],
            include: {
              inventory_item: {
                select: INVENTORY_ITEM_PUBLIC_SELECT,
              },
            },
          },
        },
      },
    },
  },
  dispense_attestations: {
    where: { deleted_at: null },
    orderBy: [{ attested_at: 'desc' }, { created_at: 'desc' }],
  },
};

const INVENTORY_STOCK_WITH_RELATIONS_INCLUDE = {
  inventory_item: {
    select: INVENTORY_ITEM_PUBLIC_SELECT,
  },
  facility: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
    },
  },
};

const buildPagination = (page, limit, total) => {
  const safePage = Number.isFinite(Number(page)) ? Number(page) : 1;
  const safeLimit = Number.isFinite(Number(limit)) ? Number(limit) : 20;
  const totalPages = Math.max(1, Math.ceil(total / safeLimit));

  return {
    page: safePage,
    limit: safeLimit,
    total,
    totalPages,
    hasNextPage: safePage < totalPages,
    hasPreviousPage: safePage > 1,
  };
};

const normalizeSearchTerm = (value) => {
  const term = typeof value === 'string' ? value.trim() : '';
  if (!term) return null;

  return {
    raw: term,
    upper: term.toUpperCase(),
  };
};

const toDateOrNull = (value, fallback = null) => {
  if (!value) return fallback;
  const parsed = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(parsed.getTime())) return fallback;
  return parsed;
};

const resolveModelIdOrThrow = async ({
  identifier,
  model,
  where = {},
  errorKey = 'errors.resource.not_found',
  allowNull = false,
}) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) {
    if (allowNull) return null;
    throw new HttpError(errorKey, 404);
  }

  const resolved = await resolveModelIdByIdentifier({
    model,
    identifier: normalized,
    where,
  });

  if (!resolved) {
    throw new HttpError(errorKey, 404);
  }

  return resolved;
};

const resolveModelRecordOrThrow = async ({
  identifier,
  model,
  where = {},
  include,
  select,
  errorKey = 'errors.resource.not_found',
}) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) {
    throw new HttpError(errorKey, 404);
  }

  const record = await resolveModelRecordByIdentifier({
    model,
    identifier: normalized,
    where,
    include,
    select,
  });

  if (!record) {
    throw new HttpError(errorKey, 404);
  }

  return record;
};

const applyDateRangeFilter = (where, field, fromValue, toValue) => {
  const from = toDateOrNull(fromValue, null);
  const to = toDateOrNull(toValue, null);
  if (!from && !to) return;

  where[field] = {};
  if (from) where[field].gte = from;
  if (to) where[field].lte = to;
};

const resolveScopedUserContext = (user = {}) => {
  const normalizedUser = normalizeUserContext(user || {});
  const roles = Array.isArray(normalizedUser.roles) ? normalizedUser.roles : [];
  const canManageAllTenants = roles.includes(ROLES.SUPER_ADMIN);
  const tenantId = normalizedUser.tenant_id || null;
  const facilityId = normalizedUser.facility_id || null;

  if (!canManageAllTenants && !tenantId) {
    throw new HttpError('errors.auth.scope_mismatch', 403);
  }

  return {
    user: normalizedUser,
    tenant_id: tenantId,
    facility_id: facilityId,
    can_manage_all_tenants: canManageAllTenants,
  };
};

const buildTenantScopeWhere = (scope = {}, tenantField = 'tenant_id') => {
  if (scope?.can_manage_all_tenants || !scope?.tenant_id) {
    return {};
  }

  return {
    [tenantField]: scope.tenant_id,
  };
};

const buildTenantFacilityScopeWhere = (
  scope = {},
  { tenantField = 'tenant_id', facilityField = 'facility_id' } = {}
) => {
  const where = buildTenantScopeWhere(scope, tenantField);

  if (!scope?.can_manage_all_tenants && scope?.facility_id) {
    where[facilityField] = scope.facility_id;
  }

  return where;
};

const buildPatientScopeWhere = (scope = {}) => buildTenantFacilityScopeWhere(scope);

const buildEncounterScopeWhere = (scope = {}) => buildTenantFacilityScopeWhere(scope);

const buildDrugScopeWhere = (scope = {}) => buildTenantScopeWhere(scope);

const buildInventoryItemScopeWhere = (scope = {}) => buildTenantScopeWhere(scope);

const buildOrderScopeWhere = (scope = {}) => {
  const patientWhere = buildPatientScopeWhere(scope);
  if (!Object.keys(patientWhere).length) return {};

  return {
    patient: patientWhere,
  };
};

const buildOrderItemScopeWhere = (scope = {}) => {
  const orderWhere = buildOrderScopeWhere(scope);
  if (!Object.keys(orderWhere).length) return {};

  return {
    pharmacy_order: orderWhere,
  };
};

const buildInventoryStockScopeWhere = (scope = {}) => {
  if (scope?.can_manage_all_tenants) {
    return {};
  }

  const where = {};
  const inventoryItemWhere = buildInventoryItemScopeWhere(scope);

  if (Object.keys(inventoryItemWhere).length) {
    where.inventory_item = inventoryItemWhere;
  }

  if (scope?.facility_id) {
    where.facility_id = scope.facility_id;
  }

  return where;
};

const matchesTenantFacilityScope = (
  record = {},
  scope = {},
  { tenantField = 'tenant_id', facilityField = 'facility_id' } = {}
) => {
  if (scope?.can_manage_all_tenants) return true;
  if (!scope?.tenant_id) return false;
  if (String(record?.[tenantField] || '') !== String(scope.tenant_id)) return false;
  if (scope?.facility_id && String(record?.[facilityField] || '') !== String(scope.facility_id)) {
    return false;
  }
  return true;
};

const matchesOrderScope = (orderRecord = {}, scope = {}) =>
  matchesTenantFacilityScope(orderRecord?.patient || {}, scope);

const matchesOrderItemScope = (orderItemRecord = {}, scope = {}) =>
  matchesOrderScope(orderItemRecord?.pharmacy_order || {}, scope);

const matchesInventoryStockScope = (stockRecord = {}, scope = {}) => {
  if (scope?.can_manage_all_tenants) return true;
  if (!scope?.tenant_id) return false;
  if (String(stockRecord?.inventory_item?.tenant_id || '') !== String(scope.tenant_id)) return false;
  if (scope?.facility_id && String(stockRecord?.facility_id || '') !== String(scope.facility_id)) {
    return false;
  }
  return true;
};

module.exports = {
  PATIENT_PUBLIC_SELECT,
  ENCOUNTER_PUBLIC_SELECT,
  DRUG_PUBLIC_SELECT,
  INVENTORY_ITEM_PUBLIC_SELECT,
  PHARMACY_ORDER_WITH_RELATIONS_INCLUDE,
  INVENTORY_STOCK_WITH_RELATIONS_INCLUDE,
  buildPagination,
  normalizeSearchTerm,
  toDateOrNull,
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
  applyDateRangeFilter,
  resolveScopedUserContext,
  buildTenantScopeWhere,
  buildTenantFacilityScopeWhere,
  buildPatientScopeWhere,
  buildEncounterScopeWhere,
  buildDrugScopeWhere,
  buildInventoryItemScopeWhere,
  buildOrderScopeWhere,
  buildOrderItemScopeWhere,
  buildInventoryStockScopeWhere,
  matchesOrderScope,
  matchesOrderItemScope,
  matchesInventoryStockScope,
};
