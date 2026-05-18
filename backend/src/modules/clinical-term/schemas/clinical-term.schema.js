/**
 * Clinical term validation schemas
 */

const { z } = require('zod');
const { listQuerySchema, uuidSchema } = require('@lib/validation/zod');

const TERM_TYPE_VALUES = ['DIAGNOSIS', 'PROCEDURE'];
const TERM_SCOPE_VALUES = ['PERSONAL', 'SHARED'];

const listClinicalTermSuggestionsQuerySchema = z.object({
  tenant_id: uuidSchema.optional(),
  facility_id: uuidSchema.optional().nullable(),
  term_type: z.enum(TERM_TYPE_VALUES).optional().default('DIAGNOSIS'),
  q: z.string().trim().max(120).optional(),
  limit: z.coerce.number().int().min(1).max(1000).optional(),
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
  code: z.string().trim().max(80).optional().nullable(),
  description: z.string().trim().min(1).max(10000),
});

const clinicalTermFavoriteIdParamsSchema = z.object({
  id: uuidSchema,
});

module.exports = {
  listClinicalTermSuggestionsQuerySchema,
  listClinicalTermFavoritesQuerySchema,
  createClinicalTermFavoriteSchema,
  clinicalTermFavoriteIdParamsSchema,
};
