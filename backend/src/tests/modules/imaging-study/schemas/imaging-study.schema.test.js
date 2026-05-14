/**
 * Imaging study schema validation tests
 * 
 * Per testing.mdc: Test all validation paths including:
 * - Valid data passes
 * - Invalid data fails with correct errors
 * - Required fields
 * - Optional fields
 * - Field types and formats
 * - Edge cases
 */

const {
  createImagingStudySchema,
  updateImagingStudySchema,
  imagingStudyIdParamsSchema,
  listImagingStudiesQuerySchema
} = require('@validations/imaging-study/imaging-study.schema');

describe('Imaging Study Schema Validation', () => {
  // ==================== createImagingStudySchema ====================
  describe('createImagingStudySchema', () => {
    describe('Valid data', () => {
      it('should accept valid complete imaging study data', () => {
        const validData = {
          radiology_order_id: '123e4567-e89b-12d3-a456-426614174000',
          modality: 'XRAY',
          performed_at: '2024-01-15T10:30:00.000Z'
        };

        const result = createImagingStudySchema.safeParse(validData);
        expect(result.success).toBe(true);
        if (result.success) {
          expect(result.data).toEqual(validData);
        }
      });

      it('should accept valid data without optional performed_at', () => {
        const validData = {
          radiology_order_id: '123e4567-e89b-12d3-a456-426614174000',
          modality: 'CT'
        };

        const result = createImagingStudySchema.safeParse(validData);
        expect(result.success).toBe(true);
      });

      it('should accept all valid modality values', () => {
        const modalities = ['XRAY', 'CT', 'MRI', 'ULTRASOUND', 'PET', 'OTHER'];
        
        modalities.forEach(modality => {
          const validData = {
            radiology_order_id: '123e4567-e89b-12d3-a456-426614174000',
            modality
          };

          const result = createImagingStudySchema.safeParse(validData);
          expect(result.success).toBe(true);
        });
      });

      it('should accept null for performed_at', () => {
        const validData = {
          radiology_order_id: '123e4567-e89b-12d3-a456-426614174000',
          modality: 'MRI',
          performed_at: null
        };

        const result = createImagingStudySchema.safeParse(validData);
        expect(result.success).toBe(true);
      });
    });

    describe('Invalid radiology_order_id', () => {
      it('should reject missing radiology_order_id', () => {
        const invalidData = {
          modality: 'XRAY'
        };

        const result = createImagingStudySchema.safeParse(invalidData);
        expect(result.success).toBe(false);
        if (!result.success) {
          expect(result.error.issues).toEqual(
            expect.arrayContaining([
              expect.objectContaining({
                path: ['radiology_order_id']
              })
            ])
          );
        }
      });

      it('should reject invalid UUID format', () => {
        const invalidData = {
          radiology_order_id: 'not-a-uuid',
          modality: 'CT'
        };

        const result = createImagingStudySchema.safeParse(invalidData);
        expect(result.success).toBe(false);
        if (!result.success) {
          expect(result.error.issues).toEqual(
            expect.arrayContaining([
              expect.objectContaining({
                path: ['radiology_order_id'],
                message: expect.stringContaining('UUID')
              })
            ])
          );
        }
      });
    });

    describe('Invalid modality', () => {
      it('should reject missing modality', () => {
        const invalidData = {
          radiology_order_id: '123e4567-e89b-12d3-a456-426614174000'
        };

        const result = createImagingStudySchema.safeParse(invalidData);
        expect(result.success).toBe(false);
        if (!result.success) {
          expect(result.error.issues).toEqual(
            expect.arrayContaining([
              expect.objectContaining({
                path: ['modality']
              })
            ])
          );
        }
      });

      it('should reject invalid modality value', () => {
        const invalidData = {
          radiology_order_id: '123e4567-e89b-12d3-a456-426614174000',
          modality: 'INVALID_MODALITY'
        };

        const result = createImagingStudySchema.safeParse(invalidData);
        expect(result.success).toBe(false);
      });
    });

    describe('Invalid performed_at', () => {
      it('should reject invalid date format', () => {
        const invalidData = {
          radiology_order_id: '123e4567-e89b-12d3-a456-426614174000',
          modality: 'XRAY',
          performed_at: '2024-01-15'
        };

        const result = createImagingStudySchema.safeParse(invalidData);
        expect(result.success).toBe(false);
      });

      it('should reject non-date string', () => {
        const invalidData = {
          radiology_order_id: '123e4567-e89b-12d3-a456-426614174000',
          modality: 'MRI',
          performed_at: 'not-a-date'
        };

        const result = createImagingStudySchema.safeParse(invalidData);
        expect(result.success).toBe(false);
      });
    });

    describe('Extra fields', () => {
      it('should strip extra fields not in schema', () => {
        const dataWithExtra = {
          radiology_order_id: '123e4567-e89b-12d3-a456-426614174000',
          modality: 'CT',
          extra_field: 'should be removed'
        };

        const result = createImagingStudySchema.safeParse(dataWithExtra);
        expect(result.success).toBe(true);
        if (result.success) {
          expect(result.data).not.toHaveProperty('extra_field');
        }
      });
    });
  });

  // ==================== updateImagingStudySchema ====================
  describe('updateImagingStudySchema', () => {
    describe('Valid data', () => {
      it('should accept modality update', () => {
        const validData = {
          modality: 'ULTRASOUND'
        };

        const result = updateImagingStudySchema.safeParse(validData);
        expect(result.success).toBe(true);
      });

      it('should accept performed_at update', () => {
        const validData = {
          performed_at: '2024-01-20T14:30:00.000Z'
        };

        const result = updateImagingStudySchema.safeParse(validData);
        expect(result.success).toBe(true);
      });

      it('should accept all fields update', () => {
        const validData = {
          modality: 'PET',
          performed_at: '2024-01-20T14:30:00.000Z'
        };

        const result = updateImagingStudySchema.safeParse(validData);
        expect(result.success).toBe(true);
      });

      it('should accept empty object for partial update', () => {
        const validData = {};

        const result = updateImagingStudySchema.safeParse(validData);
        expect(result.success).toBe(true);
      });

      it('should accept null for performed_at', () => {
        const validData = {
          performed_at: null
        };

        const result = updateImagingStudySchema.safeParse(validData);
        expect(result.success).toBe(true);
      });
    });

    describe('Invalid data', () => {
      it('should reject invalid modality', () => {
        const invalidData = {
          modality: 'INVALID'
        };

        const result = updateImagingStudySchema.safeParse(invalidData);
        expect(result.success).toBe(false);
      });

      it('should reject invalid performed_at format', () => {
        const invalidData = {
          performed_at: 'invalid-date'
        };

        const result = updateImagingStudySchema.safeParse(invalidData);
        expect(result.success).toBe(false);
      });
    });
  });

  // ==================== imagingStudyIdParamsSchema ====================
  describe('imagingStudyIdParamsSchema', () => {
    describe('Valid data', () => {
      it('should accept valid UUID', () => {
        const validParams = {
          id: '123e4567-e89b-12d3-a456-426614174000'
        };

        const result = imagingStudyIdParamsSchema.safeParse(validParams);
        expect(result.success).toBe(true);
      });
    });

    describe('Invalid data', () => {
      it('should reject missing id', () => {
        const invalidParams = {};

        const result = imagingStudyIdParamsSchema.safeParse(invalidParams);
        expect(result.success).toBe(false);
      });

      it('should reject invalid UUID format', () => {
        const invalidParams = {
          id: 'not-a-uuid'
        };

        const result = imagingStudyIdParamsSchema.safeParse(invalidParams);
        expect(result.success).toBe(false);
      });

      it('should reject numeric id', () => {
        const invalidParams = {
          id: '12345'
        };

        const result = imagingStudyIdParamsSchema.safeParse(invalidParams);
        expect(result.success).toBe(false);
      });
    });
  });

  // ==================== listImagingStudiesQuerySchema ====================
  describe('listImagingStudiesQuerySchema', () => {
    describe('Valid data', () => {
      it('should accept empty query', () => {
        const validQuery = {};

        const result = listImagingStudiesQuerySchema.safeParse(validQuery);
        expect(result.success).toBe(true);
      });

      it('should accept pagination parameters', () => {
        const validQuery = {
          page: '2',
          limit: '50'
        };

        const result = listImagingStudiesQuerySchema.safeParse(validQuery);
        expect(result.success).toBe(true);
        if (result.success) {
          expect(result.data.page).toBe(2);
          expect(result.data.limit).toBe(50);
        }
      });

      it('should accept sort parameters', () => {
        const validQuery = {
          sort_by: 'performed_at',
          order: 'desc'
        };

        const result = listImagingStudiesQuerySchema.safeParse(validQuery);
        expect(result.success).toBe(true);
      });

      it('should accept radiology_order_id filter', () => {
        const validQuery = {
          radiology_order_id: '123e4567-e89b-12d3-a456-426614174000'
        };

        const result = listImagingStudiesQuerySchema.safeParse(validQuery);
        expect(result.success).toBe(true);
      });

      it('should accept modality filter', () => {
        const validQuery = {
          modality: 'XRAY'
        };

        const result = listImagingStudiesQuerySchema.safeParse(validQuery);
        expect(result.success).toBe(true);
      });

      it('should accept performed_at filter', () => {
        const validQuery = {
          performed_at: '2024-01-15T10:30:00.000Z'
        };

        const result = listImagingStudiesQuerySchema.safeParse(validQuery);
        expect(result.success).toBe(true);
      });

      it('should accept all parameters together', () => {
        const validQuery = {
          page: '1',
          limit: '20',
          sort_by: 'modality',
          order: 'asc',
          radiology_order_id: '123e4567-e89b-12d3-a456-426614174000',
          modality: 'CT',
          performed_at: '2024-01-15T10:30:00.000Z'
        };

        const result = listImagingStudiesQuerySchema.safeParse(validQuery);
        expect(result.success).toBe(true);
      });

      it('should apply default values for page and limit', () => {
        const validQuery = {};

        const result = listImagingStudiesQuerySchema.safeParse(validQuery);
        expect(result.success).toBe(true);
        if (result.success) {
          expect(result.data.page).toBeDefined();
          expect(result.data.limit).toBeDefined();
        }
      });
    });

    describe('Invalid data', () => {
      it('should reject invalid page value', () => {
        const invalidQuery = {
          page: '-1'
        };

        const result = listImagingStudiesQuerySchema.safeParse(invalidQuery);
        expect(result.success).toBe(false);
      });

      it('should reject invalid limit value exceeding max', () => {
        const invalidQuery = {
          limit: '1000'
        };

        const result = listImagingStudiesQuerySchema.safeParse(invalidQuery);
        expect(result.success).toBe(false);
      });

      it('should reject invalid order value', () => {
        const invalidQuery = {
          order: 'invalid'
        };

        const result = listImagingStudiesQuerySchema.safeParse(invalidQuery);
        expect(result.success).toBe(false);
      });

      it('should reject invalid radiology_order_id', () => {
        const invalidQuery = {
          radiology_order_id: 'not-a-uuid'
        };

        const result = listImagingStudiesQuerySchema.safeParse(invalidQuery);
        expect(result.success).toBe(false);
      });

      it('should reject invalid modality', () => {
        const invalidQuery = {
          modality: 'INVALID_MODALITY'
        };

        const result = listImagingStudiesQuerySchema.safeParse(invalidQuery);
        expect(result.success).toBe(false);
      });

      it('should reject invalid performed_at format', () => {
        const invalidQuery = {
          performed_at: 'not-a-date'
        };

        const result = listImagingStudiesQuerySchema.safeParse(invalidQuery);
        expect(result.success).toBe(false);
      });
    });
  });
});
