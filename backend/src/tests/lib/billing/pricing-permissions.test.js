const {
  assertPharmacyRetailPriceMutationAllowed,
  assertFacilityTariffMutationAllowed,
  assertPriceBookBillingEntityWrite,
} = require('@lib/billing/pricing-permissions');
const { PERMISSIONS } = require('@config/permissions');
const { HttpError } = require('@lib/errors');

jest.mock('@middlewares/auth.middleware', () => ({
  getUserPermissions: jest.fn(),
}));

const { getUserPermissions } = require('@middlewares/auth.middleware');

describe('pricing-permissions', () => {
  beforeEach(() => {
    getUserPermissions.mockReset();
  });

  it('allows pharmacy retail mutation when pricing:pharmacy_write is granted', () => {
    getUserPermissions.mockReturnValue([PERMISSIONS.PRICING_PHARMACY_WRITE]);
    expect(() =>
      assertPharmacyRetailPriceMutationAllowed(
        { id: 'u1' },
        { unit_price: 10, currency: 'UGX' }
      )
    ).not.toThrow();
  });

  it('rejects pharmacy retail mutation without pricing:pharmacy_write', () => {
    getUserPermissions.mockReturnValue([PERMISSIONS.PHARMACY_WRITE]);
    expect(() =>
      assertPharmacyRetailPriceMutationAllowed({ id: 'u1' }, { unit_price: 10 })
    ).toThrow(HttpError);
  });

  it('allows identity updates that omit pharmacy price fields', () => {
    getUserPermissions.mockReturnValue([PERMISSIONS.PHARMACY_WRITE]);
    expect(() =>
      assertPharmacyRetailPriceMutationAllowed(
        { id: 'u1' },
        { name: 'Paracetamol', form: 'Tablet' }
      )
    ).not.toThrow();
  });

  it('rejects pharmacy buy/transfer mutation without pricing:pharmacy_write', () => {
    getUserPermissions.mockReturnValue([PERMISSIONS.PHARMACY_WRITE]);
    expect(() =>
      assertPharmacyRetailPriceMutationAllowed(
        { id: 'u1' },
        { buy_unit_price: 5 }
      )
    ).toThrow(HttpError);
    expect(() =>
      assertPharmacyRetailPriceMutationAllowed(
        { id: 'u1' },
        { transfer_unit_price: 8 }
      )
    ).toThrow(HttpError);
  });

  it('allows pharmacy buy and transfer when pricing:pharmacy_write is granted', () => {
    getUserPermissions.mockReturnValue([PERMISSIONS.PRICING_PHARMACY_WRITE]);
    expect(() =>
      assertPharmacyRetailPriceMutationAllowed(
        { id: 'u1' },
        { buy_unit_price: 5, transfer_unit_price: 8, unit_price: 12 }
      )
    ).not.toThrow();
  });

  it('rejects facility tariff mutation without pricing:facility_write', () => {
    getUserPermissions.mockReturnValue([PERMISSIONS.BILLING_WRITE]);
    expect(() =>
      assertFacilityTariffMutationAllowed({ id: 'u1' }, { unit_price: 20 })
    ).toThrow(HttpError);
  });

  it('allows shelf-only facility offering updates without pricing write', () => {
    getUserPermissions.mockReturnValue([PERMISSIONS.PHARMACY_WRITE]);
    expect(() =>
      assertFacilityTariffMutationAllowed(
        { id: 'u1' },
        { default_storage_shelf_id: 'shelf-1' }
      )
    ).not.toThrow();
  });

  it('gates price-book writes by billing_entity', () => {
    getUserPermissions.mockReturnValue([PERMISSIONS.PRICING_FACILITY_WRITE]);
    expect(() =>
      assertPriceBookBillingEntityWrite({ id: 'u1' }, 'FACILITY')
    ).not.toThrow();
    expect(() =>
      assertPriceBookBillingEntityWrite({ id: 'u1' }, 'PHARMACY')
    ).toThrow(HttpError);

    getUserPermissions.mockReturnValue([PERMISSIONS.PRICING_PHARMACY_WRITE]);
    expect(() =>
      assertPriceBookBillingEntityWrite({ id: 'u1' }, 'PHARMACY')
    ).not.toThrow();
  });
});
