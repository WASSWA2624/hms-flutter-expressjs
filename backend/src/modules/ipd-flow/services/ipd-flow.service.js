/**
 * IPD flow service
 */

const prisma = require("@prisma/client");
const ipdFlowRepository = require("@repositories/ipd-flow/ipd-flow.repository");
const { HttpError } = require("@lib/errors");
const { createAuditLog } = require("@lib/audit");
const {
  emitToUser,
  emitToUsers,
  IPD_EVENTS,
  ADMISSION_BED_EVENTS,
  NOTIFICATION_EVENTS,
} = require("@lib/websocket");
const { ROLES } = require("@config/roles");
const {
  buildIpdMedicationReminderNote,
  normalizeMedicationFrequency,
  parseIpdMedicationReminderNote,
  resolveMedicationFrequencyIntervalHours,
} = require("@lib/clinical/ipdMedicationReminder");

const UUID_LIKE_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const STAGES = Object.freeze({
  ADMITTED_PENDING_BED: "ADMITTED_PENDING_BED",
  ADMITTED_IN_BED: "ADMITTED_IN_BED",
  TRANSFER_REQUESTED: "TRANSFER_REQUESTED",
  TRANSFER_IN_PROGRESS: "TRANSFER_IN_PROGRESS",
  DISCHARGE_PLANNED: "DISCHARGE_PLANNED",
  DISCHARGED: "DISCHARGED",
  CANCELLED: "CANCELLED",
});

const TRANSFER_ACTIONS = Object.freeze({
  APPROVE: "APPROVE",
  START: "START",
  COMPLETE: "COMPLETE",
  CANCEL: "CANCEL",
});

const QUEUE_SCOPES = Object.freeze({
  ACTIVE: "ACTIVE",
  ALL: "ALL",
});
const ICU_QUEUE_SCOPES = Object.freeze({
  ALL: "ALL",
  WITH_ICU: "WITH_ICU",
  ACTIVE: "ACTIVE",
});
const ICU_STATUSES = Object.freeze({
  ACTIVE: "ACTIVE",
  ENDED: "ENDED",
  NONE: "NONE",
});
const CRITICAL_SEVERITY_ORDER = Object.freeze({
  LOW: 1,
  MEDIUM: 2,
  HIGH: 3,
  CRITICAL: 4,
});
const TERMINAL_STAGES = new Set([STAGES.DISCHARGED, STAGES.CANCELLED]);
const LEGACY_ROUTE_CONFIG = Object.freeze({
  admissions: {
    delegate: "admission",
    admissionField: "id",
    panel: "snapshot",
    action: "open_admission",
  },
  "bed-assignments": {
    delegate: "bed_assignment",
    admissionField: "admission_id",
    panel: "beds",
    action: "manage_bed",
  },
  "ward-rounds": {
    delegate: "ward_round",
    admissionField: "admission_id",
    panel: "rounds",
    action: "add_ward_round",
  },
  "nursing-notes": {
    delegate: "nursing_note",
    admissionField: "admission_id",
    panel: "nursing",
    action: "add_nursing_note",
  },
  "medication-administrations": {
    delegate: "medication_administration",
    admissionField: "admission_id",
    panel: "medication",
    action: "add_medication",
  },
  "discharge-summaries": {
    delegate: "discharge_summary",
    admissionField: "admission_id",
    panel: "discharge",
    action: "plan_discharge",
  },
  "transfer-requests": {
    delegate: "transfer_request",
    admissionField: "admission_id",
    panel: "transfer",
    action: "manage_transfer",
  },
  "icu-stays": {
    delegate: "icu_stay",
    admissionField: "admission_id",
    panel: "stays",
    action: "manage_icu_stay",
  },
  "icu-observations": {
    delegate: "icu_observation",
    admissionField: "icu_stay.admission_id",
    panel: "observations",
    action: "add_icu_observation",
  },
  "critical-alerts": {
    delegate: "critical_alert",
    admissionField: "icu_stay.admission_id",
    panel: "alerts",
    action: "add_critical_alert",
  },
});

const TERMINAL_ADMISSION_STATUSES = new Set(["DISCHARGED", "CANCELLED"]);
const OPEN_TRANSFER_STATUSES = new Set([
  "REQUESTED",
  "APPROVED",
  "IN_PROGRESS",
]);
const IPD_RECIPIENT_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
];

const toDate = (value, fallback = new Date()) => {
  if (!value) return fallback;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? fallback : parsed;
};

const sanitizeIdentifier = (value) => String(value || "").trim();
const isUuidLike = (value) => UUID_LIKE_REGEX.test(sanitizeIdentifier(value));
const normalizeQueueScope = (value) =>
  String(value || QUEUE_SCOPES.ACTIVE)
    .trim()
    .toUpperCase() === QUEUE_SCOPES.ALL
    ? QUEUE_SCOPES.ALL
    : QUEUE_SCOPES.ACTIVE;
const normalizeIcuQueueScope = (value) => {
  const normalized = String(value || ICU_QUEUE_SCOPES.ALL)
    .trim()
    .toUpperCase();
  if (normalized === ICU_QUEUE_SCOPES.WITH_ICU)
    return ICU_QUEUE_SCOPES.WITH_ICU;
  if (normalized === ICU_QUEUE_SCOPES.ACTIVE) return ICU_QUEUE_SCOPES.ACTIVE;
  return ICU_QUEUE_SCOPES.ALL;
};
const parseBooleanString = (value) => {
  if (typeof value === "boolean") return value;
  const normalized = String(value || "")
    .trim()
    .toLowerCase();
  if (["1", "true", "yes", "on"].includes(normalized)) return true;
  if (["0", "false", "no", "off"].includes(normalized)) return false;
  return null;
};
const toBooleanFlag = (value, fallback = false) => {
  if (typeof value === "boolean") return value;
  const parsed = parseBooleanString(value);
  if (parsed === null) return fallback;
  return parsed;
};

const toPublicScalarIdentifier = (value) => {
  const normalized = sanitizeIdentifier(value);
  if (!normalized) return null;
  return isUuidLike(normalized) ? null : normalized;
};

const resolvePublicIdentifier = (record) => {
  if (!record) return null;
  if (typeof record === "string") return toPublicScalarIdentifier(record);
  return toPublicScalarIdentifier(record.human_friendly_id) || null;
};

const resolvePatientDisplayName = (patient) => {
  const firstName = sanitizeIdentifier(patient?.first_name);
  const lastName = sanitizeIdentifier(patient?.last_name);
  return [firstName, lastName].filter(Boolean).join(" ").trim();
};

const parseDoseAndUnit = (value) => {
  const text = sanitizeIdentifier(value);
  if (!text) return { dose: null, unit: null };

  const matched = text.match(/^([\d./]+(?:\s*-\s*[\d./]+)?)\s*(.+)$/);
  if (matched) {
    return {
      dose: sanitizeIdentifier(matched[1]) || null,
      unit: sanitizeIdentifier(matched[2]) || null,
    };
  }

  return {
    dose: text,
    unit: null,
  };
};

const buildMedicationSuggestionLabel = ({
  drugName,
  strength,
  dosage,
  route,
  frequency,
}) => {
  return [drugName, dosage || strength, route, frequency]
    .map(sanitizeIdentifier)
    .filter(Boolean)
    .join(" | ");
};

const mapMedicationSuggestion = (item) => {
  if (!item) return null;

  const dosageLabel =
    sanitizeIdentifier(item?.dosage) ||
    sanitizeIdentifier(item?.drug?.strength) ||
    "";
  const { dose, unit } = parseDoseAndUnit(dosageLabel);
  const route = sanitizeIdentifier(item?.route) || "ORAL";
  const frequency = normalizeMedicationFrequency(item?.frequency, "ONCE");
  const drugName = sanitizeIdentifier(item?.drug?.name);
  const medicationLabel =
    buildMedicationSuggestionLabel({
      drugName,
      strength: sanitizeIdentifier(item?.drug?.strength),
      dosage: dosageLabel,
      route,
      frequency,
    }) ||
    drugName ||
    dosageLabel;

  return {
    id: resolvePublicIdentifier(item),
    order_id: resolvePublicIdentifier(item?.pharmacy_order),
    drug_id: resolvePublicIdentifier(item?.drug),
    drug_name: drugName || null,
    medication_label: medicationLabel || null,
    dose: dose || null,
    unit: unit || null,
    route,
    frequency,
    order_status: sanitizeIdentifier(item?.pharmacy_order?.status) || null,
    item_status: sanitizeIdentifier(item?.status) || null,
    ordered_at: item?.pharmacy_order?.ordered_at || null,
    dosage: dosageLabel || null,
    form: sanitizeIdentifier(item?.drug?.form) || null,
    strength: sanitizeIdentifier(item?.drug?.strength) || null,
  };
};

const buildMedicationSuggestions = (admission) => {
  const orders = Array.isArray(admission?.encounter?.pharmacy_orders)
    ? admission.encounter.pharmacy_orders
    : [];

  return orders
    .filter(
      (order) =>
        sanitizeIdentifier(order?.status).toUpperCase() !== "CANCELLED",
    )
    .flatMap((order) =>
      (Array.isArray(order?.items) ? order.items : [])
        .filter(
          (item) => sanitizeIdentifier(item?.status).toUpperCase() === "ACTIVE",
        )
        .map((item) =>
          mapMedicationSuggestion({ ...item, pharmacy_order: order }),
        ),
    )
    .filter(Boolean);
};

const mapMedicationReminder = (entry) => {
  if (!entry) return null;
  const metadata = parseIpdMedicationReminderNote(entry.notes);
  if (!metadata) return null;

  return {
    id: resolvePublicIdentifier(entry),
    scheduled_at: entry.scheduled_at || null,
    status: sanitizeIdentifier(entry.status) || null,
    created_at: entry.created_at || null,
    completed_at: entry.completed_at || null,
    note: metadata.display_note || null,
    medication_label:
      metadata.medication_label ||
      [metadata.dose, metadata.unit, metadata.route]
        .filter(Boolean)
        .join(" | ") ||
      null,
    dose: metadata.dose || null,
    unit: metadata.unit || null,
    route: metadata.route || null,
    frequency: metadata.frequency || null,
    prescription_id: metadata.prescription_public_id || null,
    occurrence: Number(metadata.occurrence || 0),
    total_occurrences: Number(metadata.total_occurrences || 0),
    admission_id: metadata.admission_public_id || null,
    encounter_id: metadata.encounter_public_id || null,
  };
};

const buildMedicationReminders = (admission) => {
  const reminders = Array.isArray(admission?.encounter?.follow_ups)
    ? admission.encounter.follow_ups
    : [];
  const admissionPublicId = resolvePublicIdentifier(admission);

  return reminders
    .map(mapMedicationReminder)
    .filter(
      (entry) =>
        entry &&
        (!entry.admission_id ||
          !admissionPublicId ||
          entry.admission_id.toUpperCase() === admissionPublicId.toUpperCase()),
    );
};

const buildMedicationReminderSchedule = ({
  administeredAt,
  reminderFirstAt,
  occurrences,
  intervalHours,
}) => {
  const safeOccurrences = Math.max(1, Number(occurrences || 1));
  const firstAt = toDate(reminderFirstAt || administeredAt, administeredAt);

  return Array.from({ length: safeOccurrences }, (_entry, index) => {
    if (index === 0) return firstAt;
    return new Date(firstAt.getTime() + intervalHours * index * 60 * 60 * 1000);
  });
};

const getNestedValue = (source, path) => {
  if (!source || !path) return null;
  return String(path)
    .split(".")
    .reduce(
      (cursor, key) =>
        cursor && cursor[key] !== undefined ? cursor[key] : null,
      source,
    );
};

const normalizeQueryOptions = (queryOptions) => {
  if (!queryOptions) {
    return { select: { id: true } };
  }

  if (queryOptions.select || queryOptions.include) {
    return queryOptions;
  }

  return { select: queryOptions };
};

