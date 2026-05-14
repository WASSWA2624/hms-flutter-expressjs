const { z } = require('zod');
const { uuidSchema, listQuerySchema } = require('@lib/validation/zod');

const createEquipmentUtilizationSnapshotSchema = z.object({
  tenant_id: uuidSchema
}).passthrough();

const updateEquipmentUtilizationSnapshotSchema = z.object({}).passthrough();

const equipmentUtilizationSnapshotIdParamsSchema = z.object({
  id: uuidSchema
});

const listEquipmentUtilizationSnapshotsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  search: z.string().trim().optional()
}).passthrough();

module.exports = {
  createEquipmentUtilizationSnapshotSchema,
  updateEquipmentUtilizationSnapshotSchema,
  equipmentUtilizationSnapshotIdParamsSchema,
  listEquipmentUtilizationSnapshotsQuerySchema
};
