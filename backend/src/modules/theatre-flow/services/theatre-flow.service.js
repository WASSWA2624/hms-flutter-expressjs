/**
 * Theatre flow service
 */

const prisma = require('@prisma/client');
const theatreFlowRepository = require('@repositories/theatre-flow/theatre-flow.repository');
const { HttpError } = require('@lib/errors');
const { createAuditLog } = require('@lib/audit');
const { isUuidLike } = require('@lib/identifiers/sanitize-friendly-ids');
const { normalizeRoleName, ROLES } = require('@config/roles');

const QUEUE_SCOPES = Object.freeze({
  ACTIVE: 'ACTIVE',
  ALL: 'ALL',
});

const ACTIVE_CASE_STATUSES = new Set(['SCHEDULED', 'IN_PROGRESS']);
const TERMINAL_CASE_STATUSES = new Set(['COMPLETED', 'CANCELLED']);
const THEATRE_STAGE_SEQUENCE = Object.freeze([
  'PRE_OP',
  'SIGN_IN',
  'TIME_OUT',
  'INTRA_OP',
  'SIGN_OUT',
  'POST_OP',
  'PACU_HANDOFF',
  'COMPLETED',
]);
const REQUIRED_CHECKLIST_PHASES_FOR_CLOSURE = Object.freeze([
  'SIGN_IN',
  'TIME_OUT',
  'SIGN_OUT',
  'PACU_HANDOFF',
]);
const STAGE_INDEX = new Map(
  THEATRE_STAGE_SEQUENCE.map((stage, index) => [stage, index])
);
const REOPEN_ALLOWED_ROLES = new Set([
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
]);

const LEGACY_ROUTE_CONFIG = Object.freeze({
  'theatre-cases': {
    delegate: 'theatre_case',
    caseField: 'id',
    panel: 'snapshot',
    action: 'open_case',
  },
  'anesthesia-records': {
    delegate: 'anesthesia_record',
    caseField: 'theatre_case_id',
    panel: 'anesthesia',
    action: 'open_anesthesia',
  },
  'post-op-notes': {
    delegate: 'post_op_note',
    caseField: 'theatre_case_id',
    panel: 'post-op',
    action: 'open_post_op',
  },
});

const RESOURCE_TYPE_CONFIG = Object.freeze({
  ROOM: {
    model: 'room',
    resolveLabel: (record) => sanitize(record?.name),
  },
  STAFF: {
    model: 'staff_profile',
    resolveLabel: (record) => {
      const profile = record?.user?.profile || null;
      const fullName = [
        sanitize(profile?.first_name),
        sanitize(profile?.middle_name),
        sanitize(profile?.last_name),
      ]
        .filter(Boolean)
        .join(' ')
        .trim();
      return fullName || sanitize(record?.staff_number) || null;
    },
  },
  EQUIPMENT: {
    model: 'equipment_registry',
    resolveLabel: (record) =>
      sanitize(record?.equipment_name) ||
      sanitize(record?.name) ||
      sanitize(record?.equipment_code),
  },
});

const sanitize = (value) => String(value || '').trim();
const toUpper = (value) => sanitize(value).toUpperCase();
const resolveStage = (value) => {
  const normalized = toUpper(value);
  return STAGE_INDEX.has(normalized) ? normalized : 'PRE_OP';
};
const hasTerminalStatus = (theatreCase) =>
  TERMINAL_CASE_STATUSES.has(toUpper(theatreCase?.status));

const assertCaseNotTerminal = (theatreCase) => {
  if (hasTerminalStatus(theatreCase)) {
    throw new HttpError('errors.theatre_flow.case_terminal', 400);
  }
};

const assertStageTransitionAllowed = (currentStage, nextStage) => {
  const normalizedNextStage = resolveStage(nextStage);
  const normalizedCurrentStage = resolveStage(currentStage);

  if (normalizedNextStage === normalizedCurrentStage) return normalizedNextStage;

  const currentIndex = STAGE_INDEX.get(normalizedCurrentStage) ?? 0;
  const nextIndex = STAGE_INDEX.get(normalizedNextStage) ?? 0;
  if (nextIndex === currentIndex + 1) return normalizedNextStage;

  throw new HttpError('errors.theatre_flow.stage_transition_invalid', 400, [
    {
      current_stage: normalizedCurrentStage,
      next_stage: normalizedNextStage,
    },
  ]);
};

const parseBoolean = (value, fallback = false) => {
  if (typeof value === 'boolean') return value;
  const normalized = sanitize(value).toLowerCase();
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true;
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false;
  return fallback;
};

const normalizeQueueScope = (value) =>
  toUpper(value) === QUEUE_SCOPES.ALL ? QUEUE_SCOPES.ALL : QUEUE_SCOPES.ACTIVE;

const toDate = (value, fallback = new Date()) => {
  if (!value) return fallback;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? fallback : parsed;
};

const toPublicScalarIdentifier = (value) => {
  const normalized = sanitize(value);
  if (!normalized || isUuidLike(normalized)) return null;
  return normalized;
};

const resolvePublicIdentifier = (record) => {
  if (!record) return null;
  if (typeof record === 'string') return toPublicScalarIdentifier(record);
  return (
    toPublicScalarIdentifier(record.display_id) ||
    toPublicScalarIdentifier(record.human_friendly_id) ||
    toPublicScalarIdentifier(record.id) ||
    null
  );
};

const resolvePatientDisplayName = (patient) => {
  const firstName = sanitize(patient?.first_name);
  const lastName = sanitize(patient?.last_name);
  const fullName = [firstName, lastName].filter(Boolean).join(' ').trim();
  return fullName || null;
};

const resolveUserDisplayName = (user) => {
  const profile = user?.profile || null;
  const fullName = [
    sanitize(profile?.first_name),
    sanitize(profile?.middle_name),
    sanitize(profile?.last_name),
  ]
    .filter(Boolean)
    .join(' ')
    .trim();
  return fullName || sanitize(user?.email) || null;
};

const normalizeQueryOptions = (queryOptions) => {
  if (!queryOptions) return { select: { id: true } };
  if (queryOptions.select || queryOptions.include) return queryOptions;
  return { select: queryOptions };
};

const resolveByIdentifier = async (
  delegate,
  identifier,
  where = {},
  queryOptions = { select: { id: true } }
) => {
  const normalized = sanitize(identifier);
  if (!normalized || !delegate || typeof delegate.findFirst !== 'function') {
    return null;
  }

  const queryShape = normalizeQueryOptions(queryOptions);
  const baseWhere = {
    deleted_at: null,
    ...(where || {}),
  };

  if (isUuidLike(normalized)) {
    const byUuid = await delegate.findFirst({
      where: {
        ...baseWhere,
        id: normalized.toLowerCase(),
      },
      ...queryShape,
    });
    if (byUuid) return byUuid;
  }

  return delegate.findFirst({
    where: {
      ...baseWhere,
      human_friendly_id: normalized.toUpperCase(),
    },
    ...queryShape,
  });
};

const resolveTheatreCaseByIdentifier = (tx, identifier) =>
  resolveByIdentifier(tx.theatre_case, identifier, {}, {
    id: true,
    encounter_id: true,
    status: true,
    completed_at: true,
    workflow_stage: true,
  });

const resolveEncounterByIdentifier = (tx, identifier) =>
  resolveByIdentifier(tx.encounter, identifier, {}, {
    id: true,
    tenant_id: true,
    facility_id: true,
    patient_id: true,
  });

const resolveRoomByIdentifier = (tx, identifier, tenantId = null, facilityId = null) =>
  resolveByIdentifier(
    tx.room,
    identifier,
    {
      ...(tenantId ? { tenant_id: tenantId } : {}),
      ...(facilityId ? { facility_id: facilityId } : {}),
    },
    {
      id: true,
      human_friendly_id: true,
      name: true,
    }
  );