const resolveByIdentifier = async (
  delegate,
  identifier,
  where = {},
  queryOptions = { select: { id: true } },
) => {
  const normalized = sanitizeIdentifier(identifier);
  if (!normalized || !delegate || typeof delegate.findFirst !== "function")
    return null;
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

const resolveAdmissionByIdentifier = (tx, identifier) =>
  resolveByIdentifier(
    tx.admission,
    identifier,
    {},
    {
      id: true,
      tenant_id: true,
      facility_id: true,
      status: true,
      patient_id: true,
    },
  );

const resolveTenantByIdentifier = (tx, identifier) =>
  resolveByIdentifier(tx.tenant, identifier, {}, { id: true });

const resolveFacilityByIdentifier = (tx, identifier, tenantId = null) =>
  resolveByIdentifier(
    tx.facility,
    identifier,
    tenantId ? { tenant_id: tenantId } : {},
    {
      id: true,
      tenant_id: true,
    },
  );

const resolvePatientByIdentifier = (
  tx,
  identifier,
  tenantId = null,
  facilityId = null,
) =>
  resolveByIdentifier(
    tx.patient,
    identifier,
    {
      ...(tenantId ? { tenant_id: tenantId } : {}),
      ...(facilityId ? { facility_id: facilityId } : {}),
    },
    {
      id: true,
      tenant_id: true,
      facility_id: true,
    },
  );

const resolveEncounterByIdentifier = (
  tx,
  identifier,
  tenantId = null,
  facilityId = null,
) =>
  resolveByIdentifier(
    tx.encounter,
    identifier,
    {
      ...(tenantId ? { tenant_id: tenantId } : {}),
      ...(facilityId ? { facility_id: facilityId } : {}),
    },
    {
      id: true,
      tenant_id: true,
      facility_id: true,
      patient_id: true,
    },
  );

const resolvePharmacyOrderItemByIdentifier = async (
  tx,
  identifier,
  encounterId = null,
  patientId = null,
) =>
  resolveByIdentifier(
    tx.pharmacy_order_item,
    identifier,
    {
      pharmacy_order: {
        is: {
          deleted_at: null,
          ...(encounterId ? { encounter_id: encounterId } : {}),
          ...(patientId ? { patient_id: patientId } : {}),
        },
      },
    },
    {
      id: true,
      human_friendly_id: true,
      dosage: true,
      frequency: true,
      route: true,
      status: true,
      drug: {
        select: {
          id: true,
          human_friendly_id: true,
          name: true,
          form: true,
          strength: true,
        },
      },
      pharmacy_order: {
        select: {
          id: true,
          human_friendly_id: true,
          status: true,
          ordered_at: true,
        },
      },
    },
  );

const resolveBedByIdentifier = (
  tx,
  identifier,
  tenantId = null,
  facilityId = null,
) =>
  resolveByIdentifier(
    tx.bed,
    identifier,
    {
      ...(tenantId ? { tenant_id: tenantId } : {}),
      ...(facilityId ? { facility_id: facilityId } : {}),
    },
    {
      id: true,
      status: true,
      ward_id: true,
      room_id: true,
      tenant_id: true,
      facility_id: true,
      human_friendly_id: true,
      label: true,
    },
  );

const resolveWardByIdentifier = (
  tx,
  identifier,
  tenantId = null,
  facilityId = null,
) =>
  resolveByIdentifier(
    tx.ward,
    identifier,
    {
      ...(tenantId ? { tenant_id: tenantId } : {}),
      ...(facilityId ? { facility_id: facilityId } : {}),
    },
    {
      id: true,
      name: true,
      tenant_id: true,
      facility_id: true,
      human_friendly_id: true,
    },
  );

const resolveRoomByIdentifier = (
  tx,
  identifier,
  tenantId = null,
  facilityId = null,
) =>
  resolveByIdentifier(
    tx.room,
    identifier,
    {
      ...(tenantId ? { tenant_id: tenantId } : {}),
      ...(facilityId ? { facility_id: facilityId } : {}),
    },
    {
      id: true,
      ward_id: true,
      tenant_id: true,
      facility_id: true,
      human_friendly_id: true,
      name: true,
    },
  );

const resolveUserByIdentifier = (
  tx,
  identifier,
  tenantId = null,
  facilityId = null,
) =>
  resolveByIdentifier(
    tx.user,
    identifier,
    {
      ...(tenantId ? { tenant_id: tenantId } : {}),
      ...(facilityId ? { facility_id: facilityId } : {}),
    },
    {
      id: true,
    },
  );

const resolveStaffProfileByIdentifier = (
  tx,
  identifier,
  tenantId = null,
  facilityId = null,
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
      user_id: true,
      user: {
        select: {
          id: true,
          human_friendly_id: true,
        },
      },
    },
  );

const resolveTransferByIdentifier = (tx, identifier, admissionId = null) =>
  resolveByIdentifier(
    tx.transfer_request,
    identifier,
    admissionId ? { admission_id: admissionId } : {},
    {
      id: true,
      admission_id: true,
      status: true,
    },
  );

const resolveIcuStayByIdentifier = (tx, identifier, admissionId = null) =>
  resolveByIdentifier(
    tx.icu_stay,
    identifier,
    admissionId ? { admission_id: admissionId } : {},
    {
      id: true,
      admission_id: true,
      ended_at: true,
    },
  );

const resolveCriticalAlertByIdentifier = (tx, identifier) =>
  resolveByIdentifier(
    tx.critical_alert,
    identifier,
    {},
    {
      id: true,
      icu_stay_id: true,
    },
  );

const getActiveBedAssignment = (admission) =>
  (Array.isArray(admission?.bed_assignments)
    ? admission.bed_assignments
    : []
  ).find((item) => !item.released_at && !item.deleted_at) || null;

const getOpenTransferRequest = (admission) =>
  (Array.isArray(admission?.transfer_requests)
    ? admission.transfer_requests
    : []
  ).find((item) =>
    OPEN_TRANSFER_STATUSES.has(String(item?.status || "").toUpperCase()),
  ) || null;

const getLatestDischargeSummary = (admission) =>
  (Array.isArray(admission?.discharge_summaries)
    ? admission.discharge_summaries
    : [])[0] || null;

const getIcuStays = (admission) =>
  Array.isArray(admission?.icu_stays)
    ? admission.icu_stays
        .filter((stay) => stay && !stay.deleted_at)
        .sort((left, right) => {
          const leftTs =
            new Date(left?.started_at || left?.created_at || 0).getTime() || 0;
          const rightTs =
            new Date(right?.started_at || right?.created_at || 0).getTime() ||
            0;
          return rightTs - leftTs;
        })
    : [];

const getIcuStayObservations = (stay) =>
  Array.isArray(stay?.observations)
    ? stay.observations
        .filter((entry) => entry && !entry.deleted_at)
        .sort((left, right) => {
          const leftTs =
            new Date(left?.observed_at || left?.created_at || 0).getTime() || 0;
          const rightTs =
            new Date(right?.observed_at || right?.created_at || 0).getTime() ||
            0;
          return rightTs - leftTs;
        })
    : [];

const getIcuStayAlerts = (stay) =>
  Array.isArray(stay?.alerts)
    ? stay.alerts
        .filter((entry) => entry && !entry.deleted_at)
        .sort((left, right) => {
          const leftTs = new Date(left?.created_at || 0).getTime() || 0;
          const rightTs = new Date(right?.created_at || 0).getTime() || 0;
          return rightTs - leftTs;
        })
    : [];

const getActiveIcuStay = (admission) =>
  getIcuStays(admission).find((stay) => !stay.ended_at) || null;

const getLatestIcuStay = (admission) => getIcuStays(admission)[0] || null;

const deriveIcuStatus = (admission) => {
  const icuStays = getIcuStays(admission);
  if (!icuStays.length) return ICU_STATUSES.NONE;
  if (icuStays.some((stay) => !stay.ended_at)) return ICU_STATUSES.ACTIVE;
  return ICU_STATUSES.ENDED;
};

const getSeverityScore = (severity) =>
  CRITICAL_SEVERITY_ORDER[String(severity || "").toUpperCase()] || 0;

const getHighestSeverity = (alerts = []) =>
  alerts.reduce((highest, entry) => {
    const severity = String(entry?.severity || "").toUpperCase();
    if (getSeverityScore(severity) > getSeverityScore(highest)) return severity;
    return highest;
  }, null);
const deriveIpdStage = ({
  admission,
  activeBedAssignment,
  openTransferRequest,
  latestDischargeSummary,
}) => {
  const admissionStatus = String(admission?.status || "").toUpperCase();
  if (admissionStatus === "CANCELLED") return STAGES.CANCELLED;
  if (admissionStatus === "DISCHARGED") return STAGES.DISCHARGED;

  const dischargeStatus = String(
    latestDischargeSummary?.status || "",
  ).toUpperCase();
  if (dischargeStatus === "PLANNED") return STAGES.DISCHARGE_PLANNED;

  const transferStatus = String(
    openTransferRequest?.status || "",
  ).toUpperCase();
  if (transferStatus === "IN_PROGRESS") return STAGES.TRANSFER_IN_PROGRESS;
  if (transferStatus === "REQUESTED" || transferStatus === "APPROVED")
    return STAGES.TRANSFER_REQUESTED;

  return activeBedAssignment
    ? STAGES.ADMITTED_IN_BED
    : STAGES.ADMITTED_PENDING_BED;
};

const deriveNextStep = (stage, openTransferRequest = null) => {
  if (stage === STAGES.ADMITTED_PENDING_BED) return "ASSIGN_BED";
  if (stage === STAGES.ADMITTED_IN_BED) return "RECORD_NURSING_NOTE";
  if (stage === STAGES.TRANSFER_REQUESTED) {
    return String(openTransferRequest?.status || "").toUpperCase() ===
      "APPROVED"
      ? "START_TRANSFER"
      : "APPROVE_TRANSFER";
  }
  if (stage === STAGES.TRANSFER_IN_PROGRESS) return "COMPLETE_TRANSFER";
  if (stage === STAGES.DISCHARGE_PLANNED) return "FINALIZE_DISCHARGE";
  return null;
};

const buildFlowSummary = (snapshot) => ({
  stage: snapshot?.flow?.stage || null,
  next_step: snapshot?.flow?.next_step || null,
  admission_status: snapshot?.admission?.status || null,
  has_active_bed: Boolean(snapshot?.active_bed_assignment),
  transfer_status: snapshot?.open_transfer_request?.status || null,
});

const buildIcuOverlay = (admission) => {
  const icuStays = getIcuStays(admission);
  const activeStay = icuStays.find((stay) => !stay.ended_at) || null;
  const latestStay = icuStays[0] || null;
  const recentStays = icuStays.slice(0, 5);

  const allObservations = icuStays
    .flatMap((stay) =>
      getIcuStayObservations(stay).map((entry) => ({
        ...entry,
        icu_stay_id: stay.id,
      })),
    )
    .sort((left, right) => {
      const leftTs =
        new Date(left?.observed_at || left?.created_at || 0).getTime() || 0;
      const rightTs =
        new Date(right?.observed_at || right?.created_at || 0).getTime() || 0;
      return rightTs - leftTs;
    });

  const allAlerts = icuStays
    .flatMap((stay) =>
      getIcuStayAlerts(stay).map((entry) => ({
        ...entry,
        icu_stay_id: stay.id,
      })),
    )
    .sort((left, right) => {
      const leftTs = new Date(left?.created_at || 0).getTime() || 0;
      const rightTs = new Date(right?.created_at || 0).getTime() || 0;
      return rightTs - leftTs;
    });

  const activeAlerts = activeStay
    ? allAlerts.filter(
        (entry) =>
          String(entry?.icu_stay_id || "") === String(activeStay.id || ""),
      )
    : [];

  const targetAlerts = activeAlerts.length ? activeAlerts : allAlerts;
  const criticalAlertSummary = {
    total: targetAlerts.length,
    highest_severity: getHighestSeverity(targetAlerts),
    by_severity: {
      LOW: targetAlerts.filter(
        (entry) => String(entry?.severity || "").toUpperCase() === "LOW",
      ).length,
      MEDIUM: targetAlerts.filter(
        (entry) => String(entry?.severity || "").toUpperCase() === "MEDIUM",
      ).length,
      HIGH: targetAlerts.filter(
        (entry) => String(entry?.severity || "").toUpperCase() === "HIGH",
      ).length,
      CRITICAL: targetAlerts.filter(
        (entry) => String(entry?.severity || "").toUpperCase() === "CRITICAL",
      ).length,
    },
    recent: targetAlerts.slice(0, 10),
  };

  return {
    status: deriveIcuStatus(admission),
    has_critical_alert: criticalAlertSummary.total > 0,
    critical_severity: criticalAlertSummary.highest_severity || null,
    active_stay: activeStay,
    latest_stay: latestStay,
    recent_stays: recentStays,
    recent_observations: allObservations.slice(0, 12),
    critical_alert_summary: criticalAlertSummary,
    recent_alerts: allAlerts.slice(0, 12),
  };
};

const buildIpdSnapshot = (admission, options = {}) => {
  const includeIcu = Boolean(options?.include_icu);
  const activeBedAssignment = getActiveBedAssignment(admission);
  const openTransferRequest = getOpenTransferRequest(admission);
  const latestDischargeSummary = getLatestDischargeSummary(admission);
  const medicationSuggestions = buildMedicationSuggestions(admission);
  const medicationReminders = buildMedicationReminders(admission);

  const stage = deriveIpdStage({
    admission,
    activeBedAssignment,
    openTransferRequest,
    latestDischargeSummary,
  });

  const snapshot = {
    admission: {
      id: admission.id,
      human_friendly_id: admission.human_friendly_id || null,
      tenant_id: admission.tenant_id,
      facility_id: admission.facility_id || null,
      patient_id: admission.patient_id,
      encounter_id: admission.encounter_id || null,
      status: admission.status,
      admitted_at: admission.admitted_at,
      discharged_at: admission.discharged_at || null,
      created_at: admission.created_at,
      updated_at: admission.updated_at,
    },
    patient: admission.patient || null,
    encounter: admission.encounter || null,
    facility: admission.facility || null,
    tenant: admission.tenant || null,
    active_bed_assignment: activeBedAssignment || null,
    open_transfer_request: openTransferRequest || null,
    latest_discharge_summary: latestDischargeSummary || null,
    transfer_requests: Array.isArray(admission.transfer_requests)
      ? admission.transfer_requests
      : [],
    discharge_summaries: Array.isArray(admission.discharge_summaries)
      ? admission.discharge_summaries
      : [],
    ward_rounds: Array.isArray(admission.ward_rounds)
      ? admission.ward_rounds
      : [],
    nursing_notes: Array.isArray(admission.nursing_notes)
      ? admission.nursing_notes
      : [],
    medication_administrations: Array.isArray(
      admission.medication_administrations,
    )
      ? admission.medication_administrations
      : [],
    medication_suggestions: medicationSuggestions,
    medication_reminders: medicationReminders,
    flow: {
      stage,
      next_step: deriveNextStep(stage, openTransferRequest),
      transfer_status: openTransferRequest?.status || null,
      has_active_bed: Boolean(activeBedAssignment),
      admission_status: admission.status,
    },
    icu: includeIcu ? buildIcuOverlay(admission) : null,
  };

  snapshot.flow_summary = buildFlowSummary(snapshot);
  return snapshot;
};

const mapPublicWard = (ward) => {
  if (!ward) return null;
  return {
    id: resolvePublicIdentifier(ward),
    name: sanitizeIdentifier(ward.name) || null,
    ward_type: sanitizeIdentifier(ward.ward_type) || null,
  };
};

const mapPublicRoom = (room) => {
  if (!room) return null;
  return {
    id: resolvePublicIdentifier(room),
    name: sanitizeIdentifier(room.name) || null,
    floor: room.floor ?? null,
  };
};

