/**
 * Unit tests for ICU stay billing helpers (All / Active ICU start-stay fees).
 */

jest.mock('@lib/billing/clinical-request-billing', () => {
  const actual = jest.requireActual('@lib/billing/clinical-request-billing');
  return {
    ...actual,
  };
});

const {
  buildIcuStayBilling,
  ICU_STAY_START_CHARGE_KEY,
} = require('@lib/billing/icu-billing');

describe('icu-billing', () => {
  it('returns null when no payload and no facility fee', () => {
    expect(
      buildIcuStayBilling({
        facility: { extension_json: { billing: { currency: 'UGX' } } },
      })
    ).toBeNull();
  });

  it('prefers explicit PENDING billing payload', () => {
    const billing = {
      payment_status: 'PENDING',
      currency: 'UGX',
      total_amount: '100.00',
      line_items: [
        {
          id: 'ICU_CRITICAL_CARE_PACKAGE',
          label: 'ICU critical-care package',
          quantity: 1,
          unit_price: '100.00',
          line_total: '100.00',
        },
      ],
    };
    const resolved = buildIcuStayBilling({ billing });
    expect(resolved).toEqual(
      expect.objectContaining({
        payment_status: 'PENDING',
        total_amount: expect.any(String),
      })
    );
    expect(ICU_STAY_START_CHARGE_KEY).toBe('ICU_STAY_START');
  });

  it('builds package + bed/day lines from facility fees', () => {
    const resolved = buildIcuStayBilling({
      facility: {
        extension_json: {
          billing: {
            icu_critical_care_package_fee: 150000,
            icu_bed_day_fee: 50000,
            currency: 'UGX',
          },
        },
      },
    });

    expect(resolved).toEqual(
      expect.objectContaining({
        payment_status: 'PENDING',
        currency: 'UGX',
      })
    );
    expect(resolved.line_items).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ id: 'icu-critical-care-package' }),
        expect.objectContaining({ id: 'icu-bed-day' }),
      ])
    );
  });

  it('does not treat NOT_BILLED request as a charge (falls back to facility)', () => {
    const resolved = buildIcuStayBilling({
      billing: {
        payment_status: 'NOT_BILLED',
        total_amount: '0.00',
      },
      facility: {
        extension_json: {
          billing: { icu_package_fee: 80, currency: 'USD' },
        },
      },
    });
    expect(resolved.line_items[0].id).toBe('icu-critical-care-package');
  });
});