const resolveUserByIdentifier = (tx, identifier, tenantId = null, facilityId = null) =>
  resolveByIdentifier(
    tx.user,
    identifier,
    {
      ...(tenantId ? { tenant_id: tenantId } : {}),
      ...(facilityId ? { facility_id: facilityId } : {}),
    },
    {
      id: true,
      human_friendly_id: true,
      email: true,
      profile: {
        select: {
          first_name: true,
          middle_name: true,
          last_name: true,
        },
      },
    }
  );

const resolveStaffProfileByIdentifier = (
  tx,
  identifier,
  tenantId = null,
  facilityId = null
) =>
  resolveByIdentifier(
    tx.staff_profile,
    identifier,
    {
      ...(tenantId ? { tenant_id: tenantId } : {}),
      ...(facilityId ? { user: { facility_id: facilityId } } : {}),
    },
    {
      id: true,
      human_friendly_id: true,
      staff_number: true,
      user_id: true,
      user: {
        select: {
          id: true,
          human_friendly_id: true,
          email: true,
          profile: {
            select: {
              first_name: true,
              middle_name: true,
              last_name: true,
            },
          },
        },
      },
    }
  );

const resolveEquipmentByIdentifier = (tx, identifier, tenantId = null) =>
  resolveByIdentifier(
    tx.equipment_registry,
    identifier,
    {
      ...(tenantId ? { tenant_id: tenantId } : {}),
    },
    {
      id: true,
      human_friendly_id: true,
      equipment_name: true,
      equipment_code: true,
      name: true,
    }
  );

const resolveAnesthesiaRecordByIdentifier = (
  tx,
  identifier,
  theatreCaseId = null
) =>
  resolveByIdentifier(
    tx.anesthesia_record,
    identifier,
    theatreCaseId ? { theatre_case_id: theatreCaseId } : {},
    {
      id: true,
      theatre_case_id: true,
      record_status: true,
    }
  );

const resolvePostOpNoteByIdentifier = (tx, identifier, theatreCaseId = null) =>
  resolveByIdentifier(
    tx.post_op_note,
    identifier,
    theatreCaseId ? { theatre_case_id: theatreCaseId } : {},
    {
      id: true,
      theatre_case_id: true,
      record_status: true,
    }
  );

const resolveResourceAllocationByIdentifier = (
  tx,
  identifier,
  theatreCaseId = null
) =>
  resolveByIdentifier(
    tx.theatre_case_resource_allocation,
    identifier,
    theatreCaseId ? { theatre_case_id: theatreCaseId } : {},
    {
      id: true,
      theatre_case_id: true,
      resource_type: true,
      resource_id: true,
      released_at: true,
    }
  );

const createResourceLookupResolver = () => {
  const cache = new Map();

  const read = async (model, identifier) => {
    const normalized = sanitize(identifier);
    if (!normalized) return null;

    const key = `${model}:${normalized}`;
    if (cache.has(key)) return cache.get(key);

    let record = null;
    if (model === 'room') {
      record = await resolveRoomByIdentifier(prisma, normalized);
    } else if (model === 'staff_profile') {
      record = await resolveStaffProfileByIdentifier(prisma, normalized);
    } else if (model === 'equipment_registry') {
      record = await resolveEquipmentByIdentifier(prisma, normalized);
    } else if (model === 'user') {
      record = await resolveUserByIdentifier(prisma, normalized);
    }

    cache.set(key, record || null);
    return record || null;
  };

  return {
    read,
  };
};

const mapResourceAllocation = async (entry, lookupResolver) => {
  const normalizedType = toUpper(entry?.resource_type);
  const config = RESOURCE_TYPE_CONFIG[normalizedType] || null;
  let resourceRecord = null;
  if (config) {
    resourceRecord = await lookupResolver.read(config.model, entry?.resource_id);
  }

  return {
    id: resolvePublicIdentifier(entry),
    display_id: resolvePublicIdentifier(entry),
    theatre_case_display_id:
      toPublicScalarIdentifier(entry?.theatre_case_display_id) ||
      toPublicScalarIdentifier(entry?.theatre_case_id),
    resource_type: normalizedType || entry?.resource_type || null,
    resource_display_id:
      resolvePublicIdentifier(resourceRecord) || toPublicScalarIdentifier(entry?.resource_id),
    resource_label: config ? config.resolveLabel(resourceRecord) : null,
    assigned_at: entry?.assigned_at || null,
    released_at: entry?.released_at || null,
    notes: sanitize(entry?.notes) || null,
    assigned_by_user_display_id: toPublicScalarIdentifier(entry?.assigned_by_user_id),
    released_by_user_display_id: toPublicScalarIdentifier(entry?.released_by_user_id),
    created_at: entry?.created_at || null,
    updated_at: entry?.updated_at || null,
  };
};

const mapChecklistItem = (entry) => ({
  id: resolvePublicIdentifier(entry),
  display_id: resolvePublicIdentifier(entry),
  phase: toUpper(entry?.phase) || null,
  item_code: sanitize(entry?.item_code) || null,
  item_label: sanitize(entry?.item_label) || null,
  is_checked: Boolean(entry?.is_checked),
  checked_at: entry?.checked_at || null,
  notes: sanitize(entry?.notes) || null,
  checked_by_user_display_id: toPublicScalarIdentifier(entry?.checked_by_user_id),
  created_at: entry?.created_at || null,
  updated_at: entry?.updated_at || null,
});

const mapAnesthesiaObservation = (entry) => ({
  id: resolvePublicIdentifier(entry),
  display_id: resolvePublicIdentifier(entry),
  theatre_case_display_id:
    toPublicScalarIdentifier(entry?.theatre_case_display_id) ||
    toPublicScalarIdentifier(entry?.theatre_case_id),
  observed_at: entry?.observed_at || null,
  observation_type: sanitize(entry?.observation_type) || null,
  metric_key: sanitize(entry?.metric_key) || null,
  metric_value: sanitize(entry?.metric_value) || null,
  unit: sanitize(entry?.unit) || null,
  notes: sanitize(entry?.notes) || null,
  observed_by_user_display_id: toPublicScalarIdentifier(entry?.observed_by_user_id),
  created_at: entry?.created_at || null,
  updated_at: entry?.updated_at || null,
});

const mapAnesthesiaRecord = (entry) => ({
  id: resolvePublicIdentifier(entry),
  display_id: resolvePublicIdentifier(entry),
  theatre_case_display_id:
    toPublicScalarIdentifier(entry?.theatre_case_display_id) ||
    toPublicScalarIdentifier(entry?.theatre_case_id),
  anesthetist_user_display_id: resolvePublicIdentifier(entry?.anesthetist),
  staff_profile_display_id: resolvePublicIdentifier(entry?.anesthetist?.staff_profile),
  anesthetist_display_name: resolveUserDisplayName(entry?.anesthetist),
  record_status: toUpper(entry?.record_status) || 'DRAFT',
  notes: sanitize(entry?.notes) || null,
  finalized_at: entry?.finalized_at || null,
  reopened_at: entry?.reopened_at || null,
  finalized_by_user_display_id: toPublicScalarIdentifier(entry?.finalized_by_user_id),
  reopened_by_user_display_id: toPublicScalarIdentifier(entry?.reopened_by_user_id),
  created_at: entry?.created_at || null,
  updated_at: entry?.updated_at || null,
});