const mapPublicBed = (bed) => {
  if (!bed) return null;
  return {
    id: resolvePublicIdentifier(bed),
    label: sanitizeIdentifier(bed.label) || null,
    status: sanitizeIdentifier(bed.status) || null,
    ward: mapPublicWard(bed.ward),
    room: mapPublicRoom(bed.room),
  };
};

const mapPublicBedAssignment = (assignment) => {
  if (!assignment) return null;
  return {
    id: resolvePublicIdentifier(assignment),
    assigned_at: assignment.assigned_at || null,
    released_at: assignment.released_at || null,
    bed: mapPublicBed(assignment.bed),
  };
};

const mapPublicTransferRequest = (request) => {
  if (!request) return null;
  return {
    id: resolvePublicIdentifier(request),
    status: sanitizeIdentifier(request.status) || null,
    requested_at: request.requested_at || null,
    from_ward: mapPublicWard(request.from_ward),
    to_ward: mapPublicWard(request.to_ward),
  };
};

const mapPublicDischargeSummary = (summary) => {
  if (!summary) return null;
  return {
    id: resolvePublicIdentifier(summary),
    status: sanitizeIdentifier(summary.status) || null,
    summary: summary.summary || null,
    discharged_at: summary.discharged_at || null,
    created_at: summary.created_at || null,
    updated_at: summary.updated_at || null,
  };
};

const mapPublicWardRound = (round) => {
  if (!round) return null;
  return {
    id: resolvePublicIdentifier(round),
    round_at: round.round_at || null,
    notes: round.notes || null,
    created_at: round.created_at || null,
  };
};

const resolveUserDisplayName = (user) => {
  if (!user || !user.profile) return "";
  const first = sanitizeIdentifier(user.profile.first_name);
  const middle = sanitizeIdentifier(user.profile.middle_name);
  const last = sanitizeIdentifier(user.profile.last_name);
  return [first, middle, last].filter(Boolean).join(" ").trim();
};

const mapPublicNursingNote = (note) => {
  if (!note) return null;
  return {
    id: resolvePublicIdentifier(note),
    nurse_user_id: resolvePublicIdentifier(note.nurse),
    nurse_name:
      resolveUserDisplayName(note.nurse) ||
      sanitizeIdentifier(note.nurse?.email) ||
      null,
    note: note.note || null,
    created_at: note.created_at || null,
  };
};

const mapPublicMedicationAdministration = (entry) => {
  if (!entry) return null;
  return {
    id: resolvePublicIdentifier(entry),
    prescription_id: toPublicScalarIdentifier(entry.prescription_id),
    administered_at: entry.administered_at || null,
    dose: entry.dose || null,
    unit: entry.unit || null,
    route: sanitizeIdentifier(entry.route) || null,
    created_at: entry.created_at || null,
  };
};

const mapPublicMedicationSuggestion = (entry) => {
  if (!entry) return null;
  return {
    id: sanitizeIdentifier(entry.id) || null,
    order_id: sanitizeIdentifier(entry.order_id) || null,
    drug_id: sanitizeIdentifier(entry.drug_id) || null,
    drug_name: sanitizeIdentifier(entry.drug_name) || null,
    medication_label: sanitizeIdentifier(entry.medication_label) || null,
    dose: sanitizeIdentifier(entry.dose) || null,
    unit: sanitizeIdentifier(entry.unit) || null,
    route: sanitizeIdentifier(entry.route) || null,
    frequency: sanitizeIdentifier(entry.frequency) || null,
    order_status: sanitizeIdentifier(entry.order_status) || null,
    item_status: sanitizeIdentifier(entry.item_status) || null,
    ordered_at: entry.ordered_at || null,
    dosage: sanitizeIdentifier(entry.dosage) || null,
    form: sanitizeIdentifier(entry.form) || null,
    strength: sanitizeIdentifier(entry.strength) || null,
  };
};

const mapPublicMedicationReminder = (entry) => {
  if (!entry) return null;
  return {
    id: sanitizeIdentifier(entry.id) || null,
    scheduled_at: entry.scheduled_at || null,
    status: sanitizeIdentifier(entry.status) || null,
    created_at: entry.created_at || null,
    completed_at: entry.completed_at || null,
    note: sanitizeIdentifier(entry.note) || null,
    medication_label: sanitizeIdentifier(entry.medication_label) || null,
    dose: sanitizeIdentifier(entry.dose) || null,
    unit: sanitizeIdentifier(entry.unit) || null,
    route: sanitizeIdentifier(entry.route) || null,
    frequency: sanitizeIdentifier(entry.frequency) || null,
    prescription_id: sanitizeIdentifier(entry.prescription_id) || null,
    occurrence: Number(entry.occurrence || 0),
    total_occurrences: Number(entry.total_occurrences || 0),
    admission_id: sanitizeIdentifier(entry.admission_id) || null,
    encounter_id: sanitizeIdentifier(entry.encounter_id) || null,
  };
};

const mapPublicIcuStay = (stay) => {
  if (!stay) return null;
  return {
    id: resolvePublicIdentifier(stay),
    display_id: resolvePublicIdentifier(stay),
    started_at: stay.started_at || null,
    ended_at: stay.ended_at || null,
    created_at: stay.created_at || null,
  };
};

const mapPublicIcuObservation = (entry) => {
  if (!entry) return null;
  return {
    id: resolvePublicIdentifier(entry),
    display_id: resolvePublicIdentifier(entry),
    icu_stay_id: toPublicScalarIdentifier(entry.icu_stay_id),
    observed_at: entry.observed_at || null,
    observation: entry.observation || null,
    created_at: entry.created_at || null,
  };
};

const mapPublicCriticalAlert = (entry) => {
  if (!entry) return null;
  return {
    id: resolvePublicIdentifier(entry),
    display_id: resolvePublicIdentifier(entry),
    icu_stay_id: toPublicScalarIdentifier(entry.icu_stay_id),
    severity: sanitizeIdentifier(entry.severity) || null,
    message: entry.message || null,
    created_at: entry.created_at || null,
  };
};

const mapPublicIcuOverlay = (overlay) => {
  if (!overlay) return null;

  const activeStay = mapPublicIcuStay(overlay.active_stay);
  const latestStay = mapPublicIcuStay(overlay.latest_stay);
  const recentStays = (
    Array.isArray(overlay.recent_stays) ? overlay.recent_stays : []
  )
    .map(mapPublicIcuStay)
    .filter(Boolean);
  const recentObservations = (
    Array.isArray(overlay.recent_observations)
      ? overlay.recent_observations
      : []
  )
    .map(mapPublicIcuObservation)
    .filter(Boolean);
  const recentAlerts = (
    Array.isArray(overlay.recent_alerts) ? overlay.recent_alerts : []
  )
    .map(mapPublicCriticalAlert)
    .filter(Boolean);

  return {
    status: sanitizeIdentifier(overlay.status) || null,
    has_critical_alert: Boolean(overlay.has_critical_alert),
    critical_severity: sanitizeIdentifier(overlay.critical_severity) || null,
    active_stay: activeStay,
    latest_stay: latestStay,
    recent_stays: recentStays,
    recent_observations: recentObservations,
    recent_alerts: recentAlerts,
    critical_alert_summary: {
      total: Number(overlay?.critical_alert_summary?.total || 0),
      highest_severity:
        sanitizeIdentifier(overlay?.critical_alert_summary?.highest_severity) ||
        null,
      by_severity: {
        LOW: Number(overlay?.critical_alert_summary?.by_severity?.LOW || 0),
        MEDIUM: Number(
          overlay?.critical_alert_summary?.by_severity?.MEDIUM || 0,
        ),
        HIGH: Number(overlay?.critical_alert_summary?.by_severity?.HIGH || 0),
        CRITICAL: Number(
          overlay?.critical_alert_summary?.by_severity?.CRITICAL || 0,
        ),
      },
      recent: (Array.isArray(overlay?.critical_alert_summary?.recent)
        ? overlay.critical_alert_summary.recent
        : []
      )
        .map(mapPublicCriticalAlert)
        .filter(Boolean),
    },
  };
};

const buildPublicTimeline = (snapshot) => {
  const events = [];

  (Array.isArray(snapshot?.ward_rounds) ? snapshot.ward_rounds : []).forEach(
    (round) => {
      events.push({
        type: "WARD_ROUND",
        at: round.round_at || round.created_at || null,
        label: round.notes || "Ward round recorded",
      });
    },
  );

  (Array.isArray(snapshot?.nursing_notes)
    ? snapshot.nursing_notes
    : []
  ).forEach((note) => {
    events.push({
      type: "NURSING_NOTE",
      at: note.created_at || null,
      label: note.note || "Nursing note recorded",
    });
  });

  (Array.isArray(snapshot?.medication_administrations)
    ? snapshot.medication_administrations
    : []
  ).forEach((entry) => {
    events.push({
      type: "MEDICATION_ADMINISTRATION",
      at: entry.administered_at || entry.created_at || null,
      label: sanitizeIdentifier(entry.dose)
        ? `Dose ${entry.dose}${entry.unit ? ` ${entry.unit}` : ""}`
        : "Medication recorded",
    });
  });

  (Array.isArray(snapshot?.medication_reminders)
    ? snapshot.medication_reminders
    : []
  ).forEach((entry) => {
    events.push({
      type: "MEDICATION_REMINDER",
      at: entry.scheduled_at || entry.created_at || null,
      label:
        sanitizeIdentifier(entry.medication_label) ||
        sanitizeIdentifier(entry.note) ||
        "Medication reminder scheduled",
    });
  });

  (Array.isArray(snapshot?.transfer_requests)
    ? snapshot.transfer_requests
    : []
  ).forEach((request) => {
    events.push({
      type: "TRANSFER",
      at: request.requested_at || null,
      label: `Transfer ${sanitizeIdentifier(request.status) || "UPDATED"}`,
    });
  });

  (Array.isArray(snapshot?.icu?.recent_observations)
    ? snapshot.icu.recent_observations
    : []
  ).forEach((entry) => {
    events.push({
      type: "ICU_OBSERVATION",
      at: entry.observed_at || entry.created_at || null,
      label:
        sanitizeIdentifier(entry.observation) || "ICU observation recorded",
    });
  });

  (Array.isArray(snapshot?.icu?.recent_alerts)
    ? snapshot.icu.recent_alerts
    : []
  ).forEach((entry) => {
    events.push({
      type: "CRITICAL_ALERT",
      at: entry.created_at || null,
      label: `${sanitizeIdentifier(entry.severity) || "ALERT"}: ${sanitizeIdentifier(entry.message) || "Critical alert raised"}`,
    });
  });

  return events
    .filter((entry) => sanitizeIdentifier(entry.at))
    .sort((left, right) => {
      const leftTs = new Date(left.at).getTime() || 0;
      const rightTs = new Date(right.at).getTime() || 0;
      return rightTs - leftTs;
    });
};

