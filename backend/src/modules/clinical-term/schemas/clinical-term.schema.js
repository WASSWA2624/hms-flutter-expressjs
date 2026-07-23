/**
 * Clinical term validation schemas
 */

const { z } = require('zod');
const { listQuerySchema, uuidSchema } = require('@lib/validation/zod');

const TERM_TYPE_VALUES = ['DIAGNOSIS', 'PROCEDURE', 'LAB_TEST', 'LAB_PANEL', 'RADIOLOGY_TEST', 'PRESCRIPTION'];
const TERM_SCOPE_VALUES = ['PERSONAL', 'SHARED'];
const CATALOG_SOURCE_VALUES = ['FAVORITES', 'FACILITY', 'GLOBAL', 'ALL'];

const listClinicalTermSuggestionsQuerySchema = z.object({
  tenant_id: uuidSchema.optional(),
  facility_id: uuidSchema.optional().nullable(),
  term_type: z.enum(TERM_TYPE_VALUES).optional().default('DIAGNOSIS'),
  source: z.enum(CATALOG_SOURCE_VALUES).optional().default('ALL'),
  q: z.string().trim().max(120).optional(),
  limit: z.coerce.number().int().min(1).max(1000).optional(),
});

const listClinicalCatalogSearchQuerySchema = z.object({
  tenant_id: uuidSchema.optional(),
  facility_id: uuidSchema.optional().nullable(),
  term_type: z.enum(TERM_TYPE_VALUES),
  source: z.enum(CATALOG_SOURCE_VALUES).optional().default('ALL'),
  q: z.string().trim().max(120).optional(),
  limit: z.coerce.number().int().min(1).max(1000).optional(),
  offered_only: z.enum(['true', 'false']).optional(),
});

const listClinicalTermFavoritesQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  facility_id: uuidSchema.optional().nullable(),
  term_type: z.enum(TERM_TYPE_VALUES).optional(),
  scope: z.enum(TERM_SCOPE_VALUES).optional(),
  q: z.string().trim().max(120).optional(),
});

const createClinicalTermFavoriteSchema = z.object({
  tenant_id: uuidSchema.optional(),
  facility_id: uuidSchema.optional().nullable(),
  term_type: z.enum(TERM_TYPE_VALUES),
  scope: z.enum(TERM_SCOPE_VALUES).optional().default('PERSONAL'),
  item_id: uuidSchema.optional().nullable(),
  code: z.string().trim().max(80).optional().nullable(),
  description: z.string().trim().min(1).max(10000),
});

const listFacilityCatalogOfferingsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  facility_id: uuidSchema.optional(),
  term_type: z.enum(TERM_TYPE_VALUES).optional(),
  q: z.string().trim().max(120).optional(),
});

const upsertFacilityCatalogOfferingSchema = z.object({
  tenant_id: uuidSchema.optional(),
  facility_id: uuidSchema,
  term_type: z.enum(TERM_TYPE_VALUES),
  item_id: z.string().trim().min(1).max(120),
  is_active: z.boolean().optional().default(true),
  sort_order: z.coerce.number().int().min(0).max(9999).optional().default(0),
});

const facilityCatalogOfferingIdParamsSchema = z.object({
  id: uuidSchema,
});

const clinicalTermFavoriteIdParamsSchema = z.object({
  id: uuidSchema,
});

const CATALOG_TERM_TYPE_VALUES = ['DIAGNOSIS', 'PROCEDURE'];

const createCatalogTermSchema = z.object({
  tenant_id: uuidSchema.optional(),
  term_type: z.enum(CATALOG_TERM_TYPE_VALUES).optional().default('DIAGNOSIS'),
  code: z.string().trim().max(80).optional().nullable(),
  description: z.string().trim().min(1).max(10000),
  category: z.string().trim().max(120).optional().nullable(),
  catalog_key: z.string().trim().max(120).optional().nullable(),
  source: z.string().trim().max(80).optional().default('CUSTOM'),
  sort_order: z.coerce.number().int().min(0).max(9999).optional().default(0),
  usage_rank: z.coerce.number().int().min(0).max(9999).optional().default(0),
});

const updateCatalogTermSchema = z.object({
  code: z.string().trim().max(80).optional().nullable(),
  description: z.string().trim().min(1).max(10000).optional(),
  category: z.string().trim().max(120).optional().nullable(),
  source: z.string().trim().max(80).optional(),
  sort_order: z.coerce.number().int().min(0).max(9999).optional(),
  usage_rank: z.coerce.number().int().min(0).max(9999).optional(),
  is_active: z.boolean().optional(),
});

const catalogTermIdParamsSchema = z.object({
  id: uuidSchema,
});

module.exports = {
  listClinicalTermSuggestionsQuerySchema,
  listClinicalCatalogSearchQuerySchema,
  listClinicalTermFavoritesQuerySchema,
  createClinicalTermFavoriteSchema,
  clinicalTermFavoriteIdParamsSchema,
  listFacilityCatalogOfferingsQuerySchema,
  upsertFacilityCatalogOfferingSchema,
  facilityCatalogOfferingIdParamsSchema,
  createCatalogTermSchema,
  updateCatalogTermSchema,
  catalogTermIdParamsSchema,
};
