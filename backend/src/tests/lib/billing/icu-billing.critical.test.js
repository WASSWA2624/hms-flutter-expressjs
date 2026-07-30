/**
 * ICU stay billing helpers (Critical / Active stay start).
 *
 * @module tests/lib/billing/icu-billing.critical
 */

const {
  shouldApplyClinicalRequestBilling,
  BILLABLE_SOURCE_MODULES,
} = require('@lib/billing/clinical-request-billing');
const {
  buildIcuStayBilling,
  ICU_STAY_START_CHARGE_KEY,
} = require('@lib/billing/icu-billing');

describe('icu-billing (Critical alerts tab)', () => {
  it('facility package + bed-day posts PENDING (create-charge / defer settle)', () => {
    const billing = buildIcuStayBilling({
      facility: {
        extension_json: {
          billing: {
            critical_care_package_fee: 400,
            icu_bed_day_fee: 100,
            currency: 'USD',
          },
        },
      },
    });

    expect(shouldApplyClinicalRequestBilling(billing)).toBe(true);
    expect(billing.payment_status).toBe('PENDING');
    expect(billing.line_items).toHaveLength(2);
    expect(billing.line_items).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ id: 'icu-critical-care-package' }),
        expect.objectContaining({ id: 'icu-bed-day' }),
      ])
    );
  });

  it('returns null when no fee configured (NOT_REQUIRED — no orphan invoice)', () => {
    expect(buildIcuStayBilling({})).toBeNull();
    expect(
      buildIcuStayBilling({
        facility: { extension_json: { billing: {} } },
      })
    ).toBeNull();
  });

  it('prefers explicit caller billing line items', () => {
    const billing = buildIcuStayBilling({
      facility: {
        extension_json: {
          billing: { critical_care_package_fee: 999, currency: 'USD' },
        },
      },
      billing: {
        payment_status: 'PENDING',
        currency: 'UGX',
        line_items: [
          {
            id: 'custom',
            label: 'Custom ICU package',
            quantity: 1,
            unit_price: '90.00',
            line_total: '90.00',
          },
        ],
      },
    });
    expect(billing.currency).toBe('UGX');
    expect(billing.line_items[0].id).toBe('custom');
  });

  it('ICU_STAY source module + charge key support idempotent stay start', () => {
    expect(BILLABLE_SOURCE_MODULES.ICU_STAY).toBe('ICU_STAY');
    expect(ICU_STAY_START_CHARGE_KEY).toBe('ICU_STAY_START');
  });
});
