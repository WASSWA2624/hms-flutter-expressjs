/**
 * Emergency case service
 *
 * @module modules/emergency-case/services
 * @description Business logic layer for emergency case operations.
 * Per module-creation.mdc: Only import and use its own repository.
 * Per module-creation.mdc: All mutations must call audit log.
 */

const emergencyCaseRepository = require('@repositories/emergency-case/emergency-case.repository');
const patientRepository = require('@repositories/patient/patient.repository');
const patientContactRepository = require('@repositories/patient-contact/patient-contact.repository');
const triageAssessmentRepository = require('@repositories/triage-assessment/triage-assessment.repository');
const emergencyResponseRepository = require('@modules/emergency-response/repositories/emergency-response.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');
const { createAuditLog } = require('@lib/audit');
const { isUuidLike } = require('@lib/identifiers/sanitize-friendly-ids');
const { resolveModelIdByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload
} = require('@lib/identifiers/service-identifier-resolution');

const sanitizeIdentifier = (value) => (typeof value === 'string' ? value.trim() : '');
const sanitizeText = (value) => (typeof value === 'string' ? value.trim() : null);
const toPublicIdentifier = (value) => {
  const normalized = sanitizeIdentifier(value);
  if (!normalized || isUuidLike(normalized)) return null;
  return normalized;
};
const resolveDisplayIdentifier = (...values) => {
  for (const value of values) {
    const displayValue = toPublicIdentifier(value);
    if (displayValue) return displayValue;
  }
  return null;
};
const resolvePatientDisplayName = (patient) => {
  const firstName = sanitizeIdentifier(patient?.first_name);
  const lastName = sanitizeIdentifier(patient?.last_name);
  const fullName = [firstName, lastName].filter(Boolean).join(' ').trim();
  return fullName || null;
};

const requirePublicIdentifier = (record, field) => {
  const identifier = sanitizeIdentifier(record?.human_friendly_id);
  if (!identifier) {
    throw new HttpError('errors.server.unexpected', 500, [{ field }]);
  }
  return identifier;
};

const mapQuickArrivalCase = (record) => {
  const caseId = requirePublicIdentifier(record, 'emergency_case_id');
  const patientId = requirePublicIdentifier(record?.patient, 'patient_id');
  const tenantId = requirePublicIdentifier(record?.tenant, 'tenant_id');
  const facilityId = record?.facility
    ? requirePublicIdentifier(record.facility, 'facility_id')
    : null;

  return {
    human_friendly_id: caseId,
    display_id: caseId,
    tenant_id: tenantId,
    tenant_display_id: tenantId,
    facility_id: facilityId,
    facility_display_id: facilityId,
    patient_id: patientId,
    patient_display_id: patientId,
    patient_display_name: resolvePatientDisplayName(record.patient),
    severity: record.severity,
    status: record.status,
    extension_json: record.extension_json || null,
    created_at: record.created_at,
    updated_at: record.updated_at
  };
};

const mapQuickArrivalRelatedRecord = (record, emergencyCaseId) => {
  if (!record) return null;
  const displayId = requirePublicIdentifier(record, 'related_record_id');
  return {
    human_friendly_id: displayId,
    display_id: displayId,
    emergency_case_id: emergencyCaseId,
    emergency_case_display_id: emergencyCaseId,
    triage_level: record.triage_level,
    response_at: record.response_at,
    notes: record.notes,
    created_at: record.created_at,
    updated_at: record.updated_at
  };
};

const EMERGENCY_CASE_STATUS_ALIAS_MAP = Object.freeze({
  OPEN: 'OPEN',
  CLOSED: 'CLOSED',
  CANCELLED: 'CANCELLED',
  PENDING: 'OPEN',
  IN_PROGRESS: 'OPEN',
  COMPLETED: 'CLOSED'
});

const normalizeEmergencyCaseStatus = (value) => {
  const normalized = sanitizeIdentifier(value).toUpperCase();
  if (!normalized) return null;
  return EMERGENCY_CASE_STATUS_ALIAS_MAP[normalized] || null;
};