const mapPostOpNote = (entry) => ({
  id: resolvePublicIdentifier(entry),
  display_id: resolvePublicIdentifier(entry),
  theatre_case_display_id:
    toPublicScalarIdentifier(entry?.theatre_case_display_id) ||
    toPublicScalarIdentifier(entry?.theatre_case_id),
  note: sanitize(entry?.note) || null,
  record_status: toUpper(entry?.record_status) || 'DRAFT',
  finalized_at: entry?.finalized_at || null,
  reopened_at: entry?.reopened_at || null,
  finalized_by_user_display_id: toPublicScalarIdentifier(entry?.finalized_by_user_id),
  reopened_by_user_display_id: toPublicScalarIdentifier(entry?.reopened_by_user_id),
  created_at: entry?.created_at || null,
  updated_at: entry?.updated_at || null,
});

const buildTimeline = (snapshot) => {
  const timeline = [];

  if (snapshot?.scheduled_at) {
    timeline.push({
      type: 'CASE_SCHEDULED',
      at: snapshot.scheduled_at,
      label: 'Case scheduled',
    });
  }
  if (snapshot?.started_at) {
    timeline.push({
      type: 'CASE_STARTED',
      at: snapshot.started_at,
      label: 'Case started',
    });
  }
  if (snapshot?.completed_at) {
    timeline.push({
      type: 'CASE_COMPLETED',
      at: snapshot.completed_at,
      label: 'Case completed',
    });
  }
  if (snapshot?.cancelled_at) {
    timeline.push({
      type: 'CASE_CANCELLED',
      at: snapshot.cancelled_at,
      label: 'Case cancelled',
    });
  }

  for (const item of Array.isArray(snapshot?.checklist_items)
    ? snapshot.checklist_items
    : []) {
    if (!item?.checked_at) continue;
    timeline.push({
      type: 'CHECKLIST',
      at: item.checked_at,
      label: `${item.phase || 'CHECKLIST'} | ${item.item_label || item.item_code}`,
    });
  }

  for (const item of Array.isArray(snapshot?.anesthesia_observations)
    ? snapshot.anesthesia_observations
    : []) {
    timeline.push({
      type: 'ANESTHESIA_OBSERVATION',
      at: item.observed_at || item.created_at,
      label: item.notes || item.metric_key || item.observation_type || 'Observation recorded',
    });
  }

  for (const entry of Array.isArray(snapshot?.resource_allocations)
    ? snapshot.resource_allocations
    : []) {
    timeline.push({
      type: 'RESOURCE_ASSIGNED',
      at: entry.assigned_at || entry.created_at,
      label: `${entry.resource_type || 'RESOURCE'} assigned`,
    });
    if (entry.released_at) {
      timeline.push({
        type: 'RESOURCE_RELEASED',
        at: entry.released_at,
        label: `${entry.resource_type || 'RESOURCE'} released`,
      });
    }
  }

  for (const record of Array.isArray(snapshot?.anesthesia_records)
    ? snapshot.anesthesia_records
    : []) {
    timeline.push({
      type: 'ANESTHESIA_RECORD',
      at: record.updated_at || record.created_at,
      label:
        record.record_status === 'FINAL'
          ? 'Anesthesia record finalized'
          : 'Anesthesia record updated',
    });
  }

  for (const record of Array.isArray(snapshot?.post_op_notes)
    ? snapshot.post_op_notes
    : []) {
    timeline.push({
      type: 'POST_OP_NOTE',
      at: record.updated_at || record.created_at,
      label:
        record.record_status === 'FINAL' ? 'Post-op note finalized' : 'Post-op note updated',
    });
  }

  return timeline
    .filter((entry) => entry && entry.at)
    .sort((left, right) => {
      const leftTs = new Date(left.at).getTime() || 0;
      const rightTs = new Date(right.at).getTime() || 0;
      return rightTs - leftTs;
    });
};

const mapTheatreSnapshot = async (snapshot, options = {}) => {
  if (!snapshot) return null;

  const includeTimeline = options.include_timeline !== false;
  const lookupResolver = options.lookupResolver || createResourceLookupResolver();

  const encounter = snapshot.encounter || null;
  const patient = encounter?.patient || null;
  const caseDisplayId = resolvePublicIdentifier(snapshot);
  const encounterDisplayId = resolvePublicIdentifier(encounter);
  const patientDisplayId = resolvePublicIdentifier(patient);

  const roomRecord = snapshot.room_id
    ? await lookupResolver.read('room', snapshot.room_id)
    : null;
  const surgeon = snapshot.surgeon_user_id
    ? await lookupResolver.read('user', snapshot.surgeon_user_id)
    : null;
  const anesthetistFromCase = snapshot.anesthetist_user_id
    ? await lookupResolver.read('user', snapshot.anesthetist_user_id)
    : null;

  const resourceAllocations = await Promise.all(
    (Array.isArray(snapshot.resource_allocations) ? snapshot.resource_allocations : []).map((entry) =>
      mapResourceAllocation(entry, lookupResolver)
    )
  );
  const checklistItems = (Array.isArray(snapshot.checklist_items) ? snapshot.checklist_items : []).map(
    mapChecklistItem
  );
  const anesthesiaObservations = (
    Array.isArray(snapshot.anesthesia_observations) ? snapshot.anesthesia_observations : []
  ).map(mapAnesthesiaObservation);
  const anesthesiaRecords = (
    Array.isArray(snapshot.anesthesia_records) ? snapshot.anesthesia_records : []
  ).map(mapAnesthesiaRecord);
  const postOpNotes = (Array.isArray(snapshot.post_op_notes) ? snapshot.post_op_notes : []).map(
    mapPostOpNote
  );

  const latestAnesthesia = anesthesiaRecords[0] || null;
  const latestPostOp = postOpNotes[0] || null;

  const checklistSummary = {
    total: checklistItems.length,
    completed: checklistItems.filter((entry) => Boolean(entry.is_checked)).length,
    pending: checklistItems.filter((entry) => !entry.is_checked).length,
  };

  const flowSummary = {
    stage: sanitize(snapshot.workflow_stage) || null,
    status: sanitize(snapshot.status) || null,
    anesthesia_status: latestAnesthesia?.record_status || null,
    post_op_status: latestPostOp?.record_status || null,
    checklist_completed: checklistSummary.completed,
    checklist_total: checklistSummary.total,
  };

  return {
    id: caseDisplayId,
    display_id: caseDisplayId,
    human_friendly_id: caseDisplayId,
    theatre_case_display_id: caseDisplayId,
    scheduled_at: snapshot?.scheduled_at || null,
    started_at: snapshot?.started_at || null,
    completed_at: snapshot?.completed_at || null,
    cancelled_at: snapshot?.cancelled_at || null,
    status: toUpper(snapshot?.status) || null,
    workflow_stage: toUpper(snapshot?.workflow_stage) || null,
    stage_notes: sanitize(snapshot?.stage_notes) || null,
    encounter_display_id: encounterDisplayId,
    patient_display_id: patientDisplayId,
    patient_display_name: resolvePatientDisplayName(patient),
    room_display_id: resolvePublicIdentifier(roomRecord),
    room_display_label: sanitize(roomRecord?.name) || null,
    surgeon_user_display_id: resolvePublicIdentifier(surgeon),
    surgeon_display_name: resolveUserDisplayName(surgeon),
    anesthetist_user_display_id:
      resolvePublicIdentifier(anesthetistFromCase) ||
      latestAnesthesia?.anesthetist_user_display_id ||
      null,
    anesthetist_display_name:
      resolveUserDisplayName(anesthetistFromCase) ||
      latestAnesthesia?.anesthetist_display_name ||
      null,
    anesthesia_record_display_id: latestAnesthesia?.display_id || null,
    post_op_note_display_id: latestPostOp?.display_id || null,
    anesthesia_status: latestAnesthesia?.record_status || null,
    post_op_status: latestPostOp?.record_status || null,
    created_at: snapshot?.created_at || null,
    updated_at: snapshot?.updated_at || null,
    checklist_items: checklistItems,
    checklist_summary: checklistSummary,
    resource_allocations: resourceAllocations,
    anesthesia_observations: anesthesiaObservations,
    anesthesia_records: anesthesiaRecords,
    post_op_notes: postOpNotes,
    latest_anesthesia_record: latestAnesthesia,
    latest_post_op_note: latestPostOp,
    flow_summary: flowSummary,
    timeline: includeTimeline
      ? buildTimeline({
          ...snapshot,
          checklist_items: checklistItems,
          resource_allocations: resourceAllocations,
          anesthesia_observations: anesthesiaObservations,
          anesthesia_records: anesthesiaRecords,
          post_op_notes: postOpNotes,
        })
      : [],
  };
};