const toPublicIpdSnapshot = (snapshot) => {
  const admissionPublicId = resolvePublicIdentifier(snapshot?.admission);
  const patientPublicId = resolvePublicIdentifier(snapshot?.patient);
  const encounterPublicId = resolvePublicIdentifier(snapshot?.encounter);
  const activeBed = mapPublicBedAssignment(snapshot?.active_bed_assignment);
  const openTransfer = mapPublicTransferRequest(
    snapshot?.open_transfer_request,
  );
  const latestDischarge = mapPublicDischargeSummary(
    snapshot?.latest_discharge_summary,
  );
  const patientName = resolvePatientDisplayName(snapshot?.patient);
  const icuOverlay = mapPublicIcuOverlay(snapshot?.icu);

  const publicSnapshot = {
    id: admissionPublicId,
    human_friendly_id: admissionPublicId,
    display_id: admissionPublicId,
    admission: {
      id: admissionPublicId,
      status: sanitizeIdentifier(snapshot?.admission?.status) || null,
      admitted_at: snapshot?.admission?.admitted_at || null,
      discharged_at: snapshot?.admission?.discharged_at || null,
      created_at: snapshot?.admission?.created_at || null,
      updated_at: snapshot?.admission?.updated_at || null,
    },
    tenant: snapshot?.tenant
      ? {
          id: resolvePublicIdentifier(snapshot.tenant),
          name: sanitizeIdentifier(snapshot.tenant.name) || null,
        }
      : null,
    facility: snapshot?.facility
      ? {
          id: resolvePublicIdentifier(snapshot.facility),
          name: sanitizeIdentifier(snapshot.facility.name) || null,
          facility_type:
            sanitizeIdentifier(snapshot.facility.facility_type) || null,
        }
      : null,
    patient: snapshot?.patient
      ? {
          id: patientPublicId,
          first_name: snapshot.patient.first_name || null,
          last_name: snapshot.patient.last_name || null,
          date_of_birth: snapshot.patient.date_of_birth || null,
          gender: sanitizeIdentifier(snapshot.patient.gender) || null,
        }
      : null,
    encounter: snapshot?.encounter
      ? {
          id: encounterPublicId,
          encounter_type:
            sanitizeIdentifier(snapshot.encounter.encounter_type) || null,
          status: sanitizeIdentifier(snapshot.encounter.status) || null,
          started_at: snapshot.encounter.started_at || null,
          ended_at: snapshot.encounter.ended_at || null,
          provider_user_id: null,
        }
      : null,
    active_bed_assignment: activeBed,
    open_transfer_request: openTransfer,
    latest_discharge_summary: latestDischarge,
    transfer_requests: (Array.isArray(snapshot?.transfer_requests)
      ? snapshot.transfer_requests
      : []
    )
      .map(mapPublicTransferRequest)
      .filter(Boolean),
    discharge_summaries: (Array.isArray(snapshot?.discharge_summaries)
      ? snapshot.discharge_summaries
      : []
    )
      .map(mapPublicDischargeSummary)
      .filter(Boolean),
    ward_rounds: (Array.isArray(snapshot?.ward_rounds)
      ? snapshot.ward_rounds
      : []
    )
      .map(mapPublicWardRound)
      .filter(Boolean),
    nursing_notes: (Array.isArray(snapshot?.nursing_notes)
      ? snapshot.nursing_notes
      : []
    )
      .map(mapPublicNursingNote)
      .filter(Boolean),
    medication_administrations: (Array.isArray(
      snapshot?.medication_administrations,
    )
      ? snapshot.medication_administrations
      : []
    )
      .map(mapPublicMedicationAdministration)
      .filter(Boolean),
    medication_suggestions: (Array.isArray(snapshot?.medication_suggestions)
      ? snapshot.medication_suggestions
      : []
    )
      .map(mapPublicMedicationSuggestion)
      .filter(Boolean),
    medication_reminders: (Array.isArray(snapshot?.medication_reminders)
      ? snapshot.medication_reminders
      : []
    )
      .map(mapPublicMedicationReminder)
      .filter(Boolean),
    flow: {
      stage: sanitizeIdentifier(snapshot?.flow?.stage) || null,
      next_step: sanitizeIdentifier(snapshot?.flow?.next_step) || null,
      transfer_status:
        sanitizeIdentifier(snapshot?.flow?.transfer_status) || null,
      has_active_bed: Boolean(snapshot?.flow?.has_active_bed),
      admission_status:
        sanitizeIdentifier(snapshot?.flow?.admission_status) || null,
    },
    flow_summary: {
      stage: sanitizeIdentifier(snapshot?.flow_summary?.stage) || null,
      next_step: sanitizeIdentifier(snapshot?.flow_summary?.next_step) || null,
      admission_status:
        sanitizeIdentifier(snapshot?.flow_summary?.admission_status) || null,
      has_active_bed: Boolean(snapshot?.flow_summary?.has_active_bed),
      transfer_status:
        sanitizeIdentifier(snapshot?.flow_summary?.transfer_status) || null,
    },
    stage: sanitizeIdentifier(snapshot?.flow?.stage) || null,
    next_step: sanitizeIdentifier(snapshot?.flow?.next_step) || null,
    transfer_status:
      sanitizeIdentifier(snapshot?.flow?.transfer_status) || null,
    patient_display_name: patientName || patientPublicId || null,
    patient_display_id: patientPublicId,
    encounter_display_id: encounterPublicId,
    ward_display_name:
      sanitizeIdentifier(activeBed?.bed?.ward?.name) ||
      sanitizeIdentifier(openTransfer?.to_ward?.name) ||
      null,
    icu: icuOverlay,
    icu_status: sanitizeIdentifier(icuOverlay?.status) || null,
    has_critical_alert: Boolean(icuOverlay?.has_critical_alert),
    critical_severity:
      sanitizeIdentifier(icuOverlay?.critical_severity) || null,
    active_icu_stay_id: icuOverlay?.active_stay?.id || null,
    latest_icu_stay_id: icuOverlay?.latest_stay?.id || null,
  };

  publicSnapshot.timeline = buildPublicTimeline(publicSnapshot);
  return publicSnapshot;
};

const toQueueCardDto = (snapshot) => {
  const publicSnapshot = toPublicIpdSnapshot(snapshot);
  return {
    id: publicSnapshot.id,
    admission_id: publicSnapshot.id,
    display_id: publicSnapshot.display_id,
    human_friendly_id: publicSnapshot.human_friendly_id,
    stage: publicSnapshot.stage,
    next_step: publicSnapshot.next_step,
    transfer_status: publicSnapshot.transfer_status,
    has_active_bed: Boolean(publicSnapshot?.flow_summary?.has_active_bed),
    patient_id: publicSnapshot.patient_display_id,
    patient_display_id: publicSnapshot.patient_display_id,
    patient_display_name: publicSnapshot.patient_display_name,
    encounter_display_id: publicSnapshot.encounter_display_id || null,
    ward_display_name: publicSnapshot.ward_display_name,
    room_id: publicSnapshot?.active_bed_assignment?.bed?.room?.id || null,
    room_display_label:
      publicSnapshot?.active_bed_assignment?.bed?.room?.name || null,
    bed_id: publicSnapshot?.active_bed_assignment?.bed?.id || null,
    bed_display_label:
      publicSnapshot?.active_bed_assignment?.bed?.label || null,
    open_transfer_request_id: publicSnapshot?.open_transfer_request?.id || null,
    admitted_at: publicSnapshot?.admission?.admitted_at || null,
    discharged_at: publicSnapshot?.admission?.discharged_at || null,
    discharge_status: publicSnapshot?.latest_discharge_summary?.status || null,
    flow_summary: publicSnapshot.flow_summary,
    admission_status: publicSnapshot?.admission?.status || null,
    icu_status: publicSnapshot?.icu_status || null,
    has_critical_alert: Boolean(publicSnapshot?.has_critical_alert),
    critical_severity: publicSnapshot?.critical_severity || null,
    active_icu_stay_id: publicSnapshot?.active_icu_stay_id || null,
  };
};

const matchesDerivedFilters = (snapshot, filters = {}) => {
  if (filters.stage && snapshot.flow?.stage !== filters.stage) return false;

  if (filters.transfer_status) {
    if (
      String(snapshot?.open_transfer_request?.status || "").toUpperCase() !==
      String(filters.transfer_status).toUpperCase()
    ) {
      return false;
    }
  }

  if (typeof filters.has_active_bed === "boolean") {
    if (Boolean(snapshot?.active_bed_assignment) !== filters.has_active_bed)
      return false;
  }

  if (filters.ward_id) {
    const wardId =
      snapshot?.active_bed_assignment?.bed?.ward_id ||
      snapshot?.active_bed_assignment?.bed?.ward?.id ||
      null;
    if (!wardId || wardId !== filters.ward_id) return false;
  }

  if (filters.icu_status) {
    if (
      String(snapshot?.icu?.status || "").toUpperCase() !==
      String(filters.icu_status || "").toUpperCase()
    ) {
      return false;
    }
  }

  if (typeof filters.has_critical_alert === "boolean") {
    if (
      Boolean(snapshot?.icu?.has_critical_alert) !== filters.has_critical_alert
    )
      return false;
  }

  if (filters.critical_severity) {
    const summarySeverity = String(
      snapshot?.icu?.critical_alert_summary?.highest_severity || "",
    ).toUpperCase();
    if (summarySeverity !== String(filters.critical_severity).toUpperCase())
      return false;
  }

  const icuQueueScope = String(
    filters.icu_queue_scope || ICU_QUEUE_SCOPES.ALL,
  ).toUpperCase();
  if (icuQueueScope === ICU_QUEUE_SCOPES.WITH_ICU) {
    if (String(snapshot?.icu?.status || "").toUpperCase() === ICU_STATUSES.NONE)
      return false;
  }

  if (icuQueueScope === ICU_QUEUE_SCOPES.ACTIVE) {
    if (
      String(snapshot?.icu?.status || "").toUpperCase() !== ICU_STATUSES.ACTIVE
    )
      return false;
  }

  if (filters.queue_scope === QUEUE_SCOPES.ACTIVE && !filters.stage) {
    if (TERMINAL_STAGES.has(snapshot?.flow?.stage)) return false;
  }

  return true;
};

const DETAILED_SNAPSHOT_INCLUDE = {
  encounter: {
    select: {
      id: true,
      human_friendly_id: true,
      encounter_type: true,
      status: true,
      started_at: true,
      ended_at: true,
      provider_user_id: true,
      follow_ups: {
        where: {
          deleted_at: null,
        },
        orderBy: {
          scheduled_at: "asc",
        },
        take: 20,
        select: {
          id: true,
          human_friendly_id: true,
          scheduled_at: true,
          status: true,
          completed_at: true,
          created_at: true,
          notes: true,
        },
      },
      pharmacy_orders: {
        where: {
          deleted_at: null,
        },
        orderBy: {
          ordered_at: "desc",
        },
        take: 10,
        select: {
          id: true,
          human_friendly_id: true,
          status: true,
          ordered_at: true,
          items: {
            where: {
              deleted_at: null,
            },
            orderBy: {
              created_at: "desc",
            },
            select: {
              id: true,
              human_friendly_id: true,
              dosage: true,
              frequency: true,
              route: true,
              status: true,
              drug: {
                select: {
                  id: true,
                  human_friendly_id: true,
                  name: true,
                  form: true,
                  strength: true,
                },
              },
            },
          },
        },
      },
    },
  },
};

const getIpdSnapshotByIdInternal = async (id, options = {}) => {
  const includeIcu = Boolean(options?.include_icu);
  const resolved = await resolveAdmissionByIdentifier(prisma, id);
  if (!resolved) {
    throw new HttpError("errors.ipd_flow.not_found", 404);
  }

  const admission = await ipdFlowRepository.findById(
    resolved.id,
    DETAILED_SNAPSHOT_INCLUDE,
  );
  if (!admission) {
    throw new HttpError("errors.ipd_flow.not_found", 404);
  }

  return buildIpdSnapshot(admission, { include_icu: includeIcu });
};

const getIpdFlowById = async (id, options = {}) =>
  toPublicIpdSnapshot(
    await getIpdSnapshotByIdInternal(id, {
      include_icu: toBooleanFlag(options?.include_icu, false),
    }),
  );

const listIpdFlows = async (
  filters = {},
  page = 1,
  limit = 20,
  sortBy = "admitted_at",
  order = "desc",
) => {
  const currentPage = Math.max(1, Number(page) || 1);
  const currentLimit = Math.max(1, Math.min(100, Number(limit) || 20));
  const skip = (currentPage - 1) * currentLimit;
  const direction =
    String(order || "").toLowerCase() === "asc" ? "asc" : "desc";
  const queueScope = normalizeQueueScope(filters.queue_scope);
  const icuQueueScope = normalizeIcuQueueScope(filters.icu_queue_scope);
  const hasIcuFilters = Boolean(
    filters.icu_status ||
    filters.critical_severity ||
    typeof filters.has_critical_alert === "boolean" ||
    icuQueueScope !== ICU_QUEUE_SCOPES.ALL,
  );
  const includeIcu = toBooleanFlag(filters.include_icu, false) || hasIcuFilters;

  const where = {};

  if (filters.tenant_id) {
    const tenant = await resolveTenantByIdentifier(prisma, filters.tenant_id);
    if (!tenant)
      throw new HttpError("errors.tenant.not_found", 404, [
        { field: "tenant_id" },
      ]);
    where.tenant_id = tenant.id;
  }

  if (filters.facility_id) {
    const facility = await resolveFacilityByIdentifier(
      prisma,
      filters.facility_id,
      where.tenant_id || null,
    );
    if (!facility)
      throw new HttpError("errors.facility.not_found", 404, [
        { field: "facility_id" },
      ]);
    where.facility_id = facility.id;
    if (!where.tenant_id) where.tenant_id = facility.tenant_id;
  }

  if (filters.patient_id) {
    const patient = await resolvePatientByIdentifier(
      prisma,
      filters.patient_id,
      where.tenant_id || null,
      where.facility_id || null,
    );

    if (!patient)
      throw new HttpError("errors.ipd_flow.patient_not_found", 404, [
        { field: "patient_id" },
      ]);
    where.patient_id = patient.id;
  }

  if (queueScope === QUEUE_SCOPES.ACTIVE && !filters.stage) {
    where.status = { notIn: ["DISCHARGED", "CANCELLED"] };
  }

  if (includeIcu && icuQueueScope === ICU_QUEUE_SCOPES.WITH_ICU) {
    where.icu_stays = {
      some: {
        deleted_at: null,
      },
    };
  }

  if (includeIcu && icuQueueScope === ICU_QUEUE_SCOPES.ACTIVE) {
    where.icu_stays = {
      some: {
        deleted_at: null,
        ended_at: null,
      },
    };
  }

  const searchText = sanitizeIdentifier(filters.search);
  if (searchText) {
    where.OR = [
      { human_friendly_id: { contains: searchText } },
      { patient: { is: { human_friendly_id: { contains: searchText } } } },
      { patient: { is: { first_name: { contains: searchText } } } },
      { patient: { is: { last_name: { contains: searchText } } } },
      { encounter: { is: { human_friendly_id: { contains: searchText } } } },
    ];
  }

  let wardId = null;
  if (filters.ward_id) {
    const ward = await resolveWardByIdentifier(
      prisma,
      filters.ward_id,
      where.tenant_id || null,
      where.facility_id || null,
    );
    if (!ward)
      throw new HttpError("errors.ward.not_found", 404, [{ field: "ward_id" }]);
    wardId = ward.id;
  }

  const hasDerivedFilters = Boolean(
    filters.stage ||
    filters.transfer_status ||
    wardId ||
    typeof filters.has_active_bed === "boolean" ||
    (includeIcu &&
      (filters.icu_status ||
        filters.critical_severity ||
        typeof filters.has_critical_alert === "boolean" ||
        icuQueueScope !== ICU_QUEUE_SCOPES.ALL)),
  );

  if (hasDerivedFilters) {
    const rows = await ipdFlowRepository.findMany(where, 0, 300, {
      [sortBy || "admitted_at"]: direction,
    });
    const filtered = rows
      .map((row) => buildIpdSnapshot(row, { include_icu: includeIcu }))
      .filter((snapshot) =>
        matchesDerivedFilters(snapshot, {
          stage: filters.stage,
          transfer_status: filters.transfer_status,
          has_active_bed: filters.has_active_bed,
          ward_id: wardId,
          queue_scope: queueScope,
          icu_queue_scope: icuQueueScope,
          icu_status: includeIcu ? filters.icu_status : undefined,
          critical_severity: includeIcu ? filters.critical_severity : undefined,
          has_critical_alert: includeIcu
            ? filters.has_critical_alert
            : undefined,
        }),
      );

    const items = filtered.slice(skip, skip + currentLimit).map(toQueueCardDto);

    return {
      items,
      pagination: {
        page: currentPage,
        limit: currentLimit,
        total: filtered.length,
        totalPages: Math.ceil(filtered.length / currentLimit) || 1,
        hasNextPage: skip + currentLimit < filtered.length,
        hasPreviousPage: currentPage > 1,
      },
    };
  }

  const [rows, total] = await Promise.all([
    ipdFlowRepository.findMany(where, skip, currentLimit, {
      [sortBy || "admitted_at"]: direction,
    }),
    ipdFlowRepository.count(where),
  ]);

  return {
    items: rows.map((row) =>
      toQueueCardDto(buildIpdSnapshot(row, { include_icu: includeIcu })),
    ),
    pagination: {
      page: currentPage,
      limit: currentLimit,
      total,
      totalPages: Math.ceil(total / currentLimit) || 1,
      hasNextPage: skip + currentLimit < total,
      hasPreviousPage: currentPage > 1,
    },
  };
};

