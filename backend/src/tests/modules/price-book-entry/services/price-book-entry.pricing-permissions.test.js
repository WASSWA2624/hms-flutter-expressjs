const priceBookEntryService = require('@services/price-book-entry/price-book-entry.service');
const priceBookEntryRepository = require('@repositories/price-book-entry/price-book-entry.repository');
const { createAuditLog } = require('@lib/audit');
const { PERMISSIONS } = require('@config/permissions');

jest.mock('@repositories/price-book-entry/price-book-entry.repository');
jest.mock('@lib/audit');
jest.mock('@lib/billing/identifiers', () => ({
  sanitizeIdentifier: (value) => value,
  resolvePublicIdentifier: (value) => value,
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value),
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value),
  resolveEntityId: jest.fn(async ({ identifier }) => identifier),
}));
jest.mock('@middlewares/auth.middleware', () => ({
  getUserPermissions: jest.fn(),
}));

const { getUserPermissions } = require('@middlewares/auth.middleware');

describe('price-book-entry pricing permission gates', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockReturnValue(Promise.resolve());
  });

  it('rejects FACILITY price-book create without pricing:facility_write', async () => {
    getUserPermissions.mockReturnValue([PERMISSIONS.BILLING_WRITE]);

    await expect(
      priceBookEntryService.createPriceBookEntry(
        {
          tenant_id: 'tenant-1',
          catalog_type: 'DRUG',
          catalog_item_id: 'drug-1',
          payment_mode: 'SELF_PAY',
          billing_entity: 'FACILITY',
          unit_price: 100,
          currency: 'UGX',
        },
        'user-1',
        '127.0.0.1',
        { id: 'user-1' }
      )
    ).rejects.toMatchObject({
      statusCode: 403,
      message: 'errors.auth.insufficient_permissions',
    });
    expect(priceBookEntryRepository.create).not.toHaveBeenCalled();
  });

  it('allows FACILITY price-book create with pricing:facility_write', async () => {
    getUserPermissions.mockReturnValue([PERMISSIONS.PRICING_FACILITY_WRITE]);
    const created = {
      id: 'pbe-1',
      tenant_id: 'tenant-1',
      billing_entity: 'FACILITY',
      unit_price: 100,
      currency: 'UGX',
    };
    priceBookEntryRepository.create.mockResolvedValue(created);
    priceBookEntryRepository.findById.mockResolvedValue(created);

    const result = await priceBookEntryService.createPriceBookEntry(
      {
        tenant_id: 'tenant-1',
        catalog_type: 'DRUG',
        catalog_item_id: 'drug-1',
        payment_mode: 'SELF_PAY',
        billing_entity: 'FACILITY',
        unit_price: 100,
        currency: 'UGX',
      },
      'user-1',
      '127.0.0.1',
      { id: 'user-1' }
    );

    expect(result.id).toBe('pbe-1');
    expect(priceBookEntryRepository.create).toHaveBeenCalled();
  });

  it('rejects PHARMACY price-book create without pricing:pharmacy_write', async () => {
    getUserPermissions.mockReturnValue([PERMISSIONS.PRICING_FACILITY_WRITE]);

    await expect(
      priceBookEntryService.createPriceBookEntry(
        {
          tenant_id: 'tenant-1',
          catalog_type: 'DRUG',
          catalog_item_id: 'drug-1',
          payment_mode: 'SELF_PAY',
          billing_entity: 'PHARMACY',
          unit_price: 120,
          currency: 'UGX',
        },
        'user-1',
        '127.0.0.1',
        { id: 'user-1' }
      )
    ).rejects.toMatchObject({
      statusCode: 403,
      message: 'errors.auth.insufficient_permissions',
    });
    expect(priceBookEntryRepository.create).not.toHaveBeenCalled();
  });
});
