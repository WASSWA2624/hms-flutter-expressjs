const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');
const { isUuidLike } = require('@lib/identifiers/sanitize-friendly-ids');

const ACTIVE_STORAGE_ASSIGNMENT_WHERE = Object.freeze({
  deleted_at: null,
  assignment_status: 'ACTIVE',
  ended_at: null,
});

const BILLING_SETTLED_STATUSES = Object.freeze(['SETTLED', 'PAID', 'CANCELLED']);
const POST_MORTEM_ACTIVE_STATUSES = Object.freeze([
  'REQUESTED',
  'APPROVED',
  'SCHEDULED',
  'IN_PROGRESS',
]);
const STORAGE_EXCEPTION_STATUSES = Object.freeze([
  'HELD',
  'OUT_OF_SERVICE',
  'CLEANING',
]);

const normalizeString = (value) => String(value || '').trim();

const buildBaseWhere = ({ tenantId, facilityId }) => ({
  deleted_at: null,
  tenant_id: tenantId || '__missing_tenant__',
  ...(facilityId ? { facility_id: facilityId } : {}),
});

const appendAnd = (where, clause) => {
  if (!clause || Object.keys(clause).length === 0) return where;
  where.AND = [...(Array.isArray(where.AND) ? where.AND : []), clause];
  return where;
};

const appendIdentifierFilter = (where, identifier) => {
  const normalized = normalizeString(identifier);
  if (!normalized) return where;

  const matches = [{ human_friendly_id: normalized.toUpperCase() }];
  if (isUuidLike(normalized)) {
    matches.unshift({ id: normalized });
  }

  return appendAnd(where, { OR: matches });
};

const appendSearchFilter = (where, search, clauses) => {
  const normalized = normalizeString(search);
  if (!normalized) return where;

  return appendAnd(where, {
    OR: clauses(normalized, normalized.toUpperCase()),
  });
};

const getDateWindow = (preset) => {
  const normalized = normalizeString(preset);
  const now = new Date();
  const todayStart = new Date(now);
  todayStart.setHours(0, 0, 0, 0);

  if (normalized === 'today') {
    const todayEnd = new Date(todayStart);
    todayEnd.setDate(todayEnd.getDate() + 1);
    return { gte: todayStart, lt: todayEnd };
  }

  if (normalized === 'next_7_days') {
    const end = new Date(now);
    end.setDate(end.getDate() + 7);
    return { gte: now, lte: end };
  }

  if (normalized === 'overdue') {
    return { lt: now };
  }

  if (normalized === 'this_month') {
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const nextMonth = new Date(now.getFullYear(), now.getMonth() + 1, 1);
    return { gte: monthStart, lt: nextMonth };
  }

  return null;
};

const applyDatePreset = (where, field, datePreset) => {
  const range = getDateWindow(datePreset);
  if (range) where[field] = range;
  return where;
};

const appendCaseQueueFilter = (where, queue) => {
  if (queue === 'IDENTIFICATION_PENDING') {
    return appendAnd(where, {
      OR: [
        { status: 'IDENTIFICATION_PENDING' },
        { identification_status: { not: 'VERIFIED' } },
      ],
    });
  }

  if (queue === 'STORAGE_EXCEPTIONS') {
    return appendAnd(where, {
      storage_assignments: {
        some: {
          deleted_at: null,
          OR: [
            { assignment_status: { not: 'ACTIVE' } },
            { storage_slot: { status: { in: STORAGE_EXCEPTION_STATUSES } } },
          ],
        },
      },
    });
  }

  if (queue === 'RELEASE_READY') {
    return appendAnd(where, {
      OR: [
        { status: 'READY_FOR_RELEASE' },
        {
          release_authorisations: {
            some: { deleted_at: null, status: 'APPROVED', released_at: null },
          },
        },
      ],
    });
  }

  if (queue === 'UNSETTLED_BILLING') {
    return appendAnd(where, {
      OR: [
        { billing_status: { notIn: BILLING_SETTLED_STATUSES } },
        {
          billable_events: {
            some: {
              deleted_at: null,
              status: { notIn: BILLING_SETTLED_STATUSES },
            },
          },
        },
      ],
    });
  }

  if (queue === 'POST_MORTEM_PENDING') {
    return appendAnd(where, {
      OR: [
        { status: 'POST_MORTEM_PENDING' },
        {
          post_mortem_requests: {
            some: {
              deleted_at: null,
              status: { in: POST_MORTEM_ACTIVE_STATUSES },
            },
          },
        },
      ],
    });
  }

  return where;
};

