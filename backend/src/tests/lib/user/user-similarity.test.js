const {
  checkUserDuplicates,
  compositeUserSimilarityScore,
  normalizeUserEmail,
  normalizeUserPhoneDigits,
  canonicalizeUserPositionTitle,
  canonicalizePersonName,
  scorePhonePair,
  EMAIL_WEIGHT,
  PHONE_WEIGHT,
  FULL_NAME_WEIGHT,
  POSITION_TITLE_WEIGHT,
  FACILITY_WEIGHT,
  PHONE_COMPOSITE_MIN
} = require('@lib/user/user-similarity');

describe('user-similarity', () => {
  const existing = [
    {
      id: 'user-1',
      human_friendly_id: 'USR0001',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      email: 'alice.smith@example.com',
      phone: '+256700111222',
      position_title: 'Registered Nurse',
      profile: {
        first_name: 'Alice',
        last_name: 'Smith'
      },
      tenant: { id: 'tenant-1', name: 'Alpha Hospital' },
      facility: { id: 'facility-1', name: 'Main Facility' }
    }
  ];

  it('weights email and name above position and facility', () => {
    expect(EMAIL_WEIGHT).toBeGreaterThan(FULL_NAME_WEIGHT);
    expect(FULL_NAME_WEIGHT).toBeGreaterThan(PHONE_WEIGHT);
    expect(PHONE_WEIGHT).toBeGreaterThan(POSITION_TITLE_WEIGHT);
    expect(POSITION_TITLE_WEIGHT).toBeGreaterThan(FACILITY_WEIGHT);
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

  it('normalizes email, phone digits, names, and position title aliases', () => {
    expect(normalizeUserEmail('  Alice@Example.COM ')).toBe('alice@example.com');
    expect(normalizeUserPhoneDigits('+256 700-111-222')).toBe('256700111222');
    expect(canonicalizePersonName('Dr. Alice  Smith')).toBe('alice smith');
    expect(canonicalizeUserPositionTitle('RN')).toBe('registered nurse');
  });

  it('treats national phone suffixes as exact-strength matches', () => {
    expect(scorePhonePair('256700111222', '700111222')).toBe(100);
    expect(scorePhonePair('256700111222', '256788888888')).toBeLessThan(
      PHONE_COMPOSITE_MIN
    );
  });

  it('flags an exact email conflict within the tenant', () => {
    const result = checkUserDuplicates({
      email: 'ALICE.SMITH@example.com',
      phone: '+256999000111',
      positionTitle: 'Lab Tech',
      firstName: 'Alice',
      lastName: 'Smith',
      tenantId: 'tenant-1',
      existing
    });

    expect(result.exactEmailConflict).toBe(true);
    expect(result.hasExactConflict).toBe(true);
    expect(result.similarMatches[0].exactEmailConflict).toBe(true);
    expect(result.overridableMatches).toHaveLength(0);
  });

  it('flags an exact phone conflict within the tenant (formatting-agnostic)', () => {
    const result = checkUserDuplicates({
      email: 'brandnew@example.com',
      phone: '256-700-111-222',
      positionTitle: 'Lab Tech',
      firstName: 'Bob',
      lastName: 'Jones',
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
      firstName: 'Carol',
      lastName: 'Nguyen',
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

  it('surfaces swapped first/last names as a strong name match', () => {
    const result = checkUserDuplicates({
      email: 'brandnew@example.com',
      phone: '+256999000111',
      positionTitle: 'Pharmacist',
      firstName: 'Smith',
      lastName: 'Alice',
      facilityId: 'facility-1',
      tenantId: 'tenant-1',
      existing
    });

    expect(result.hasExactConflict).toBe(false);
    expect(result.similarMatches.length).toBeGreaterThan(0);
    const match = result.similarMatches[0];
    expect(match.fullNameScore).toBeGreaterThanOrEqual(88);
    expect(match.reasons).toEqual(
      expect.arrayContaining(['full_name', 'facility'])
    );
  });

  it('matches email local-part against the peer full name', () => {
    const result = checkUserDuplicates({
      email: 'alice.smith@other.org',
      phone: '+256999000111',
      positionTitle: 'Clerk',
      firstName: 'Alicia',
      lastName: 'Smyth',
      tenantId: 'tenant-1',
      existing
    });

    expect(result.similarMatches.length).toBeGreaterThan(0);
    const match = result.similarMatches[0];
    expect(match.fullNameScore).toBeGreaterThanOrEqual(75);
  });

  it('does not dilute composite score with weak unrelated phone similarity', () => {
    const result = checkUserDuplicates({
      email: 'alice.smith@example.com',
      phone: '+256788888888',
      positionTitle: 'Registered Nurse',
      firstName: 'Alice',
      lastName: 'Smith',
      facilityId: 'facility-1',
      tenantId: 'tenant-1',
      existing
    });

    expect(result.exactEmailConflict).toBe(true);
    const match = result.similarMatches[0];
    // Email + name + position + facility should stay near 100 when weak phone is excluded.
    expect(match.score).toBeGreaterThanOrEqual(95);
    const phoneComparison = match.field_comparisons.find(
      (entry) => entry.field === 'phone'
    );
    expect(phoneComparison.status).toBe('DIFFERENT');
  });

  it('returns no matches for an unrelated user', () => {
    const result = checkUserDuplicates({
      email: 'unrelated@other.com',
      phone: '+1555000999',
      positionTitle: 'Pharmacist',
      firstName: 'Zed',
      lastName: 'Quark',
      tenantId: 'tenant-1',
      existing
    });

    expect(result.hasExactConflict).toBe(false);
    expect(result.similarMatches).toHaveLength(0);
  });

  it('excludes the user being edited from its own conflict set', () => {
    const result = checkUserDuplicates({
      email: 'alice.smith@example.com',
      phone: '+256700111222',
      positionTitle: 'Registered Nurse',
      firstName: 'Alice',
      lastName: 'Smith',
      tenantId: 'tenant-1',
      existing,
      excludeUserId: 'user-1'
    });

    expect(result.hasExactConflict).toBe(false);
    expect(result.similarMatches).toHaveLength(0);
  });

  it('emits field comparisons including name and facility', () => {
    const result = checkUserDuplicates({
      email: 'alice.smith@example.com',
      phone: '+256700111222',
      positionTitle: 'Registered Nurse',
      firstName: 'Alice',
      lastName: 'Smith',
      facilityId: 'facility-1',
      tenantId: 'tenant-1',
      existing
    });

    const match = result.similarMatches[0];
    const fields = match.field_comparisons.map((entry) => entry.field);
    expect(fields).toEqual(
      expect.arrayContaining([
        'first_name',
        'last_name',
        'full_name',
        'email',
        'phone',
        'position_title',
        'facility'
      ])
    );
    const emailComparison = match.field_comparisons.find(
      (entry) => entry.field === 'email'
    );
    expect(emailComparison.status).toBe('MATCH');
  });
});