const buildEmptyListResult = (page, limit) => ({
  items: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1,
  },
});

const getTheatreFlowByIdInternal = async (id) => {
  const resolved = await resolveTheatreCaseByIdentifier(prisma, id);
  if (!resolved) throw new HttpError('errors.theatre_flow.not_found', 404);
  const snapshot = await theatreFlowRepository.findById(resolved.id);
  if (!snapshot) throw new HttpError('errors.theatre_flow.not_found', 404);
  return snapshot;
};

const resolveAuditOperation = (operation) =>
  operation === 'START' ? 'CREATE' : 'UPDATE';

const assertNoActiveDuplicateResource = async ({
  tx,
  theatreCaseId,
  resourceType,
  resourceId,
}) => {
  const existing = await tx.theatre_case_resource_allocation.findFirst({
    where: {
      theatre_case_id: theatreCaseId,
      deleted_at: null,
      released_at: null,
      resource_type: resourceType,
      resource_id: resourceId,
    },
    select: { id: true },
  });

  if (existing) {
    throw new HttpError('errors.theatre_flow.resource_already_assigned', 409);
  }
};

const assertAnesthesiaRecordReadyForFinalization = async (tx, theatreCaseId, targetId) => {
  const record = await tx.anesthesia_record.findFirst({
    where: {
      id: targetId,
      theatre_case_id: theatreCaseId,
      deleted_at: null,
    },
    select: {
      id: true,
      notes: true,
      theatre_case: {
        select: {
          anesthesia_observations: {
            where: { deleted_at: null },
            select: { id: true },
            take: 1,
          },
        },
      },
    },
  });

  const hasNotes = Boolean(sanitize(record?.notes));
  const hasObservations = Boolean(
    Array.isArray(record?.theatre_case?.anesthesia_observations) &&
      record.theatre_case.anesthesia_observations.length > 0
  );

  if (!hasNotes && !hasObservations) {
    throw new HttpError('errors.theatre_flow.anesthesia_documentation_incomplete', 400);
  }
};

const assertPostOpRecordReadyForFinalization = async (tx, theatreCaseId, targetId) => {
  const record = await tx.post_op_note.findFirst({
    where: {
      id: targetId,
      theatre_case_id: theatreCaseId,
      deleted_at: null,
    },
    select: {
      id: true,
      note: true,
    },
  });

  if (!sanitize(record?.note)) {
    throw new HttpError('errors.theatre_flow.post_op_documentation_incomplete', 400);
  }
};

const assertChecklistReadyForClosure = async (tx, theatreCaseId) => {
  const checklistItems = await tx.theatre_case_checklist_item.findMany({
    where: {
      theatre_case_id: theatreCaseId,
      deleted_at: null,
      phase: {
        in: REQUIRED_CHECKLIST_PHASES_FOR_CLOSURE,
      },
      is_checked: true,
    },
    select: { phase: true },
  });

  const completedPhases = new Set(
    checklistItems.map((entry) => toUpper(entry?.phase)).filter(Boolean)
  );
  const missingPhases = REQUIRED_CHECKLIST_PHASES_FOR_CLOSURE.filter(
    (phase) => !completedPhases.has(phase)
  );

  if (missingPhases.length > 0) {
    throw new HttpError('errors.theatre_flow.checklist_incomplete', 400, [
      { missing_phases: missingPhases },
    ]);
  }
};

const finalizeAction = async ({ theatreCaseId, action, context = {}, details = {} }) => {
  const snapshot = await getTheatreFlowByIdInternal(theatreCaseId);

  await createAuditLog({
    tenant_id: sanitize(snapshot?.encounter?.tenant_id) || null,
    user_id: context.user_id || null,
    action: resolveAuditOperation(action),
    entity: 'theatre_case',
    entity_id: snapshot.id,
    diff: {
      after: snapshot,
      metadata: {
        operation: action,
        ...details,
      },
    },
    ip_address: context.ip_address || null,
  }).catch(() => {});

  return mapTheatreSnapshot(snapshot, { include_timeline: true });
};

const listTheatreFlows = async (
  filters = {},
  page = 1,
  limit = 20,
  sortBy = 'scheduled_at',
  order = 'desc'
) => {
  const skip = (page - 1) * limit;
  const orderBy = sortBy ? { [sortBy]: order } : { scheduled_at: 'desc' };
  const where = {};

  const queueScope = normalizeQueueScope(filters.queue_scope);
  if (queueScope === QUEUE_SCOPES.ACTIVE) {
    where.status = { in: Array.from(ACTIVE_CASE_STATUSES) };
  }

  const tenant = filters.tenant_id
    ? await resolveByIdentifier(prisma.tenant, filters.tenant_id, {}, { id: true })
    : null;
  if (filters.tenant_id && !tenant) return buildEmptyListResult(page, limit);

  const facility = filters.facility_id
    ? await resolveByIdentifier(
        prisma.facility,
        filters.facility_id,
        tenant ? { tenant_id: tenant.id } : {},
        { id: true, tenant_id: true }
      )
    : null;
  if (filters.facility_id && !facility) return buildEmptyListResult(page, limit);

  const encounterFilter = {};
  if (tenant?.id) encounterFilter.tenant_id = tenant.id;
  if (facility?.id) encounterFilter.facility_id = facility.id;

  if (filters.patient_id) {
    const patient = await resolveByIdentifier(
      prisma.patient,
      filters.patient_id,
      {
        ...(tenant?.id ? { tenant_id: tenant.id } : {}),
        ...(facility?.id ? { facility_id: facility.id } : {}),
      },
      { id: true }
    );
    if (!patient) return buildEmptyListResult(page, limit);
    encounterFilter.patient_id = patient.id;
  }

  if (filters.encounter_id) {
    const encounter = await resolveEncounterByIdentifier(prisma, filters.encounter_id);
    if (!encounter) return buildEmptyListResult(page, limit);
    where.encounter_id = encounter.id;
  }

  if (Object.keys(encounterFilter).length > 0) {
    where.encounter = encounterFilter;
  }

  if (filters.status) where.status = toUpper(filters.status);
  if (filters.stage) where.workflow_stage = sanitize(filters.stage);

  if (filters.room_id) {
    const room = await resolveRoomByIdentifier(prisma, filters.room_id, tenant?.id || null);
    if (!room) return buildEmptyListResult(page, limit);
    where.room_id = room.id;
  }

  if (filters.surgeon_user_id) {
    const surgeon = await resolveUserByIdentifier(
      prisma,
      filters.surgeon_user_id,
      tenant?.id || null,
      facility?.id || null
    );
    if (!surgeon) return buildEmptyListResult(page, limit);
    where.surgeon_user_id = surgeon.id;
  }

  if (filters.anesthetist_user_id) {
    const anesthetist = await resolveUserByIdentifier(
      prisma,
      filters.anesthetist_user_id,
      tenant?.id || null,
      facility?.id || null
    );
    if (!anesthetist) return buildEmptyListResult(page, limit);
    where.anesthetist_user_id = anesthetist.id;
  }

  if (filters.anesthesia_status) {
    where.anesthesia_records = {
      some: {
        deleted_at: null,
        record_status: toUpper(filters.anesthesia_status),
      },
    };
  }

  if (filters.post_op_status) {
    where.post_op_notes = {
      some: {
        deleted_at: null,
        record_status: toUpper(filters.post_op_status),
      },
    };
  }

  if (filters.finalized !== undefined) {
    const finalized = parseBoolean(filters.finalized, false);
    if (finalized) {
      where.AND = [
        ...(Array.isArray(where.AND) ? where.AND : []),
        {
          anesthesia_records: {
            some: {
              deleted_at: null,
              record_status: 'FINAL',
            },
          },
        },
        {
          post_op_notes: {
            some: {
              deleted_at: null,
              record_status: 'FINAL',
            },
          },
        },
      ];
    }
  }

  if (filters.scheduled_from || filters.scheduled_to) {
    where.scheduled_at = {};
    if (filters.scheduled_from) {
      where.scheduled_at.gte = toDate(filters.scheduled_from);
    }
    if (filters.scheduled_to) {
      where.scheduled_at.lte = toDate(filters.scheduled_to);
    }
  }

  if (filters.search) {
    const searchTerm = sanitize(filters.search);
    const upperSearch = searchTerm.toUpperCase();
    where.OR = [
      { human_friendly_id: { contains: upperSearch } },
      { workflow_stage: { contains: searchTerm } },
      { stage_notes: { contains: searchTerm } },
      {
        encounter: {
          OR: [
            { human_friendly_id: { contains: upperSearch } },
            {
              patient: {
                OR: [
                  { human_friendly_id: { contains: upperSearch } },
                  { first_name: { contains: searchTerm } },
                  { last_name: { contains: searchTerm } },
                ],
              },
            },
          ],
        },
      },
      {
        anesthesia_records: {
          some: {
            notes: { contains: searchTerm },
          },
        },
      },
      {
        post_op_notes: {
          some: {
            note: { contains: searchTerm },
          },
        },
      },
    ];
  }

  const [records, total] = await Promise.all([
    theatreFlowRepository.findMany(where, skip, limit, orderBy),
    theatreFlowRepository.count(where),
  ]);

  const lookupResolver = createResourceLookupResolver();
  const items = await Promise.all(
    records.map((entry) =>
      mapTheatreSnapshot(entry, { include_timeline: false, lookupResolver })
    )
  );

  return {
    items,
    pagination: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
      hasNextPage: page < Math.ceil(total / limit),
      hasPreviousPage: page > 1,
    },
  };
};

