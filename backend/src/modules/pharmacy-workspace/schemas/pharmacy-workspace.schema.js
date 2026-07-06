const { z } = require('zod');
const { listQuerySchema, uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');
const { createPharmacyOrderSchema } = require('@validations/pharmacy-order/pharmacy-order.schema');
const { clinicalRequestBillingSchema } = require('@lib/billing/clinical-request-billing.schema');

const pharmacyOrderStatusSchema = z.enum([
  'ORDERED',
  'DISPENSED',
  'PARTIALLY_DISPENSED',
  'CANCELLED',
]);

const pharmacyOrderPrioritySchema = z.enum(['STAT', 'URGENT', 'ROUTINE', 'NORMAL']);

const stockReasonSchema = z.enum(['PURCHASE', 'DISPENSE', 'RETURN', 'DAMAGE', 'EXPIRY', 'OTHER']);

const stockStatusSchema = z.enum([
  'IN_STOCK',
  'ALMOST_OUT_OF_STOCK',
  'LOW_STOCK',
  'OUT_OF_STOCK',
]);

const panelSchema = z.enum(['orders', 'inventory']);

const orderWorkflowParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

const orderLocationSchema = z.enum(['OUTPATIENT', 'INPATIENT', 'DISCHARGE']);

const getPharmacyWorkbenchQuerySchema = listQuerySchema.extend({
  panel: panelSchema.optional(),
  status: pharmacyOrderStatusSchema.optional(),
  location: orderLocationSchema.optional(),
  pending_payment: z.coerce.boolean().optional(),
  partial_stock: z.coerce.boolean().optional(),
  urgent: z.coerce.boolean().optional(),
  priority: pharmacyOrderPrioritySchema.optional(),
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
  storage_room_id: uuidOrFriendlyIdentifierSchema.optional(),
  storage_shelf_id: uuidOrFriendlyIdentifierSchema.optional(),
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
  stock_status: stockStatusSchema.optional(),
  expiring_within_days: z.coerce.number().int().min(1).max(365).optional(),
  expired_only: z.coerce.boolean().optional(),
  storage_room_id: uuidOrFriendlyIdentifierSchema.optional(),
  storage_shelf_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional(),
});

const adjustInventorySchema = z
  .object({
    inventory_item_id: uuidOrFriendlyIdentifierSchema,
    facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
    quantity_delta: z.coerce.number().int().optional().default(0),
    reorder_level: z.coerce.number().int().min(0).optional(),
    reason: stockReasonSchema.optional(),
    notes: z.string().trim().max(255).optional().nullable(),
    occurred_at: z.string().datetime().optional(),
    batch_number: z.string().trim().min(1).max(80).optional(),
    expiry_date: z.string().datetime().optional().nullable(),
    storage_room_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
    storage_shelf_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
    drug_id: uuidOrFriendlyIdentifierSchema.optional(),
  })
  .superRefine((data, ctx) => {
    const quantityDelta = Number(data.quantity_delta || 0);
    const hasQuantityChange = quantityDelta !== 0;
    const hasReorderChange = data.reorder_level !== undefined;

    if (!hasQuantityChange && !hasReorderChange) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'errors.validation.required',
        path: ['quantity_delta'],
      });
    }

    if (data.expiry_date && !data.batch_number) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'errors.validation.required',
        path: ['batch_number'],
      });
    }
  });

const setupPharmacyDrugSchema = z
  .object({
    tenant_id: uuidOrFriendlyIdentifierSchema,
    name: z.string().trim().min(1).max(255),
    code: z.string().trim().max(80).optional().nullable(),
    form: z.string().trim().max(80).optional().nullable(),
    strength: z.string().trim().max(80).optional().nullable(),
    unit_price: z.coerce.number().min(0).optional().nullable(),
    currency: z.string().trim().max(10).optional().nullable(),
    inventory_unit: z.string().trim().max(80).optional().nullable(),
    initial_stock: z.coerce.number().int().min(0).optional(),
    reorder_level: z.coerce.number().int().min(0).optional(),
    batch_number: z.string().trim().min(1).max(80).optional(),
    manufactured_at: z.string().datetime().optional().nullable(),
    expiry_date: z.string().datetime().optional().nullable(),
    expiry_alert_lead_days: z.coerce.number().int().min(1).max(730).optional().nullable(),
    storage_room_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
    storage_shelf_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
    default_storage_shelf_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
    facility_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  })
  .superRefine((data, ctx) => {
    if (data.expiry_date && !data.batch_number) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'errors.validation.required',
        path: ['batch_number'],
      });
    }
  });

const recordOrderBillingSchema = z.object({
  billing: clinicalRequestBillingSchema,
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

const getPharmacyStorageLayoutQuerySchema = z.object({
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  include_inactive: z.coerce.boolean().optional(),
});

const createPharmacyStorageRoomSchema = z.object({
  tenant_id: uuidOrFriendlyIdentifierSchema.optional(),
  facility_id: uuidOrFriendlyIdentifierSchema.optional(),
  name: z.string().trim().min(1).max(255),
  code: z.string().trim().max(80).optional().nullable(),
  is_active: z.coerce.boolean().optional(),
});

const updatePharmacyStorageRoomSchema = z.object({
  name: z.string().trim().min(1).max(255).optional(),
  code: z.string().trim().max(80).optional().nullable(),
  is_active: z.coerce.boolean().optional(),
});

const pharmacyStorageRoomParamsSchema = z.object({
  roomId: uuidOrFriendlyIdentifierSchema,
});

const createPharmacyStorageShelfSchema = z.object({
  shelf_code: z.string().trim().min(1).max(80),
  label: z.string().trim().max(120).optional().nullable(),
  is_active: z.coerce.boolean().optional(),
});

const updatePharmacyStorageShelfSchema = z.object({
  shelf_code: z.string().trim().min(1).max(80).optional(),
  label: z.string().trim().max(120).optional().nullable(),
  is_active: z.coerce.boolean().optional(),
});

const pharmacyStorageShelfParamsSchema = z.object({
  shelfId: uuidOrFriendlyIdentifierSchema,
});

module.exports = {
  pharmacyOrderStatusSchema,
  stockStatusSchema,
  orderLocationSchema,
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
  setupPharmacyDrugSchema,
  recordOrderBillingSchema,
  resolveLegacyRouteParamsSchema,
  getPharmacyStorageLayoutQuerySchema,
  createPharmacyStorageRoomSchema,
  updatePharmacyStorageRoomSchema,
  pharmacyStorageRoomParamsSchema,
  createPharmacyStorageShelfSchema,
  updatePharmacyStorageShelfSchema,
  pharmacyStorageShelfParamsSchema,
};