const EMERGENCY_HANDOFF_DESTINATION_ALIAS_MAP = Object.freeze({
  OPD: 'OPD',
  IPD: 'IPD',
  ICU: 'ICU',
  THEATER: 'THEATER',
  THEATRE: 'THEATER',
  REFERRAL: 'REFERRAL',
  DISCHARGE: 'DISCHARGE'
});

const normalizeHandoffDestination = (value) => {
  const normalized = sanitizeIdentifier(value).toUpperCase();
  return EMERGENCY_HANDOFF_DESTINATION_ALIAS_MAP[normalized] || null;
};

const buildHandoffNote = (destination, notes) =>
  [`Handoff to ${destination}.`, sanitizeText(notes)].filter(Boolean).join('\n');

const buildWorkflowContext = (emergencyCase, user = {}) => ({
  user_id: user.id || user.user_id || user.userId || null,
  tenant_id: emergencyCase.tenant_id || user.tenant_id || null,
  facility_id: emergencyCase.facility_id || user.facility_id || null
});

const resolvePublicSnapshotId = (...values) => {
  for (const value of values) {
    const normalized = sanitizeIdentifier(value);
    if (normalized) return normalized;
  }
  return null;
};

const getEmergencyResponseRepository = () =>
  require('@modules/emergency-response/repositories/emergency-response.repository');

const getOpdFlowService = () => require('@services/opd-flow/opd-flow.service');
const getIpdFlowService = () => require('@services/ipd-flow/ipd-flow.service');
const getEncounterService = () => require('@services/encounter/encounter.service');
const getTheatreFlowService = () => require('@services/theatre-flow/theatre-flow.service');
const {
  buildEmergencyAdmissionBilling,
  buildEmergencyTheatreBilling,
  HANDOFF_ADMISSION_CHARGE_KEY,
  HANDOFF_THEATRE_CHARGE_KEY,
  persistEmergencyCaseServiceBilling,
  shouldApplyClinicalRequestBilling,
} = require('@lib/billing/emergency-billing');

const buildEmptyListResult = (page, limit) => ({
  items: [],
  total: 0,
  page,
  limit,
  totalPages: 0
});

const extractHandoffSnapshot = (record) => {
  const extension = record?.extension_json;
  if (!extension || typeof extension !== 'object') return null;
  const handoff = extension.handoff;
  return handoff && typeof handoff === 'object' ? handoff : null;
};

const mapEmergencyCaseForDisplay = (record) => {
  if (!record || typeof record !== 'object') return record;

  return {
    ...record,
    handoff: extractHandoffSnapshot(record),
    display_id: resolveDisplayIdentifier(record.display_id, record.human_friendly_id, record.id),
    tenant_display_id: resolveDisplayIdentifier(
      record.tenant_display_id,
      record.tenant?.human_friendly_id,
      record.tenant_id
    ),
    facility_display_id: resolveDisplayIdentifier(
      record.facility_display_id,
      record.facility?.human_friendly_id,
      record.facility_id
    ),
    patient_display_id: resolveDisplayIdentifier(
      record.patient_display_id,
      record.patient?.human_friendly_id,
      record.patient_id
    ),
    patient_display_name: record.patient_display_name || resolvePatientDisplayName(record.patient)
  };
};

const resolveEmergencyCaseId = async (id) => {
  const normalized = sanitizeIdentifier(id);
  if (!normalized) return normalized;

  const resolvedId = await resolveModelIdByIdentifier({
    model: 'emergency_case',
    identifier: normalized
  });

  return resolvedId || normalized;
};

