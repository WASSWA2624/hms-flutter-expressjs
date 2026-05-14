const { z } = require('zod');
const { uuidSchema, listQuerySchema } = require('@lib/validation/zod');

const createEquipmentIncidentReportSchema = z.object({
  tenant_id: uuidSchema
}).passthrough();

const updateEquipmentIncidentReportSchema = z.object({}).passthrough();

const equipmentIncidentReportIdParamsSchema = z.object({
  id: uuidSchema
});

const listEquipmentIncidentReportsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  search: z.string().trim().optional()
}).passthrough();

module.exports = {
  createEquipmentIncidentReportSchema,
  updateEquipmentIncidentReportSchema,
  equipmentIncidentReportIdParamsSchema,
  listEquipmentIncidentReportsQuerySchema
};
