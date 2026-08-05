const { withActivePatient } = require('@lib/patient-query-filters');

describe('withActivePatient', () => {
  test('default requires an active patient relation (no null patient_id)', () => {
    expect(withActivePatient({ tenant_id: 't1' })).toEqual({
      tenant_id: 't1',
      deleted_at: null,
      AND: [{ patient: { deleted_at: null } }],
    });
  });

  test('allowNullPatient keeps visitor rows with null patient_id', () => {
    expect(withActivePatient({ tenant_id: 't1' }, { allowNullPatient: true })).toEqual({
      tenant_id: 't1',
      deleted_at: null,
      AND: [
        {
          OR: [{ patient_id: null }, { patient: { deleted_at: null } }],
        },
      ],
    });
  });

  test('preserves existing AND clauses', () => {
    const result = withActivePatient({
      tenant_id: 't1',
      AND: [{ status: 'OPEN' }],
    });
    expect(result.AND).toEqual([
      { status: 'OPEN' },
      { patient: { deleted_at: null } },
    ]);
  });
});
