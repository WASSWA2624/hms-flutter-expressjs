const repository = require('../../../../modules/dashboard-workspace/repositories/dashboard-workspace.repository');

describe('dashboard-workspace repository', () => {
  it('exports workspace repository helpers', () => {
    expect(repository).toBeDefined();
    expect(typeof repository).toBe('object');
    expect(Object.keys(repository)).toEqual(
      expect.arrayContaining([
        'resolveWorkspaceScope',
        'findLookups',
        'findFacilityContext',
        'findCurrentSubscription',
        'countRows',
        'sumRows',
        'findRows',
        'safePublicId',
      ])
    );
  });
});