const resolveListFilters = async (filters = {}, page, limit) => {
  const resolvedFilters = {};

  if (filters.tenant_id !== undefined) {
    const tenantId = await resolveIdentifierForFilter({
      value: filters.tenant_id,
      model: 'tenant'
    });
    if (tenantId === null) return buildEmptyListResult(page, limit);
    if (tenantId !== undefined) resolvedFilters.tenant_id = tenantId;
  }

  if (filters.facility_id !== undefined) {
    const facilityId = await resolveIdentifierForFilter({
      value: filters.facility_id,
      model: 'facility',
      where: resolvedFilters.tenant_id ? { tenant_id: resolvedFilters.tenant_id } : {}
    });
    if (facilityId === null) return buildEmptyListResult(page, limit);
    if (facilityId !== undefined) resolvedFilters.facility_id = facilityId;
  }

  if (filters.patient_id !== undefined) {
    const patientId = await resolveIdentifierForFilter({
      value: filters.patient_id,
      model: 'patient',
      where: {
        ...(resolvedFilters.tenant_id ? { tenant_id: resolvedFilters.tenant_id } : {}),
        ...(resolvedFilters.facility_id ? { facility_id: resolvedFilters.facility_id } : {})
      }
    });
    if (patientId === null) return buildEmptyListResult(page, limit);
    if (patientId !== undefined) resolvedFilters.patient_id = patientId;
  }

  if (filters.severity) resolvedFilters.severity = filters.severity;
  if (filters.status !== undefined) {
    const mappedStatus = normalizeEmergencyCaseStatus(filters.status);
    if (!mappedStatus) return buildEmptyListResult(page, limit);
    resolvedFilters.status = mappedStatus;
  }

  const search = sanitizeIdentifier(filters.search);
  if (search) resolvedFilters.search = search;

  return resolvedFilters;
};

const resolveCreatePayload = async (data = {}) => {
  const payload = { ...data };

  const tenantId = await resolveIdentifierForPayload({
    value: payload.tenant_id,
    field: 'tenant_id',
    model: 'tenant'
  });
  const facilityId = await resolveIdentifierForPayload({
    value: payload.facility_id,
    field: 'facility_id',
    model: 'facility',
    where: tenantId ? { tenant_id: tenantId } : {},
    nullable: true
  });
  const patientId = await resolveIdentifierForPayload({
    value: payload.patient_id,
    field: 'patient_id',
    model: 'patient',
    where: {
      ...(tenantId ? { tenant_id: tenantId } : {}),
      ...(facilityId ? { facility_id: facilityId } : {})
    }
  });

  payload.tenant_id = tenantId;
  if (facilityId !== undefined) {
    payload.facility_id = facilityId;
  } else {
    delete payload.facility_id;
  }
  payload.patient_id = patientId;

  const mappedStatus = normalizeEmergencyCaseStatus(payload.status);
  if (!mappedStatus) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'status' }]);
  }
  payload.status = mappedStatus;

  return payload;
};

const resolveUpdatePayload = async (data = {}, existing = null) => {
  const payload = { ...data };
  const tenantId = existing?.tenant_id || null;

  const hasFacilityField = Object.prototype.hasOwnProperty.call(payload, 'facility_id');
  if (hasFacilityField) {
    payload.facility_id = await resolveIdentifierForPayload({
      value: payload.facility_id,
      field: 'facility_id',
      model: 'facility',
      where: tenantId ? { tenant_id: tenantId } : {},
      nullable: true
    });
  }

  if (payload.patient_id !== undefined) {
    const effectiveFacilityId = hasFacilityField
      ? payload.facility_id
      : existing?.facility_id || null;
    payload.patient_id = await resolveIdentifierForPayload({
      value: payload.patient_id,
      field: 'patient_id',
      model: 'patient',
      where: {
        ...(tenantId ? { tenant_id: tenantId } : {}),
        ...(effectiveFacilityId ? { facility_id: effectiveFacilityId } : {})
      }
    });
  }

  if (payload.status !== undefined) {
    const mappedStatus = normalizeEmergencyCaseStatus(payload.status);
    if (!mappedStatus) {
      throw new HttpError('errors.validation.invalid', 400, [{ field: 'status' }]);
    }
    payload.status = mappedStatus;
  }

  return payload;
};

const startEmergencyOpdFlow = async (emergencyCase, note, context) => {
  if (!emergencyCase.patient_id) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'patient_id' }]);
  }

  const opdFlowService = getOpdFlowService();
  // Care proceeds without payment gate, but consultation fee still posts a
  // PENDING Billing invoice when a fee resolves (deferred settlement).
  return opdFlowService.startOpdFlow(
    {
      tenant_id: emergencyCase.tenant_id,
      facility_id: emergencyCase.facility_id || null,
      patient_id: emergencyCase.patient_id,
      arrival_mode: 'EMERGENCY',
      emergency_case_id: emergencyCase.id,
      initial_stage: 'WAITING_VITALS',
      require_consultation_payment: false,
      create_consultation_invoice: true,
      reuse_open_encounter: true,
      queued_at: new Date().toISOString(),
      notes: note
    },
    context
  );
};

