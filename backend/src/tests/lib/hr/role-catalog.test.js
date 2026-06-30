const {
  HR_ROLE_CATALOG,
  HR_ASSIGNABLE_ROLE_NAMES,
  roleLabel,
  enrichRoleOption,
  sortRoleRecords,
} = require('@lib/hr/role-catalog');

describe('hr role-catalog', () => {
  it('includes a comprehensive hospital role catalog', () => {
    expect(HR_ROLE_CATALOG.length).toBeGreaterThanOrEqual(50);
    expect(HR_ASSIGNABLE_ROLE_NAMES).toEqual(
      expect.arrayContaining([
        'DOCTOR',
        'NURSE',
        'ATTENDING_PHYSICIAN',
        'NURSE_PRACTITIONER',
        'PARAMEDIC',
        'MEDICAL_CODER',
        'BIOMED',
      ])
    );
    for (const entry of HR_ROLE_CATALOG) {
      expect(entry.labelKey).toMatch(/^labels\.hr\.reference\.role\./);
      expect(entry.defaultLabel).not.toMatch(/_/);
    }
  });

  it('returns human-readable labels instead of machine codes', () => {
    expect(roleLabel('BIOMED')).toBe('Biomedical Engineer / Technician');
    expect(roleLabel('AMBULANCE_OPERATOR')).toBe('Ambulance Operator');
    expect(roleLabel('NURSE')).toBe('Registered Nurse (RN)');
  });

  it('enriches role options with localized labels', () => {
    const option = enrichRoleOption({
      id: 'role-1',
      human_friendly_id: 'ROLE-ABC123',
      name: 'PHYSICIAN_ASSISTANT',
      permissions: [{ permission_id: 'p1' }, { permission_id: 'p2' }],
    });
    expect(option).toEqual(
      expect.objectContaining({
        value: 'ROLE-ABC123',
        label: 'Physician Assistant (PA)',
        label_key: 'labels.hr.reference.role.physician_assistant',
        name: 'PHYSICIAN_ASSISTANT',
        permission_count: 2,
      })
    );
  });

  it('sorts roles by clinical category before label', () => {
    const sorted = sortRoleRecords([
      { name: 'BILLING' },
      { name: 'DOCTOR' },
      { name: 'NURSE' },
    ]).map((entry) => entry.name);
    expect(sorted.indexOf('DOCTOR')).toBeLessThan(sorted.indexOf('NURSE'));
    expect(sorted.indexOf('NURSE')).toBeLessThan(sorted.indexOf('BILLING'));
  });
});