const resolveLegacyRoute = async (resource, id) => {
  const normalizedResource = sanitizeIdentifier(resource).toLowerCase();
  const config = LEGACY_ROUTE_CONFIG[normalizedResource];
  if (!config) throw new HttpError("errors.ipd_flow.not_found", 404);

  const delegate = prisma[config.delegate];
  if (!delegate || typeof delegate.findFirst !== "function") {
    throw new HttpError("errors.ipd_flow.not_found", 404);
  }

  const isNestedAdmissionField = String(config.admissionField || "").includes(
    ".",
  );
  let queryOptions = {
    select: {
      id: true,
      human_friendly_id: true,
      [config.admissionField]: true,
    },
  };

  if (isNestedAdmissionField) {
    const [relationName, relationField] = String(config.admissionField).split(
      ".",
    );
    queryOptions = {
      include: {
        [relationName]: {
          select: {
            [relationField]: true,
          },
        },
      },
    };
  }

  const resolvedResource = await resolveByIdentifier(
    delegate,
    id,
    {},
    queryOptions,
  );
  if (!resolvedResource) throw new HttpError("errors.ipd_flow.not_found", 404);

  const admissionInternalId =
    config.admissionField === "id"
      ? resolvedResource.id
      : isNestedAdmissionField
        ? getNestedValue(resolvedResource, config.admissionField)
        : resolvedResource[config.admissionField];

  if (!admissionInternalId)
    throw new HttpError("errors.ipd_flow.not_found", 404);

  const admission = await prisma.admission.findFirst({
    where: {
      id: admissionInternalId,
      deleted_at: null,
    },
    select: {
      id: true,
      human_friendly_id: true,
      status: true,
    },
  });

  if (!admission) throw new HttpError("errors.ipd_flow.not_found", 404);

  return {
    admission_id: resolvePublicIdentifier(admission),
    resource: normalizedResource,
    resource_id: resolvePublicIdentifier(resolvedResource),
    panel: config.panel,
    action: config.action,
    stage_hint:
      String(admission.status || "").toUpperCase() === "DISCHARGED"
        ? STAGES.DISCHARGED
        : String(admission.status || "").toUpperCase() === "CANCELLED"
          ? STAGES.CANCELLED
          : null,
  };
};

const ensureAdmissionIsMutable = (admission) => {
  const status = String(admission?.status || "").toUpperCase();
  if (TERMINAL_ADMISSION_STATUSES.has(status)) {
    throw new HttpError("errors.ipd_flow.admission_terminal", 400);
  }
};

const fetchAdmissionForMutation = async (tx, admissionId) => {
  const admission = await tx.admission.findFirst({
    where: {
      id: admissionId,
      deleted_at: null,
    },
    include: {
      bed_assignments: {
        where: { deleted_at: null },
        orderBy: { assigned_at: "desc" },
        include: { bed: true },
      },
      transfer_requests: {
        where: { deleted_at: null },
        orderBy: { requested_at: "desc" },
      },
      discharge_summaries: {
        where: { deleted_at: null },
        orderBy: { updated_at: "desc" },
      },
      icu_stays: {
        where: { deleted_at: null },
        orderBy: { started_at: "desc" },
        include: {
          observations: {
            where: { deleted_at: null },
            orderBy: { observed_at: "desc" },
          },
          alerts: {
            where: { deleted_at: null },
            orderBy: { created_at: "desc" },
          },
        },
      },
    },
  });

  if (!admission) throw new HttpError("errors.ipd_flow.not_found", 404);
  return admission;
};

const buildRealtimePayload = ({ snapshot, transition }) => {
  const admissionPublicId = snapshot?.id || snapshot?.admission?.id || null;
  const patientPublicId = snapshot?.patient?.id || null;

  return {
    admission_id: admissionPublicId,
    admission_public_id: admissionPublicId,
    patient_id: patientPublicId,
    patient_public_id: patientPublicId,
    stage_from: transition?.stage_from || null,
    stage_to: transition?.stage_to || snapshot?.flow?.stage || null,
    next_step: snapshot?.flow?.next_step || null,
    action: transition?.action || "UPDATED",
    occurred_at: transition?.occurred_at || new Date().toISOString(),
    flow_summary: snapshot?.flow_summary || null,
    target_path: admissionPublicId
      ? `/ipd?id=${encodeURIComponent(admissionPublicId)}`
      : "/ipd",
  };
};

const resolveRoleRecipients = async ({
  tenantId,
  facilityId = null,
  roles = [],
}) => {
  if (!tenantId || !Array.isArray(roles) || roles.length === 0) return [];

  if (!prisma?.user_role?.findMany) return [];

  const rows = await prisma.user_role.findMany({
    where: {
      deleted_at: null,
      tenant_id: tenantId,
      role: {
        name: {
          in: roles,
        },
        deleted_at: null,
      },
      ...(facilityId
        ? { OR: [{ facility_id: null }, { facility_id: facilityId }] }
        : {}),
    },
    select: {
      user_id: true,
    },
  });

  return rows.map((item) => item.user_id).filter(Boolean);
};

const createAndEmitNotifications = async ({
  payload,
  recipientUserIds,
  tenantId,
}) => {
  if (!Array.isArray(recipientUserIds) || recipientUserIds.length === 0) return;
  if (!prisma?.notification?.create) return;

  const title = `IPD flow update: ${String(payload?.stage_to || "UPDATED").replace(/_/g, " ")}`;
  const message = `Admission ${payload?.admission_public_id || "unknown"} moved to ${payload?.stage_to || "UPDATED"}.`;

  for (const userId of recipientUserIds) {
    try {
      const notification = await prisma.notification.create({
        data: {
          tenant_id: tenantId,
          user_id: userId,
          notification_type: "SYSTEM",
          priority:
            payload?.stage_to === STAGES.TRANSFER_IN_PROGRESS
              ? "HIGH"
              : "MEDIUM",
          title,
          message,
        },
      });

      emitToUser(
        notification.user_id,
        NOTIFICATION_EVENTS.NOTIFICATION_CREATED,
        {
          notification: {
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
            target_path: payload.target_path,
          },
          target_path: payload.target_path,
        },
      );
    } catch (_error) {
      // ignore notification errors
    }
  }
};

const buildCompatibilityEvents = (signals = []) => {
  const events = [];
  if (signals.includes("PATIENT_ADMITTED"))
    events.push(ADMISSION_BED_EVENTS.PATIENT_ADMITTED);
  if (signals.includes("PATIENT_TRANSFERRED"))
    events.push(ADMISSION_BED_EVENTS.PATIENT_TRANSFERRED);
  if (signals.includes("PATIENT_DISCHARGED"))
    events.push(ADMISSION_BED_EVENTS.PATIENT_DISCHARGED);
  if (signals.includes("BED_ASSIGNMENT_CHANGED"))
    events.push(ADMISSION_BED_EVENTS.BED_ASSIGNMENT_CHANGED);
  return [...new Set(events)];
};

const publishIpdRealtimeUpdates = async ({
  snapshot,
  transition,
  context,
  compatibilitySignals = [],
  tenantInternalId = null,
  facilityInternalId = null,
}) => {
  try {
    const payload = buildRealtimePayload({ snapshot, transition });
    const resolvedTenantId = tenantInternalId || context?.tenant_id || null;
    const resolvedFacilityId =
      facilityInternalId || context?.facility_id || null;
    const recipientUserIds = await resolveRoleRecipients({
      tenantId: resolvedTenantId,
      facilityId: resolvedFacilityId,
      roles: IPD_RECIPIENT_ROLES,
    });

    const recipients = recipientUserIds.filter(
      (userId) => userId && userId !== context?.user_id,
    );
    if (!recipients.length) return;

    emitToUsers(recipients, IPD_EVENTS.IPD_FLOW_UPDATED, payload);

    const compatibilityPayload = {
      admission_id: payload.admission_id,
      admission_public_id: payload.admission_public_id,
      patient_id: payload.patient_id,
      patient_public_id: payload.patient_public_id,
      stage_to: payload.stage_to,
      action: payload.action,
      occurred_at: payload.occurred_at,
      target_path: payload.target_path,
    };

    buildCompatibilityEvents(compatibilitySignals).forEach((eventName) => {
      emitToUsers(recipients, eventName, compatibilityPayload);
    });

    await createAndEmitNotifications({
      payload,
      recipientUserIds: recipients,
      tenantId: resolvedTenantId,
    });
  } catch (_error) {
    // realtime should not block workflow
  }
};

const writeAuditLog = ({
  context,
  admissionId,
  tenantId,
  action,
  after,
  metadata = {},
}) => {
  createAuditLog({
    tenant_id: tenantId,
    user_id: context?.user_id,
    action,
    entity: "ipd_flow",
    entity_id: admissionId,
    diff: {
      after,
      metadata,
    },
    ip_address: context?.ip_address,
  }).catch(() => {});
};

