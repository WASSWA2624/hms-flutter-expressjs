/**
 * OPD flow service
 *
 * @module modules/opd-flow/services
 * @description OPD patient flow orchestration rooted on encounter records.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: direct model operations in service are limited to prisma.$transaction orchestration.
 */

const opdFlowRepository = require('@repositories/opd-flow/opd-flow.repository');
const prisma = require('@prisma/client');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { emitToUser, emitToUsers, OPD_EVENTS, NOTIFICATION_EVENTS } = require('@lib/websocket');
const { ROLES } = require('@config/roles');
const clinicalAlertThresholdService = require('@services/clinical-alert-threshold/clinical-alert-threshold.service');
const { LAB_PANEL_WITH_RELATIONS_INCLUDE } = require('@services/lab-workspace/lab.shared');

const STAGES = {
  WAITING_CONSULTATION_PAYMENT: 'WAITING_CONSULTATION_PAYMENT',
  WAITING_VITALS: 'WAITING_VITALS',
  WAITING_DOCTOR_ASSIGNMENT: 'WAITING_DOCTOR_ASSIGNMENT',
  WAITING_DOCTOR_REVIEW: 'WAITING_DOCTOR_REVIEW',
  LAB_REQUESTED: 'LAB_REQUESTED',
  RADIOLOGY_REQUESTED: 'RADIOLOGY_REQUESTED',
  LAB_AND_RADIOLOGY_REQUESTED: 'LAB_AND_RADIOLOGY_REQUESTED',
  PHARMACY_REQUESTED: 'PHARMACY_REQUESTED',
  WAITING_DISPOSITION: 'WAITING_DISPOSITION',
  ADMITTED: 'ADMITTED',
  DISCHARGED: 'DISCHARGED'
};

const TERMINAL_STAGES = new Set([STAGES.ADMITTED, STAGES.DISCHARGED]);
const WORKFLOW_STAGE_SET = new Set(Object.values(STAGES));
const WORKFLOW_STAGE_ORDER = Object.values(STAGES);
const ACTIVE_OPD_ENCOUNTER_TYPES = ['OPD', 'EMERGENCY'];
const QUEUE_SCOPES = Object.freeze({
  ASSIGNED: 'ASSIGNED',
  WAITING: 'WAITING',
  ALL: 'ALL'
});
const WAITING_QUEUE_STAGES = [STAGES.WAITING_DOCTOR_ASSIGNMENT];
const PAID_PAYMENT_STATUSES = new Set(['COMPLETED', 'PAID', 'SUCCESS', 'SUCCESSFUL', 'APPROVED']);
const PAID_BILLING_STATUSES = new Set(['PAID', 'SETTLED', 'CLEARED']);
const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const BLOOD_PRESSURE_VALUE_REGEX = /^(\d{2,3}(?:\.\d{1,2})?)\s*\/\s*(\d{2,3}(?:\.\d{1,2})?)$/;
const MAX_OPD_SEARCH_TOKENS = 6;
const OPD_FLOW_STAGE_JSON_PATH = '$.opd_flow.stage';
const OPD_FLOW_APPOINTMENT_ID_JSON_PATH = '$.opd_flow.appointment_id';
const OPD_FLOW_VISIT_QUEUE_ID_JSON_PATH = '$.opd_flow.visit_queue_id';
const OPD_FLOW_EMERGENCY_CASE_ID_JSON_PATH = '$.opd_flow.emergency_case_id';
const LEGACY_ROUTE_CONFIG = Object.freeze({
  'emergency-cases': {
    model: 'emergency_case',
    panel: 'queue',
    action: 'open_case'
  },
  'triage-assessments': {
    model: 'triage_assessment',
    emergencyCaseField: 'emergency_case_id',
    panel: 'intake',
    action: 'update_triage'
  },
  'emergency-responses': {
    model: 'emergency_response',
    emergencyCaseField: 'emergency_case_id',
    panel: 'responses',
    action: 'add_response'
  },
  ambulances: {
    model: 'ambulance',
    ambulanceField: 'id',
    panel: 'ambulance',
    action: 'view_fleet'
  },
  'ambulance-dispatches': {
    model: 'ambulance_dispatch',
    emergencyCaseField: 'emergency_case_id',
    ambulanceField: 'ambulance_id',
    panel: 'dispatch',
    action: 'manage_dispatch'
  },
  'ambulance-trips': {
    model: 'ambulance_trip',
    emergencyCaseField: 'emergency_case_id',
    ambulanceField: 'ambulance_id',
    panel: 'trips',
    action: 'manage_trip'
  }
});

const PROVIDER_PROFILE_SELECT = {
  first_name: true,
  middle_name: true,
  last_name: true
};

const PROVIDER_STAFF_PROFILE_SELECT = {
  id: true,
  human_friendly_id: true,
  staff_number: true,
  position: true,
  practitioner_type: true,
  consultation_fee: true,
  consultation_currency: true,
  deleted_at: true
};

const PROVIDER_SELECT = {
  id: true,
  human_friendly_id: true,
  tenant_id: true,
  facility_id: true,
  email: true,
  phone: true,
  status: true,
  created_at: true,
  updated_at: true,
  deleted_at: true,
  version: true,
  profile: {
    select: PROVIDER_PROFILE_SELECT
  },
  staff_profile: {
    select: PROVIDER_STAFF_PROFILE_SELECT
  }
};

const PROVIDER_INCLUDE = {
  select: PROVIDER_SELECT
};

const TRIAGE_ALIAS_MAP = {
  IMMEDIATE: 'LEVEL_1',
  URGENT: 'LEVEL_2',
  LESS_URGENT: 'LEVEL_3',
  NON_URGENT: 'LEVEL_4',
  LEVEL_1: 'LEVEL_1',
  LEVEL_2: 'LEVEL_2',
  LEVEL_3: 'LEVEL_3',
  LEVEL_4: 'LEVEL_4',
  LEVEL_5: 'LEVEL_5'
};

const normalizeIdentifier = (value) => (typeof value === 'string' ? value.trim() : '');
const normalizeNotes = (value) => {
  const normalized = typeof value === 'string' ? value.trim() : '';
  return normalized || null;
};
const buildOpdFlowJsonFilter = (jsonPath, equalsValue) => ({
  path: jsonPath,
  equals: equalsValue
});
const buildOpdFlowStagePresenceClause = () => ({
  OR: Object.values(STAGES).map((stage) => ({
    extension_json: buildOpdFlowJsonFilter(OPD_FLOW_STAGE_JSON_PATH, stage)
  }))
});

const stageCorrectionRequiresReason = (stageFrom, stageTo) => {
  if (TERMINAL_STAGES.has(stageTo)) return true;
  const fromIndex = WORKFLOW_STAGE_ORDER.indexOf(stageFrom);
  const toIndex = WORKFLOW_STAGE_ORDER.indexOf(stageTo);
  if (fromIndex < 0 || toIndex < 0) return true;
  return toIndex < fromIndex || Math.abs(toIndex - fromIndex) > 1;
};

const normalizeSearchTokens = (search) =>
  String(search || '')
    .trim()
    .split(/\s+/)
    .map((token) => token.trim())
    .filter(Boolean)
    .slice(0, MAX_OPD_SEARCH_TOKENS);

const isUuid = (value) => UUID_REGEX.test(normalizeIdentifier(value));
const toPublicIdentifier = (value) => {
  const normalized = normalizeIdentifier(value);
  if (!normalized || isUuid(normalized)) return null;
  return normalized;
};

const resolveTenantByIdentifier = async (tx, identifier) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) return null;
  if (!tx?.tenant?.findFirst) {
    return null;
  }

  return tx.tenant.findFirst({
    where: {
      deleted_at: null,
      OR: isUuid(normalized) ? [{ id: normalized }] : [{ human_friendly_id: normalized.toUpperCase() }]
    }
  });
};

const resolveFacilityByIdentifier = async (tx, identifier, tenantId = null) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) return null;
  if (!tx?.facility?.findFirst) {
    return null;
  }

  return tx.facility.findFirst({
    where: {
      deleted_at: null,
      ...(tenantId ? { tenant_id: tenantId } : {}),
      OR: isUuid(normalized) ? [{ id: normalized }] : [{ human_friendly_id: normalized.toUpperCase() }]
    }
  });
};

const resolveEntityByIdentifier = async (tx, modelName, identifier, where = {}) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) return null;
  const delegate = tx?.[modelName];
  if (!delegate?.findFirst) {
    return null;
  }

  return delegate.findFirst({
    where: {
      deleted_at: null,
      ...where,
      OR: isUuid(normalized) ? [{ id: normalized }] : [{ human_friendly_id: normalized.toUpperCase() }]
    }
  });
};

const resolvePatientLookupWhere = (identifier, tenantId = null) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) return null;

  const where = {
    deleted_at: null,
    ...(tenantId ? { tenant_id: tenantId } : {})
  };

  if (isUuid(normalized)) {
    return {
      ...where,
      id: normalized
    };
  }

  return {
    ...where,
    human_friendly_id: normalized.toUpperCase()
  };
};

const resolvePatientByIdentifier = async (tx, identifier, tenantId = null) => {
  const where = resolvePatientLookupWhere(identifier, tenantId);
  if (!where) return null;
  if (!tx?.patient?.findFirst) {
    return null;
  }

  return tx.patient.findFirst({ where });
};

const resolveUserLookupWhere = (identifier, tenantId = null, facilityId = null) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) return null;

  const where = {
    deleted_at: null,
    ...(tenantId ? { tenant_id: tenantId } : {})
  };

  if (facilityId) {
    where.OR = [{ facility_id: facilityId }, { facility_id: null }];
  }

  if (isUuid(normalized)) {
    return {
      ...where,
      id: normalized
    };
  }

  const upper = normalized.toUpperCase();
  return {
    ...where,
    AND: [
      ...(Array.isArray(where.OR) ? [{ OR: where.OR }] : []),
      {
        OR: [
          { human_friendly_id: upper },
          { email: normalized },
          { phone: normalized },
          { profile: { first_name: { contains: normalized } } },
          { profile: { middle_name: { contains: normalized } } },
          { profile: { last_name: { contains: normalized } } },
          { staff_profile: { human_friendly_id: { contains: upper } } },
          { staff_profile: { staff_number: { contains: normalized } } },
          { staff_profile: { position: { contains: normalized } } },
          { staff_profile: { practitioner_type: { contains: upper } } }
        ]
      }
    ]
  };
};

const resolveProviderByIdentifier = async (tx, identifier, tenantId = null, facilityId = null) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) return null;
  if (!tx?.user?.findFirst) {
    return null;
  }

  const facilityScopedWhere = resolveUserLookupWhere(identifier, tenantId, facilityId);
  if (!facilityScopedWhere) return null;

  const facilityScopedProvider = await tx.user.findFirst({
    where: facilityScopedWhere,
    select: PROVIDER_SELECT
  });
  if (facilityScopedProvider || !facilityId) {
    return facilityScopedProvider;
  }

  const tenantScopedWhere = resolveUserLookupWhere(identifier, tenantId, null);
  if (!tenantScopedWhere) return null;

  return tx.user.findFirst({
    where: tenantScopedWhere,
    select: PROVIDER_SELECT
  });
};

const resolveAppointmentByIdentifier = async (tx, identifier, tenantId = null, facilityId = null) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) return null;
  if (!tx?.appointment?.findFirst) return null;

  const where = {
    deleted_at: null,
    ...(tenantId ? { tenant_id: tenantId } : {}),
    ...(facilityId ? { facility_id: facilityId } : {})
  };

  if (isUuid(normalized)) {
    return tx.appointment.findFirst({
      where: {
        ...where,
        id: normalized
      }
    });
  }

  return tx.appointment.findFirst({
    where: {
      ...where,
      human_friendly_id: normalized.toUpperCase()
    }
  });
};

const resolveVisitQueueByIdentifier = async (tx, identifier, tenantId = null, facilityId = null) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) return null;
  if (!tx?.visit_queue?.findFirst) return null;

  const where = {
    deleted_at: null,
    ...(tenantId ? { tenant_id: tenantId } : {}),
    ...(facilityId ? { facility_id: facilityId } : {})
  };

  if (isUuid(normalized)) {
    return tx.visit_queue.findFirst({
      where: {
        ...where,
        id: normalized
      }
    });
  }

  return tx.visit_queue.findFirst({
    where: {
      ...where,
      human_friendly_id: normalized.toUpperCase()
    }
  });
};

const resolveEncounterByIdentifier = async (tx, identifier, options = {}) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) return null;
  if (!tx?.encounter?.findFirst) return null;
  const include = options?.include || undefined;
  return tx.encounter.findFirst({
    where: {
      OR: [{ id: normalized }, { human_friendly_id: normalized.toUpperCase() }],
      deleted_at: null,
      encounter_type: { in: ['OPD', 'EMERGENCY'] }
    },
    ...(include ? { include } : {})
  });
};

const resolveOpenEncounterForPatient = async (
  tx,
  { tenantId, patientId, encounterTypes = ACTIVE_OPD_ENCOUNTER_TYPES }
) => {
  return opdFlowRepository.findOpenActiveEncounterForPatient(
    {
      tenantId,
      patientId,
      encounterTypes
    },
    tx
  );
};