const resolveLegacyRoute = async (resource, id) => {
  const normalizedResource = sanitize(resource).toLowerCase();
  const config = LEGACY_ROUTE_CONFIG[normalizedResource];
  if (!config) throw new HttpError('errors.theatre_flow.legacy_resource_unsupported', 400);

  const delegate = prisma[config.delegate];
  const resolvedResource = await resolveByIdentifier(delegate, id, {}, {
    id: true,
    human_friendly_id: true,
    theatre_case_id: true,
  });

  if (!resolvedResource) throw new HttpError('errors.theatre_flow.legacy_resource_not_found', 404);

  const theatreCaseId =
    config.caseField === 'id'
      ? resolvedResource.id
      : resolvedResource[config.caseField];

  if (!theatreCaseId) throw new HttpError('errors.theatre_flow.not_found', 404);

  const theatreCase = await prisma.theatre_case.findFirst({
    where: {
      id: theatreCaseId,
      deleted_at: null,
    },
    select: {
      id: true,
      human_friendly_id: true,
      workflow_stage: true,
    },
  });
  if (!theatreCase) throw new HttpError('errors.theatre_flow.not_found', 404);

  return {
    theatre_case_id: resolvePublicIdentifier(theatreCase),
    resource: normalizedResource,
    resource_id: resolvePublicIdentifier(resolvedResource),
    panel: config.panel,
    action: config.action,
    stage_hint: sanitize(theatreCase.workflow_stage).toUpperCase() || null,
  };
};

const getTheatreFlowById = async (id, options = {}) => {
  const snapshot = await getTheatreFlowByIdInternal(id);
  return mapTheatreSnapshot(snapshot, {
    include_timeline: parseBoolean(options?.include_timeline, true),
  });
};

const startTheatreFlow = async (data, context = {}) => {
  const result = await prisma.$transaction(async (tx) => {
    const encounter = await resolveEncounterByIdentifier(tx, data.encounter_id);
    if (!encounter) throw new HttpError('errors.theatre_flow.encounter_not_found', 404);

    const requestedStatus = toUpper(data?.status) || 'SCHEDULED';
    const requestedStage = data?.workflow_stage
      ? resolveStage(data.workflow_stage)
      : 'PRE_OP';
    if (requestedStatus === 'COMPLETED' || requestedStage === 'COMPLETED') {
      throw new HttpError('errors.theatre_flow.complete_via_finalization_required', 400);
    }

    const payload = {
      encounter_id: encounter.id,
      scheduled_at: toDate(data?.scheduled_at),
      status: requestedStatus,
      workflow_stage: requestedStage,
      stage_notes: sanitize(data?.stage_notes) || null,
    };

    if (data.room_id) {
      const room = await resolveRoomByIdentifier(
        tx,
        data.room_id,
        encounter.tenant_id,
        encounter.facility_id || null
      );
      if (!room) throw new HttpError('errors.theatre_flow.room_not_found', 404);
      payload.room_id = room.id;
    }

    if (data.surgeon_user_id) {
      const surgeon = await resolveUserByIdentifier(
        tx,
        data.surgeon_user_id,
        encounter.tenant_id,
        encounter.facility_id || null
      );
      if (!surgeon) throw new HttpError('errors.theatre_flow.user_not_found', 404);
      payload.surgeon_user_id = surgeon.id;
    }

    if (data.anesthetist_user_id) {
      const anesthetist = await resolveUserByIdentifier(
        tx,
        data.anesthetist_user_id,
        encounter.tenant_id,
        encounter.facility_id || null
      );
      if (!anesthetist) throw new HttpError('errors.theatre_flow.user_not_found', 404);
      payload.anesthetist_user_id = anesthetist.id;
    }

    const theatreCase = await tx.theatre_case.create({
      data: payload,
      select: { id: true },
    });

    return theatreCase.id;
  });

  return finalizeAction({
    theatreCaseId: result,
    action: 'START',
    context,
    details: { payload: data },
  });
};

const updateStage = async (id, data, context = {}) => {
  const result = await prisma.$transaction(async (tx) => {
    const theatreCase = await resolveTheatreCaseByIdentifier(tx, id);
    if (!theatreCase) throw new HttpError('errors.theatre_flow.not_found', 404);
    assertCaseNotTerminal(theatreCase);

    const payload = {};
    if (data.workflow_stage !== undefined) {
      const requestedStage = sanitize(data.workflow_stage);
      if (!requestedStage) {
        payload.workflow_stage = null;
      } else {
        payload.workflow_stage = assertStageTransitionAllowed(
          theatreCase.workflow_stage,
          requestedStage
        );
      }
    }
    if (data.stage_notes !== undefined) payload.stage_notes = sanitize(data.stage_notes) || null;
    if (data.status !== undefined) payload.status = toUpper(data.status) || theatreCase.status;
    if (data.started_at !== undefined) payload.started_at = data.started_at ? toDate(data.started_at) : null;
    if (data.completed_at !== undefined) payload.completed_at = data.completed_at ? toDate(data.completed_at) : null;
    if (data.cancelled_at !== undefined) payload.cancelled_at = data.cancelled_at ? toDate(data.cancelled_at) : null;

    const nextStage = toUpper(payload.workflow_stage);
    if (nextStage === 'COMPLETED' || payload.status === 'COMPLETED') {
      throw new HttpError('errors.theatre_flow.complete_via_finalization_required', 400);
    }
    if (nextStage && nextStage !== 'PRE_OP' && !payload.started_at) {
      payload.started_at = new Date();
      if (!payload.status || payload.status === 'SCHEDULED') payload.status = 'IN_PROGRESS';
    }
    if (payload.status === 'CANCELLED' && !payload.cancelled_at) {
      payload.cancelled_at = new Date();
    }

    await tx.theatre_case.update({
      where: { id: theatreCase.id },
      data: payload,
      select: { id: true },
    });

    return theatreCase.id;
  });

  return finalizeAction({
    theatreCaseId: result,
    action: 'UPDATE_STAGE',
    context,
    details: { payload: data },
  });
};

