/**
 * IPD flow module validation schemas
 *
 * @module modules/ipd-flow/schemas
 * @description Zod validation schemas for IPD orchestration endpoints.
 */

const { z } = require("zod");
const { listQuerySchema } = require("@lib/validation/zod");

const UUID_LIKE_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const FRIENDLY_ID_REGEX = /^(?=.*\d)[A-Za-z][A-Za-z0-9_-]*$/;

const parseBooleanString = (value) => {
  const normalized = String(value || "")
    .trim()
    .toLowerCase();
  if (["true", "1", "yes", "on"].includes(normalized)) return true;
  if (["false", "0", "no", "off"].includes(normalized)) return false;
  return null;
};

const identifierSchema = z
  .string()
  .trim()
  .min(2)
  .max(64)
  .refine(
    (value) => UUID_LIKE_REGEX.test(value) || FRIENDLY_ID_REGEX.test(value),
    "Invalid identifier format",
  )
  .transform((value) =>
    UUID_LIKE_REGEX.test(value) ? value.toLowerCase() : value.toUpperCase(),
  );

const optionalIdentifierSchema = identifierSchema.optional().nullable();

const workflowStageSchema = z.enum([
  "ADMITTED_PENDING_BED",
  "ADMITTED_IN_BED",
  "TRANSFER_REQUESTED",
  "TRANSFER_IN_PROGRESS",
  "DISCHARGE_PLANNED",
  "DISCHARGED",
  "CANCELLED",
]);

const transferStatusSchema = z.enum([
  "REQUESTED",
  "APPROVED",
  "IN_PROGRESS",
  "COMPLETED",
  "CANCELLED",
]);
const transferActionSchema = z.enum(["APPROVE", "START", "COMPLETE", "CANCEL"]);
const medicationRouteSchema = z.enum([
  "ORAL",
  "IV",
  "IM",
  "TOPICAL",
  "INHALATION",
  "OTHER",
]);
const queueScopeSchema = z.enum(["ACTIVE", "ALL"]);
const icuQueueScopeSchema = z
  .enum(["ALL", "WITH_ICU", "ACTIVE"])
  .optional()
  .default("ALL");
const icuStatusSchema = z.enum(["ACTIVE", "ENDED", "NONE"]);
const criticalSeveritySchema = z.enum(["LOW", "MEDIUM", "HIGH", "CRITICAL"]);
const legacyResourceSchema = z.enum([
  "admissions",
  "bed-assignments",
  "ward-rounds",
  "nursing-notes",
  "medication-administrations",
  "discharge-summaries",
  "transfer-requests",
  "icu-stays",
  "icu-observations",
  "critical-alerts",
]);

const booleanFlagSchema = z
  .union([
    z.boolean(),
    z
      .string()
      .trim()
      .min(1)
      .transform((value, ctx) => {
        const parsed = parseBooleanString(value);
        if (parsed === null) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: "Invalid boolean flag",
          });
          return z.NEVER;
        }
        return parsed;
      }),
  ])
  .optional();

const listIpdFlowsQuerySchema = listQuerySchema.extend({
  tenant_id: identifierSchema.optional(),
  facility_id: identifierSchema.optional(),
  patient_id: identifierSchema.optional(),
  queue_scope: queueScopeSchema.optional().default("ACTIVE"),
  stage: workflowStageSchema.optional(),
  ward_id: identifierSchema.optional(),
  transfer_status: transferStatusSchema.optional(),
  has_active_bed: booleanFlagSchema,
  include_icu: booleanFlagSchema,
  icu_queue_scope: icuQueueScopeSchema,
  icu_status: icuStatusSchema.optional(),
  critical_severity: criticalSeveritySchema.optional(),
  has_critical_alert: booleanFlagSchema,
  search: z.string().trim().optional(),
});

const admissionIdParamsSchema = z.object({
  id: identifierSchema,
});

const resolveLegacyRouteParamsSchema = z.object({
  resource: legacyResourceSchema,
  id: identifierSchema,
});

const getIpdFlowQuerySchema = z.object({
  include_icu: booleanFlagSchema,
});

const startIpdFlowSchema = z.object({
  tenant_id: identifierSchema.optional(),
  facility_id: optionalIdentifierSchema,
  patient_id: identifierSchema,
  encounter_id: optionalIdentifierSchema,
  ward_id: optionalIdentifierSchema,
  room_id: optionalIdentifierSchema,
  bed_id: optionalIdentifierSchema,
});

