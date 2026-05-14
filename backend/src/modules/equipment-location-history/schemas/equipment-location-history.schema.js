const { z } = require('zod');
const { uuidSchema, listQuerySchema } = require('@lib/validation/zod');

const createEquipmentLocationHistorySchema = z.object({
  tenant_id: uuidSchema
}).passthrough();

const updateEquipmentLocationHistorySchema = z.object({}).passthrough();

const equipmentLocationHistoryIdParamsSchema = z.object({
  id: uuidSchema
});

const listEquipmentLocationHistorysQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  search: z.string().trim().optional()
}).passthrough();

module.exports = {
  createEquipmentLocationHistorySchema,
  updateEquipmentLocationHistorySchema,
  equipmentLocationHistoryIdParamsSchema,
  listEquipmentLocationHistorysQuerySchema
};
