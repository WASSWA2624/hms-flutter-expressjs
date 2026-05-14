const { z } = require('zod');
const { uuidOrFriendlyIdentifierSchema, listQuerySchema } = require('@lib/validation/zod');

const createEquipmentWorkOrderSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema
}).passthrough();

const updateEquipmentWorkOrderSchema = z.object({}).passthrough();

const startEquipmentWorkOrderSchema = z.object({
  notes: z.string().trim().max(10000).optional().nullable(),
  started_at: z.string().datetime().optional().nullable()
});

const returnToServiceEquipmentWorkOrderSchema = z.object({
  verification_evidence_manifest: z.array(z.object({}).passthrough()).min(1),
  notes: z.string().trim().max(10000).optional().nullable()
});

const equipmentWorkOrderIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

const listEquipmentWorkOrdersQuerySchema = listQuerySchema.extend({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  equipment_registry_id: uuidOrFriendlyIdentifierSchema.optional(),
  assigned_engineer_user_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional()
}).passthrough();

module.exports = {
  createEquipmentWorkOrderSchema,
  updateEquipmentWorkOrderSchema,
  startEquipmentWorkOrderSchema,
  returnToServiceEquipmentWorkOrderSchema,
  equipmentWorkOrderIdParamsSchema,
  listEquipmentWorkOrdersQuerySchema
};