const startEmergencyIpdFlow = async (emergencyCase, context, handoffData = {}) => {
  if (!emergencyCase.patient_id) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'patient_id' }]);
  }

  const admissionBilling = buildEmergencyAdmissionBilling({
    billing: handoffData.billing,
    facility: emergencyCase.facility,
  });
  const ipdFlowService = getIpdFlowService();
  const snapshot = await ipdFlowService.startIpdFlow(
    {
      tenant_id: emergencyCase.tenant_id,
      facility_id: emergencyCase.facility_id || null,
      patient_id: emergencyCase.patient_id,
      ...(admissionBilling ? { billing: admissionBilling } : {})
    },
    context
  );

  // When IPD start accepted no billing payload (or fee unresolved), still try
  // an idempotent SERVICE post keyed by emergency case so deferred care is
  // traceable in Billing when a fee becomes available via handoff.billing.
  if (
    admissionBilling &&
    shouldApplyClinicalRequestBilling(admissionBilling) &&
    !snapshot?.billing &&
    !snapshot?.admission?.billing_snapshot
  ) {
    const admissionId =
      snapshot?.admission?.id ||
      snapshot?.admission_id ||
      null;
    if (admissionId) {
      await prisma.$transaction(async (tx) => {
        await persistEmergencyCaseServiceBilling(tx, {
          emergencyCaseId: emergencyCase.id,
          chargeKey: HANDOFF_ADMISSION_CHARGE_KEY,
          billing: admissionBilling,
          tenantId: emergencyCase.tenant_id,
          facilityId: emergencyCase.facility_id || null,
          patientId: emergencyCase.patient_id,
          description: 'Emergency admission fee',
          actorUserId: context.user_id || null
        });
      });
    }
  }

  return {
    ...snapshot,
    billing_deferred: true,
    billing: admissionBilling || snapshot?.billing || null
  };
};

const startEmergencyIcuFlow = async (emergencyCase, context, handoffData = {}) => {
  const ipdFlowService = getIpdFlowService();
  const admissionSnapshot = await startEmergencyIpdFlow(
    emergencyCase,
    context,
    handoffData
  );
  const admissionId = resolvePublicSnapshotId(
    admissionSnapshot?.id,
    admissionSnapshot?.human_friendly_id,
    admissionSnapshot?.admission?.id
  );

  if (!admissionId) {
    throw new HttpError('errors.ipd_flow.not_found', 404, [{ field: 'admission_id' }]);
  }

  const icuStay = await ipdFlowService.startIcuStay(
    admissionId,
    { started_at: new Date().toISOString() },
    context
  );

  return { admission: admissionSnapshot, icuStay, billing: admissionSnapshot?.billing || null };
};

const startEmergencyTheatreFlow = async (emergencyCase, note, context, handoffData = {}) => {
  if (!emergencyCase.patient_id) {
    throw new HttpError('errors.validation.field.required', 400, [{ field: 'patient_id' }]);
  }

  const theatreBilling = buildEmergencyTheatreBilling({
    billing: handoffData.billing,
    facility: emergencyCase.facility,
  });

  const encounterService = getEncounterService();
  const theatreEncounter = await encounterService.createEncounter(
    {
      tenant_id: emergencyCase.tenant_id,
      facility_id: emergencyCase.facility_id || null,
      patient_id: emergencyCase.patient_id,
      encounter_type: 'THEATRE',
      status: 'OPEN',
      started_at: new Date().toISOString()
    },
    context.user_id,
    context.ip_address
  );
  const encounterId = resolvePublicSnapshotId(
    theatreEncounter?.human_friendly_id,
    theatreEncounter?.display_id,
    theatreEncounter?.id
  );

  if (!encounterId) {
    throw new HttpError('errors.encounter.not_found', 404, [{ field: 'encounter_id' }]);
  }

  const theatreFlowService = getTheatreFlowService();
  const theatre = await theatreFlowService.startTheatreFlow(
    {
      encounter_id: encounterId,
      emergency_case_id: resolvePublicSnapshotId(
        emergencyCase?.human_friendly_id,
        emergencyCase?.display_id,
        emergencyCase?.id
      ),
      source_kind: 'EMERGENCY',
      scheduled_at: new Date().toISOString(),
      status: 'SCHEDULED',
      workflow_stage: 'PRE_OP',
      stage_notes: note,
      ...(theatreBilling ? { billing: theatreBilling } : {})
    },
    context
  );

  if (theatreBilling && shouldApplyClinicalRequestBilling(theatreBilling) && !theatre?.billing) {
    await prisma.$transaction(async (tx) => {
      await persistEmergencyCaseServiceBilling(tx, {
        emergencyCaseId: emergencyCase.id,
        chargeKey: HANDOFF_THEATRE_CHARGE_KEY,
        billing: theatreBilling,
        tenantId: emergencyCase.tenant_id,
        facilityId: emergencyCase.facility_id || null,
        patientId: emergencyCase.patient_id,
        description: 'Emergency theatre fee',
        actorUserId: context.user_id || null
      });
    });
  }

  return { theatre, encounterId, billing: theatreBilling || null };
};

