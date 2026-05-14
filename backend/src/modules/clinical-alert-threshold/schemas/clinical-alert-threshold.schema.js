/**
 * Clinical alert threshold validation schemas
 */

const { z } = require('zod');
const { uuidSchema } = require('@lib/validation/zod');

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

const AGE_BAND_VALUES = ['NEONATE', 'INFANT', 'CHILD', 'ADOLESCENT', 'ADULT'];

const listClinicalAlertThresholdsQuerySchema = z.object({
  tenant_id: uuidSchema.optional(),
  facility_id: uuidSchema.optional().nullable(),
  vital_type: z.enum(VITAL_TYPE_VALUES).optional(),
});

const thresholdRuleSchema = z.object({
  vital_type: z.enum(VITAL_TYPE_VALUES),
  component: z.string().trim().min(1).max(32).default('VALUE'),
  age_band: z.enum(AGE_BAND_VALUES).default('ADULT'),
  normal_min: z.coerce.number().optional().nullable(),
  normal_max: z.coerce.number().optional().nullable(),
  critical_low: z.coerce.number().optional().nullable(),
  critical_high: z.coerce.number().optional().nullable(),
  is_active: z.boolean().optional().default(true),
});

const updateClinicalAlertThresholdsSchema = z.object({
  tenant_id: uuidSchema.optional(),
  facility_id: uuidSchema.optional().nullable(),
  rules: z.array(thresholdRuleSchema).min(1),
});

module.exports = {
  listClinicalAlertThresholdsQuerySchema,
  updateClinicalAlertThresholdsSchema,
};

