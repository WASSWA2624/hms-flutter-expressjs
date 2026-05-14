const { z } = require('zod');
const { uuidSchema, listQuerySchema } = require('@lib/validation/zod');

const createEquipmentServiceProviderSchema = z.object({
  tenant_id: uuidSchema
}).passthrough();

const updateEquipmentServiceProviderSchema = z.object({}).passthrough();

const equipmentServiceProviderIdParamsSchema = z.object({
  id: uuidSchema
});

const listEquipmentServiceProvidersQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  search: z.string().trim().optional()
}).passthrough();

module.exports = {
  createEquipmentServiceProviderSchema,
  updateEquipmentServiceProviderSchema,
  equipmentServiceProviderIdParamsSchema,
  listEquipmentServiceProvidersQuerySchema
};
