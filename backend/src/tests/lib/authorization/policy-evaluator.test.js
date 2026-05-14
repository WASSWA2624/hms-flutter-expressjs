const {
  evaluatePolicies,
  matchConditions,
  matchValue,
} = require('@lib/authorization/policy-evaluator');

describe('policy-evaluator', () => {
  it('supports includes, not, and any_of matching', () => {
    expect(matchValue(['ward-a', 'ward-b'], { includes: ['ward-b'] })).toBe(true);
    expect(matchValue('night', { not: 'day' })).toBe(true);
    expect(matchValue('doctor', { any_of: ['nurse', 'doctor'] })).toBe(true);
    expect(
      matchConditions(
        {
          role: { any_of: ['DOCTOR', 'NURSE'] },
          ward_ids: { includes: ['WARD-2'] },
          handover_pending: { not: true },
        },
        {
          role: 'DOCTOR',
          ward_ids: ['WARD-1', 'WARD-2'],
          handover_pending: false,
        }
      )
    ).toBe(true);
  });

  it('prefers deny when priorities are equal', () => {
    const result = evaluatePolicies({
      policies: [
        {
          id: 'allow-1',
          effect: 'ALLOW',
          priority: 50,
          subject_conditions_json: { role: 'DOCTOR' },
        },
        {
          id: 'deny-1',
          effect: 'DENY',
          priority: 50,
          subject_conditions_json: { role: 'DOCTOR' },
        },
      ],
      subject: { role: 'DOCTOR' },
    });

    expect(result.allowed).toBe(false);
    expect(result.winner).toEqual(expect.objectContaining({ id: 'deny-1', effect: 'DENY' }));
    expect(result.matched).toHaveLength(2);
  });

  it('returns null when no policy matches the request context', () => {
    const result = evaluatePolicies({
      policies: [
        {
          id: 'allow-night-shift',
          effect: 'ALLOW',
          priority: 10,
          subject_conditions_json: { role: 'NURSE' },
          environment_conditions_json: { shift_type: 'NIGHT' },
        },
      ],
      subject: { role: 'DOCTOR' },
      environment: { shift_type: 'DAY' },
    });

    expect(result.allowed).toBeNull();
    expect(result.winner).toBeNull();
    expect(result.matched).toEqual([]);
  });
});