const buildCaseWhere = (filters = {}) => {
  const where = buildBaseWhere(filters);

  if (filters.status) where.status = filters.status;
  if (filters.identificationStatus) {
    where.identification_status = filters.identificationStatus;
  }
  if (filters.storageUnitId || filters.storageSlotId) {
    appendAnd(where, {
      storage_assignments: {
        some: {
          ...ACTIVE_STORAGE_ASSIGNMENT_WHERE,
          ...(filters.storageUnitId ? { storage_unit_id: filters.storageUnitId } : {}),
          ...(filters.storageSlotId ? { storage_slot_id: filters.storageSlotId } : {}),
        },
      },
    });
  }

  appendCaseQueueFilter(where, filters.queue);
  applyDatePreset(where, 'received_at', filters.datePreset);
  appendIdentifierFilter(where, filters.id);
  appendSearchFilter(where, filters.search, (search, upperSearch) => [
    { human_friendly_id: { contains: upperSearch } },
    { source_workflow: { contains: search } },
    { source_department: { contains: search } },
    { source_reference_id: { contains: search } },
    { received_from: { contains: search } },
    { deceased_profile: { display_name: { contains: search } } },
    { deceased_profile: { human_friendly_id: { contains: upperSearch } } },
    { patient: { human_friendly_id: { contains: upperSearch } } },
    { patient: { first_name: { contains: search } } },
    { patient: { last_name: { contains: search } } },
  ]);

  return where;
};

const buildStorageUnitWhere = (filters = {}) => {
  const where = buildBaseWhere(filters);
  if (filters.status) where.status = filters.status;
  appendIdentifierFilter(where, filters.id);
  appendSearchFilter(where, filters.search, (search, upperSearch) => [
    { human_friendly_id: { contains: upperSearch } },
    { name: { contains: search } },
    { unit_type: { contains: search } },
    { location_label: { contains: search } },
  ]);
  return where;
};

const buildStorageSlotWhere = (filters = {}) => {
  const where = buildBaseWhere(filters);
  if (filters.storageUnitId) where.storage_unit_id = filters.storageUnitId;
  if (filters.storageSlotId) where.id = filters.storageSlotId;
  if (filters.status) where.status = filters.status;
  appendIdentifierFilter(where, filters.id);
  appendSearchFilter(where, filters.search, (search, upperSearch) => [
    { human_friendly_id: { contains: upperSearch } },
    { slot_code: { contains: search } },
    { label: { contains: search } },
    { temperature_zone: { contains: search } },
    { storage_unit: { name: { contains: search } } },
  ]);
  return where;
};

const buildStorageAssignmentWhere = (filters = {}) => {
  const where = buildBaseWhere(filters);
  if (filters.storageUnitId) where.storage_unit_id = filters.storageUnitId;
  if (filters.storageSlotId) where.storage_slot_id = filters.storageSlotId;
  if (filters.status) where.assignment_status = filters.status;
  if (filters.queue === 'STORAGE_EXCEPTIONS') {
    appendAnd(where, {
      OR: [
        { assignment_status: { not: 'ACTIVE' } },
        { storage_slot: { status: { in: STORAGE_EXCEPTION_STATUSES } } },
      ],
    });
  }
  applyDatePreset(where, 'assigned_at', filters.datePreset);
  appendIdentifierFilter(where, filters.id);
  appendSearchFilter(where, filters.search, (search, upperSearch) => [
    { human_friendly_id: { contains: upperSearch } },
    { mortuary_case: { human_friendly_id: { contains: upperSearch } } },
    { mortuary_case: { deceased_profile: { display_name: { contains: search } } } },
    { storage_unit: { name: { contains: search } } },
    { storage_slot: { slot_code: { contains: search } } },
    { storage_slot: { label: { contains: search } } },
  ]);
  return where;
};