const upsertAnesthesiaRecord = async (id, data, context = {}) => {
  const result = await prisma.$transaction(async (tx) => {
    const theatreCase = await resolveTheatreCaseByIdentifier(tx, id);
    if (!theatreCase) throw new HttpError('errors.theatre_flow.not_found', 404);

    if (TERMINAL_CASE_STATUSES.has(toUpper(theatreCase.status))) {
      throw new HttpError('errors.theatre_flow.case_terminal', 400);
    }

    let target = null;
    if (data.anesthesia_record_id) {
      target = await resolveAnesthesiaRecordByIdentifier(
        tx,
        data.anesthesia_record_id,
        theatreCase.id
      );
      if (!target) throw new HttpError('errors.theatre_flow.anesthesia_record_not_found', 404);
    } else {
      target = await tx.anesthesia_record.findFirst({
        where: {
          theatre_case_id: theatreCase.id,
          deleted_at: null,
        },
        orderBy: {
          updated_at: 'desc',
        },
        select: {
          id: true,
          record_status: true,
        },
      });
    }

    let anesthetistUserId = undefined;
    if (data.anesthetist_user_id !== undefined) {
      if (!sanitize(data.anesthetist_user_id)) {
        anesthetistUserId = null;
      } else {
        const encounter = await tx.theatre_case.findFirst({
          where: { id: theatreCase.id },
          select: {
            encounter: {
              select: {
                tenant_id: true,
                facility_id: true,
              },
            },
          },
        });
        const anesthetist = await resolveUserByIdentifier(
          tx,
          data.anesthetist_user_id,
          encounter?.encounter?.tenant_id || null,
          encounter?.encounter?.facility_id || null
        );
        if (!anesthetist) throw new HttpError('errors.theatre_flow.user_not_found', 404);
        anesthetistUserId = anesthetist.id;
      }
    }

    if (target) {
      if (toUpper(target.record_status) === 'FINAL') {
        throw new HttpError('errors.theatre_flow.record_finalized_locked', 400);
      }

      await tx.anesthesia_record.update({
        where: { id: target.id },
        data: {
          ...(data.notes !== undefined ? { notes: sanitize(data.notes) || null } : {}),
          ...(anesthetistUserId !== undefined
            ? { anesthetist_user_id: anesthetistUserId }
            : {}),
          ...(data.record_status ? { record_status: toUpper(data.record_status) } : {}),
        },
        select: { id: true },
      });
    } else {
      await tx.anesthesia_record.create({
        data: {
          theatre_case_id: theatreCase.id,
          anesthetist_user_id: anesthetistUserId || null,
          notes: sanitize(data.notes) || null,
          record_status: toUpper(data.record_status) || 'DRAFT',
        },
        select: { id: true },
      });
    }

    return theatreCase.id;
  });

  return finalizeAction({
    theatreCaseId: result,
    action: 'UPSERT_ANESTHESIA_RECORD',
    context,
    details: { payload: data },
  });
};

const addAnesthesiaObservation = async (id, data, context = {}) => {
  const result = await prisma.$transaction(async (tx) => {
    const theatreCase = await resolveTheatreCaseByIdentifier(tx, id);
    if (!theatreCase) throw new HttpError('errors.theatre_flow.not_found', 404);

    if (TERMINAL_CASE_STATUSES.has(toUpper(theatreCase.status))) {
      throw new HttpError('errors.theatre_flow.case_terminal', 400);
    }

    let observedByUserId = context.user_id || null;
    if (data.observed_by_user_id) {
      const user = await resolveUserByIdentifier(tx, data.observed_by_user_id);
      if (!user) throw new HttpError('errors.theatre_flow.user_not_found', 404);
      observedByUserId = user.id;
    }

    await tx.anesthesia_observation.create({
      data: {
        theatre_case_id: theatreCase.id,
        observed_at: toDate(data.observed_at),
        observation_type: sanitize(data.observation_type) || null,
        metric_key: sanitize(data.metric_key) || null,
        metric_value: sanitize(data.metric_value) || null,
        unit: sanitize(data.unit) || null,
        notes: sanitize(data.notes) || null,
        observed_by_user_id: observedByUserId,
      },
      select: { id: true },
    });

    return theatreCase.id;
  });

  return finalizeAction({
    theatreCaseId: result,
    action: 'ADD_ANESTHESIA_OBSERVATION',
    context,
    details: { payload: data },
  });
};

const upsertPostOpNote = async (id, data, context = {}) => {
  const result = await prisma.$transaction(async (tx) => {
    const theatreCase = await resolveTheatreCaseByIdentifier(tx, id);
    if (!theatreCase) throw new HttpError('errors.theatre_flow.not_found', 404);
    assertCaseNotTerminal(theatreCase);

    if (!sanitize(data.note)) {
      throw new HttpError('errors.validation.field.required', 400, [{ field: 'note' }]);
    }

    let target = null;
    if (data.post_op_note_id) {
      target = await resolvePostOpNoteByIdentifier(tx, data.post_op_note_id, theatreCase.id);
      if (!target) throw new HttpError('errors.theatre_flow.post_op_note_not_found', 404);
    } else {
      target = await tx.post_op_note.findFirst({
        where: {
          theatre_case_id: theatreCase.id,
          deleted_at: null,
        },
        orderBy: {
          updated_at: 'desc',
        },
        select: {
          id: true,
          record_status: true,
        },
      });
    }

    if (target) {
      if (toUpper(target.record_status) === 'FINAL') {
        throw new HttpError('errors.theatre_flow.record_finalized_locked', 400);
      }

      await tx.post_op_note.update({
        where: { id: target.id },
        data: {
          note: sanitize(data.note),
          ...(data.record_status ? { record_status: toUpper(data.record_status) } : {}),
        },
        select: { id: true },
      });
    } else {
      await tx.post_op_note.create({
        data: {
          theatre_case_id: theatreCase.id,
          note: sanitize(data.note),
          record_status: toUpper(data.record_status) || 'DRAFT',
        },
        select: { id: true },
      });
    }

    return theatreCase.id;
  });

  return finalizeAction({
    theatreCaseId: result,
    action: 'UPSERT_POST_OP_NOTE',
    context,
    details: { payload: data },
  });
};