const throwIfPatientHasOpenEncounter = async (tx, { tenantId, patientId }) => {
  const existing = await resolveOpenEncounterForPatient(tx, {
    tenantId,
    patientId,
    encounterTypes: ACTIVE_OPD_ENCOUNTER_TYPES
  });

  if (!existing) {
    return;
  }

  throw new HttpError('errors.opd_flow.active_encounter_exists', 409, [
    {
      field: 'patient_id',
      encounter_id: existing.human_friendly_id || existing.id,
      encounter_type: existing.encounter_type,
      stage: existing.extension_json?.opd_flow?.stage || null
    }
  ]);
};

const NEXT_STEP_BY_STAGE = {
  [STAGES.WAITING_CONSULTATION_PAYMENT]: 'PAY_CONSULTATION',
  [STAGES.WAITING_VITALS]: 'RECORD_VITALS',
  [STAGES.WAITING_DOCTOR_ASSIGNMENT]: 'ASSIGN_DOCTOR',
  [STAGES.WAITING_DOCTOR_REVIEW]: 'DOCTOR_REVIEW',
  [STAGES.WAITING_DISPOSITION]: 'DISPOSITION',
  [STAGES.LAB_REQUESTED]: 'DISPOSITION',
  [STAGES.RADIOLOGY_REQUESTED]: 'DISPOSITION',
  [STAGES.LAB_AND_RADIOLOGY_REQUESTED]: 'DISPOSITION',
  [STAGES.PHARMACY_REQUESTED]: 'DISPOSITION',
  [STAGES.ADMITTED]: null,
  [STAGES.DISCHARGED]: null
};

const STAGE_ROLE_TEAM_MAP = {
  [STAGES.WAITING_CONSULTATION_PAYMENT]: [ROLES.RECEPTIONIST, ROLES.BILLING],
  [STAGES.WAITING_VITALS]: [ROLES.NURSE],
  [STAGES.WAITING_DOCTOR_ASSIGNMENT]: [ROLES.RECEPTIONIST, ROLES.NURSE],
  [STAGES.WAITING_DOCTOR_REVIEW]: [ROLES.DOCTOR],
  [STAGES.LAB_REQUESTED]: [ROLES.LAB_TECH],
  [STAGES.RADIOLOGY_REQUESTED]: [ROLES.RADIOLOGY_TECH],
  [STAGES.LAB_AND_RADIOLOGY_REQUESTED]: [ROLES.LAB_TECH, ROLES.RADIOLOGY_TECH],
  [STAGES.PHARMACY_REQUESTED]: [ROLES.PHARMACIST],
  [STAGES.WAITING_DISPOSITION]: [ROLES.DOCTOR],
  [STAGES.ADMITTED]: [ROLES.RECEPTIONIST, ROLES.OPERATIONS],
  [STAGES.DISCHARGED]: [ROLES.RECEPTIONIST, ROLES.OPERATIONS]
};

const formatStageLabel = (stage) =>
  String(stage || 'UPDATED')
    .trim()
    .replace(/_/g, ' ')
    .toLowerCase();

const buildFlowSummary = (snapshot) => {
  const flow = snapshot?.flow || {};
  const timeline = Array.isArray(flow.timeline)
    ? flow.timeline
    : Array.isArray(snapshot?.timeline)
      ? snapshot.timeline
      : [];

  return {
    stage: flow.stage || null,
    next_step: flow.next_step || null,
    encounter_type: snapshot?.encounter?.encounter_type || null,
    timeline_count: timeline.length
  };
};

const buildRealtimePayload = ({ snapshot, transition, context }) => {
  const encounterPublicId = snapshot?.encounter?.human_friendly_id || null;
  const providerPublicId = snapshot?.encounter?.provider?.human_friendly_id || null;
  const patientPublicId = snapshot?.encounter?.patient?.human_friendly_id || null;
  const tenantPublicId = snapshot?.encounter?.tenant?.human_friendly_id || null;
  const facilityPublicId = snapshot?.encounter?.facility?.human_friendly_id || null;
  const providerInternalId = snapshot?.encounter?.provider_user_id || transition?.provider_user_id || null;
  const actorInternalId = context?.user_id || null;
  const stageTo = transition?.stage_to || snapshot?.flow?.stage || null;
  const stageFrom = transition?.stage_from || null;
  const occurredAt =
    transition?.occurred_at || snapshot?.encounter?.updated_at?.toISOString?.() || new Date().toISOString();

  return {
    encounter_id: encounterPublicId || snapshot?.encounter?.id || null,
    encounter_public_id: encounterPublicId,
    tenant_id: tenantPublicId,
    facility_id: facilityPublicId,
    tenant_internal_id: snapshot?.encounter?.tenant_id || context?.tenant_id || null,
    facility_internal_id: snapshot?.encounter?.facility_id || context?.facility_id || null,
    patient_id: patientPublicId,
    provider_user_id: providerPublicId,
    stage_from: stageFrom,
    stage_to: stageTo,
    next_step: snapshot?.flow?.next_step || null,
    action: transition?.action || 'OPD_FLOW_UPDATED',
    actor_user_id: actorInternalId,
    provider_internal_user_id: providerInternalId,
    actor_internal_user_id: actorInternalId,
    occurred_at: occurredAt,
    flow_summary: buildFlowSummary(snapshot),
    target_path: encounterPublicId ? `/scheduling/opd-flows/${encounterPublicId}` : '/scheduling/opd-flows'
  };
};

const buildOpdNotificationContent = (payload) => {
  const stageLabel = formatStageLabel(payload?.stage_to || payload?.flow_summary?.stage);
  const title = `OPD flow update: ${stageLabel}`;
  const message = `Encounter ${payload.encounter_public_id || 'unknown'} is now ${stageLabel}.`;

  return {
    title,
    message
  };
};

const resolveRoleRecipients = async ({ tenantId, facilityId, roles = [] }) => {
  if (!tenantId || !Array.isArray(roles) || roles.length === 0) {
    return [];
  }

  if (!prisma?.user_role?.findMany) {
    return [];
  }

  const where = {
    tenant_id: tenantId,
    deleted_at: null,
    role: {
      deleted_at: null,
      name: { in: roles }
    }
  };

  if (facilityId) {
    where.OR = [{ facility_id: facilityId }, { facility_id: null }];
  }

  const rows = await prisma.user_role.findMany({
    where,
    select: { user_id: true }
  });

  return rows.map((row) => row.user_id).filter(Boolean);
};

const resolveOpdRecipientUserIds = async ({ payload }) => {
  const roleTeams = STAGE_ROLE_TEAM_MAP[payload.stage_to] || [];
  const roleRecipients = await resolveRoleRecipients({
    tenantId: payload.tenant_internal_id,
    facilityId: payload.facility_internal_id,
    roles: roleTeams
  });

  const recipientSet = new Set(roleRecipients);
  if (payload.provider_internal_user_id) {
    recipientSet.add(payload.provider_internal_user_id);
  }
  if (payload.actor_internal_user_id) {
    recipientSet.delete(payload.actor_internal_user_id);
  }

  return Array.from(recipientSet).filter(Boolean);
};

const toSafeNotificationPayload = (notification, targetPath) => ({
  id: notification.human_friendly_id || null,
  tenant_id: null,
  user_id: null,
  notification_type: notification.notification_type,
  priority: notification.priority,
  title: notification.title,
  message: notification.message,
  read_at: notification.read_at || null,
  created_at: notification.created_at,
  updated_at: notification.updated_at,
  target_path: targetPath
});

const createAndEmitOpdNotifications = async ({ payload, recipientUserIds }) => {
  if (!Array.isArray(recipientUserIds) || recipientUserIds.length === 0) {
    return [];
  }

  if (!prisma?.notification?.create) {
    return [];
  }

  const priority = payload?.flow_summary?.encounter_type === 'EMERGENCY' ? 'HIGH' : 'MEDIUM';
  const { title, message } = buildOpdNotificationContent(payload);

  const createdNotifications = [];

  for (const userId of recipientUserIds) {
    // Keep notification creation resilient and non-blocking per user.
    try {
      const notification = await prisma.notification.create({
        data: {
          tenant_id: payload.tenant_internal_id,
          user_id: userId,
          notification_type: 'SYSTEM',
          priority,
          title,
          message
        }
      });
      createdNotifications.push(notification);
    } catch (_err) {
      // Notification creation should not block OPD flow progression.
    }
  }

  if (createdNotifications.length > 0 && prisma?.notification_delivery?.createMany) {
    try {
      await prisma.notification_delivery.createMany({
        data: createdNotifications.map((notification) => ({
          notification_id: notification.id,
          channel: 'IN_APP',
          status: 'SENT',
          sent_at: new Date()
        }))
      });
    } catch (_err) {
      // Delivery metadata failure should not block clinical flow.
    }
  }

  createdNotifications.forEach((notification) => {
    emitToUser(notification.user_id, NOTIFICATION_EVENTS.NOTIFICATION_CREATED, {
      notification: toSafeNotificationPayload(notification, payload.target_path),
      target_path: payload.target_path
    });
  });

  return createdNotifications;
};

const publishOpdRealtimeUpdates = async ({ snapshot, transition, context }) => {
  try {
    const payload = buildRealtimePayload({
      snapshot,
      transition,
      context
    });
    const recipientUserIds = await resolveOpdRecipientUserIds({ payload });
    if (recipientUserIds.length > 0) {
      emitToUsers(recipientUserIds, OPD_EVENTS.OPD_FLOW_UPDATED, payload);
      await createAndEmitOpdNotifications({ payload, recipientUserIds });
    }
  } catch (_err) {
    // Realtime updates must never fail the OPD transaction response path.
  }
};

const toDecimalNumber = (value) => {
  if (value === null || value === undefined) return 0;
  if (typeof value === 'number') return value;
  if (typeof value === 'string') return Number(value);
  if (typeof value.toNumber === 'function') return value.toNumber();
  if (typeof value.toString === 'function') return Number(value.toString());
  return Number(value);
};

const normalizeDecimalString = (value, fallback = '0.00') => {
  if (value === null || value === undefined || value === '') {
    return fallback;
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value.toString === 'function') {
    return value.toString();
  }
  return String(value);
};

const normalizeCurrencyCode = (value, fallback = null) => {
  const normalized = normalizeIdentifier(value).toUpperCase();
  return normalized || fallback;
};

const normalizeUpper = (value) => normalizeIdentifier(value).toUpperCase();

const uniqueNormalizedIdentifiers = (values = []) =>
  Array.from(new Set(values.map((value) => normalizeIdentifier(value)).filter(Boolean)));

const lookupIdentifierKeys = (value) => {
  const normalized = normalizeIdentifier(value);
  if (!normalized) return [];
  const upper = normalized.toUpperCase();
  return normalized === upper ? [normalized] : [normalized, upper];
};

const setLookupRecord = (target, identifier, record) => {
  for (const key of lookupIdentifierKeys(identifier)) {
    target.set(key, record);
  }
};

const getLookupRecord = (source, identifier) => {
  for (const key of lookupIdentifierKeys(identifier)) {
    if (source.has(key)) return source.get(key);
  }
  return null;
};

const positiveDecimalStringOrNull = (value) => {
  const amount = toDecimalNumber(value);
  if (!Number.isFinite(amount) || amount <= 0) return null;
  return normalizeDecimalString(value, amount.toFixed(2));
};

const sumPaidPayments = (payments = []) => {
  const total = (Array.isArray(payments) ? payments : []).reduce((sum, payment) => {
    if (!payment || payment.deleted_at) return sum;
    if (!PAID_PAYMENT_STATUSES.has(normalizeUpper(payment.status))) return sum;
    return sum + toDecimalNumber(payment.amount);
  }, 0);
  return total > 0 ? total.toFixed(2) : null;
};

const resolveConsultationPaymentAmount = ({ consultation = {}, invoice = null, payment = null } = {}) => {
  const directAmount = positiveDecimalStringOrNull(
    consultation.paid_amount || consultation.payment_amount || consultation.amount_paid
  );
  if (directAmount) return directAmount;

  if (payment && PAID_PAYMENT_STATUSES.has(normalizeUpper(payment.status))) {
    const paymentAmount = positiveDecimalStringOrNull(payment.amount);
    if (paymentAmount) return paymentAmount;
  }

  const invoicePaymentAmount = sumPaidPayments(invoice?.payments);
  if (invoicePaymentAmount) return invoicePaymentAmount;

  const consultationIsPaid =
    consultation.is_paid === true ||
    consultation.paid === true ||
    PAID_PAYMENT_STATUSES.has(normalizeUpper(consultation.payment_status));
  const invoiceIsPaid =
    PAID_BILLING_STATUSES.has(normalizeUpper(invoice?.billing_status)) ||
    PAID_BILLING_STATUSES.has(normalizeUpper(invoice?.status));

  if (consultationIsPaid || invoiceIsPaid) {
    return positiveDecimalStringOrNull(invoice?.total_amount);
  }

  return null;
};

const resolveConsultationFeeAmount = (consultation = {}, invoice = null) => {
  return (
    positiveDecimalStringOrNull(consultation.consultation_fee) ||
    positiveDecimalStringOrNull(consultation.fee) ||
    positiveDecimalStringOrNull(invoice?.total_amount) ||
    normalizeDecimalString(consultation.consultation_fee, null)
  );
};

const resolveConsultationPaymentStatus = ({ consultation = {}, invoice = null, payment = null } = {}) => {
  return (
    payment?.status ||
    consultation.payment_status ||
    invoice?.billing_status ||
    invoice?.status ||
    (consultation.is_paid ? 'COMPLETED' : consultation.require_payment ? 'PENDING' : 'NOT_REQUIRED')
  );
};