const startReceivingDepartmentWork = async (
  emergencyCase,
  destination,
  note,
  context,
  handoffData = {}
) => {
  switch (destination) {
    case 'OPD':
      return startEmergencyOpdFlow(emergencyCase, note, context);
    case 'IPD':
      return startEmergencyIpdFlow(emergencyCase, context, handoffData);
    case 'ICU':
      return startEmergencyIcuFlow(emergencyCase, context, handoffData);
    case 'THEATER':
      return startEmergencyTheatreFlow(emergencyCase, note, context, handoffData);
    case 'REFERRAL':
    case 'DISCHARGE':
      return null;
    default:
      throw new HttpError('errors.validation.invalid', 400, [{ field: 'destination' }]);
  }
};

const HANDOFF_ROUTE_BY_DESTINATION = Object.freeze({
  OPD: 'opd',
  IPD: 'ipd',
  ICU: 'icu',
  THEATER: 'theater'
});

const HANDOFF_TERMINAL_DESTINATIONS = new Set(['REFERRAL', 'DISCHARGE']);

/**
 * Normalize the receiving department workflow into a UI-friendly snapshot so
 * the emergency case detail can deep-link to the downstream module without
 * leaking raw identifiers or re-querying the receiving workflow.
 *
 * @param {string} destination - Normalized handoff destination
 * @param {Object|null} receivingWork - Raw return of the receiving flow service
 * @returns {Object} Receiving workflow snapshot fields
 */
const buildReceivingWorkSnapshot = (destination, receivingWork) => {
  if (!receivingWork || typeof receivingWork !== 'object') {
    return {
      receiving_display_id: null,
      stage: null,
      billing_deferred: false
    };
  }

  switch (destination) {
    case 'OPD': {
      const encounter = receivingWork.encounter || receivingWork;
      const flow = receivingWork.flow || {};
      const encounterId = resolvePublicSnapshotId(
        encounter?.human_friendly_id,
        encounter?.display_id,
        encounter?.id,
        receivingWork.human_friendly_id,
        receivingWork.id
      );
      return {
        receiving_display_id: encounterId,
        encounter_display_id: encounterId,
        stage: resolvePublicSnapshotId(flow.workflow_stage, flow.stage) || 'WAITING_VITALS',
        billing_deferred: false
      };
    }
    case 'IPD': {
      const admission = receivingWork.admission || receivingWork;
      const flow = receivingWork.flow || {};
      const admissionId = resolvePublicSnapshotId(
        admission?.human_friendly_id,
        admission?.display_id,
        admission?.id,
        receivingWork.human_friendly_id,
        receivingWork.id
      );
      return {
        receiving_display_id: admissionId,
        admission_display_id: admissionId,
        stage: resolvePublicSnapshotId(flow.stage, flow.workflow_stage, admission?.status),
        billing_deferred: true
      };
    }
    case 'ICU': {
      const admission = receivingWork.admission || {};
      const icuStay = receivingWork.icuStay || {};
      const flow = icuStay.flow || admission.flow || {};
      const admissionId = resolvePublicSnapshotId(
        admission.human_friendly_id,
        admission.display_id,
        admission.id,
        icuStay.human_friendly_id,
        icuStay.id
      );
      return {
        receiving_display_id: admissionId,
        admission_display_id: admissionId,
        icu_stay_display_id: resolvePublicSnapshotId(
          icuStay.human_friendly_id,
          icuStay.display_id,
          icuStay.id
        ),
        stage: resolvePublicSnapshotId(flow.stage, flow.workflow_stage) || 'ICU',
        billing_deferred: true
      };
    }
    case 'THEATER': {
      const theatre = receivingWork.theatre || receivingWork;
      const flow = theatre.flow || {};
      const theatreId = resolvePublicSnapshotId(
        theatre.human_friendly_id,
        theatre.display_id,
        theatre.id,
        receivingWork.human_friendly_id,
        receivingWork.id
      );
      return {
        receiving_display_id: theatreId,
        encounter_display_id: resolvePublicSnapshotId(receivingWork.encounterId),
        stage:
          resolvePublicSnapshotId(theatre.workflow_stage, flow.workflow_stage, flow.stage) ||
          'PRE_OP',
        billing_deferred: false
      };
    }
    default:
      return {
        receiving_display_id: null,
        stage: null,
        billing_deferred: false
      };
  }
};

