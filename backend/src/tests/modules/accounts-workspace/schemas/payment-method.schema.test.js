const {
  PAYMENT_METHOD_STATUSES,
  PAYMENT_METHOD_ACTIONS,
  PAYMENT_METHOD_TYPES,
  PAYMENT_METHOD_DIRECTIONS,
  paymentMethodsQuerySchema,
  paymentMethodIdentifierParamsSchema,
  paymentMethodActionParamsSchema,
  createPaymentMethodSchema,
  updatePaymentMethodSchema,
  paymentMethodActionSchema,
} = require('@validations/accounts-workspace/payment-method.schema');

const validCreate = {
  method_code: 'MOMO',
  method_name: 'Mobile Money',
  method_type: 'MOBILE_MONEY',
  direction: 'INCOMING',
};

describe('payment-method schemas', () => {
  it('exposes the documented status model and actions', () => {
    expect(PAYMENT_METHOD_STATUSES).toEqual([
      'DRAFT',
      'ACTIVE',
      'INACTIVE',
      'ARCHIVED',
    ]);
    expect(PAYMENT_METHOD_ACTIONS).toEqual([
      'activate',
      'deactivate',
      'archive',
      'restore',
    ]);
    expect(PAYMENT_METHOD_DIRECTIONS).toEqual([
      'INCOMING',
      'OUTGOING',
      'BOTH',
    ]);
  });

  it('mirrors the canonical PaymentMethodType taxonomy exactly', () => {
    // Guards against this tab drifting into a second tender taxonomy.
    expect(PAYMENT_METHOD_TYPES).toEqual([
      'CASH',
      'CREDIT_CARD',
      'DEBIT_CARD',
      'PREPAID_CARD',
      'GIFT_CARD',
      'VOUCHER',
      'BANK_CHECK',
      'MOBILE_MONEY',
      'BANK_TRANSFER',
      'INSURANCE',
      'OTHER',
    ]);
  });

  describe('paymentMethodsQuerySchema', () => {
    it('parses comma-separated status and type multi-selects', () => {
      const parsed = paymentMethodsQuerySchema.parse({
        status: 'ACTIVE, draft',
        method_type: 'cash,MOBILE_MONEY',
      });
      expect(parsed.status).toEqual(['ACTIVE', 'DRAFT']);
      expect(parsed.method_type).toEqual(['CASH', 'MOBILE_MONEY']);
    });

    it('drops values outside the canonical taxonomy', () => {
      const parsed = paymentMethodsQuerySchema.parse({ method_type: 'CRYPTO' });
      expect(parsed.method_type).toBeUndefined();
    });

    it('coerces the boolean flag filters', () => {
      const parsed = paymentMethodsQuerySchema.parse({
        requires_external_reference: 'true',
        requires_approval: '0',
      });
      expect(parsed.requires_external_reference).toBe(true);
      expect(parsed.requires_approval).toBe(false);
    });

    it('rejects a non-boolean flag value', () => {
      expect(() =>
        paymentMethodsQuerySchema.parse({ requires_approval: 'maybe' })
      ).toThrow();
    });

    it('rejects an unparseable date boundary', () => {
      expect(() =>
        paymentMethodsQuerySchema.parse({ from: 'not-a-date' })
      ).toThrow();
    });
  });

  describe('createPaymentMethodSchema', () => {
    it('accepts a minimal valid payload', () => {
      expect(() => createPaymentMethodSchema.parse(validCreate)).not.toThrow();
    });

    it.each(['method_code', 'method_name', 'method_type', 'direction'])(
      'requires %s',
      (field) => {
        const payload = { ...validCreate };
        delete payload[field];
        expect(() => createPaymentMethodSchema.parse(payload)).toThrow();
      }
    );

    it('rejects a method type outside the canonical taxonomy', () => {
      expect(() =>
        createPaymentMethodSchema.parse({
          ...validCreate,
          method_type: 'CRYPTO',
        })
      ).toThrow();
    });

    it('rejects an unknown direction', () => {
      expect(() =>
        createPaymentMethodSchema.parse({
          ...validCreate,
          direction: 'SIDEWAYS',
        })
      ).toThrow();
    });

    it('rejects an effective window that ends before it starts', () => {
      expect(() =>
        createPaymentMethodSchema.parse({
          ...validCreate,
          effective_from: '2026-06-01T00:00:00.000Z',
          effective_to: '2026-01-01T00:00:00.000Z',
        })
      ).toThrow(/effective_to_before_from/);
    });

    it('accepts an open-ended effective window', () => {
      expect(() =>
        createPaymentMethodSchema.parse({
          ...validCreate,
          effective_from: '2026-01-01T00:00:00.000Z',
          effective_to: null,
        })
      ).not.toThrow();
    });

    it('enforces the documented length limits', () => {
      expect(() =>
        createPaymentMethodSchema.parse({
          ...validCreate,
          method_code: 'X'.repeat(33),
        })
      ).toThrow();
      expect(() =>
        createPaymentMethodSchema.parse({
          ...validCreate,
          method_name: 'X'.repeat(161),
        })
      ).toThrow();
    });

    it('requires an explicit boolean for the flag fields', () => {
      expect(() =>
        createPaymentMethodSchema.parse({
          ...validCreate,
          requires_approval: 'yes',
        })
      ).toThrow();
    });

    it('does not accept a client-supplied status', () => {
      const parsed = createPaymentMethodSchema.parse({
        ...validCreate,
        status: 'ACTIVE',
      });
      expect(parsed.status).toBeUndefined();
    });
  });

  describe('updatePaymentMethodSchema', () => {
    it('allows a partial patch carrying the optimistic version', () => {
      const parsed = updatePaymentMethodSchema.parse({
        method_name: 'Renamed',
        version: 3,
      });
      expect(parsed).toMatchObject({ method_name: 'Renamed', version: 3 });
    });

    it('still enforces effective-window ordering on a patch', () => {
      expect(() =>
        updatePaymentMethodSchema.parse({
          effective_from: '2026-06-01T00:00:00.000Z',
          effective_to: '2026-01-01T00:00:00.000Z',
        })
      ).toThrow(/effective_to_before_from/);
    });

    it('rejects a version below one', () => {
      expect(() => updatePaymentMethodSchema.parse({ version: 0 })).toThrow();
    });
  });

  describe('params and action schemas', () => {
    it('accepts a human-friendly identifier', () => {
      expect(() =>
        paymentMethodIdentifierParamsSchema.parse({
          paymentMethodIdentifier: 'PMT0000001',
        })
      ).not.toThrow();
    });

    it('rejects an action outside the documented set', () => {
      expect(() =>
        paymentMethodActionParamsSchema.parse({
          paymentMethodIdentifier: 'PMT0000001',
          action: 'delete',
        })
      ).toThrow();
    });

    it.each(PAYMENT_METHOD_ACTIONS)('accepts the %s action', (action) => {
      expect(() =>
        paymentMethodActionParamsSchema.parse({
          paymentMethodIdentifier: 'PMT0000001',
          action,
        })
      ).not.toThrow();
    });

    it('caps the audit reason length', () => {
      expect(() =>
        paymentMethodActionSchema.parse({ reason: 'X'.repeat(501) })
      ).toThrow();
    });
  });
});