const enrichConsultationBillingForListItems = async (items = []) => {
  const invoiceIdentifiers = uniqueNormalizedIdentifiers(items.map((item) => item?.flow?.consultation?.invoice_id));
  const paymentIdentifiers = uniqueNormalizedIdentifiers(items.map((item) => item?.flow?.consultation?.payment_id));

  if (invoiceIdentifiers.length === 0 && paymentIdentifiers.length === 0) {
    return items;
  }

  const [invoices, payments] = await Promise.all([
    invoiceIdentifiers.length > 0 && typeof prisma.invoice?.findMany === 'function'
      ? prisma.invoice.findMany({
          where: {
            deleted_at: null,
            OR: [
              { id: { in: invoiceIdentifiers } },
              {
                human_friendly_id: {
                  in: invoiceIdentifiers.flatMap(lookupIdentifierKeys)
                }
              }
            ]
          },
          include: {
            payments: {
              where: { deleted_at: null },
              orderBy: { created_at: 'desc' }
            }
          }
        })
      : [],
    paymentIdentifiers.length > 0 && typeof prisma.payment?.findMany === 'function'
      ? prisma.payment.findMany({
          where: {
            deleted_at: null,
            OR: [
              { id: { in: paymentIdentifiers } },
              {
                human_friendly_id: {
                  in: paymentIdentifiers.flatMap(lookupIdentifierKeys)
                }
              }
            ]
          },
          include: {
            invoice: {
              include: {
                payments: {
                  where: { deleted_at: null },
                  orderBy: { created_at: 'desc' }
                }
              }
            }
          }
        })
      : []
  ]);

  const invoiceByIdentifier = new Map();
  for (const invoice of invoices) {
    setLookupRecord(invoiceByIdentifier, invoice?.id, invoice);
    setLookupRecord(invoiceByIdentifier, invoice?.human_friendly_id, invoice);
  }

  const paymentByIdentifier = new Map();
  for (const payment of payments) {
    setLookupRecord(paymentByIdentifier, payment?.id, payment);
    setLookupRecord(paymentByIdentifier, payment?.human_friendly_id, payment);
  }

  return items.map((item) => {
    const flow = item?.flow || null;
    const consultation = flow?.consultation || {};
    const payment = getLookupRecord(paymentByIdentifier, consultation.payment_id);
    const invoice = getLookupRecord(invoiceByIdentifier, consultation.invoice_id) || payment?.invoice || null;
    if (
      !flow ||
      (!invoice && !payment && !consultation.paid_amount && !consultation.payment_amount && !consultation.amount_paid)
    ) {
      return item;
    }

    return {
      ...item,
      flow: {
        ...flow,
        consultation: {
          ...consultation,
          consultation_fee: resolveConsultationFeeAmount(consultation, invoice),
          paid_amount: resolveConsultationPaymentAmount({
            consultation,
            invoice,
            payment
          }),
          currency: consultation.currency || invoice?.currency || null,
          invoice_id: invoice?.human_friendly_id || consultation.invoice_id || null,
          payment_id: payment?.human_friendly_id || consultation.payment_id || null,
          payment_status: resolveConsultationPaymentStatus({
            consultation,
            invoice,
            payment
          })
        }
      }
    };
  });
};

const resolveCurrencyFromExtension = (extensionJson) => {
  if (!extensionJson || typeof extensionJson !== 'object' || Array.isArray(extensionJson)) return null;

  const directCandidates = [extensionJson.currency, extensionJson.default_currency, extensionJson.defaultCurrency];
  const nestedCandidates = [
    extensionJson.settings?.currency,
    extensionJson.settings?.default_currency,
    extensionJson.settings?.defaultCurrency,
    extensionJson.billing?.currency,
    extensionJson.billing?.default_currency,
    extensionJson.billing?.defaultCurrency,
    extensionJson.preferences?.currency,
    extensionJson.preferences?.default_currency,
    extensionJson.preferences?.defaultCurrency
  ];

  const matched = [...directCandidates, ...nestedCandidates].find(
    (candidate) => typeof candidate === 'string' && candidate.trim()
  );

  return normalizeCurrencyCode(matched, null);
};

const resolveDefaultCurrency = async (tx, tenantId, facilityId = null) => {
  let facilityCurrency = null;
  if (facilityId && tx?.facility?.findFirst) {
    const facility = await tx.facility.findFirst({
      where: { id: facilityId, deleted_at: null },
      select: { extension_json: true }
    });
    facilityCurrency = resolveCurrencyFromExtension(facility?.extension_json);
  }

  if (facilityCurrency) return facilityCurrency;

  if (tenantId && tx?.tenant?.findFirst) {
    const tenant = await tx.tenant.findFirst({
      where: { id: tenantId, deleted_at: null },
      select: { extension_json: true }
    });
    const tenantCurrency = resolveCurrencyFromExtension(tenant?.extension_json);
    if (tenantCurrency) return tenantCurrency;
  }

  return 'USD';
};

const resolveProviderConsultationDefaults = (provider) => {
  const profile = provider?.staff_profile || null;
  if (!profile || profile.deleted_at) {
    return {
      consultationFee: null,
      consultationCurrency: null
    };
  }

  const practitionerType = normalizeIdentifier(profile.practitioner_type).toUpperCase();
  if (practitionerType !== 'SPECIALIST') {
    return {
      consultationFee: null,
      consultationCurrency: null
    };
  }

  return {
    consultationFee: normalizeDecimalString(profile.consultation_fee, null),
    consultationCurrency: normalizeCurrencyCode(profile.consultation_currency, null)
  };
};

