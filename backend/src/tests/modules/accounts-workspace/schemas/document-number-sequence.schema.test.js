const {
  DOCUMENT_SEQUENCE_STATUSES,
  DOCUMENT_SEQUENCE_ACTIONS,
  DOCUMENT_SEQUENCE_TYPES,
  DOCUMENT_SEQUENCE_RESET_FREQUENCIES,
  DOCUMENT_SEQUENCE_GAP_POLICIES,
  MAX_REFERENCE_LENGTH,
  documentSequencesQuerySchema,
  documentSequenceIdentifierParamsSchema,
  documentSequenceActionParamsSchema,
  createDocumentSequenceSchema,
  updateDocumentSequenceSchema,
  documentSequenceActionSchema,
} = require('@validations/accounts-workspace/document-number-sequence.schema');

const validCreate = {
  sequence_code: 'INV-MAIN',
  document_type: 'INVOICE',
  module: 'BILLING',
  prefix: 'INV',
  minimum_length: 7,
  reset_frequency: 'NEVER',
};

describe('document-number-sequence schemas', () => {
  it('exposes the documented status model and actions', () => {
    expect(DOCUMENT_SEQUENCE_STATUSES).toEqual([
      'DRAFT',
      'ACTIVE',
      'INACTIVE',
      'ARCHIVED',
    ]);
    expect(DOCUMENT_SEQUENCE_ACTIONS).toEqual([
      'activate',
      'deactivate',
      'archive',
      'restore',
    ]);
  });

  it('offers only document types that already reserve friendly ids', () => {
    // A sequence configured for a document the system does not number would
    // never issue anything; the taxonomy is closed on purpose.
    expect(DOCUMENT_SEQUENCE_TYPES).toEqual([
      'INVOICE',
      'ACCOUNTS_INVOICE',
      'RECEIPT',
      'PAYMENT',
      'REFUND',
      'CREDIT_NOTE',
      'DEBIT_NOTE',
      'PURCHASE_ORDER',
      'GOODS_RECEIPT',
      'CLAIM',
    ]);
  });

  it('exposes the documented reset frequencies and gap policies', () => {
    expect(DOCUMENT_SEQUENCE_RESET_FREQUENCIES).toEqual([
      'NEVER',
      'DAILY',
      'MONTHLY',
      'QUARTERLY',
      'YEARLY',
    ]);
    expect(DOCUMENT_SEQUENCE_GAP_POLICIES).toEqual([
      'ALLOW_GAPS',
      'NO_GAPS',
      'RESERVE_AND_VOID',
    ]);
  });

  describe('documentSequencesQuerySchema', () => {
    it('parses comma-separated status and document type multi-selects', () => {
      const parsed = documentSequencesQuerySchema.parse({
        status: 'ACTIVE, draft',
        document_type: 'invoice,CLAIM',
      });
      expect(parsed.status).toEqual(['ACTIVE', 'DRAFT']);
      expect(parsed.document_type).toEqual(['INVOICE', 'CLAIM']);
    });

    it('drops values outside the documented vocabularies', () => {
      const parsed = documentSequencesQuerySchema.parse({
        document_type: 'PRESCRIPTION',
        reset_frequency: 'HOURLY',
        gap_policy: 'IGNORE',
      });
      expect(parsed.document_type).toBeUndefined();
      expect(parsed.reset_frequency).toBeUndefined();
      expect(parsed.gap_policy).toBeUndefined();
    });

    it('accepts the documented date range filter', () => {
      const parsed = documentSequencesQuerySchema.parse({
        from: '2026-01-01',
        to: '2026-12-31',
      });
      expect(parsed.from).toBe('2026-01-01');
      expect(parsed.to).toBe('2026-12-31');
    });

    it('rejects an unparseable date boundary', () => {
      expect(() =>
        documentSequencesQuerySchema.parse({ from: 'last-tuesday' })
      ).toThrow();
    });
  });

  describe('identifier params', () => {
    it('accepts a public human-friendly reference', () => {
      expect(
        documentSequenceIdentifierParamsSchema.parse({
          documentSequenceIdentifier: 'DNS0000001',
        }).documentSequenceIdentifier
      ).toBe('DNS0000001');
    });

    it('rejects an action outside the documented workflow', () => {
      expect(() =>
        documentSequenceActionParamsSchema.parse({
          documentSequenceIdentifier: 'DNS0000001',
          action: 'delete',
        })
      ).toThrow();
    });

    it('accepts each documented action', () => {
      for (const action of DOCUMENT_SEQUENCE_ACTIONS) {
        expect(
          documentSequenceActionParamsSchema.parse({
            documentSequenceIdentifier: 'DNS0000001',
            action,
          }).action
        ).toBe(action);
      }
    });
  });

  describe('createDocumentSequenceSchema', () => {
    it('accepts a well-formed policy', () => {
      const parsed = createDocumentSequenceSchema.parse(validCreate);
      expect(parsed.sequence_code).toBe('INV-MAIN');
      expect(parsed.minimum_length).toBe(7);
    });

    it('coerces a numeric string minimum length', () => {
      const parsed = createDocumentSequenceSchema.parse({
        ...validCreate,
        minimum_length: '9',
      });
      expect(parsed.minimum_length).toBe(9);
    });

    it('requires a prefix so issued references stay identifiable', () => {
      expect(() =>
        createDocumentSequenceSchema.parse({ ...validCreate, prefix: '' })
      ).toThrow();
    });

    it('rejects an affix that would smuggle punctuation into a reference', () => {
      expect(() =>
        createDocumentSequenceSchema.parse({ ...validCreate, prefix: 'IN V!' })
      ).toThrow();
    });

    it('rejects a date pattern the formatter cannot understand', () => {
      expect(() =>
        createDocumentSequenceSchema.parse({
          ...validCreate,
          date_pattern: 'yyyy MMM (fy)',
        })
      ).toThrow();
    });

    it('accepts a literal calendar pattern', () => {
      const parsed = createDocumentSequenceSchema.parse({
        ...validCreate,
        date_pattern: 'yyyyMM',
      });
      expect(parsed.date_pattern).toBe('yyyyMM');
    });

    it('rejects a reference wider than the reference column', () => {
      expect(() =>
        createDocumentSequenceSchema.parse({
          ...validCreate,
          prefix: 'INVOICE',
          suffix: 'BRANCHONE',
          date_pattern: 'yyyyMMdd',
          minimum_length: 12,
        })
      ).toThrow();
    });

    it('accepts the widest reference that still fits the budget', () => {
      // `minimum_length` caps at 20 independently, so the widest legal padding
      // plus these affixes must stay inside the reference column.
      const parsed = createDocumentSequenceSchema.parse({
        ...validCreate,
        prefix: 'INV',
        suffix: 'A',
        date_pattern: 'yyyyMM',
        minimum_length: 20,
      });
      expect(parsed.minimum_length).toBe(20);
      expect(3 + 1 + 6 + parsed.minimum_length).toBeLessThanOrEqual(
        MAX_REFERENCE_LENGTH
      );
    });

    it('rejects a sequence code with separators that break lookups', () => {
      expect(() =>
        createDocumentSequenceSchema.parse({
          ...validCreate,
          sequence_code: 'INV MAIN/2026',
        })
      ).toThrow();
    });
  });

  describe('updateDocumentSequenceSchema', () => {
    it('allows a partial patch carrying the optimistic version', () => {
      const parsed = updateDocumentSequenceSchema.parse({
        module: 'GENERAL_LEDGER',
        version: 3,
      });
      expect(parsed.module).toBe('GENERAL_LEDGER');
      expect(parsed.version).toBe(3);
    });

    it('still enforces the reference budget on a partial patch', () => {
      expect(() =>
        updateDocumentSequenceSchema.parse({
          prefix: 'ACCOUNTSINVO',
          suffix: 'BRANCHONE',
          date_pattern: 'yyyyMMdd',
          minimum_length: 10,
        })
      ).toThrow();
    });
  });

  describe('documentSequenceActionSchema', () => {
    it('accepts an audit reason and an optimistic version', () => {
      const parsed = documentSequenceActionSchema.parse({
        reason: 'Go live for FY2026',
        version: 2,
      });
      expect(parsed.reason).toBe('Go live for FY2026');
      expect(parsed.version).toBe(2);
    });

    it('accepts an empty body so a reasonless transition still validates', () => {
      expect(documentSequenceActionSchema.parse({})).toEqual({});
    });
  });
});