const buildCustodyEventWhere = (filters = {}) => {
  const where = buildBaseWhere(filters);
  if (filters.status) where.event_type = filters.status;
  applyDatePreset(where, 'event_at', filters.datePreset);
  appendIdentifierFilter(where, filters.id);
  appendSearchFilter(where, filters.search, (search, upperSearch) => [
    { human_friendly_id: { contains: upperSearch } },
    { actor_name: { contains: search } },
    { actor_role: { contains: search } },
    { location_label: { contains: search } },
    { reason: { contains: search } },
    { mortuary_case: { human_friendly_id: { contains: upperSearch } } },
    { mortuary_case: { deceased_profile: { display_name: { contains: search } } } },
  ]);
  return where;
};

const buildViewingWhere = (filters = {}) => {
  const where = buildBaseWhere(filters);
  if (filters.status) where.status = filters.status;
  applyDatePreset(where, 'scheduled_at', filters.datePreset);
  appendIdentifierFilter(where, filters.id);
  appendSearchFilter(where, filters.search, (search, upperSearch) => [
    { human_friendly_id: { contains: upperSearch } },
    { authorised_by_name: { contains: search } },
    { attendee_summary: { contains: search } },
    { mortuary_case: { human_friendly_id: { contains: upperSearch } } },
    { mortuary_case: { deceased_profile: { display_name: { contains: search } } } },
  ]);
  return where;
};

const buildPostMortemWhere = (filters = {}) => {
  const where = buildBaseWhere(filters);
  if (filters.status) where.status = filters.status;
  if (filters.queue === 'POST_MORTEM_PENDING') {
    where.status = { in: POST_MORTEM_ACTIVE_STATUSES };
  }
  applyDatePreset(where, 'scheduled_at', filters.datePreset);
  appendIdentifierFilter(where, filters.id);
  appendSearchFilter(where, filters.search, (search, upperSearch) => [
    { human_friendly_id: { contains: upperSearch } },
    { requested_by_name: { contains: search } },
    { diagnostics_reference_id: { contains: search } },
    { mortuary_case: { human_friendly_id: { contains: upperSearch } } },
    { mortuary_case: { deceased_profile: { display_name: { contains: search } } } },
  ]);
  return where;
};

const buildReleaseWhere = (filters = {}) => {
  const where = buildBaseWhere(filters);
  if (filters.status) where.status = filters.status;
  if (filters.queue === 'RELEASE_READY') {
    where.status = 'APPROVED';
    where.released_at = null;
  }
  applyDatePreset(where, 'approved_at', filters.datePreset);
  appendIdentifierFilter(where, filters.id);
  appendSearchFilter(where, filters.search, (search, upperSearch) => [
    { human_friendly_id: { contains: upperSearch } },
    { recipient_name: { contains: search } },
    { recipient_relationship: { contains: search } },
    { verification_reference: { contains: search } },
    { funeral_service_name: { contains: search } },
    { mortuary_case: { human_friendly_id: { contains: upperSearch } } },
    { mortuary_case: { deceased_profile: { display_name: { contains: search } } } },
  ]);
  return where;
};

const buildBillableEventWhere = (filters = {}) => {
  const where = buildBaseWhere(filters);
  if (filters.status) where.status = filters.status;
  if (filters.queue === 'UNSETTLED_BILLING') {
    where.status = { notIn: BILLING_SETTLED_STATUSES };
  }
  applyDatePreset(where, 'charged_at', filters.datePreset);
  appendIdentifierFilter(where, filters.id);
  appendSearchFilter(where, filters.search, (search, upperSearch) => [
    { human_friendly_id: { contains: upperSearch } },
    { event_type: { contains: search } },
    { billing_reference_id: { contains: search } },
    { mortuary_case: { human_friendly_id: { contains: upperSearch } } },
    { mortuary_case: { deceased_profile: { display_name: { contains: search } } } },
  ]);
  return where;
};