const toFiniteNumber = (value) => {
  if (value === null || value === undefined) return null;
  if (typeof value === 'number') {
    return Number.isFinite(value) ? value : null;
  }
  if (typeof value === 'string') {
    const parsed = Number(value.trim());
    return Number.isFinite(parsed) ? parsed : null;
  }
  if (typeof value?.toNumber === 'function') {
    const parsed = value.toNumber();
    return Number.isFinite(parsed) ? parsed : null;
  }
  if (typeof value?.toString === 'function') {
    const parsed = Number(value.toString());
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
};

const roundToTwo = (value) => {
  if (!Number.isFinite(value)) return null;
  return Math.round(value * 100) / 100;
};

const formatBloodPressureValueComponent = (value) => {
  const rounded = roundToTwo(value);
  if (!Number.isFinite(rounded)) return '';
  return Number.isInteger(rounded) ? String(rounded) : String(rounded);
};

const parseLegacyBloodPressureValue = (value) => {
  const match = String(value || '')
    .trim()
    .match(BLOOD_PRESSURE_VALUE_REGEX);
  if (!match) return null;

  const systolic = roundToTwo(toFiniteNumber(match[1]));
  const diastolic = roundToTwo(toFiniteNumber(match[2]));

  if (!Number.isFinite(systolic) || !Number.isFinite(diastolic)) {
    return null;
  }

  return { systolic, diastolic };
};

const computeMeanArterialPressure = (systolic, diastolic) => {
  if (!Number.isFinite(systolic) || !Number.isFinite(diastolic)) return null;
  return roundToTwo((systolic + 2 * diastolic) / 3);
};

const normalizeBloodPressureVital = (vital) => {
  const parsedLegacy = parseLegacyBloodPressureValue(vital.value);
  const systolic = roundToTwo(toFiniteNumber(vital.systolic_value)) ?? parsedLegacy?.systolic ?? null;
  const diastolic = roundToTwo(toFiniteNumber(vital.diastolic_value)) ?? parsedLegacy?.diastolic ?? null;

  if (!Number.isFinite(systolic) || !Number.isFinite(diastolic)) {
    throw new HttpError('errors.validation.required', 400, [{ field: 'systolic_value' }, { field: 'diastolic_value' }]);
  }

  const mapValue = roundToTwo(toFiniteNumber(vital.map_value)) ?? computeMeanArterialPressure(systolic, diastolic);
  const canonicalValue = `${formatBloodPressureValueComponent(systolic)}/${formatBloodPressureValueComponent(diastolic)}`;

  return {
    value: canonicalValue,
    systolic_value: systolic,
    diastolic_value: diastolic,
    map_value: mapValue
  };
};

const normalizeVitalForPersistence = (vital) => {
  const vitalType = String(vital?.vital_type || '')
    .trim()
    .toUpperCase();
  if (vitalType === 'BLOOD_PRESSURE') {
    const normalizedBp = normalizeBloodPressureVital(vital);
    return {
      vital_type: vitalType,
      value: normalizedBp.value,
      systolic_value: normalizedBp.systolic_value,
      diastolic_value: normalizedBp.diastolic_value,
      map_value: normalizedBp.map_value
    };
  }

  return {
    vital_type: vitalType,
    value: String(vital?.value || '').trim(),
    systolic_value: null,
    diastolic_value: null,
    map_value: null
  };
};

const deriveArrivalMode = (data, appointment) => {
  if (data.arrival_mode) return data.arrival_mode;
  if (data.emergency) return 'EMERGENCY';
  if (appointment || data.appointment_id) return 'ONLINE_APPOINTMENT';
  return 'WALK_IN';
};

const mapTriageLevel = (triageLevel) => {
  if (!triageLevel) return null;
  return TRIAGE_ALIAS_MAP[triageLevel] || null;
};

const TRIAGE_PRIORITY_RANK = Object.freeze({
  LEVEL_1: 0,
  LEVEL_2: 1,
  LEVEL_3: 2,
  LEVEL_4: 3,
  LEVEL_5: 4
});

const resolveTriagePriorityRank = (triageLevel) => {
  const mapped = mapTriageLevel(triageLevel);
  if (!mapped) return 99;
  return Number.isInteger(TRIAGE_PRIORITY_RANK[mapped]) ? TRIAGE_PRIORITY_RANK[mapped] : 99;
};

const toTimestamp = (value) => {
  const parsed = new Date(value || '');
  if (Number.isNaN(parsed.getTime())) return Number.MAX_SAFE_INTEGER;
  return parsed.getTime();
};

const resolveEmergencyQueueTimestamp = (item) => {
  const flow = item?.flow || {};
  const encounter = item?.encounter || {};
  return toTimestamp(flow.queued_at || encounter.started_at || encounter.created_at);
};

const enrichEmergencyQueueUrgency = async (items = []) => {
  if (!Array.isArray(items) || items.length === 0) return items;
  if (!prisma?.triage_assessment?.findMany) return items;

  const emergencyCaseIds = Array.from(
    new Set(items.map((item) => normalizeIdentifier(item?.flow?.emergency_case_id)).filter(Boolean))
  );

  if (emergencyCaseIds.length === 0) {
    return items.map((item) => ({
      ...item,
      flow: {
        ...(item?.flow || {}),
        triage_level: null,
        triage_priority_rank: 99
      }
    }));
  }

  const triageRows = await prisma.triage_assessment.findMany({
    where: {
      deleted_at: null,
      emergency_case_id: { in: emergencyCaseIds }
    },
    select: {
      emergency_case_id: true,
      triage_level: true,
      created_at: true
    },
    orderBy: [{ created_at: 'desc' }]
  });

  const triageByEmergencyCaseId = new Map();
  for (const row of triageRows || []) {
    const emergencyCaseId = normalizeIdentifier(row?.emergency_case_id);
    if (!emergencyCaseId || triageByEmergencyCaseId.has(emergencyCaseId)) continue;
    triageByEmergencyCaseId.set(emergencyCaseId, mapTriageLevel(row?.triage_level));
  }

  return items.map((item) => {
    const flow = item?.flow || {};
    const emergencyCaseId = normalizeIdentifier(flow?.emergency_case_id);
    const triageLevel = triageByEmergencyCaseId.get(emergencyCaseId) || null;
    return {
      ...item,
      flow: {
        ...flow,
        triage_level: triageLevel,
        triage_priority_rank: resolveTriagePriorityRank(triageLevel)
      }
    };
  });
};

const sortEmergencyQueueItems = (items = []) =>
  [...items].sort((left, right) => {
    const leftRank = resolveTriagePriorityRank(left?.flow?.triage_level);
    const rightRank = resolveTriagePriorityRank(right?.flow?.triage_level);
    if (leftRank !== rightRank) return leftRank - rightRank;

    const leftQueuedAt = resolveEmergencyQueueTimestamp(left);
    const rightQueuedAt = resolveEmergencyQueueTimestamp(right);
    if (leftQueuedAt !== rightQueuedAt) return leftQueuedAt - rightQueuedAt;

    const leftStartedAt = toTimestamp(left?.encounter?.started_at);
    const rightStartedAt = toTimestamp(right?.encounter?.started_at);
    if (leftStartedAt !== rightStartedAt) return leftStartedAt - rightStartedAt;

    const leftId = normalizeIdentifier(left?.encounter?.id);
    const rightId = normalizeIdentifier(right?.encounter?.id);
    return leftId.localeCompare(rightId);
  });

const getOpdFlowState = (encounter) => {
  const opdFlow = encounter?.extension_json?.opd_flow;
  if (!opdFlow) {
    throw new HttpError('errors.opd_flow.not_found', 404);
  }
  return opdFlow;
};

const getNextStep = (stage) => NEXT_STEP_BY_STAGE[stage] || null;

const appendTimelineEvent = (flow, event, context = {}, details = {}, at = new Date()) => {
  if (!Array.isArray(flow.timeline)) {
    flow.timeline = [];
  }

  flow.timeline.push({
    event,
    at: at.toISOString(),
    by_user_id: context.user_id || null,
    details
  });
};

const setFlowStage = (flow, stage) => {
  flow.stage = stage;
  flow.next_step = getNextStep(stage);
};

const ensureNonTerminalStage = (flow) => {
  if (TERMINAL_STAGES.has(flow.stage)) {
    throw new HttpError('errors.opd_flow.already_terminal', 400);
  }
};

const buildEncounterSearchTokenClause = (token) => {
  const term = String(token || '').trim();
  const upper = term.toUpperCase();

  return {
    OR: [
      { human_friendly_id: { contains: upper } },
      { patient: { first_name: { contains: term } } },
      { patient: { last_name: { contains: term } } },
      { patient: { human_friendly_id: { contains: upper } } },
      {
        patient: {
          identifiers: {
            some: {
              deleted_at: null,
              OR: [
                { human_friendly_id: { contains: upper } },
                { identifier_type: { contains: term } },
                { identifier_value: { contains: term } }
              ]
            }
          }
        }
      },
      {
        patient: {
          contacts: {
            some: {
              deleted_at: null,
              OR: [{ human_friendly_id: { contains: upper } }, { value: { contains: term } }]
            }
          }
        }
      },
      {
        patient: {
          guardians: {
            some: {
              deleted_at: null,
              OR: [
                { human_friendly_id: { contains: upper } },
                { name: { contains: term } },
                { relationship: { contains: term } },
                { phone: { contains: term } },
                { email: { contains: term } }
              ]
            }
          }
        }
      },
      { provider: { email: { contains: term } } },
      { provider: { phone: { contains: term } } },
      { provider: { human_friendly_id: { contains: upper } } },
      { provider: { profile: { first_name: { contains: term } } } },
      { provider: { profile: { last_name: { contains: term } } } },
      { provider: { profile: { middle_name: { contains: term } } } },
      { provider: { staff_profile: { staff_number: { contains: term } } } },
      {
        provider: { staff_profile: { practitioner_type: { contains: upper } } }
      },
      { provider: { staff_profile: { position: { contains: term } } } }
    ]
  };
};

const buildEncounterWhereClause = (filters = {}) => {
  const where = {
    encounter_type: { in: ['OPD', 'EMERGENCY'] }
  };
  const andClauses = [];

  if (filters.tenant_id) where.tenant_id = filters.tenant_id;
  if (filters.facility_id) where.facility_id = filters.facility_id;
  if (filters.patient_id) where.patient_id = filters.patient_id;
  if (filters.provider_user_id) where.provider_user_id = filters.provider_user_id;
  if (filters.encounter_type) where.encounter_type = filters.encounter_type;
  if (filters.stage) {
    where.extension_json = buildOpdFlowJsonFilter(OPD_FLOW_STAGE_JSON_PATH, filters.stage);
  } else {
    andClauses.push(buildOpdFlowStagePresenceClause());
  }

  const requestedStage = normalizeIdentifier(filters.stage).toUpperCase();
  if (!TERMINAL_STAGES.has(requestedStage)) {
    andClauses.push({ status: 'OPEN' });
  }

  const queueScope = String(filters.queue_scope || QUEUE_SCOPES.ALL)
    .trim()
    .toUpperCase();
  if (queueScope === QUEUE_SCOPES.ASSIGNED) {
    andClauses.push({ status: 'OPEN' });
    if (!filters.provider_user_id) {
      andClauses.push({ provider_user_id: { not: null } });
    }
  } else if (queueScope === QUEUE_SCOPES.WAITING) {
    andClauses.push(
      { status: 'OPEN' },
      { provider_user_id: null },
      {
        OR: WAITING_QUEUE_STAGES.map((stage) => ({
          extension_json: buildOpdFlowJsonFilter(OPD_FLOW_STAGE_JSON_PATH, stage)
        }))
      }
    );
  }

  const searchTokens = normalizeSearchTokens(filters.search);
  if (searchTokens.length > 0) {
    andClauses.push(...searchTokens.map(buildEncounterSearchTokenClause));
  }

  if (andClauses.length > 0) {
    where.AND = andClauses;
  }

  return where;
};

const resolveLegacyRoute = async (resource, id) => {
  const normalizedResource = normalizeIdentifier(resource).toLowerCase();
  const config = LEGACY_ROUTE_CONFIG[normalizedResource];
  if (!config) {
    throw new HttpError('errors.opd_flow.not_found', 404);
  }

  const normalizedIdentifier = normalizeIdentifier(id);
  if (!normalizedIdentifier) {
    throw new HttpError('errors.opd_flow.not_found', 404);
  }

  const delegate = prisma?.[config.model];
  if (!delegate || typeof delegate.findFirst !== 'function') {
    throw new HttpError('errors.opd_flow.not_found', 404);
  }

  const resolvedResource = await delegate.findFirst({
    where: {
      deleted_at: null,
      OR: isUuid(normalizedIdentifier)
        ? [{ id: normalizedIdentifier }]
        : [{ human_friendly_id: normalizedIdentifier.toUpperCase() }]
    },
    select: {
      id: true,
      human_friendly_id: true,
      ...(config.emergencyCaseField && config.emergencyCaseField !== 'id' ? { [config.emergencyCaseField]: true } : {}),
      ...(config.ambulanceField && config.ambulanceField !== 'id' ? { [config.ambulanceField]: true } : {})
    }
  });

  if (!resolvedResource) {
    throw new HttpError('errors.opd_flow.not_found', 404);
  }

  const emergencyCaseInternalId = config.emergencyCaseField
    ? config.emergencyCaseField === 'id'
      ? resolvedResource.id
      : resolvedResource[config.emergencyCaseField] || null
    : null;
  const ambulanceInternalId = config.ambulanceField
    ? config.ambulanceField === 'id'
      ? resolvedResource.id
      : resolvedResource[config.ambulanceField] || null
    : null;

  const [emergencyCase, ambulance] = await Promise.all([
    emergencyCaseInternalId
      ? prisma.emergency_case.findFirst({
          where: {
            id: emergencyCaseInternalId,
            deleted_at: null
          },
          select: {
            id: true,
            human_friendly_id: true
          }
        })
      : null,
    ambulanceInternalId
      ? prisma.ambulance.findFirst({
          where: {
            id: ambulanceInternalId,
            deleted_at: null
          },
          select: {
            id: true,
            human_friendly_id: true
          }
        })
      : null
  ]);

  const encounter = emergencyCaseInternalId
    ? await prisma.encounter.findFirst({
        where: {
          deleted_at: null,
          encounter_type: 'EMERGENCY',
          extension_json: buildOpdFlowJsonFilter(OPD_FLOW_EMERGENCY_CASE_ID_JSON_PATH, emergencyCaseInternalId)
        },
        orderBy: {
          started_at: 'desc'
        },
        select: {
          id: true,
          human_friendly_id: true
        }
      })
    : null;

  return {
    encounter_id: toPublicIdentifier(encounter?.human_friendly_id || encounter?.id) || null,
    emergency_case_id:
      toPublicIdentifier(
        emergencyCase?.human_friendly_id ||
          (config.emergencyCaseField === 'id' ? resolvedResource.human_friendly_id : null)
      ) || null,
    ambulance_id:
      toPublicIdentifier(
        ambulance?.human_friendly_id || (config.ambulanceField === 'id' ? resolvedResource.human_friendly_id : null)
      ) || null,
    resource: normalizedResource,
    resource_id: toPublicIdentifier(resolvedResource.human_friendly_id || normalizedIdentifier) || null,
    panel: config.panel,
    action: config.action
  };
};

const getOpdFlowById = async (id) => {
  const result = await prisma.$transaction(async (tx) => {
    const encounter = await resolveEncounterByIdentifier(tx, id, {
      include: {
        tenant: true,
        facility: true,
        patient: true,
        provider: PROVIDER_INCLUDE,
        vital_signs: {
          where: { deleted_at: null },
          orderBy: { recorded_at: 'asc' }
        },
        clinical_notes: {
          where: { deleted_at: null },
          orderBy: { created_at: 'asc' }
        },
        diagnoses: {
          where: { deleted_at: null },
          orderBy: { created_at: 'asc' }
        },
        procedures: {
          where: { deleted_at: null },
          orderBy: { created_at: 'asc' }
        },
        care_plans: {
          where: { deleted_at: null },
          orderBy: { created_at: 'asc' }
        },
        alerts: {
          where: { deleted_at: null },
          orderBy: { created_at: 'desc' }
        },
        referrals: {
          where: { deleted_at: null },
          orderBy: { created_at: 'desc' }
        },
        follow_ups: {
          where: { deleted_at: null },
          orderBy: { scheduled_at: 'asc' }
        },
        admissions: {
          where: { deleted_at: null },
          orderBy: { created_at: 'desc' }
        },
        lab_orders: {
          where: { deleted_at: null },
          orderBy: { created_at: 'desc' },
          include: {
            items: {
              where: { deleted_at: null }
            }
          }
        },
        radiology_orders: {
          where: { deleted_at: null },
          orderBy: { created_at: 'desc' }
        },
        pharmacy_orders: {
          where: { deleted_at: null },
          orderBy: { created_at: 'desc' },
          include: {
            items: { where: { deleted_at: null } }
          }
        }
      }
    });
    if (!encounter) {
      throw new HttpError('errors.opd_flow.not_found', 404);
    }

    const flow = getOpdFlowState(encounter);

    const [visitQueue, appointment, consultationInvoice, consultationPayment, emergencyCase, triageAssessment] =
      await Promise.all([
        flow.visit_queue_id
          ? tx.visit_queue.findFirst({
              where: { id: flow.visit_queue_id, deleted_at: null },
              include: {
                provider: PROVIDER_INCLUDE,
                facility: true,
                appointment: true
              }
            })
          : null,
        flow.appointment_id
          ? tx.appointment.findFirst({
              where: { id: flow.appointment_id, deleted_at: null },
              include: { provider: PROVIDER_INCLUDE, facility: true }
            })
          : null,
        flow.consultation?.invoice_id
          ? tx.invoice.findFirst({
              where: { id: flow.consultation.invoice_id, deleted_at: null },
              include: {
                payments: {
                  where: { deleted_at: null },
                  orderBy: { created_at: 'desc' }
                }
              }
            })
          : null,
        flow.consultation?.payment_id
          ? tx.payment.findFirst({
              where: { id: flow.consultation.payment_id, deleted_at: null }
            })
          : null,
        flow.emergency_case_id
          ? tx.emergency_case.findFirst({
              where: { id: flow.emergency_case_id, deleted_at: null }
            })
          : null,
        flow.triage_assessment_id
          ? tx.triage_assessment.findFirst({
              where: { id: flow.triage_assessment_id, deleted_at: null }
            })
          : null
      ]);

    const resolvedAdmission =
      (Array.isArray(encounter.admissions)
        ? encounter.admissions.find((item) => item.id === flow.admission_id) || encounter.admissions[0]
        : null) || null;
    const resolvedPharmacyOrder =
      (Array.isArray(encounter.pharmacy_orders)
        ? encounter.pharmacy_orders.find((item) => item.id === flow.pharmacy_order_id) || encounter.pharmacy_orders[0]
        : null) || null;
    const consultation = flow.consultation || {};

    const flowWithFriendlyIds = {
      ...flow,
      consultation: {
        ...consultation,
        consultation_fee: resolveConsultationFeeAmount(consultation, consultationInvoice),
        paid_amount: resolveConsultationPaymentAmount({
          consultation,
          invoice: consultationInvoice,
          payment: consultationPayment
        }),
        currency: consultation.currency || consultationInvoice?.currency || null,
        invoice_id: consultationInvoice?.human_friendly_id || consultation.invoice_id || null,
        payment_id: consultationPayment?.human_friendly_id || consultation.payment_id || null,
        payment_status: resolveConsultationPaymentStatus({
          consultation,
          invoice: consultationInvoice,
          payment: consultationPayment
        })
      },
      appointment_id: appointment?.human_friendly_id || flow.appointment_id || null,
      visit_queue_id: visitQueue?.human_friendly_id || flow.visit_queue_id || null,
      emergency_case_id: emergencyCase?.human_friendly_id || flow.emergency_case_id || null,
      triage_assessment_id: triageAssessment?.human_friendly_id || flow.triage_assessment_id || null,
      lab_order_ids: Array.isArray(encounter.lab_orders)
        ? encounter.lab_orders.map((entry) => entry.human_friendly_id).filter(Boolean)
        : [],
      radiology_order_ids: Array.isArray(encounter.radiology_orders)
        ? encounter.radiology_orders.map((entry) => entry.human_friendly_id).filter(Boolean)
        : [],
      pharmacy_order_id: resolvedPharmacyOrder?.human_friendly_id || null,
      admission_id: resolvedAdmission?.human_friendly_id || null
    };

    return {
      encounter,
      flow: flowWithFriendlyIds,
      visit_queue: visitQueue,
      appointment,
      consultation_invoice: consultationInvoice,
      consultation_payment: consultationPayment,
      emergency_case: emergencyCase,
      triage_assessment: triageAssessment,
      care_plans: encounter.care_plans || [],
      clinical_alerts: encounter.alerts || [],
      referrals: encounter.referrals || [],
      follow_ups: encounter.follow_ups || []
    };
  });

  return result;
};

const listOpdFlows = async (
  filters = {},
  page = 1,
  limit = 20,
  sortBy = 'started_at',
  order = 'desc',
  context = {}
) => {
  const skip = (page - 1) * limit;
  const resolvedFilters = { ...filters };
  resolvedFilters.queue_scope = String(filters.queue_scope || QUEUE_SCOPES.ALL)
    .trim()
    .toUpperCase();
  if (!Object.values(QUEUE_SCOPES).includes(resolvedFilters.queue_scope)) {
    resolvedFilters.queue_scope = QUEUE_SCOPES.ALL;
  }

  if (filters.tenant_id) {
    const tenant = await resolveTenantByIdentifier(prisma, filters.tenant_id);
    if (!tenant) {
      return {
        items: [],
        pagination: {
          page,
          limit,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: page > 1
        }
      };
    }
    resolvedFilters.tenant_id = tenant.id;
  }

  if (filters.facility_id) {
    const facility = await resolveFacilityByIdentifier(prisma, filters.facility_id, resolvedFilters.tenant_id || null);
    if (!facility) {
      return {
        items: [],
        pagination: {
          page,
          limit,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: page > 1
        }
      };
    }
    resolvedFilters.facility_id = facility.id;
  }

  if (filters.patient_id) {
    const patient = await resolvePatientByIdentifier(prisma, filters.patient_id, resolvedFilters.tenant_id || null);
    if (!patient) {
      return {
        items: [],
        pagination: {
          page,
          limit,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: page > 1
        }
      };
    }
    resolvedFilters.patient_id = patient.id;
  }

  const requestedProviderIdentifier =
    filters.provider_user_id || (resolvedFilters.queue_scope === QUEUE_SCOPES.ASSIGNED ? context.user_id : null);

  if (requestedProviderIdentifier) {
    const provider = await resolveProviderByIdentifier(
      prisma,
      requestedProviderIdentifier,
      resolvedFilters.tenant_id || null,
      resolvedFilters.facility_id || null
    );
    if (!provider) {
      return {
        items: [],
        pagination: {
          page,
          limit,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: page > 1
        }
      };
    }
    resolvedFilters.provider_user_id = provider.id;
  }

  const where = buildEncounterWhereClause(resolvedFilters);
  const orderBy = { [sortBy]: order };

  const [encounters, total] = await Promise.all([
    opdFlowRepository.findMany(where, skip, limit, orderBy),
    opdFlowRepository.count(where)
  ]);

  let items = encounters.map((encounter) => {
    const flow = encounter?.extension_json?.opd_flow || null;
    return {
      encounter,
      flow
    };
  });

  if (resolvedFilters.encounter_type === 'EMERGENCY') {
    items = sortEmergencyQueueItems(await enrichEmergencyQueueUrgency(items));
  }
  items = await enrichConsultationBillingForListItems(items);

  return {
    items,
    pagination: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
      hasNextPage: page < Math.ceil(total / limit),
      hasPreviousPage: page > 1
    }
  };
};

