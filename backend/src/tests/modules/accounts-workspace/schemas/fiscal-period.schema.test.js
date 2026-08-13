const {
  fiscalPeriodsQuerySchema,
  fiscalPeriodActionParamsSchema,
  createFiscalPeriodSchema,
  updateFiscalPeriodSchema,
  fiscalPeriodActionSchema,
} = require('@validations/accounts-workspace/fiscal-period.schema');

const validCreate = {
  fiscal_year: 'FY2026',
  period_no: 1,
  period_name: 'January 2026',
  start_date: '2026-01-01T00:00:00.000Z',
  end_date: '2026-01-31T00:00:00.000Z',
};

describe('fiscal-period schemas', () => {
  describe('fiscalPeriodsQuerySchema', () => {
    it('parses a comma-separated status multi-select and drops unknown values', () => {
      const parsed = fiscalPeriodsQuerySchema.parse({
        status: 'active, archived, nonsense',
      });
      expect(parsed.status).toEqual(['ACTIVE', 'ARCHIVED']);
    });

    it('leaves status undefined when no valid value is supplied', () => {
      expect(fiscalPeriodsQuerySchema.parse({ status: 'nonsense' }).status).toBeUndefined();
      expect(fiscalPeriodsQuerySchema.parse({}).status).toBeUndefined();
    });

    it('rejects an unparseable date range boundary', () => {
      expect(() => fiscalPeriodsQuerySchema.parse({ from: 'not-a-date' })).toThrow();
    });
  });

  describe('fiscalPeriodActionParamsSchema', () => {
    it.each(['activate', 'deactivate', 'archive', 'restore'])(
      'accepts the %s action',
      (action) => {
        expect(
          fiscalPeriodActionParamsSchema.parse({
            fiscalPeriodIdentifier: 'FIS0000001',
            action,
          }).action
        ).toBe(action);
      }
    );

    it('rejects an action outside the workflow contract', () => {
      expect(() =>
        fiscalPeriodActionParamsSchema.parse({
          fiscalPeriodIdentifier: 'FIS0000001',
          action: 'delete',
        })
      ).toThrow();
    });
  });

  describe('createFiscalPeriodSchema', () => {
    it('accepts a well-formed payload', () => {
      const parsed = createFiscalPeriodSchema.parse(validCreate);
      expect(parsed.period_no).toBe(1);
      expect(parsed.period_name).toBe('January 2026');
    });

    it('requires the identifying fields', () => {
      expect(() => createFiscalPeriodSchema.parse({})).toThrow();
    });

    it('rejects an end date before the start date', () => {
      expect(() =>
        createFiscalPeriodSchema.parse({
          ...validCreate,
          end_date: '2025-12-01T00:00:00.000Z',
        })
      ).toThrow(/end_before_start/);
    });

    it('rejects close milestones that run out of order', () => {
      expect(() =>
        createFiscalPeriodSchema.parse({
          ...validCreate,
          soft_close_date: '2026-02-10T00:00:00.000Z',
          close_date: '2026-02-01T00:00:00.000Z',
        })
      ).toThrow(/milestone_out_of_order/);
    });

    it('rejects a period number outside the calendar range', () => {
      expect(() =>
        createFiscalPeriodSchema.parse({ ...validCreate, period_no: 0 })
      ).toThrow();
      expect(() =>
        createFiscalPeriodSchema.parse({ ...validCreate, period_no: 400 })
      ).toThrow();
    });
  });

  describe('updateFiscalPeriodSchema', () => {
    it('allows a partial patch carrying the optimistic version', () => {
      const parsed = updateFiscalPeriodSchema.parse({
        period_name: 'Renamed',
        version: 3,
      });
      expect(parsed).toEqual({ period_name: 'Renamed', version: 3 });
    });

    it('still enforces date ordering on a partial patch', () => {
      expect(() =>
        updateFiscalPeriodSchema.parse({
          start_date: '2026-03-01T00:00:00.000Z',
          end_date: '2026-02-01T00:00:00.000Z',
        })
      ).toThrow(/end_before_start/);
    });
  });

  describe('fiscalPeriodActionSchema', () => {
    it('accepts an audit reason and version', () => {
      expect(fiscalPeriodActionSchema.parse({ reason: 'Superseded', version: 2 })).toEqual(
        { reason: 'Superseded', version: 2 }
      );
    });

    it('accepts an empty body', () => {
      expect(fiscalPeriodActionSchema.parse({})).toEqual({});
    });
  });
});