const finalizeAction = async ({ result, context, metadata = {} }) => {
  const includeIcu = toBooleanFlag(metadata?.include_icu, false);
  const internalSnapshot = await getIpdSnapshotByIdInternal(
    result.admission_id,
    {
      include_icu: includeIcu,
    },
  );
  const snapshot = toPublicIpdSnapshot(internalSnapshot);
  await publishIpdRealtimeUpdates({
    snapshot,
    transition: {
      ...result.transition,
      stage_to: snapshot?.flow?.stage || null,
    },
    context,
    compatibilitySignals: result.compatibilitySignals,
    tenantInternalId:
      result.tenant_id ||
      internalSnapshot?.admission?.tenant_id ||
      context?.tenant_id ||
      null,
    facilityInternalId:
      internalSnapshot?.admission?.facility_id || context?.facility_id || null,
  });

  writeAuditLog({
    context,
    admissionId: result.admission_id,
    tenantId: result.tenant_id,
    action: "UPDATE",
    after: snapshot,
    metadata: {
      ...metadata,
      include_icu: undefined,
    },
  });

  return snapshot;
};
const startIpdFlow = async (data, context = {}) => {
  const admittedAt = new Date();

  const result = await prisma.$transaction(async (tx) => {
    const tenantFromPayload = data?.tenant_id
      ? await resolveTenantByIdentifier(tx, data.tenant_id)
      : null;
    if (data?.tenant_id && !tenantFromPayload) {
      throw new HttpError("errors.tenant.not_found", 404, [
        { field: "tenant_id" },
      ]);
    }

    const tenantId = tenantFromPayload?.id || context?.tenant_id || null;
    if (!tenantId) {
      throw new HttpError("errors.validation.field.required", 400, [
        { field: "tenant_id" },
      ]);
    }

    let facilityId = context?.facility_id || null;
    if (data?.facility_id !== undefined) {
      if (data.facility_id === null) {
        facilityId = null;
      } else {
        const facility = await resolveFacilityByIdentifier(
          tx,
          data.facility_id,
          tenantId,
        );
        if (!facility) {
          throw new HttpError("errors.facility.not_found", 404, [
            { field: "facility_id" },
          ]);
        }
        facilityId = facility.id;
      }
    }

    const patient = await resolvePatientByIdentifier(
      tx,
      data.patient_id,
      tenantId,
      facilityId,
    );
    if (!patient) {
      throw new HttpError("errors.ipd_flow.patient_not_found", 404, [
        { field: "patient_id" },
      ]);
    }

    if (!facilityId && patient.facility_id) {
      facilityId = patient.facility_id;
    }

    let requestedWard = null;
    if (data?.ward_id) {
      requestedWard = await resolveWardByIdentifier(
        tx,
        data.ward_id,
        tenantId,
        facilityId,
      );
      if (!requestedWard) {
        throw new HttpError("errors.ward.not_found", 404, [
          { field: "ward_id" },
        ]);
      }
      if (!facilityId && requestedWard.facility_id) {
        facilityId = requestedWard.facility_id;
      }
    }

    let requestedRoom = null;
    if (data?.room_id) {
      requestedRoom = await resolveRoomByIdentifier(
        tx,
        data.room_id,
        tenantId,
        facilityId,
      );
      if (!requestedRoom) {
        throw new HttpError("errors.room.not_found", 404, [
          { field: "room_id" },
        ]);
      }
      if (requestedWard && requestedRoom.ward_id !== requestedWard.id) {
        throw new HttpError("errors.validation.invalid", 400, [
          { field: "room_id" },
        ]);
      }
      if (!facilityId && requestedRoom.facility_id) {
        facilityId = requestedRoom.facility_id;
      }
      if (facilityId && requestedRoom.facility_id !== facilityId) {
        throw new HttpError("errors.validation.invalid", 400, [
          { field: "room_id" },
        ]);
      }
    }

    let requestedBed = null;
    if (data?.bed_id) {
      requestedBed = await resolveBedByIdentifier(
        tx,
        data.bed_id,
        tenantId,
        facilityId,
      );
      if (!requestedBed) {
        throw new HttpError("errors.bed.not_found", 404, [
          { field: "bed_id" },
        ]);
      }
      if (!facilityId && requestedBed.facility_id) {
        facilityId = requestedBed.facility_id;
      }
      if (facilityId && requestedBed.facility_id !== facilityId) {
        throw new HttpError("errors.validation.invalid", 400, [
          { field: "bed_id" },
        ]);
      }
      if (requestedWard && requestedBed.ward_id !== requestedWard.id) {
        throw new HttpError("errors.validation.invalid", 400, [
          { field: "bed_id" },
        ]);
      }
      if (requestedRoom && requestedBed.room_id !== requestedRoom.id) {
        throw new HttpError("errors.validation.invalid", 400, [
          { field: "bed_id" },
        ]);
      }
    }

    if (patient.facility_id && facilityId && patient.facility_id !== facilityId) {
      throw new HttpError("errors.validation.invalid", 400, [
        { field: "patient_id" },
      ]);
    }

    let encounterId = null;
    if (data?.encounter_id) {
      const encounter = await resolveEncounterByIdentifier(
        tx,
        data.encounter_id,
        tenantId,
        facilityId,
      );
      if (!encounter) {
        throw new HttpError("errors.encounter.not_found", 404, [
          { field: "encounter_id" },
        ]);
      }
      if (encounter.patient_id !== patient.id) {
        throw new HttpError("errors.validation.invalid", 400, [
          { field: "encounter_id" },
        ]);
      }
      encounterId = encounter.id;
    }

    const existingAdmission = await tx.admission.findFirst({
      where: {
        tenant_id: tenantId,
        patient_id: patient.id,
        deleted_at: null,
        status: { notIn: Array.from(TERMINAL_ADMISSION_STATUSES) },
        ...(facilityId
          ? { OR: [{ facility_id: facilityId }, { facility_id: null }] }
          : {}),
      },
      orderBy: { admitted_at: "desc" },
      include: {
        bed_assignments: {
          where: { deleted_at: null, released_at: null },
          orderBy: { assigned_at: "desc" },
          take: 1,
          include: {
            bed: {
              select: {
                id: true,
                status: true,
              },
            },
          },
        },
      },
    });

    const admission = existingAdmission
      ? await tx.admission.update({
          where: { id: existingAdmission.id },
          data: {
            facility_id: facilityId || existingAdmission.facility_id,
            encounter_id: encounterId || existingAdmission.encounter_id,
            status: "ADMITTED",
            discharged_at: null,
          },
        })
      : await tx.admission.create({
          data: {
            tenant_id: tenantId,
            facility_id: facilityId,
            patient_id: patient.id,
            encounter_id: encounterId,
            status: "ADMITTED",
            admitted_at: admittedAt,
          },
        });

    const compatibilitySignals = ["PATIENT_ADMITTED"];
    const activeBedAssignment = existingAdmission
      ? getActiveBedAssignment(existingAdmission)
      : null;

    if (requestedBed) {
      const requestedBedStatus = String(requestedBed.status || "").toUpperCase();
      if (activeBedAssignment) {
        if (activeBedAssignment.bed_id !== requestedBed.id) {
          throw new HttpError("errors.ipd_flow.active_bed_exists", 400);
        }
      } else {
        if (requestedBedStatus !== "AVAILABLE") {
          throw new HttpError("errors.ipd_flow.bed_not_available", 400, [
            { field: "bed_id" },
          ]);
        }

        await tx.bed_assignment.create({
          data: {
            admission_id: admission.id,
            bed_id: requestedBed.id,
            assigned_at: admittedAt,
          },
        });

        await tx.bed.update({
          where: { id: requestedBed.id },
          data: { status: "OCCUPIED" },
        });

        compatibilitySignals.push("BED_ASSIGNMENT_CHANGED");
      }
    }

    return {
      admission_id: admission.id,
      tenant_id: tenantId,
      transition: {
        action: existingAdmission ? "START_UPDATE" : "START",
        stage_from: null,
        stage_to: null,
        occurred_at: admittedAt.toISOString(),
      },
      compatibilitySignals,
    };
  });

  return finalizeAction({ result, context, metadata: { operation: "start" } });
};

const assignBed = async (id, data, context = {}) => {
  const assignedAt = toDate(data?.assigned_at, new Date());

  const result = await prisma.$transaction(async (tx) => {
    const resolved = await resolveAdmissionByIdentifier(tx, id);
    if (!resolved) throw new HttpError("errors.ipd_flow.not_found", 404);

    const admission = await fetchAdmissionForMutation(tx, resolved.id);
    ensureAdmissionIsMutable(admission);

    if (getActiveBedAssignment(admission)) {
      throw new HttpError("errors.ipd_flow.active_bed_exists", 400);
    }

    const bed = await resolveBedByIdentifier(
      tx,
      data?.bed_id,
      admission.tenant_id,
      admission.facility_id || null,
    );
    if (!bed)
      throw new HttpError("errors.bed.not_found", 404, [{ field: "bed_id" }]);
    if (String(bed.status || "").toUpperCase() !== "AVAILABLE") {
      throw new HttpError("errors.ipd_flow.bed_not_available", 400, [
        { field: "bed_id" },
      ]);
    }

    const stageBefore = deriveIpdStage({
      admission,
      activeBedAssignment: null,
      openTransferRequest: getOpenTransferRequest(admission),
      latestDischargeSummary: getLatestDischargeSummary(admission),
    });

    await tx.bed_assignment.create({
      data: {
        admission_id: admission.id,
        bed_id: bed.id,
        assigned_at: assignedAt,
      },
    });

    await tx.bed.update({
      where: { id: bed.id },
      data: { status: "OCCUPIED" },
    });

    return {
      admission_id: admission.id,
      tenant_id: admission.tenant_id,
      transition: {
        action: "ASSIGN_BED",
        stage_from: stageBefore,
        stage_to: null,
        occurred_at: assignedAt.toISOString(),
      },
      compatibilitySignals: ["BED_ASSIGNMENT_CHANGED"],
    };
  });

  return finalizeAction({
    result,
    context,
    metadata: { operation: "assign_bed" },
  });
};

const releaseBed = async (id, data, context = {}) => {
  const releasedAt = toDate(data?.released_at, new Date());

  const result = await prisma.$transaction(async (tx) => {
    const resolved = await resolveAdmissionByIdentifier(tx, id);
    if (!resolved) throw new HttpError("errors.ipd_flow.not_found", 404);

    const admission = await fetchAdmissionForMutation(tx, resolved.id);
    ensureAdmissionIsMutable(admission);

    const activeBedAssignment = getActiveBedAssignment(admission);
    if (!activeBedAssignment) {
      throw new HttpError("errors.ipd_flow.active_bed_required", 400);
    }

    const stageBefore = deriveIpdStage({
      admission,
      activeBedAssignment,
      openTransferRequest: getOpenTransferRequest(admission),
      latestDischargeSummary: getLatestDischargeSummary(admission),
    });

    await tx.bed_assignment.update({
      where: { id: activeBedAssignment.id },
      data: { released_at: releasedAt },
    });

    await tx.bed.update({
      where: { id: activeBedAssignment.bed_id },
      data: { status: "AVAILABLE" },
    });

    return {
      admission_id: admission.id,
      tenant_id: admission.tenant_id,
      transition: {
        action: "RELEASE_BED",
        stage_from: stageBefore,
        stage_to: null,
        occurred_at: releasedAt.toISOString(),
      },
      compatibilitySignals: ["BED_ASSIGNMENT_CHANGED"],
    };
  });

  return finalizeAction({
    result,
    context,
    metadata: { operation: "release_bed" },
  });
};

const rejectAdmissionRequest = async (id, data, context = {}) => {
  const rejectedAt = new Date();
  const reason = sanitizeIdentifier(data?.reason);
  if (!reason) {
    throw new HttpError("errors.validation.field.required", 400, [
      { field: "reason" },
    ]);
  }

  const result = await prisma.$transaction(async (tx) => {
    const resolved = await resolveAdmissionByIdentifier(tx, id);
    if (!resolved) throw new HttpError("errors.ipd_flow.not_found", 404);

    const admission = await fetchAdmissionForMutation(tx, resolved.id);
    ensureAdmissionIsMutable(admission);

    const activeBedAssignment = getActiveBedAssignment(admission);
    const stageBefore = deriveIpdStage({
      admission,
      activeBedAssignment,
      openTransferRequest: getOpenTransferRequest(admission),
      latestDischargeSummary: getLatestDischargeSummary(admission),
    });

    if (activeBedAssignment) {
      await tx.bed_assignment.update({
        where: { id: activeBedAssignment.id },
        data: { released_at: rejectedAt },
      });

      await tx.bed.update({
        where: { id: activeBedAssignment.bed_id },
        data: { status: "AVAILABLE" },
      });
    }

    await tx.admission.update({
      where: { id: admission.id },
      data: {
        status: "CANCELLED",
        updated_at: rejectedAt,
      },
    });

    return {
      admission_id: admission.id,
      tenant_id: admission.tenant_id,
      transition: {
        action: "REJECT_ADMISSION",
        stage_from: stageBefore,
        stage_to: STAGES.CANCELLED,
        occurred_at: rejectedAt.toISOString(),
      },
      compatibilitySignals: activeBedAssignment ? ["BED_ASSIGNMENT_CHANGED"] : [],
      rejection_reason: reason,
    };
  });

  return finalizeAction({
    result,
    context,
    metadata: {
      operation: "reject_admission",
      rejection_reason: reason,
    },
  });
};

const requestTransfer = async (id, data, context = {}) => {
  const requestedAt = toDate(data?.requested_at, new Date());

  const result = await prisma.$transaction(async (tx) => {
    const resolved = await resolveAdmissionByIdentifier(tx, id);
    if (!resolved) throw new HttpError("errors.ipd_flow.not_found", 404);

    const admission = await fetchAdmissionForMutation(tx, resolved.id);
    ensureAdmissionIsMutable(admission);

    if (getOpenTransferRequest(admission)) {
      throw new HttpError("errors.ipd_flow.invalid_transfer_transition", 400);
    }

    const activeBedAssignment = getActiveBedAssignment(admission);
    let fromWardId = activeBedAssignment?.bed?.ward_id || null;

    if (data?.from_ward_id) {
      const fromWard = await resolveWardByIdentifier(
        tx,
        data.from_ward_id,
        admission.tenant_id,
        admission.facility_id || null,
      );
      if (!fromWard)
        throw new HttpError("errors.ward.not_found", 404, [
          { field: "from_ward_id" },
        ]);
      fromWardId = fromWard.id;
    }

    const toWard = await resolveWardByIdentifier(
      tx,
      data?.to_ward_id,
      admission.tenant_id,
      admission.facility_id || null,
    );
    if (!toWard)
      throw new HttpError("errors.ward.not_found", 404, [
        { field: "to_ward_id" },
      ]);

    const stageBefore = deriveIpdStage({
      admission,
      activeBedAssignment,
      openTransferRequest: null,
      latestDischargeSummary: getLatestDischargeSummary(admission),
    });

    await tx.transfer_request.create({
      data: {
        admission_id: admission.id,
        from_ward_id: fromWardId,
        to_ward_id: toWard.id,
        status: "REQUESTED",
        requested_at: requestedAt,
      },
    });

    return {
      admission_id: admission.id,
      tenant_id: admission.tenant_id,
      transition: {
        action: "REQUEST_TRANSFER",
        stage_from: stageBefore,
        stage_to: null,
        occurred_at: requestedAt.toISOString(),
      },
      compatibilitySignals: ["PATIENT_TRANSFERRED"],
    };
  });

  return finalizeAction({
    result,
    context,
    metadata: { operation: "request_transfer" },
  });
};
const resolveTransferForAction = async (
  tx,
  admission,
  transferRequestId = null,
) => {
  if (transferRequestId) {
    const transfer = await resolveTransferByIdentifier(
      tx,
      transferRequestId,
      admission.id,
    );
    if (!transfer)
      throw new HttpError("errors.ipd_flow.transfer_request_not_found", 404);

    return tx.transfer_request.findFirst({
      where: {
        id: transfer.id,
        deleted_at: null,
      },
    });
  }

  return getOpenTransferRequest(admission);
};

const resolveIcuStayForAction = async (
  tx,
  admission,
  icuStayIdentifier = null,
  { requireActive = false, allowLatestFallback = true } = {},
) => {
  if (icuStayIdentifier) {
    const resolvedStay = await resolveIcuStayByIdentifier(
      tx,
      icuStayIdentifier,
      admission.id,
    );
    if (!resolvedStay)
      throw new HttpError("errors.ipd_flow.icu_stay_not_found", 404);

    if (requireActive && resolvedStay.ended_at) {
      throw new HttpError("errors.ipd_flow.active_icu_stay_required", 400);
    }

    return resolvedStay;
  }

  const activeStay = getActiveIcuStay(admission);
  if (activeStay) return activeStay;

  if (requireActive) {
    throw new HttpError("errors.ipd_flow.active_icu_stay_required", 400);
  }

  if (allowLatestFallback) {
    const latestStay = getLatestIcuStay(admission);
    if (latestStay) return latestStay;
  }

  return null;
};

const resolveCriticalAlertForAction = async (
  tx,
  admission,
  criticalAlertIdentifier = null,
) => {
  if (criticalAlertIdentifier) {
    const resolvedAlert = await resolveCriticalAlertByIdentifier(
      tx,
      criticalAlertIdentifier,
    );
    if (!resolvedAlert)
      throw new HttpError("errors.ipd_flow.critical_alert_not_found", 404);

    const stay = await tx.icu_stay.findFirst({
      where: {
        id: resolvedAlert.icu_stay_id,
        admission_id: admission.id,
        deleted_at: null,
      },
      select: {
        id: true,
      },
    });

    if (!stay)
      throw new HttpError("errors.ipd_flow.critical_alert_not_found", 404);
    return resolvedAlert;
  }

  const activeStay = getActiveIcuStay(admission);
  const activeAlerts = activeStay ? getIcuStayAlerts(activeStay) : [];
  if (activeAlerts.length) return activeAlerts[0];

  const fallbackAlerts = getIcuStays(admission).flatMap((stay) =>
    getIcuStayAlerts(stay),
  );
  return fallbackAlerts[0] || null;
};

