const currencyRateService = require('@services/accounts-workspace/currency-rate.service');
const repo = require('@repositories/accounts-workspace/currency-rate.repository');
const fiscalPeriodRepo = require('@repositories/accounts-workspace/fiscal-period.repository');
const { createAuditLog } = require('@lib/audit');

jest.mock('@repositories/accounts-workspace/currency-rate.repository');
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
  id: 'cr-1',
  human_friendly_id: 'CUR0000001',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  currency_code: 'USD',
  currency_name: 'US Dollar',
  symbol: '$',
  decimal_places: 2,
  is_base_currency: false,
  rate_type: 'SPOT',
  exchange_rate: '3800.00000000',
  effective_date: new Date('2026-01-15T00:00:00.000Z'),
  source: 'Bank of Uganda',
  buy_rate: '3790.00000000',
  sell_rate: '3810.00000000',
  status: 'DRAFT',
  notes: null,
  version: 1,
  created_at: new Date('2026-01-01T00:00:00.000Z'),
  updated_at: new Date('2026-01-02T00:00:00.000Z'),
  archived_at: null,
  facility: { id: 'facility-1', human_friendly_id: 'FAC0001', name: 'Main Hospital' },
  updated_user: {
    id: 'user-1',
    human_friendly_id: 'USR0001',
    profile: { first_name: 'Ada', last_name: 'Byron' },
  },
  ...overrides,
});

