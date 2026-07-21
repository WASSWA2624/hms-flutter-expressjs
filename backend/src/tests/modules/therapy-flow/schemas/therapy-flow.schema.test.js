const { QUEUE_SCOPE_VALUES, THERAPY_STATUS_VALUES } = require('@validations/therapy-flow/therapy-flow.schema');

describe('therapy-flow.schema', () => {
  it('defines queue scopes aligned with frontend', () => {
    expect(QUEUE_SCOPE_VALUES).toEqual(
      expect.arrayContaining([
        'REFERRAL',
        'TODAY',
        'MISSED',
        'ACTIVE_PLAN',
        'FOLLOW_UP_DUE',
        'COMPLETED',
        'ALL'])
    );
  });

  it('defines canonical therapy statuses', () => {
    expect(THERAPY_STATUS_VALUES).toEqual(
      expect.arrayContaining(['REFERRAL', 'ACTIVE_PLAN', 'CLOSED'])
    );
  });
});
