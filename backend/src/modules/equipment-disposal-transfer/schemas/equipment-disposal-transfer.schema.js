const { z } = require('zod');
const { uuidSchema, listQuerySchema } = require('@lib/validation/zod');

const createEquipmentDisposalTransferSchema = z.object({
  tenant_id: uuidSchema
}).passthrough();

const updateEquipmentDisposalTransferSchema = z.object({}).passthrough();

const equipmentDisposalTransferIdParamsSchema = z.object({
  id: uuidSchema
});

const listEquipmentDisposalTransfersQuerySchema = listQuerySchema.extend({
  tenant_id: uuidSchema.optional(),
  search: z.string().trim().optional()
}).passthrough();

module.exports = {
  createEquipmentDisposalTransferSchema,
  updateEquipmentDisposalTransferSchema,
  equipmentDisposalTransferIdParamsSchema,
  listEquipmentDisposalTransfersQuerySchema
};
