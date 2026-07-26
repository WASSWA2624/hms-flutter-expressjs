const facilityRepository = require('../../../../modules/facility/repositories/facility.repository');
const facilityService = require('../../../../modules/facility/services/facility.service');
const { HttpError } = require('@lib/errors');

jest.mock('@repositories/facility/facility.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue(undefined)
}));
jest.mock('@lib/billing/identifiers', () => ({
  resolveEntityId: jest.fn(async ({ identifier }) => identifier),
  resolvePublicIdentifier: jest.fn((...values) => values.find((value) => value) || null)}));
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelIdByIdentifier: jest.fn(async ({ identifier }) => identifier),
  resolveModelRecordByIdentifier: jest.fn().mockResolvedValue(null)}));
jest.mock('@lib/websocket/crud-realtime', () => ({
  publishCrudRealtimeEvent: jest.fn().mockResolvedValue(undefined)}));
jest.mock('@lib/realtime/platform-realtime', () => ({
  publishPlatformRealtimeEvent: jest.fn().mockResolvedValue(1),
  buildFacilityDashboardDeltas: jest.fn().mockReturnValue({})}));
jest.mock('@lib/storage', () => ({
  createStorageService: jest.fn()}));
jest.mock('@lib/storage/facility-logo-storage', () => ({
  deleteFacilityLogoFromStorage: jest.fn().mockResolvedValue(true)}));

const { createStorageService } = require('@lib/storage');
const {
  deleteFacilityLogoFromStorage} = require('@lib/storage/facility-logo-storage');

describe('facility.service duplicate name validation', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('rejects create when facility name already exists for tenant', async () => {
    facilityRepository.findMany.mockResolvedValue([
      {
        id: 'FAC0001',
        tenant_id: 'TEN0001',
        name: 'DemoCare General Hospital',
        facility_type: 'HOSPITAL',
        is_active: true,
        contacts: [],
        addresses: []
      }
    ]);

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

  it('rejects create when similar facility exists without confirm_similar', async () => {
    facilityRepository.findMany.mockResolvedValue([
      {
        id: 'FAC0001',
        tenant_id: 'TEN0001',
        name: 'DemoCare General Hospital',
        facility_type: 'HOSPITAL',
        is_active: true,
        contacts: [],
        addresses: []
      }
    ]);

    await expect(
      facilityService.createFacility({
        tenant_id: 'TEN0001',
        name: 'Democare General Hospitl',
        facility_type: 'HOSPITAL'
      })
    ).rejects.toMatchObject({
      messageKey: 'errors.facility.similar_exists',
      statusCode: 409
    });

    expect(facilityRepository.create).not.toHaveBeenCalled();
  });

  it('allows create with confirm_similar when similar facility exists', async () => {
    facilityRepository.findMany.mockResolvedValue([
      {
        id: 'FAC0001',
        tenant_id: 'TEN0001',
        name: 'DemoCare General Hospital',
        facility_type: 'HOSPITAL',
        is_active: true,
        contacts: [],
        addresses: []
      }
    ]);
    facilityRepository.create.mockResolvedValue({
      id: 'FAC0002',
      tenant_id: 'TEN0001',
      name: 'Democare General Hospitl',
      facility_type: 'HOSPITAL',
      is_active: true
    });

    const facility = await facilityService.createFacility({
      tenant_id: 'TEN0001',
      name: 'Democare General Hospitl',
      facility_type: 'HOSPITAL',
      confirm_similar: true,
      phone: '+256700000000'
    });

    expect(facility.id).toBe('FAC0002');
    expect(facilityRepository.create).toHaveBeenCalledWith(
      expect.not.objectContaining({
        confirm_similar: expect.anything(),
        phone: expect.anything()
      })
    );
  });

  it('allows create when no duplicate exists for tenant', async () => {
    facilityRepository.findMany.mockResolvedValue([]);
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
      is_active: true,
      contacts: [],
      addresses: []
    });
    facilityRepository.findMany.mockResolvedValue([
      {
        id: 'FAC0001',
        tenant_id: 'TEN0001',
        name: 'DemoCare General Hospital',
        facility_type: 'HOSPITAL',
        is_active: true,
        contacts: [],
        addresses: []
      },
      {
        id: 'FAC0002',
        tenant_id: 'TEN0001',
        name: 'Old Name',
        facility_type: 'HOSPITAL',
        is_active: true,
        contacts: [],
        addresses: []
      }
    ]);

    await expect(
      facilityService.updateFacility('FAC0002', { name: 'DemoCare General Hospital' })
    ).rejects.toMatchObject({
      messageKey: 'errors.facility.duplicate_name',
      statusCode: 409
    });
    expect(facilityRepository.update).not.toHaveBeenCalled();
  });

  it('rejects update when similar facility exists without confirm_similar', async () => {
    facilityRepository.findById.mockResolvedValue({
      id: 'FAC0002',
      tenant_id: 'TEN0001',
      name: 'Old Name',
      facility_type: 'HOSPITAL',
      is_active: true,
      contacts: [],
      addresses: []
    });
    facilityRepository.findMany.mockResolvedValue([
      {
        id: 'FAC0001',
        tenant_id: 'TEN0001',
        name: 'DemoCare General Hospital',
        facility_type: 'HOSPITAL',
        is_active: true,
        contacts: [],
        addresses: []
      },
      {
        id: 'FAC0002',
        tenant_id: 'TEN0001',
        name: 'Old Name',
        facility_type: 'HOSPITAL',
        is_active: true,
        contacts: [],
        addresses: []
      }
    ]);

    await expect(
      facilityService.updateFacility('FAC0002', {
        name: 'Democare General Hospitl',
        facility_type: 'HOSPITAL'
      })
    ).rejects.toMatchObject({
      messageKey: 'errors.facility.similar_exists',
      statusCode: 409
    });
    expect(facilityRepository.update).not.toHaveBeenCalled();
  });

  it('excludes the edited facility from similarity matches', async () => {
    const before = {
      id: 'FAC0002',
      tenant_id: 'TEN0001',
      name: 'DemoCare General Hospital',
      facility_type: 'HOSPITAL',
      is_active: true,
      contacts: [],
      addresses: []
    };
    facilityRepository.findById.mockResolvedValue(before);
    facilityRepository.findMany.mockResolvedValue([before]);
    facilityRepository.update.mockResolvedValue({
      ...before,
      name: 'DemoCare General Hospital'
    });

    const facility = await facilityService.updateFacility('FAC0002', {
      name: 'DemoCare General Hospital'
    });

    expect(facility.id).toBe('FAC0002');
    expect(facilityRepository.update).toHaveBeenCalled();
  });

  it('allows update with confirm_similar when similar facility exists', async () => {
    facilityRepository.findById.mockResolvedValue({
      id: 'FAC0002',
      tenant_id: 'TEN0001',
      name: 'Old Name',
      facility_type: 'HOSPITAL',
      is_active: true,
      contacts: [],
      addresses: []
    });
    facilityRepository.findMany.mockResolvedValue([
      {
        id: 'FAC0001',
        tenant_id: 'TEN0001',
        name: 'DemoCare General Hospital',
        facility_type: 'HOSPITAL',
        is_active: true,
        contacts: [],
        addresses: []
      }
    ]);
    facilityRepository.update.mockResolvedValue({
      id: 'FAC0002',
      tenant_id: 'TEN0001',
      name: 'Democare General Hospitl',
      facility_type: 'HOSPITAL',
      is_active: true
    });

    const facility = await facilityService.updateFacility('FAC0002', {
      name: 'Democare General Hospitl',
      facility_type: 'HOSPITAL',
      confirm_similar: true,
      phone: '+256700000000'
    });

    expect(facility.id).toBe('FAC0002');
    expect(facilityRepository.update).toHaveBeenCalledWith(
      'FAC0002',
      expect.not.objectContaining({
        confirm_similar: expect.anything(),
        phone: expect.anything()
      })
    );
  });
});

