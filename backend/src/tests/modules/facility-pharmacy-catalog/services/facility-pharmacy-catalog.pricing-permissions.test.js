const facilityPharmacyCatalogService = require('@services/facility-pharmacy-catalog/facility-pharmacy-catalog.service');
const facilityPharmacyCatalogRepository = require('@repositories/facility-pharmacy-catalog/facility-pharmacy-catalog.repository');
const drugRepository = require('@repositories/drug/drug.repository');
const { createAuditLog } = require('@lib/audit');
const { PERMISSIONS } = require('@config/permissions');

jest.mock('@repositories/facility-pharmacy-catalog/facility-pharmacy-catalog.repository');
jest.mock('@repositories/drug/drug.repository');
jest.mock('@lib/audit');
jest.mock('@lib/facility-context', () => ({
  resolveOperationalFacilityId: jest.fn(async () => 'facility-1'),
}));
jest.mock('@services/pharmacy-workspace/pharmacy.shared', () => ({
  buildPagination: jest.fn(),
  normalizeSearchTerm: jest.fn(),
  resolveModelIdOrThrow: jest.fn(async ({ identifier }) => identifier),
  resolveModelRecordOrThrow: jest.fn(async ({ identifier }) => ({
    id: identifier,
    currency: 'UGX',
    name: 'Paracetamol',
  })),
}));
jest.mock('@services/pharmacy-workspace/pharmacy-storage.service', () => ({
  resolveDefaultStorageShelfId: jest.fn(async (id) => id),
}));
jest.mock('@services/pharmacy-workspace/facility-pharmacy-catalog.merge', () => ({
  mapMergedDrugRecord: jest.fn((drug, offering) => ({
    ...(drug || {}),
    ...(offering || {}),
  })),
}));
jest.mock('@middlewares/auth.middleware', () => ({
  getUserPermissions: jest.fn(),
}));

const { getUserPermissions } = require('@middlewares/auth.middleware');

describe('facility pharmacy offering pricing gates', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockReturnValue(Promise.resolve());
    facilityPharmacyCatalogRepository.findDrugOffering.mockResolvedValue(null);
  });

  it('rejects tariff upsert without pricing:facility_write', async () => {
    getUserPermissions.mockReturnValue([PERMISSIONS.PHARMACY_WRITE]);

    await expect(
      facilityPharmacyCatalogService.upsertFacilityPharmacyOffering(
        {
          drug_id: 'drug-1',
          unit_price: 450,
          currency: 'UGX',
          is_active: true,
        },
        {
          tenant_id: 'tenant-1',
          user_id: 'user-1',
          facility_id: 'facility-1',
          user: { id: 'user-1' },
        }
      )
    ).rejects.toMatchObject({
      statusCode: 403,
      message: 'errors.auth.insufficient_permissions',
    });
    expect(
      facilityPharmacyCatalogRepository.createDrugOffering
    ).not.toHaveBeenCalled();
  });

  it('allows shelf-only upsert without pricing write', async () => {
    getUserPermissions.mockReturnValue([PERMISSIONS.PHARMACY_WRITE]);
    facilityPharmacyCatalogRepository.createDrugOffering.mockResolvedValue({
      id: 'offering-1',
      unit_price: 0,
      is_active: false,
      default_storage_shelf_id: 'shelf-1',
    });

    const result =
      await facilityPharmacyCatalogService.upsertFacilityPharmacyOffering(
        {
          drug_id: 'drug-1',
          default_storage_shelf_id: 'shelf-1',
        },
        {
          tenant_id: 'tenant-1',
          user_id: 'user-1',
          facility_id: 'facility-1',
          user: { id: 'user-1' },
        }
      );

    expect(result.id).toBe('offering-1');
    expect(
      facilityPharmacyCatalogRepository.createDrugOffering
    ).toHaveBeenCalled();
  });

  it('allows tariff upsert with pricing:facility_write', async () => {
    getUserPermissions.mockReturnValue([PERMISSIONS.PRICING_FACILITY_WRITE]);
    facilityPharmacyCatalogRepository.createDrugOffering.mockResolvedValue({
      id: 'offering-2',
      unit_price: 450,
      is_active: true,
    });

    const result =
      await facilityPharmacyCatalogService.upsertFacilityPharmacyOffering(
        {
          drug_id: 'drug-1',
          unit_price: 450,
          currency: 'UGX',
          is_active: true,
        },
        {
          tenant_id: 'tenant-1',
          user_id: 'user-1',
          facility_id: 'facility-1',
          user: { id: 'user-1' },
        }
      );

    expect(result.id).toBe('offering-2');
  });
});
