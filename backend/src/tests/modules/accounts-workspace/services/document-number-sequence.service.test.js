const documentSequenceService = require('@services/accounts-workspace/document-number-sequence.service');
const repo = require('@repositories/accounts-workspace/document-number-sequence.repository');
const { createAuditLog } = require('@lib/audit');

jest.mock('@repositories/accounts-workspace/document-number-sequence.repository');
jest.mock('@lib/audit');
jest.mock('@config/feature-flags', () => ({
  isFeatureEnabled: () => true,
}));
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelRecordByIdentifier: jest.fn(async ({ identifier }) => ({
    id: `resolved-${identifier}`,
  })),
}));
jest.mock('@lib/billing/identifiers', () => ({
  resolvePublicIdentifier: (...values) => values.find((value) => value) || null,
}));

const USER = { id: 'user-1', tenant_id: 'tenant-1', facility_id: 'facility-1' };

const validCreate = {
  sequence_code: 'INV-MAIN',
  document_type: 'INVOICE',
  module: 'BILLING',
  prefix: 'INV',
  minimum_length: 7,
  reset_frequency: 'NEVER',
};

/**
 * The `human_id_counter` row the seeded record's policy configures.
 *
 * Derived the same way `src/prisma/client.js` derives it when it reserves a
 * number: model `invoice` → prefix `INV`, scoped to the narrowest key.
 */
const INVOICE_COUNTER = {
  model_name: 'invoice',
  prefix: 'INV',
  scope_key: 'facility:facility-1:model:invoice:prefix:INV',
  last_value: 42,
  updated_at: new Date('2026-08-01T09:30:00.000Z'),
};

const buildRecord = (overrides = {}) => ({
  id: 'dns-1',
  human_friendly_id: 'DNS0000001',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  sequence_code: 'INV-MAIN',
  document_type: 'INVOICE',
  module: 'BILLING',
  counter_model: 'invoice',
  prefix: 'INV',
  suffix: null,
  date_pattern: null,
  minimum_length: 7,
  reset_frequency: 'NEVER',
  gap_policy: 'ALLOW_GAPS',
  status: 'DRAFT',
  notes: null,
  version: 1,
  created_at: new Date('2026-01-01T00:00:00.000Z'),
  updated_at: new Date('2026-01-01T00:00:00.000Z'),
  archived_at: null,
  facility: {
    id: 'facility-1',
    human_friendly_id: 'FAC0001',
    name: 'Main Hospital',
  },
  ...overrides,
});

