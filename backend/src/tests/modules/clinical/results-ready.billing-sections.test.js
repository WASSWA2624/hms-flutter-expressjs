/**
 * Clinical Results ready billing-sections scan
 *
 * Proves radiology / pharmacy / procedure create handlers post through
 * clinical-request-billing (including server-side fallbacks when clients omit
 * billing), and that pending payloads stay idempotent / PENDING for office
 * clearance.
 *
 * @module tests/modules/clinical/results-ready.billing-sections
 */

jest.mock('@lib/billing/price-resolver', () => {
  const actual = jest.requireActual('@lib/billing/price-resolver');
  return {
    ...actual,
    resolveUnitPrice: jest.fn(),
    resolveUnitPrices: jest.fn(),
  };
});

const {
  buildPendingClinicalRequestBilling,
  buildRadiologyOrderBillingFromRequest,
  buildPharmacyOrderBillingFromRequest,
  buildProcedureBillingFromRequest,
  normalizeBillingOfficeClinicalBilling,
} = require('@lib/billing/clinical-request-billing');
const { resolveUnitPrice } = require('@lib/billing/price-resolver');

// Ensure prisma catalog models exist for resolveCatalogRecord.
const prisma = require('@prisma/client');
prisma.radiology_procedure = prisma.radiology_procedure || {};
prisma.drug = prisma.drug || {};


describe('clinical Results ready billing-sections scan', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('buildRadiologyOrderBillingFromRequest posts PENDING via shared Billing', async () => {
    const prisma = require('@prisma/client');
    prisma.radiology_procedure = {
      findFirst: jest.fn().mockResolvedValue({
        id: 'rad-uuid-1',
        human_friendly_id: 'RAD-CXR',
        name: 'Chest X-Ray',
        unit_price: '55.00',
        currency: 'USD',
      }),
    };
    resolveUnitPrice.mockResolvedValue({
      unitPrice: '55.00',
      currency: 'USD',
      source: 'CATALOG',
    });

    const billing = await buildRadiologyOrderBillingFromRequest({
      radiologyTestId: 'rad-uuid-1',
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      description: 'Radiology: Chest X-Ray',
    });

    expect(billing).toEqual(
      expect.objectContaining({
        payment_status: 'PENDING',
        currency: 'USD',
        total_amount: '55.00',
      })
    );
    expect(billing.line_items).toHaveLength(1);
    expect(billing.paid_amount).toBeUndefined();
  });

  it('buildPharmacyOrderBillingFromRequest posts PENDING for priced drugs', async () => {
    const prisma = require('@prisma/client');
    prisma.drug = {
      findFirst: jest.fn().mockResolvedValue({
        id: 'drug-uuid-1',
        human_friendly_id: 'DRUG-1',
        name: 'Amoxicillin',
        unit_price: '2.50',
        currency: 'USD',
      }),
    };
    resolveUnitPrice.mockResolvedValue({
      unitPrice: '2.50',
      currency: 'USD',
      source: 'CATALOG',
      priceSource: 'FACILITY',
    });

    const billing = await buildPharmacyOrderBillingFromRequest({
      items: [{ drug_id: 'drug-uuid-1', quantity: 10 }],
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
    });

    expect(billing).toEqual(
      expect.objectContaining({
        payment_status: 'PENDING',
        total_amount: '25.00',
      })
    );
    expect(billing.line_items[0]).toEqual(
      expect.objectContaining({
        quantity: 10,
        unit_price: '2.50',
      })
    );
  });

  it('buildProcedureBillingFromRequest uses unit price when catalog unresolved', async () => {
    resolveUnitPrice.mockResolvedValue({
      unitPrice: null,
      currency: null,
      source: 'UNRESOLVED',
    });

    const billing = await buildProcedureBillingFromRequest({
      code: '99213',
      description: 'Office visit',
      unitPrice: '80.00',
      currency: 'USD',
      tenantId: 'tenant-1',
    });

    expect(billing).toEqual(
      expect.objectContaining({
        payment_status: 'PENDING',
        total_amount: '80.00',
      })
    );
  });

  it('normalizeBillingOfficeClinicalBilling strips pay-now (no bypass settle)', () => {
    const billing = normalizeBillingOfficeClinicalBilling({
      payment_status: 'PAID',
      paid_amount: '55.00',
      payment_method: 'CASH',
      currency: 'USD',
      line_items: [
        {
          id: 'RAD-CXR',
          label: 'Chest X-Ray',
          quantity: 1,
          unit_price: '55.00',
          line_total: '55.00',
        },
      ],
    });

    expect(billing.payment_status).toBe('PENDING');
    expect(billing.paid_amount).toBeUndefined();
    expect(billing.payment_method).toBeUndefined();
  });

  it('pending billing payload is idempotent on replay shape', () => {
    const first = buildPendingClinicalRequestBilling({
      lineItems: [
        {
          id: 'LAB-CBC',
          label: 'CBC',
          quantity: 1,
          unit_price: '40.00',
          line_total: '40.00',
        },
      ],
      currency: 'USD',
    });
    const second = buildPendingClinicalRequestBilling({
      lineItems: [
        {
          id: 'LAB-CBC',
          label: 'CBC',
          quantity: 1,
          unit_price: '40.00',
          line_total: '40.00',
        },
      ],
      currency: 'USD',
    });
    expect(first).toEqual(second);
    expect(first.payment_status).toBe('PENDING');
  });

  it('unpriced radiology request returns null (explicit no charge path)', async () => {
    const prisma = require('@prisma/client');
    prisma.radiology_procedure = {
      findFirst: jest.fn().mockResolvedValue({
        id: 'rad-uuid-2',
        human_friendly_id: 'RAD-FREE',
        name: 'Internal review',
        unit_price: null,
        currency: 'USD',
      }),
    };
    resolveUnitPrice.mockResolvedValue({
      unitPrice: null,
      currency: null,
      source: 'UNRESOLVED',
    });

    const billing = await buildRadiologyOrderBillingFromRequest({
      radiologyTestId: 'rad-uuid-2',
      tenantId: 'tenant-1',
    });
    expect(billing).toBeNull();
  });
});
