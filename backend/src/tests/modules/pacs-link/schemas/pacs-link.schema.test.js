/**
 * PACS link schema validation tests
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
  createPacsLinkSchema,
  updatePacsLinkSchema,
  pacsLinkIdParamsSchema,
  listPacsLinksQuerySchema
} = require('@validations/pacs-link/pacs-link.schema');

describe('PACS Link Schema Validation', () => {
  // ==================== createPacsLinkSchema ====================
  describe('createPacsLinkSchema', () => {
    describe('Valid data', () => {
      it('should accept valid complete PACS link data', () => {
        const validData = {
          imaging_study_id: '123e4567-e89b-12d3-a456-426614174000',
          url: 'https://pacs.example.com/studies/12345',
          expires_at: '2024-12-31T23:59:59.000Z'
        };

        const result = createPacsLinkSchema.safeParse(validData);
        expect(result.success).toBe(true);
        if (result.success) {
          expect(result.data).toEqual(validData);
        }
      });

      it('should accept valid data without optional expires_at', () => {
        const validData = {
          imaging_study_id: '123e4567-e89b-12d3-a456-426614174000',
          url: 'https://pacs.example.com/studies/67890'
        };

        const result = createPacsLinkSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });

      it('should accept null for expires_at', () => {
        const validData = {
          imaging_study_id: '123e4567-e89b-12d3-a456-426614174000',
          url: 'https://pacs.example.com/viewer',
          expires_at: null
        };

        const result = createPacsLinkSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });

      it('should accept various valid URL formats', () => {
        const urls = [
          'https://pacs.example.com/study/123',
          'http://localhost:8080/viewer',
          'https://pacs-server.hospital.org/dicom/view?id=xyz',
          'https://10.0.0.1:9000/pacs'
        ];

        urls.forEach(url => {
          const validData = {
            imaging_study_id: '123e4567-e89b-12d3-a456-426614174000',
            url
          };

          const result = createPacsLinkSchema.safeParse(validData);
          expect(result.success).toBe(true);
        });
      });

      it('should trim URL whitespace', () => {
        const validData = {
          imaging_study_id: '123e4567-e89b-12d3-a456-426614174000',
          url: '  https://pacs.example.com/study  '
        };

        const result = createPacsLinkSchema.safeParse(validData);
        expect(result.success).toBe(true);
        if (result.success) {
          expect(result.data.url).toBe('https://pacs.example.com/study');
        }
      });
    });

    describe('Invalid imaging_study_id', () => {
      it('should reject missing imaging_study_id', () => {
        const invalidData = {
          url: 'https://pacs.example.com/study'
        };

        const result = createPacsLinkSchema.safeParse(invalidData);
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
          url: 'https://pacs.example.com/study'
        };

        const result = createPacsLinkSchema.safeParse(invalidData);
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

    describe('Invalid url', () => {
      it('should reject missing url', () => {
        const invalidData = {
          imaging_study_id: '123e4567-e89b-12d3-a456-426614174000'
        };

        const result = createPacsLinkSchema.safeParse(invalidData);
        expect(result.success).toBe(false);
        if (!result.success) {
          expect(result.error.issues).toEqual(
            expect.arrayContaining([
              expect.objectContaining({
                path: ['url']
              })
            ])
          );
        }
      });

      it('should reject invalid URL format', () => {
        const invalidUrls = [
          'not-a-url',
          'just-text',
          '//missing-protocol.com'
        ];

        invalidUrls.forEach(url => {
          const invalidData = {
            imaging_study_id: '123e4567-e89b-12d3-a456-426614174000',
            url
          };

          const result = createPacsLinkSchema.safeParse(invalidData);
          expect(result.success).toBe(false);
        });
      });
    });

    describe('Invalid expires_at', () => {
      it('should reject invalid date format', () => {
        const invalidData = {
          imaging_study_id: '123e4567-e89b-12d3-a456-426614174000',
          url: 'https://pacs.example.com/study',
          expires_at: '2024-01-15'
        };

        const result = createPacsLinkSchema.safeParse(invalidData);
        expect(result.success).toBe(false);
      });

      it('should reject non-date string', () => {
        const invalidData = {
          imaging_study_id: '123e4567-e89b-12d3-a456-426614174000',
          url: 'https://pacs.example.com/study',
          expires_at: 'not-a-date'
        };

        const result = createPacsLinkSchema.safeParse(invalidData);
        expect(result.success).toBe(false);
      });
    });

    describe('Extra fields', () => {
      it('should strip extra fields not in schema', () => {
        const dataWithExtra = {
          imaging_study_id: '123e4567-e89b-12d3-a456-426614174000',
          url: 'https://pacs.example.com/study',
          extra_field: 'should be removed'
        };

        const result = createPacsLinkSchema.safeParse(dataWithExtra);
        expect(result.success).toBe(true);
        if (result.success) {
          expect(result.data).not.toHaveProperty('extra_field');
        }
      });
    });
  });

  // ==================== updatePacsLinkSchema ====================
  describe('updatePacsLinkSchema', () => {
    describe('Valid data', () => {
      it('should accept url update', () => {
        const validData = {
          url: 'https://new-pacs.example.com/study'
        };

        const result = updatePacsLinkSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });

      it('should accept expires_at update', () => {
        const validData = {
          expires_at: '2024-12-31T23:59:59.000Z'
        };

        const result = updatePacsLinkSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });

      it('should accept all fields update', () => {
        const validData = {
          url: 'https://updated-pacs.example.com/viewer',
          expires_at: '2025-01-31T23:59:59.000Z'
        };

        const result = updatePacsLinkSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });

      it('should accept empty object for partial update', () => {
        const validData = {};

        const result = updatePacsLinkSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });

      it('should accept null for expires_at', () => {
        const validData = {
          expires_at: null
        };

        const result = updatePacsLinkSchema.safeParse(validData);
        expect(result.success).toBe(true);
      });
    });

    describe('Invalid data', () => {
      it('should reject invalid url', () => {
        const invalidData = {
          url: 'not-a-valid-url'
        };

        const result = updatePacsLinkSchema.safeParse(invalidData);
        expect(result.success).toBe(false);
      });

      it('should reject invalid expires_at format', () => {
        const invalidData = {
          expires_at: 'invalid-date'
        };

        const result = updatePacsLinkSchema.safeParse(invalidData);
        expect(result.success).toBe(false);
      });
    });
  });

  // ==================== pacsLinkIdParamsSchema ====================
  describe('pacsLinkIdParamsSchema', () => {
    describe('Valid data', () => {
      it('should accept valid UUID', () => {
        const validParams = {
          id: '123e4567-e89b-12d3-a456-426614174000'
        };

        const result = pacsLinkIdParamsSchema.safeParse(validParams);
        expect(result.success).toBe(true);
      });
    });

    describe('Invalid data', () => {
      it('should reject missing id', () => {
        const invalidParams = {};

        const result = pacsLinkIdParamsSchema.safeParse(invalidParams);
        expect(result.success).toBe(false);
      });

      it('should reject invalid UUID format', () => {
        const invalidParams = {
          id: 'not-a-uuid'
        };

        const result = pacsLinkIdParamsSchema.safeParse(invalidParams);
        expect(result.success).toBe(false);
      });
    });
  });

  // ==================== listPacsLinksQuerySchema ====================
  describe('listPacsLinksQuerySchema', () => {
    describe('Valid data', () => {
      it('should accept empty query', () => {
        const validQuery = {};

        const result = listPacsLinksQuerySchema.safeParse(validQuery);
        expect(result.success).toBe(true);
      });

      it('should accept pagination parameters', () => {
        const validQuery = {
          page: '2',
          limit: '50'
        };

        const result = listPacsLinksQuerySchema.safeParse(validQuery);
        expect(result.success).toBe(true);
        if (result.success) {
          expect(result.data.page).toBe(2);
          expect(result.data.limit).toBe(50);
        }
      });

      it('should accept sort parameters', () => {
        const validQuery = {
          sort_by: 'expires_at',
          order: 'desc'
        };

        const result = listPacsLinksQuerySchema.safeParse(validQuery);
        expect(result.success).toBe(true);
      });

      it('should accept imaging_study_id filter', () => {
        const validQuery = {
          imaging_study_id: '123e4567-e89b-12d3-a456-426614174000'
        };

        const result = listPacsLinksQuerySchema.safeParse(validQuery);
        expect(result.success).toBe(true);
      });

      it('should accept expires_at filter', () => {
        const validQuery = {
          expires_at: '2024-12-31T23:59:59.000Z'
        };

        const result = listPacsLinksQuerySchema.safeParse(validQuery);
        expect(result.success).toBe(true);
      });

      it('should accept all parameters together', () => {
        const validQuery = {
          page: '1',
          limit: '20',
          sort_by: 'created_at',
          order: 'asc',
          imaging_study_id: '123e4567-e89b-12d3-a456-426614174000',
          expires_at: '2024-12-31T23:59:59.000Z'
        };

        const result = listPacsLinksQuerySchema.safeParse(validQuery);
        expect(result.success).toBe(true);
      });
    });

    describe('Invalid data', () => {
      it('should reject invalid page value', () => {
        const invalidQuery = {
          page: '-1'
        };

        const result = listPacsLinksQuerySchema.safeParse(invalidQuery);
        expect(result.success).toBe(false);
      });

      it('should reject invalid limit value exceeding max', () => {
        const invalidQuery = {
          limit: '1000'
        };

        const result = listPacsLinksQuerySchema.safeParse(invalidQuery);
        expect(result.success).toBe(false);
      });

      it('should reject invalid order value', () => {
        const invalidQuery = {
          order: 'invalid'
        };

        const result = listPacsLinksQuerySchema.safeParse(invalidQuery);
        expect(result.success).toBe(false);
      });

      it('should reject invalid imaging_study_id', () => {
        const invalidQuery = {
          imaging_study_id: 'not-a-uuid'
        };

        const result = listPacsLinksQuerySchema.safeParse(invalidQuery);
        expect(result.success).toBe(false);
      });

      it('should reject invalid expires_at format', () => {
        const invalidQuery = {
          expires_at: 'not-a-date'
        };

        const result = listPacsLinksQuerySchema.safeParse(invalidQuery);
        expect(result.success).toBe(false);
      });
    });
  });
});
