/**
 * Therapy flow validation schemas
 */

const { z } = require('zod');
const { listQuerySchema } = require('@lib/validation/zod');
const { clinicalRequestBillingSchema } = require('@lib/billing/clinical-request-billing.schema');

const UUID_LIKE_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const FRIENDLY_ID_REGEX = /^(?=.*\d)[A-Za-z][A-Za-z0-9_-]*$/;

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

const QUEUE_SCOPE_VALUES = [
  'REFERRAL',
  'TODAY',
  'MISSED',
  'ACTIVE_PLAN',
  'FOLLOW_UP_DUE',
  'COMPLETED',
  'ALL'];

const THERAPY_STATUS_VALUES = [
  'REFERRAL',
  'ACCEPTED',
  'ASSESSMENT',
  'ACTIVE_PLAN',
  'SESSION_SCHEDULED',
  'FOLLOW_UP_DUE',
  'MISSED',
  'COMPLETED',
  'CLOSED'];

const ATTENDANCE_VALUES = [
  'SCHEDULED',
  'ATTENDED',
  'NO_SHOW',
  'CANCELLED',
  'RESCHEDULED'];

const SOURCE_KIND_VALUES = ['OPD', 'IPD', 'EMERGENCY', 'TRIAGE'];

const therapyEpisodeIdParamsSchema = z.object({
  id: identifierSchema});

const listTherapyFlowsQuerySchema = listQuerySchema.extend({
  tenant_id: optionalIdentifierSchema,
  facility_id: optionalIdentifierSchema,
  patient_id: optionalIdentifierSchema,
  encounter_id: optionalIdentifierSchema,
  therapist_id: optionalIdentifierSchema,
  queue_scope: z.enum(QUEUE_SCOPE_VALUES).optional().default('REFERRAL'),
  therapy_status: z.enum(THERAPY_STATUS_VALUES).optional(),
  source_kind: z.enum(SOURCE_KIND_VALUES).optional(),
  scheduled_from: z.string().datetime().optional(),
  scheduled_to: z.string().datetime().optional(),
  search: z.string().trim().optional()});

const getTherapyFlowQuerySchema = z.object({
  include_timeline: z
    .union([z.boolean(), z.enum(['true', 'false', '1', '0'])])
    .optional()});

const createTherapyReferralSchema = z.object({
  encounter_id: identifierSchema,
  admission_id: optionalIdentifierSchema,
  referral_id: optionalIdentifierSchema,
  source_kind: z.enum(SOURCE_KIND_VALUES).optional(),
  source_id: optionalIdentifierSchema,
  source_title: z.string().trim().max(255).optional().nullable(),
  referral_reason: z.string().trim().max(2000).optional().nullable(),
  priority: z.string().trim().max(40).optional().nullable(),
  therapist_user_id: optionalIdentifierSchema,
  notes: z.string().trim().max(65535).optional().nullable()});

const acceptReferralSchema = z.object({
  note: z.string().trim().max(65535).optional().nullable(),
  therapist_user_id: optionalIdentifierSchema});

const recordAssessmentSchema = z.object({
  assessment: z.string().trim().min(1).max(65535),
  goals: z.string().trim().max(65535).optional().nullable(),
  plan: z.string().trim().max(65535).optional().nullable(),
  instructions: z.string().trim().max(65535).optional().nullable(),
  contraindications: z.string().trim().max(65535).optional().nullable(),
  session_frequency: z.string().trim().max(120).optional().nullable()});

const scheduleSessionSchema = z.object({
  therapist_user_id: optionalIdentifierSchema,
  scheduled_start_at: z.string().datetime(),
  scheduled_end_at: z.string().datetime().optional().nullable(),
  location: z.string().trim().max(255).optional().nullable(),
  reason: z.string().trim().max(2000).optional().nullable(),
  billing: clinicalRequestBillingSchema.optional().nullable()});

const recordSessionSchema = z.object({
  session_id: optionalIdentifierSchema,
  note: z.string().trim().min(1).max(65535),
  attendance_status: z.enum(ATTENDANCE_VALUES).optional(),
  billing: clinicalRequestBillingSchema.optional().nullable()});

const markAttendanceSchema = z.object({
  session_id: identifierSchema,
  attendance_status: z.enum(ATTENDANCE_VALUES),
  note: z.string().trim().max(65535).optional().nullable()});

const updatePlanSchema = z.object({
  plan: z.string().trim().min(1).max(65535),
  goals: z.string().trim().max(65535).optional().nullable(),
  instructions: z.string().trim().max(65535).optional().nullable(),
  contraindications: z.string().trim().max(65535).optional().nullable(),
  session_frequency: z.string().trim().max(120).optional().nullable(),
  plan_started_at: z.string().datetime().optional().nullable(),
  plan_ends_at: z.string().datetime().optional().nullable()});

const addProgressNoteSchema = z.object({
  note: z.string().trim().min(1).max(65535)});

const scheduleFollowUpSchema = z.object({
  scheduled_at: z.string().datetime(),
  notes: z.string().trim().max(65535).optional().nullable()});

const closeEpisodeSchema = z.object({
  outcome_summary: z.string().trim().min(1).max(65535)});

const requestTherapySchema = z.object({
  clinical_indication: z.string().trim().min(1).max(2000),
  priority: z.string().trim().max(40).optional().nullable(),
  therapist_user_id: optionalIdentifierSchema,
  notes: z.string().trim().max(65535).optional().nullable()});

module.exports = {
  therapyEpisodeIdParamsSchema,
  listTherapyFlowsQuerySchema,
  getTherapyFlowQuerySchema,
  createTherapyReferralSchema,
  acceptReferralSchema,
  recordAssessmentSchema,
  scheduleSessionSchema,
  recordSessionSchema,
  markAttendanceSchema,
  updatePlanSchema,
  addProgressNoteSchema,
  scheduleFollowUpSchema,
  closeEpisodeSchema,
  requestTherapySchema,
  QUEUE_SCOPE_VALUES,
  THERAPY_STATUS_VALUES};