const toggleChecklistItem = async (id, data, context = {}) => {
  const result = await prisma.$transaction(async (tx) => {
    const theatreCase = await resolveTheatreCaseByIdentifier(tx, id);
    if (!theatreCase) throw new HttpError('errors.theatre_flow.not_found', 404);
    assertCaseNotTerminal(theatreCase);

    let checklistItem = null;
    if (data.checklist_item_id) {
      checklistItem = await resolveByIdentifier(
        tx.theatre_case_checklist_item,
        data.checklist_item_id,
        { theatre_case_id: theatreCase.id },
        {
          id: true,
          is_checked: true,
        }
      );
    } else {
      checklistItem = await tx.theatre_case_checklist_item.findFirst({
        where: {
          theatre_case_id: theatreCase.id,
          phase: toUpper(data.phase),
          item_code: sanitize(data.item_code),
          deleted_at: null,
        },
        select: {
          id: true,
          is_checked: true,
        },
      });
    }

    const nextChecked =
      data.is_checked === undefined
        ? !Boolean(checklistItem?.is_checked)
        : parseBoolean(data.is_checked, false);

    const checkedAt = nextChecked ? new Date() : null;
    const checkedByUserId = nextChecked ? context.user_id || null : null;

    if (checklistItem) {
      await tx.theatre_case_checklist_item.update({
        where: { id: checklistItem.id },
        data: {
          is_checked: nextChecked,
          checked_at: checkedAt,
          checked_by_user_id: checkedByUserId,
          ...(data.notes !== undefined ? { notes: sanitize(data.notes) || null } : {}),
          ...(data.item_label !== undefined
            ? { item_label: sanitize(data.item_label) || sanitize(data.item_code) }
            : {}),
        },
        select: { id: true },
      });
    } else {
      await tx.theatre_case_checklist_item.create({
        data: {
          theatre_case_id: theatreCase.id,
          phase: toUpper(data.phase),
          item_code: sanitize(data.item_code),
          item_label: sanitize(data.item_label) || sanitize(data.item_code),
          is_checked: nextChecked,
          checked_at: checkedAt,
          checked_by_user_id: checkedByUserId,
          notes: sanitize(data.notes) || null,
        },
        select: { id: true },
      });
    }

    return theatreCase.id;
  });

  return finalizeAction({
    theatreCaseId: result,
    action: 'TOGGLE_CHECKLIST_ITEM',
    context,
    details: { payload: data },
  });
};

const assignResource = async (id, data, context = {}) => {
  const result = await prisma.$transaction(async (tx) => {
    const theatreCase = await resolveTheatreCaseByIdentifier(tx, id);
    if (!theatreCase) throw new HttpError('errors.theatre_flow.not_found', 404);
    assertCaseNotTerminal(theatreCase);

    const flowScope = await tx.theatre_case.findFirst({
      where: { id: theatreCase.id },
      select: {
        encounter: {
          select: {
            tenant_id: true,
            facility_id: true,
          },
        },
      },
    });

    const tenantId = flowScope?.encounter?.tenant_id || null;
    const facilityId = flowScope?.encounter?.facility_id || null;

    const resourceType = toUpper(data.resource_type);
    let resolvedResource = null;
    let caseUpdate = {};

    if (resourceType === 'ROOM') {
      resolvedResource = await resolveRoomByIdentifier(
        tx,
        data.resource_id,
        tenantId,
        facilityId
      );
      if (!resolvedResource) throw new HttpError('errors.theatre_flow.room_not_found', 404);
      caseUpdate.room_id = resolvedResource.id;
    } else if (resourceType === 'STAFF') {
      resolvedResource = await resolveStaffProfileByIdentifier(
        tx,
        data.resource_id,
        tenantId,
        facilityId
      );
      if (!resolvedResource) throw new HttpError('errors.theatre_flow.staff_not_found', 404);

      const staffRole = toUpper(data.staff_role);
      if (staffRole === 'SURGEON') {
        caseUpdate.surgeon_user_id = resolvedResource.user_id;
      } else if (staffRole === 'ANESTHETIST') {
        caseUpdate.anesthetist_user_id = resolvedResource.user_id;
      }
    } else if (resourceType === 'EQUIPMENT') {
      resolvedResource = await resolveEquipmentByIdentifier(tx, data.resource_id, tenantId);
      if (!resolvedResource) throw new HttpError('errors.theatre_flow.equipment_not_found', 404);
    } else {
      throw new HttpError('errors.validation.invalid', 400, [{ field: 'resource_type' }]);
    }

    await assertNoActiveDuplicateResource({
      tx,
      theatreCaseId: theatreCase.id,
      resourceType,
      resourceId: resolvedResource.id,
    });

    await tx.theatre_case_resource_allocation.create({
      data: {
        theatre_case_id: theatreCase.id,
        resource_type: resourceType,
        resource_id: resolvedResource.id,
        assigned_by_user_id: context.user_id || null,
        notes: sanitize(data.notes) || null,
      },
      select: { id: true },
    });

    if (Object.keys(caseUpdate).length > 0) {
      await tx.theatre_case.update({
        where: { id: theatreCase.id },
        data: caseUpdate,
        select: { id: true },
      });
    }

    return theatreCase.id;
  });

  return finalizeAction({
    theatreCaseId: result,
    action: 'ASSIGN_RESOURCE',
    context,
    details: { payload: data },
  });
};

const releaseResource = async (id, data, context = {}) => {
  const result = await prisma.$transaction(async (tx) => {
    const theatreCase = await resolveTheatreCaseByIdentifier(tx, id);
    if (!theatreCase) throw new HttpError('errors.theatre_flow.not_found', 404);

    let allocation = null;
    if (data.allocation_id) {
      allocation = await resolveResourceAllocationByIdentifier(
        tx,
        data.allocation_id,
        theatreCase.id
      );
      if (!allocation) throw new HttpError('errors.theatre_flow.resource_allocation_not_found', 404);
    } else {
      const resourceType = sanitize(data.resource_type)
        ? toUpper(data.resource_type)
        : undefined;
      let resourceId = null;
      if (sanitize(data.resource_id)) {
        if (resourceType === 'ROOM') {
          const room = await resolveRoomByIdentifier(tx, data.resource_id);
          if (!room) throw new HttpError('errors.theatre_flow.room_not_found', 404);
          resourceId = room.id;
        } else if (resourceType === 'STAFF') {
          const staff = await resolveStaffProfileByIdentifier(tx, data.resource_id);
          if (!staff) throw new HttpError('errors.theatre_flow.staff_not_found', 404);
          resourceId = staff.id;
        } else if (resourceType === 'EQUIPMENT') {
          const equipment = await resolveEquipmentByIdentifier(tx, data.resource_id);
          if (!equipment) throw new HttpError('errors.theatre_flow.equipment_not_found', 404);
          resourceId = equipment.id;
        }
      }

      allocation = await tx.theatre_case_resource_allocation.findFirst({
        where: {
          theatre_case_id: theatreCase.id,
          deleted_at: null,
          released_at: null,
          ...(resourceType ? { resource_type: resourceType } : {}),
          ...(resourceId ? { resource_id: resourceId } : {}),
        },
        orderBy: {
          assigned_at: 'desc',
        },
        select: {
          id: true,
          resource_type: true,
          resource_id: true,
        },
      });
      if (!allocation) throw new HttpError('errors.theatre_flow.resource_allocation_not_found', 404);
    }

    await tx.theatre_case_resource_allocation.update({
      where: { id: allocation.id },
      data: {
        released_at: toDate(data.released_at),
        released_by_user_id: context.user_id || null,
        ...(data.notes !== undefined ? { notes: sanitize(data.notes) || null } : {}),
      },
      select: { id: true },
    });

    if (toUpper(allocation.resource_type) === 'ROOM') {
      const current = await tx.theatre_case.findFirst({
        where: { id: theatreCase.id },
        select: { room_id: true },
      });
      if (current?.room_id && current.room_id === allocation.resource_id) {
        await tx.theatre_case.update({
          where: { id: theatreCase.id },
          data: { room_id: null },
        });
      }
    } else if (toUpper(allocation.resource_type) === 'STAFF') {
      const staff = await resolveStaffProfileByIdentifier(tx, allocation.resource_id);
      if (staff?.user_id) {
        const current = await tx.theatre_case.findFirst({
          where: { id: theatreCase.id },
          select: {
            surgeon_user_id: true,
            anesthetist_user_id: true,
          },
        });
        const patch = {};
        if (current?.surgeon_user_id === staff.user_id) patch.surgeon_user_id = null;
        if (current?.anesthetist_user_id === staff.user_id) patch.anesthetist_user_id = null;
        if (Object.keys(patch).length > 0) {
          await tx.theatre_case.update({
            where: { id: theatreCase.id },
            data: patch,
          });
        }
      }
    }

    return theatreCase.id;
  });

  return finalizeAction({
    theatreCaseId: result,
    action: 'RELEASE_RESOURCE',
    context,
    details: { payload: data },
  });
};