const CASE_SUMMARY_SELECT = Object.freeze({
  id: true,
  human_friendly_id: true,
  status: true,
  identification_status: true,
  received_at: true,
  release_ready_at: true,
  released_at: true,
  billing_status: true,
  deceased_profile: {
    select: {
      id: true,
      human_friendly_id: true,
      display_name: true,
      external_reference: true,
    },
  },
});

const caseSelect = {
  id: true,
  human_friendly_id: true,
  facility_id: true,
  status: true,
  identification_status: true,
  source_workflow: true,
  source_department: true,
  source_reference_id: true,
  received_from: true,
  received_at: true,
  release_ready_at: true,
  released_at: true,
  closed_at: true,
  billing_status: true,
  created_at: true,
  updated_at: true,
  facility: {
    select: { id: true, human_friendly_id: true, name: true },
  },
  patient: {
    select: {
      id: true,
      human_friendly_id: true,
      first_name: true,
      last_name: true,
    },
  },
  deceased_profile: {
    select: {
      id: true,
      human_friendly_id: true,
      display_name: true,
      date_of_death: true,
      external_reference: true,
    },
  },
  storage_assignments: {
    where: ACTIVE_STORAGE_ASSIGNMENT_WHERE,
    orderBy: { assigned_at: 'desc' },
    take: 1,
    select: {
      id: true,
      human_friendly_id: true,
      assignment_status: true,
      assigned_at: true,
      ended_at: true,
      storage_unit: {
        select: { id: true, human_friendly_id: true, name: true, unit_type: true },
      },
      storage_slot: {
        select: {
          id: true,
          human_friendly_id: true,
          slot_code: true,
          label: true,
          status: true,
          temperature_zone: true,
        },
      },
    },
  },
  custody_events: {
    where: { deleted_at: null },
    orderBy: { event_at: 'desc' },
    take: 8,
    select: {
      id: true,
      human_friendly_id: true,
      event_type: true,
      event_at: true,
      actor_name: true,
      actor_role: true,
      location_label: true,
      reason: true,
      notes: true,
      created_at: true,
      updated_at: true,
    },
  },
  viewings: {
    where: { deleted_at: null },
    orderBy: { scheduled_at: 'desc' },
    take: 5,
    select: {
      id: true,
      human_friendly_id: true,
      scheduled_at: true,
      status: true,
      authorised_by_name: true,
      attendee_summary: true,
      completed_at: true,
    },
  },
  post_mortem_requests: {
    where: { deleted_at: null },
    orderBy: { created_at: 'desc' },
    take: 5,
    select: {
      id: true,
      human_friendly_id: true,
      requested_by_name: true,
      request_reason: true,
      status: true,
      diagnostics_reference_id: true,
      scheduled_at: true,
      completed_at: true,
      report_received_at: true,
    },
  },
  release_authorisations: {
    where: { deleted_at: null },
    orderBy: { created_at: 'desc' },
    take: 5,
    select: {
      id: true,
      human_friendly_id: true,
      recipient_name: true,
      recipient_relationship: true,
      verification_reference: true,
      funeral_service_name: true,
      release_method: true,
      status: true,
      approved_by_name: true,
      approved_at: true,
      released_at: true,
    },
  },
  billable_events: {
    where: { deleted_at: null },
    orderBy: { charged_at: 'desc' },
    take: 5,
    select: {
      id: true,
      human_friendly_id: true,
      event_type: true,
      description: true,
      amount: true,
      currency: true,
      status: true,
      billing_reference_id: true,
      charged_at: true,
      settled_at: true,
    },
  },
};

