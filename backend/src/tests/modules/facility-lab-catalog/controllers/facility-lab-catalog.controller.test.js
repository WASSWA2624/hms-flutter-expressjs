/**
 * Facility lab catalog controller tests
 */

const facilityLabCatalogController = require('@controllers/facility-lab-catalog/facility-lab-catalog.controller');
const facilityLabCatalogService = require('@services/facility-lab-catalog/facility-lab-catalog.service');
const { sendSuccess, sendPaginated } = require('@lib/response');

jest.mock('@services/facility-lab-catalog/facility-lab-catalog.service');
jest.mock('@lib/response');

describe('Facility Lab Catalog Controller', () => {
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
        facility_id: '323e4567-e89b-12d3-a456-426614174002'},
      ip: '127.0.0.1'};
    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis()};
    jest.clearAllMocks();
  });

  it('upserts a facility lab test offering with a numeric success status', async () => {
    const item = { id: 'LAB0000001', name: 'CBC', code: 'CBC' };
    mockReq.params = { lab_test_id: 'STD_LAB_TEST:CBC' };
    mockReq.body = { unit_price: 50000, currency: 'UGX', is_active: true };
    facilityLabCatalogService.upsertFacilityLabTestOffering.mockResolvedValue(item);

    await facilityLabCatalogController.upsertFacilityLabTestOffering(mockReq, mockRes);

    expect(facilityLabCatalogService.upsertFacilityLabTestOffering).toHaveBeenCalledWith(
      expect.objectContaining({ lab_test_id: 'STD_LAB_TEST:CBC' }),
      expect.objectContaining({
        tenant_id: mockReq.user.tenant_id,
        facility_id: mockReq.user.facility_id,
        user_id: mockReq.user.id})
    );
    expect(sendSuccess).toHaveBeenCalledWith(
      mockRes,
      200,
      'messages.facility_lab_catalog.tests.upsert.success',
      item
    );
  });

  it('upserts a facility lab panel offering with a numeric success status', async () => {
    const item = { id: 'LBP0000001', name: 'Abdominal Pain Panel', code: 'ABDP' };
    mockReq.params = { lab_panel_id: 'LBP-BE78B566C1' };
    mockReq.body = { unit_price: 40000, currency: 'UGX', is_active: true };
    facilityLabCatalogService.upsertFacilityLabPanelOffering.mockResolvedValue(item);

    await facilityLabCatalogController.upsertFacilityLabPanelOffering(mockReq, mockRes);

    expect(sendSuccess).toHaveBeenCalledWith(
      mockRes,
      200,
      'messages.facility_lab_catalog.panels.upsert.success',
      item
    );
  });

  it('searches facility lab catalog with a numeric success status', async () => {
    const items = [{ id: 'LAB0000001', term_type: 'LAB_TEST' }];
    mockReq.query = { term_type: 'LAB_TEST', offered_only: 'true' };
    facilityLabCatalogService.searchFacilityLabCatalog.mockResolvedValue(items);

    await facilityLabCatalogController.searchFacilityLabCatalog(mockReq, mockRes);

    expect(sendSuccess).toHaveBeenCalledWith(
      mockRes,
      200,
      'messages.facility_lab_catalog.search.success',
      items
    );
  });

  it('lists facility lab tests through sendPaginated', async () => {
    const items = [{ id: 'LAB0000001' }];
    const pagination = { page: 1, limit: 20, total: 1, totalPages: 1 };
    mockReq.query = { page: '1', limit: '20' };
    facilityLabCatalogService.listFacilityLabTests.mockResolvedValue({ items, pagination });

    await facilityLabCatalogController.listFacilityLabTests(mockReq, mockRes);

    expect(sendPaginated).toHaveBeenCalledWith(
      mockRes,
      'messages.facility_lab_catalog.tests.list.success',
      items,
      pagination
    );
  });
});
