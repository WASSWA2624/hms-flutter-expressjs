/**
 * Clinical catalog service tests
 */

const authRepository = require('@repositories/auth/auth.repository');
const clinicalCatalogService = require('@services/clinical-term/clinical-catalog.service');
const facilityLabCatalogService = require('@services/facility-lab-catalog/facility-lab-catalog.service');
const { HttpError } = require('@lib/errors');

jest.mock('@repositories/auth/auth.repository');
jest.mock('@services/facility-lab-catalog/facility-lab-catalog.service');

describe('clinical-catalog.service listClinicalCatalogSearch', () => {
  const context = {
    user_id: 'user-1',
    tenant_id: 'tenant-1',
    facility_id: null};

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('delegates offered lab catalog search with resolved facility id', async () => {
    authRepository.getUserFacilities.mockResolvedValue([{ id: 'facility-1' }]);
    facilityLabCatalogService.searchFacilityLabCatalog.mockResolvedValue([
      { id: 'LAB0000001', term_type: 'LAB_TEST' }]);

    const result = await clinicalCatalogService.listClinicalCatalogSearch(
      {
        term_type: 'LAB_TEST',
        offered_only: 'true',
        source: 'FACILITY'},
      context
    );

    expect(facilityLabCatalogService.searchFacilityLabCatalog).toHaveBeenCalledWith(
      expect.objectContaining({
        term_type: 'LAB_TEST',
        offered_only: 'true',
        facility_id: 'facility-1'}),
      context
    );
    expect(result).toEqual([{ id: 'LAB0000001', term_type: 'LAB_TEST' }]);
  });

  it('uses explicit facility id from query filters', async () => {
    facilityLabCatalogService.searchFacilityLabCatalog.mockResolvedValue([]);

    await clinicalCatalogService.listClinicalCatalogSearch(
      {
        term_type: 'LAB_PANEL',
        offered_only: 'true',
        facility_id: 'facility-explicit'},
      context
    );

    expect(authRepository.getUserFacilities).not.toHaveBeenCalled();
    expect(facilityLabCatalogService.searchFacilityLabCatalog).toHaveBeenCalledWith(
      expect.objectContaining({
        facility_id: 'facility-explicit'}),
      context
    );
  });

  it('propagates facility resolution failures for offered lab catalog search', async () => {
    authRepository.getUserFacilities.mockResolvedValue([]);
    facilityLabCatalogService.searchFacilityLabCatalog.mockRejectedValue(
      new HttpError('errors.validation.field.required', 400, [{ field: 'facility_id' }])
    );

    await expect(
      clinicalCatalogService.listClinicalCatalogSearch(
        {
          term_type: 'LAB_TEST',
          offered_only: 'true'},
        context
      )
    ).rejects.toMatchObject({
      statusCode: 400,
      messageKey: 'errors.validation.field.required'});
  });
});