const RESOURCE_CONFIG = Object.freeze({
  'mortuary-cases': {
    delegate: 'mortuary_case',
    where: buildCaseWhere,
    query: { select: caseSelect },
  },
  'mortuary-storage-units': {
    delegate: 'mortuary_storage_unit',
    where: buildStorageUnitWhere,
    query: {
      select: {
        id: true,
        human_friendly_id: true,
        facility_id: true,
        name: true,
        unit_type: true,
        status: true,
        location_label: true,
        capacity: true,
        created_at: true,
        updated_at: true,
        facility: { select: { id: true, human_friendly_id: true, name: true } },
        _count: { select: { slots: true, assignments: true } },
      },
    },
  },
  'mortuary-storage-slots': {
    delegate: 'mortuary_storage_slot',
    where: buildStorageSlotWhere,
    query: {
      select: {
        id: true,
        human_friendly_id: true,
        facility_id: true,
        storage_unit_id: true,
        slot_code: true,
        label: true,
        status: true,
        temperature_zone: true,
        is_active: true,
        created_at: true,
        updated_at: true,
        facility: { select: { id: true, human_friendly_id: true, name: true } },
        storage_unit: {
          select: { id: true, human_friendly_id: true, name: true, unit_type: true },
        },
        assignments: {
          where: ACTIVE_STORAGE_ASSIGNMENT_WHERE,
          orderBy: { assigned_at: 'desc' },
          take: 1,
          select: {
            id: true,
            human_friendly_id: true,
            assignment_status: true,
            assigned_at: true,
            mortuary_case: { select: CASE_SUMMARY_SELECT },
          },
        },
      },
    },
  },
  'mortuary-storage-assignments': {
    delegate: 'mortuary_storage_assignment',
    where: buildStorageAssignmentWhere,
    query: {
      select: {
        id: true,
        human_friendly_id: true,
        facility_id: true,
        assignment_status: true,
        assigned_at: true,
        ended_at: true,
        reason: true,
        created_at: true,
        updated_at: true,
        facility: { select: { id: true, human_friendly_id: true, name: true } },
        mortuary_case: { select: CASE_SUMMARY_SELECT },
        storage_unit: {
          select: { id: true, human_friendly_id: true, name: true, unit_type: true },
        },
        storage_slot: {
          select: {
            id: true,
            human_friendly_id: true,
            slot_code: true,
            label: true,
            status: true,
          },
        },
      },
    },
  },
  'mortuary-custody-events': {
    delegate: 'mortuary_custody_event',
    where: buildCustodyEventWhere,
    query: {
      select: {
        id: true,
        human_friendly_id: true,
        facility_id: true,
        event_type: true,
        event_at: true,
        actor_name: true,
        actor_role: true,
        location_label: true,
        reason: true,
        notes: true,
        created_at: true,
        updated_at: true,
        facility: { select: { id: true, human_friendly_id: true, name: true } },
        mortuary_case: { select: CASE_SUMMARY_SELECT },
      },
    },
  },
  'mortuary-viewings': {
    delegate: 'mortuary_viewing',
    where: buildViewingWhere,
    query: {
      select: {
        id: true,
        human_friendly_id: true,
        facility_id: true,
        scheduled_at: true,
        status: true,
        authorised_by_name: true,
        attendee_summary: true,
        completed_at: true,
        created_at: true,
        updated_at: true,
        facility: { select: { id: true, human_friendly_id: true, name: true } },
        mortuary_case: { select: CASE_SUMMARY_SELECT },
      },
    },
  },
  'mortuary-post-mortem-requests': {
    delegate: 'mortuary_post_mortem_request',
    where: buildPostMortemWhere,
    query: {
      select: {
        id: true,
        human_friendly_id: true,
        facility_id: true,
        requested_by_name: true,
        request_reason: true,
        status: true,
        diagnostics_reference_id: true,
        scheduled_at: true,
        completed_at: true,
        report_received_at: true,
        created_at: true,
        updated_at: true,
        facility: { select: { id: true, human_friendly_id: true, name: true } },
        mortuary_case: { select: CASE_SUMMARY_SELECT },
      },
    },
  },
  'mortuary-release-authorisations': {
    delegate: 'mortuary_release_authorisation',
    where: buildReleaseWhere,
    query: {
      select: {
        id: true,
        human_friendly_id: true,
        facility_id: true,
        recipient_name: true,
        recipient_relationship: true,
        verification_reference: true,
        funeral_service_name: true,
        release_method: true,
        status: true,
        approved_by_name: true,
        approved_at: true,
        released_at: true,
        created_at: true,
        updated_at: true,
        facility: { select: { id: true, human_friendly_id: true, name: true } },
        mortuary_case: { select: CASE_SUMMARY_SELECT },
      },
    },
  },
  'mortuary-billable-events': {
    delegate: 'mortuary_billable_event',
    where: buildBillableEventWhere,
    query: {
      select: {
        id: true,
        human_friendly_id: true,
        facility_id: true,
        event_type: true,
        description: true,
        amount: true,
        currency: true,
        status: true,
        billing_reference_id: true,
        charged_at: true,
        settled_at: true,
        created_at: true,
        updated_at: true,
        facility: { select: { id: true, human_friendly_id: true, name: true } },
        mortuary_case: { select: CASE_SUMMARY_SELECT },
      },
    },
  },
});