describe('currency-rate service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockReturnValue(Promise.resolve());
    repo.groupByStatus.mockResolvedValue([]);
    fiscalPeriodRepo.findFirst.mockResolvedValue(null);
  });

  describe('listCurrencyRates', () => {
    it('scopes rows to the caller tenant and facility and returns public rows', async () => {
      repo.findMany.mockResolvedValue([buildRecord()]);
      repo.count.mockResolvedValue(1);

      const result = await currencyRateService.listCurrencyRates({}, 1, 20, USER);

      expect(repo.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
        }),
        0,
        20,
        expect.any(Array)
      );
      expect(result.items[0]).toEqual(
        expect.objectContaining({
          human_friendly_id: 'CUR0000001',
          currency_code: 'USD',
          currency_name: 'US Dollar',
          base_currency: false,
          rate_type: 'SPOT',
          exchange_rate: 3800,
          buy_rate: 3790,
          sell_rate: 3810,
          updated_by: 'Ada Byron',
          currency_status: 'DRAFT',
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
        currencyRateService.listCurrencyRates({}, 1, 20, {})
      ).rejects.toMatchObject({ statusCode: 403 });
    });

    it('applies status, currency, base, and search filters', async () => {
      repo.findMany.mockResolvedValue([]);
      repo.count.mockResolvedValue(0);

      await currencyRateService.listCurrencyRates(
        {
          status: ['ACTIVE', 'DRAFT'],
          currency_code: 'usd',
          base_currency: true,
          search: 'dollar',
        },
        1,
        20,
        USER
      );

      const where = repo.findMany.mock.calls[0][0];
      expect(where.status).toEqual({ in: ['ACTIVE', 'DRAFT'] });
      expect(where.currency_code).toBe('USD');
      expect(where.is_base_currency).toBe(true);
      expect(where.OR).toEqual(
        expect.arrayContaining([{ currency_name: { contains: 'dollar' } }])
      );
    });

    it('accepts a comma-separated status string from the shared work-items route', async () => {
      repo.findMany.mockResolvedValue([]);
      repo.count.mockResolvedValue(0);

      await currencyRateService.listCurrencyRates(
        { status: 'active,archived' },
        1,
        20,
        USER
      );

      expect(repo.findMany.mock.calls[0][0].status).toEqual({
        in: ['ACTIVE', 'ARCHIVED'],
      });
    });

    it('filters an inclusive effective-date range', async () => {
      repo.findMany.mockResolvedValue([]);
      repo.count.mockResolvedValue(0);

      await currencyRateService.listCurrencyRates(
        { from: '2026-01-01', to: '2026-01-31' },
        1,
        20,
        USER
      );

      const where = repo.findMany.mock.calls[0][0];
      expect(where.effective_date.gte).toBeInstanceOf(Date);
      expect(where.effective_date.lte).toBeInstanceOf(Date);
    });

    it('maps a known sort key and ignores an unknown one', async () => {
      repo.findMany.mockResolvedValue([]);
      repo.count.mockResolvedValue(0);

      await currencyRateService.listCurrencyRates(
        {},
        1,
        20,
        USER,
        'currency_status',
        'asc'
      );
      expect(repo.findMany.mock.calls[0][3][0]).toEqual({ status: 'asc' });

      await currencyRateService.listCurrencyRates(
        {},
        1,
        20,
        USER,
        'drop table',
        'asc'
      );
      expect(repo.findMany.mock.calls[1][3][0]).toEqual({
        effective_date: 'desc',
      });
    });
  });

  describe('getCurrencyRate', () => {
    it('returns 404 when the record is outside the caller scope', async () => {
      repo.findFirst.mockResolvedValue(null);

      await expect(
        currencyRateService.getCurrencyRate('CUR0000001', {}, USER)
      ).rejects.toMatchObject({
        statusCode: 404,
        message: 'errors.accounts.currency_rate.not_found',
      });
    });
  });

  describe('createCurrencyRate', () => {
    const payload = {
      currency_code: 'usd',
      currency_name: 'US Dollar',
      symbol: '$',
      decimal_places: 2,
      exchange_rate: 3800,
      effective_date: '2026-01-15T00:00:00.000Z',
    };

    it('assigns the safe initial status, uppercases the code, and audits', async () => {
      repo.findFirst
        .mockResolvedValueOnce(null) // duplicate check
        .mockResolvedValueOnce(buildRecord()); // reload
      repo.create.mockResolvedValue(buildRecord());

      const result = await currencyRateService.createCurrencyRate(
        payload,
        USER,
        '127.0.0.1'
      );

      expect(repo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          currency_code: 'USD',
          rate_type: 'SPOT',
          status: 'DRAFT',
          created_by: 'user-1',
        })
      );
      expect(result.currency_status).toBe('DRAFT');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'CREATE',
          entity: 'accounts_currency_rate',
        })
      );
    });

    it('rejects a duplicate currency, rate type, and effective date', async () => {
      repo.findFirst.mockResolvedValueOnce(buildRecord());

      await expect(
        currencyRateService.createCurrencyRate(payload, USER)
      ).rejects.toMatchObject({
        statusCode: 409,
        message: 'errors.accounts.currency_rate.duplicate',
      });
      expect(repo.create).not.toHaveBeenCalled();
    });

    it('forces the base currency rate to parity', async () => {
      repo.findFirst
        .mockResolvedValueOnce(null) // duplicate
        .mockResolvedValueOnce(null) // existing base
        .mockResolvedValueOnce(buildRecord({ is_base_currency: true }));
      repo.create.mockResolvedValue(buildRecord({ is_base_currency: true }));

      await currencyRateService.createCurrencyRate(
        { ...payload, is_base_currency: true, exchange_rate: 42 },
        USER
      );

      expect(repo.create.mock.calls[0][0].exchange_rate).toBe(1);
    });

    it('rejects a second base currency in the same scope', async () => {
      repo.findFirst
        .mockResolvedValueOnce(null) // duplicate
        .mockResolvedValueOnce(buildRecord({ currency_code: 'UGX', is_base_currency: true }));

      await expect(
        currencyRateService.createCurrencyRate(
          { ...payload, is_base_currency: true, exchange_rate: 1 },
          USER
        )
      ).rejects.toMatchObject({
        statusCode: 409,
        message: 'errors.accounts.currency_rate.base_exists',
      });
      expect(repo.create).not.toHaveBeenCalled();
    });

    it('blocks a rate dated inside a locked fiscal period', async () => {
      repo.findFirst.mockResolvedValueOnce(null);
      fiscalPeriodRepo.findFirst.mockResolvedValueOnce({ id: 'fp-1' });

      await expect(
        currencyRateService.createCurrencyRate(payload, USER)
      ).rejects.toMatchObject({
        statusCode: 409,
        message: 'errors.accounts.currency_rate.period_locked',
      });
      expect(repo.create).not.toHaveBeenCalled();
    });
  });

  describe('updateCurrencyRate', () => {
    it('returns 409 when the submitted version is stale', async () => {
      repo.findFirst.mockResolvedValueOnce(buildRecord({ version: 3 }));

      await expect(
        currencyRateService.updateCurrencyRate(
          'CUR0000001',
          { currency_name: 'Renamed', version: 2 },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 409, message: 'errors.conflict' });
      expect(repo.updateWithVersion).not.toHaveBeenCalled();
    });

    it('blocks edits on an archived record', async () => {
      repo.findFirst.mockResolvedValueOnce(buildRecord({ status: 'ARCHIVED' }));

      await expect(
        currencyRateService.updateCurrencyRate(
          'CUR0000001',
          { currency_name: 'x' },
          USER
        )
      ).rejects.toMatchObject({
        statusCode: 409,
        message: 'errors.accounts.currency_rate.not_editable',
      });
    });

    it('rejects a buy rate above the sell rate', async () => {
      repo.findFirst.mockResolvedValueOnce(buildRecord());

      await expect(
        currencyRateService.updateCurrencyRate(
          'CUR0000001',
          { buy_rate: 4000 },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 400 });
    });

    it('blocks an edit whose effective date sits in a locked period', async () => {
      repo.findFirst.mockResolvedValueOnce(buildRecord());
      fiscalPeriodRepo.findFirst.mockResolvedValueOnce({ id: 'fp-1' });

      await expect(
        currencyRateService.updateCurrencyRate(
          'CUR0000001',
          { currency_name: 'Renamed' },
          USER
        )
      ).rejects.toMatchObject({
        statusCode: 409,
        message: 'errors.accounts.currency_rate.period_locked',
      });
    });

    it('persists the patch and audits the change', async () => {
      repo.findFirst.mockResolvedValueOnce(buildRecord());
      repo.updateWithVersion.mockResolvedValue(
        buildRecord({ currency_name: 'United States Dollar', version: 2 })
      );

      const result = await currencyRateService.updateCurrencyRate(
        'CUR0000001',
        { currency_name: 'United States Dollar' },
        USER,
        '127.0.0.1'
      );

      expect(repo.updateWithVersion).toHaveBeenCalledWith(
        'cr-1',
        1,
        expect.objectContaining({
          currency_name: 'United States Dollar',
          updated_by: 'user-1',
        })
      );
      expect(result.currency_name).toBe('United States Dollar');
      expect(result.version).toBe(2);
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'UPDATE',
          entity: 'accounts_currency_rate',
        })
      );
    });

    it('returns 409 when the row changed between read and write', async () => {
      repo.findFirst.mockResolvedValueOnce(buildRecord());
      repo.updateWithVersion.mockResolvedValue(null);

      await expect(
        currencyRateService.updateCurrencyRate(
          'CUR0000001',
          { currency_name: 'x' },
          USER
        )
      ).rejects.toMatchObject({ statusCode: 409, message: 'errors.conflict' });
    });
  });

  describe('applyCurrencyRateAction', () => {
    it('activates a draft record', async () => {
      repo.findFirst
        .mockResolvedValueOnce(buildRecord({ status: 'DRAFT' }))
        .mockResolvedValueOnce(null); // base uniqueness
      repo.updateWithVersion.mockResolvedValue(
        buildRecord({ status: 'ACTIVE', version: 2 })
      );

      const result = await currencyRateService.applyCurrencyRateAction(
        'CUR0000001',
        'activate',
        {},
        USER,
        '127.0.0.1'
      );

      expect(result.currency_status).toBe('ACTIVE');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({ action: 'ACTIVATE' })
      );
    });

    it('rejects a transition the status model does not allow', async () => {
      repo.findFirst.mockResolvedValueOnce(buildRecord({ status: 'DRAFT' }));

      await expect(
        currencyRateService.applyCurrencyRateAction(
          'CUR0000001',
          'deactivate',
          {},
          USER
        )
      ).rejects.toMatchObject({
        statusCode: 409,
        message: 'errors.accounts.currency_rate.invalid_transition',
      });
      expect(repo.updateWithVersion).not.toHaveBeenCalled();
    });

    it('refuses to retire the base currency', async () => {
      repo.findFirst.mockResolvedValueOnce(
        buildRecord({ status: 'ACTIVE', is_base_currency: true })
      );

      await expect(
        currencyRateService.applyCurrencyRateAction(
          'CUR0000001',
          'archive',
          {},
          USER
        )
      ).rejects.toMatchObject({
        statusCode: 409,
        message: 'errors.accounts.currency_rate.base_in_use',
      });
    });

    it('archives without hard deleting and stamps archived_at', async () => {
      repo.findFirst.mockResolvedValueOnce(buildRecord({ status: 'ACTIVE' }));
      repo.updateWithVersion.mockResolvedValue(
        buildRecord({ status: 'ARCHIVED', version: 2 })
      );

      await currencyRateService.applyCurrencyRateAction(
        'CUR0000001',
        'archive',
        { reason: 'Superseded' },
        USER
      );

      const patch = repo.updateWithVersion.mock.calls[0][2];
      expect(patch.status).toBe('ARCHIVED');
      expect(patch.archived_at).toBeInstanceOf(Date);
      expect(patch.deleted_at).toBeUndefined();
    });

    it('restores an archived record back to active', async () => {
      repo.findFirst
        .mockResolvedValueOnce(buildRecord({ status: 'ARCHIVED' }))
        .mockResolvedValueOnce(null);
      repo.updateWithVersion.mockResolvedValue(
        buildRecord({ status: 'ACTIVE', version: 2 })
      );

      await currencyRateService.applyCurrencyRateAction(
        'CUR0000001',
        'restore',
        {},
        USER
      );

      const patch = repo.updateWithVersion.mock.calls[0][2];
      expect(patch.status).toBe('ACTIVE');
      expect(patch.archived_at).toBeNull();
    });

    it('carries the reason into the audit event', async () => {
      repo.findFirst.mockResolvedValueOnce(buildRecord({ status: 'ACTIVE' }));
      repo.updateWithVersion.mockResolvedValue(
        buildRecord({ status: 'INACTIVE', version: 2 })
      );

      await currencyRateService.applyCurrencyRateAction(
        'CUR0000001',
        'deactivate',
        { reason: 'Stale quote' },
        USER
      );

      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'DEACTIVATE',
          diff: expect.objectContaining({ reason: 'Stale quote' }),
        })
      );
    });

    it('rejects an unknown action', async () => {
      await expect(
        currencyRateService.applyCurrencyRateAction(
          'CUR0000001',
          'purge',
          {},
          USER
        )
      ).rejects.toMatchObject({ statusCode: 400 });
    });
  });

  describe('countActiveCurrencyRates', () => {
    it('counts only active rows in scope', async () => {
      repo.count.mockResolvedValue(7);

      const total = await currencyRateService.countActiveCurrencyRates({}, USER);

      expect(total).toBe(7);
      expect(repo.count).toHaveBeenCalledWith(
        expect.objectContaining({ status: 'ACTIVE', tenant_id: 'tenant-1' })
      );
    });

    it('degrades to zero instead of throwing for the summary badge', async () => {
      repo.count.mockRejectedValue(new Error('db down'));

      await expect(
        currencyRateService.countActiveCurrencyRates({}, USER)
      ).resolves.toBe(0);
    });
  });
});
