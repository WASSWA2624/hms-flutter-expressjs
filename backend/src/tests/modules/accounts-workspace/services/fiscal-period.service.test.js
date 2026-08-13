const fiscalPeriodService = require('@services/accounts-workspace/fiscal-period.service');
const repo = require('@repositories/accounts-workspace/fiscal-period.repository');
const { createAuditLog } = require('@lib/audit');

jest.mock('@repositories/accounts-workspace/fiscal-period.repository');
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

const buildRecord = (overrides = {}) => ({
  id: 'fp-1',
  human_friendly_id: 'FIS0000001',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  fiscal_year: 'FY2026',
  period_no: 1,
  period_name: 'January 2026',
  start_date: new Date('2026-01-01T00:00:00.000Z'),
  end_date: new Date('2026-01-31T00:00:00.000Z'),
  module: 'ALL',
  open_date: null,
  soft_close_date: null,
  close_date: null,
  lock_date: null,
  reopened_at: null,
  reopened_by: null,
  reopened_user: null,
  status: 'DRAFT',
  notes: null,
  version: 1,
  created_at: new Date('2026-01-01T00:00:00.000Z'),
  updated_at: new Date('2026-01-01T00:00:00.000Z'),
  archived_at: null,
  facility: { id: 'facility-1', human_friendly_id: 'FAC0001', name: 'Main Hospital' },
  ...overrides,
});

