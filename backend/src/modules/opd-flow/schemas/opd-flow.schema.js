/**
 * OPD flow module validation schemas
 *
 * @module modules/opd-flow/schemas
 * @description Zod validation schemas for OPD patient flow orchestration endpoints.
 */

const { z } = require('zod');
const { listQuerySchema, decimalStringSchema } = require('@lib/validation/zod');

const ARRIVAL_MODE_VALUES = ['WALK_IN', 'ONLINE_APPOINTMENT', 'EMERGENCY'];
const EMERGENCY_SEVERITY_VALUES = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];
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
const PAYMENT_METHOD_VALUES = [
  'CASH',
  'CREDIT_CARD',
  'DEBIT_CARD',
  'PREPAID_CARD',
  'GIFT_CARD',
  'VOUCHER',
  'BANK_CHECK',
  'MOBILE_MONEY',
  'BANK_TRANSFER',
  'INSURANCE',
  'OTHER'
];
const PAYMENT_STATUS_VALUES = ['PENDING', 'COMPLETED', 'FAILED'];
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
const BLOOD_PRESSURE_VALUE_REGEX = /^(\d{2,3}(?:\.\d{1,2})?)\s*\/\s*(\d{2,3}(?:\.\d{1,2})?)$/;
const DIAGNOSIS_TYPE_VALUES = ['PRIMARY', 'SECONDARY', 'DIFFERENTIAL'];
const LAB_ORDER_STATUS_VALUES = ['ORDERED', 'COLLECTED', 'IN_PROCESS', 'COMPLETED', 'CANCELLED'];
const RADIOLOGY_ORDER_STATUS_VALUES = ['ORDERED', 'IN_PROCESS', 'COMPLETED', 'CANCELLED'];
const PRESCRIPTION_STATUS_VALUES = ['DRAFT', 'ACTIVE', 'COMPLETED', 'CANCELLED'];
const MEDICATION_ROUTE_VALUES = ['ORAL', 'IV', 'IM', 'TOPICAL', 'INHALATION', 'OTHER'];
const MEDICATION_FREQUENCY_VALUES = ['ONCE', 'BID', 'TID', 'QID', 'PRN', 'STAT', 'CUSTOM'];
const DISPOSITION_VALUES = ['ADMIT', 'SEND_TO_PHARMACY', 'DISCHARGE'];
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
const QUEUE_SCOPE_VALUES = ['ASSIGNED', 'WAITING', 'ALL'];
const LEGACY_RESOURCE_VALUES = [
  'emergency-cases',
  'triage-assessments',
  'emergency-responses',
  'ambulances',
  'ambulance-dispatches',
  'ambulance-trips'
];
const UUID_LIKE_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const PATIENT_FRIENDLY_ID_REGEX = /^(?=.*\d)[A-Za-z][A-Za-z0-9_-]*$/;
const RESOURCE_FRIENDLY_ID_REGEX = /^(?=.*\d)[A-Za-z][A-Za-z0-9_-]*$/;

const patientFriendlyIdSchema = z
  .string()
  .trim()
  .min(2)
  .max(64)
  .regex(PATIENT_FRIENDLY_ID_REGEX, 'Invalid patient identifier format')
  .transform((value) => value.toUpperCase());

const patientIdentifierSchema = patientFriendlyIdSchema;
const resourceFriendlyIdSchema = z
  .string()
  .trim()
  .min(2)
  .max(64)
  .regex(RESOURCE_FRIENDLY_ID_REGEX, 'Invalid identifier format')
  .transform((value) => value.toUpperCase());
const scopeIdentifierSchema = z
  .string()
  .trim()
  .min(2)
  .max(64)
  .refine((value) => UUID_LIKE_REGEX.test(value) || RESOURCE_FRIENDLY_ID_REGEX.test(value), 'Invalid identifier format')
  .transform((value) => (UUID_LIKE_REGEX.test(value) ? value.toLowerCase() : value.toUpperCase()));
