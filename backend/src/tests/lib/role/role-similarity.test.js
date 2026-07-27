const {
  checkRoleDuplicates,
  compositeSimilarityScore,
  canonicalizeRoleText,
  normalizeRoleCompactKey,
  normalizeRoleSortedTokens,
  roleInitialsKey,
  roleScopesMatch,
  scoreTextPair
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

  it('normalizes compact and sorted identity keys', () => {
    expect(normalizeRoleCompactKey('WARD_CLERK')).toBe('wardclerk');
    expect(normalizeRoleCompactKey('Ward Clerk')).toBe('wardclerk');
    expect(normalizeRoleSortedTokens('Clerk Ward')).toBe('clerk ward');
    expect(normalizeRoleSortedTokens('Ward Clerk')).toBe('clerk ward');
  });

  it('canonicalizes aliases and filler tokens', () => {
    expect(canonicalizeRoleText('The RN Role')).toBe('registered nurse');
    expect(roleInitialsKey('Ward Clerk')).toBe('wc');
  });

  it('scores compact and reordered identity pairs highly', () => {
    expect(scoreTextPair('ward clerk', 'wardclerk')).toBe(100);
    expect(scoreTextPair('ward clerk', 'clerk ward')).toBe(100);
  });

  it('detects exact name conflict within the same scope', () => {
    const result = checkRoleDuplicates({
      name: 'WARD CLERK',
      displayName: 'Ward Clerk',
      description: 'Front desk ward support',
      tenantId: 'tenant-1',
      facilityId: null,
      existing
    });

    expect(result.exactNameConflict).toBe(true);
    expect(result.hasExactConflict).toBe(true);
    expect(result.similarMatches[0].isExact).toBe(true);
  });

  it('detects compact-key exact conflicts (WARDCLERK vs Ward Clerk)', () => {
    const result = checkRoleDuplicates({
      name: 'WARDCLERK',
      displayName: 'Desk Aide',
      description: 'Different description',
      tenantId: 'tenant-1',
      facilityId: null,
      existing
    });

    expect(result.hasExactConflict).toBe(true);
    expect(result.similarMatches[0].isExact).toBe(true);
  });

  it('detects reordered display-name conflicts', () => {
    const result = checkRoleDuplicates({
      name: 'FRONT DESK',
      displayName: 'Clerk Ward',
      description: 'Other duties',
      tenantId: 'tenant-1',
      facilityId: null,
      existing
    });

    expect(result.hasExactConflict).toBe(true);
    expect(result.similarMatches.some((match) => match.exactDisplayNameConflict || match.isExact)).toBe(true);
  });

  it('detects cross-field identity when name matches existing display name', () => {
    const result = checkRoleDuplicates({
      name: 'Ward Clerk',
      displayName: 'Desk Support',
      description: 'Other',
      tenantId: 'tenant-1',
      facilityId: null,
      existing
    });

    expect(result.hasExactConflict).toBe(true);
    expect(result.similarMatches[0].crossIdentityScore).toBe(100);
  });

  it('returns overridable similar matches for near names', () => {
    const result = checkRoleDuplicates({
      name: 'WARD CLRCK',
      displayName: 'Ward Clerck',
      description: 'Front desk ward suport',
      tenantId: 'tenant-1',
      facilityId: null,
      existing
    });

    expect(result.hasExactConflict).toBe(false);
    expect(result.overridableMatches.length).toBeGreaterThan(0);
    expect(result.overridableMatches[0].score).toBeGreaterThanOrEqual(72);
  });

  it('flags description-led near matches with supporting identity', () => {
    const result = checkRoleDuplicates({
      name: 'WARD AID',
      displayName: 'Ward Aide',
      description: 'Front desk ward support',
      tenantId: 'tenant-1',
      facilityId: null,
      existing
    });

    expect(result.similarMatches.length).toBeGreaterThan(0);
    expect(result.similarMatches[0].descriptionScore).toBeGreaterThanOrEqual(85);
  });

  it('flags soft composite near-matches below the hard 80 threshold', () => {
    const result = checkRoleDuplicates({
      name: 'WARD SUPPORT',
      displayName: 'Ward Support Clerk',
      description: 'Helps at front desk',
      tenantId: 'tenant-1',
      facilityId: null,
      existing
    });

    expect(result.similarMatches.length).toBeGreaterThan(0);
  });

  it('ignores peers outside the facility scope', () => {
    const result = checkRoleDuplicates({
      name: 'WARD CLERK',
      displayName: 'Ward Clerk',
      description: 'Front desk ward support',
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      existing
    });

    expect(result.similarMatches).toHaveLength(0);
  });

  it('isolates platform roles from tenant-scoped peers', () => {
    const result = checkRoleDuplicates({
      name: 'WARD CLERK',
      displayName: 'Ward Clerk',
      tenantId: null,
      facilityId: null,
      existing
    });

    expect(result.similarMatches).toHaveLength(0);
  });

  it('expands hospital role aliases for exact conflicts', () => {
    const result = checkRoleDuplicates({
      name: 'RN',
      displayName: 'RN',
      tenantId: 'tenant-1',
      facilityId: null,
      existing: [
        {
          id: 'role-rn',
          tenant_id: 'tenant-1',
          facility_id: null,
          name: 'REGISTERED NURSE',
          display_name: 'Registered Nurse'
        }
      ]
    });

    expect(result.hasExactConflict).toBe(true);
    expect(result.similarMatches[0].nameScore).toBe(100);
  });

  it('treats initials as exact identity conflicts', () => {
    const result = checkRoleDuplicates({
      name: 'WC',
      displayName: 'WC',
      tenantId: 'tenant-1',
      facilityId: null,
      existing
    });

    expect(result.hasExactConflict).toBe(true);
  });

  it('flags token-subset near matches like Senior Ward Clerk', () => {
    const result = checkRoleDuplicates({
      name: 'SENIOR WARD CLERK',
      displayName: 'Senior Ward Clerk',
      tenantId: 'tenant-1',
      facilityId: null,
      existing
    });

    expect(result.similarMatches.length).toBeGreaterThan(0);
    expect(result.similarMatches[0].nameScore).toBeGreaterThanOrEqual(78);
  });

  it('roleScopesMatch distinguishes platform tenant and facility', () => {
    expect(roleScopesMatch({
      leftTenantId: null,
      leftFacilityId: null,
      rightTenantId: null,
      rightFacilityId: null
    })).toBe(true);
    expect(roleScopesMatch({
      leftTenantId: null,
      leftFacilityId: null,
      rightTenantId: 'tenant-1',
      rightFacilityId: null
    })).toBe(false);
  });

  it('excludes the role being edited', () => {
    const result = checkRoleDuplicates({
      name: 'WARD CLERK',
      displayName: 'Ward Clerk',
      description: 'Front desk ward support',
      tenantId: 'tenant-1',
      facilityId: null,
      existing,
      excludeRoleId: 'role-1'
    });

    expect(result.similarMatches).toHaveLength(0);
  });
});
