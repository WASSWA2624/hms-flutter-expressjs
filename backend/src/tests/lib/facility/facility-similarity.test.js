const {
  checkFacilityDuplicates,
  compositeSimilarityScore,
  normalizeFacilityType
} = require('@lib/facility/facility-similarity');

describe('facility-similarity', () => {
  const existing = [
    {
      id: 'facility-1',
      human_friendly_id: 'FAC0001',
      tenant_id: 'TEN0001',
      name: 'DemoCare General Hospital',
      facility_type: 'HOSPITAL',
      is_active: true,
      contacts: [
        { contact_type: 'PHONE', value: '+256 700 000 000', is_primary: true },
        { contact_type: 'EMAIL', value: 'info@democare.test', is_primary: true }
      ],
      addresses: [
        {
          line1: '12 Kampala Road',
          city: 'Kampala',
          country: 'Uganda'
        }
      ]
    }
  ];

  it('normalizes facility type', () => {
    expect(normalizeFacilityType(' hospital ')).toBe('HOSPITAL');
  });

  it('weights name more heavily than status', () => {
    const nameHeavy = compositeSimilarityScore({
      nameScore: 100,
      statusScore: 0
    });
    const statusHeavy = compositeSimilarityScore({
      nameScore: 0,
      statusScore: 100
    });
    expect(nameHeavy).toBeGreaterThan(statusHeavy);
  });

  it('detects exact name conflict within tenant peers', () => {
    const result = checkFacilityDuplicates({
      name: 'DemoCare General Hospital',
      facilityType: 'HOSPITAL',
      isActive: true,
      existing
    });

    expect(result.exactNameConflict).toBe(true);
    expect(result.hasExactConflict).toBe(true);
    expect(result.similarMatches[0].isExact).toBe(true);
  });

  it('returns overridable similar matches for near names', () => {
    const result = checkFacilityDuplicates({
      name: 'Democare General Hospitl',
      facilityType: 'HOSPITAL',
      isActive: true,
      phone: '+256700000000',
      existing
    });

    expect(result.exactNameConflict).toBe(false);
    expect(result.overridableMatches.length).toBeGreaterThan(0);
    expect(result.overridableMatches[0].score).toBeGreaterThanOrEqual(80);
  });

  it('excludes the edited facility id', () => {
    const result = checkFacilityDuplicates({
      name: 'DemoCare General Hospital',
      facilityType: 'HOSPITAL',
      isActive: true,
      existing,
      excludeFacilityId: 'facility-1'
    });

    expect(result.exactNameConflict).toBe(false);
    expect(result.similarMatches).toHaveLength(0);
  });
});
