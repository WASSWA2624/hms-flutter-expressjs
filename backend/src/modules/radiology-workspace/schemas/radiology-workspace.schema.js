const { z } = require('zod');
const { listQuerySchema, uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');

const imagingModalitySchema = z.enum([
  'XRAY',
  'CT',
  'MRI',
  'ULTRASOUND',
  'PET',
  'ECG',
  'ECHO',
  'ENDO',
  'GASTRO',
  'OTHER',
]);

const stageFilterSchema = z.enum([
  'ALL',
  'ORDERED',
  'PROCESSING',
  'REPORTING',
  'COMPLETED',
  'CANCELLED',
]);

const orderWorkflowParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

const studyWorkflowParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

const resultWorkflowParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema,
});

const getRadiologyWorkbenchQuerySchema = listQuerySchema.extend({
  stage: stageFilterSchema.optional(),
  status: z.enum(['ORDERED', 'IN_PROCESS', 'COMPLETED', 'CANCELLED']).optional(),
  modality: imagingModalitySchema.optional(),
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  encounter_id: uuidOrFriendlyIdentifierSchema.optional(),
  search: z.string().trim().optional(),
});

const referenceDataQuerySchema = z.object({
  search: z.string().trim().max(120).optional(),
  patient_id: uuidOrFriendlyIdentifierSchema.optional(),
  limit: z.coerce.number().int().min(1).max(50).optional(),
});

const createRadiologyOrderSchema = z.object({
  patient_id: uuidOrFriendlyIdentifierSchema,
  encounter_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  radiology_test_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  ordered_at: z.string().datetime().optional(),
  notes: z.string().trim().max(65535).optional().nullable(),
});

const assignRadiologyOrderSchema = z.object({
  assignee_user_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
  notes: z.string().trim().max(65535).optional().nullable(),
});

const startRadiologyOrderSchema = z.object({
  started_at: z.string().datetime().optional(),
  notes: z.string().trim().max(65535).optional().nullable(),
});

const completeRadiologyOrderSchema = z.object({
  completed_at: z.string().datetime().optional(),
  notes: z.string().trim().max(65535).optional().nullable(),
});

const cancelRadiologyOrderSchema = z.object({
  reason: z.string().trim().min(2).max(255),
  cancelled_at: z.string().datetime().optional(),
  notes: z.string().trim().max(65535).optional().nullable(),
});

const createRadiologyStudySchema = z.object({
  modality: imagingModalitySchema.optional(),
  performed_at: z.string().datetime().optional(),
  notes: z.string().trim().max(65535).optional().nullable(),
});

const initUploadAssetSchema = z.object({
  file_name: z.string().trim().min(1).max(255),
  content_type: z.string().trim().max(120).optional().nullable(),
  size_bytes: z.coerce.number().int().positive().optional(),
});

const commitUploadAssetSchema = z.object({
  storage_key: z.string().trim().min(1).max(255),
  file_name: z.string().trim().max(255).optional().nullable(),
  content_type: z.string().trim().max(120).optional().nullable(),
  upload_token: z.string().trim().max(255).optional().nullable(),
});

const pacsSyncStudySchema = z.object({
  study_uid: z.string().trim().max(255).optional().nullable(),
  instances: z.array(z.any()).optional(),
  metadata: z.array(z.record(z.any())).optional(),
  notes: z.string().trim().max(65535).optional().nullable(),
});

const draftRadiologyResultSchema = z.object({
  report_text: z.string().trim().max(65535).optional().nullable(),
  findings: z.string().trim().max(65535).optional().nullable(),
  impression: z.string().trim().max(65535).optional().nullable(),
  reported_at: z.string().datetime().optional(),
});

const finalizeRadiologyResultSchema = z.object({
  report_text: z.string().trim().max(65535).optional().nullable(),
  reported_at: z.string().datetime().optional(),
  notes: z.string().trim().max(65535).optional().nullable(),
});

const requestFinalizationRadiologyResultSchema = z.object({
  statement: z.string().trim().max(65535).optional().nullable(),
  reason: z.string().trim().max(255).optional().nullable(),
  requested_at: z.string().datetime().optional(),
  notes: z.string().trim().max(65535).optional().nullable(),
});

const attestFinalizationRadiologyResultSchema = z.object({
  statement: z.string().trim().max(65535).optional().nullable(),
  reason: z.string().trim().max(255).optional().nullable(),
  report_text: z.string().trim().max(65535).optional().nullable(),
  reported_at: z.string().datetime().optional(),
  attested_at: z.string().datetime().optional(),
  notes: z.string().trim().max(65535).optional().nullable(),
});

const addendumRadiologyResultSchema = z.object({
  addendum_text: z.string().trim().min(2).max(65535),
  reported_at: z.string().datetime().optional(),
  notes: z.string().trim().max(65535).optional().nullable(),
});

module.exports = {
  getRadiologyWorkbenchQuerySchema,
  referenceDataQuerySchema,
  orderWorkflowParamsSchema,
  studyWorkflowParamsSchema,
  resultWorkflowParamsSchema,
  createRadiologyOrderSchema,
  assignRadiologyOrderSchema,
  startRadiologyOrderSchema,
  completeRadiologyOrderSchema,
  cancelRadiologyOrderSchema,
  createRadiologyStudySchema,
  initUploadAssetSchema,
  commitUploadAssetSchema,
  pacsSyncStudySchema,
  draftRadiologyResultSchema,
  finalizeRadiologyResultSchema,
  requestFinalizationRadiologyResultSchema,
  attestFinalizationRadiologyResultSchema,
  addendumRadiologyResultSchema,
};
