const { z } = require('zod');
const { uuidSchema, listQuerySchema } = require('@lib/validation/zod');

const createEquipmentCalibrationLogSchema = z.object({
  tenant_id: uuidSchema
}).passthrough();

const updateEquipmentCalibrationLogSchema = z.object({}).passthrough();

const equipmentCalibrationLogIdParamsSchema = z.object({
  id: uuidSchema
});

const listEquipmentCalibrationLogsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  search: z.string().trim().optional()
}).passthrough();

module.exports = {
  createEquipmentCalibrationLogSchema,
  updateEquipmentCalibrationLogSchema,
  equipmentCalibrationLogIdParamsSchema,
  listEquipmentCalibrationLogsQuerySchema
};