/**
 * Compose the persisted handoff snapshot stored on `extension_json.handoff`.
 *
 * @param {string} destination - Normalized handoff destination
 * @param {Object|null} receivingWork - Raw return of the receiving flow service
 * @param {Object} data - Original handoff request data
 * @returns {Object} Handoff snapshot persisted on the emergency case
 */
const buildHandoffSnapshot = (destination, receivingWork, data = {}) => {
  const terminal = HANDOFF_TERMINAL_DESTINATIONS.has(destination);
  const receiving = terminal
    ? { receiving_display_id: null, stage: null, billing_deferred: false }
    : buildReceivingWorkSnapshot(destination, receivingWork);

  return {
    destination,
    route: HANDOFF_ROUTE_BY_DESTINATION[destination] || null,
    terminal,
    notes: sanitizeText(data.notes),
    close_case: data.close_case !== false,
    handoff_at: new Date().toISOString(),
    ...receiving
  };
};

/**
 * List emergency cases with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order (asc/desc)
 * @returns {Promise<Object>} Paginated emergency cases
 */
const listEmergencyCases = async (
  filters = {},
  page = 1,
  limit = 20,
  sortBy = 'created_at',
  order = 'desc'
) => {
  const skip = (page - 1) * limit;
  const orderBy = { [sortBy]: order };

  const resolvedFilters = await resolveListFilters(filters, page, limit);
  if (resolvedFilters && resolvedFilters.items && resolvedFilters.total !== undefined) {
    return resolvedFilters;
  }

  const [items, total] = await Promise.all([
    emergencyCaseRepository.findMany(resolvedFilters, skip, limit, orderBy),
    emergencyCaseRepository.count(resolvedFilters)
  ]);

  return {
    items: items.map(mapEmergencyCaseForDisplay),
    total,
    page,
    limit,
    totalPages: Math.ceil(total / limit)
  };
};

/**
 * Get emergency case by ID
 *
 * @param {string} id - Emergency case ID
 * @returns {Promise<Object>} Emergency case object
 * @throws {HttpError} If emergency case not found
 */
const getEmergencyCaseById = async (id) => {
  const resolvedId = await resolveEmergencyCaseId(id);
  const emergencyCase = await emergencyCaseRepository.findById(resolvedId);

  if (!emergencyCase) {
    throw new HttpError('errors.emergency_case.not_found', 404);
  }

  return mapEmergencyCaseForDisplay(emergencyCase);
};

/**
 * Create new emergency case
 *
 * @param {Object} data - Emergency case data
 * @param {Object} user - User performing the action (for audit)
 * @returns {Promise<Object>} Created emergency case
 */
