const { z } = require('zod');
const { uuidSchema, listQuerySchema } = require('@lib/validation/zod');

const createEquipmentSafetyTestLogSchema = z.object({
  tenant_id: uuidSchema
}).passthrough();

const updateEquipmentSafetyTestLogSchema = z.object({}).passthrough();

const equipmentSafetyTestLogIdParamsSchema = z.object({
  id: uuidSchema
});

const listEquipmentSafetyTestLogsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  search: z.string().trim().optional()
}).passthrough();

module.exports = {
  createEquipmentSafetyTestLogSchema,
  updateEquipmentSafetyTestLogSchema,
  equipmentSafetyTestLogIdParamsSchema,
  listEquipmentSafetyTestLogsQuerySchema
};