const providerIdentifierSchema = scopeIdentifierSchema;
const appointmentIdentifierSchema = resourceFriendlyIdSchema;
const encounterIdentifierSchema = resourceFriendlyIdSchema;
const facilityIdentifierSchema = scopeIdentifierSchema;
const invoiceIdentifierSchema = resourceFriendlyIdSchema;

const patientRegistrationSchema = z.object({
  first_name: z.string().trim().min(1).max(120),
  last_name: z.string().trim().min(1).max(120),
  date_of_birth: z.string().datetime().optional().nullable(),
  gender: z.enum(['MALE', 'FEMALE', 'OTHER', 'UNKNOWN']).optional().nullable()
});

const emergencyPayloadSchema = z.object({
  severity: z.enum(EMERGENCY_SEVERITY_VALUES).default('HIGH'),
  triage_level: z.enum(TRIAGE_LEVEL_VALUES).optional(),
  notes: z.string().trim().max(65535).optional().nullable()
});

const payNowSchema = z.object({
  method: z.enum(PAYMENT_METHOD_VALUES),
  amount: decimalStringSchema.optional(),
  status: z.enum(PAYMENT_STATUS_VALUES).optional(),
  transaction_ref: z.string().trim().max(120).optional().nullable(),
  paid_at: z.string().datetime().optional()
});

const createOpdFlowSchema = z
  .object({
    tenant_id: scopeIdentifierSchema.optional(),
    facility_id: facilityIdentifierSchema.optional().nullable(),
    patient_id: patientIdentifierSchema.optional(),
    patient_registration: patientRegistrationSchema.optional(),
    arrival_mode: z.enum(ARRIVAL_MODE_VALUES).default('WALK_IN'),
    appointment_id: appointmentIdentifierSchema.optional(),
    visit_queue_id: scopeIdentifierSchema.optional(),
    provider_user_id: providerIdentifierSchema.optional().nullable(),
    initial_stage: z.enum(WORKFLOW_STAGE_VALUES).optional(),
    consultation_fee: decimalStringSchema.optional(),
    currency: z.string().trim().min(1).max(10).optional(),
    create_consultation_invoice: z.boolean().optional(),
    require_consultation_payment: z.boolean().optional(),
    pay_now: payNowSchema.optional(),
    emergency: emergencyPayloadSchema.optional(),
    notes: z.string().trim().max(65535).optional().nullable(),
    queued_at: z.string().datetime().optional()
  })
  .superRefine((data, ctx) => {
    if (!data.patient_id && !data.patient_registration && !data.appointment_id && !data.visit_queue_id) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['patient_id'],
        message: 'errors.opd_flow.patient_or_appointment_required'
      });
    }

    if (data.arrival_mode === 'ONLINE_APPOINTMENT' && !data.appointment_id) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['appointment_id'],
        message: 'errors.opd_flow.appointment_required_for_online_mode'
      });
    }
  });

const bootstrapOpdFlowSchema = z.object({
  patient_id: patientIdentifierSchema,
  facility_id: facilityIdentifierSchema.optional().nullable(),
  provider_user_id: providerIdentifierSchema.optional().nullable(),
  encounter_type: z.enum(['OPD', 'EMERGENCY']).optional().default('OPD'),
  reuse_open_encounter: z.boolean().optional().default(true)
});

const encounterIdParamsSchema = z.object({
  id: encounterIdentifierSchema
});

const resolveLegacyRouteParamsSchema = z.object({
  resource: z.enum(LEGACY_RESOURCE_VALUES),
  id: scopeIdentifierSchema
});

const payConsultationSchema = z.object({
  invoice_id: invoiceIdentifierSchema.optional(),
  amount: decimalStringSchema.optional(),
  currency: z.string().trim().min(1).max(10).optional(),
  method: z.enum(PAYMENT_METHOD_VALUES),
  status: z.enum(PAYMENT_STATUS_VALUES).optional(),
  transaction_ref: z.string().trim().max(120).optional().nullable(),
  paid_at: z.string().datetime().optional(),
  notes: z.string().trim().max(10000).optional().nullable()
});

