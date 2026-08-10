const {
  checkStaffPositionDuplicates,
  normalizeText
} = require('@lib/staff-position/staff-position-similarity');

describe('staff-position-similarity', () => {
  const existing = [
    {
      id: 'pos-1',
      human_friendly_id: 'SPO0001',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      name: 'Nurse',
      is_active: true
    },
    {
      id: 'pos-2',
      human_friendly_id: 'SPO0002',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      name: 'Registered Nurse',
      is_active: true
    }
  ];

  test('flags exact name conflicts', () => {
    const result = checkStaffPositionDuplicates({
      name: 'nurse',
      existing
    });
    expect(result.exactNameConflict).toBe(true);
    expect(result.similarMatches[0].exactNameConflict).toBe(true);
    expect(normalizeText('Nurse')).toBe(normalizeText('nurse'));
  });

  test('returns similar matches for near names', () => {
    const result = checkStaffPositionDuplicates({
      name: 'Registered Nurses',
      existing
    });
    expect(result.exactNameConflict).toBe(false);
    expect(result.overridableMatches.length).toBeGreaterThan(0);
  });

  test('excludes the editing position id', () => {
    const result = checkStaffPositionDuplicates({
      name: 'Nurse',
      existing,
      excludePositionId: 'pos-1'
    });
    expect(result.exactNameConflict).toBe(false);
  });
});