describe('document-number-sequence service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockReturnValue(Promise.resolve());
    repo.groupByStatus.mockResolvedValue([]);
    repo.findCounters.mockResolvedValue([]);
  });

  describe('listDocumentSequences', () => {
    it('scopes rows to the caller tenant and facility and returns public rows', async () => {
      repo.findMany.mockResolvedValue([buildRecord()]);
      repo.count.mockResolvedValue(1);

      const result = await documentSequenceService.listDocumentSequences(
        {},
        1,
        20,
        USER
      );

      expect(repo.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
        }),
        0,
        20,
        expect.any(Array)
      );
      expect(result.items).toHaveLength(1);
      expect(result.meta.section).toBe('document-numbering');
      expect(result.meta.filtered_total).toBe(1);
    });

    it('never leaks a raw database id in a public row', async () => {
      repo.findMany.mockResolvedValue([buildRecord()]);
      repo.count.mockResolvedValue(1);

      const result = await documentSequenceService.listDocumentSequences(
        {},
        1,
        20,
        USER
      );
      const row = result.items[0];

      expect(row.human_friendly_id).toBe('DNS0000001');
      expect(JSON.stringify(row)).not.toContain('dns-1');
      expect(JSON.stringify(row)).not.toContain('facility-1');
      expect(row).not.toHaveProperty('id');
      expect(row).not.toHaveProperty('tenant_id');
      expect(row).not.toHaveProperty('counter_model');
    });

    it('derives the issued numbers from the live counter, not a second copy', async () => {
      repo.findMany.mockResolvedValue([buildRecord()]);
      repo.count.mockResolvedValue(1);
      repo.findCounters.mockResolvedValue([INVOICE_COUNTER]);

      const result = await documentSequenceService.listDocumentSequences(
        {},
        1,
        20,
        USER
      );
      const row = result.items[0];

      expect(repo.findCounters).toHaveBeenCalledWith([
        {
          model_name: 'invoice',
          prefix: 'INV',
          scope_key: 'facility:facility-1:model:invoice:prefix:INV',
        },
      ]);
      expect(row.last_issued_number).toBe(42);
      expect(row.next_number).toBe(43);
      expect(row.last_issued_at).toBe('2026-08-01T09:30:00.000Z');
      expect(row.next_reference_preview).toBe('INV0000043');
    });

    it('reports an unused sequence as starting at one with nothing issued', async () => {
      repo.findMany.mockResolvedValue([buildRecord()]);
      repo.count.mockResolvedValue(1);

      const result = await documentSequenceService.listDocumentSequences(
        {},
        1,
        20,
        USER
      );
      const row = result.items[0];

      expect(row.next_number).toBe(1);
      expect(row.last_issued_number).toBeNull();
      expect(row.last_issued_at).toBeNull();
      expect(row.next_reference_preview).toBe('INV0000001');
    });

    it('wraps the padded number in the configured affixes and date pattern', async () => {
      repo.findMany.mockResolvedValue([
        buildRecord({
          prefix: 'INV',
          suffix: 'KLA',
          date_pattern: '2026',
          minimum_length: 5,
        }),
      ]);
      repo.count.mockResolvedValue(1);
      repo.findCounters.mockResolvedValue([INVOICE_COUNTER]);

      const result = await documentSequenceService.listDocumentSequences(
        {},
        1,
        20,
        USER
      );

      expect(result.items[0].next_reference_preview).toBe('INV202600043KLA');
    });

    it('rejects a caller with no tenant instead of widening scope', async () => {
      await expect(
        documentSequenceService.listDocumentSequences({ tenant_id: '' }, 1, 20, {})
      ).rejects.toMatchObject({ statusCode: 403 });
    });

    it('ignores a crafted tenant_id filter and uses the session tenant', async () => {
      repo.findMany.mockResolvedValue([]);
      repo.count.mockResolvedValue(0);

      await documentSequenceService.listDocumentSequences(
        { tenant_id: 'other-tenant' },
        1,
        20,
        USER
      );

      expect(repo.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ tenant_id: 'tenant-1' }),
        0,
        20,
        expect.any(Array)
      );
    });

    it('filters by status, document type, reset frequency, and gap policy', async () => {
      repo.findMany.mockResolvedValue([]);
      repo.count.mockResolvedValue(0);

      await documentSequenceService.listDocumentSequences(
        {
          status: 'ACTIVE,DRAFT',
          document_type: 'INVOICE,CLAIM',
          reset_frequency: 'YEARLY',
          gap_policy: 'NO_GAPS',
        },
        1,
        20,
        USER
      );

      const where = repo.findMany.mock.calls[0][0];
      expect(where.status).toEqual({ in: ['ACTIVE', 'DRAFT'] });
      expect(where.document_type).toEqual({ in: ['INVOICE', 'CLAIM'] });
      expect(where.reset_frequency).toEqual({ in: ['YEARLY'] });
      expect(where.gap_policy).toEqual({ in: ['NO_GAPS'] });
    });

    it('drops a status outside the documented model', async () => {
      repo.findMany.mockResolvedValue([]);
      repo.count.mockResolvedValue(0);

      await documentSequenceService.listDocumentSequences(
        { status: 'DELETED' },
        1,
        20,
        USER
      );

      expect(repo.findMany.mock.calls[0][0].status).toBeUndefined();
    });

    it('searches the public reference and the permitted display fields', async () => {
      repo.findMany.mockResolvedValue([]);
      repo.count.mockResolvedValue(0);

      await documentSequenceService.listDocumentSequences(
        { search: 'INV' },
        1,
        20,
        USER
      );

      expect(repo.findMany.mock.calls[0][0].OR).toEqual([
        { human_friendly_id: { contains: 'INV' } },
        { sequence_code: { contains: 'INV' } },
        { prefix: { contains: 'INV' } },
        { suffix: { contains: 'INV' } },
        { module: { contains: 'INV' } },
      ]);
    });

    it('applies inclusive date boundaries to the record timeline', async () => {
      repo.findMany.mockResolvedValue([]);
      repo.count.mockResolvedValue(0);

      await documentSequenceService.listDocumentSequences(
        { from: '2026-01-01', to: '2026-12-31' },
        1,
        20,
        USER
      );

      expect(repo.findMany.mock.calls[0][0].updated_at).toEqual({
        gte: expect.any(Date),
        lte: expect.any(Date),
      });
    });

    it('maps documented sort keys and falls back to the spec default', async () => {
      repo.findMany.mockResolvedValue([]);
      repo.count.mockResolvedValue(0);

      await documentSequenceService.listDocumentSequences(
        {},
        1,
        20,
        USER,
        'sequence_status',
        'asc'
      );
      expect(repo.findMany.mock.calls[0][3]).toEqual([
        { status: 'asc' },
        { sequence_code: 'asc' },
      ]);

      await documentSequenceService.listDocumentSequences(
        {},
        1,
        20,
        USER,
        'nonsense',
        'asc'
      );
      expect(repo.findMany.mock.calls[1][3]).toEqual([
        { document_type: 'asc' },
        { sequence_code: 'asc' },
      ]);
    });

    it('falls back to the default order for counter-derived sort keys', async () => {
      repo.findMany.mockResolvedValue([]);
      repo.count.mockResolvedValue(0);

      // `last_issued_at` lives in `human_id_counter`, so it cannot be pushed
      // into this table's query.
      await documentSequenceService.listDocumentSequences(
        {},
        1,
        20,
        USER,
        'last_issued_at',
        'desc'
      );

      expect(repo.findMany.mock.calls[0][3]).toEqual([
        { document_type: 'asc' },
        { sequence_code: 'asc' },
      ]);
    });

    it('returns status tallies for the filtered result', async () => {
      repo.findMany.mockResolvedValue([]);
      repo.count.mockResolvedValue(3);
      repo.groupByStatus.mockResolvedValue([
        { status: 'ACTIVE', _count: { _all: 2 } },
        { status: 'DRAFT', _count: { _all: 1 } },
      ]);

      const result = await documentSequenceService.listDocumentSequences(
        {},
        1,
        20,
        USER
      );

      expect(result.meta.status_counts).toEqual({ ACTIVE: 2, DRAFT: 1 });
    });
  });

  describe('getDocumentSequence', () => {
    it('resolves a record by its public reference', async () => {
      repo.findFirst.mockResolvedValue(buildRecord());

      const row = await documentSequenceService.getDocumentSequence(
        'DNS0000001',
        {},
        USER
      );

      expect(row.human_friendly_id).toBe('DNS0000001');
      expect(repo.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-1',
          OR: [{ human_friendly_id: 'DNS0000001' }, { id: 'DNS0000001' }],
        })
      );
    });

    it('reports a record outside the caller scope as missing', async () => {
      repo.findFirst.mockResolvedValue(null);

      await expect(
        documentSequenceService.getDocumentSequence('DNS0000009', {}, USER)
      ).rejects.toMatchObject({ statusCode: 404 });
    });
  });

  describe('createDocumentSequence', () => {
    it('forces DRAFT status and writes an audit event', async () => {
      repo.findFirst
        .mockResolvedValueOnce(null) // duplicate code probe
        .mockResolvedValueOnce(null) // duplicate scope probe
        .mockResolvedValueOnce(buildRecord());
      repo.create.mockResolvedValue({ id: 'dns-1' });

      const row = await documentSequenceService.createDocumentSequence(
        { ...validCreate, status: 'ACTIVE' },
        USER,
        '10.0.0.1'
      );

      const payload = repo.create.mock.calls[0][0];
      expect(payload.status).toBe('DRAFT');
      expect(payload.tenant_id).toBe('tenant-1');
      expect(payload.sequence_code).toBe('INV-MAIN');
      expect(row.sequence_status).toBe('DRAFT');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'CREATE',
          entity: 'document_number_sequence',
        })
      );
    });

    it('binds the policy to the counter the document family already uses', async () => {
      repo.findFirst
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(buildRecord());
      repo.create.mockResolvedValue({ id: 'dns-1' });

      await documentSequenceService.createDocumentSequence(
        { ...validCreate, document_type: 'CREDIT_NOTE' },
        USER
      );

      // Credit and debit notes are both billing adjustments; they share a
      // counter rather than getting a second source of truth.
      expect(repo.create.mock.calls[0][0].counter_model).toBe(
        'billing_adjustment'
      );
    });

    it('rejects a document type the system does not number', async () => {
      await expect(
        documentSequenceService.createDocumentSequence(
          { ...validCreate, document_type: 'PRESCRIPTION' },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 400 });
      expect(repo.create).not.toHaveBeenCalled();
    });

    it('rejects a duplicate sequence code in the tenant', async () => {
      repo.findFirst.mockResolvedValueOnce(buildRecord());

      await expect(
        documentSequenceService.createDocumentSequence(validCreate, USER)
      ).rejects.toMatchObject({ statusCode: 409 });
      expect(repo.create).not.toHaveBeenCalled();
    });

    it('refuses a second live sequence for the same document family', async () => {
      repo.findFirst
        .mockResolvedValueOnce(null) // code is free
        .mockResolvedValueOnce(buildRecord({ status: 'ACTIVE' }));

      await expect(
        documentSequenceService.createDocumentSequence(validCreate, USER)
      ).rejects.toMatchObject({ statusCode: 409 });
      expect(repo.create).not.toHaveBeenCalled();
    });
  });

  describe('updateDocumentSequence', () => {
    it('rejects a stale optimistic version', async () => {
      repo.findFirst.mockResolvedValue(buildRecord({ version: 4 }));

      await expect(
        documentSequenceService.updateDocumentSequence(
          'DNS0000001',
          { module: 'GENERAL_LEDGER', version: 2 },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 409 });
      expect(repo.updateWithVersion).not.toHaveBeenCalled();
    });

    it('rejects an archived record as not editable', async () => {
      repo.findFirst.mockResolvedValue(buildRecord({ status: 'ARCHIVED' }));

      await expect(
        documentSequenceService.updateDocumentSequence(
          'DNS0000001',
          { module: 'GENERAL_LEDGER' },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 409 });
    });

    it('freezes the reference shape once numbers have been issued', async () => {
      repo.findFirst.mockResolvedValue(buildRecord());
      repo.findCounters.mockResolvedValue([INVOICE_COUNTER]);

      // Changing the prefix now would make old and new references
      // indistinguishable.
      await expect(
        documentSequenceService.updateDocumentSequence(
          'DNS0000001',
          { prefix: 'BIL' },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 409 });
      expect(repo.updateWithVersion).not.toHaveBeenCalled();
    });

    it('allows a shape change while the sequence has issued nothing', async () => {
      repo.findFirst
        .mockResolvedValueOnce(buildRecord())
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(null);
      repo.updateWithVersion.mockResolvedValue(
        buildRecord({ prefix: 'BIL', version: 2 })
      );

      await documentSequenceService.updateDocumentSequence(
        'DNS0000001',
        { prefix: 'BIL' },
        USER
      );

      expect(repo.updateWithVersion.mock.calls[0][2].prefix).toBe('BIL');
    });

    it('refuses to repoint an in-use sequence at another document family', async () => {
      repo.findFirst.mockResolvedValue(buildRecord());
      repo.findCounters.mockResolvedValue([INVOICE_COUNTER]);

      await expect(
        documentSequenceService.updateDocumentSequence(
          'DNS0000001',
          { document_type: 'CLAIM' },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 409 });
    });

    it('reports a conflict when the guarded update matches no row', async () => {
      repo.findFirst
        .mockResolvedValueOnce(buildRecord())
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(null);
      repo.updateWithVersion.mockResolvedValue(null);

      await expect(
        documentSequenceService.updateDocumentSequence(
          'DNS0000001',
          { module: 'GENERAL_LEDGER' },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 409 });
    });

    it('writes a before/after audit diff on success', async () => {
      repo.findFirst
        .mockResolvedValueOnce(buildRecord())
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(null);
      repo.updateWithVersion.mockResolvedValue(
        buildRecord({ module: 'GENERAL_LEDGER', version: 2 })
      );

      await documentSequenceService.updateDocumentSequence(
        'DNS0000001',
        { module: 'GENERAL_LEDGER' },
        USER,
        '10.0.0.1'
      );

      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'UPDATE',
          entity: 'document_number_sequence',
          diff: expect.objectContaining({
            before: expect.any(Object),
            after: expect.any(Object),
          }),
        })
      );
    });
  });

  describe('applyDocumentSequenceAction', () => {
    it('activates a draft and records the reason', async () => {
      repo.findFirst
        .mockResolvedValueOnce(buildRecord({ status: 'DRAFT' }))
        .mockResolvedValueOnce(null); // no conflicting active sequence
      repo.updateWithVersion.mockResolvedValue(
        buildRecord({ status: 'ACTIVE', version: 2 })
      );

      const row = await documentSequenceService.applyDocumentSequenceAction(
        'DNS0000001',
        'activate',
        { reason: 'Go live' },
        USER,
        '10.0.0.1'
      );

      expect(row.sequence_status).toBe('ACTIVE');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'ACTIVATE',
          diff: expect.objectContaining({ reason: 'Go live' }),
        })
      );
    });

    it('refuses to activate a second sequence for the same document family', async () => {
      repo.findFirst
        .mockResolvedValueOnce(buildRecord({ status: 'DRAFT' }))
        .mockResolvedValueOnce(buildRecord({ id: 'dns-2', status: 'ACTIVE' }));

      // Two active policies would race for the same counter and issue
      // duplicate references.
      await expect(
        documentSequenceService.applyDocumentSequenceAction(
          'DNS0000001',
          'activate',
          {},
          USER
        )
      ).rejects.toMatchObject({ statusCode: 409 });
      expect(repo.updateWithVersion).not.toHaveBeenCalled();
    });

    it('refuses a transition the status model does not allow', async () => {
      repo.findFirst.mockResolvedValue(buildRecord({ status: 'DRAFT' }));

      await expect(
        documentSequenceService.applyDocumentSequenceAction(
          'DNS0000001',
          'deactivate',
          {},
          USER
        )
      ).rejects.toMatchObject({ statusCode: 409 });
      expect(repo.updateWithVersion).not.toHaveBeenCalled();
    });

    it('archives as a soft state change, never a delete', async () => {
      repo.findFirst.mockResolvedValue(buildRecord({ status: 'ACTIVE' }));
      repo.updateWithVersion.mockResolvedValue(
        buildRecord({ status: 'ARCHIVED', archived_at: new Date(), version: 2 })
      );

      await documentSequenceService.applyDocumentSequenceAction(
        'DNS0000001',
        'archive',
        {},
        USER
      );

      const patch = repo.updateWithVersion.mock.calls[0][2];
      expect(patch.status).toBe('ARCHIVED');
      expect(patch.archived_at).toBeInstanceOf(Date);
    });

    it('restores an archived record back to active', async () => {
      repo.findFirst
        .mockResolvedValueOnce(buildRecord({ status: 'ARCHIVED' }))
        .mockResolvedValueOnce(null);
      repo.updateWithVersion.mockResolvedValue(
        buildRecord({ status: 'ACTIVE', version: 3 })
      );

      const row = await documentSequenceService.applyDocumentSequenceAction(
        'DNS0000001',
        'restore',
        {},
        USER
      );

      expect(row.sequence_status).toBe('ACTIVE');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({ action: 'RESTORE' })
      );
    });

    it('rejects an unknown action', async () => {
      await expect(
        documentSequenceService.applyDocumentSequenceAction(
          'DNS0000001',
          'explode',
          {},
          USER
        )
      ).rejects.toMatchObject({ statusCode: 400 });
    });

    it('rejects a stale version before touching the row', async () => {
      repo.findFirst.mockResolvedValue(
        buildRecord({ status: 'DRAFT', version: 5 })
      );

      await expect(
        documentSequenceService.applyDocumentSequenceAction(
          'DNS0000001',
          'activate',
          { version: 2 },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 409 });
      expect(repo.updateWithVersion).not.toHaveBeenCalled();
    });
  });

  describe('countActiveDocumentSequences', () => {
    it('counts only ACTIVE rows inside the caller scope', async () => {
      repo.count.mockResolvedValue(5);

      const total = await documentSequenceService.countActiveDocumentSequences(
        {},
        USER
      );

      expect(total).toBe(5);
      expect(repo.count).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          status: 'ACTIVE',
        })
      );
    });

    it('degrades to zero rather than breaking the workspace summary', async () => {
      repo.count.mockRejectedValue(new Error('db down'));

      await expect(
        documentSequenceService.countActiveDocumentSequences({}, USER)
      ).resolves.toBe(0);
    });
  });
});
