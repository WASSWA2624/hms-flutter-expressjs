/**
 * Unit tests for IPD admission start / bed-assign / transfer billing helpers.
 */

jest.mock('@lib/billing/clinical-request-billing', () => {
  const actual = jest.requireActual('@lib/billing/clinical-request-billing');
  return {
    ...actual,
  };
});

const {
  buildAdmissionBilling,
  buildBedDayBilling,
  buildBedTransferBilling,
  admissionSnapshotHasBedCharge,
  ADMISSION_START_CHARGE_KEY,
  BED_ASSIGN_CHARGE_KEY,
} = require('@lib/billing/admission-billing');

describe('admission-billing', () => {
  it('returns null when no payload and no facility fee', () => {
    expect(
      buildAdmissionBilling({
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
          id: 'ADMISSION_FEE',
          label: 'Admission fee',
          quantity: 1,
          unit_price: '100.00',
          line_total: '100.00',
        },
      ],
    };
    const resolved = buildAdmissionBilling({ billing });
    expect(resolved).toEqual(
      expect.objectContaining({
        payment_status: 'PENDING',
        total_amount: expect.any(String),
      })
    );
    expect(ADMISSION_START_CHARGE_KEY).toBe('ADMISSION_START');
    expect(BED_ASSIGN_CHARGE_KEY).toBe('BED_ASSIGN');
  });

  it('builds fee + deposit + bed/day lines from facility fees', () => {
    const resolved = buildAdmissionBilling({
      facility: {
        extension_json: {
          billing: {
            admission_fee: 80000,
            admission_deposit: 20000,
            bed_day_fee: 50000,
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
        expect.objectContaining({ id: 'admission-fee' }),
        expect.objectContaining({ id: 'admission-deposit' }),
        expect.objectContaining({ id: 'bed-day' }),
      ])
    );
  });

  it('does not treat NOT_BILLED request as a charge (falls back to facility)', () => {
    const resolved = buildAdmissionBilling({
      billing: {
        payment_status: 'NOT_BILLED',
        total_amount: '0.00',
      },
      facility: {
        extension_json: {
          billing: { admission_fee: 80, currency: 'USD' },
        },
      },
    });
    expect(resolved.line_items[0].id).toBe('admission-fee');
  });

  it('buildBedDayBilling posts bed/day only for assign-bed', () => {
    const resolved = buildBedDayBilling({
      facility: {
        extension_json: {
          billing: { bed_day_fee: 55, currency: 'USD' },
        },
      },
    });
    expect(resolved.line_items).toHaveLength(1);
    expect(resolved.line_items[0].id).toBe('bed-day');
  });

  it('buildBedTransferBilling is null when ward rates match', () => {
    expect(
      buildBedTransferBilling({
        facility: {
          extension_json: {
            billing: { bed_day_fee: 50, currency: 'USD' },
          },
        },
        fromWardType: 'GENERAL',
        toWardType: 'GENERAL',
      })
    ).toBeNull();
  });

  it('admissionSnapshotHasBedCharge treats NOT_REQUIRED as uncharged', () => {
    expect(
      admissionSnapshotHasBedCharge({
        payment_status: 'NOT_REQUIRED',
        audit_code: 'ADMISSION_REQUEST_NO_CHARGE',
      })
    ).toBe(false);
  });
});
