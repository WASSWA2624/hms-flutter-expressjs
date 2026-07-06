/**
 * Facility radiology catalog controller tests
 */

const facilityRadiologyCatalogController = require('@controllers/facility-radiology-catalog/facility-radiology-catalog.controller');
const facilityRadiologyCatalogService = require('@services/facility-radiology-catalog/facility-radiology-catalog.service');
const { sendSuccess, sendPaginated } = require('@lib/response');

jest.mock('@services/facility-radiology-catalog/facility-radiology-catalog.service');
jest.mock('@lib/response');

describe('Facility Radiology Catalog Controller', () => {
  let mockReq;
  let mockRes;

  beforeEach(() => {
    mockReq = {
      query: {},
      params: {},
      body: {},
      user: {
        id: '123e4567-e89b-12d3-a456-426614174000',
        tenant_id: '223e4567-e89b-12d3-a456-426614174001',
        facility_id: '323e4567-e89b-12d3-a456-426614174002',
      },
      ip: '127.0.0.1',
    };
    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis(),
    };
    jest.clearAllMocks();
  });

  it('upserts a facility radiology test offering', async () => {
    const item = { id: 'RAD0000001', name: 'Chest X-Ray', code: 'CXR' };
    mockReq.params = { radiology_test_id: 'STD_RAD_TEST_CXR' };
    mockReq.body = { unit_price: 50000, currency: 'UGX', is_active: true };
    facilityRadiologyCatalogService.upsertFacilityRadiologyTestOffering.mockResolvedValue(item);

    await facilityRadiologyCatalogController.upsertFacilityRadiologyTestOffering(mockReq, mockRes);

    expect(facilityRadiologyCatalogService.upsertFacilityRadiologyTestOffering).toHaveBeenCalledWith(
      expect.objectContaining({ radiology_test_id: 'STD_RAD_TEST_CXR' }),
      expect.objectContaining({
        tenant_id: mockReq.user.tenant_id,
        facility_id: mockReq.user.facility_id,
        user_id: mockReq.user.id,
      })
    );
    expect(sendSuccess).toHaveBeenCalledWith(
      mockRes,
      200,
      'messages.facility_radiology_catalog.tests.upsert.success',
      item
    );
  });

  it('searches facility radiology catalog', async () => {
    const items = [{ id: 'RAD0000001', term_type: 'RADIOLOGY_TEST' }];
    mockReq.query = { term_type: 'RADIOLOGY_TEST', offered_only: 'true' };
    facilityRadiologyCatalogService.searchFacilityRadiologyCatalog.mockResolvedValue(items);

    await facilityRadiologyCatalogController.searchFacilityRadiologyCatalog(mockReq, mockRes);

    expect(sendSuccess).toHaveBeenCalledWith(
      mockRes,
      200,
      'messages.facility_radiology_catalog.search.success',
      items
    );
  });

  it('lists facility radiology tests with pagination', async () => {
    const result = {
      items: [{ id: 'RAD0000001', name: 'Chest X-Ray' }],
      pagination: { page: 1, limit: 20, total: 1 },
    };
    facilityRadiologyCatalogService.listFacilityRadiologyTests.mockResolvedValue(result);

    await facilityRadiologyCatalogController.listFacilityRadiologyTests(mockReq, mockRes);

    expect(sendPaginated).toHaveBeenCalledWith(
      mockRes,
      'messages.facility_radiology_catalog.tests.list.success',
      result.items,
      result.pagination
    );
  });
});