const resolveAdmissionNurseForAction = async (
  tx,
  admission,
  identifier,
  context = {},
) => {
  const nurseIdentifier =
    sanitizeIdentifier(identifier) || sanitizeIdentifier(context?.user_id);
  if (!nurseIdentifier) {
    throw new HttpError("errors.validation.field.required", 400, [
      { field: "nurse_user_id" },
    ]);
  }

  const directUser = await resolveUserByIdentifier(
    tx,
    nurseIdentifier,
    admission.tenant_id,
    admission.facility_id || null,
  );
  if (directUser) return directUser;

  const staffProfile = await resolveStaffProfileByIdentifier(
    tx,
    nurseIdentifier,
    admission.tenant_id,
    admission.facility_id || null,
  );
  if (staffProfile?.user_id) {
    return {
      id: staffProfile.user_id,
      human_friendly_id: staffProfile.user?.human_friendly_id || null,
    };
  }

  throw new HttpError("errors.user.not_found", 404, [
    { field: "nurse_user_id" },
  ]);
};

const updateTransfer = async (id, data, context = {}) => {
  const action = String(data?.action || "")
    .trim()
    .toUpperCase();

  const result = await prisma.$transaction(async (tx) => {
    const resolved = await resolveAdmissionByIdentifier(tx, id);
    if (!resolved) throw new HttpError("errors.ipd_flow.not_found", 404);

    const admission = await fetchAdmissionForMutation(tx, resolved.id);
    ensureAdmissionIsMutable(admission);

    const transferRequest = await resolveTransferForAction(
      tx,
      admission,
      data?.transfer_request_id,
    );
    if (!transferRequest)
      throw new HttpError("errors.ipd_flow.transfer_request_not_found", 404);

    const transferStatus = String(transferRequest.status || "").toUpperCase();
    const activeBedAssignment = getActiveBedAssignment(admission);
    const stageBefore = deriveIpdStage({
      admission,
      activeBedAssignment,
      openTransferRequest: transferRequest,
      latestDischargeSummary: getLatestDischargeSummary(admission),
    });

    const occurredAt = new Date();
    const compatibilitySignals = ["PATIENT_TRANSFERRED"];

    if (action === TRANSFER_ACTIONS.APPROVE) {
      if (transferStatus !== "REQUESTED")
        throw new HttpError("errors.ipd_flow.invalid_transfer_transition", 400);
      await tx.transfer_request.update({
        where: { id: transferRequest.id },
        data: { status: "APPROVED" },
      });
    } else if (action === TRANSFER_ACTIONS.START) {
      if (transferStatus !== "APPROVED")
        throw new HttpError("errors.ipd_flow.invalid_transfer_transition", 400);
      await tx.transfer_request.update({
        where: { id: transferRequest.id },
        data: { status: "IN_PROGRESS" },
      });
    } else if (action === TRANSFER_ACTIONS.CANCEL) {
      if (!OPEN_TRANSFER_STATUSES.has(transferStatus)) {
        throw new HttpError("errors.ipd_flow.invalid_transfer_transition", 400);
      }
      await tx.transfer_request.update({
        where: { id: transferRequest.id },
        data: { status: "CANCELLED" },
      });
    } else if (action === TRANSFER_ACTIONS.COMPLETE) {
      if (transferStatus !== "IN_PROGRESS")
        throw new HttpError("errors.ipd_flow.invalid_transfer_transition", 400);
      if (!activeBedAssignment)
        throw new HttpError("errors.ipd_flow.active_bed_required", 400);
      if (!data?.to_bed_id) {
        throw new HttpError(
          "errors.ipd_flow.transfer_destination_bed_required",
          400,
          [{ field: "to_bed_id" }],
        );
      }

      const destinationBed = await resolveBedByIdentifier(
        tx,
        data.to_bed_id,
        admission.tenant_id,
        admission.facility_id || null,
      );
      if (!destinationBed)
        throw new HttpError("errors.bed.not_found", 404, [
          { field: "to_bed_id" },
        ]);
      if (String(destinationBed.status || "").toUpperCase() !== "AVAILABLE") {
        throw new HttpError("errors.ipd_flow.bed_not_available", 400, [
          { field: "to_bed_id" },
        ]);
      }

      await tx.bed_assignment.update({
        where: { id: activeBedAssignment.id },
        data: { released_at: occurredAt },
      });
      await tx.bed.update({
        where: { id: activeBedAssignment.bed_id },
        data: { status: "AVAILABLE" },
      });

      await tx.bed_assignment.create({
        data: {
          admission_id: admission.id,
          bed_id: destinationBed.id,
          assigned_at: occurredAt,
        },
      });
      await tx.bed.update({
        where: { id: destinationBed.id },
        data: { status: "OCCUPIED" },
      });

      await tx.transfer_request.update({
        where: { id: transferRequest.id },
        data: {
          status: "COMPLETED",
          to_ward_id: destinationBed.ward_id,
        },
      });

      compatibilitySignals.push("BED_ASSIGNMENT_CHANGED");
    } else {
      throw new HttpError("errors.ipd_flow.invalid_transfer_transition", 400);
    }

    return {
      admission_id: admission.id,
      tenant_id: admission.tenant_id,
      transition: {
        action: `TRANSFER_${action}`,
        stage_from: stageBefore,
        stage_to: null,
        occurred_at: occurredAt.toISOString(),
      },
      compatibilitySignals,
    };
  });

  return finalizeAction({
    result,
    context,
    metadata: { operation: "update_transfer" },
  });
};

const addWardRound = async (id, data, context = {}) => {
  const roundAt = toDate(data?.round_at, new Date());

  const result = await prisma.$transaction(async (tx) => {
    const resolved = await resolveAdmissionByIdentifier(tx, id);
    if (!resolved) throw new HttpError("errors.ipd_flow.not_found", 404);

    const admission = await fetchAdmissionForMutation(tx, resolved.id);
    ensureAdmissionIsMutable(admission);

    const stageBefore = deriveIpdStage({
      admission,
      activeBedAssignment: getActiveBedAssignment(admission),
      openTransferRequest: getOpenTransferRequest(admission),
      latestDischargeSummary: getLatestDischargeSummary(admission),
    });

    await tx.ward_round.create({
      data: {
        admission_id: admission.id,
        round_at: roundAt,
        notes: data?.notes || null,
      },
    });

    return {
      admission_id: admission.id,
      tenant_id: admission.tenant_id,
      transition: {
        action: "ADD_WARD_ROUND",
        stage_from: stageBefore,
        stage_to: null,
        occurred_at: roundAt.toISOString(),
      },
      compatibilitySignals: [],
    };
  });

  return finalizeAction({
    result,
    context,
    metadata: { operation: "add_ward_round" },
  });
};

const addNursingNote = async (id, data, context = {}) => {
  const note = String(data?.note || "").trim();
  if (!note)
    throw new HttpError("errors.ipd_flow.nursing_note_required", 400, [
      { field: "note" },
    ]);

  const result = await prisma.$transaction(async (tx) => {
    const resolved = await resolveAdmissionByIdentifier(tx, id);
    if (!resolved) throw new HttpError("errors.ipd_flow.not_found", 404);

    const admission = await fetchAdmissionForMutation(tx, resolved.id);
    ensureAdmissionIsMutable(admission);

    const nurse = await resolveAdmissionNurseForAction(
      tx,
      admission,
      data?.nurse_user_id,
      context,
    );

    const stageBefore = deriveIpdStage({
      admission,
      activeBedAssignment: getActiveBedAssignment(admission),
      openTransferRequest: getOpenTransferRequest(admission),
      latestDischargeSummary: getLatestDischargeSummary(admission),
    });

    await tx.nursing_note.create({
      data: {
        admission_id: admission.id,
        nurse_user_id: nurse.id,
        note,
      },
    });

    return {
      admission_id: admission.id,
      tenant_id: admission.tenant_id,
      transition: {
        action: "ADD_NURSING_NOTE",
        stage_from: stageBefore,
        stage_to: null,
        occurred_at: new Date().toISOString(),
      },
      compatibilitySignals: [],
    };
  });

  return finalizeAction({
    result,
    context,
    metadata: { operation: "add_nursing_note" },
  });
};

const addMedicationAdministration = async (id, data, context = {}) => {
  const dose = String(data?.dose || "").trim();
  if (!dose)
    throw new HttpError("errors.ipd_flow.medication_dose_required", 400, [
      { field: "dose" },
    ]);

  const result = await prisma.$transaction(async (tx) => {
    const resolved = await resolveAdmissionByIdentifier(tx, id);
    if (!resolved) throw new HttpError("errors.ipd_flow.not_found", 404);

    const admission = await fetchAdmissionForMutation(tx, resolved.id);
    ensureAdmissionIsMutable(admission);

    const administeredAt = toDate(data?.administered_at, new Date());
    const resolvedPrescription = sanitizeIdentifier(data?.prescription_id)
      ? await resolvePharmacyOrderItemByIdentifier(
          tx,
          data.prescription_id,
          admission.encounter_id || null,
          admission.patient_id || null,
        )
      : null;

    if (sanitizeIdentifier(data?.prescription_id) && !resolvedPrescription) {
      throw new HttpError(
        "errors.ipd_flow.medication_prescription_not_found",
        404,
        [{ field: "prescription_id" }],
      );
    }

    const frequency = normalizeMedicationFrequency(
      data?.frequency,
      resolvedPrescription?.frequency || "ONCE",
    );
    const scheduleReminders = Boolean(data?.schedule_reminders);
    const reminderOccurrences = Math.max(
      1,
      Number(data?.reminder_occurrences || 1),
    );
    const reminderIntervalHours = resolveMedicationFrequencyIntervalHours(
      frequency,
      data?.reminder_interval_hours,
    );

    if (scheduleReminders && !admission.encounter_id) {
      throw new HttpError(
        "errors.ipd_flow.medication_reminder_encounter_required",
        400,
        [{ field: "schedule_reminders" }],
      );
    }

    if (
      scheduleReminders &&
      reminderOccurrences > 1 &&
      !reminderIntervalHours
    ) {
      throw new HttpError(
        "errors.ipd_flow.medication_reminder_interval_required",
        400,
        [{ field: "reminder_interval_hours" }],
      );
    }

    const firstReminderAt = scheduleReminders
      ? toDate(
          data?.reminder_first_at,
          reminderIntervalHours
            ? new Date(
                administeredAt.getTime() +
                  reminderIntervalHours * 60 * 60 * 1000,
              )
            : new Date(administeredAt.getTime() + 60 * 60 * 1000),
        )
      : null;

    const prescriptionPublicId =
      resolvePublicIdentifier(resolvedPrescription) ||
      sanitizeIdentifier(data?.prescription_id) ||
      null;
    const medicationLabel =
      sanitizeIdentifier(data?.medication_label) ||
      mapMedicationSuggestion(resolvedPrescription)?.medication_label ||
      null;
    const administrationStatus = sanitizeIdentifier(data?.status || "GIVEN").toUpperCase();
    const administrationNote = String(data?.administration_note || "").trim();

    const stageBefore = deriveIpdStage({
      admission,
      activeBedAssignment: getActiveBedAssignment(admission),
      openTransferRequest: getOpenTransferRequest(admission),
      latestDischargeSummary: getLatestDischargeSummary(admission),
    });

    if (administrationStatus === "GIVEN") {
      await tx.medication_administration.create({
        data: {
          admission_id: admission.id,
          prescription_id: resolvedPrescription?.id || null,
          administered_at: administeredAt,
          dose,
          unit: data?.unit || null,
          route: data?.route || "ORAL",
        },
      });
    }

    if ((administrationStatus !== "GIVEN" || administrationNote) && context?.user_id) {
      await tx.nursing_note.create({
        data: {
          admission_id: admission.id,
          nurse_user_id: context.user_id,
          note: [
            `[MEDICATION ${administrationStatus}]`,
            [medicationLabel, dose, data?.unit, data?.route].filter(Boolean).join(" "),
            administrationNote,
          ]
            .filter(Boolean)
            .join(" - "),
        },
      });
    }

    if (scheduleReminders && administrationStatus === "GIVEN") {
      const encounterPublicId =
        resolvePublicIdentifier(
          admission.encounter_id
            ? await tx.encounter.findFirst({
                where: {
                  id: admission.encounter_id,
                  deleted_at: null,
                },
                select: {
                  id: true,
                  human_friendly_id: true,
                },
              })
            : null,
        ) || null;

      const schedule = buildMedicationReminderSchedule({
        administeredAt,
        reminderFirstAt: firstReminderAt,
        occurrences: reminderOccurrences,
        intervalHours: reminderIntervalHours || 1,
      });

      for (const [index, scheduledAt] of schedule.entries()) {
        await tx.follow_up.create({
          data: {
            encounter_id: admission.encounter_id,
            scheduled_at: scheduledAt,
            status: "SCHEDULED",
            notes: buildIpdMedicationReminderNote({
              medicationLabel,
              dose,
              unit: data?.unit || null,
              route: data?.route || "ORAL",
              frequency,
              admissionPublicId: resolvePublicIdentifier(admission),
              encounterPublicId,
              prescriptionPublicId,
              occurrence: index + 1,
              totalOccurrences: reminderOccurrences,
            }),
          },
        });
      }
    }

    return {
      admission_id: admission.id,
      tenant_id: admission.tenant_id,
      transition: {
        action: "ADD_MEDICATION_ADMINISTRATION",
        stage_from: stageBefore,
        stage_to: null,
        occurred_at: new Date().toISOString(),
      },
      compatibilitySignals: [],
    };
  });

  return finalizeAction({
    result,
    context,
    metadata: { operation: "add_medication_administration" },
  });
};

