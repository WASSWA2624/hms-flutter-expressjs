jest.mock('@prisma/client', () => ({
  drug: { findFirst: jest.fn() },
  facility_pharmacy_offering: { findFirst: jest.fn() },
  scheme_offer: { findMany: jest.fn() },
  coverage_plan: { findFirst: jest.fn() },
  price_book_entry: { findMany: jest.fn() },
}));

const prisma = require('@prisma/client');
const { resolveUnitPrice } = require('@lib/billing/price-resolver');

describe('price-resolver drug pharmacy vs facility sync', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    prisma.scheme_offer.findMany.mockResolvedValue([]);
    prisma.coverage_plan.findFirst.mockResolvedValue(null);
    prisma.price_book_entry.findMany.mockResolvedValue([]);
  });

  it('resolves PHARMACY from drug.unit_price (external sell)', async () => {
    prisma.drug.findFirst.mockResolvedValue({
      id: 'drug-1',
      unit_price: 2050,
      currency: 'UGX',
    });

    const price = await resolveUnitPrice({
      catalogType: 'DRUG',
      catalogItemId: 'drug-1',
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      billingEntity: 'PHARMACY',
    });

    expect(price).toMatchObject({
      unitPrice: '2050.00',
      source: 'CATALOG',
      priceSource: 'PHARMACY',
    });
    expect(prisma.facility_pharmacy_offering.findFirst).not.toHaveBeenCalled();
  });

  it('resolves FACILITY from facility offering and does not use pharmacy sell', async () => {
    prisma.drug.findFirst.mockResolvedValue({
      id: 'drug-1',
      unit_price: 2050,
      currency: 'UGX',
    });
    prisma.facility_pharmacy_offering.findFirst.mockResolvedValue({
      unit_price: 2600,
      currency: 'UGX',
    });

    const price = await resolveUnitPrice({
      catalogType: 'DRUG',
      catalogItemId: 'DRG-1',
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      billingEntity: 'FACILITY',
    });

    expect(price).toMatchObject({
      unitPrice: '2600.00',
      source: 'FACILITY_OFFERING',
      priceSource: 'FACILITY',
    });
  });

  it('does not fall back to pharmacy sell when FACILITY offering is missing', async () => {
    prisma.drug.findFirst.mockResolvedValue({
      id: 'drug-1',
      unit_price: 2050,
      currency: 'UGX',
    });
    prisma.facility_pharmacy_offering.findFirst.mockResolvedValue(null);

    const price = await resolveUnitPrice({
      catalogType: 'DRUG',
      catalogItemId: 'drug-1',
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      billingEntity: 'FACILITY',
    });

    expect(price.unitPrice).toBeNull();
    expect(price.source).toBe('UNRESOLVED');
  });
});
