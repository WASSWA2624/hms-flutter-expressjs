const {
  checkUserDuplicates,
  compositeUserSimilarityScore,
  normalizeUserEmail,
  normalizeUserPhoneDigits,
  canonicalizeUserPositionTitle,
  EMAIL_WEIGHT,
  PHONE_WEIGHT,
  POSITION_TITLE_WEIGHT
} = require('@lib/user/user-similarity');

describe('user-similarity', () => {
  const existing = [
    {
      id: 'user-1',
      human_friendly_id: 'USR0001',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      email: 'alice@example.com',
      phone: '+256700111222',
      position_title: 'Registered Nurse',
      tenant: { id: 'tenant-1', name: 'Alpha Hospital' },
      facility: { id: 'facility-1', name: 'Main Facility' }
    }
  ];

  it('weights email above phone above position title', () => {
    expect(EMAIL_WEIGHT).toBeGreaterThan(PHONE_WEIGHT);
    expect(PHONE_WEIGHT).toBeGreaterThan(POSITION_TITLE_WEIGHT);
    const emailHeavy = compositeUserSimilarityScore({
      emailScore: 100,
      positionScore: 0
    });
    const positionHeavy = compositeUserSimilarityScore({
      emailScore: 0,
      positionScore: 100
    });
    expect(emailHeavy).toBeGreaterThan(positionHeavy);
  });

  it('normalizes email, phone digits, and position title', () => {
    expect(normalizeUserEmail('  Alice@Example.COM ')).toBe('alice@example.com');
    expect(normalizeUserPhoneDigits('+256 700-111-222')).toBe('256700111222');
    expect(canonicalizeUserPositionTitle('Registered  Nurse!')).toBe(
      'registered nurse'
    );
  });

  it('flags an exact email conflict within the tenant', () => {
    const result = checkUserDuplicates({
      email: 'ALICE@example.com',
      phone: '+256999000111',
      positionTitle: 'Lab Tech',
      tenantId: 'tenant-1',
      existing
    });

    expect(result.exactEmailConflict).toBe(true);
    expect(result.hasExactConflict).toBe(true);
    expect(result.similarMatches[0].exactEmailConflict).toBe(true);
    // Exact contact conflicts cannot be overridden with confirm_similar.
    expect(result.overridableMatches).toHaveLength(0);
  });

  it('flags an exact phone conflict within the tenant (formatting-agnostic)', () => {
    const result = checkUserDuplicates({
      email: 'brandnew@example.com',
      phone: '256-700-111-222',
      positionTitle: 'Lab Tech',
      tenantId: 'tenant-1',
      existing
    });

    expect(result.exactPhoneConflict).toBe(true);
    expect(result.hasExactConflict).toBe(true);
    expect(result.overridableMatches).toHaveLength(0);
  });

  it('surfaces a near position match as an overridable soft conflict', () => {
    const result = checkUserDuplicates({
      email: 'brandnew@example.com',
      phone: '+256999000111',
      positionTitle: 'Registered Nurses',
      tenantId: 'tenant-1',
      existing
    });

    expect(result.exactEmailConflict).toBe(false);
    expect(result.exactPhoneConflict).toBe(false);
    expect(result.hasExactConflict).toBe(false);
    expect(result.similarMatches.length).toBeGreaterThan(0);
    expect(result.overridableMatches.length).toBeGreaterThan(0);
    const match = result.similarMatches[0];
    expect(match.isExact).toBe(false);
    expect(match.positionScore).toBeGreaterThanOrEqual(75);
    expect(match.reasons).toContain('position_title');
  });

  it('returns no matches for an unrelated user', () => {
    const result = checkUserDuplicates({
      email: 'unrelated@other.com',
      phone: '+1555000999',
      positionTitle: 'Pharmacist',
      tenantId: 'tenant-1',
      existing
    });

    expect(result.hasExactConflict).toBe(false);
    expect(result.similarMatches).toHaveLength(0);
  });

  it('excludes the user being edited from its own conflict set', () => {
    const result = checkUserDuplicates({
      email: 'alice@example.com',
      phone: '+256700111222',
      positionTitle: 'Registered Nurse',
      tenantId: 'tenant-1',
      existing,
      excludeUserId: 'user-1'
    });

    expect(result.hasExactConflict).toBe(false);
    expect(result.similarMatches).toHaveLength(0);
  });

  it('emits field comparisons with input/candidate values', () => {
    const result = checkUserDuplicates({
      email: 'alice@example.com',
      phone: '+256700111222',
      positionTitle: 'Registered Nurse',
      tenantId: 'tenant-1',
      existing
    });

    const match = result.similarMatches[0];
    const emailComparison = match.field_comparisons.find(
      (entry) => entry.field === 'email'
    );
    expect(emailComparison).toBeDefined();
    expect(emailComparison.status).toBe('MATCH');
    expect(emailComparison.candidate_value).toBe('alice@example.com');
  });
});
