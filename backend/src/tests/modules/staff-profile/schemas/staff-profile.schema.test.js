const subject = require('../../../../modules/staff-profile/schemas/staff-profile.schema');

describe('staff-profile.schema contract', () => {
  it('exports schema definitions', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });

  it('rejects duplicate compensation pay types in one payload', () => {
    const result = subject.updateStaffProfileSchema.safeParse({
      compensations: [
        {
          pay_type: 'PER_MONTH',
          rate: 3000,
          currency: 'USD',
          effective_from: '2026-01-01'},
        {
          pay_type: 'PER_MONTH',
          rate: 3200,
          currency: 'USD',
          effective_from: '2026-02-01'}]});

    expect(result.success).toBe(false);
  });

  it('accepts multi-line compensation with metadata_json', () => {
    const result = subject.updateStaffProfileSchema.safeParse({
      compensations: [
        {
          pay_type: 'PER_MONTH',
          rate: 3000,
          currency: 'USD',
          effective_from: '2026-01-01',
          metadata_json: { pay_frequency: 'MONTHLY' }},
        {
          pay_type: 'PER_CONSULTATION',
          rate: 75,
          currency: 'USD',
          effective_from: '2026-01-01'}]});

    expect(result.success).toBe(true);
  });
});
