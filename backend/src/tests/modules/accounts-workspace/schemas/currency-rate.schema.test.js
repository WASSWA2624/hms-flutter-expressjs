const {
  currencyRatesQuerySchema,
  currencyRateActionParamsSchema,
  createCurrencyRateSchema,
  updateCurrencyRateSchema,
  currencyRateActionSchema,
} = require('@validations/accounts-workspace/currency-rate.schema');

const validCreate = {
  currency_code: 'USD',
  currency_name: 'US Dollar',
  symbol: '$',
  decimal_places: 2,
  exchange_rate: 3800,
  effective_date: '2026-01-15T00:00:00.000Z',
};

describe('currency-rate schemas', () => {
  describe('currencyRatesQuerySchema', () => {
    it('parses a comma-separated status multi-select and drops unknown values', () => {
      const parsed = currencyRatesQuerySchema.parse({
        status: 'active, archived, nonsense',
      });
      expect(parsed.status).toEqual(['ACTIVE', 'ARCHIVED']);
    });

    it('leaves status undefined when no valid value is supplied', () => {
      expect(
        currencyRatesQuerySchema.parse({ status: 'nonsense' }).status
      ).toBeUndefined();
      expect(currencyRatesQuerySchema.parse({}).status).toBeUndefined();
    });

    it('normalizes the currency filter to upper case', () => {
      expect(
        currencyRatesQuerySchema.parse({ currency_code: 'ugx' }).currency_code
      ).toBe('UGX');
    });

    it('coerces the base-currency filter to a boolean', () => {
      expect(
        currencyRatesQuerySchema.parse({ base_currency: 'true' }).base_currency
      ).toBe(true);
      expect(
        currencyRatesQuerySchema.parse({ base_currency: 'false' }).base_currency
      ).toBe(false);
      expect(currencyRatesQuerySchema.parse({}).base_currency).toBeUndefined();
    });

    it('parses a rate-type multi-select', () => {
      expect(
        currencyRatesQuerySchema.parse({ rate_type: 'spot,monthly' }).rate_type
      ).toEqual(['SPOT', 'MONTHLY']);
    });

    it('rejects an unparseable date range boundary', () => {
      expect(() =>
        currencyRatesQuerySchema.parse({ from: 'not-a-date' })
      ).toThrow();
    });
  });

  describe('currencyRateActionParamsSchema', () => {
    it.each(['activate', 'deactivate', 'archive', 'restore'])(
      'accepts the %s action',
      (action) => {
        expect(
          currencyRateActionParamsSchema.parse({
            currencyRateIdentifier: 'CUR0000001',
            action,
          }).action
        ).toBe(action);
      }
    );

    it('rejects an action outside the workflow contract', () => {
      expect(() =>
        currencyRateActionParamsSchema.parse({
          currencyRateIdentifier: 'CUR0000001',
          action: 'delete',
        })
      ).toThrow();
    });
  });

  describe('createCurrencyRateSchema', () => {
    it('accepts a well-formed payload and upper-cases the code', () => {
      const parsed = createCurrencyRateSchema.parse({
        ...validCreate,
        currency_code: 'usd',
      });
      expect(parsed.currency_code).toBe('USD');
      expect(parsed.exchange_rate).toBe(3800);
    });

    it.each([
      ['currency_code', 'US'],
      ['currency_code', 'US1'],
      ['currency_name', ''],
      ['symbol', ''],
      ['decimal_places', 9],
      ['decimal_places', -1],
      ['exchange_rate', 0],
      ['exchange_rate', -3],
      ['effective_date', 'not-a-date'],
    ])('rejects an invalid %s of %p', (field, value) => {
      expect(() =>
        createCurrencyRateSchema.parse({ ...validCreate, [field]: value })
      ).toThrow();
    });

    it('rejects a buy rate above the sell rate', () => {
      expect(() =>
        createCurrencyRateSchema.parse({
          ...validCreate,
          buy_rate: 3900,
          sell_rate: 3810,
        })
      ).toThrow();
    });

    it('rejects a base currency quoted away from parity', () => {
      expect(() =>
        createCurrencyRateSchema.parse({
          ...validCreate,
          is_base_currency: true,
          exchange_rate: 3800,
        })
      ).toThrow();
    });

    it('accepts a base currency at parity', () => {
      expect(
        createCurrencyRateSchema.parse({
          ...validCreate,
          is_base_currency: true,
          exchange_rate: 1,
        }).exchange_rate
      ).toBe(1);
    });

    it('never accepts a client-supplied status or version', () => {
      const parsed = createCurrencyRateSchema.parse({
        ...validCreate,
        status: 'ACTIVE',
        version: 9,
      });
      expect(parsed.status).toBeUndefined();
      expect(parsed.version).toBeUndefined();
    });
  });

  describe('updateCurrencyRateSchema', () => {
    it('accepts a partial patch with an optimistic version', () => {
      const parsed = updateCurrencyRateSchema.parse({
        currency_name: 'United States Dollar',
        version: 3,
      });
      expect(parsed).toEqual({
        currency_name: 'United States Dollar',
        version: 3,
      });
    });

    it('still enforces buy/sell ordering on a patch', () => {
      expect(() =>
        updateCurrencyRateSchema.parse({ buy_rate: 10, sell_rate: 5 })
      ).toThrow();
    });
  });

  describe('currencyRateActionSchema', () => {
    it('accepts an audit reason and version', () => {
      expect(
        currencyRateActionSchema.parse({ reason: 'Stale quote', version: 2 })
      ).toEqual({ reason: 'Stale quote', version: 2 });
    });

    it('rejects an over-long reason', () => {
      expect(() =>
        currencyRateActionSchema.parse({ reason: 'x'.repeat(501) })
      ).toThrow();
    });
  });
});
