const { z } = require('zod');
const { uuidSchema, listQuerySchema } = require('@lib/validation/zod');

const createEquipmentRegistrySchema = z.object({
  tenant_id: uuidSchema
}).passthrough();

const updateEquipmentRegistrySchema = z.object({}).passthrough();

const equipmentRegistryIdParamsSchema = z.object({
  id: uuidSchema
});

const listEquipmentRegistrysQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  search: z.string().trim().optional()
}).passthrough();

module.exports = {
  createEquipmentRegistrySchema,
  updateEquipmentRegistrySchema,
  equipmentRegistryIdParamsSchema,
  listEquipmentRegistrysQuerySchema
};
