const paymentMethodService = require('@services/accounts-workspace/payment-method.service');
const repo = require('@repositories/accounts-workspace/payment-method.repository');
const { createAuditLog } = require('@lib/audit');

jest.mock('@repositories/accounts-workspace/payment-method.repository');
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
  method_code: 'MOMO',
  method_name: 'Mobile Money',
  method_type: 'MOBILE_MONEY',
  direction: 'INCOMING',
};

const buildRecord = (overrides = {}) => ({
  id: 'pm-1',
  human_friendly_id: 'PMT0000001',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  method_code: 'MOMO',
  method_name: 'Mobile Money',
  method_type: 'MOBILE_MONEY',
  direction: 'INCOMING',
  provider: 'MTN',
  settlement_account_id: null,
  settlement_account: null,
  clearing_account_id: null,
  clearing_account: null,
  requires_external_reference: true,
  requires_approval: false,
  fee_rule: null,
  facility_scope: null,
  effective_from: new Date('2026-01-01T00:00:00.000Z'),
  effective_to: null,
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

describe('payment-method service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockReturnValue(Promise.resolve());
    repo.groupByStatus.mockResolvedValue([]);
    repo.countRecordedPayments.mockResolvedValue(0);
  });

  describe('listPaymentMethods', () => {
    it('scopes rows to the caller tenant and facility and returns public rows', async () => {
      repo.findMany.mockResolvedValue([buildRecord()]);
      repo.count.mockResolvedValue(1);

      const result = await paymentMethodService.listPaymentMethods(
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
      expect(result.meta.section).toBe('payment-methods');
    });

    it('never leaks a raw database id in a public row', async () => {
      repo.findMany.mockResolvedValue([buildRecord()]);
      repo.count.mockResolvedValue(1);

      const result = await paymentMethodService.listPaymentMethods(
        {},
        1,
        20,
        USER
      );
      const row = result.items[0];

      expect(row.human_friendly_id).toBe('PMT0000001');
      expect(JSON.stringify(row)).not.toContain('pm-1');
      expect(JSON.stringify(row)).not.toContain('facility-1');
      expect(row).not.toHaveProperty('id');
      expect(row).not.toHaveProperty('tenant_id');
    });

    it('exposes the direction under the documented column id', async () => {
      repo.findMany.mockResolvedValue([buildRecord()]);
      repo.count.mockResolvedValue(1);

      const result = await paymentMethodService.listPaymentMethods(
        {},
        1,
        20,
        USER
      );

      expect(result.items[0].incoming_and_outgoing).toBe('INCOMING');
    });

    it('rejects a caller with no tenant instead of widening scope', async () => {
      await expect(
        paymentMethodService.listPaymentMethods({ tenant_id: '' }, 1, 20, {})
      ).rejects.toMatchObject({ statusCode: 403 });
    });

    it('ignores a crafted tenant_id filter and uses the session tenant', async () => {
      repo.findMany.mockResolvedValue([]);
      repo.count.mockResolvedValue(0);

      await paymentMethodService.listPaymentMethods(
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

    it('filters by status, method type, and direction multi-selects', async () => {
      repo.findMany.mockResolvedValue([]);
      repo.count.mockResolvedValue(0);

      await paymentMethodService.listPaymentMethods(
        {
          status: 'ACTIVE,DRAFT',
          method_type: 'CASH,MOBILE_MONEY',
          direction: 'INCOMING',
        },
        1,
        20,
        USER
      );

      const where = repo.findMany.mock.calls[0][0];
      expect(where.status).toEqual({ in: ['ACTIVE', 'DRAFT'] });
      expect(where.method_type).toEqual({ in: ['CASH', 'MOBILE_MONEY'] });
      expect(where.direction).toEqual({ in: ['INCOMING'] });
    });

    it('drops method types outside the canonical taxonomy', async () => {
      repo.findMany.mockResolvedValue([]);
      repo.count.mockResolvedValue(0);

      await paymentMethodService.listPaymentMethods(
        { method_type: 'CRYPTO' },
        1,
        20,
        USER
      );

      expect(repo.findMany.mock.calls[0][0].method_type).toBeUndefined();
    });

    it('filters the boolean flags from query strings', async () => {
      repo.findMany.mockResolvedValue([]);
      repo.count.mockResolvedValue(0);

      await paymentMethodService.listPaymentMethods(
        { requires_external_reference: 'true', requires_approval: 'false' },
        1,
        20,
        USER
      );

      const where = repo.findMany.mock.calls[0][0];
      expect(where.requires_external_reference).toBe(true);
      expect(where.requires_approval).toBe(false);
    });

    it('treats an open effective window as overlapping the requested range', async () => {
      repo.findMany.mockResolvedValue([]);
      repo.count.mockResolvedValue(0);

      await paymentMethodService.listPaymentMethods(
        { from: '2026-01-01', to: '2026-12-31' },
        1,
        20,
        USER
      );

      const where = repo.findMany.mock.calls[0][0];
      expect(where.effective_from).toEqual({ lte: expect.any(Date) });
      expect(where.OR).toEqual([
        { effective_to: null },
        { effective_to: { gte: expect.any(Date) } },
      ]);
    });

    it('maps documented sort keys and falls back to the spec default', async () => {
      repo.findMany.mockResolvedValue([]);
      repo.count.mockResolvedValue(0);

      await paymentMethodService.listPaymentMethods(
        {},
        1,
        20,
        USER,
        'incoming_and_outgoing',
        'asc'
      );
      expect(repo.findMany.mock.calls[0][3]).toEqual([
        { direction: 'asc' },
        { method_code: 'asc' },
      ]);

      await paymentMethodService.listPaymentMethods(
        {},
        1,
        20,
        USER,
        'nonsense',
        'asc'
      );
      expect(repo.findMany.mock.calls[1][3]).toEqual([
        { effective_from: 'desc' },
        { method_code: 'desc' },
      ]);
    });
  });

  describe('createPaymentMethod', () => {
    it('forces DRAFT status and writes an audit event', async () => {
      repo.findFirst
        .mockResolvedValueOnce(null) // duplicate probe
        .mockResolvedValueOnce(buildRecord());
      repo.create.mockResolvedValue({ id: 'pm-1' });

      const row = await paymentMethodService.createPaymentMethod(
        { ...validCreate, status: 'ACTIVE' },
        USER,
        '10.0.0.1'
      );

      const payload = repo.create.mock.calls[0][0];
      expect(payload.status).toBe('DRAFT');
      expect(payload.tenant_id).toBe('tenant-1');
      expect(payload.method_code).toBe('MOMO');
      expect(row.status).toBe('DRAFT');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({ action: 'CREATE', entity: 'payment_method' })
      );
    });

    it('rejects a method type outside the canonical taxonomy', async () => {
      await expect(
        paymentMethodService.createPaymentMethod(
          { ...validCreate, method_type: 'CRYPTO' },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 400 });
      expect(repo.create).not.toHaveBeenCalled();
    });

    it('rejects an unknown direction', async () => {
      await expect(
        paymentMethodService.createPaymentMethod(
          { ...validCreate, direction: 'SIDEWAYS' },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 400 });
    });

    it('rejects a duplicate method code in the tenant', async () => {
      repo.findFirst.mockResolvedValueOnce(buildRecord());

      await expect(
        paymentMethodService.createPaymentMethod(validCreate, USER)
      ).rejects.toMatchObject({ statusCode: 409 });
      expect(repo.create).not.toHaveBeenCalled();
    });

    it('refuses a clearing account without a settlement account', async () => {
      await expect(
        paymentMethodService.createPaymentMethod(
          { ...validCreate, clearing_account_id: 'ACC002' },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 400 });
      expect(repo.create).not.toHaveBeenCalled();
    });

    it('refuses an account that does not resolve inside the tenant', async () => {
      const {
        resolveModelRecordByIdentifier,
      } = require('@lib/identifiers/resolve-entity-id');
      resolveModelRecordByIdentifier.mockResolvedValueOnce(null);

      await expect(
        paymentMethodService.createPaymentMethod(
          { ...validCreate, settlement_account_id: 'FOREIGN' },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 400 });
      expect(repo.create).not.toHaveBeenCalled();
    });
  });

  describe('updatePaymentMethod', () => {
    it('rejects a stale optimistic version', async () => {
      repo.findFirst.mockResolvedValue(buildRecord({ version: 4 }));

      await expect(
        paymentMethodService.updatePaymentMethod(
          'PMT0000001',
          { method_name: 'Renamed', version: 2 },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 409 });
      expect(repo.updateWithVersion).not.toHaveBeenCalled();
    });

    it('rejects an archived record as not editable', async () => {
      repo.findFirst.mockResolvedValue(buildRecord({ status: 'ARCHIVED' }));

      await expect(
        paymentMethodService.updatePaymentMethod(
          'PMT0000001',
          { method_name: 'Renamed' },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 409 });
    });

    it('rejects an effective window that ends before it starts', async () => {
      repo.findFirst.mockResolvedValue(buildRecord());

      await expect(
        paymentMethodService.updatePaymentMethod(
          'PMT0000001',
          {
            effective_from: '2026-06-01T00:00:00.000Z',
            effective_to: '2026-01-01T00:00:00.000Z',
          },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 400 });
    });

    it('toggles the boolean flags explicitly', async () => {
      repo.findFirst.mockResolvedValue(buildRecord());
      repo.updateWithVersion.mockResolvedValue(
        buildRecord({ requires_approval: true, version: 2 })
      );

      await paymentMethodService.updatePaymentMethod(
        'PMT0000001',
        { requires_approval: true, requires_external_reference: false },
        USER
      );

      const patch = repo.updateWithVersion.mock.calls[0][2];
      expect(patch.requires_approval).toBe(true);
      expect(patch.requires_external_reference).toBe(false);
    });

    it('reports a conflict when the guarded update matches no row', async () => {
      repo.findFirst.mockResolvedValue(buildRecord());
      repo.updateWithVersion.mockResolvedValue(null);

      await expect(
        paymentMethodService.updatePaymentMethod(
          'PMT0000001',
          { method_name: 'Renamed' },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 409 });
    });

    it('writes a before/after audit diff on success', async () => {
      repo.findFirst.mockResolvedValue(buildRecord());
      repo.updateWithVersion.mockResolvedValue(
        buildRecord({ method_name: 'Renamed', version: 2 })
      );

      await paymentMethodService.updatePaymentMethod(
        'PMT0000001',
        { method_name: 'Renamed' },
        USER,
        '10.0.0.1'
      );

      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'UPDATE',
          entity: 'payment_method',
          diff: expect.objectContaining({
            before: expect.any(Object),
            after: expect.any(Object),
          }),
        })
      );
    });
  });

  describe('applyPaymentMethodAction', () => {
    it('activates a draft and records the reason', async () => {
      repo.findFirst.mockResolvedValue(buildRecord({ status: 'DRAFT' }));
      repo.updateWithVersion.mockResolvedValue(
        buildRecord({ status: 'ACTIVE', version: 2 })
      );

      const row = await paymentMethodService.applyPaymentMethodAction(
        'PMT0000001',
        'activate',
        { reason: 'Go live' },
        USER,
        '10.0.0.1'
      );

      expect(row.status).toBe('ACTIVE');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'ACTIVATE',
          diff: expect.objectContaining({ reason: 'Go live' }),
        })
      );
    });

    it('refuses a transition the status model does not allow', async () => {
      repo.findFirst.mockResolvedValue(buildRecord({ status: 'DRAFT' }));

      await expect(
        paymentMethodService.applyPaymentMethodAction(
          'PMT0000001',
          'deactivate',
          {},
          USER
        )
      ).rejects.toMatchObject({ statusCode: 409 });
      expect(repo.updateWithVersion).not.toHaveBeenCalled();
    });

    it('refuses to archive while recorded payments used this tender', async () => {
      repo.findFirst.mockResolvedValue(buildRecord({ status: 'ACTIVE' }));
      repo.countRecordedPayments.mockResolvedValue(12);

      await expect(
        paymentMethodService.applyPaymentMethodAction(
          'PMT0000001',
          'archive',
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

      await paymentMethodService.applyPaymentMethodAction(
        'PMT0000001',
        'archive',
        {},
        USER
      );

      const patch = repo.updateWithVersion.mock.calls[0][2];
      expect(patch.status).toBe('ARCHIVED');
      expect(patch.archived_at).toBeInstanceOf(Date);
    });

    it('restores an archived record back to active', async () => {
      repo.findFirst.mockResolvedValue(buildRecord({ status: 'ARCHIVED' }));
      repo.updateWithVersion.mockResolvedValue(
        buildRecord({ status: 'ACTIVE', version: 3 })
      );

      const row = await paymentMethodService.applyPaymentMethodAction(
        'PMT0000001',
        'restore',
        {},
        USER
      );

      expect(row.status).toBe('ACTIVE');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({ action: 'RESTORE' })
      );
    });

    it('rejects an unknown action', async () => {
      await expect(
        paymentMethodService.applyPaymentMethodAction(
          'PMT0000001',
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
        paymentMethodService.applyPaymentMethodAction(
          'PMT0000001',
          'activate',
          { version: 2 },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 409 });
      expect(repo.updateWithVersion).not.toHaveBeenCalled();
    });
  });

  describe('countActivePaymentMethods', () => {
    it('counts only ACTIVE rows inside the caller scope', async () => {
      repo.count.mockResolvedValue(5);

      const total = await paymentMethodService.countActivePaymentMethods(
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
        paymentMethodService.countActivePaymentMethods({}, USER)
      ).resolves.toBe(0);
    });
  });
});
