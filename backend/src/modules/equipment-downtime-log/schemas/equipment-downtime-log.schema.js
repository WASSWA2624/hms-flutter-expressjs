const { z } = require('zod');
const { uuidSchema, listQuerySchema } = require('@lib/validation/zod');

const createEquipmentDowntimeLogSchema = z.object({
  tenant_id: uuidSchema
}).passthrough();

const updateEquipmentDowntimeLogSchema = z.object({}).passthrough();

const equipmentDowntimeLogIdParamsSchema = z.object({
  id: uuidSchema
});

const listEquipmentDowntimeLogsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  search: z.string().trim().optional()
}).passthrough();

module.exports = {
  createEquipmentDowntimeLogSchema,
  updateEquipmentDowntimeLogSchema,
  equipmentDowntimeLogIdParamsSchema,
  listEquipmentDowntimeLogsQuerySchema
};