const assignBedSchema = z.object({
  bed_id: identifierSchema,
  assigned_at: z.string().datetime().optional(),
});

const releaseBedSchema = z.object({
  released_at: z.string().datetime().optional(),
});

const rejectAdmissionSchema = z.object({
  reason: z.string().trim().min(2).max(5000),
});

const requestTransferSchema = z.object({
  from_ward_id: optionalIdentifierSchema,
  to_ward_id: identifierSchema,
  requested_at: z.string().datetime().optional(),
});

const updateTransferSchema = z
  .object({
    transfer_request_id: optionalIdentifierSchema,
    action: transferActionSchema,
    to_bed_id: optionalIdentifierSchema,
  })
  .superRefine((value, ctx) => {
    if (value.action === "COMPLETE" && !value.to_bed_id) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["to_bed_id"],
        message: "to_bed_id is required for COMPLETE action",
      });
    }
  });

const addWardRoundSchema = z.object({
  round_at: z.string().datetime().optional(),
  notes: z.string().trim().max(65535).optional().nullable(),
});

const addNursingNoteSchema = z.object({
  nurse_user_id: optionalIdentifierSchema,
  note: z.string().trim().min(1).max(65535),
});

const addMedicationAdministrationSchema = z.object({
  prescription_id: optionalIdentifierSchema,
  medication_label: z.string().trim().max(255).optional().nullable(),
  administered_at: z.string().datetime().optional(),
  dose: z.string().trim().min(1).max(80),
  unit: z.string().trim().max(40).optional().nullable(),
  route: medicationRouteSchema.optional().default("ORAL"),
  status: z
    .enum(["GIVEN", "MISSED", "DELAYED", "REFUSED"])
    .optional()
    .default("GIVEN"),
  administration_note: z.string().trim().max(65535).optional().nullable(),
  frequency: z
    .enum(["ONCE", "BID", "TID", "QID", "PRN", "STAT", "CUSTOM"])
    .optional()
    .default("ONCE"),
  schedule_reminders: z.boolean().optional().default(false),
  reminder_first_at: z.string().datetime().optional().nullable(),
  reminder_occurrences: z.coerce.number().int().min(1).max(12).optional(),
  reminder_interval_hours: z.coerce
    .number()
    .positive()
    .max(168)
    .optional()
    .nullable(),
});

const planDischargeSchema = z.object({
  summary: z.string().trim().min(1).max(65535),
  discharged_at: z.string().datetime().optional().nullable(),
});

const finalizeDischargeSchema = z.object({
  summary: z.string().trim().max(65535).optional().nullable(),
  discharged_at: z.string().datetime().optional(),
});

const startIcuStaySchema = z.object({
  started_at: z.string().datetime().optional(),
});

const endIcuStaySchema = z.object({
  icu_stay_id: optionalIdentifierSchema,
  ended_at: z.string().datetime().optional(),
});

const addIcuObservationSchema = z.object({
  icu_stay_id: optionalIdentifierSchema,
  observed_at: z.string().datetime().optional(),
  observation: z.string().trim().min(1).max(5000),
});

const addCriticalAlertSchema = z.object({
  icu_stay_id: optionalIdentifierSchema,
  severity: criticalSeveritySchema,
  message: z.string().trim().min(1).max(2000),
});

const resolveCriticalAlertSchema = z.object({
  critical_alert_id: optionalIdentifierSchema,
});

module.exports = {
  listIpdFlowsQuerySchema,
  getIpdFlowQuerySchema,
  admissionIdParamsSchema,
  startIpdFlowSchema,
  assignBedSchema,
  releaseBedSchema,
  rejectAdmissionSchema,
  requestTransferSchema,
  updateTransferSchema,
  addWardRoundSchema,
  addNursingNoteSchema,
  addMedicationAdministrationSchema,
  planDischargeSchema,
  finalizeDischargeSchema,
  startIcuStaySchema,
  endIcuStaySchema,
  addIcuObservationSchema,
  addCriticalAlertSchema,
  resolveCriticalAlertSchema,
  workflowStageSchema,
  transferActionSchema,
  queueScopeSchema,
  icuQueueScopeSchema,
  icuStatusSchema,
  criticalSeveritySchema,
  legacyResourceSchema,
  resolveLegacyRouteParamsSchema,
};
