jest.mock('@repositories/settings-workspace/settings-workspace.repository');

const repository = require('@repositories/settings-workspace/settings-workspace.repository');
const service = require('../../../../modules/settings-workspace/services/settings-workspace.service');

describe('settings-workspace service', () => {
  beforeEach(() => {
    jest.clearAllMocks();

    repository.resolveWorkspaceScope.mockResolvedValue({
      state: 'ready',
      scope: { tenant_id: 'tenant-uuid', facility_id: 'facility-uuid' },
    });
    repository.findTenantContext.mockResolvedValue({
      id: 'tenant-uuid',
      human_friendly_id: 'TEN0001',
      name: 'Acme',
    });
    repository.findFacilityContext.mockResolvedValue({
      id: 'facility-uuid',
      human_friendly_id: 'FAC0001',
      name: 'Main Branch',
      facility_type: 'HOSPITAL',
    });
    repository.findReferenceData.mockResolvedValue({
      tenants: [{ id: 'tenant-uuid', human_friendly_id: 'TEN0001', name: 'Acme' }],
      facilities: [{ id: 'facility-uuid', human_friendly_id: 'FAC0001', name: 'Main Branch', facility_type: 'HOSPITAL' }],
    });
    repository.findModuleMetrics.mockResolvedValue({
      tenant: { count: 1, last_updated_at: '2026-03-01T00:00:00.000Z' },
      facility: { count: 1, last_updated_at: '2026-03-01T00:00:00.000Z' },
      branch: { count: 1, last_updated_at: '2026-03-01T00:00:00.000Z' },
      department: { count: 2, last_updated_at: '2026-03-01T00:00:00.000Z' },
      unit: { count: 1, last_updated_at: '2026-03-01T00:00:00.000Z' },
      room: { count: 2, last_updated_at: '2026-03-01T00:00:00.000Z' },
      ward: { count: 1, last_updated_at: '2026-03-01T00:00:00.000Z' },
      bed: { count: 4, last_updated_at: '2026-03-01T00:00:00.000Z' },
      address: { count: 3, last_updated_at: '2026-03-01T00:00:00.000Z' },
      contact: { count: 3, last_updated_at: '2026-03-01T00:00:00.000Z' },
      user: { count: 5, last_updated_at: '2026-03-01T00:00:00.000Z' },
      'user-profile': { count: 5, last_updated_at: '2026-03-01T00:00:00.000Z' },
      role: { count: 4, last_updated_at: '2026-03-01T00:00:00.000Z' },
      permission: { count: 10, last_updated_at: '2026-03-01T00:00:00.000Z' },
      'role-permission': { count: 15, last_updated_at: '2026-03-01T00:00:00.000Z' },
      'user-role': { count: 8, last_updated_at: '2026-03-01T00:00:00.000Z' },
      'user-session': { count: 11, last_updated_at: '2026-03-01T00:00:00.000Z' },
      'api-key': { count: 2, last_updated_at: '2026-03-01T00:00:00.000Z' },
      'api-key-permission': { count: 4, last_updated_at: '2026-03-01T00:00:00.000Z' },
      'user-mfa': { count: 3, last_updated_at: '2026-03-01T00:00:00.000Z' },
      'oauth-account': { count: 1, last_updated_at: '2026-03-01T00:00:00.000Z' },
    });

    repository.safePublicId.mockImplementation((...values) => values.find(Boolean) || null);
  });

  it('returns settings workspace payload with grouped modules and quick actions', async () => {
    const result = await service.getWorkspace({}, { role: 'TENANT_ADMIN' });

    expect(result.state).toBe('ready');
    expect(result.summary_cards).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ id: 'organization', total_modules: 10 }),
      ])
    );
    expect(result.module_groups).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ id: 'organization' }),
      ])
    );
    expect(result.quick_actions.length).toBeGreaterThan(0);
    expect(result.stats.total_modules).toBeGreaterThan(0);

    const securityGroup = result.module_groups.find((group) => group.id === 'security');
    const apiKeyModule = securityGroup.modules.find((module) => module.module_id === 'api-key');

    expect(apiKeyModule).toEqual(
      expect.objectContaining({
        create_route: null,
        can_create: false,
      })
    );
    expect(result.quick_actions.some((entry) => entry.module_id === 'api-key')).toBe(false);
  });

  it('returns tenant-context-required state when super admin has no tenant selected', async () => {
    repository.resolveWorkspaceScope.mockResolvedValueOnce({
      state: 'tenant_context_required',
      scope: null,
    });

    const result = await service.getWorkspace({}, { role: 'SUPER_ADMIN' });

    expect(result.state).toBe('tenant_context_required');
    expect(result.lookups.tenants.length).toBeGreaterThanOrEqual(0);
  });

  it('returns reference data payload', async () => {
    const result = await service.getReferenceData({}, { role: 'TENANT_ADMIN' });

    expect(result).toEqual(
      expect.objectContaining({
        state: 'ready',
        tenants: expect.any(Array),
        facilities: expect.any(Array),
      })
    );
  });
});
