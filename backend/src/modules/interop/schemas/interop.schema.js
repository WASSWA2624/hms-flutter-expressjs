/**
 * Interop module validation schemas
 */

const { z } = require('zod');
const { uuidOrFriendlyIdentifierSchema, urlSchema } = require('@lib/validation/zod');

const interopResourceParamsSchema = z.object({
  resource: z.string().trim().min(1).max(80)
});

const interopStudyIdParamsSchema = z.object({
  id: uuidOrFriendlyIdentifierSchema
});

const fhirImportSchema = z.object({
  records: z.array(z.any()).optional(),
  mode: z.enum(['merge', 'replace']).optional(),
  source_system: z.string().trim().max(120).optional().nullable()
});

const hl7MessagesSchema = z.object({
  message: z.string().trim().min(1).max(50000),
  source_system: z.string().trim().max(120).optional().nullable()
});

const dicomStudyLinkSchema = z.object({
  study_uid: z.string().trim().min(1).max(255),
  pacs_url: urlSchema.max(255).optional().nullable(),
  notes: z.string().trim().max(10000).optional().nullable()
});

const interopMigrationImportSchema = z.object({
  payload: z.any(),
  mode: z.enum(['append', 'replace']).optional(),
  source_system: z.string().trim().max(120).optional().nullable()
});

module.exports = {
  interopResourceParamsSchema,
  interopStudyIdParamsSchema,
  fhirImportSchema,
  hl7MessagesSchema,
  dicomStudyLinkSchema,
  interopMigrationImportSchema
};
