/**
 * Patient Document schema tests
 *
 * @module tests/modules/patient-document/schemas
 * @description Tests for patient document validation schemas
 * Per testing.mdc: Comprehensive validation schema tests required
 */

const {
  createPatientDocumentSchema,
  updatePatientDocumentSchema,
  patientDocumentIdParamsSchema,
  listPatientDocumentsQuerySchema
} = require('@validations/patient-document/patient-document.schema');

describe('Patient Document Schemas', () => {
  describe('createPatientDocumentSchema', () => {
    const validData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      patient_id: '550e8400-e29b-41d4-a716-446655440001',
      document_type: 'Lab Report',
      storage_key: 'documents/patient-001/lab-report-2024.pdf',
      file_name: 'lab-report-2024.pdf',
      content_type: 'application/pdf'
    };

    it('should validate correct patient document data', () => {
      const result = createPatientDocumentSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should require tenant_id', () => {
      const data = { ...validData };
      delete data.tenant_id;
      const result = createPatientDocumentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require patient_id', () => {
      const data = { ...validData };
      delete data.patient_id;
      const result = createPatientDocumentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require document_type', () => {
      const data = { ...validData };
      delete data.document_type;
      const result = createPatientDocumentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should require storage_key', () => {
      const data = { ...validData };
      delete data.storage_key;
      const result = createPatientDocumentSchema.safeParse(data);
      expect(result.success).toBe(false);
    });

    it('should allow optional file_name', () => {
      const data = { ...validData };
      delete data.file_name;
      const result = createPatientDocumentSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow optional content_type', () => {
      const data = { ...validData };
      delete data.content_type;
      const result = createPatientDocumentSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('updatePatientDocumentSchema', () => {
    it('should validate update with all fields', () => {
      const data = {
        document_type: 'Updated Document Type',
        storage_key: 'updated/storage/key.pdf',
        file_name: 'updated-file.pdf',
        content_type: 'application/pdf'
      };
      const result = updatePatientDocumentSchema.safeParse(data);
      expect(result.success).toBe(true);
    });

    it('should allow partial updates', () => {
      const data = { document_type: 'Updated Document Type' };
      const result = updatePatientDocumentSchema.safeParse(data);
      expect(result.success).toBe(true);
    });
  });

  describe('patientDocumentIdParamsSchema', () => {
    it('should validate valid UUID', () => {
      const params = { id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = patientDocumentIdParamsSchema.safeParse(params);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID', () => {
      const params = { id: 'invalid-uuid' };
      const result = patientDocumentIdParamsSchema.safeParse(params);
      expect(result.success).toBe(false);
    });

    it('should require id', () => {
      const params = {};
      const result = patientDocumentIdParamsSchema.safeParse(params);
      expect(result.success).toBe(false);
    });
  });

  describe('listPatientDocumentsQuerySchema', () => {
    it('should validate empty query', () => {
      const query = {};
      const result = listPatientDocumentsQuerySchema.safeParse(query);
      expect(result.success).toBe(true);
    });

    it('should validate with all filters', () => {
      const query = {
        page: 1,
        limit: 20,
        sort_by: 'created_at',
        order: 'desc',
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        patient_id: '550e8400-e29b-41d4-a716-446655440001',
        document_type: 'Lab Report',
        search: 'test'
      };
      const result = listPatientDocumentsQuerySchema.safeParse(query);
      expect(result.success).toBe(true);
    });
  });
});
