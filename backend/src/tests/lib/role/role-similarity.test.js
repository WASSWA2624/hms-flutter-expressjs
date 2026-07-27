const {
  checkRoleDuplicates,
  compositeSimilarityScore
} = require('@lib/role/role-similarity');

describe('role-similarity', () => {
  const existing = [
    {
      id: 'role-1',
      human_friendly_id: 'ROL0001',
      tenant_id: 'tenant-1',
      facility_id: null,
      name: 'WARD CLERK',
      display_name: 'Ward Clerk',
      description: 'Front desk ward support'
    }
  ];

  it('weights name more heavily than description', () => {
    const nameHeavy = compositeSimilarityScore({
      nameScore: 100,
      descriptionScore: 0
    });
    const descriptionHeavy = compositeSimilarityScore({
      nameScore: 0,
      descriptionScore: 100
    });
    expect(nameHeavy).toBeGreaterThan(descriptionHeavy);
  });

  it('detects exact name conflict within the same scope', () => {
    const result = checkRoleDuplicates({
      name: 'WARD CLERK',
      displayName: 'Ward Clerk',
      description: 'Front desk ward support',
      facilityId: null,
      existing
    });

    expect(result.exactNameConflict).toBe(true);
    expect(result.hasExactConflict).toBe(true);
    expect(result.similarMatches[0].isExact).toBe(true);
  });

  it('returns overridable similar matches for near names', () => {
    const result = checkRoleDuplicates({
      name: 'WARD CLRCK',
      displayName: 'Ward Clerk',
      description: 'Front desk ward support',
      facilityId: null,
      existing
    });

    expect(result.exactNameConflict).toBe(false);
    expect(result.overridableMatches.length).toBeGreaterThan(0);
    expect(result.overridableMatches[0].score).toBeGreaterThanOrEqual(80);
  });

  it('ignores peers outside the facility scope', () => {
    const result = checkRoleDuplicates({
      name: 'WARD CLERK',
      displayName: 'Ward Clerk',
      description: 'Front desk ward support',
      facilityId: 'facility-1',
      existing
    });

    expect(result.similarMatches).toHaveLength(0);
  });

  it('excludes the role being edited', () => {
    const result = checkRoleDuplicates({
      name: 'WARD CLERK',
      displayName: 'Ward Clerk',
      description: 'Front desk ward support',
      facilityId: null,
      existing,
      excludeRoleId: 'role-1'
    });

    expect(result.similarMatches).toHaveLength(0);
  });
});