const decimalInputSchema = z.union([z.coerce.number().positive(), decimalStringSchema]);

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

const assignDoctorSchema = z.object({
  provider_user_id: providerIdentifierSchema
});

const doctorReviewSchema = z.object({
  note: z.string().trim().min(1).max(65535),
  diagnoses: z
    .array(
      z.object({
        diagnosis_type: z.enum(DIAGNOSIS_TYPE_VALUES),
        code: z.string().trim().max(80).optional().nullable(),
        description: z.string().trim().min(1).max(65535)
      })
    )
    .optional(),
  procedures: z
    .array(
      z.object({
        code: z.string().trim().max(80).optional().nullable(),
        description: z.string().trim().min(1).max(65535),
        performed_at: z.string().datetime().optional().nullable()
      })
    )
    .optional(),
  lab_requests: z
    .array(
      z
        .object({
          lab_test_id: resourceFriendlyIdSchema.optional().nullable(),
          lab_panel_id: resourceFriendlyIdSchema.optional().nullable(),
          status: z.enum(LAB_ORDER_STATUS_VALUES).optional()
        })
        .superRefine((value, ctx) => {
          const hasLabTest = Boolean(value?.lab_test_id);
          const hasLabPanel = Boolean(value?.lab_panel_id);

          if (!hasLabTest && !hasLabPanel) {
            ctx.addIssue({
              code: z.ZodIssueCode.custom,
              message: 'Either lab_test_id or lab_panel_id is required.',
              path: ['lab_test_id']
            });
          }

          if (hasLabTest && hasLabPanel) {
            ctx.addIssue({
              code: z.ZodIssueCode.custom,
              message: 'Select either a lab test or a lab panel.',
              path: ['lab_panel_id']
            });
          }
        })
    )
    .optional(),
  radiology_requests: z
    .array(
      z.object({
        radiology_test_id: resourceFriendlyIdSchema.optional().nullable(),
        status: z.enum(RADIOLOGY_ORDER_STATUS_VALUES).optional()
      })
    )
    .optional(),
  medications: z
    .array(
      z.object({
        drug_id: resourceFriendlyIdSchema,
        quantity: z.coerce.number().int().positive(),
        dosage: z.string().trim().max(80).optional().nullable(),
        frequency: z.enum(MEDICATION_FREQUENCY_VALUES).optional().nullable(),
        route: z.enum(MEDICATION_ROUTE_VALUES).optional().nullable(),
        status: z.enum(PRESCRIPTION_STATUS_VALUES).optional()
      })
    )
    .optional(),
  notes: z.string().trim().max(65535).optional().nullable()
});

const dispositionSchema = z.object({
  decision: z.enum(DISPOSITION_VALUES),
  admission_facility_id: facilityIdentifierSchema.optional().nullable(),
  notes: z.string().trim().max(65535).optional().nullable()
});

const correctStageSchema = z.object({
  stage_to: z.enum(WORKFLOW_STAGE_VALUES),
  reason: z.string().trim().max(2000).optional().nullable()
});

const listOpdFlowsQuerySchema = listQuerySchema.extend({
  tenant_id: scopeIdentifierSchema.optional(),
  facility_id: facilityIdentifierSchema.optional(),
  patient_id: patientIdentifierSchema.optional(),
  provider_user_id: providerIdentifierSchema.optional(),
  queue_scope: z.enum(QUEUE_SCOPE_VALUES).optional().default('ALL'),
  encounter_type: z.enum(['OPD', 'EMERGENCY']).optional(),
  stage: z.enum(WORKFLOW_STAGE_VALUES).optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createOpdFlowSchema,
  bootstrapOpdFlowSchema,
  encounterIdParamsSchema,
  resolveLegacyRouteParamsSchema,
  payConsultationSchema,
  recordVitalsSchema,
  assignDoctorSchema,
  doctorReviewSchema,
  dispositionSchema,
  correctStageSchema,
  listOpdFlowsQuerySchema,
  QUEUE_SCOPE_VALUES
};
