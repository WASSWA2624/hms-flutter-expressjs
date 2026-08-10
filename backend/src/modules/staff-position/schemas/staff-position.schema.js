/**
 * Staff position module validation schemas
 */

const { z } = require('zod');
const {
  uuidOrFriendlyIdentifierSchema,
  listQuerySchema
} = require('@lib/validation/zod');

const createStaffPositionSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema,
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  department_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().trim().min(1).max(120),
  description: z.string().trim().max(255).optional().nullable(),
  is_active: z.boolean().optional(),
  confirm_similar: z.boolean().optional()
});

const updateStaffPositionSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  department_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  name: z.string().trim().min(1).max(120).optional(),
  description: z.string().trim().max(255).optional().nullable(),
  is_active: z.boolean().optional(),
  confirm_similar: z.boolean().optional()
});

const staffPositionIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

const listStaffPositionsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  department_id: uuidOrFriendlyIdentifierSchema.optional(),
  name: z.string().trim().optional(),
  is_active: z
    .string()
    .transform((val) => val === 'true')
    .optional(),
  search: z.string().trim().optional(),
  include_deleted: z
    .union([z.boolean(), z.string()])
    .optional()
    .transform((val) => val === true || val === 'true')
});

module.exports = {
  createStaffPositionSchema,
  updateStaffPositionSchema,
  staffPositionIdParamsSchema,
  listStaffPositionsQuerySchema
};