const createEmergencyCase = async (data, user) => {
  const payload = await resolveCreatePayload(data);
  const emergencyCase = await emergencyCaseRepository.create(payload);

  await createAuditLog({
    action: 'CREATE',
    resource: 'emergency_case',
    resource_id: emergencyCase.id,
    user_id: user.id,
    tenant_id: emergencyCase.tenant_id || payload.tenant_id,
    details: { data: payload }
  });

  return mapEmergencyCaseForDisplay(emergencyCase);
};

/**
 * Atomically create the incomplete patient, emergency case, and optional
 * triage/response records used by emergency quick arrival.
 */
const createQuickArrival = async (data = {}, user = {}) => {
  const tenantId = await resolveIdentifierForPayload({
    value: data.tenant_id,
    field: 'tenant_id',
    model: 'tenant'
  });
  const facilityId = await resolveIdentifierForPayload({
    value: data.facility_id,
    field: 'facility_id',
    model: 'facility',
    where: tenantId ? { tenant_id: tenantId } : {},
    nullable: true
  });
  const registeredAt = new Date();
  const firstName = sanitizeIdentifier(data.first_name) || 'Emergency';
  const lastName = sanitizeIdentifier(data.last_name) || `Patient ${registeredAt.getTime()}`;
  const phone = sanitizeIdentifier(data.phone);
  const notes = sanitizeText(data.notes);

  const created = await prisma.$transaction(async (tx) => {
    const patient = await patientRepository.create(
      {
        tenant_id: tenantId,
        facility_id: facilityId,
        first_name: firstName,
        last_name: lastName,
        gender: 'UNKNOWN',
        is_active: true,
        extension_json: {
          registration: {
            source: 'EMERGENCY',
            status: 'INCOMPLETE',
            requires_completion: true,
            registered_at: registeredAt.toISOString(),
            notes
          }
        }
      },
      tx
    );

    if (phone) {
      await patientContactRepository.create(
        {
          tenant_id: tenantId,
          patient_id: patient.id,
          contact_type: 'PHONE',
          value: phone,
          is_primary: true
        },
        tx
      );
    }

    const emergencyCase = await emergencyCaseRepository.create(
      {
        tenant_id: tenantId,
        facility_id: facilityId,
        patient_id: patient.id,
        severity: data.severity,
        status: 'OPEN'
      },
      tx
    );

    const triageAssessment = data.triage_level
      ? await triageAssessmentRepository.create(
          {
            emergency_case_id: emergencyCase.id,
            triage_level: data.triage_level,
            notes
          },
          tx
        )
      : null;

    const emergencyResponse = notes
      ? await emergencyResponseRepository.create(
          {
            emergency_case_id: emergencyCase.id,
            response_at: registeredAt,
            notes
          },
          tx
        )
      : null;

    const publicCase = mapQuickArrivalCase(emergencyCase);
    return {
      patient,
      emergencyCase,
      publicCase,
      triageAssessment: mapQuickArrivalRelatedRecord(
        triageAssessment,
        publicCase.human_friendly_id
      ),
      emergencyResponse: mapQuickArrivalRelatedRecord(
        emergencyResponse,
        publicCase.human_friendly_id
      )
    };
  });

  await Promise.all([
    createAuditLog({
      action: 'CREATE',
      resource: 'patient',
      resource_id: created.patient.id,
      user_id: user.id || user.user_id || user.userId || null,
      tenant_id: tenantId,
      details: {
        source: 'EMERGENCY_QUICK_ARRIVAL',
        patient_id: created.publicCase.patient_id
      }
    }),
    createAuditLog({
      action: 'CREATE',
      resource: 'emergency_case',
      resource_id: created.emergencyCase.id,
      user_id: user.id || user.user_id || user.userId || null,
      tenant_id: tenantId,
      details: {
        source: 'QUICK_ARRIVAL',
        emergency_case_id: created.publicCase.human_friendly_id,
        patient_id: created.publicCase.patient_id,
        severity: created.publicCase.severity
      }
    })
  ]);

  return {
    patient: {
      human_friendly_id: created.publicCase.patient_id,
      display_id: created.publicCase.patient_id
    },
    emergency_case: created.publicCase,
    triage_assessment: created.triageAssessment,
    emergency_response: created.emergencyResponse
  };
};

