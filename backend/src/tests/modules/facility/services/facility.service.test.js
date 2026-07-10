const facilityRepository = require('../../../../modules/facility/repositories/facility.repository');
const facilityService = require('../../../../modules/facility/services/facility.service');
const { HttpError } = require('@lib/errors');

jest.mock('@repositories/facility/facility.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue(undefined)
}));
jest.mock('@lib/billing/identifiers', () => ({
  resolveEntityId: jest.fn(async ({ identifier }) => identifier),
  resolvePublicIdentifier: jest.fn((...values) => values.find((value) => value) || null),
}));

describe('facility.service duplicate name validation', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('rejects create when facility name already exists for tenant', async () => {
    facilityRepository.findByTenantAndName.mockResolvedValue({
      id: 'FAC0001',
      tenant_id: 'TEN0001',
      name: 'DemoCare General Hospital'
    });

    await expect(
      facilityService.createFacility({
        tenant_id: 'TEN0001',
        name: 'DemoCare General Hospital',
        facility_type: 'HOSPITAL'
      })
    ).rejects.toMatchObject({
      messageKey: 'errors.facility.duplicate_name',
      statusCode: 409
    });

    expect(facilityRepository.create).not.toHaveBeenCalled();
  });

  it('allows create when no duplicate exists for tenant', async () => {
    facilityRepository.findByTenantAndName.mockResolvedValue(null);
    facilityRepository.create.mockResolvedValue({
      id: 'FAC0002',
      tenant_id: 'TEN0001',
      name: 'New Facility',
      facility_type: 'HOSPITAL',
      is_active: true
    });

    const facility = await facilityService.createFacility({
      tenant_id: 'TEN0001',
      name: 'New Facility',
      facility_type: 'HOSPITAL'
    });

    expect(facility.id).toBe('FAC0002');
    expect(facilityRepository.create).toHaveBeenCalled();
  });

  it('rejects update when renamed to an existing facility name', async () => {
    facilityRepository.findById.mockResolvedValue({
      id: 'FAC0002',
      tenant_id: 'TEN0001',
      name: 'Old Name',
      facility_type: 'HOSPITAL',
      is_active: true
    });
    facilityRepository.findByTenantAndName.mockResolvedValue({
      id: 'FAC0001',
      tenant_id: 'TEN0001',
      name: 'DemoCare General Hospital'
    });

    await expect(
      facilityService.updateFacility('FAC0002', { name: 'DemoCare General Hospital' })
    ).rejects.toBeInstanceOf(HttpError);
  });
});
