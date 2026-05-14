/**
 * Imaging asset schema validation tests
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
  createImagingAssetSchema,
  updateImagingAssetSchema,
  imagingAssetIdParamsSchema,
  listImagingAssetsQuerySchema
} = require('@validations/imaging-asset/imaging-asset.schema');

describe('Imaging Asset Schema Validation', () => {
  // ==================== createImagingAssetSchema ====================
  describe('createImagingAssetSchema', () => {
    describe('Valid data', () => {
      it('should accept valid complete imaging asset data', () => {
        const validData = {
          imaging_study_id: '123e4567-e89b-12d3-a456-426614174000',
          storage_key: 'imaging/2024/01/15/xray-12345.dcm',
          file_name: 'chest-xray-frontal.dcm',
          content_type: 'application/dicom'
        };

        const result = createImagingAssetSchema.safeParse(validData);
        expect(result.success).toBe(true);
        if (result.success) {
          expect(result.data).toEqual(validData);
        }
      });

      it('should accept valid data without optional fields', () => {
        const validData = {
          imaging_study_id: '123e4567-e89b-12d3-a456-426614174000',
          storage_key: 'imaging/xray.dcm'
        };

        const result = createImagingAssetSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });

      it('should accept null for optional fields', () => {
        const validData = {
          imaging_study_id: '123e4567-e89b-12d3-a456-426614174000',
          storage_key: 'imaging/study.dcm',
          file_name: null,
          content_type: null
        };

        const result = createImagingAssetSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });

      it('should trim whitespace from string fields', () => {
        const validData = {
          imaging_study_id: '123e4567-e89b-12d3-a456-426614174000',
          storage_key: '  imaging/xray.dcm  ',
          file_name: '  chest-xray.dcm  ',
          content_type: '  application/dicom  '
        };

        const result = createImagingAssetSchema.safeParse(validData);
        expect(result.success).toBe(true);
        if (result.success) {
          expect(result.data.storage_key).toBe('imaging/xray.dcm');
          expect(result.data.file_name).toBe('chest-xray.dcm');
          expect(result.data.content_type).toBe('application/dicom');
        }
      });

      it('should accept maximum length strings', () => {
        const validData = {
          imaging_study_id: '123e4567-e89b-12d3-a456-426614174000',
          storage_key: 'a'.repeat(255),
          file_name: 'b'.repeat(255),
          content_type: 'c'.repeat(120)
        };

        const result = createImagingAssetSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });
    });

    describe('Invalid imaging_study_id', () => {
      it('should reject missing imaging_study_id', () => {
        const invalidData = {
          storage_key: 'imaging/xray.dcm'
        };

        const result = createImagingAssetSchema.safeParse(invalidData);
        expect(result.success).toBe(false);
        if (!result.success) {
          expect(result.error.issues).toEqual(
            expect.arrayContaining([
              expect.objectContaining({
                path: ['imaging_study_id']
              })
            ])
          );
        }
      });

      it('should reject invalid UUID format', () => {
        const invalidData = {
          imaging_study_id: 'not-a-uuid',
          storage_key: 'imaging/xray.dcm'
        };

        const result = createImagingAssetSchema.safeParse(invalidData);
        expect(result.success).toBe(false);
        if (!result.success) {
          expect(result.error.issues).toEqual(
            expect.arrayContaining([
              expect.objectContaining({
                path: ['imaging_study_id'],
                message: expect.stringContaining('UUID')
              })
            ])
          );
        }
      });
    });

    describe('Invalid storage_key', () => {
      it('should reject missing storage_key', () => {
        const invalidData = {
          imaging_study_id: '123e4567-e89b-12d3-a456-426614174000'
        };

        const result = createImagingAssetSchema.safeParse(invalidData);
        expect(result.success).toBe(false);
        if (!result.success) {
          expect(result.error.issues).toEqual(
            expect.arrayContaining([
              expect.objectContaining({
                path: ['storage_key']
              })
            ])
          );
        }
      });

      it('should reject empty storage_key', () => {
        const invalidData = {
          imaging_study_id: '123e4567-e89b-12d3-a456-426614174000',
          storage_key: ''
        };

        const result = createImagingAssetSchema.safeParse(invalidData);
        expect(result.success).toBe(false);
      });

      it('should reject storage_key exceeding max length', () => {
        const invalidData = {
          imaging_study_id: '123e4567-e89b-12d3-a456-426614174000',
          storage_key: 'a'.repeat(256)
        };

        const result = createImagingAssetSchema.safeParse(invalidData);
        expect(result.success).toBe(false);
      });
    });

    describe('Invalid file_name', () => {
      it('should reject file_name exceeding max length', () => {
        const invalidData = {
          imaging_study_id: '123e4567-e89b-12d3-a456-426614174000',
          storage_key: 'imaging/xray.dcm',
          file_name: 'a'.repeat(256)
        };

        const result = createImagingAssetSchema.safeParse(invalidData);
        expect(result.success).toBe(false);
      });
    });

    describe('Invalid content_type', () => {
      it('should reject content_type exceeding max length', () => {
        const invalidData = {
          imaging_study_id: '123e4567-e89b-12d3-a456-426614174000',
          storage_key: 'imaging/xray.dcm',
          content_type: 'a'.repeat(121)
        };

        const result = createImagingAssetSchema.safeParse(invalidData);
        expect(result.success).toBe(false);
      });
    });

    describe('Extra fields', () => {
      it('should strip extra fields not in schema', () => {
        const dataWithExtra = {
          imaging_study_id: '123e4567-e89b-12d3-a456-426614174000',
          storage_key: 'imaging/xray.dcm',
          extra_field: 'should be removed'
        };

        const result = createImagingAssetSchema.safeParse(dataWithExtra);
        expect(result.success).toBe(true);
        if (result.success) {
          expect(result.data).not.toHaveProperty('extra_field');
        }
      });
    });
  });

  // ==================== updateImagingAssetSchema ====================
  describe('updateImagingAssetSchema', () => {
    describe('Valid data', () => {
      it('should accept file_name update', () => {
        const validData = {
          file_name: 'updated-filename.dcm'
        };

        const result = updateImagingAssetSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });

      it('should accept content_type update', () => {
        const validData = {
          content_type: 'image/jpeg'
        };

        const result = updateImagingAssetSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });

      it('should accept all fields update', () => {
        const validData = {
          file_name: 'new-file.dcm',
          content_type: 'application/dicom'
        };

        const result = updateImagingAssetSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });

      it('should accept empty object for partial update', () => {
        const validData = {};

        const result = updateImagingAssetSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });

      it('should accept null values', () => {
        const validData = {
          file_name: null,
          content_type: null
        };

        const result = updateImagingAssetSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });
    });

    describe('Invalid data', () => {
      it('should reject file_name exceeding max length', () => {
        const invalidData = {
          file_name: 'a'.repeat(256)
        };

        const result = updateImagingAssetSchema.safeParse(invalidData);
        expect(result.success).toBe(false);
      });

      it('should reject content_type exceeding max length', () => {
        const invalidData = {
          content_type: 'a'.repeat(121)
        };

        const result = updateImagingAssetSchema.safeParse(invalidData);
        expect(result.success).toBe(false);
      });
    });
  });

  // ==================== imagingAssetIdParamsSchema ====================
  describe('imagingAssetIdParamsSchema', () => {
    describe('Valid data', () => {
      it('should accept valid UUID', () => {
        const validParams = {
          id: '123e4567-e89b-12d3-a456-426614174000'
        };

        const result = imagingAssetIdParamsSchema.safeParse(validParams);
        expect(result.success).toBe(true);
      });
    });

    describe('Invalid data', () => {
      it('should reject missing id', () => {
        const invalidParams = {};

        const result = imagingAssetIdParamsSchema.safeParse(invalidParams);
        expect(result.success).toBe(false);
      });

      it('should reject invalid UUID format', () => {
        const invalidParams = {
          id: 'not-a-uuid'
        };

        const result = imagingAssetIdParamsSchema.safeParse(invalidParams);
        expect(result.success).toBe(false);
      });
    });
  });

  // ==================== listImagingAssetsQuerySchema ====================
  describe('listImagingAssetsQuerySchema', () => {
    describe('Valid data', () => {
      it('should accept empty query', () => {
        const validQuery = {};

        const result = listImagingAssetsQuerySchema.safeParse(validQuery);
        expect(result.success).toBe(true);
      });

      it('should accept pagination parameters', () => {
        const validQuery = {
          page: '2',
          limit: '50'
        };

        const result = listImagingAssetsQuerySchema.safeParse(validQuery);
        expect(result.success).toBe(true);
        if (result.success) {
          expect(result.data.page).toBe(2);
          expect(result.data.limit).toBe(50);
        }
      });

      it('should accept sort parameters', () => {
        const validQuery = {
          sort_by: 'file_name',
          order: 'desc'
        };

        const result = listImagingAssetsQuerySchema.safeParse(validQuery);
        expect(result.success).toBe(true);
      });

      it('should accept imaging_study_id filter', () => {
        const validQuery = {
          imaging_study_id: '123e4567-e89b-12d3-a456-426614174000'
        };

        const result = listImagingAssetsQuerySchema.safeParse(validQuery);
        expect(result.success).toBe(true);
      });

      it('should accept content_type filter', () => {
        const validQuery = {
          content_type: 'application/dicom'
        };

        const result = listImagingAssetsQuerySchema.safeParse(validQuery);
        expect(result.success).toBe(true);
      });

      it('should accept all parameters together', () => {
        const validQuery = {
          page: '1',
          limit: '20',
          sort_by: 'created_at',
          order: 'asc',
          imaging_study_id: '123e4567-e89b-12d3-a456-426614174000',
          content_type: 'image/jpeg'
        };

        const result = listImagingAssetsQuerySchema.safeParse(validQuery);
        expect(result.success).toBe(true);
      });
    });

    describe('Invalid data', () => {
      it('should reject invalid page value', () => {
        const invalidQuery = {
          page: '-1'
        };

        const result = listImagingAssetsQuerySchema.safeParse(invalidQuery);
        expect(result.success).toBe(false);
      });

      it('should reject invalid imaging_study_id', () => {
        const invalidQuery = {
          imaging_study_id: 'not-a-uuid'
        };

        const result = listImagingAssetsQuerySchema.safeParse(invalidQuery);
        expect(result.success).toBe(false);
      });
    });
  });
});