/**
 * Update emergency case
 *
 * @param {string} id - Emergency case ID
 * @param {Object} data - Update data
 * @param {Object} user - User performing the action (for audit)
 * @returns {Promise<Object>} Updated emergency case
 * @throws {HttpError} If emergency case not found
 */
const updateEmergencyCase = async (id, data, user) => {
  const resolvedId = await resolveEmergencyCaseId(id);
  const existing = await emergencyCaseRepository.findById(resolvedId);
  if (!existing) {
    throw new HttpError('errors.emergency_case.not_found', 404);
  }

  const payload = await resolveUpdatePayload(data, existing);
  const updated = await emergencyCaseRepository.update(existing.id, payload);

  await createAuditLog({
    action: 'UPDATE',
    resource: 'emergency_case',
    resource_id: existing.id,
    user_id: user.id,
    tenant_id: existing.tenant_id,
    details: { before: existing, after: payload }
  });

  return mapEmergencyCaseForDisplay(updated);
};

/**
 * Record an emergency case handoff and start the receiving department workflow.
 *
 * @param {string} id - Emergency case ID
 * @param {Object} data - Handoff data
 * @param {Object} user - User performing the action (for audit)
 * @returns {Promise<Object>} Updated emergency case
 * @throws {HttpError} If emergency case is not found or handoff is invalid
 */
const handoffEmergencyCase = async (id, data = {}, user = {}) => {
  const resolvedId = await resolveEmergencyCaseId(id);
  const existing = await emergencyCaseRepository.findById(resolvedId);
  if (!existing) {
    throw new HttpError('errors.emergency_case.not_found', 404);
  }

  const destination = normalizeHandoffDestination(data.destination);
  if (!destination) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'destination' }]);
  }

  const note = buildHandoffNote(destination, data.notes);
  const context = buildWorkflowContext(existing, user);
  const receivingWork = await startReceivingDepartmentWork(existing, destination, note, context);
  const snapshot = buildHandoffSnapshot(destination, receivingWork, data);

  await getEmergencyResponseRepository().create({
    emergency_case_id: existing.id,
    response_at: new Date(),
    notes: note
  });

  const closeCase = data.close_case !== false;
  const existingExtension =
    existing.extension_json && typeof existing.extension_json === 'object'
      ? existing.extension_json
      : {};
  const updatePayload = {
    extension_json: { ...existingExtension, handoff: snapshot }
  };
  if (closeCase) {
    updatePayload.status = 'CLOSED';
  }
  const updated = await emergencyCaseRepository.update(existing.id, updatePayload);

  await createAuditLog({
    action: 'HANDOFF',
    resource: 'emergency_case',
    resource_id: existing.id,
    user_id: user.id || user.user_id || user.userId || null,
    tenant_id: existing.tenant_id,
    details: {
      destination,
      close_case: closeCase,
      receiving_work: Boolean(receivingWork),
      receiving_display_id: snapshot.receiving_display_id,
      billing_deferred: snapshot.billing_deferred,
      notes: sanitizeText(data.notes)
    }
  });

  return mapEmergencyCaseForDisplay(updated);
};

/**
 * Delete emergency case (soft delete)
 *
 * @param {string} id - Emergency case ID
 * @param {Object} user - User performing the action (for audit)
 * @returns {Promise<Object>} Deleted emergency case
 * @throws {HttpError} If emergency case not found
 */
const deleteEmergencyCase = async (id, user) => {
  const resolvedId = await resolveEmergencyCaseId(id);
  const existing = await emergencyCaseRepository.findById(resolvedId);
  if (!existing) {
    throw new HttpError('errors.emergency_case.not_found', 404);
  }

  const deleted = await emergencyCaseRepository.softDelete(existing.id);

  await createAuditLog({
    action: 'DELETE',
    resource: 'emergency_case',
    resource_id: existing.id,
    user_id: user.id,
    tenant_id: existing.tenant_id,
    details: { data: existing }
  });

  return mapEmergencyCaseForDisplay(deleted);
};

module.exports = {
  listEmergencyCases,
  getEmergencyCaseById,
  createEmergencyCase,
  createQuickArrival,
  updateEmergencyCase,
  handoffEmergencyCase,
  deleteEmergencyCase
};
