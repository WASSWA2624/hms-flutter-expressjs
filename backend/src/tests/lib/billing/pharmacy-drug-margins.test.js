const {
  pharmacyRetailMarginUnit,
  facilityPatientMarginUnit,
} = require('@lib/billing/pharmacy-drug-margins');

describe('pharmacy-drug-margins', () => {
  it('computes pharmacy retail margin when buy cost is present', () => {
    expect(
      pharmacyRetailMarginUnit({ unitPrice: 100, buyUnitPrice: 40 })
    ).toBe(60);
  });

  it('returns null pharmacy margin when buy cost is missing', () => {
    expect(
      pharmacyRetailMarginUnit({ unitPrice: 100, buyUnitPrice: null })
    ).toBeNull();
    expect(pharmacyRetailMarginUnit({ unitPrice: 100 })).toBeNull();
  });

  it('computes facility patient margin when transfer price is present', () => {
    expect(
      facilityPatientMarginUnit({
        facilityUnitPrice: 120,
        transferUnitPrice: 70,
      })
    ).toBe(50);
  });

  it('returns null facility margin when transfer is missing', () => {
    expect(
      facilityPatientMarginUnit({
        facilityUnitPrice: 120,
        transferUnitPrice: null,
      })
    ).toBeNull();
  });
});