const bootstrapOpdFlow = async (data = {}, context = {}) => {
  const encounterType =
    String(data?.encounter_type || 'OPD')
      .trim()
      .toUpperCase() === 'EMERGENCY'
      ? 'EMERGENCY'
      : 'OPD';
  const reuseOpenEncounter = data?.reuse_open_encounter !== false;

  const result = await prisma.$transaction(async (tx) => {
    const resolvedTenantFromBody = data.tenant_id ? await resolveTenantByIdentifier(tx, data.tenant_id) : null;
    if (data.tenant_id && !resolvedTenantFromBody) {
      throw new HttpError('errors.tenant.not_found', 404, [{ field: 'tenant_id' }]);
    }

    const tenantId = resolvedTenantFromBody?.id || context.tenant_id || null;
    if (!tenantId) {
      throw new HttpError('errors.validation.required', 400, [{ field: 'tenant_id' }]);
    }

    const patient = await resolvePatientByIdentifier(tx, data.patient_id, tenantId);
    if (!patient) {
      throw new HttpError('errors.patient.not_found', 404, [{ field: 'patient_id' }]);
    }

    let facilityId = context.facility_id || null;
    if (data.facility_id !== undefined && data.facility_id !== null) {
      const facility = await resolveFacilityByIdentifier(tx, data.facility_id, tenantId);
      if (!facility) {
        throw new HttpError('errors.facility.not_found', 404, [{ field: 'facility_id' }]);
      }
      facilityId = facility.id;
    } else if (data.facility_id === null) {
      facilityId = null;
    }

    let providerUserId = null;
    if (data.provider_user_id) {
      const provider = await resolveProviderByIdentifier(tx, data.provider_user_id, tenantId, facilityId);
      if (!provider) {
        throw new HttpError('errors.user.not_found', 404, [{ field: 'provider_user_id' }]);
      }
      providerUserId = provider.id;
    }

    const existingOpenEncounter = await resolveOpenEncounterForPatient(tx, {
      tenantId,
      patientId: patient.id,
      encounterTypes: ACTIVE_OPD_ENCOUNTER_TYPES
    });
    if (existingOpenEncounter) {
      if (reuseOpenEncounter) {
        return { encounterId: existingOpenEncounter.id, reused: true };
      }

      throw new HttpError('errors.opd_flow.active_encounter_exists', 409, [
        {
          field: 'patient_id',
          encounter_id: existingOpenEncounter.human_friendly_id || existingOpenEncounter.id,
          encounter_type: existingOpenEncounter.encounter_type,
          stage: existingOpenEncounter.extension_json?.opd_flow?.stage || null
        }
      ]);
    }

    return {
      encounterId: null,
      reused: false,
      startPayload: {
        tenant_id: tenantId,
        facility_id: facilityId,
        patient_id: patient.id,
        provider_user_id: providerUserId || null,
        arrival_mode: encounterType === 'EMERGENCY' ? 'EMERGENCY' : 'WALK_IN',
        emergency: encounterType === 'EMERGENCY' ? { severity: 'HIGH' } : undefined
      }
    };
  });

  if (result?.reused && result?.encounterId) {
    return getOpdFlowById(result.encounterId);
  }

  return startOpdFlow(result.startPayload, context);
};

