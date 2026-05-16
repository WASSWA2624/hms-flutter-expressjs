/**
 * Triage validation schemas
 *
 * @module modules/triage/schemas
 * @description Zod validation schemas for the Triage queue and routing workflow.
 */

const { z } = require('zod');
const { listQuerySchema, decimalStringSchema } = require('@lib/validation/zod');

const UUID_LIKE_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const RESOURCE_FRIENDLY_ID_REGEX = /^(?=.*\d)[A-Za-z][A-Za-z0-9_-]*$/;
const BLOOD_PRESSURE_VALUE_REGEX = /^(\d{2,3}(?:\.\d{1,2})?)\s*\/\s*(\d{2,3}(?:\.\d{1,2})?)$/;

const WORKFLOW_STAGE_VALUES = [
  'WAITING_CONSULTATION_PAYMENT',
  'WAITING_VITALS',
  'WAITING_DOCTOR_ASSIGNMENT',
  'WAITING_DOCTOR_REVIEW',
  'LAB_REQUESTED',
  'RADIOLOGY_REQUESTED',
  'LAB_AND_RADIOLOGY_REQUESTED',
  'PHARMACY_REQUESTED',
  'WAITING_DISPOSITION',
  'ADMITTED',
  'DISCHARGED'
];

const TRIAGE_LEVEL_VALUES = [
  'LEVEL_1',
  'LEVEL_2',
  'LEVEL_3',
  'LEVEL_4',
  'LEVEL_5',
  'IMMEDIATE',
  'URGENT',
  'LESS_URGENT',
  'NON_URGENT'
];

const VITAL_TYPE_VALUES = [
  'TEMPERATURE',
  'BLOOD_PRESSURE',
  'HEART_RATE',
  'RESPIRATORY_RATE',
  'OXYGEN_SATURATION',
  'WEIGHT',
  'HEIGHT',
  'BMI'
];

const ROUTE_DESTINATION_VALUES = [
  'CONSULTATION',
  'LAB',
  'RADIOLOGY',
  'LAB_AND_RADIOLOGY',
  'PHYSIOTHERAPY',
  'OTHER_SERVICE',
  'ADMIT',
  'EMERGENCY',
  'THEATRE',
  'MINOR_PROCEDURE',
  'DISCHARGE'
];

const QUEUE_SCOPE_VALUES = ['ASSIGNED', 'WAITING', 'ALL'];

const resourceIdentifierSchema = z
  .string()
  .trim()
  .min(2)
  .max(64)
  .refine((value) => UUID_LIKE_REGEX.test(value) || RESOURCE_FRIENDLY_ID_REGEX.test(value), 'Invalid identifier format')
  .transform((value) => (UUID_LIKE_REGEX.test(value) ? value.toLowerCase() : value.toUpperCase()));

const scopeIdentifierSchema = z
  .string()
  .trim()
  .min(2)
  .max(64)
  .refine((value) => UUID_LIKE_REGEX.test(value) || RESOURCE_FRIENDLY_ID_REGEX.test(value), 'Invalid identifier format')
  .transform((value) => (UUID_LIKE_REGEX.test(value) ? value.toLowerCase() : value.toUpperCase()));

const nullableResourceIdentifierSchema = resourceIdentifierSchema.optional().nullable();
const nullableScopeIdentifierSchema = scopeIdentifierSchema.optional().nullable();
const decimalInputSchema = z.union([z.coerce.number().positive(), decimalStringSchema]);

const triageIdParamsSchema = z.object({
  id: resourceIdentifierSchema
});

const listTriageQueueQuerySchema = listQuerySchema.extend({
  tenant_id: scopeIdentifierSchema.optional(),
  facility_id: scopeIdentifierSchema.optional(),
  patient_id: resourceIdentifierSchema.optional(),
  provider_user_id: resourceIdentifierSchema.optional(),
  queue_scope: z.enum(QUEUE_SCOPE_VALUES).optional().default('ALL'),
  encounter_type: z.enum(['OPD', 'EMERGENCY']).optional(),
  triage_status: z.enum(WORKFLOW_STAGE_VALUES).optional(),
  stage: z.enum(WORKFLOW_STAGE_VALUES).optional(),
  urgency_level: z.enum(TRIAGE_LEVEL_VALUES).optional(),
  triage_level: z.enum(TRIAGE_LEVEL_VALUES).optional(),
  search: z.string().trim().optional()
});

const recordVitalItemSchema = z
  .object({
    vital_type: z.enum(VITAL_TYPE_VALUES),
    value: z.string().trim().min(1).max(80).optional(),
    unit: z.string().trim().max(20).optional().nullable(),
    systolic_value: decimalInputSchema.optional(),
    diastolic_value: decimalInputSchema.optional(),
    map_value: decimalInputSchema.optional(),
    recorded_at: z.string().datetime().optional()
  })
  .superRefine((vital, ctx) => {
    if (vital.vital_type === 'BLOOD_PRESSURE') {
      const hasStructuredComponents = vital.systolic_value != null && vital.diastolic_value != null;
      const hasLegacyValue = typeof vital.value === 'string' && BLOOD_PRESSURE_VALUE_REGEX.test(vital.value.trim());

      if (!hasStructuredComponents && !hasLegacyValue) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['systolic_value'],
          message: 'errors.validation.required'
        });
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['diastolic_value'],
          message: 'errors.validation.required'
        });
      }
      return;
    }

    if (!vital.value) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['value'],
        message: 'errors.validation.required'
      });
    }
  });

const recordVitalsSchema = z.object({
  vitals: z.array(recordVitalItemSchema).min(1),
  triage_level: z.enum(TRIAGE_LEVEL_VALUES).optional(),
  triage_priority: z.enum(TRIAGE_LEVEL_VALUES).optional(),
  chief_complaint: z.string().trim().max(65535).optional().nullable(),
  emergency: z.boolean().optional(),
  triage_notes: z.string().trim().max(65535).optional().nullable()
});

const assignProviderSchema = z.object({
  provider_user_id: resourceIdentifierSchema
});

const routeTriageSchema = z.object({
  route_to: z.enum(ROUTE_DESTINATION_VALUES),
  provider_user_id: nullableResourceIdentifierSchema,
  department_id: nullableResourceIdentifierSchema,
  admission_facility_id: nullableScopeIdentifierSchema,
  triage_level: z.enum(TRIAGE_LEVEL_VALUES).optional().nullable(),
  emergency: z.boolean().optional(),
  notes: z.string().trim().max(65535).optional().nullable(),
  reason: z.string().trim().max(65535).optional().nullable(),
  scheduled_at: z.string().datetime().optional().nullable(),
  admitted_at: z.string().datetime().optional().nullable()
});

const correctStageSchema = z.object({
  stage_to: z.enum(WORKFLOW_STAGE_VALUES),
  reason: z.string().trim().min(1).max(2000)
});

module.exports = {
  triageIdParamsSchema,
  listTriageQueueQuerySchema,
  recordVitalsSchema,
  assignProviderSchema,
  routeTriageSchema,
  correctStageSchema,
  QUEUE_SCOPE_VALUES,
  ROUTE_DESTINATION_VALUES,
  TRIAGE_LEVEL_VALUES,
  WORKFLOW_STAGE_VALUES
};