const planDischarge = async (id, data, context = {}) => {
  const summary = String(data?.summary || "").trim();
  if (!summary) {
    throw new HttpError("errors.ipd_flow.discharge_summary_required", 400, [
      { field: "summary" },
    ]);
  }

  const plannedDischargeAt = data?.discharged_at
    ? toDate(data.discharged_at, new Date())
    : null;

  const result = await prisma.$transaction(async (tx) => {
    const resolved = await resolveAdmissionByIdentifier(tx, id);
    if (!resolved) throw new HttpError("errors.ipd_flow.not_found", 404);

    const admission = await fetchAdmissionForMutation(tx, resolved.id);
    ensureAdmissionIsMutable(admission);

    const openTransferRequest = getOpenTransferRequest(admission);
    if (openTransferRequest) {
      throw new HttpError(
        "errors.ipd_flow.transfer_must_be_resolved_before_discharge",
        400,
      );
    }

    const stageBefore = deriveIpdStage({
      admission,
      activeBedAssignment: getActiveBedAssignment(admission),
      openTransferRequest: null,
      latestDischargeSummary: getLatestDischargeSummary(admission),
    });

    const latestDischargeSummary = getLatestDischargeSummary(admission);
    const latestStatus = String(
      latestDischargeSummary?.status || "",
    ).toUpperCase();

    if (latestDischargeSummary && latestStatus !== "COMPLETED") {
      await tx.discharge_summary.update({
        where: { id: latestDischargeSummary.id },
        data: {
          summary,
          status: "PLANNED",
          discharged_at: plannedDischargeAt,
        },
      });
    } else {
      await tx.discharge_summary.create({
        data: {
          admission_id: admission.id,
          summary,
          status: "PLANNED",
          discharged_at: plannedDischargeAt,
        },
      });
    }

    return {
      admission_id: admission.id,
      tenant_id: admission.tenant_id,
      transition: {
        action: "PLAN_DISCHARGE",
        stage_from: stageBefore,
        stage_to: null,
        occurred_at: new Date().toISOString(),
      },
      compatibilitySignals: [],
    };
  });

  return finalizeAction({
    result,
    context,
    metadata: { operation: "plan_discharge" },
  });
};

const finalizeDischarge = async (id, data, context = {}) => {
  const dischargedAt = toDate(data?.discharged_at, new Date());
  const payloadSummary = String(data?.summary || "").trim();

  const result = await prisma.$transaction(async (tx) => {
    const resolved = await resolveAdmissionByIdentifier(tx, id);
    if (!resolved) throw new HttpError("errors.ipd_flow.not_found", 404);

    const admission = await fetchAdmissionForMutation(tx, resolved.id);
    ensureAdmissionIsMutable(admission);

    const openTransferRequest = getOpenTransferRequest(admission);
    if (openTransferRequest) {
      throw new HttpError(
        "errors.ipd_flow.transfer_must_be_resolved_before_discharge",
        400,
      );
    }

    const activeBedAssignment = getActiveBedAssignment(admission);
    const stageBefore = deriveIpdStage({
      admission,
      activeBedAssignment,
      openTransferRequest: null,
      latestDischargeSummary: getLatestDischargeSummary(admission),
    });

    const latestDischargeSummary = getLatestDischargeSummary(admission);
    const summary =
      payloadSummary || String(latestDischargeSummary?.summary || "").trim();
    if (!summary) {
      throw new HttpError("errors.ipd_flow.discharge_summary_required", 400, [
        { field: "summary" },
      ]);
    }

    if (latestDischargeSummary) {
      await tx.discharge_summary.update({
        where: { id: latestDischargeSummary.id },
        data: {
          summary,
          status: "COMPLETED",
          discharged_at: dischargedAt,
        },
      });
    } else {
      await tx.discharge_summary.create({
        data: {
          admission_id: admission.id,
          summary,
          status: "COMPLETED",
          discharged_at: dischargedAt,
        },
      });
    }

    const compatibilitySignals = ["PATIENT_DISCHARGED"];

    if (activeBedAssignment) {
      await tx.bed_assignment.update({
        where: { id: activeBedAssignment.id },
        data: { released_at: dischargedAt },
      });
      await tx.bed.update({
        where: { id: activeBedAssignment.bed_id },
        data: { status: "AVAILABLE" },
      });
      compatibilitySignals.push("BED_ASSIGNMENT_CHANGED");
    }

    await tx.admission.update({
      where: { id: admission.id },
      data: {
        status: "DISCHARGED",
        discharged_at: dischargedAt,
      },
    });

    return {
      admission_id: admission.id,
      tenant_id: admission.tenant_id,
      transition: {
        action: "FINALIZE_DISCHARGE",
        stage_from: stageBefore,
        stage_to: STAGES.DISCHARGED,
        occurred_at: dischargedAt.toISOString(),
      },
      compatibilitySignals,
    };
  });

  return finalizeAction({
    result,
    context,
    metadata: { operation: "finalize_discharge" },
  });
};

const startIcuStay = async (id, data, context = {}) => {
  const startedAt = toDate(data?.started_at, new Date());

  const result = await prisma.$transaction(async (tx) => {
    const resolved = await resolveAdmissionByIdentifier(tx, id);
    if (!resolved) throw new HttpError("errors.ipd_flow.not_found", 404);

    const admission = await fetchAdmissionForMutation(tx, resolved.id);
    ensureAdmissionIsMutable(admission);

    if (getActiveIcuStay(admission)) {
      throw new HttpError("errors.ipd_flow.icu_stay_already_active", 400);
    }

    await tx.icu_stay.create({
      data: {
        admission_id: admission.id,
        started_at: startedAt,
      },
    });

    return {
      admission_id: admission.id,
      tenant_id: admission.tenant_id,
      transition: {
        action: "START_ICU_STAY",
        stage_from: deriveIpdStage({
          admission,
          activeBedAssignment: getActiveBedAssignment(admission),
          openTransferRequest: getOpenTransferRequest(admission),
          latestDischargeSummary: getLatestDischargeSummary(admission),
        }),
        stage_to: null,
        occurred_at: startedAt.toISOString(),
      },
      compatibilitySignals: [],
    };
  });

  return finalizeAction({
    result,
    context,
    metadata: { operation: "start_icu_stay", include_icu: true },
  });
};

const endIcuStay = async (id, data, context = {}) => {
  const endedAt = toDate(data?.ended_at, new Date());

  const result = await prisma.$transaction(async (tx) => {
    const resolved = await resolveAdmissionByIdentifier(tx, id);
    if (!resolved) throw new HttpError("errors.ipd_flow.not_found", 404);

    const admission = await fetchAdmissionForMutation(tx, resolved.id);
    ensureAdmissionIsMutable(admission);

    const stay = await resolveIcuStayForAction(
      tx,
      admission,
      data?.icu_stay_id,
      {
        requireActive: true,
        allowLatestFallback: false,
      },
    );

    await tx.icu_stay.update({
      where: { id: stay.id },
      data: { ended_at: endedAt },
    });

    return {
      admission_id: admission.id,
      tenant_id: admission.tenant_id,
      transition: {
        action: "END_ICU_STAY",
        stage_from: deriveIpdStage({
          admission,
          activeBedAssignment: getActiveBedAssignment(admission),
          openTransferRequest: getOpenTransferRequest(admission),
          latestDischargeSummary: getLatestDischargeSummary(admission),
        }),
        stage_to: null,
        occurred_at: endedAt.toISOString(),
      },
      compatibilitySignals: [],
    };
  });

  return finalizeAction({
    result,
    context,
    metadata: { operation: "end_icu_stay", include_icu: true },
  });
};

const addIcuObservation = async (id, data, context = {}) => {
  const observedAt = toDate(data?.observed_at, new Date());
  const observation = String(data?.observation || "").trim();
  if (!observation) {
    throw new HttpError("errors.validation.field.required", 400, [
      { field: "observation" },
    ]);
  }

  const result = await prisma.$transaction(async (tx) => {
    const resolved = await resolveAdmissionByIdentifier(tx, id);
    if (!resolved) throw new HttpError("errors.ipd_flow.not_found", 404);

    const admission = await fetchAdmissionForMutation(tx, resolved.id);
    ensureAdmissionIsMutable(admission);

    const stay = await resolveIcuStayForAction(
      tx,
      admission,
      data?.icu_stay_id,
      {
        requireActive: true,
        allowLatestFallback: false,
      },
    );

    await tx.icu_observation.create({
      data: {
        icu_stay_id: stay.id,
        observed_at: observedAt,
        observation,
      },
    });

    return {
      admission_id: admission.id,
      tenant_id: admission.tenant_id,
      transition: {
        action: "ADD_ICU_OBSERVATION",
        stage_from: deriveIpdStage({
          admission,
          activeBedAssignment: getActiveBedAssignment(admission),
          openTransferRequest: getOpenTransferRequest(admission),
          latestDischargeSummary: getLatestDischargeSummary(admission),
        }),
        stage_to: null,
        occurred_at: observedAt.toISOString(),
      },
      compatibilitySignals: [],
    };
  });

  return finalizeAction({
    result,
    context,
    metadata: { operation: "add_icu_observation", include_icu: true },
  });
};

const addCriticalAlert = async (id, data, context = {}) => {
  const message = String(data?.message || "").trim();
  const severity = String(data?.severity || "")
    .trim()
    .toUpperCase();
  if (!message) {
    throw new HttpError("errors.validation.field.required", 400, [
      { field: "message" },
    ]);
  }

  const result = await prisma.$transaction(async (tx) => {
    const resolved = await resolveAdmissionByIdentifier(tx, id);
    if (!resolved) throw new HttpError("errors.ipd_flow.not_found", 404);

    const admission = await fetchAdmissionForMutation(tx, resolved.id);
    ensureAdmissionIsMutable(admission);

    const stay = await resolveIcuStayForAction(
      tx,
      admission,
      data?.icu_stay_id,
      {
        requireActive: true,
        allowLatestFallback: false,
      },
    );

    await tx.critical_alert.create({
      data: {
        icu_stay_id: stay.id,
        severity,
        message,
      },
    });

    return {
      admission_id: admission.id,
      tenant_id: admission.tenant_id,
      transition: {
        action: "ADD_CRITICAL_ALERT",
        stage_from: deriveIpdStage({
          admission,
          activeBedAssignment: getActiveBedAssignment(admission),
          openTransferRequest: getOpenTransferRequest(admission),
          latestDischargeSummary: getLatestDischargeSummary(admission),
        }),
        stage_to: null,
        occurred_at: new Date().toISOString(),
      },
      compatibilitySignals: [],
    };
  });

  return finalizeAction({
    result,
    context,
    metadata: { operation: "add_critical_alert", include_icu: true },
  });
};

const resolveCriticalAlert = async (id, data, context = {}) => {
  const result = await prisma.$transaction(async (tx) => {
    const resolved = await resolveAdmissionByIdentifier(tx, id);
    if (!resolved) throw new HttpError("errors.ipd_flow.not_found", 404);

    const admission = await fetchAdmissionForMutation(tx, resolved.id);
    ensureAdmissionIsMutable(admission);

    const alert = await resolveCriticalAlertForAction(
      tx,
      admission,
      data?.critical_alert_id,
    );
    if (!alert)
      throw new HttpError("errors.ipd_flow.critical_alert_not_found", 404);

    await tx.critical_alert.update({
      where: { id: alert.id },
      data: {
        deleted_at: new Date(),
      },
    });

    return {
      admission_id: admission.id,
      tenant_id: admission.tenant_id,
      transition: {
        action: "RESOLVE_CRITICAL_ALERT",
        stage_from: deriveIpdStage({
          admission,
          activeBedAssignment: getActiveBedAssignment(admission),
          openTransferRequest: getOpenTransferRequest(admission),
          latestDischargeSummary: getLatestDischargeSummary(admission),
        }),
        stage_to: null,
        occurred_at: new Date().toISOString(),
      },
      compatibilitySignals: [],
    };
  });

  return finalizeAction({
    result,
    context,
    metadata: { operation: "resolve_critical_alert", include_icu: true },
  });
};

const emitAdmissionRefreshEvent = async (admissionIdentifier, context = {}) => {
  const normalized = sanitizeIdentifier(admissionIdentifier);
  if (!normalized) return null;

  try {
    const internalSnapshot = await getIpdSnapshotByIdInternal(normalized);
    const snapshot = toPublicIpdSnapshot(internalSnapshot);
    await publishIpdRealtimeUpdates({
      snapshot,
      transition: {
        action: "OPD_ADMITTED",
        stage_from: null,
        stage_to: snapshot?.flow?.stage || null,
        occurred_at: new Date().toISOString(),
      },
      context,
      compatibilitySignals: ["PATIENT_ADMITTED"],
      tenantInternalId:
        internalSnapshot?.admission?.tenant_id || context?.tenant_id || null,
      facilityInternalId:
        internalSnapshot?.admission?.facility_id ||
        context?.facility_id ||
        null,
    });
    return snapshot;
  } catch (_error) {
    return null;
  }
};

module.exports = {
  STAGES,
  TRANSFER_ACTIONS,
  listIpdFlows,
  resolveLegacyRoute,
  getIpdFlowById,
  startIpdFlow,
  assignBed,
  releaseBed,
  rejectAdmissionRequest,
  requestTransfer,
  updateTransfer,
  addWardRound,
  addNursingNote,
  addMedicationAdministration,
  planDischarge,
  finalizeDischarge,
  startIcuStay,
  endIcuStay,
  addIcuObservation,
  addCriticalAlert,
  resolveCriticalAlert,
  emitAdmissionRefreshEvent,
};
