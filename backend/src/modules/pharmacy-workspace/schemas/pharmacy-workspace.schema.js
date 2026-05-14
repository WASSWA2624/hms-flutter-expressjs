const { z } = require('zod');
const { listQuerySchema, uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');
const { createPharmacyOrderSchema } = require('@validations/pharmacy-order/pharmacy-order.schema');

const pharmacyOrderStatusSchema = z.enum([
  'ORDERED',
  'DISPENSED',
  'PARTIALLY_DISPENSED',
  'CANCELLED',
]);

const stockReasonSchema = z.enum(['PURCHASE', 'DISPENSE', 'RETURN', 'DAMAGE', 'EXPIRY', 'OTHER']);

const panelSchema = z.enum(['orders', 'inventory']);

const orderWorkflowParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

const getPharmacyWorkbenchQuerySchema = listQuerySchema.extend({
  panel: panelSchema.optional(),
  status: pharmacyOrderStatusSchema.optional(),
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  encounter_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional(),
});

const searchDrugsQuerySchema = listQuerySchema.extend({
  search: z.string().trim().optional(),
  name: z.string().trim().optional(),
  code: z.string().trim().optional(),
  form: z.string().trim().optional(),
  strength: z.string().trim().optional(),
  stock_status: z
    .enum(['IN_STOCK', 'ALMOST_OUT_OF_STOCK', 'LOW_STOCK', 'OUT_OF_STOCK'])
    .optional(),
});

const prepareDispenseLineSchema = z.object({
  order_item_id: uuidOrFriendlyIdentifierSchema,
  quantity: z.coerce.number().int().positive(),
  inventory_item_id: uuidOrFriendlyIdentifierSchema.optional(),
  notes: z.string().trim().max(255).optional().nullable(),
});

const prepareDispenseSchema = z.object({
  dispense_batch_ref: z.string().trim().min(3).max(64).optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  statement: z.string().trim().max(65535).optional().nullable(),
  reason: z.string().trim().max(255).optional().nullable(),
  items: z.array(prepareDispenseLineSchema).min(1).optional(),
});

const attestDispenseSchema = z.object({
  dispense_batch_ref: z.string().trim().min(3).max(64),
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  statement: z.string().trim().max(65535).optional().nullable(),
  reason: z.string().trim().max(255).optional().nullable(),
  attested_at: z.string().datetime().optional(),
});

const cancelPharmacyOrderSchema = z.object({
  reason: z.string().trim().min(2).max(255),
  notes: z.string().trim().max(65535).optional().nullable(),
});

const returnDispenseLineSchema = z.object({
  order_item_id: uuidOrFriendlyIdentifierSchema,
  quantity: z.coerce.number().int().positive(),
  inventory_item_id: uuidOrFriendlyIdentifierSchema.optional(),
});

const returnPharmacyOrderSchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  reason: z.string().trim().min(2).max(255).optional().nullable(),
  notes: z.string().trim().max(65535).optional().nullable(),
  items: z.array(returnDispenseLineSchema).min(1),
});

const getInventoryStockQuerySchema = listQuerySchema.extend({
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  inventory_item_id: uuidOrFriendlyIdentifierSchema.optional(),
  low_stock_only: z.coerce.boolean().optional(),
  search: z.string().trim().optional(),
});

const adjustInventorySchema = z.object({
  inventory_item_id: uuidOrFriendlyIdentifierSchema,
  facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  quantity_delta: z.coerce.number().int().refine((value) => value !== 0, {
    message: 'errors.validation.non_zero',
  }),
  reason: stockReasonSchema.optional(),
  notes: z.string().trim().max(255).optional().nullable(),
  occurred_at: z.string().datetime().optional(),
});

const resolveLegacyRouteParamsSchema = z.object({
  resource: z.enum([
    'pharmacy-orders',
    'pharmacy-order-items',
    'dispense-logs',
    'inventory-items',
    'inventory-stocks',
    'stock-movements',
    'drugs',
  ]),
  id: uuidOrFriendlyIdentifierSchema,
});

module.exports = {
  pharmacyOrderStatusSchema,
  orderWorkflowParamsSchema,
  getPharmacyWorkbenchQuerySchema,
  searchDrugsQuerySchema,
  createPharmacyOrderSchema,
  prepareDispenseSchema,
  attestDispenseSchema,
  cancelPharmacyOrderSchema,
  returnPharmacyOrderSchema,
  getInventoryStockQuerySchema,
  adjustInventorySchema,
  resolveLegacyRouteParamsSchema,
};
