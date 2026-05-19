/**
 * Pharmacy order item module validation schemas
 *
 * @module modules/pharmacy-order-item/schemas
 * @description Zod validation schemas for pharmacy order item endpoints.
 */

const { z } = require('zod');
const {
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema
} = require('@lib/validation/zod');

const PRESCRIPTION_STATUS_VALUES = ['DRAFT', 'ACTIVE', 'COMPLETED', 'CANCELLED'];

const MEDICATION_ROUTE_VALUES = [
  'ORAL',
  'IV',
  'IM',
  'SC',
  'SUBLINGUAL',
  'RECTAL',
  'VAGINAL',
  'TOPICAL',
  'INHALATION',
  'OPHTHALMIC',
  'OTIC',
  'NASAL',
  'INTRADERMAL',
  'OTHER',
];

const MEDICATION_FREQUENCY_VALUES = [
  'ONCE',
  'OD',
  'BID',
  'TID',
  'QID',
  'Q4H',
  'Q6H',
  'Q8H',
  'Q12H',
  'QHS',
  'WEEKLY',
  'PRN',
  'STAT',
  'CUSTOM',
];

const sharedPharmacyOrderItemFields = {
  quantity: z.coerce.number().int().positive(),
  quantity_unit: z.string().trim().min(1).max(40).optional().nullable(),
  dosage: z.string().trim().max(80).optional().nullable(),
  dose_amount: z.coerce.number().positive().optional().nullable(),
  dose_unit: z.string().trim().min(1).max(40).optional().nullable(),
  duration_value: z.coerce.number().int().positive().optional().nullable(),
  duration_unit: z.string().trim().min(1).max(40).optional().nullable(),
  instructions: z.string().trim().max(5000).optional().nullable(),
  custom_prescription: z.string().trim().max(5000).optional().nullable(),
  frequency: z.enum(MEDICATION_FREQUENCY_VALUES).optional().nullable(),
  route: z.enum(MEDICATION_ROUTE_VALUES).optional().nullable(),
  status: z.enum(PRESCRIPTION_STATUS_VALUES).optional()
};

const refinePharmacyOrderItem = (value, ctx) => {
  const hasStructuredDose =
    value.dose_amount !== undefined && value.dose_amount !== null;
  const hasLegacyDose = Boolean(String(value.dosage || '').trim());
  const hasCustomPrescription = Boolean(
    String(value.custom_prescription || '').trim()
  );

  if (!hasStructuredDose && !hasLegacyDose && !hasCustomPrescription) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['dose_amount'],
      message: 'errors.validation.required',
    });
  }

  if (
    value.duration_value !== undefined &&
    value.duration_value !== null &&
    !String(value.duration_unit || '').trim()
  ) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['duration_unit'],
      message: 'errors.validation.required',
    });
  }

  if (
    String(value.frequency || '').trim() === 'CUSTOM' &&
    !String(value.instructions || value.custom_prescription || '').trim()
  ) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['instructions'],
      message: 'errors.validation.required',
    });
  }
};

/**
 * Create pharmacy order item body validation
 */
const createPharmacyOrderItemSchema = z
  .object({
    pharmacy_order_id: uuidOrFriendlyIdentifierSchema,
    drug_id: uuidOrFriendlyIdentifierSchema,
    ...sharedPharmacyOrderItemFields,
  })
  .superRefine(refinePharmacyOrderItem);

/**
 * Update pharmacy order item body validation
 */
const updatePharmacyOrderItemSchema = z
  .object({
    pharmacy_order_id: uuidOrFriendlyIdentifierSchema.optional(),
    drug_id: uuidOrFriendlyIdentifierSchema.optional(),
    ...Object.fromEntries(
      Object.entries(sharedPharmacyOrderItemFields).map(([key, value]) => [
        key,
        value.optional(),
      ])
    ),
  })
  .superRefine((value, ctx) => {
    if (
      value.dose_amount !== undefined ||
      value.dose_unit !== undefined ||
      value.dosage !== undefined ||
      value.custom_prescription !== undefined ||
      value.duration_value !== undefined ||
      value.duration_unit !== undefined ||
      value.frequency !== undefined ||
      value.instructions !== undefined
    ) {
      refinePharmacyOrderItem(value, ctx);
    }
  });

/**
 * Pharmacy order item ID URL parameter validation
 */
const pharmacyOrderItemIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

/**
 * List pharmacy order items query validation
 */
const listPharmacyOrderItemsQuerySchema = listQuerySchema.extend({
  pharmacy_order_id: uuidOrFriendlyIdentifierSchema.optional(),
  drug_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(PRESCRIPTION_STATUS_VALUES).optional(),
  route: z.enum(MEDICATION_ROUTE_VALUES).optional(),
  frequency: z.enum(MEDICATION_FREQUENCY_VALUES).optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createPharmacyOrderItemSchema,
  updatePharmacyOrderItemSchema,
  pharmacyOrderItemIdParamsSchema,
  listPharmacyOrderItemsQuerySchema
};
