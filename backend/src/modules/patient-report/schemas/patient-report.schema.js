const { z } = require('zod');
const { uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');
const {
  PATIENT_REPORT_SECTIONS,
  REPORT_ACTIONS,
  REPORT_TYPES,
} = require('@lib/patient-reports/sections');

const sectionIdSchema = z.enum(
  PATIENT_REPORT_SECTIONS.map((section) => section.id)
);

const periodSchema = z
  .object({
    mode: z.enum(['all_dates', 'single_date', 'date_range']).optional(),
    single_date: z.string().datetime().optional().nullable(),
    start_date: z.string().datetime().optional().nullable(),
    end_date: z.string().datetime().optional().nullable(),
  })
  .strict()
  .optional()
  .nullable();

const listSectionsQuerySchema = z
  .object({
    patient_id: uuidOrFriendlyIdentifierSchema,
    encounter_id: uuidOrFriendlyIdentifierSchema.optional(),
    period_mode: z.enum(['all_dates', 'single_date', 'date_range']).optional(),
    single_date: z.string().datetime().optional(),
    start_date: z.string().datetime().optional(),
    end_date: z.string().datetime().optional(),
  })
  .strict();

const createPatientReportJobSchema = z
  .object({
    patient_id: uuidOrFriendlyIdentifierSchema,
    encounter_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
    report_type: z
      .enum(Object.values(REPORT_TYPES))
      .optional(),
    action: z
      .enum([
        REPORT_ACTIONS.GENERATE,
        REPORT_ACTIONS.EXPORT,
        REPORT_ACTIONS.PRINT,
        REPORT_ACTIONS.PREVIEW,
      ])
      .optional(),
    format: z.enum(['PDF', 'CSV', 'JSON', 'XLSX']).optional(),
    sections: z.array(sectionIdSchema).min(1).max(40),
    period: periodSchema,
    async: z.boolean().optional(),
  })
  .strict();

const patientReportJobIdParamsSchema = z
  .object({
    id: uuidOrFriendlyIdentifierSchema,
  })
  .strict();

const recordPrintEventSchema = z
  .object({
    patient_id: uuidOrFriendlyIdentifierSchema,
    encounter_id: uuidOrFriendlyIdentifierSchema.optional().nullable(),
    report_type: z.enum(Object.values(REPORT_TYPES)).optional(),
    action: z
      .enum([
        REPORT_ACTIONS.PRINT,
        REPORT_ACTIONS.EXPORT,
        REPORT_ACTIONS.PREVIEW,
        REPORT_ACTIONS.ACCESS,
      ])
      .optional(),
    sections: z.array(z.string().min(1).max(80)).max(40).optional().default([]),
  })
  .strict();

module.exports = {
  createPatientReportJobSchema,
  listSectionsQuerySchema,
  patientReportJobIdParamsSchema,
  recordPrintEventSchema,
};
