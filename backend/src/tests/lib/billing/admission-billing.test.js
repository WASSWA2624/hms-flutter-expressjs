/**
 * Unit tests for admission + bed-transfer billing helpers.
 */

const {
  buildAdmissionBilling,
  buildBedTransferBilling,
  bedTransferChargeKey,
  resolveBedDayFeeForWardType,
  ADMISSION_START_CHARGE_KEY,
  BED_TRANSFER_CHARGE_KEY_PREFIX,
} = require('@lib/billing/admission-billing');

const facilityWithRates = {
  extension_json: {
    billing: {
      bed_day_fee: 50000,
      icu_bed_day_fee: 150000,
      currency: 'UGX',
    },
  },
};

describe('admission-billing bed transfer helpers', () => {
  it('bedTransferChargeKey prefixes transfer id', () => {
    expect(bedTransferChargeKey('tr-1')).toBe(
      `${BED_TRANSFER_CHARGE_KEY_PREFIX}:tr-1`,
    );
    expect(ADMISSION_START_CHARGE_KEY).toBe('ADMISSION_START');
  });

  it('resolveBedDayFeeForWardType prefers ICU fee for ICU wards', () => {
    const icu = resolveBedDayFeeForWardType(facilityWithRates, 'ICU');
    const general = resolveBedDayFeeForWardType(facilityWithRates, 'GENERAL');
    expect(icu.amount).toBe('150000.00');
    expect(general.amount).toBe('50000.00');
  });

  it('buildBedTransferBilling posts destination rate when rates differ', () => {
    const billing = buildBedTransferBilling({
      facility: facilityWithRates,
      fromWardType: 'GENERAL',
      toWardType: 'ICU',
    });
    expect(billing).not.toBeNull();
    expect(billing.payment_status).toBe('PENDING');
    expect(billing.line_items).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: 'bed-transfer-day',
          unit_price: '150000.00',
        }),
      ]),
    );
  });

  it('buildBedTransferBilling returns null for same-rate moves', () => {
    const billing = buildBedTransferBilling({
      facility: facilityWithRates,
      fromWardType: 'GENERAL',
      toWardType: 'SURGICAL',
    });
    expect(billing).toBeNull();
  });

  it('buildBedTransferBilling prefers explicit billing payload', () => {
    const billing = buildBedTransferBilling({
      billing: {
        payment_status: 'PENDING',
        currency: 'UGX',
        total_amount: '20000.00',
        line_items: [
          {
            id: 'override',
            label: 'Override',
            quantity: 1,
            unit_price: '20000.00',
            line_total: '20000.00',
          },
        ],
      },
      facility: facilityWithRates,
      fromWardType: 'GENERAL',
      toWardType: 'GENERAL',
    });
    expect(billing).not.toBeNull();
    expect(billing.total_amount).toBe('20000.00');
  });

  it('buildAdmissionBilling still builds start fee lines', () => {
    const billing = buildAdmissionBilling({
      facility: {
        extension_json: {
          billing: {
            admission_fee: 10000,
            bed_day_fee: 50000,
            currency: 'UGX',
          },
        },
      },
    });
    expect(billing).not.toBeNull();
    expect(billing.line_items.length).toBeGreaterThanOrEqual(2);
  });
});
