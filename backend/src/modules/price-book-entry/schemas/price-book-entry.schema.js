/**
 * Price Book Entry module validation schemas
 *
 * @module modules/price-book-entry/schemas
 * @description Zod validation schemas for price book entry endpoints.
 * Per validation.mdc: Use Zod exclusively for all validation
 * Per module-creation.mdc: Define schemas for body, params, and query
 */

const { z } = require('zod');
const {
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema
} = require('@lib/validation/zod');

// ==================== Enums ====================

const PriceBookCatalogTypeEnum = z.enum([
  'DRUG',
  'LAB_TEST',
  'LAB_PANEL',
  'RADIOLOGY_TEST',
  'CONSULTATION',
  'SERVICE'
]);

const PriceBookPaymentModeEnum = z.enum(['SELF_PAY', 'INSURANCE']);

const BillingEntityTypeEnum = z.enum(['FACILITY', 'PHARMACY']);

// ==================== Body Schemas ====================

/**
 * Create price book entry body validation
 * Used for POST /price-book-entries endpoint
 */
const createPriceBookEntrySchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  catalog_type: PriceBookCatalogTypeEnum,
  catalog_item_id: z.string().trim().min(1).max(36),
  payment_mode: PriceBookPaymentModeEnum,
  coverage_plan_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  insurer_key: z.string().trim().max(120).optional().nullable(),
  billing_entity: BillingEntityTypeEnum.optional().default('FACILITY'),
  unit_price: z.number().min(0).finite(),
  currency: z.string().trim().length(3).toUpperCase(),
  effective_from: z.string().datetime().optional().nullable(),
  effective_to: z.string().datetime().optional().nullable(),
  is_active: z.boolean().optional().default(true),
  notes: z.string().trim().max(255).optional().nullable()
});

/**
 * Update price book entry body validation
 * Used for PUT /price-book-entries/:id endpoint
 * All fields optional for partial updates
 */
const updatePriceBookEntrySchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  catalog_type: PriceBookCatalogTypeEnum.optional(),
  catalog_item_id: z.string().trim().min(1).max(36).optional(),
  payment_mode: PriceBookPaymentModeEnum.optional(),
  coverage_plan_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  insurer_key: z.string().trim().max(120).optional().nullable(),
  billing_entity: BillingEntityTypeEnum.optional(),
  unit_price: z.number().min(0).finite().optional(),
  currency: z.string().trim().length(3).toUpperCase().optional(),
  effective_from: z.string().datetime().optional().nullable(),
  effective_to: z.string().datetime().optional().nullable(),
  is_active: z.boolean().optional(),
  notes: z.string().trim().max(255).optional().nullable()
});

/**
 * Resolve unit prices body validation
 * Used for POST /price-book-entries/resolve
 */
const resolvePriceBookEntriesSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  payment_mode: PriceBookPaymentModeEnum.optional(),
  coverage_plan_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  insurer_key: z.string().trim().max(120).optional().nullable(),
  billing_entity: BillingEntityTypeEnum.optional(),
  currency: z.string().trim().length(3).toUpperCase().optional().nullable(),
  items: z
    .array(
      z.object({
        id: z.string().trim().optional().nullable(),
        catalog_type: PriceBookCatalogTypeEnum,
        catalog_item_id: z.string().trim().min(1).max(36),
        quantity: z.number().positive().finite().optional(),
        price_source: BillingEntityTypeEnum.optional().nullable()
      })
    )
    .min(1)
});

// ==================== URL Params ====================

/**
 * Price Book Entry ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const priceBookEntryIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List price book entries query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with price book entry-specific filters
 */
const listPriceBookEntriesQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  catalog_type: PriceBookCatalogTypeEnum.optional(),
  catalog_item_id: z.string().trim().min(1).max(36).optional(),
  payment_mode: PriceBookPaymentModeEnum.optional(),
  coverage_plan_id: uuidOrFriendlyIdentifierSchema.optional(),
  billing_entity: BillingEntityTypeEnum.optional(),
  is_active: z.enum(['true', 'false']).optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createPriceBookEntrySchema,
  updatePriceBookEntrySchema,
  resolvePriceBookEntriesSchema,
  priceBookEntryIdParamsSchema,
  listPriceBookEntriesQuerySchema,
  PriceBookCatalogTypeEnum,
  PriceBookPaymentModeEnum,
  BillingEntityTypeEnum
};
