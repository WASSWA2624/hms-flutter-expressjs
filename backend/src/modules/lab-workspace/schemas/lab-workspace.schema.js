const { z } = require('zod');
const { listQuerySchema, uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');

const stageFilterSchema = z.enum([
  'ALL',
  'COLLECTION',
  'PROCESSING',
  'RESULTS',
  'COMPLETED',
  'CANCELLED',
]);

const criticalityFilterSchema = z.enum(['ALL', 'CRITICAL', 'NON_CRITICAL']);

const orderWorkflowParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

const sampleWorkflowParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

const orderItemWorkflowParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

const getLabWorkbenchQuerySchema = listQuerySchema.extend({
  stage: stageFilterSchema.optional(),
  status: z.enum(['ORDERED', 'COLLECTED', 'IN_PROCESS', 'COMPLETED', 'CANCELLED']).optional(),
  criticality: criticalityFilterSchema.optional(),
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  encounter_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional(),
});

const collectLabOrderSchema = z.object({
  sample_id: uuidOrFriendlyIdentifierSchema.optional(),
  collected_at: z.string().datetime().optional(),
  notes: z.string().trim().max(65535).optional().nullable(),
});

const receiveLabSampleSchema = z.object({
  received_at: z.string().datetime().optional(),
  notes: z.string().trim().max(65535).optional().nullable(),
});

const rejectLabSampleSchema = z.object({
  reason: z.string().trim().min(2).max(255),
  rejected_at: z.string().datetime().optional(),
  notes: z.string().trim().max(65535).optional().nullable(),
});

const releaseLabOrderItemSchema = z.object({
  result_id: uuidOrFriendlyIdentifierSchema.optional(),
  status: z.enum(['NORMAL', 'ABNORMAL', 'CRITICAL']).optional(),
  result_value: z.string().trim().max(120).optional().nullable(),
  result_unit: z.string().trim().max(40).optional().nullable(),
  result_text: z.string().trim().max(65535).optional().nullable(),
  reported_at: z.string().datetime().optional(),
  notes: z.string().trim().max(65535).optional().nullable(),
});

const reverseLabOrderWorkflowSchema = z.object({
  reason: z.string().trim().min(2).max(65535),
});

module.exports = {
  getLabWorkbenchQuerySchema,
  orderWorkflowParamsSchema,
  sampleWorkflowParamsSchema,
  orderItemWorkflowParamsSchema,
  collectLabOrderSchema,
  receiveLabSampleSchema,
  rejectLabSampleSchema,
  releaseLabOrderItemSchema,
  reverseLabOrderWorkflowSchema,
};