const startOpdFlow = async (data, context = {}) => {
  const startedAt = new Date();
  const reuseOpenEncounter = data?.reuse_open_encounter === true;

  const startedResult = await prisma.$transaction(async (tx) => {
    const resolvedTenantFromBody = data.tenant_id ? await resolveTenantByIdentifier(tx, data.tenant_id) : null;
    if (data.tenant_id && !resolvedTenantFromBody) {
      throw new HttpError('errors.tenant.not_found', 404, [{ field: 'tenant_id' }]);
    }

    const requestedTenantId = resolvedTenantFromBody?.id || context.tenant_id || null;
    let requestedFacilityId = context.facility_id !== undefined ? context.facility_id : null;
    if (data.facility_id !== undefined && data.facility_id !== null) {
      const resolvedFacility = await resolveFacilityByIdentifier(tx, data.facility_id, requestedTenantId || null);
      if (!resolvedFacility) {
        throw new HttpError('errors.facility.not_found', 404, [{ field: 'facility_id' }]);
      }
      requestedFacilityId = resolvedFacility.id;
    } else if (data.facility_id === null) {
      requestedFacilityId = null;
    }

    const appointmentIdentifier = normalizeIdentifier(data.appointment_id);
    let appointment = appointmentIdentifier
      ? await resolveAppointmentByIdentifier(tx, appointmentIdentifier, requestedTenantId, requestedFacilityId)
      : null;

    if (appointmentIdentifier && !appointment) {
      throw new HttpError('errors.appointment.not_found', 404);
    }

    const visitQueueIdentifier = normalizeIdentifier(data.visit_queue_id);
    const requestedVisitQueue = visitQueueIdentifier
      ? await resolveVisitQueueByIdentifier(tx, visitQueueIdentifier, requestedTenantId, requestedFacilityId)
      : null;

    if (visitQueueIdentifier && !requestedVisitQueue) {
      throw new HttpError('errors.visit_queue.not_found', 404, [{ field: 'visit_queue_id' }]);
    }

    if (!appointment && requestedVisitQueue?.appointment_id) {
      appointment = await resolveAppointmentByIdentifier(
        tx,
        requestedVisitQueue.appointment_id,
        requestedVisitQueue.tenant_id || requestedTenantId,
        requestedVisitQueue.facility_id || requestedFacilityId
      );
    }

    if (appointment && (appointment.status === 'CANCELLED' || appointment.status === 'NO_SHOW')) {
      throw new HttpError('errors.opd_flow.appointment_terminal_status', 400);
    }

    if (requestedVisitQueue) {
      const existingQueueFlow = await tx.encounter.findFirst({
        where: {
          deleted_at: null,
          status: 'OPEN',
          encounter_type: { in: ['OPD', 'EMERGENCY'] },
          extension_json: buildOpdFlowJsonFilter(OPD_FLOW_VISIT_QUEUE_ID_JSON_PATH, requestedVisitQueue.id)
        },
        select: { id: true }
      });

      if (existingQueueFlow) {
        return { existingEncounterId: existingQueueFlow.id };
      }
    }

    if (appointment) {
      const existingFlow = await tx.encounter.findFirst({
        where: {
          deleted_at: null,
          status: 'OPEN',
          encounter_type: { in: ['OPD', 'EMERGENCY'] },
          extension_json: buildOpdFlowJsonFilter(OPD_FLOW_APPOINTMENT_ID_JSON_PATH, appointment.id)
        },
        select: { id: true }
      });

      if (existingFlow) {
        return { existingEncounterId: existingFlow.id };
      }
    }

    const arrivalMode = deriveArrivalMode(data, appointment);

    if (arrivalMode === 'ONLINE_APPOINTMENT' && !appointment) {
      throw new HttpError('errors.opd_flow.appointment_required_for_online_mode', 400);
    }

    const tenantId =
      resolvedTenantFromBody?.id ||
      context.tenant_id ||
      appointment?.tenant_id ||
      requestedVisitQueue?.tenant_id ||
      null;
    if (!tenantId) {
      throw new HttpError('errors.validation.required', 400, [{ field: 'tenant_id' }]);
    }

    let facilityId =
      data.facility_id !== undefined
        ? requestedFacilityId
        : requestedFacilityId || appointment?.facility_id || requestedVisitQueue?.facility_id || null;
    if (data.facility_id === null) {
      facilityId = null;
    }

    const requestedPatientIdentifier = normalizeIdentifier(data.patient_id);
    let patientId = appointment?.patient_id || requestedVisitQueue?.patient_id || null;

    if (requestedPatientIdentifier) {
      const existingPatient = await resolvePatientByIdentifier(tx, requestedPatientIdentifier, tenantId);
      if (!existingPatient) {
        throw new HttpError('errors.opd_flow.patient_not_found', 404);
      }

      if (appointment && appointment.patient_id !== existingPatient.id) {
        throw new HttpError('errors.opd_flow.appointment_patient_mismatch', 400);
      }

      patientId = existingPatient.id;
    } else if (patientId) {
      const existingPatient = await resolvePatientByIdentifier(tx, patientId, tenantId);
      if (!existingPatient) {
        throw new HttpError('errors.opd_flow.patient_not_found', 404);
      }

      patientId = existingPatient.id;
    } else if (data.patient_registration) {
      const createdPatient = await tx.patient.create({
        data: {
          tenant_id: tenantId,
          facility_id: facilityId,
          first_name: data.patient_registration.first_name,
          last_name: data.patient_registration.last_name,
          date_of_birth: data.patient_registration.date_of_birth
            ? new Date(data.patient_registration.date_of_birth)
            : null,
          gender: data.patient_registration.gender || null,
          is_active: true
        }
      });
      patientId = createdPatient.id;
    } else {
      throw new HttpError('errors.opd_flow.patient_or_appointment_required', 400);
    }

    if (requestedVisitQueue && requestedVisitQueue.patient_id !== patientId) {
      throw new HttpError('errors.opd_flow.patient_queue_mismatch', 400, [{ field: 'visit_queue_id' }]);
    }

    if (appointment && requestedVisitQueue?.appointment_id && requestedVisitQueue.appointment_id !== appointment.id) {
      throw new HttpError('errors.opd_flow.appointment_queue_mismatch', 400, [{ field: 'visit_queue_id' }]);
    }

    const existingOpenEncounter = await resolveOpenEncounterForPatient(tx, {
      tenantId,
      patientId
    });
    if (existingOpenEncounter) {
      if (reuseOpenEncounter) {
        return { existingEncounterId: existingOpenEncounter.id };
      }

      throw new HttpError('errors.opd_flow.active_encounter_exists', 409, [
        {
          field: 'patient_id',
          encounter_id: existingOpenEncounter.human_friendly_id || existingOpenEncounter.id,
          encounter_type: existingOpenEncounter.encounter_type,
          stage: existingOpenEncounter.extension_json?.opd_flow?.stage || null
        }
      ]);
    }

    const providerIdentifier =
      normalizeIdentifier(data.provider_user_id) ||
      normalizeIdentifier(requestedVisitQueue?.provider_user_id) ||
      normalizeIdentifier(appointment?.provider_user_id);
    let resolvedProvider = null;
    if (providerIdentifier) {
      resolvedProvider = await resolveProviderByIdentifier(tx, providerIdentifier, tenantId, facilityId);
      if (!resolvedProvider && normalizeIdentifier(data.provider_user_id)) {
        throw new HttpError('errors.user.not_found', 404, [{ field: 'provider_user_id' }]);
      }
    }

    const providerUserId =
      resolvedProvider?.id ||
      (normalizeIdentifier(requestedVisitQueue?.provider_user_id) ? requestedVisitQueue.provider_user_id : null) ||
      (normalizeIdentifier(appointment?.provider_user_id) ? appointment.provider_user_id : null);
    const providerDefaults = resolveProviderConsultationDefaults(resolvedProvider);
    const defaultCurrency = await resolveDefaultCurrency(tx, tenantId, facilityId);
    const consultationFee = normalizeDecimalString(data.consultation_fee, providerDefaults.consultationFee || '0.00');
    const currency = normalizeCurrencyCode(
      data.currency,
      providerDefaults.consultationCurrency || defaultCurrency || 'USD'
    );
    const requireConsultationPayment =
      data.require_consultation_payment !== undefined ? data.require_consultation_payment : arrivalMode !== 'EMERGENCY';
    const createConsultationInvoice =
      data.create_consultation_invoice !== undefined
        ? data.create_consultation_invoice
        : requireConsultationPayment || Boolean(data.pay_now);

    let consultationInvoice = null;
    let consultationPayment = null;
    let isConsultationPaid = false;
    let consultationPaidAt = null;
    let consultationPaymentStatus = requireConsultationPayment ? 'PENDING' : 'NOT_REQUIRED';

    if (createConsultationInvoice || data.pay_now) {
      consultationInvoice = await tx.invoice.create({
        data: {
          tenant_id: tenantId,
          facility_id: facilityId,
          patient_id: patientId,
          status: 'SENT',
          billing_status: 'ISSUED',
          total_amount: consultationFee,
          currency,
          issued_at: startedAt
        }
      });
    }

    if (data.pay_now) {
      const paymentStatus = data.pay_now.status || 'COMPLETED';
      consultationPaymentStatus = paymentStatus;
      const paidAt = data.pay_now.paid_at ? new Date(data.pay_now.paid_at) : startedAt;
      const amount = normalizeDecimalString(data.pay_now.amount, consultationFee);

      consultationPayment = await tx.payment.create({
        data: {
          tenant_id: tenantId,
          facility_id: facilityId,
          patient_id: patientId,
          invoice_id: consultationInvoice.id,
          status: paymentStatus,
          method: data.pay_now.method,
          amount,
          paid_at: paymentStatus === 'COMPLETED' ? paidAt : null,
          transaction_ref: data.pay_now.transaction_ref || null
        }
      });

      if (paymentStatus === 'COMPLETED') {
        const invoiceAmount = toDecimalNumber(consultationInvoice.total_amount);
        const paymentAmount = toDecimalNumber(amount);
        isConsultationPaid = paymentAmount >= invoiceAmount;
        consultationPaidAt = isConsultationPaid ? consultationPayment.paid_at || paidAt : null;
        await tx.invoice.update({
          where: { id: consultationInvoice.id },
          data: {
            status: paymentAmount >= invoiceAmount ? 'PAID' : 'SENT',
            billing_status: paymentAmount >= invoiceAmount ? 'PAID' : 'PARTIAL'
          }
        });
      }
    }

    let emergencyCase = null;
    let triageAssessment = null;

    if (arrivalMode === 'EMERGENCY') {
      emergencyCase = await tx.emergency_case.create({
        data: {
          tenant_id: tenantId,
          facility_id: facilityId,
          patient_id: patientId,
          severity: data.emergency?.severity || 'HIGH',
          status: 'OPEN'
        }
      });

      const triageLevel = mapTriageLevel(data.emergency?.triage_level);
      if (triageLevel) {
        triageAssessment = await tx.triage_assessment.create({
          data: {
            emergency_case_id: emergencyCase.id,
            triage_level: triageLevel,
            notes: data.emergency?.notes || null
          }
        });
      }
    }

    const defaultInitialStage =
      arrivalMode !== 'EMERGENCY' && requireConsultationPayment && !isConsultationPaid
        ? STAGES.WAITING_CONSULTATION_PAYMENT
        : STAGES.WAITING_VITALS;
    const requestedInitialStage = normalizeIdentifier(data.initial_stage).toUpperCase();
    const initialStage =
      requestedInitialStage &&
      WORKFLOW_STAGE_SET.has(requestedInitialStage) &&
      !TERMINAL_STAGES.has(requestedInitialStage)
        ? requestedInitialStage
        : defaultInitialStage;

    const flowState = {
      version: 1,
      arrival_mode: arrivalMode,
      stage: initialStage,
      next_step: getNextStep(initialStage),
      consultation: {
        require_payment: requireConsultationPayment,
        consultation_fee: consultationFee,
        currency,
        invoice_id: consultationInvoice?.id || null,
        payment_id: consultationPayment?.id || null,
        payment_status: consultationPaymentStatus,
        is_paid: isConsultationPaid,
        paid_amount:
          isConsultationPaid && consultationPayment ? consultationPayment.amount?.toString?.() || null : null,
        paid_at: consultationPaidAt ? consultationPaidAt.toISOString() : null
      },
      appointment_id: appointment?.id || requestedVisitQueue?.appointment_id || null,
      visit_queue_id: requestedVisitQueue?.id || null,
      emergency_case_id: emergencyCase?.id || null,
      triage_assessment_id: triageAssessment?.id || null,
      lab_order_ids: [],
      radiology_order_ids: [],
      pharmacy_order_id: null,
      admission_id: null,
      review_completed: false,
      timeline: []
    };

    appendTimelineEvent(
      flowState,
      'FLOW_STARTED',
      context,
      {
        arrival_mode: arrivalMode,
        notes: data.notes || null
      },
      startedAt
    );

    if (consultationInvoice) {
      appendTimelineEvent(
        flowState,
        'CONSULTATION_INVOICE_CREATED',
        context,
        {
          invoice_id: consultationInvoice.id,
          consultation_fee: consultationFee,
          currency
        },
        startedAt
      );
    }

    if (consultationPayment) {
      appendTimelineEvent(
        flowState,
        'CONSULTATION_PAYMENT_RECORDED',
        context,
        {
          payment_id: consultationPayment.id,
          status: consultationPayment.status
        },
        startedAt
      );
    }

    if (emergencyCase) {
      appendTimelineEvent(
        flowState,
        'EMERGENCY_CASE_OPENED',
        context,
        {
          emergency_case_id: emergencyCase.id,
          severity: emergencyCase.severity,
          triage_assessment_id: triageAssessment?.id || null
        },
        startedAt
      );
    }

    const queuedAt = data.queued_at ? new Date(data.queued_at) : requestedVisitQueue?.queued_at || startedAt;
    let visitQueue = requestedVisitQueue || null;
    if (visitQueue) {
      visitQueue = await tx.visit_queue.update({
        where: { id: visitQueue.id },
        data: {
          provider_user_id: providerUserId || visitQueue.provider_user_id || null,
          status: 'IN_PROGRESS',
          queued_at: queuedAt
        }
      });
    } else {
      visitQueue = await tx.visit_queue.create({
        data: {
          tenant_id: tenantId,
          facility_id: facilityId,
          patient_id: patientId,
          appointment_id: appointment?.id || null,
          provider_user_id: providerUserId,
          status: 'CONFIRMED',
          queued_at: queuedAt
        }
      });
    }
    flowState.visit_queue_id = visitQueue.id;

    const encounter = await tx.encounter.create({
      data: {
        tenant_id: tenantId,
        facility_id: facilityId,
        patient_id: patientId,
        provider_user_id: providerUserId,
        encounter_type: arrivalMode === 'EMERGENCY' ? 'EMERGENCY' : 'OPD',
        status: 'OPEN',
        started_at: startedAt,
        extension_json: {
          opd_flow: flowState
        }
      },
      include: {
        tenant: true,
        facility: true,
        patient: true,
        provider: PROVIDER_INCLUDE
      }
    });

    if (appointment && appointment.status !== 'IN_PROGRESS') {
      await tx.appointment.update({
        where: { id: appointment.id },
        data: { status: 'IN_PROGRESS' }
      });
    }

    return {
      encounter,
      transition: {
        action: 'START_FLOW',
        stage_from: null,
        stage_to: initialStage,
        provider_user_id: providerUserId,
        occurred_at: startedAt.toISOString()
      }
    };
  });

  if (startedResult.existingEncounterId) {
    return getOpdFlowById(startedResult.existingEncounterId);
  }

  createAuditLog({
    tenant_id: startedResult.encounter.tenant_id,
    user_id: context.user_id,
    action: 'CREATE',
    entity: 'opd_flow',
    entity_id: startedResult.encounter.id,
    diff: { after: startedResult.encounter },
    ip_address: context.ip_address
  }).catch(() => {});

  const snapshot = await getOpdFlowById(startedResult.encounter.id);
  await publishOpdRealtimeUpdates({
    snapshot,
    transition: startedResult.transition,
    context
  });
  return snapshot;
};

const payConsultation = async (id, data, context = {}) => {
  const updatedResult = await prisma.$transaction(async (tx) => {
    const encounter = await resolveEncounterByIdentifier(tx, id);
    if (!encounter) {
      throw new HttpError('errors.opd_flow.not_found', 404);
    }

    const flow = getOpdFlowState(encounter);
    ensureNonTerminalStage(flow);
    const stageBefore = flow.stage;

    const consultation = flow.consultation || {};
    const isCorrection =
      consultation.is_paid === true || PAID_PAYMENT_STATUSES.has(normalizeUpper(consultation.payment_status));

    let invoiceId = data.invoice_id || consultation.invoice_id || null;
    let invoice = null;

    if (invoiceId) {
      invoice = await resolveEntityByIdentifier(tx, 'invoice', invoiceId, {
        tenant_id: encounter.tenant_id
      });
      if (!invoice) {
        throw new HttpError('errors.invoice.not_found', 404);
      }
      invoiceId = invoice.id;
    } else {
      invoice = await tx.invoice.create({
        data: {
          tenant_id: encounter.tenant_id,
          facility_id: encounter.facility_id,
          patient_id: encounter.patient_id,
          status: 'SENT',
          billing_status: 'ISSUED',
          total_amount: normalizeDecimalString(data.amount, consultation.consultation_fee || '0.00'),
          currency: normalizeCurrencyCode(
            data.currency || consultation.currency,
            await resolveDefaultCurrency(tx, encounter.tenant_id, encounter.facility_id)
          ),
          issued_at: new Date()
        }
      });
      invoiceId = invoice.id;
    }

    const paymentStatus = data.status || 'COMPLETED';
    const currency = normalizeCurrencyCode(
      data.currency || consultation.currency || invoice.currency,
      await resolveDefaultCurrency(tx, encounter.tenant_id, encounter.facility_id)
    );
    const amount = normalizeDecimalString(
      data.amount,
      consultation.consultation_fee || normalizeDecimalString(invoice.total_amount, '0.00')
    );

    const payment = await tx.payment.create({
      data: {
        tenant_id: encounter.tenant_id,
        facility_id: encounter.facility_id,
        patient_id: encounter.patient_id,
        invoice_id: invoiceId,
        status: paymentStatus,
        method: data.method,
        amount,
        paid_at: paymentStatus === 'COMPLETED' ? (data.paid_at ? new Date(data.paid_at) : new Date()) : null,
        transaction_ref: data.transaction_ref || null
      }
    });

    const correctedInvoiceTotal =
      isCorrection && data.amount ? amount : normalizeDecimalString(invoice.total_amount, amount);
    if (
      isCorrection &&
      data.amount &&
      toDecimalNumber(correctedInvoiceTotal) !== toDecimalNumber(invoice.total_amount)
    ) {
      invoice = await tx.invoice.update({
        where: { id: invoice.id },
        data: {
          total_amount: correctedInvoiceTotal,
          currency
        }
      });
    }

    const invoiceTotal = toDecimalNumber(correctedInvoiceTotal);
    const paidAmount = toDecimalNumber(amount);
    const isPaid = paymentStatus === 'COMPLETED' && paidAmount >= invoiceTotal;

    await tx.invoice.update({
      where: { id: invoice.id },
      data: {
        status: isPaid ? 'PAID' : 'SENT',
        currency,
        billing_status: paymentStatus === 'COMPLETED' ? (isPaid ? 'PAID' : 'PARTIAL') : 'ISSUED'
      }
    });

    consultation.invoice_id = invoice.id;
    consultation.payment_id = payment.id;
    consultation.payment_status = paymentStatus;
    consultation.is_paid = isPaid;
    consultation.paid_amount = isPaid ? amount : null;
    consultation.paid_at = isPaid && payment.paid_at ? payment.paid_at.toISOString() : null;
    consultation.currency = currency;
    flow.consultation = consultation;

    if (flow.stage === STAGES.WAITING_CONSULTATION_PAYMENT && consultation.is_paid) {
      setFlowStage(flow, STAGES.WAITING_VITALS);
    }

    appendTimelineEvent(
      flow,
      isCorrection ? 'CONSULTATION_PAYMENT_CORRECTED' : 'CONSULTATION_PAYMENT_RECORDED',
      context,
      {
        payment_id: payment.id,
        invoice_id: invoice.id,
        amount,
        status: paymentStatus,
        notes: data.notes || null
      }
    );

    const updatedEncounter = await tx.encounter.update({
      where: { id: encounter.id },
      data: {
        extension_json: {
          ...(encounter.extension_json || {}),
          opd_flow: flow
        }
      }
    });

    return {
      encounter: updatedEncounter,
      transition: {
        action: 'PAY_CONSULTATION',
        stage_from: stageBefore,
        stage_to: flow.stage,
        provider_user_id: encounter.provider_user_id || null,
        occurred_at: new Date().toISOString()
      }
    };
  });

  createAuditLog({
    tenant_id: updatedResult.encounter.tenant_id,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'opd_flow',
    entity_id: updatedResult.encounter.id,
    diff: { after: updatedResult.encounter },
    ip_address: context.ip_address
  }).catch(() => {});

  const snapshot = await getOpdFlowById(updatedResult.encounter.id);
  await publishOpdRealtimeUpdates({
    snapshot,
    transition: updatedResult.transition,
    context
  });
  return snapshot;
};