const findSummary = async ({ tenantId, facilityId }) => {
  try {
    const base = buildBaseWhere({ tenantId, facilityId });
    const [totalCases, identificationPending, inStorage, releaseReady, unsettledBilling] =
      await Promise.all([
        prisma.mortuary_case.count({ where: base }),
        prisma.mortuary_case.count({
          where: buildCaseWhere({ tenantId, facilityId, queue: 'IDENTIFICATION_PENDING' }),
        }),
        prisma.mortuary_case.count({
          where: { ...base, status: 'IN_STORAGE' },
        }),
        prisma.mortuary_case.count({
          where: buildCaseWhere({ tenantId, facilityId, queue: 'RELEASE_READY' }),
        }),
        prisma.mortuary_case.count({
          where: buildCaseWhere({ tenantId, facilityId, queue: 'UNSETTLED_BILLING' }),
        }),
      ]);

    return {
      total_cases: totalCases,
      identification_pending: identificationPending,
      in_storage: inStorage,
      release_ready: releaseReady,
      unsettled_billing: unsettledBilling,
    };
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findQueueCounts = async ({ tenantId, facilityId }) => {
  try {
    const [identificationPending, storageExceptions, releaseReady, unsettledBilling, postMortemPending] =
      await Promise.all([
        prisma.mortuary_case.count({
          where: buildCaseWhere({ tenantId, facilityId, queue: 'IDENTIFICATION_PENDING' }),
        }),
        prisma.mortuary_storage_slot.count({
          where: {
            ...buildBaseWhere({ tenantId, facilityId }),
            status: { in: STORAGE_EXCEPTION_STATUSES },
          },
        }),
        prisma.mortuary_case.count({
          where: buildCaseWhere({ tenantId, facilityId, queue: 'RELEASE_READY' }),
        }),
        prisma.mortuary_billable_event.count({
          where: buildBillableEventWhere({
            tenantId,
            facilityId,
            queue: 'UNSETTLED_BILLING',
          }),
        }),
        prisma.mortuary_post_mortem_request.count({
          where: buildPostMortemWhere({
            tenantId,
            facilityId,
            queue: 'POST_MORTEM_PENDING',
          }),
        }),
      ]);

    return {
      IDENTIFICATION_PENDING: identificationPending,
      STORAGE_EXCEPTIONS: storageExceptions,
      RELEASE_READY: releaseReady,
      UNSETTLED_BILLING: unsettledBilling,
      POST_MORTEM_PENDING: postMortemPending,
    };
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findItems = async ({ resource, filters, skip, take, orderBy }) => {
  try {
    const config = RESOURCE_CONFIG[resource] || RESOURCE_CONFIG['mortuary-cases'];
    const delegate = prisma[config.delegate];
    const where = config.where(filters);

    const [items, total] = await Promise.all([
      delegate.findMany({
        where,
        skip,
        take,
        orderBy,
        ...config.query,
      }),
      delegate.count({ where }),
    ]);

    return { items, total };
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findLookups = async ({ tenantId, facilityId, storageUnitId, search }) => {
  try {
    const normalizedSearch = normalizeString(search);
    const upperSearch = normalizedSearch.toUpperCase();
    const base = buildBaseWhere({ tenantId, facilityId });
    const searchClause = normalizedSearch
      ? {
          OR: [
            { human_friendly_id: { contains: upperSearch } },
            { name: { contains: normalizedSearch } },
          ],
        }
      : {};

    const [facilities, storageUnits, storageSlots, deceasedProfiles, patients, sourceWorkflows] =
      await Promise.all([
        prisma.facility.findMany({
          where: {
            tenant_id: tenantId || '__missing_tenant__',
            deleted_at: null,
            ...(normalizedSearch
              ? {
                  OR: [
                    { name: { contains: normalizedSearch } },
                    { human_friendly_id: { contains: upperSearch } },
                  ],
                }
              : {}),
          },
          take: 50,
          orderBy: { name: 'asc' },
          select: { id: true, human_friendly_id: true, name: true, facility_type: true },
        }),
        prisma.mortuary_storage_unit.findMany({
          where: {
            ...base,
            ...searchClause,
          },
          take: 50,
          orderBy: { name: 'asc' },
          select: {
            id: true,
            human_friendly_id: true,
            name: true,
            unit_type: true,
            status: true,
            location_label: true,
          },
        }),
        prisma.mortuary_storage_slot.findMany({
          where: {
            ...buildBaseWhere({ tenantId, facilityId }),
            ...(storageUnitId ? { storage_unit_id: storageUnitId } : {}),
            ...(normalizedSearch
              ? {
                  OR: [
                    { human_friendly_id: { contains: upperSearch } },
                    { slot_code: { contains: normalizedSearch } },
                    { label: { contains: normalizedSearch } },
                    { storage_unit: { name: { contains: normalizedSearch } } },
                  ],
                }
              : {}),
          },
          take: 100,
          orderBy: { slot_code: 'asc' },
          select: {
            id: true,
            human_friendly_id: true,
            slot_code: true,
            label: true,
            status: true,
            temperature_zone: true,
            storage_unit: {
              select: { id: true, human_friendly_id: true, name: true },
            },
          },
        }),
        prisma.mortuary_deceased_profile.findMany({
          where: {
            ...buildBaseWhere({ tenantId, facilityId }),
            ...(normalizedSearch
              ? {
                  OR: [
                    { human_friendly_id: { contains: upperSearch } },
                    { display_name: { contains: normalizedSearch } },
                    { external_reference: { contains: normalizedSearch } },
                  ],
                }
              : {}),
          },
          take: 50,
          orderBy: { display_name: 'asc' },
          select: {
            id: true,
            human_friendly_id: true,
            display_name: true,
            external_reference: true,
            date_of_death: true,
          },
        }),
        prisma.patient.findMany({
          where: {
            tenant_id: tenantId || '__missing_tenant__',
            deleted_at: null,
            ...(facilityId ? { facility_id: facilityId } : {}),
            ...(normalizedSearch
              ? {
                  OR: [
                    { human_friendly_id: { contains: upperSearch } },
                    { first_name: { contains: normalizedSearch } },
                    { last_name: { contains: normalizedSearch } },
                  ],
                }
              : {}),
          },
          take: 50,
          orderBy: { last_name: 'asc' },
          select: {
            id: true,
            human_friendly_id: true,
            first_name: true,
            last_name: true,
          },
        }),
        prisma.mortuary_case.findMany({
          where: {
            ...base,
            source_workflow: { not: null },
          },
          distinct: ['source_workflow'],
          take: 50,
          orderBy: { source_workflow: 'asc' },
          select: { source_workflow: true },
        }),
      ]);

    return {
      facilities,
      storageUnits,
      storageSlots,
      deceasedProfiles,
      patients,
      sourceWorkflows,
    };
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  BILLING_SETTLED_STATUSES,
  POST_MORTEM_ACTIVE_STATUSES,
  STORAGE_EXCEPTION_STATUSES,
  findItems,
  findLookups,
  findQueueCounts,
  findSummary,
};
