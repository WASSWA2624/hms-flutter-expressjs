const { z } = require('zod');
const { listQuerySchema, uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');

const stageFilterSchema = z.enum([
  'ALL',
  'COLLECTION',
  'PENDING',
  'PROCESSING', // legacy alias → pending
  'RESULTS', // legacy alias → pending
  'COMPLETED',
  'CANCELLED']);

const criticalityFilterSchema = z.enum(['ALL', 'CRITICAL', 'NON_CRITICAL']);
const workbenchViewSchema = z.enum(['PATIENTS', 'ORDERS', 'patients', 'orders']);

const orderWorkflowParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema});

const sampleWorkflowParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema});

const orderItemWorkflowParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema});

const getLabWorkbenchQuerySchema = listQuerySchema.extend({
  stage: stageFilterSchema.optional(),
  status: z.enum(['ORDERED', 'COLLECTED', 'IN_PROCESS', 'COMPLETED', 'CANCELLED']).optional(),
  criticality: criticalityFilterSchema.optional(),
  view: workbenchViewSchema.optional(),
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  encounter_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional()});

const searchLabOrderContextPatientsQuerySchema = listQuerySchema.extend({
  search: z.string().trim().max(120).optional()});

const labOrderContextPatientParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema});

const collectLabOrderSchema = z.object({
  sample_id: uuidOrFriendlyIdentifierSchema.optional(),
  collected_at: z.string().datetime().optional(),
  notes: z.string().trim().max(65535).optional().nullable()});

const receiveLabSampleSchema = z.object({
  received_at: z.string().datetime().optional(),
  notes: z.string().trim().max(65535).optional().nullable()});

const rejectLabSampleSchema = z.object({
  reason: z.string().trim().min(2).max(255),
  rejected_at: z.string().datetime().optional(),
  notes: z.string().trim().max(65535).optional().nullable()});

const saveLabOrderItemResultSchema = z.object({
  result_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(['NORMAL', 'ABNORMAL', 'CRITICAL']).optional(),
  result_value: z.string().trim().max(120).optional().nullable(),
  result_unit: z.string().trim().max(40).optional().nullable(),
  result_text: z.string().trim().max(65535).optional().nullable(),
  reported_at: z.string().datetime().optional(),
  notes: z.string().trim().max(65535).optional().nullable()});

const saveLabOrderResultItemSchema = saveLabOrderItemResultSchema.extend({
  order_item_id: uuidOrFriendlyIdentifierSchema});

const saveLabOrderResultsSchema = z.object({
  results: z.array(saveLabOrderResultItemSchema).min(1).max(100)});

const rejectLabOrderItemSchema = z.object({
  reason: z.string().trim().min(2).max(255),
  rejected_at: z.string().datetime().optional(),
  notes: z.string().trim().max(65535).optional().nullable()});

const reverseLabOrderWorkflowSchema = z.object({
  reason: z.string().trim().min(2).max(65535)});

const reopenLabOrderItemResultSchema = z.object({
  reason: z.string().trim().min(2).max(65535),
  notes: z.string().trim().max(65535).optional().nullable()});

const restoreLabOrderItemSchema = z.object({
  reason: z.string().trim().max(65535).optional().nullable(),
  notes: z.string().trim().max(65535).optional().nullable()});

const deleteLabOrderItemsSchema = z
  .object({
    panel_id: z.string().trim().min(1).max(64).optional().nullable(),
    order_item_ids: z
      .array(uuidOrFriendlyIdentifierSchema)
      .min(1)
      .max(100)
      .optional(),
    reason: z.string().trim().max(65535).optional().nullable(),
    notes: z.string().trim().max(65535).optional().nullable()})
  .refine(
    (value) =>
      Boolean(value.panel_id) ||
      (Array.isArray(value.order_item_ids) && value.order_item_ids.length > 0),
    {
      message: 'Either panel_id or order_item_ids must be provided.',
      path: ['order_item_ids']}
  );

module.exports = {
  getLabWorkbenchQuerySchema,
  searchLabOrderContextPatientsQuerySchema,
  labOrderContextPatientParamsSchema,
  orderWorkflowParamsSchema,
  sampleWorkflowParamsSchema,
  orderItemWorkflowParamsSchema,
  collectLabOrderSchema,
  receiveLabSampleSchema,
  rejectLabSampleSchema,
  saveLabOrderItemResultSchema,
  saveLabOrderResultsSchema,
  rejectLabOrderItemSchema,
  reverseLabOrderWorkflowSchema,
  reopenLabOrderItemResultSchema,
  restoreLabOrderItemSchema,
  deleteLabOrderItemsSchema};
