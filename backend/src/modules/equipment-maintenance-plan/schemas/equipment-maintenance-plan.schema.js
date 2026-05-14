const { z } = require('zod');
const { uuidSchema, listQuerySchema } = require('@lib/validation/zod');

const createEquipmentMaintenancePlanSchema = z.object({
  tenant_id: uuidSchema
}).passthrough();

const updateEquipmentMaintenancePlanSchema = z.object({}).passthrough();

const equipmentMaintenancePlanIdParamsSchema = z.object({
  id: uuidSchema
});

const listEquipmentMaintenancePlansQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  search: z.string().trim().optional()
}).passthrough();

module.exports = {
  createEquipmentMaintenancePlanSchema,
  updateEquipmentMaintenancePlanSchema,
  equipmentMaintenancePlanIdParamsSchema,
  listEquipmentMaintenancePlansQuerySchema
};
