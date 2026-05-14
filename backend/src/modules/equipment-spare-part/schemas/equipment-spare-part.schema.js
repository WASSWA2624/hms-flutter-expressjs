const { z } = require('zod');
const { uuidSchema, listQuerySchema } = require('@lib/validation/zod');

const createEquipmentSparePartSchema = z.object({
  tenant_id: uuidSchema
}).passthrough();

const updateEquipmentSparePartSchema = z.object({}).passthrough();

const equipmentSparePartIdParamsSchema = z.object({
  id: uuidSchema
});

const listEquipmentSparePartsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  search: z.string().trim().optional()
}).passthrough();

module.exports = {
  createEquipmentSparePartSchema,
  updateEquipmentSparePartSchema,
  equipmentSparePartIdParamsSchema,
  listEquipmentSparePartsQuerySchema
};