describe('fiscal-period service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockReturnValue(Promise.resolve());
    repo.groupByStatus.mockResolvedValue([]);
  });

  describe('listFiscalPeriods', () => {
    it('scopes rows to the caller tenant and facility and returns public rows', async () => {
      repo.findMany.mockResolvedValue([buildRecord()]);
      repo.count.mockResolvedValue(1);

      const result = await fiscalPeriodService.listFiscalPeriods({}, 1, 20, USER);

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
      expect(result.items[0]).toEqual(
        expect.objectContaining({
          human_friendly_id: 'FIS0000001',
          fiscal_year: 'FY2026',
          period_no: 1,
          entity_and_facility: 'Main Hospital',
          period_status: 'DRAFT',
        })
      );
      expect(result.items[0].id).toBeUndefined();
      expect(result.items[0].tenant_id).toBeUndefined();
      expect(result.pagination).toEqual(
        expect.objectContaining({ page: 1, limit: 20, total: 1, totalPages: 1 })
      );
    });

    it('rejects a caller without tenant context', async () => {
      await expect(
        fiscalPeriodService.listFiscalPeriods({}, 1, 20, {})
      ).rejects.toMatchObject({ statusCode: 403 });
    });

    it('applies status, fiscal year, and search filters', async () => {
      repo.findMany.mockResolvedValue([]);
      repo.count.mockResolvedValue(0);

      await fiscalPeriodService.listFiscalPeriods(
        { status: ['ACTIVE', 'DRAFT'], fiscal_year: 'FY2026', search: 'jan' },
        1,
        20,
        USER
      );

      const where = repo.findMany.mock.calls[0][0];
      expect(where.status).toEqual({ in: ['ACTIVE', 'DRAFT'] });
      expect(where.fiscal_year).toBe('FY2026');
      expect(where.OR).toEqual(
        expect.arrayContaining([{ period_name: { contains: 'jan' } }])
      );
    });

    it('accepts a comma-separated status string from the shared work-items route', async () => {
      repo.findMany.mockResolvedValue([]);
      repo.count.mockResolvedValue(0);

      await fiscalPeriodService.listFiscalPeriods(
        { status: 'active,archived' },
        1,
        20,
        USER
      );

      expect(repo.findMany.mock.calls[0][0].status).toEqual({
        in: ['ACTIVE', 'ARCHIVED'],
      });
    });

    it('maps a known sort key and ignores an unknown one', async () => {
      repo.findMany.mockResolvedValue([]);
      repo.count.mockResolvedValue(0);

      await fiscalPeriodService.listFiscalPeriods({}, 1, 20, USER, 'period_status', 'asc');
      expect(repo.findMany.mock.calls[0][3][0]).toEqual({ status: 'asc' });

      await fiscalPeriodService.listFiscalPeriods({}, 1, 20, USER, 'drop table', 'asc');
      expect(repo.findMany.mock.calls[1][3][0]).toEqual({ start_date: 'desc' });
    });
  });

  describe('getFiscalPeriod', () => {
    it('returns 404 when the record is outside the caller scope', async () => {
      repo.findFirst.mockResolvedValue(null);

      await expect(
        fiscalPeriodService.getFiscalPeriod('FIS0000001', {}, USER)
      ).rejects.toMatchObject({
        statusCode: 404,
        message: 'errors.accounts.fiscal_period.not_found',
      });
    });
  });

  describe('createFiscalPeriod', () => {
    const payload = {
      fiscal_year: 'FY2026',
      period_no: 1,
      period_name: 'January 2026',
      start_date: '2026-01-01T00:00:00.000Z',
      end_date: '2026-01-31T00:00:00.000Z',
    };

    it('assigns the safe initial status and writes an audit event', async () => {
      repo.findFirst
        .mockResolvedValueOnce(null) // duplicate check
        .mockResolvedValueOnce(null) // overlap check
        .mockResolvedValueOnce(buildRecord());
      repo.create.mockResolvedValue(buildRecord());

      const result = await fiscalPeriodService.createFiscalPeriod(payload, USER, '127.0.0.1');

      expect(repo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          status: 'DRAFT',
          module: 'ALL',
          created_by: 'user-1',
        })
      );
      expect(result.period_status).toBe('DRAFT');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({ action: 'CREATE', entity: 'fiscal_period' })
      );
    });

    it('rejects a duplicate period number for the same year and module', async () => {
      repo.findFirst.mockResolvedValueOnce(buildRecord());

      await expect(
        fiscalPeriodService.createFiscalPeriod(payload, USER, '127.0.0.1')
      ).rejects.toMatchObject({
        statusCode: 409,
        message: 'errors.accounts.fiscal_period.duplicate',
      });
      expect(repo.create).not.toHaveBeenCalled();
    });

    it('rejects a period overlapping an existing one', async () => {
      repo.findFirst
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(buildRecord({ id: 'fp-2' }));

      await expect(
        fiscalPeriodService.createFiscalPeriod(payload, USER, '127.0.0.1')
      ).rejects.toMatchObject({
        statusCode: 409,
        message: 'errors.accounts.fiscal_period.overlapping',
      });
      expect(repo.create).not.toHaveBeenCalled();
    });
  });

  describe('updateFiscalPeriod', () => {
    it('returns 409 when the submitted version is stale', async () => {
      repo.findFirst.mockResolvedValueOnce(buildRecord({ version: 3 }));

      await expect(
        fiscalPeriodService.updateFiscalPeriod(
          'FIS0000001',
          { period_name: 'Renamed', version: 2 },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 409, message: 'errors.conflict' });
      expect(repo.updateWithVersion).not.toHaveBeenCalled();
    });

    it('blocks edits once the period is locked', async () => {
      repo.findFirst.mockResolvedValueOnce(
        buildRecord({ lock_date: new Date('2020-01-01T00:00:00.000Z') })
      );

      await expect(
        fiscalPeriodService.updateFiscalPeriod('FIS0000001', { period_name: 'x' }, USER)
      ).rejects.toMatchObject({
        statusCode: 409,
        message: 'errors.accounts.fiscal_period.locked',
      });
    });

    it('blocks edits on an archived record', async () => {
      repo.findFirst.mockResolvedValueOnce(buildRecord({ status: 'ARCHIVED' }));

      await expect(
        fiscalPeriodService.updateFiscalPeriod('FIS0000001', { period_name: 'x' }, USER)
      ).rejects.toMatchObject({
        statusCode: 409,
        message: 'errors.accounts.fiscal_period.not_editable',
      });
    });

    it('rejects an end date earlier than the start date', async () => {
      repo.findFirst.mockResolvedValueOnce(buildRecord());

      await expect(
        fiscalPeriodService.updateFiscalPeriod(
          'FIS0000001',
          { end_date: '2025-12-01T00:00:00.000Z' },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 400 });
    });

    it('persists the patch and audits the change', async () => {
      repo.findFirst
        .mockResolvedValueOnce(buildRecord())
        .mockResolvedValueOnce(null); // overlap check
      repo.updateWithVersion.mockResolvedValue(
        buildRecord({ period_name: 'Renamed', version: 2 })
      );

      const result = await fiscalPeriodService.updateFiscalPeriod(
        'FIS0000001',
        { period_name: 'Renamed' },
        USER,
        '127.0.0.1'
      );

      expect(repo.updateWithVersion).toHaveBeenCalledWith(
        'fp-1',
        1,
        expect.objectContaining({ period_name: 'Renamed', updated_by: 'user-1' })
      );
      expect(result.period_name).toBe('Renamed');
      expect(result.version).toBe(2);
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({ action: 'UPDATE', entity: 'fiscal_period' })
      );
    });

    it('returns 409 when the row changed between read and write', async () => {
      repo.findFirst.mockResolvedValueOnce(buildRecord()).mockResolvedValueOnce(null);
      repo.updateWithVersion.mockResolvedValue(null);

      await expect(
        fiscalPeriodService.updateFiscalPeriod('FIS0000001', { period_name: 'x' }, USER)
      ).rejects.toMatchObject({ statusCode: 409, message: 'errors.conflict' });
    });
  });

  describe('applyFiscalPeriodAction', () => {
    it('activates a draft record', async () => {
      repo.findFirst.mockResolvedValueOnce(buildRecord({ status: 'DRAFT' }));
      repo.updateWithVersion.mockResolvedValue(
        buildRecord({ status: 'ACTIVE', version: 2 })
      );

      const result = await fiscalPeriodService.applyFiscalPeriodAction(
        'FIS0000001',
        'activate',
        {},
        USER,
        '127.0.0.1'
      );

      expect(result.period_status).toBe('ACTIVE');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({ action: 'ACTIVATE' })
      );
    });

    it('rejects a transition the status model does not allow', async () => {
      repo.findFirst.mockResolvedValueOnce(buildRecord({ status: 'DRAFT' }));

      await expect(
        fiscalPeriodService.applyFiscalPeriodAction('FIS0000001', 'deactivate', {}, USER)
      ).rejects.toMatchObject({
        statusCode: 409,
        message: 'errors.accounts.fiscal_period.invalid_transition',
      });
      expect(repo.updateWithVersion).not.toHaveBeenCalled();
    });

    it('archives without hard deleting and stamps archived_at', async () => {
      repo.findFirst.mockResolvedValueOnce(buildRecord({ status: 'ACTIVE' }));
      repo.updateWithVersion.mockResolvedValue(
        buildRecord({ status: 'ARCHIVED', version: 2 })
      );

      await fiscalPeriodService.applyFiscalPeriodAction(
        'FIS0000001',
        'archive',
        { reason: 'Superseded' },
        USER
      );

      const patch = repo.updateWithVersion.mock.calls[0][2];
      expect(patch.status).toBe('ARCHIVED');
      expect(patch.archived_at).toBeInstanceOf(Date);
      expect(patch.deleted_at).toBeUndefined();
    });

    it('records the reopen actor when restoring an archived record', async () => {
      repo.findFirst.mockResolvedValueOnce(buildRecord({ status: 'ARCHIVED' }));
      repo.updateWithVersion.mockResolvedValue(
        buildRecord({ status: 'ACTIVE', version: 2 })
      );

      await fiscalPeriodService.applyFiscalPeriodAction(
        'FIS0000001',
        'restore',
        {},
        USER
      );

      const patch = repo.updateWithVersion.mock.calls[0][2];
      expect(patch.status).toBe('ACTIVE');
      expect(patch.reopened_by).toBe('user-1');
      expect(patch.reopened_at).toBeInstanceOf(Date);
    });

    it('rejects an unknown action', async () => {
      await expect(
        fiscalPeriodService.applyFiscalPeriodAction('FIS0000001', 'purge', {}, USER)
      ).rejects.toMatchObject({ statusCode: 400 });
    });
  });

  describe('countActiveFiscalPeriods', () => {
    it('counts only active rows in scope', async () => {
      repo.count.mockResolvedValue(12);

      const total = await fiscalPeriodService.countActiveFiscalPeriods({}, USER);

      expect(total).toBe(12);
      expect(repo.count).toHaveBeenCalledWith(
        expect.objectContaining({ status: 'ACTIVE', tenant_id: 'tenant-1' })
      );
    });

    it('degrades to zero instead of throwing for the summary badge', async () => {
      repo.count.mockRejectedValue(new Error('db down'));

      await expect(fiscalPeriodService.countActiveFiscalPeriods({}, USER)).resolves.toBe(0);
    });
  });
});
