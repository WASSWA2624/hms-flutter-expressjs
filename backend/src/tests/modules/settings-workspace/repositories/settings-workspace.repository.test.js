const repository = require('../../../../modules/settings-workspace/repositories/settings-workspace.repository');

describe('settings-workspace repository', () => {
  it('exports workspace repository helpers', () => {
    expect(repository).toBeDefined();
    expect(typeof repository).toBe('object');
    expect(Object.keys(repository)).toEqual(
      expect.arrayContaining([
        'resolveWorkspaceScope',
        'findReferenceData',
        'findTenantContext',
        'findFacilityContext',
        'findModuleMetrics',
        'safePublicId',
      ])
    );
  });
});
