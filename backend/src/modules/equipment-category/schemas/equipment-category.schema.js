const { z } = require('zod');
const { uuidSchema, listQuerySchema } = require('@lib/validation/zod');

const createEquipmentCategorySchema = z.object({
  tenant_id: uuidSchema
}).passthrough();

const updateEquipmentCategorySchema = z.object({}).passthrough();

const equipmentCategoryIdParamsSchema = z.object({
  id: uuidSchema
});

const listEquipmentCategorysQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  search: z.string().trim().optional()
}).passthrough();

module.exports = {
  createEquipmentCategorySchema,
  updateEquipmentCategorySchema,
  equipmentCategoryIdParamsSchema,
  listEquipmentCategorysQuerySchema
};
