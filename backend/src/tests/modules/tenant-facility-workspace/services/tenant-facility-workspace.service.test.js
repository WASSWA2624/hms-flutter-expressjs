jest.mock('@repositories/tenant-facility-workspace/tenant-facility-workspace.repository');

const repository = require('@repositories/tenant-facility-workspace/tenant-facility-workspace.repository');
const service = require('../../../../modules/tenant-facility-workspace/services/tenant-facility-workspace.service');

describe('tenant-facility-workspace service', () => {
  beforeEach(() => {
    jest.clearAllMocks();

    repository.resolveWorkspaceScope.mockResolvedValue({
      state: 'ready',
      scope: { tenant_id: 'tenant-uuid', facility_id: 'facility-uuid' },
    });
    repository.findTenants.mockResolvedValue([
      {
        id: 'tenant-uuid',
        human_friendly_id: 'TEN0001',
        name: 'Acme Hospital',
        slug: 'acme',
        is_active: true,
      },
    ]);
    repository.findFacilities.mockResolvedValue([
      {
        id: 'facility-uuid',
        human_friendly_id: 'FAC0001',
        tenant_id: 'tenant-uuid',
        name: 'Main Campus',
        facility_type: 'HOSPITAL',
        is_active: true,
        extension_json: { logo_url: 'https://example.com/logo.png' },
      },
    ]);
    repository.findFacilityRecords.mockResolvedValue({
      branches: [
        {
          id: 'branch-uuid',
          human_friendly_id: 'BRN0001',
          tenant_id: 'tenant-uuid',
          facility_id: 'facility-uuid',
          name: 'North Wing',
          is_active: true,
        },
      ],
      departments: [
        {
          id: 'dept-uuid',
          human_friendly_id: 'DEP0001',
          tenant_id: 'tenant-uuid',
          facility_id: 'facility-uuid',
          branch_id: 'branch-uuid',
          name: 'Internal Medicine',
          short_name: 'IM',
          department_type: 'CLINICAL',
          is_active: true,
        },
      ],
      units: [
        {
          id: 'unit-uuid',
          human_friendly_id: 'UNT0001',
          tenant_id: 'tenant-uuid',
          facility_id: 'facility-uuid',
          department_id: 'dept-uuid',
          name: 'OPD Clinic',
          is_active: true,
        },
      ],
      wards: [
        {
          id: 'ward-uuid',
          human_friendly_id: 'WRD0001',
          tenant_id: 'tenant-uuid',
          facility_id: 'facility-uuid',
          department_id: 'dept-uuid',
          name: 'General Ward',
          ward_type: 'GENERAL',
          is_active: true,
        },
      ],
      rooms: [],
      beds: [
        {
          id: 'bed-uuid',
          human_friendly_id: 'BED0001',
          tenant_id: 'tenant-uuid',
          facility_id: 'facility-uuid',
          ward_id: 'ward-uuid',
          room_id: null,
          label: 'A1',
          status: 'AVAILABLE',
        },
      ],
      contacts: [
        {
          id: 'contact-phone',
          contact_type: 'PHONE',
          value: '+256700000000',
        },
        {
          id: 'contact-email',
          contact_type: 'EMAIL',
          value: 'info@acme.test',
        },
      ],
      addresses: [
        {
          id: 'address-1',
          line1: 'Plot 1 Hospital Road',
          city: 'Kampala',
          country: 'UG',
        },
      ],
    });
    repository.findSubscriptionSummary.mockResolvedValue({
      subscription: {
        id: 'sub-uuid',
        human_friendly_id: 'SUB0001',
        status: 'ACTIVE',
        plan: {
          id: 'plan-uuid',
          human_friendly_id: 'PLN0001',
          name: 'Premium',
          tier_code: 'PREMIUM',
        },
        module_subscriptions: [{ id: 'ms-1' }, { id: 'ms-2' }],
      },
      active_modules_count: 2,
    });
  });

  it('returns tenant and facility setup payload with checklist and subscription summary', async () => {
    const result = await service.getSetup({}, {
      role: 'TENANT_ADMIN',
      permissions: ['subscriptions:read'],
    });

    expect(result.state).toBe('ready');
    expect(result.tenant).toEqual(
      expect.objectContaining({ id: 'TEN0001', name: 'Acme Hospital' })
    );
    expect(result.facility).toEqual(
      expect.objectContaining({ id: 'FAC0001', name: 'Main Campus' })
    );
    expect(result.branches).toHaveLength(1);
    expect(result.departments).toHaveLength(1);
    expect(result.units).toHaveLength(1);
    expect(result.wards).toHaveLength(1);
    expect(result.beds).toHaveLength(1);
    expect(result.contact_address).toEqual(
      expect.objectContaining({
        phone: '+256700000000',
        email: 'info@acme.test',
        address_line1: 'Plot 1 Hospital Road',
      })
    );
    expect(result.checklist.completed_count).toBeGreaterThan(0);
    expect(result.subscription_summary).toEqual(
      expect.objectContaining({
        plan_label: 'Premium',
        status: 'ACTIVE',
        active_modules_count: 2,
      })
    );
    expect(result.permissions.can_manage_tenant).toBe(true);
  });

  it('resolves scoped foreign-key public ids from uuid storage', async () => {
    const result = await service.getSetup({}, { role: 'TENANT_ADMIN' });

    expect(result.facility.tenant_id).toBe('TEN0001');
    expect(result.branches[0].tenant_id).toBe('TEN0001');
    expect(result.branches[0].facility_id).toBe('FAC0001');
    expect(result.departments[0].tenant_id).toBe('TEN0001');
    expect(result.departments[0].facility_id).toBe('FAC0001');
    expect(result.departments[0].branch_id).toBe('BRN0001');
    expect(result.units[0].department_id).toBe('DEP0001');
    expect(result.wards[0].facility_id).toBe('FAC0001');
    expect(result.beds[0].ward_id).toBe('WRD0001');
  });

  it('returns tenant context required payload without facility records', async () => {
    repository.resolveWorkspaceScope.mockResolvedValue({
      state: 'tenant_context_required',
      scope: null,
    });
    repository.findTenants.mockResolvedValue([
      {
        id: 'tenant-uuid',
        human_friendly_id: 'TEN0001',
        name: 'Acme Hospital',
        is_active: true,
      },
    ]);

    const result = await service.getSetup({}, { role: 'SUPER_ADMIN' });

    expect(result.state).toBe('tenant_context_required');
    expect(result.facility).toBeNull();
    expect(result.lookups.tenants).toHaveLength(1);
    expect(repository.findFacilityRecords).not.toHaveBeenCalled();
  });

  describe('buildFacilityLogoBasename', () => {
    it('builds a short slug-logo basename from the facility name', () => {
      expect(service.buildFacilityLogoBasename('Main Campus', 'photo.JPG')).toBe(
        'main-campus-logo.jpg'
      );
      expect(
        service.buildStableFacilityLogoKey('fbb67a68-8fea-4eed-a072-4869585d8466')
      ).toBe('logo-585d8466.png');
    });

    it('clips basename to 32 characters including extension', () => {
      const longName =
        'Very Long Hospital And Medical Center Name That Should Be Clipped For Filesystem Safety';
      const basename = service.buildFacilityLogoBasename(longName, 'logo.webp');
      expect(basename.length).toBeLessThanOrEqual(32);
      expect(basename.endsWith('.webp')).toBe(true);
      expect(basename).toContain('-logo');
    });
  });
});
