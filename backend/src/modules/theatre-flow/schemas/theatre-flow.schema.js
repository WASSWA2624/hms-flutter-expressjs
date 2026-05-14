/**
 * Theatre flow module validation schemas
 *
 * @module modules/theatre-flow/schemas
 * @description Zod validation schemas for theatre workbench orchestration endpoints.
 */

const { z } = require('zod');
const { listQuerySchema } = require('@lib/validation/zod');

const UUID_LIKE_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const FRIENDLY_ID_REGEX = /^(?=.*\d)[A-Za-z][A-Za-z0-9_-]*$/;

const parseBooleanString = (value) => {
  const normalized = String(value || '').trim().toLowerCase();
  if (['true', '1', 'yes', 'on'].includes(normalized)) return true;
  if (['false', '0', 'no', 'off'].includes(normalized)) return false;
  return null;
};

const identifierSchema = z
  .string()
  .trim()
  .min(2)
  .max(64)
  .refine(
    (value) => UUID_LIKE_REGEX.test(value) || FRIENDLY_ID_REGEX.test(value),
    'Invalid identifier format'
  )
  .transform((value) =>
    UUID_LIKE_REGEX.test(value) ? value.toLowerCase() : value.toUpperCase()
  );

const optionalIdentifierSchema = identifierSchema.optional().nullable();

const queueScopeSchema = z.enum(['ACTIVE', 'ALL']);
const recordStatusSchema = z.enum(['DRAFT', 'FINAL']);
const theatreStatusSchema = z.enum([
  'SCHEDULED',
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED',
]);
const theatreChecklistPhaseSchema = z.enum([
  'PRE_OP',
  'SIGN_IN',
  'TIME_OUT',
  'SIGN_OUT',
  'PACU_HANDOFF',
]);
const theatreResourceTypeSchema = z.enum(['ROOM', 'STAFF', 'EQUIPMENT']);
const finalizeRecordTypeSchema = z.enum(['ANESTHESIA', 'POST_OP', 'ALL']);
const staffRoleSchema = z.enum(['SURGEON', 'ANESTHETIST']);
const legacyResourceSchema = z.enum([
  'theatre-cases',
  'anesthesia-records',
  'post-op-notes',
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
            message: 'Invalid boolean flag',
          });
          return z.NEVER;
        }
        return parsed;
      }),
  ])
  .optional();

const listTheatreFlowsQuerySchema = listQuerySchema.extend({
  tenant_id: identifierSchema.optional(),
  facility_id: identifierSchema.optional(),
  patient_id: identifierSchema.optional(),
  encounter_id: identifierSchema.optional(),
  queue_scope: queueScopeSchema.optional().default('ACTIVE'),
  status: theatreStatusSchema.optional(),
  stage: z.string().trim().max(80).optional(),
  room_id: identifierSchema.optional(),
  surgeon_user_id: identifierSchema.optional(),
  anesthetist_user_id: identifierSchema.optional(),
  anesthesia_status: recordStatusSchema.optional(),
  post_op_status: recordStatusSchema.optional(),
  scheduled_from: z.string().datetime().optional(),
  scheduled_to: z.string().datetime().optional(),
  finalized: booleanFlagSchema,
  search: z.string().trim().optional(),
});

const theatreCaseIdParamsSchema = z.object({
  id: identifierSchema,
});

const resolveLegacyRouteParamsSchema = z.object({
  resource: legacyResourceSchema,
  id: identifierSchema,
});

const getTheatreFlowQuerySchema = z.object({
  include_timeline: booleanFlagSchema,
});

const startTheatreFlowSchema = z.object({
  encounter_id: identifierSchema,
  scheduled_at: z.string().datetime().optional(),
  status: theatreStatusSchema.optional(),
  room_id: optionalIdentifierSchema,
  surgeon_user_id: optionalIdentifierSchema,
  anesthetist_user_id: optionalIdentifierSchema,
  workflow_stage: z.string().trim().max(80).optional(),
  stage_notes: z.string().trim().max(65535).optional().nullable(),
});

const updateStageSchema = z.object({
  workflow_stage: z.string().trim().max(80).optional(),
  status: theatreStatusSchema.optional(),
  stage_notes: z.string().trim().max(65535).optional().nullable(),
  started_at: z.string().datetime().optional().nullable(),
  completed_at: z.string().datetime().optional().nullable(),
  cancelled_at: z.string().datetime().optional().nullable(),
});

const upsertAnesthesiaRecordSchema = z.object({
  anesthesia_record_id: optionalIdentifierSchema,
  anesthetist_user_id: optionalIdentifierSchema,
  notes: z.string().trim().max(65535).optional().nullable(),
  record_status: recordStatusSchema.optional(),
});

const addAnesthesiaObservationSchema = z.object({
  observed_at: z.string().datetime().optional(),
  observation_type: z.string().trim().max(80).optional().nullable(),
  metric_key: z.string().trim().max(80).optional().nullable(),
  metric_value: z.string().trim().max(120).optional().nullable(),
  unit: z.string().trim().max(40).optional().nullable(),
  notes: z.string().trim().max(65535).optional().nullable(),
  observed_by_user_id: optionalIdentifierSchema,
});

const upsertPostOpNoteSchema = z.object({
  post_op_note_id: optionalIdentifierSchema,
  note: z.string().trim().min(1).max(65535),
  record_status: recordStatusSchema.optional(),
});

const toggleChecklistItemSchema = z.object({
  checklist_item_id: optionalIdentifierSchema,
  phase: theatreChecklistPhaseSchema,
  item_code: z.string().trim().min(1).max(120),
  item_label: z.string().trim().max(255).optional().nullable(),
  is_checked: booleanFlagSchema,
  notes: z.string().trim().max(65535).optional().nullable(),
});

const assignResourceSchema = z.object({
  resource_type: theatreResourceTypeSchema,
  resource_id: identifierSchema,
  staff_role: staffRoleSchema.optional(),
  notes: z.string().trim().max(65535).optional().nullable(),
});

const releaseResourceSchema = z.object({
  allocation_id: optionalIdentifierSchema,
  resource_type: theatreResourceTypeSchema.optional(),
  resource_id: optionalIdentifierSchema,
  released_at: z.string().datetime().optional(),
  notes: z.string().trim().max(65535).optional().nullable(),
});

const finalizeRecordSchema = z.object({
  record_type: finalizeRecordTypeSchema.optional().default('ALL'),
  anesthesia_record_id: optionalIdentifierSchema,
  post_op_note_id: optionalIdentifierSchema,
});

const reopenRecordSchema = z.object({
  record_type: finalizeRecordTypeSchema.optional().default('ALL'),
  anesthesia_record_id: optionalIdentifierSchema,
  post_op_note_id: optionalIdentifierSchema,
  reason: z.string().trim().min(3).max(65535),
});

module.exports = {
  listTheatreFlowsQuerySchema,
  getTheatreFlowQuerySchema,
  theatreCaseIdParamsSchema,
  resolveLegacyRouteParamsSchema,
  startTheatreFlowSchema,
  updateStageSchema,
  upsertAnesthesiaRecordSchema,
  addAnesthesiaObservationSchema,
  upsertPostOpNoteSchema,
  toggleChecklistItemSchema,
  assignResourceSchema,
  releaseResourceSchema,
  finalizeRecordSchema,
  reopenRecordSchema,
  queueScopeSchema,
  recordStatusSchema,
  theatreStatusSchema,
  theatreChecklistPhaseSchema,
  theatreResourceTypeSchema,
  legacyResourceSchema,
  finalizeRecordTypeSchema,
};

