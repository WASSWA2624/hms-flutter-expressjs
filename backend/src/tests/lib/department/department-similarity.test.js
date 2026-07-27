const {
  checkDepartmentDuplicates,
  compositeSimilarityScore,
  normalizeDepartmentType
} = require('@lib/department/department-similarity');

describe('department-similarity', () => {
  const existing = [
    {
      id: 'dept-1',
      human_friendly_id: 'DEP0001',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      name: 'Emergency Department',
      short_name: 'ER',
      department_type: 'CLINICAL',
      is_active: true
    }
  ];

  it('normalizes department type', () => {
    expect(normalizeDepartmentType(' clinical ')).toBe('CLINICAL');
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

  it('detects exact name conflict within facility peers', () => {
    const result = checkDepartmentDuplicates({
      name: 'Emergency Department',
      shortName: 'ER',
      departmentType: 'CLINICAL',
      isActive: true,
      existing
    });

    expect(result.exactNameConflict).toBe(true);
    expect(result.hasExactConflict).toBe(true);
    expect(result.similarMatches[0].isExact).toBe(true);
  });

  it('returns overridable similar matches for near names', () => {
    const result = checkDepartmentDuplicates({
      name: 'Emergancy Departmnt',
      shortName: 'ER',
      departmentType: 'CLINICAL',
      isActive: true,
      existing
    });

    expect(result.exactNameConflict).toBe(false);
    expect(result.overridableMatches.length).toBeGreaterThan(0);
    expect(result.overridableMatches[0].score).toBeGreaterThanOrEqual(80);
  });

  it('flags stem/containment near-matches such as test vs Testing', () => {
    const result = checkDepartmentDuplicates({
      name: 'test',
      shortName: 'test',
      departmentType: 'CLINICAL',
      isActive: true,
      existing: [
        {
          id: 'dept-2',
          human_friendly_id: 'DEP0002',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          name: 'Testing',
          short_name: 'Testing',
          department_type: 'CLINICAL',
          is_active: true
        }
      ]
    });

    expect(result.exactNameConflict).toBe(false);
    expect(result.overridableMatches.length).toBeGreaterThan(0);
    expect(result.overridableMatches[0].nameScore).toBeGreaterThanOrEqual(80);
    expect(result.overridableMatches[0].score).toBeGreaterThanOrEqual(80);
  });

  it('defaults short name to name when short name is empty', () => {
    const result = checkDepartmentDuplicates({
      name: 'Emergency Department',
      shortName: '',
      departmentType: 'CLINICAL',
      isActive: true,
      existing: [
        {
          ...existing[0],
          name: 'Other Unit',
          short_name: 'Emergency Department'
        }
      ]
    });

    expect(result.overridableMatches.length).toBeGreaterThan(0);
    expect(result.overridableMatches[0].reasons).toContain('short_name');
  });

  it('excludes the edited department id', () => {
    const result = checkDepartmentDuplicates({
      name: 'Emergency Department',
      shortName: 'ER',
      departmentType: 'CLINICAL',
      isActive: true,
      existing,
      excludeDepartmentId: 'dept-1'
    });

    expect(result.exactNameConflict).toBe(false);
    expect(result.similarMatches).toHaveLength(0);
  });
});