const finalizeRecord = async (id, data, context = {}) => {
  const result = await prisma.$transaction(async (tx) => {
    const theatreCase = await resolveTheatreCaseByIdentifier(tx, id);
    if (!theatreCase) throw new HttpError('errors.theatre_flow.not_found', 404);
    if (toUpper(theatreCase.status) === 'CANCELLED') {
      throw new HttpError('errors.theatre_flow.case_terminal', 400);
    }

    const recordType = toUpper(data.record_type || 'ALL');
    const finalizedAt = new Date();

    const finalizeAnesthesia = async () => {
      let target = null;
      if (data.anesthesia_record_id) {
        target = await resolveAnesthesiaRecordByIdentifier(
          tx,
          data.anesthesia_record_id,
          theatreCase.id
        );
      } else {
        target = await tx.anesthesia_record.findFirst({
          where: {
            theatre_case_id: theatreCase.id,
            deleted_at: null,
          },
          orderBy: {
            updated_at: 'desc',
          },
          select: { id: true },
        });
      }
      if (!target) throw new HttpError('errors.theatre_flow.anesthesia_record_not_found', 404);
      await assertAnesthesiaRecordReadyForFinalization(tx, theatreCase.id, target.id);

      await tx.anesthesia_record.update({
        where: { id: target.id },
        data: {
          record_status: 'FINAL',
          finalized_at: finalizedAt,
          finalized_by_user_id: context.user_id || null,
        },
      });
    };

    const finalizePostOp = async () => {
      let target = null;
      if (data.post_op_note_id) {
        target = await resolvePostOpNoteByIdentifier(tx, data.post_op_note_id, theatreCase.id);
      } else {
        target = await tx.post_op_note.findFirst({
          where: {
            theatre_case_id: theatreCase.id,
            deleted_at: null,
          },
          orderBy: {
            updated_at: 'desc',
          },
          select: { id: true },
        });
      }
      if (!target) throw new HttpError('errors.theatre_flow.post_op_note_not_found', 404);
      await assertPostOpRecordReadyForFinalization(tx, theatreCase.id, target.id);

      await tx.post_op_note.update({
        where: { id: target.id },
        data: {
          record_status: 'FINAL',
          finalized_at: finalizedAt,
          finalized_by_user_id: context.user_id || null,
        },
      });
    };

    if (recordType === 'ANESTHESIA') {
      await finalizeAnesthesia();
    } else if (recordType === 'POST_OP') {
      await finalizePostOp();
    } else {
      await finalizeAnesthesia();
      await finalizePostOp();
    }

    const [latestAnesthesia, latestPostOp] = await Promise.all([
      tx.anesthesia_record.findFirst({
        where: {
          theatre_case_id: theatreCase.id,
          deleted_at: null,
        },
        orderBy: { updated_at: 'desc' },
        select: { record_status: true },
      }),
      tx.post_op_note.findFirst({
        where: {
          theatre_case_id: theatreCase.id,
          deleted_at: null,
        },
        orderBy: { updated_at: 'desc' },
        select: { record_status: true },
      }),
    ]);

    if (
      toUpper(latestAnesthesia?.record_status) === 'FINAL' &&
      toUpper(latestPostOp?.record_status) === 'FINAL'
    ) {
      await assertChecklistReadyForClosure(tx, theatreCase.id);
      await tx.theatre_case.update({
        where: { id: theatreCase.id },
        data: {
          status: 'COMPLETED',
          workflow_stage: 'COMPLETED',
          completed_at: theatreCase.completed_at || finalizedAt,
        },
      });
    }

    return theatreCase.id;
  });

  return finalizeAction({
    theatreCaseId: result,
    action: 'FINALIZE_RECORD',
    context,
    details: { payload: data },
  });
};

const reopenRecord = async (id, data, context = {}) => {
  const roles = Array.isArray(context.roles)
    ? context.roles.map((role) => normalizeRoleName(role)).filter(Boolean)
    : [];
  const authorized = roles.some((role) => REOPEN_ALLOWED_ROLES.has(role));
  if (!authorized) throw new HttpError('errors.theatre_flow.reopen_not_authorized', 403);

  const reason = sanitize(data.reason);
  if (!reason) throw new HttpError('errors.validation.field.required', 400, [{ field: 'reason' }]);

  const result = await prisma.$transaction(async (tx) => {
    const theatreCase = await resolveTheatreCaseByIdentifier(tx, id);
    if (!theatreCase) throw new HttpError('errors.theatre_flow.not_found', 404);

    const recordType = toUpper(data.record_type || 'ALL');
    const reopenedAt = new Date();

    const reopenAnesthesia = async () => {
      let target = null;
      if (data.anesthesia_record_id) {
        target = await resolveAnesthesiaRecordByIdentifier(
          tx,
          data.anesthesia_record_id,
          theatreCase.id
        );
      } else {
        target = await tx.anesthesia_record.findFirst({
          where: {
            theatre_case_id: theatreCase.id,
            deleted_at: null,
          },
          orderBy: { updated_at: 'desc' },
          select: { id: true, record_status: true },
        });
      }
      if (!target) throw new HttpError('errors.theatre_flow.anesthesia_record_not_found', 404);
      if (toUpper(target.record_status) !== 'FINAL') {
        throw new HttpError('errors.theatre_flow.record_not_finalized', 400);
      }

      await tx.anesthesia_record.update({
        where: { id: target.id },
        data: {
          record_status: 'DRAFT',
          reopened_at: reopenedAt,
          reopened_by_user_id: context.user_id || null,
          reopen_reason: reason,
        },
      });
    };

    const reopenPostOp = async () => {
      let target = null;
      if (data.post_op_note_id) {
        target = await resolvePostOpNoteByIdentifier(tx, data.post_op_note_id, theatreCase.id);
      } else {
        target = await tx.post_op_note.findFirst({
          where: {
            theatre_case_id: theatreCase.id,
            deleted_at: null,
          },
          orderBy: { updated_at: 'desc' },
          select: { id: true, record_status: true },
        });
      }
      if (!target) throw new HttpError('errors.theatre_flow.post_op_note_not_found', 404);
      if (toUpper(target.record_status) !== 'FINAL') {
        throw new HttpError('errors.theatre_flow.record_not_finalized', 400);
      }

      await tx.post_op_note.update({
        where: { id: target.id },
        data: {
          record_status: 'DRAFT',
          reopened_at: reopenedAt,
          reopened_by_user_id: context.user_id || null,
          reopen_reason: reason,
        },
      });
    };

    if (recordType === 'ANESTHESIA') {
      await reopenAnesthesia();
    } else if (recordType === 'POST_OP') {
      await reopenPostOp();
    } else {
      await reopenAnesthesia();
      await reopenPostOp();
    }

    await tx.theatre_case.update({
      where: { id: theatreCase.id },
      data: {
        status: 'IN_PROGRESS',
        workflow_stage: sanitize(theatreCase.workflow_stage) || 'POST_OP',
        completed_at: null,
      },
    });

    return theatreCase.id;
  });

  return finalizeAction({
    theatreCaseId: result,
    action: 'REOPEN_RECORD',
    context,
    details: { payload: data },
  });
};

module.exports = {
  listTheatreFlows,
  getTheatreFlowById,
  resolveLegacyRoute,
  startTheatreFlow,
  updateStage,
  upsertAnesthesiaRecord,
  addAnesthesiaObservation,
  upsertPostOpNote,
  toggleChecklistItem,
  assignResource,
  releaseResource,
  finalizeRecord,
  reopenRecord,
};