describe('facility.service list filters', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    facilityRepository.findMany.mockResolvedValue([]);
    facilityRepository.count.mockResolvedValue(0);
  });

  it('builds contact and location search filters', async () => {
    await facilityService.listFacilities({ search: 'Kampala' }, 1, 20);

    expect(facilityRepository.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        OR: expect.arrayContaining([
          { name: { contains: 'Kampala' } },
          expect.objectContaining({
            contacts: expect.any(Object)
          }),
          expect.objectContaining({
            addresses: expect.any(Object)
          })
        ])
      }),
      0,
      20,
      expect.anything(),
      {},
      { includeDeleted: false }
    );
  });

  it('applies city and phone filters', async () => {
    await facilityService.listFacilities(
      { city: 'Kampala', phone: '700' },
      1,
      20
    );

    expect(facilityRepository.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        AND: expect.arrayContaining([
          expect.objectContaining({
            contacts: expect.any(Object)
          }),
          expect.objectContaining({
            addresses: expect.any(Object)
          })
        ])
      }),
      0,
      20,
      expect.anything(),
      {},
      { includeDeleted: false }
    );
  });
});

describe('facility.service restore and permanent delete', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('restores a soft-deleted facility', async () => {
    facilityRepository.restore.mockResolvedValue({
      id: 'FAC0001',
      tenant_id: 'TEN0001',
      name: 'Main',
      facility_type: 'HOSPITAL',
      is_active: true,
      deleted_at: null});

    const facility = await facilityService.restoreFacility('FAC0001', {
      user_id: 'user-1'});

    expect(facility.id).toBe('FAC0001');
    expect(facilityRepository.restore).toHaveBeenCalledWith('FAC0001');
  });

  it('permanently deletes a soft-deleted facility', async () => {
    const storage = { delete: jest.fn() };
    createStorageService.mockReturnValue(storage);
    facilityRepository.findById.mockResolvedValue({
      id: 'FAC0001',
      tenant_id: 'TEN0001',
      name: 'Main',
      facility_type: 'HOSPITAL',
      deleted_at: new Date(),
      extension_json: {
        logo_url: 'facilities_TEN0001_FAC0001_branding_main-logo.png?v=1'}});
    facilityRepository.permanentDelete.mockResolvedValue(undefined);

    await facilityService.permanentDeleteFacility('FAC0001', {
      user_id: 'user-1'});

    expect(deleteFacilityLogoFromStorage).toHaveBeenCalledWith(
      storage,
      'facilities_TEN0001_FAC0001_branding_main-logo.png?v=1'
    );
    expect(facilityRepository.permanentDelete).toHaveBeenCalledWith('FAC0001');
  });

  it('rejects permanent delete for active facility', async () => {
    facilityRepository.findById.mockResolvedValue({
      id: 'FAC0001',
      name: 'Main',
      deleted_at: null});

    await expect(
      facilityService.permanentDeleteFacility('FAC0001')
    ).rejects.toBeInstanceOf(HttpError);
  });
});