const recordVitals = async (id, data, context = {}) => {
  const updatedResult = await prisma.$transaction(async (tx) => {
    const encounter = await resolveEncounterByIdentifier(tx, id);
    if (!encounter) {
      throw new HttpError('errors.opd_flow.not_found', 404);
    }

    const flow = getOpdFlowState(encounter);
    ensureNonTerminalStage(flow);
    const stageBefore = flow.stage;

    const isEmergency = encounter.encounter_type === 'EMERGENCY';
    if (!isEmergency && flow.consultation?.require_payment && !flow.consultation?.is_paid) {
      throw new HttpError('errors.opd_flow.consultation_payment_required', 400);
    }

    const isVitalsUpdate = data.update_existing === true;
    if (
      !isVitalsUpdate &&
      flow.stage !== STAGES.WAITING_VITALS &&
      flow.stage !== STAGES.WAITING_DOCTOR_ASSIGNMENT
    ) {
      throw new HttpError('errors.opd_flow.invalid_stage_transition', 400);
    }

    const normalizedVitals = data.vitals.map((vital) => {
      const normalizedVital = normalizeVitalForPersistence(vital);
      return {
        encounter_id: encounter.id,
        vital_type: normalizedVital.vital_type,
        value: normalizedVital.value,
        systolic_value: normalizedVital.systolic_value,
        diastolic_value: normalizedVital.diastolic_value,
        map_value: normalizedVital.map_value,
        unit: vital.unit || null,
        recorded_at: vital.recorded_at ? new Date(vital.recorded_at) : new Date()
      };
    });

    const savedVitals = [];
    if (
      typeof tx?.vital_sign?.findFirst === 'function' &&
      typeof tx?.vital_sign?.update === 'function' &&
      typeof tx?.vital_sign?.create === 'function'
    ) {
      for (const vitalData of normalizedVitals) {
        const existingVital = await tx.vital_sign.findFirst({
          where: {
            encounter_id: encounter.id,
            vital_type: vitalData.vital_type,
            deleted_at: null
          },
          orderBy: { recorded_at: 'desc' }
        });
        const savedVital = existingVital
          ? await tx.vital_sign.update({
              where: { id: existingVital.id },
              data: vitalData
            })
          : await tx.vital_sign.create({ data: vitalData });
        savedVitals.push(savedVital);
      }
    } else if (typeof tx?.vital_sign?.create === 'function') {
      for (const vitalData of normalizedVitals) {
        const created = await tx.vital_sign.create({ data: vitalData });
        savedVitals.push(created);
      }
    } else {
      await tx.vital_sign.createMany({ data: normalizedVitals });
    }

    const requestedTriageValue = data.triage_priority || data.triage_level;
    const triageLevel = mapTriageLevel(requestedTriageValue);
    if (requestedTriageValue && !triageLevel) {
      throw new HttpError('errors.opd_flow.invalid_stage_transition', 400, [{ field: 'triage_level' }]);
    }

    if (triageLevel) {
      flow.triage_level = triageLevel;
      flow.triage_priority = triageLevel;
    }
    const chiefComplaint = normalizeNotes(data.chief_complaint);
    if (chiefComplaint) {
      flow.chief_complaint = chiefComplaint;
    }
    const triageNotes = normalizeNotes(data.triage_notes);
    if (triageNotes) {
      flow.triage_notes = triageNotes;
    }
    if (data.emergency === true) {
      flow.emergency_indicator = true;
    }

    if (flow.emergency_case_id && (triageLevel || triageNotes)) {
      if (flow.triage_assessment_id) {
        await tx.triage_assessment.update({
          where: { id: flow.triage_assessment_id },
          data: {
            triage_level: triageLevel || undefined,
            notes: triageNotes || undefined
          }
        });
      } else if (triageLevel) {
        const triageAssessment = await tx.triage_assessment.create({
          data: {
            emergency_case_id: flow.emergency_case_id,
            triage_level: triageLevel,
            notes: triageNotes
          }
        });
        flow.triage_assessment_id = triageAssessment.id;
      }
    }

    if (flow.stage === STAGES.WAITING_VITALS || flow.stage === STAGES.WAITING_DOCTOR_ASSIGNMENT) {
      setFlowStage(flow, STAGES.WAITING_DOCTOR_ASSIGNMENT);
    }
    appendTimelineEvent(flow, isVitalsUpdate ? 'VITALS_UPDATED' : 'VITALS_RECORDED', context, {
      vitals_count: data.vitals.length,
      triage_level: data.triage_level || null
    });

    if (flow.visit_queue_id) {
      await tx.visit_queue.update({
        where: { id: flow.visit_queue_id },
        data: { status: 'IN_PROGRESS' }
      });
    }

    const updatedEncounter = await tx.encounter.update({
      where: { id: encounter.id },
      data: {
        extension_json: {
          ...(encounter.extension_json || {}),
          opd_flow: flow
        }
      }
    });

    return {
      encounter: updatedEncounter,
      saved_vitals: savedVitals,
      transition: {
        action: 'RECORD_VITALS',
        stage_from: stageBefore,
        stage_to: flow.stage,
        provider_user_id: encounter.provider_user_id || null,
        occurred_at: new Date().toISOString()
      }
    };
  });

  createAuditLog({
    tenant_id: updatedResult.encounter.tenant_id,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'opd_flow',
    entity_id: updatedResult.encounter.id,
    diff: { after: updatedResult.encounter },
    ip_address: context.ip_address
  }).catch(() => {});

  let snapshot = await getOpdFlowById(updatedResult.encounter.id);
  const savedVitals = Array.isArray(updatedResult.saved_vitals) ? updatedResult.saved_vitals : [];
  if (savedVitals.length > 0) {
    await Promise.all(
      savedVitals.map((vital) =>
        clinicalAlertThresholdService
          .evaluateVitalAndCreateAlerts(
            {
              vitalSign: vital,
              encounter: snapshot?.encounter || updatedResult.encounter,
              patient: snapshot?.encounter?.patient || null
            },
            {
              user_id: context.user_id,
              ip_address: context.ip_address
            }
          )
          .catch(() => null)
      )
    );
    snapshot = await getOpdFlowById(updatedResult.encounter.id);
  }
  await publishOpdRealtimeUpdates({
    snapshot,
    transition: updatedResult.transition,
    context
  });
  return snapshot;
};

const assignDoctor = async (id, data, context = {}) => {
  const updatedResult = await prisma.$transaction(async (tx) => {
    const encounter = await resolveEncounterByIdentifier(tx, id);
    if (!encounter) {
      throw new HttpError('errors.opd_flow.not_found', 404);
    }

    const flow = getOpdFlowState(encounter);
    ensureNonTerminalStage(flow);
    const stageBefore = flow.stage;

    const provider = await resolveProviderByIdentifier(
      tx,
      data.provider_user_id,
      encounter.tenant_id,
      encounter.facility_id
    );
    if (!provider) {
      throw new HttpError('errors.user.not_found', 404, [{ field: 'provider_user_id' }]);
    }

    const updated = await tx.encounter.update({
      where: { id: encounter.id },
      data: {
        provider_user_id: provider.id
      }
    });

    if (flow.visit_queue_id) {
      await tx.visit_queue.update({
        where: { id: flow.visit_queue_id },
        data: {
          provider_user_id: provider.id,
          status: 'IN_PROGRESS'
        }
      });
    }

    if (flow.stage === STAGES.WAITING_DOCTOR_ASSIGNMENT) {
      setFlowStage(flow, STAGES.WAITING_DOCTOR_REVIEW);
    }
    appendTimelineEvent(flow, 'DOCTOR_ASSIGNED', context, {
      provider_user_id: provider.id
    });

    const updatedEncounter = await tx.encounter.update({
      where: { id: updated.id },
      data: {
        extension_json: {
          ...(encounter.extension_json || {}),
          opd_flow: flow
        }
      }
    });

    return {
      encounter: updatedEncounter,
      transition: {
        action: 'ASSIGN_DOCTOR',
        stage_from: stageBefore,
        stage_to: flow.stage,
        provider_user_id: provider.id,
        occurred_at: new Date().toISOString()
      }
    };
  });

  createAuditLog({
    tenant_id: updatedResult.encounter.tenant_id,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'opd_flow',
    entity_id: updatedResult.encounter.id,
    diff: { after: updatedResult.encounter },
    ip_address: context.ip_address
  }).catch(() => {});

  const snapshot = await getOpdFlowById(updatedResult.encounter.id);
  await publishOpdRealtimeUpdates({
    snapshot,
    transition: updatedResult.transition,
    context
  });
  return snapshot;
};

