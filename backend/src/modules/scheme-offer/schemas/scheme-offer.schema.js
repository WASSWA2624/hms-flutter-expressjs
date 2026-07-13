/**
 * Scheme Offer module validation schemas
 *
 * @module modules/scheme-offer/schemas
 * @description Zod validation schemas for scheme offer endpoints.
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

const BillingEntityTypeEnum = z.enum(['FACILITY', 'PHARMACY']);

const CopayTypeEnum = z.enum(['NONE', 'FIXED', 'PERCENT']);

const SchemeOfferLimitPeriodEnum = z.enum(['VISIT', 'YEAR', 'ITEM']);

// ==================== Body Schemas ====================

/**
 * Create scheme offer body validation
 * Used for POST /scheme-offers endpoint
 */
const createSchemeOfferSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  coverage_plan_id: uuidOrFriendlyIdentifierSchema,
  catalog_type: PriceBookCatalogTypeEnum,
  catalog_item_id: z.string().trim().min(1).max(36),
  billing_entity: BillingEntityTypeEnum.optional().default('FACILITY'),
  unit_price: z.number().min(0).finite().optional().nullable(),
  currency: z.string().trim().max(10).optional().nullable(),
  coverage_percentage: z.number().int().min(0).max(100).optional().nullable(),
  copay_type: CopayTypeEnum.optional().default('NONE'),
  copay_value: z.number().min(0).finite().optional().nullable(),
  requires_pre_auth: z.boolean().optional().default(false),
  is_excluded: z.boolean().optional().default(false),
  limit_amount: z.number().min(0).finite().optional().nullable(),
  limit_period: SchemeOfferLimitPeriodEnum.optional().nullable(),
  effective_from: z.string().datetime().optional().nullable(),
  effective_to: z.string().datetime().optional().nullable(),
  is_active: z.boolean().optional().default(true),
  notes: z.string().trim().max(255).optional().nullable()
});

/**
 * Update scheme offer body validation
 * Used for PUT /scheme-offers/:id endpoint
 * All fields optional for partial updates
 */
const updateSchemeOfferSchema = z.object({
  coverage_plan_id: uuidOrFriendlyIdentifierSchema.optional(),
  catalog_type: PriceBookCatalogTypeEnum.optional(),
  catalog_item_id: z.string().trim().min(1).max(36).optional(),
  billing_entity: BillingEntityTypeEnum.optional(),
  unit_price: z.number().min(0).finite().optional().nullable(),
  currency: z.string().trim().max(10).optional().nullable(),
  coverage_percentage: z.number().int().min(0).max(100).optional().nullable(),
  copay_type: CopayTypeEnum.optional(),
  copay_value: z.number().min(0).finite().optional().nullable(),
  requires_pre_auth: z.boolean().optional(),
  is_excluded: z.boolean().optional(),
  limit_amount: z.number().min(0).finite().optional().nullable(),
  limit_period: SchemeOfferLimitPeriodEnum.optional().nullable(),
  effective_from: z.string().datetime().optional().nullable(),
  effective_to: z.string().datetime().optional().nullable(),
  is_active: z.boolean().optional(),
  notes: z.string().trim().max(255).optional().nullable()
});

// ==================== URL Params ====================

/**
 * Scheme Offer ID URL parameter validation
 * Used for GET /:id, PUT /:id, and DELETE /:id endpoints
 */
const schemeOfferIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

// ==================== Query Params ====================

/**
 * List scheme offers query parameter validation
 * Used for GET / endpoint
 * Extends base listQuerySchema with scheme offer-specific filters
 */
const listSchemeOffersQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  coverage_plan_id: uuidOrFriendlyIdentifierSchema.optional(),
  catalog_type: PriceBookCatalogTypeEnum.optional(),
  catalog_item_id: z.string().trim().min(1).max(36).optional(),
  billing_entity: BillingEntityTypeEnum.optional(),
  is_excluded: z.enum(['true', 'false']).optional(),
  requires_pre_auth: z.enum(['true', 'false']).optional(),
  is_active: z.enum(['true', 'false']).optional(),
  search: z.string().trim().optional()
});

module.exports = {
  createSchemeOfferSchema,
  updateSchemeOfferSchema,
  schemeOfferIdParamsSchema,
  listSchemeOffersQuerySchema,
  PriceBookCatalogTypeEnum,
  BillingEntityTypeEnum,
  CopayTypeEnum,
  SchemeOfferLimitPeriodEnum
};
