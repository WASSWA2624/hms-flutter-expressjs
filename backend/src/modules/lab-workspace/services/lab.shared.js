const { HttpError } = require('@lib/errors');
const prisma = require('@prisma/client');
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
  encounter_type: true,
  status: true,
  provider_user_id: true,
};

// Richer encounter projection used on lab order worklist rows so the lab bench
// can show whether the order originates from OPD vs IPD and, for inpatients,
// the current ward/room/bed location. Lab never mutates these — read-only context.
const LAB_ORDER_ENCOUNTER_SELECT = {
  ...ENCOUNTER_PUBLIC_SELECT,
  admissions: {
    where: { deleted_at: null, status: 'ADMITTED' },
    orderBy: { admitted_at: 'desc' },
    take: 1,
    select: {
      id: true,
      human_friendly_id: true,
      status: true,
      bed_assignments: {
        where: { deleted_at: null, released_at: null },
        orderBy: { assigned_at: 'desc' },
        take: 1,
        select: {
          id: true,
          bed: {
            select: {
              id: true,
              human_friendly_id: true,
              label: true,
              ward: { select: { id: true, human_friendly_id: true, name: true } },
              room: { select: { id: true, human_friendly_id: true, name: true } },
            },
          },
        },
      },
    },
  },
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
  encounter: { select: LAB_ORDER_ENCOUNTER_SELECT },
  ordered_by: { select: { id: true, human_friendly_id: true } },
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

/**
 * Resolve a clinical context identifier to an encounter id.
 * Accepts encounter, visit queue (VIS…), or admission public ids.
 *
 * @param {Object} options
 * @returns {Promise<string|null>}
 */
const resolveLabOrderEncounterId = async ({
  identifier,
  patientId = null,
  tenantId = null,
  facilityId = null,
} = {}) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) {
    return null;
  }

  const encounter = await resolveModelRecordByIdentifier({
    identifier: normalized,
    model: 'encounter',
    where: { deleted_at: null },
    select: { id: true },
  });
  if (encounter?.id) {
    return encounter.id;
  }

  const visitQueue = await resolveModelRecordByIdentifier({
    identifier: normalized,
    model: 'visit_queue',
    where: { deleted_at: null },
    select: {
      id: true,
      patient_id: true,
      tenant_id: true,
      facility_id: true,
    },
  });
  if (visitQueue) {
    const scopedPatientId = patientId || visitQueue.patient_id;
    const scopedTenantId = tenantId || visitQueue.tenant_id;
    const scopedFacilityId = facilityId ?? visitQueue.facility_id ?? null;

    const linkedEncounter = await prisma.encounter.findFirst({
      where: {
        deleted_at: null,
        tenant_id: scopedTenantId,
        patient_id: scopedPatientId,
        extension_json: {
          path: '$.opd_flow.visit_queue_id',
          equals: visitQueue.id,
        },
      },
      orderBy: { started_at: 'desc' },
      select: { id: true },
    });
    if (linkedEncounter?.id) {
      return linkedEncounter.id;
    }

    const openEncounter = await prisma.encounter.findFirst({
      where: {
        deleted_at: null,
        tenant_id: scopedTenantId,
        ...(scopedFacilityId ? { facility_id: scopedFacilityId } : {}),
        patient_id: scopedPatientId,
        status: 'OPEN',
      },
      orderBy: { started_at: 'desc' },
      select: { id: true },
    });
    if (openEncounter?.id) {
      return openEncounter.id;
    }

    return null;
  }

  const admission = await resolveModelRecordByIdentifier({
    identifier: normalized,
    model: 'admission',
    where: { deleted_at: null },
    select: { encounter_id: true },
  });
  if (admission?.encounter_id) {
    return admission.encounter_id;
  }

  throw new HttpError('errors.encounter.not_found', 404);
};

module.exports = {
  PATIENT_PUBLIC_SELECT,
  ENCOUNTER_PUBLIC_SELECT,
  LAB_ORDER_ENCOUNTER_SELECT,
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
  resolveLabOrderEncounterId,
  applyDateRangeFilter,
};
