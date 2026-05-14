const { z } = require('zod');
const { uuidSchema, listQuerySchema } = require('@lib/validation/zod');

const createEquipmentRecallNoticeSchema = z.object({
  tenant_id: uuidSchema
}).passthrough();

const updateEquipmentRecallNoticeSchema = z.object({}).passthrough();

const equipmentRecallNoticeIdParamsSchema = z.object({
  id: uuidSchema
});

const listEquipmentRecallNoticesQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  search: z.string().trim().optional()
}).passthrough();

module.exports = {
  createEquipmentRecallNoticeSchema,
  updateEquipmentRecallNoticeSchema,
  equipmentRecallNoticeIdParamsSchema,
  listEquipmentRecallNoticesQuerySchema
};
