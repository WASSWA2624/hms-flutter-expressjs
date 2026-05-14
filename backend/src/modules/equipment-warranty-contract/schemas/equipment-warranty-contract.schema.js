const { z } = require('zod');
const { uuidSchema, listQuerySchema } = require('@lib/validation/zod');

const createEquipmentWarrantyContractSchema = z.object({
  tenant_id: uuidSchema
}).passthrough();

const updateEquipmentWarrantyContractSchema = z.object({}).passthrough();

const equipmentWarrantyContractIdParamsSchema = z.object({
  id: uuidSchema
});

const listEquipmentWarrantyContractsQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  search: z.string().trim().optional()
}).passthrough();

module.exports = {
  createEquipmentWarrantyContractSchema,
  updateEquipmentWarrantyContractSchema,
  equipmentWarrantyContractIdParamsSchema,
  listEquipmentWarrantyContractsQuerySchema
};