const doctorReview = async (id, data, context = {}) => {
  const updatedResult = await prisma.$transaction(async (tx) => {
    const encounter = await resolveEncounterByIdentifier(tx, id);
    if (!encounter) {
      throw new HttpError('errors.opd_flow.not_found', 404);
    }

    const flow = getOpdFlowState(encounter);
    ensureNonTerminalStage(flow);
    const stageBefore = flow.stage;

    const reviewUpdateStages = new Set([
      STAGES.WAITING_DOCTOR_REVIEW,
      STAGES.LAB_REQUESTED,
      STAGES.RADIOLOGY_REQUESTED,
      STAGES.LAB_AND_RADIOLOGY_REQUESTED,
      STAGES.PHARMACY_REQUESTED,
      STAGES.WAITING_DISPOSITION
    ]);
    if (!reviewUpdateStages.has(flow.stage)) {
      throw new HttpError('errors.opd_flow.invalid_stage_transition', 400);
    }

    const authorUserId = context.user_id || encounter.provider_user_id;
    if (!authorUserId) {
      throw new HttpError('errors.opd_flow.invalid_stage_transition', 400, [{ field: 'author_user_id' }]);
    }

    const note = await tx.clinical_note.create({
      data: {
        encounter_id: encounter.id,
        author_user_id: authorUserId,
        note: data.note
      }
    });

    if (Array.isArray(data.diagnoses) && data.diagnoses.length) {
      await tx.diagnosis.createMany({
        data: data.diagnoses.map((diagnosis) => ({
          encounter_id: encounter.id,
          diagnosis_type: diagnosis.diagnosis_type,
          code: diagnosis.code || null,
          description: diagnosis.description
        }))
      });
    }

    if (Array.isArray(data.procedures) && data.procedures.length) {
      await tx.procedure.createMany({
        data: data.procedures.map((procedure) => ({
          encounter_id: encounter.id,
          code: procedure.code || null,
          description: procedure.description,
          performed_at: procedure.performed_at ? new Date(procedure.performed_at) : null
        }))
      });
    }

    let labOrder = null;
    const resolvedLabRequests = [];
    if (Array.isArray(data.lab_requests) && data.lab_requests.length) {
      const seenLabTestIds = new Set();
      for (const [index, item] of data.lab_requests.entries()) {
        if (item.lab_test_id) {
          const labTest = await resolveEntityByIdentifier(tx, 'lab_test', item.lab_test_id, {
            tenant_id: encounter.tenant_id
          });
          if (!labTest) {
            throw new HttpError('errors.lab_test.not_found', 404, [{ field: `lab_requests.${index}.lab_test_id` }]);
          }

          if (!seenLabTestIds.has(labTest.id)) {
            seenLabTestIds.add(labTest.id);
            resolvedLabRequests.push({
              lab_test_id: labTest.id,
              status: item.status || 'ORDERED'
            });
          }
        }

        if (item.lab_panel_id) {
          const normalizedPanelId = normalizeIdentifier(item.lab_panel_id);
          const labPanel = normalizedPanelId
            ? await tx.lab_panel.findFirst({
                where: {
                  deleted_at: null,
                  tenant_id: encounter.tenant_id,
                  OR: isUuid(normalizedPanelId)
                    ? [{ id: normalizedPanelId }]
                    : [{ human_friendly_id: normalizedPanelId.toUpperCase() }]
                },
                include: LAB_PANEL_WITH_RELATIONS_INCLUDE
              })
            : null;

          if (!labPanel) {
            throw new HttpError('errors.lab_panel.not_found', 404, [{ field: `lab_requests.${index}.lab_panel_id` }]);
          }

          const panelItems = Array.isArray(labPanel.panel_items) ? labPanel.panel_items : [];
          panelItems.forEach((panelItem) => {
            const labTestId = panelItem?.lab_test_id || panelItem?.lab_test?.id;
            if (!labTestId || seenLabTestIds.has(labTestId)) return;
            seenLabTestIds.add(labTestId);
            resolvedLabRequests.push({
              lab_test_id: labTestId,
              status: item.status || 'ORDERED'
            });
          });
        }
      }

      if (resolvedLabRequests.length) {
        labOrder = await tx.lab_order.create({
          data: {
            encounter_id: encounter.id,
            patient_id: encounter.patient_id,
            status: 'ORDERED',
            ordered_at: new Date()
          }
        });

        await tx.lab_order_item.createMany({
          data: resolvedLabRequests.map((item) => ({
            lab_order_id: labOrder.id,
            lab_test_id: item.lab_test_id,
            status: item.status || 'ORDERED'
          }))
        });
      }
    }

    const radiologyOrderIds = [];
    if (Array.isArray(data.radiology_requests) && data.radiology_requests.length) {
      for (const [index, request] of data.radiology_requests.entries()) {
        let radiologyTestId = null;
        if (request.radiology_test_id) {
          const radiologyTest = await resolveEntityByIdentifier(tx, 'radiology_test', request.radiology_test_id, {
            tenant_id: encounter.tenant_id
          });
          if (!radiologyTest) {
            throw new HttpError('errors.radiology_test.not_found', 404, [
              { field: `radiology_requests.${index}.radiology_test_id` }
            ]);
          }
          radiologyTestId = radiologyTest.id;
        }

        const radiologyOrder = await tx.radiology_order.create({
          data: {
            encounter_id: encounter.id,
            patient_id: encounter.patient_id,
            radiology_test_id: radiologyTestId,
            status: request.status || 'ORDERED',
            ordered_at: new Date()
          }
        });
        radiologyOrderIds.push(radiologyOrder.id);
      }
    }

    let pharmacyOrder = null;
    const resolvedMedications = [];
    if (Array.isArray(data.medications) && data.medications.length) {
      for (const [index, medication] of data.medications.entries()) {
        const drug = await resolveEntityByIdentifier(tx, 'drug', medication.drug_id, {
          tenant_id: encounter.tenant_id
        });
        if (!drug) {
          throw new HttpError('errors.drug.not_found', 404, [{ field: `medications.${index}.drug_id` }]);
        }
        resolvedMedications.push({
          ...medication,
          drug_id: drug.id
        });
      }

      pharmacyOrder = await tx.pharmacy_order.create({
        data: {
          encounter_id: encounter.id,
          patient_id: encounter.patient_id,
          status: 'ORDERED',
          ordered_at: new Date()
        }
      });

      await tx.pharmacy_order_item.createMany({
        data: resolvedMedications.map((medication) => ({
          pharmacy_order_id: pharmacyOrder.id,
          drug_id: medication.drug_id,
          quantity: medication.quantity,
          dosage: medication.dosage || null,
          frequency: medication.frequency || null,
          route: medication.route || null,
          status: medication.status || 'ACTIVE'
        }))
      });
    }

    const hasLab = Boolean(labOrder);
    const hasRadiology = radiologyOrderIds.length > 0;
    const hasMedication = Boolean(pharmacyOrder);

    if (hasLab && hasRadiology) {
      setFlowStage(flow, STAGES.LAB_AND_RADIOLOGY_REQUESTED);
    } else if (hasLab) {
      setFlowStage(flow, STAGES.LAB_REQUESTED);
    } else if (hasRadiology) {
      setFlowStage(flow, STAGES.RADIOLOGY_REQUESTED);
    } else if (hasMedication) {
      setFlowStage(flow, STAGES.PHARMACY_REQUESTED);
    } else if (flow.stage === STAGES.WAITING_DOCTOR_REVIEW) {
      setFlowStage(flow, STAGES.WAITING_DISPOSITION);
    }

    flow.review_completed = true;
    flow.clinical_note_id = note.id;
    if (labOrder) {
      flow.lab_order_ids = [labOrder.id];
    }
    if (radiologyOrderIds.length) {
      flow.radiology_order_ids = radiologyOrderIds;
    }
    if (pharmacyOrder) {
      flow.pharmacy_order_id = pharmacyOrder.id;
    }

    appendTimelineEvent(flow, 'DOCTOR_REVIEW_COMPLETED', context, {
      note_id: note.id,
      diagnosis_count: Array.isArray(data.diagnoses) ? data.diagnoses.length : 0,
      procedure_count: Array.isArray(data.procedures) ? data.procedures.length : 0,
      lab_order_count: hasLab ? 1 : 0,
      radiology_order_count: radiologyOrderIds.length,
      medication_count: Array.isArray(data.medications) ? data.medications.length : 0,
      notes: data.notes || null
    });

    const updatedEncounter = await tx.encounter.update({
      where: { id: encounter.id },
      data: {
        extension_json: {
          ...(encounter.extension_json || {}),
          opd_flow: flow
        }
      }
    });

    return {
      encounter: updatedEncounter,
      transition: {
        action: 'DOCTOR_REVIEW',
        stage_from: stageBefore,
        stage_to: flow.stage,
        provider_user_id: encounter.provider_user_id || authorUserId || null,
        occurred_at: new Date().toISOString()
      }
    };
  });

  createAuditLog({
    tenant_id: updatedResult.encounter.tenant_id,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'opd_flow',
    entity_id: updatedResult.encounter.id,
    diff: { after: updatedResult.encounter },
    ip_address: context.ip_address
  }).catch(() => {});

  const snapshot = await getOpdFlowById(updatedResult.encounter.id);
  await publishOpdRealtimeUpdates({
    snapshot,
    transition: updatedResult.transition,
    context
  });
  return snapshot;
};

const disposition = async (id, data, context = {}) => {
  const dispositionAt = new Date();

  const updatedResult = await prisma.$transaction(async (tx) => {
    const encounter = await resolveEncounterByIdentifier(tx, id);
    if (!encounter) {
      throw new HttpError('errors.opd_flow.not_found', 404);
    }

    const flow = getOpdFlowState(encounter);
    ensureNonTerminalStage(flow);
    const stageBefore = flow.stage;
    const dispositionReason = normalizeNotes(data.reason);
    const dispositionNotes = normalizeNotes(data.notes);

    if (!flow.review_completed) {
      throw new HttpError('errors.opd_flow.doctor_review_required', 400);
    }

    let admission = null;
    if (data.decision === 'ADMIT') {
      let admissionFacilityId = encounter.facility_id || null;
      if (data.admission_facility_id !== undefined) {
        if (data.admission_facility_id === null) {
          admissionFacilityId = null;
        } else {
          const resolvedFacility = await resolveFacilityByIdentifier(
            tx,
            data.admission_facility_id,
            encounter.tenant_id
          );
          if (!resolvedFacility) {
            throw new HttpError('errors.facility.not_found', 404, [{ field: 'admission_facility_id' }]);
          }
          admissionFacilityId = resolvedFacility.id;
        }
      }

      admission = await tx.admission.create({
        data: {
          tenant_id: encounter.tenant_id,
          facility_id: admissionFacilityId,
          patient_id: encounter.patient_id,
          encounter_id: encounter.id,
          status: 'ADMITTED',
          admitted_at: dispositionAt
        }
      });
      flow.admission_id = admission.id;
      setFlowStage(flow, STAGES.ADMITTED);
    } else {
      if (data.decision === 'SEND_TO_PHARMACY' && !flow.pharmacy_order_id) {
        throw new HttpError('errors.opd_flow.pharmacy_order_required_for_disposition', 400);
      }

      setFlowStage(flow, STAGES.DISCHARGED);
    }

    flow.disposition_reason = dispositionReason;
    flow.disposition_notes = dispositionNotes;
    flow.disposition_at = dispositionAt.toISOString();

    appendTimelineEvent(flow, 'DISPOSITION_RECORDED', context, {
      decision: data.decision,
      admission_id: admission?.id || null,
      reason: dispositionReason,
      notes: dispositionNotes
    });

    const finalizedEncounter = await tx.encounter.update({
      where: { id: encounter.id },
      data: {
        status: 'CLOSED',
        ended_at: dispositionAt,
        extension_json: {
          ...(encounter.extension_json || {}),
          opd_flow: flow
        }
      }
    });

    if (flow.visit_queue_id) {
      await tx.visit_queue.update({
        where: { id: flow.visit_queue_id },
        data: {
          status: 'COMPLETED'
        }
      });
    }

    if (flow.appointment_id) {
      const appointment = await tx.appointment.findFirst({
        where: { id: flow.appointment_id, deleted_at: null }
      });
      if (appointment && appointment.status !== 'CANCELLED' && appointment.status !== 'NO_SHOW') {
        await tx.appointment.update({
          where: { id: appointment.id },
          data: { status: 'COMPLETED' }
        });
      }
    }

    if (flow.emergency_case_id) {
      await tx.emergency_case.update({
        where: { id: flow.emergency_case_id },
        data: {
          status: 'CLOSED'
        }
      });
    }

    return {
      encounter: finalizedEncounter,
      admission_id: admission?.id || null,
      transition: {
        action: 'DISPOSITION',
        stage_from: stageBefore,
        stage_to: flow.stage,
        provider_user_id: encounter.provider_user_id || null,
        occurred_at: dispositionAt.toISOString()
      }
    };
  });

  createAuditLog({
    tenant_id: updatedResult.encounter.tenant_id,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'opd_flow',
    entity_id: updatedResult.encounter.id,
    diff: { after: updatedResult.encounter },
    ip_address: context.ip_address
  }).catch(() => {});

  const snapshot = await getOpdFlowById(updatedResult.encounter.id);
  await publishOpdRealtimeUpdates({
    snapshot,
    transition: updatedResult.transition,
    context
  });

  if (updatedResult.admission_id) {
    try {
      const ipdFlowService = require('@services/ipd-flow/ipd-flow.service');
      await ipdFlowService.emitAdmissionRefreshEvent(updatedResult.admission_id, context);
    } catch (_error) {
      // OPD disposition should not fail when IPD realtime fan-out fails.
    }
  }

  return snapshot;
};

const correctStage = async (id, data, context = {}) => {
  const reason = String(data?.reason || '').trim();

  const stageTo = String(data?.stage_to || '').trim();
  if (!WORKFLOW_STAGE_SET.has(stageTo)) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'stage_to' }]);
  }

  const correctedAt = new Date();

  const updatedResult = await prisma.$transaction(async (tx) => {
    const encounter = await resolveEncounterByIdentifier(tx, id);
    if (!encounter) {
      throw new HttpError('errors.opd_flow.not_found', 404);
    }

    const flow = getOpdFlowState(encounter);
    const stageBefore = flow.stage || null;
    if (stageBefore === stageTo) {
      throw new HttpError('errors.opd_flow.invalid_stage_transition', 400, [{ field: 'stage_to' }]);
    }
    if (stageCorrectionRequiresReason(stageBefore, stageTo) && !reason) {
      throw new HttpError('errors.validation.required', 400, [{ field: 'reason' }]);
    }

    setFlowStage(flow, stageTo);
    const isTerminalStage = TERMINAL_STAGES.has(stageTo);
    appendTimelineEvent(
      flow,
      'STAGE_CORRECTED',
      context,
      {
        stage_from: stageBefore,
        stage_to: stageTo,
        ...(reason ? { reason } : {})
      },
      correctedAt
    );

    const updatedEncounter = await tx.encounter.update({
      where: { id: encounter.id },
      data: {
        status: isTerminalStage ? 'CLOSED' : 'OPEN',
        ended_at: isTerminalStage ? encounter.ended_at || correctedAt : null,
        extension_json: {
          ...(encounter.extension_json || {}),
          opd_flow: flow
        }
      }
    });

    if (flow.visit_queue_id) {
      await tx.visit_queue.update({
        where: { id: flow.visit_queue_id },
        data: {
          status: isTerminalStage ? 'COMPLETED' : 'IN_PROGRESS'
        }
      });
    }

    if (flow.appointment_id) {
      const appointment = await tx.appointment.findFirst({
        where: { id: flow.appointment_id, deleted_at: null }
      });
      if (appointment && appointment.status !== 'CANCELLED' && appointment.status !== 'NO_SHOW') {
        await tx.appointment.update({
          where: { id: appointment.id },
          data: { status: isTerminalStage ? 'COMPLETED' : 'IN_PROGRESS' }
        });
      }
    }

    return {
      encounter: updatedEncounter,
      stageBefore,
      stageAfter: stageTo,
      transition: {
        action: 'STAGE_CORRECTED',
        stage_from: stageBefore,
        stage_to: stageTo,
        provider_user_id: encounter.provider_user_id || null,
        occurred_at: correctedAt.toISOString()
      }
    };
  });

  createAuditLog({
    tenant_id: updatedResult.encounter.tenant_id,
    user_id: context.user_id,
    action: 'UPDATE',
    entity: 'opd_flow',
    entity_id: updatedResult.encounter.id,
    diff: {
      before: {
        stage: updatedResult.stageBefore
      },
      after: {
        stage: updatedResult.stageAfter
      },
      reason,
      actor_user_id: context.user_id || null
    },
    ip_address: context.ip_address
  }).catch(() => {});

  const snapshot = await getOpdFlowById(updatedResult.encounter.id);
  await publishOpdRealtimeUpdates({
    snapshot,
    transition: updatedResult.transition,
    context
  });
  return snapshot;
};

module.exports = {
  listOpdFlows,
  resolveLegacyRoute,
  getOpdFlowById,
  bootstrapOpdFlow,
  startOpdFlow,
  payConsultation,
  recordVitals,
  assignDoctor,
  doctorReview,
  disposition,
  correctStage
};
