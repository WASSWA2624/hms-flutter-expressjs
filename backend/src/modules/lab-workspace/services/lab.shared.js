const { HttpError } = require('@lib/errors');
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
  gender: true,
  date_of_birth: true,
};

const ENCOUNTER_PUBLIC_SELECT = {
  id: true,
  human_friendly_id: true,
};

const TENANT_PUBLIC_SELECT = {
  id: true,
  human_friendly_id: true,
};

const LAB_TEST_PUBLIC_SELECT = {
  id: true,
  human_friendly_id: true,
  tenant_id: true,
  name: true,
  code: true,
  category: true,
  specimen_type: true,
  result_kind: true,
  unit: true,
  description: true,
  reference_range: true,
  created_at: true,
  updated_at: true,
};

const LAB_TEST_CONFIGURATION_SELECT = {
  ...LAB_TEST_PUBLIC_SELECT,
  reference_ranges: {
    orderBy: { sort_order: 'asc' },
  },
  unit_options: {
    orderBy: { sort_order: 'asc' },
  },
  result_options: {
    orderBy: { sort_order: 'asc' },
  },
};

const LAB_ORDER_ITEM_WITH_RELATIONS_INCLUDE = {
  lab_test: { select: LAB_TEST_CONFIGURATION_SELECT },
  lab_order: {
    include: {
      patient: { select: PATIENT_PUBLIC_SELECT },
      encounter: { select: ENCOUNTER_PUBLIC_SELECT },
    },
  },
  results: {
    where: { deleted_at: null },
    orderBy: { created_at: 'desc' },
  },
};

const LAB_ORDER_WITH_RELATIONS_INCLUDE = {
  patient: { select: PATIENT_PUBLIC_SELECT },
  encounter: { select: ENCOUNTER_PUBLIC_SELECT },
  items: {
    where: { deleted_at: null },
    orderBy: { created_at: 'asc' },
    include: {
      lab_test: { select: LAB_TEST_CONFIGURATION_SELECT },
      results: {
        where: { deleted_at: null },
        orderBy: { created_at: 'desc' },
      },
    },
  },
  samples: {
    where: { deleted_at: null },
    orderBy: { created_at: 'asc' },
  },
};

const LAB_SAMPLE_WITH_RELATIONS_INCLUDE = {
  lab_order: {
    include: {
      patient: { select: PATIENT_PUBLIC_SELECT },
      encounter: { select: ENCOUNTER_PUBLIC_SELECT },
    },
  },
};

const LAB_RESULT_WITH_RELATIONS_INCLUDE = {
  lab_order_item: {
    include: {
      lab_test: { select: LAB_TEST_CONFIGURATION_SELECT },
      lab_order: {
        include: {
          patient: { select: PATIENT_PUBLIC_SELECT },
          encounter: { select: ENCOUNTER_PUBLIC_SELECT },
        },
      },
    },
  },
};

const LAB_QC_LOG_WITH_RELATIONS_INCLUDE = {
  lab_test: { select: LAB_TEST_PUBLIC_SELECT },
};

const LAB_TEST_WITH_RELATIONS_INCLUDE = {
  tenant: { select: TENANT_PUBLIC_SELECT },
  reference_ranges: {
    orderBy: { sort_order: 'asc' },
  },
  unit_options: {
    orderBy: { sort_order: 'asc' },
  },
  result_options: {
    orderBy: { sort_order: 'asc' },
  },
};

const LAB_PANEL_WITH_RELATIONS_INCLUDE = {
  tenant: { select: TENANT_PUBLIC_SELECT },
  panel_items: {
    orderBy: { sort_order: 'asc' },
    include: {
      lab_test: { select: LAB_TEST_PUBLIC_SELECT },
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

module.exports = {
  PATIENT_PUBLIC_SELECT,
  ENCOUNTER_PUBLIC_SELECT,
  TENANT_PUBLIC_SELECT,
  LAB_TEST_PUBLIC_SELECT,
  LAB_TEST_CONFIGURATION_SELECT,
  LAB_ORDER_ITEM_WITH_RELATIONS_INCLUDE,
  LAB_ORDER_WITH_RELATIONS_INCLUDE,
  LAB_SAMPLE_WITH_RELATIONS_INCLUDE,
  LAB_RESULT_WITH_RELATIONS_INCLUDE,
  LAB_QC_LOG_WITH_RELATIONS_INCLUDE,
  LAB_TEST_WITH_RELATIONS_INCLUDE,
  LAB_PANEL_WITH_RELATIONS_INCLUDE,
  buildPagination,
  normalizeSearchTerm,
  toDateOrNull,
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
  applyDateRangeFilter,
};
